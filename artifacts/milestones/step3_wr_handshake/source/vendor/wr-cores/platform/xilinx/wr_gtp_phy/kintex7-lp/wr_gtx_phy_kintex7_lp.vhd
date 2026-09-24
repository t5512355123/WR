-------------------------------------------------------------------------------
-- Title      : Deterministic Xilinx GTX LPDC wrapper - kintex-7 top module
-- Project    : White Rabbit Switch
-------------------------------------------------------------------------------
-- File       : wr_gtx_phy_kindex7_lp.vhd
-- Author     : Peter Jansweijer, Tomasz Wlostowski
-- Company    : CERN BE-CO-HT
-- Created    : 2013-04-08
-- Platform   : Kintex-7
-- Standard   : VHDL'93
-------------------------------------------------------------------------------
-- Description: Wrapper for Xilinx Kintex-7 GTX adapted for
-- deterministic delays at 1.25 Gbps.
-------------------------------------------------------------------------------
--
-- Copyright (c) 2010-2023 CERN
--
-- This source file is free software; you can redistribute it
-- and/or modify it under the terms of the GNU Lesser General
-- Public License as published by the Free Software Foundation;
-- either version 2.1 of the License, or (at your option) any
-- later version.
--
-- This source is distributed in the hope that it will be
-- useful, but WITHOUT ANY WARRANTY; without even the implied
-- warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
-- PURPOSE.  See the GNU Lesser General Public License for more
-- details.
--
-- You should have received a copy of the GNU Lesser General
-- Public License along with this source; if not, download it
-- from http://www.gnu.org/licenses/lgpl-2.1.html
--
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

library work;
use work.gencores_pkg.all;
use work.disparity_gen_pkg.all;
use work.wishbone_pkg.all;
use work.lpdc_mdio_regs_pkg.all;

entity wr_gtx_phy_kintex7_lp is

  generic (
    -- set to non-zero value to speed up the simulation by reducing some delays
    g_simulation         : integer := 0;
    g_id : integer := 0;
    g_reverse_ddmtds : boolean := false
    
    );

  port (

    -- systemc clock for MDIO registers
    clk_sys_i : in std_logic;
    rst_sys_n_i : in std_logic;

    -- Dedicated reference 125 MHz clock for the GTX transceiver
    --qpll_clk_i : in std_logic;
    --qpll_ref_clk_i : in std_logic;
    --qpll_locked_i : in std_logic;
    --qpll_reset_o : out std_logic;

    -- reset input, active hi
    rst_i         : in std_logic;

    -- DMTD clock for phase measurements (done in the PHY module as we need to
    -- multiplex between several GTX clock outputs)
    clk_dmtd_i : in std_logic;

    clk_gtx_i : in std_logic;

    -- Reference 62.5 MHz clock input for the TX/RX deterministic phase logic (not the GTX itself)
    clk_ref_i : in std_logic;
    clk_ref_sampled_o : out std_logic;

    -- TX path, synchronous to tx_clk_o (125 MHz):
    tx_clk_o : out std_logic;
    tx_locked_o  : out std_logic;

    -- data input (8 bits, not 8b10b-encoded)
    tx_data_i : in std_logic_vector(15 downto 0);

    -- 1 when tx_data_i contains a control code, 0 when it's a data byte
    tx_k_i : in std_logic_vector(1 downto 0);

    -- disparity of the currently transmitted 8b10b code (1 = plus, 0 = minus).
    -- Necessary for the PCS to generate proper frame termination sequences.
    -- Generated for the 2nd byte (LSB) of tx_data_i.
    tx_disparity_o : out std_logic;

    -- Encoding error indication (1 = error, 0 = no error)
    tx_enc_err_o : out std_logic;

    -- RX path, synchronous to ch0_rx_rbclk_o.

    -- RX recovered clock
    rx_rbclk_o : out std_logic;

    -- 8b10b-decoded data output. The data output must be kept invalid before
    -- the transceiver is locked on the incoming signal to prevent the EP from
    -- detecting a false carrier.
    rx_data_o : out std_logic_vector(15 downto 0);

    -- 1 when the byte on rx_data_o is a control code
    rx_k_o : out std_logic_vector(1 downto 0);

    -- encoding error indication
    rx_enc_err_o : out std_logic;

    -- RX bitslide indication, indicating the delay of the RX path of the
    -- transceiver (in UIs). Must be valid when ch0_rx_data_o is valid.
    -- In this "low-phase-drift" implementaion rx alignment is fixed by
    -- throwing the dice until it is on "comma_target_pos".
    -- rx_bitslide is not used and set to zero.
    rx_bitslide_o : out std_logic_vector(4 downto 0);

    loopen_i      : in std_logic;
    loopen_vec_i  : in std_logic_vector(2 downto 0);

    pad_txn_o : out std_logic;
    pad_txp_o : out std_logic;

    pad_rxn_i : in std_logic := '0';
    pad_rxp_i : in std_logic := '0';

    rdy_o     : out std_logic;

    rx_rbclk_sampled_o : out std_logic;

    fmon_clk_o : out std_logic;

    mdio_slave_i : in t_wishbone_slave_in;
    mdio_slave_o : out t_wishbone_slave_out
    );
end wr_gtx_phy_kintex7_lp;

architecture rtl of wr_gtx_phy_kintex7_lp is

  component BUFG
    port (
      O : out std_ulogic;
      I : in  std_ulogic);
  end component;

  component gc_dec_8b10b is
    port (
      clk_i       : in  std_logic;
      rst_n_i     : in  std_logic;
      in_10b_i    : in  std_logic_vector(9 downto 0);
      ctrl_o      : out std_logic;
      code_err_o  : out std_logic;
      rdisp_err_o : out std_logic;
      out_8b_o    : out std_logic_vector(7 downto 0));
  end component gc_dec_8b10b;

  constant c_rxcdrlock_max            : integer := 1000;
  constant c_reset_cnt_max            : integer := 64;	-- Reset pulse width 64 * 8 = 512 ns

  signal tx_enable_txclk, rx_enable_rxclk : std_logic;

  signal rst_rx_62m5_n : std_logic;
  signal rst_ref_n                     : std_logic;

  signal rx_gearbox_pll_locked : std_logic;

  signal clk_rx_250m_bufin             : std_logic;
  signal clk_rx_62m5_bufin, clk_rx_62m5, clk_rx_250m : std_logic;

  signal tx_out_clk_bufin             : std_logic;
  signal tx_out_clk                   : std_logic;
  signal rx_cdr_lock                  : std_logic;
  signal rx_cdr_lock_filtered         : std_logic;

  signal tx_rst_done, rx_rst_done     : std_logic;
  signal txpll_lockdet, rxpll_lockdet : std_logic;
--  signal pll_lockdet                  : std_logic;
--  signal cpll_lockdet                 : std_logic;

  signal everything_ready             : std_logic;
  signal rst_done                     : std_logic;
  signal rst_done_n                   : std_logic;

  signal rx_k_o_int    : std_logic_vector(1 downto 0);
  signal rx_data_o_int : std_logic_vector(15 downto 0);
  signal rx_k_int    : std_logic_vector(1 downto 0);
  signal rx_data_int : std_logic_vector(15 downto 0);

  signal rx_data_raw_250m : std_logic_vector(39 downto 0);
  signal rx_data_raw_62m5 : std_logic_vector(19 downto 0);

  signal rx_enc_err_o_int : std_logic;
  signal rx_disp_err, rx_code_err     : std_logic_vector(1 downto 0);


  signal cur_disp                     : t_8b10b_disparity;



  signal link_up, link_aligned : std_logic;
  signal gtx_rx_reset_a : std_logic;
  signal gtx_tx_reset_a : std_logic;
  signal gtx_rst_tx_a : std_logic;

  signal rx_rec_clk_sampled, tx_out_clk_sampled : std_logic;
  signal gtx_loopback               : std_logic_vector(2 downto 0);

  signal tx_data_8b10b : std_logic_vector(19 downto 0);

  function f_widen(x : std_logic_vector; ratio : integer) return std_logic_vector is
    variable rv : std_logic_vector(x'length * ratio -1 downto 0);
  begin
    for i in 0 to x'length-1 loop
      rv(i*ratio + ratio-1 downto i*ratio) := (others => x(i));
    end loop;

    return rv;
  end function;


  signal comma_target_pos : std_logic_vector(4 downto 0);
  signal comma_current_pos : std_logic_vector(4 downto 0);
  signal comma_pos_valid : std_logic;

  signal tx_out_clk_div2 : std_logic;
  signal tx_out_clk_div1 : std_logic;
  signal gtx_rst_n_txdiv2 : std_logic;

  signal run_disparity_q0, run_disparity_q1 : std_logic;
  signal run_disparity_reg : std_logic;

  signal tx_out_clk_div2_bufin : std_logic;
  signal tx_out_clk_div1_bufin : std_logic;
  signal txusrpll_locked : std_logic;


  attribute mark_debug : string;
  attribute mark_debug of rx_data_raw_62m5 : signal is "true";
  attribute mark_debug of tx_data_i : signal is "true";
  attribute mark_debug of tx_k_i : signal is "true";
  attribute mark_debug of rx_k_int : signal is "true";
  attribute mark_debug of rx_data_int : signal is "true";
  attribute mark_debug of link_up : signal is "true";
  attribute mark_debug of tx_enable_txclk : signal is "true";
  attribute mark_debug of rx_enable_rxclk : signal is "true";

  constant c_K28_5_PLUS : std_logic_vector(9 downto 0) := "1010000011";

  signal lpdc_regs_out : t_lpdc_regs_master_out;
  signal lpdc_regs_in : t_lpdc_regs_master_in;
  signal drp_regs_in : t_wishbone_slave_out;
  signal drp_regs_out : t_wishbone_slave_in;

  attribute mark_debug of lpdc_regs_out : signal is "true";
  attribute mark_debug of mdio_slave_o : signal is "true";
  attribute mark_debug of mdio_slave_i : signal is "true";

  signal gtx_rst_a : std_logic;

  signal drp_addr : std_logic_vector(8 downto 0);
  signal drp_dout, drp_din : std_logic_vector(15 downto 0);
  signal drp_we, drp_rdy, drp_en : std_logic;
  signal drp_in_progress : std_logic;
  signal rx_rate : std_logic_vector(2 downto 0);

  signal rst_rx_path_a : std_logic;

  signal clk_rx_fb_pll, clk_rx_fb_pll_bufg : std_logic;

  signal rx_pat_latch_p1_rx_62m5 : std_logic;
  signal rx_pat_value : std_logic_vector(239 downto 0);

  signal ddmtd_mask_cnt_sreg_fedge : std_logic_vector(3 downto 0);
  signal ddmtd_mask_sync_62m5 : std_logic;
  signal ddmtd_mask_sync_250m, ddmtd_mask_sync_250m_d, ddmtd_mask_sync_250m_p, ddmtd_mask_sync_250m_p_fedge : std_logic;


signal cpll_reset, cpll_locked : std_logic;
begin  -- rtl

  U_LPDC_regs : entity work.lpdc_mdio_regs
    port map (
      rst_n_i     => rst_sys_n_i,
      clk_i       => clk_sys_i,
      wb_i        => mdio_slave_i,
      wb_o        => mdio_slave_o,
      lpdc_regs_i => lpdc_regs_in,
      lpdc_regs_o => lpdc_regs_out,
      drp_regs_i  => drp_regs_in,
      drp_regs_o  => drp_regs_out);


  rx_rate <= lpdc_regs_out.ctrl2_rx_rate;

  -- Near-end PMA loopback if loopen_i active
  gtx_loopback <= "010" when loopen_i = '1' else loopen_vec_i;

  U_SyncTxEnable : gc_sync_ffs
    port map
    (
      clk_i    => tx_out_clk_div2,
      rst_n_i  => '1',
      data_i   => lpdc_regs_out.CTRL_tx_enable,
      synced_o => tx_enable_txclk
      );

  U_SyncRxEnable : gc_sync_ffs
    port map
    (
      clk_i    => clk_rx_62m5,
      rst_n_i  => rx_gearbox_pll_locked,
      data_i   => lpdc_regs_out.CTRL_rx_enable,
      synced_o => rx_enable_rxclk
      );

  U_SyncRxReset : gc_sync_ffs
    port map
    (
      clk_i    => clk_dmtd_i,
      rst_n_i  => '1',
      data_i   => lpdc_regs_out.CTRL_rx_sw_reset,
      synced_o => gtx_rx_reset_a
      );

  U_SyncQPLLReset : gc_sync_ffs
    port map
    (
      clk_i    => clk_dmtd_i,
      rst_n_i  => '1',
      data_i   => lpdc_regs_out.CTRL_pll_sw_reset,
      synced_o => cpll_reset
      );


  U_SyncTxReset : gc_sync_ffs
    port map
    (
      clk_i    => clk_dmtd_i,
      rst_n_i  => '1',
      data_i   => lpdc_regs_out.CTRL_tx_sw_reset,
      synced_o => gtx_tx_reset_a
      );

  U_Sampler_RX : entity work.dmtd_sampler
    generic map (
      g_divide_input_by_2 => false,
      g_reverse           => g_reverse_ddmtds)
    port map (
      clk_in_i      => clk_rx_250m,
      en_i          => f_pick(g_reverse_ddmtds, ddmtd_mask_sync_250m_p, ddmtd_mask_sync_250m_p_fedge),
      clk_dmtd_i    => clk_dmtd_i,
      clk_sampled_o => rx_rec_clk_sampled);

  U_Sampler_TX : entity work.dmtd_sampler
    generic map (
      g_divide_input_by_2 => false,
      g_reverse           => g_reverse_ddmtds)
    port map (
      clk_in_i      => tx_out_clk_div2,
      clk_dmtd_i    => clk_dmtd_i,
      clk_sampled_o => tx_out_clk_sampled);

  U_Sampler_REFCLK : entity work.dmtd_sampler
    generic map (
      g_divide_input_by_2 => false,
      g_reverse           => g_reverse_ddmtds)
    port map (
      clk_in_i      => clk_ref_i,
      clk_dmtd_i    => clk_dmtd_i,
      clk_sampled_o => clk_ref_sampled_o);

  process(clk_rx_62m5, rx_gearbox_pll_locked)
  begin
    if rx_gearbox_pll_locked = '0' then
      ddmtd_mask_sync_62m5 <= '0';
    elsif rising_edge(clk_rx_62m5) then
      ddmtd_mask_sync_62m5 <= not ddmtd_mask_sync_62m5;
    end if;
  end process;

  process(clk_rx_250m, rx_gearbox_pll_locked)
  begin
    if rx_gearbox_pll_locked = '0' then
      ddmtd_mask_sync_250m <= '0';
      ddmtd_mask_sync_250m_d <= '0';
      ddmtd_mask_sync_250m_p <= '0';
    elsif rising_edge(clk_rx_250m) then
      ddmtd_mask_sync_250m <= ddmtd_mask_sync_62m5; -- need stringent setup constraint for this one
      ddmtd_mask_sync_250m_d <= ddmtd_mask_sync_250m;
      ddmtd_mask_sync_250m_p <= ddmtd_mask_sync_250m xor ddmtd_mask_sync_250m_d;
    end if;
  end process;

  process(clk_rx_250m)
  begin
    if falling_edge(clk_rx_250m) then
      ddmtd_mask_sync_250m_p_fedge <= ddmtd_mask_sync_250m_p;
    end if;
  end process;

  process(rx_rec_clk_sampled, tx_out_clk_sampled, lpdc_regs_out)
  begin
    case lpdc_regs_out.CTRL_dmtd_clk_sel is
      when "00" =>
        rx_rbclk_sampled_o <= rx_rec_clk_sampled;
      when "01" =>
        rx_rbclk_sampled_o <= tx_out_clk_sampled;
      when others =>
        rx_rbclk_sampled_o <= '0';
    end case;
  end process;

  tx_enc_err_o <= '0';

  inst_ref_reset_generator : entity work.gc_reset_multi_aasd
    generic map (
      g_CLOCKS  => 1,
      g_RST_LEN => 16)
    port map (
      arst_i  => rst_i,
      clks_i(0)  => clk_ref_i,
      rst_n_o(0) => rst_ref_n);

  gtx_rst_tx_a <= rst_i or not tx_rst_done;

  inst_tx_reset_generator : entity work.gc_reset_multi_aasd
    generic map (
      g_CLOCKS  => 1,
      g_RST_LEN => 16)
    port map (
      arst_i  => gtx_rst_tx_a,
      clks_i(0)  => tx_out_clk_div2,
      rst_n_o(0) => gtx_rst_n_txdiv2);

    rst_rx_path_a <= gtx_rx_reset_a or rst_i or (not rx_gearbox_pll_locked);

  inst_rx_path_reset : entity work.gc_reset_multi_aasd
    generic map (
      g_CLOCKS  => 1,
      g_RST_LEN => 16)
    port map (
      arst_i  => rst_rx_path_a,
      clks_i(0)  => clk_rx_62m5,
      rst_n_o(0) => rst_rx_62m5_n);


  tx_clk_o <= tx_out_clk_div2;
  tx_locked_o  <= cpll_locked;

  rx_rbclk_o <= clk_rx_62m5;

  U_Enc1 : entity work.gc_enc_8b10b
    generic map
    (
      g_use_internal_running_disparity => false
      )
    port map (
      clk_i       => tx_out_clk_div2,
      rst_n_i     => gtx_rst_n_txdiv2,
      in_8b_i     => tx_data_i(15 downto 8),
      dispar_i => run_disparity_reg,
      dispar_o => run_disparity_q0,
      ctrl_i      => tx_k_i(1),
      out_10b_o    => tx_data_8b10b(9 downto 0));

--  tx_data_8b10b <= "00000" & c_K28_5_PLUS & "00000";
--tx_data_8b10b <= "11011" & "1000110111" & "01110";
--  tx_data_8b10b <= "10000" & "0000110000" & "00000";

  U_Enc2 : entity work.gc_enc_8b10b
    generic map (
      g_use_internal_running_disparity => false
      )
    port map (
      clk_i       => tx_out_clk_div2,
      rst_n_i     => gtx_rst_n_txdiv2,
      dispar_i => run_disparity_q0,
      dispar_o => run_disparity_q1,
      in_8b_i     => tx_data_i(7 downto 0),
      ctrl_i      => tx_k_i(0),
      out_10b_o    => tx_data_8b10b(19 downto 10) );

  p_latch_disparity : process(tx_out_clk_div2)
  begin

    if rising_edge(tx_out_clk_div2) then
      if gtx_rst_n_txdiv2 = '0' then
        run_disparity_reg <= '0';
      else
        run_disparity_reg <= run_disparity_q1;
      end if;

    end if;
  end process;




  inst_the_gtx : entity work.whiterabbit_gtxe2_channel_wrapper_kintex7_lp
    generic map
    (
       -- Simulation attributes
       GT_SIM_GTRESET_SPEEDUP    =>  "TRUE"        -- Set to "true" to speed up sim reset
    )
    port map
    (
		--------------------------------- CPLL Ports -------------------------------
		CPLLFBCLKLOST_OUT          => open,
		CPLLLOCK_OUT               => cpll_locked,
		CPLLLOCKDETCLK_IN          => '0',
		CPLLREFCLKLOST_OUT         => open,
		CPLLRESET_IN               => cpll_reset,
		-------------------------- Channel - Clocking Ports ------------------------
		GTREFCLK0_IN               => clk_gtx_i,
		---------------------------- Channel - DRP Ports  --------------------------
		DRPADDR_IN                 => drp_addr,
		DRPCLK_IN                  => clk_sys_i,
		DRPDI_IN                   => drp_din,
		DRPDO_OUT                  => drp_dout,
		DRPEN_IN                   => drp_en,
		DRPRDY_OUT                 => drp_rdy,
		DRPWE_IN                   => drp_we,
		------------------------------- Clocking Ports -----------------------------
		--QPLLCLK_IN                 => qpll_clk_i,
		--QPLLREFCLK_IN              => qpll_ref_clk_i,
		------------------------------- Loopback Ports -----------------------------
		LOOPBACK_IN                => gtx_loopback,
		--------------------- RX Initialization and Reset Ports --------------------
--		RXUSERRDY_IN               => rx_cdr_lock,
		RXUSERRDY_IN               => '1', --rx_cdr_lock_filtered,
		-------------------------- RX Margin Analysis Ports ------------------------
		EYESCANDATAERROR_OUT       => open,
		------------------------- Receive Ports - CDR Ports ------------------------
		RXCDRLOCK_OUT              => rx_cdr_lock,
                RXRATE_IN => rx_rate,
		RXCDRRESET_IN              => '0',   -- this port cannot be generated by the CoreGen GUI, it cannot be turnes "on"                           : in   std_logic;
		------------------ Receive Ports - FPGA RX Interface Ports -----------------
		RXUSRCLK_IN                => clk_rx_250m,
		RXUSRCLK2_IN               => clk_rx_250m,
		------------------ Receive Ports - FPGA RX interface Ports -----------------
		RXDATA_OUT                 => rx_data_raw_250m,
		--------------------------- Receive Ports - RX AFE -------------------------
		GTXRXP_IN                  => pad_rxp_i,
		------------------------ Receive Ports - RX AFE Ports ----------------------
		GTXRXN_IN                  => pad_rxn_i,
		--------------------- Receive Ports - RX Equilizer Ports -------------------
		RXLPMHFHOLD_IN             => '0',          -- this port is always generated by the CoreGen GUI and cannot be turned "off"
		RXLPMLFHOLD_IN             => '0',          -- this port is always generated by the CoreGen GUI and cannot be turned "off"
		--------------- Receive Ports - RX Fabric Output Control Ports -------------
		RXOUTCLK_OUT               => clk_rx_250m_bufin,
		------------- Receive Ports - RX Initialization and Reset Ports ------------
		GTRXRESET_IN               => gtx_rx_reset_a,
		RXPMARESET_IN              => '0',
		-------------- Receive Ports -RX Initialization and Reset Ports ------------
		RXRESETDONE_OUT            => rx_rst_done,
		--------------------- TX Initialization and Reset Ports --------------------
		GTTXRESET_IN               => gtx_tx_reset_a,
		TXUSERRDY_IN               => cpll_locked,
		------------------ Transmit Ports - FPGA TX Interface Ports ----------------
		TXUSRCLK_IN                => tx_out_clk,
		TXUSRCLK2_IN               => tx_out_clk,
		------------------ Transmit Ports - TX Data Path interface -----------------
		TXDATA_IN                  => f_widen(tx_data_8b10b, 1),
		---------------- Transmit Ports - TX Driver and OOB signaling --------------
		GTXTXN_OUT                 => pad_txn_o,
		GTXTXP_OUT                 => pad_txp_o,
		----------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
		TXOUTCLK_OUT               => tx_out_clk_bufin,
		TXOUTCLKFABRIC_OUT         => open,
		TXOUTCLKPCS_OUT            => open,
		--------------------- Transmit Ports - TX Gearbox Ports --------------------
		TXRESETDONE_OUT            => tx_rst_done,
                ------------------ Transmit Ports - pattern Generator Ports ----------------
                TXPRBSSEL_IN               => "000" --tx_prbs_sel_i
                );

  p_translate_wb_xdrp : process(clk_sys_i)
  begin
    if rising_edge(clk_sys_i) then
      if (rst_sys_n_i = '0') then
        drp_en <= '0';
        drp_we <= '0';
        drp_regs_in.ack <= '0';
        drp_regs_in.stall <= '0';
        drp_regs_in.err <= '0';
        drp_regs_in.rty <= '0';
        drp_in_progress <= '0';
      else
        if drp_in_progress = '0' then
          if(drp_regs_out.cyc = '1' and drp_regs_out.stb = '1' and drp_regs_in.ack = '0') then
            drp_en <= '1';
            drp_we <= drp_regs_out.we;
            drp_addr <= drp_regs_out.adr(10 downto 2);
            drp_din <= drp_regs_out.dat(15 downto 0);
            drp_in_progress <= '1';
            drp_regs_in.stall <= '1';
          else
            drp_regs_in.ack <= '0';
            drp_regs_in.stall <= '0';
          end if;
        else
          drp_en <= '0';
          drp_we <= '0';

          if drp_rdy = '1' then
            drp_in_progress <= '0';
            drp_regs_in.dat(15 downto 0) <= drp_dout;
            drp_regs_in.ack <= '1';
          end if;
        end if;
      end if;
    end if;
  end process;


  txusrpll_locked <= '1';

  tx_out_clk_div2 <= tx_out_clk;

  U_BUF_TxOutClk : BUFG
    port map (
      I => tx_out_clk_bufin,
      O => tx_out_clk);




  txpll_lockdet    <= cpll_locked;
  rxpll_lockdet    <= rx_cdr_lock_filtered;
  rst_done         <= rx_rst_done and tx_rst_done;
  rst_done_n       <= not rst_done;
  everything_ready <= rst_done and txpll_lockdet and rxpll_lockdet;
  rdy_o            <= everything_ready;


  -- 2013 August 19: Peterj
  -- The family 7 GTX seem to have an artifact in rx_cdr_lock. For no reason lock may be lost for a clock cycle
  -- There is not much information on the web but examples of "Series-7 Integrated Block for PCI Express" (pipe_user.v)
  -- show that Xilinx itself implements a small delay before an rx_cdr_lock is propagated.
  p_rx_cdr_lock_filter : process(clk_rx_62m5, rst_ref_n)
    variable rxcdrlock_cnt      : integer range 0 to c_rxcdrlock_max;
  begin
    if(rst_ref_n = '0') then
      rxcdrlock_cnt := 0;
      rx_cdr_lock_filtered <= '0';
    elsif rising_edge(clk_rx_62m5) then
      if rx_cdr_lock = '0' then
        if rxcdrlock_cnt /= c_rxcdrlock_max then
          rxcdrlock_cnt := rxcdrlock_cnt + 1;
        else
          rx_cdr_lock_filtered <= '0';
        end if;
      else
        rxcdrlock_cnt := 0;
        rx_cdr_lock_filtered <= '1';
      end if;
    end if;
  end process;

  inst_sync_idle_latch_pulse : entity work.gc_pulse_synchronizer
    port map (
      clk_in_i  => clk_sys_i,
      clk_out_i => clk_rx_62m5,
      rst_n_i   => rst_sys_n_i,
      d_p_i     => lpdc_regs_out.CTRL2_rx_latch_pattern,
      q_p_o     => rx_pat_latch_p1_rx_62m5);


  inst_idle_detect : entity work.gtx_idle_detect_kintex7_lp
    port map (
      rst_rx_n_i      => rst_rx_62m5_n,
      clk_rx_62m5_i   => clk_rx_62m5,
      clk_rx_250m_i   => clk_rx_250m,
      rx_data_raw_i   => rx_data_raw_250m(39 downto 0),
      rx_data_raw_62m5_o  => rx_data_raw_62m5,
      early_link_up_o => link_up,
      pat_latch_i     => rx_pat_latch_p1_rx_62m5,
      pat_value_o     => rx_pat_value);

  lpdc_regs_in.IDLE_PAT_0_data(15 downto 0) <= rx_pat_value(16*1-1 downto 16*0);
  lpdc_regs_in.IDLE_PAT_1_data(15 downto 0) <= rx_pat_value(16*2-1 downto 16*1);
  lpdc_regs_in.IDLE_PAT_2_data(15 downto 0) <= rx_pat_value(16*3-1 downto 16*2);
  lpdc_regs_in.IDLE_PAT_3_data(15 downto 0) <= rx_pat_value(16*4-1 downto 16*3);
  lpdc_regs_in.IDLE_PAT_4_data(15 downto 0) <= rx_pat_value(16*5-1 downto 16*4);
  lpdc_regs_in.IDLE_PAT_5_data(15 downto 0) <= rx_pat_value(16*6-1 downto 16*5);
  lpdc_regs_in.IDLE_PAT_6_data(15 downto 0) <= rx_pat_value(16*7-1 downto 16*6);
  lpdc_regs_in.IDLE_PAT_7_data(15 downto 0) <= rx_pat_value(16*8-1 downto 16*7);
  lpdc_regs_in.IDLE_PAT_8_data(15 downto 0) <= rx_pat_value(16*9-1 downto 16*8);
  lpdc_regs_in.IDLE_PAT_9_data(15 downto 0) <= rx_pat_value(16*10-1 downto 16*9);
  lpdc_regs_in.IDLE_PAT_10_data(15 downto 0) <= rx_pat_value(16*11-1 downto 16*10);
  lpdc_regs_in.IDLE_PAT_11_data(15 downto 0) <= rx_pat_value(16*12-1 downto 16*11);


  inst_rx_gearbox_pll : PLLE2_ADV
    generic map(
      BANDWIDTH          => ("HIGH"),
      COMPENSATION       => ("ZHOLD"),
      STARTUP_WAIT       => ("FALSE"),
      DIVCLK_DIVIDE      => (1),
      CLKFBOUT_MULT      => (4), -- 1 GHz
      CLKFBOUT_PHASE     => (0.000),
      CLKOUT0_DIVIDE     => (16),        --62.5 MHz
      CLKOUT0_PHASE      => (0.000),
      CLKOUT0_DUTY_CYCLE => (0.500),
      CLKIN1_PERIOD      => (4.000) )
    port map(

      CLKFBOUT => clk_rx_fb_pll,
      CLKOUT0  => clk_rx_62m5_bufin,
      CLKFBIN  => clk_rx_fb_pll_bufg,
      CLKIN1   => clk_rx_250m,
      CLKIN2   => '0',
      CLKINSEL => '1',
      DADDR    => (others => '0'),
      DCLK     => '0',
      DEN      => '0',
      DI       => (others => '0'),
      DWE    => '0',
      PWRDWN => '0',
      RST    => lpdc_regs_out.CTRL2_rx_gearbox_pll_reset,
      LOCKED => rx_gearbox_pll_locked
      );

  inst_bufg_rx_250m : BUFG
    port map (
      I => clk_rx_250m_bufin,
      O => clk_rx_250m);


  gen_real_bufg : if g_simulation = 0 generate

  inst_bufg_rx_62m5 : BUFG
    port map (
      I => clk_rx_62m5_bufin,
      O => clk_rx_62m5);

  end generate gen_real_bufg;

  gen_sim_bufg : if g_simulation /= 0 generate

  clk_rx_62m5 <= clk_rx_62m5_bufin after 1ns;

  end generate gen_sim_bufg;



  inst_bufg_rx_pll_fb : BUFG
    port map (
      I => clk_rx_fb_pll,
      O => clk_rx_fb_pll_bufg);

  U_Dec1 : gc_dec_8b10b
    port map (
      clk_i       => clk_rx_62m5,
      rst_n_i     => rst_rx_62m5_n,
      in_10b_i    => rx_data_raw_62m5(19 downto 10),
      ctrl_o      => rx_k_int(1),
      code_err_o  => rx_code_err(1),
      rdisp_err_o => open,
      out_8b_o    => rx_data_int(15 downto 8));

  U_Dec2 : gc_dec_8b10b
    port map (
      clk_i       => clk_rx_62m5,
      rst_n_i     => rst_rx_62m5_n,
      in_10b_i    => rx_data_raw_62m5(9 downto 0),
      ctrl_o      => rx_k_int(0),
      code_err_o  => rx_code_err(0),
      rdisp_err_o => open,
      out_8b_o    => rx_data_int(7 downto 0));

  rx_disp_err <= (others => '0');

 U_SyncQPLLLocked : gc_sync_ffs
    port map
    (
      clk_i    => clk_sys_i,
      rst_n_i  => rst_sys_n_i,
      data_i   => cpll_locked,
      synced_o => lpdc_regs_in.STAT_pll_locked
      );

  inst_sync_rx_pll_locked : gc_sync_ffs
    port map
    (
      clk_i    => clk_sys_i,
      rst_n_i  => rst_sys_n_i,
      data_i   => rx_cdr_lock_filtered,
      synced_o => lpdc_regs_in.CTRL2_rx_cdr_locked
      );

  inst_sync_rx_gearbox_pll_locked : gc_sync_ffs
    port map
    (
      clk_i    => clk_sys_i,
      rst_n_i  => rst_sys_n_i,
      data_i   => rx_gearbox_pll_locked,
      synced_o => lpdc_regs_in.CTRL2_rx_gearbox_pll_locked
      );

  U_SyncLinkUp : gc_sync_ffs
    port map
    (
      clk_i    => clk_sys_i,
      rst_n_i  => rst_sys_n_i,
      data_i   => link_up,
      synced_o => lpdc_regs_in.STAT_link_up
      );

  U_SyncLinkAligned : gc_sync_ffs
    port map
    (
      clk_i    => clk_sys_i,
      rst_n_i  => rst_sys_n_i,
      data_i   => link_aligned,
      synced_o => lpdc_regs_in.STAT_link_aligned
      );

  U_SyncTxResetDone : gc_sync_ffs
    port map
    (
      clk_i    => clk_sys_i,
      rst_n_i  => rst_sys_n_i,
      data_i   => tx_rst_done,
      synced_o => lpdc_regs_in.STAT_tx_rst_done
      );

    U_SyncRxResetDone : gc_sync_ffs
    port map
    (
      clk_i    => clk_sys_i,
      rst_n_i  => rst_sys_n_i,
      data_i   => rx_rst_done,
      synced_o => lpdc_regs_in.STAT_rx_rst_done
      );

  U_SyncTxUsrPLLLocked : gc_sync_ffs
    port map
    (
      clk_i    => clk_sys_i,
      rst_n_i  => rst_sys_n_i,
      data_i   => txusrpll_locked,
      synced_o => lpdc_regs_in.STAT_txusrpll_locked
      );


  p_gen_rx_outputs : process(clk_rx_62m5, rst_rx_62m5_n)
  begin
    if(rst_rx_62m5_n = '0') then
      rx_data_o_int    <= (others => '0');
      rx_k_o_int       <= (others => '0');
      rx_enc_err_o_int <= '0';
    elsif rising_edge(clk_rx_62m5) then
      if(rx_enable_rxclk = '1') then
        rx_data_o_int    <= rx_data_int(7 downto 0) & rx_data_int(15 downto 8);
        rx_k_o_int       <= rx_k_int(0) & rx_k_int(1);
        rx_enc_err_o_int <= rx_disp_err(0) or rx_disp_err(1) or rx_code_err(0) or rx_code_err(1);
      else
        rx_data_o_int    <= (others => '1');
        rx_k_o_int       <= (others => '1');
        rx_enc_err_o_int <= '1';
      end if;
    end if;
  end process;

  p_gen_tx_disparity : process(tx_out_clk_div2)
  begin
    if rising_edge(tx_out_clk_div2) then
      if tx_enable_txclk = '0' then
        cur_disp <= RD_MINUS;
      else
        cur_disp <= f_next_8b10b_disparity16(cur_disp, tx_k_i, tx_data_i);
      end if;
    end if;
  end process;

  tx_disparity_o <= to_std_logic(cur_disp);

  rx_data_o <= rx_data_o_int;
  rx_k_o <= rx_k_o_int;
  rx_enc_err_o <= rx_enc_err_o_int;


  rx_bitslide_o <= (others => '0');

  fmon_clk_o <= clk_rx_250m;

end rtl;
