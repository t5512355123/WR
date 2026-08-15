-------------------------------------------------------------------------------
-- Title      : Deterministic Xilinx GTX wrapper - kintex-7 top module
-- Project    : White Rabbit Switch
-------------------------------------------------------------------------------
-- File       : wr_gtx_phy_family7_lp.vhd
-- Author     : Peter Jansweijer, Tomasz Wlostowski
-- Company    : CERN BE-CO-HT
-- Created    : 2013-04-08
-- Last update: 2023-08-18
-- Platform   : FPGA-generic
-- Standard   : VHDL'93
-------------------------------------------------------------------------------
-- Description: Dual channel wrapper for Xilinx Kintex-7 GTX adapted for
-- deterministic delays at 1.25 Gbps.
-------------------------------------------------------------------------------
--
-- Copyright (c) 2010 CERN
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
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author    Description
-- 2013-04-08  0.1      PeterJ    Initial release based on "wr_gtx_phy_virtex6.vhd"
-- 2013-08-19  0.2      PeterJ    Implemented a small delay before a rx_cdr_lock is propgated
-- 2014-02_19  0.3      Peterj    Added tx_locked_o to indicate that the cpll reached the lock status
-- 2023-08-18  0.4      PeterJ    use WB bus for LPDC regs (resets now under software control)
-------------------------------------------------------------------------------

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

entity wr_gtx_phy_family7_lp is

  generic (
    -- set to non-zero value to speed up the simulation by reducing some delays
    g_simulation         : integer := 0
    );

  port (

    -- Dedicated reference 125 MHz clock for the GTX transceiver
    clk_gtx_i : in std_logic;

    -- DMTD clock for phase measurements (done in the PHY module as we need to
    -- multiplex between several GTX clock outputs)
    clk_dmtd_i : in std_logic;

    -- Reference 125 MHz clock input for the TX/RX deterministic phase logic (not the GTX itself)
    clk_ref_i : in std_logic;
    
    -- systemc clock for MDIO registers
    clk_sys_i            : in std_logic;
    rst_sys_n_i          : in std_logic;

    -- TX path, synchronous to tx_out_clk_o (125 MHz):
    tx_out_clk_o : out std_logic;
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

    clk_sampled_o : out std_logic;

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

    -- reset input, active hi
    rst_i : in std_logic;
    loopen_i : in std_logic;
    tx_prbs_sel_i : in std_logic_vector(2 downto 0);

    pad_txn_o : out std_logic;
    pad_txp_o : out std_logic;

    pad_rxn_i : in std_logic := '0';
    pad_rxp_i : in std_logic := '0';

    rdy_o : out std_logic;

    mdio_slave_i         : in  t_wishbone_slave_in;
    mdio_slave_o         : out t_wishbone_slave_out;

    fmon_clk_tx_o : out std_logic;
    fmon_clk_tx2_o : out std_logic;
    fmon_clk_rx_o : out std_logic
    );
end wr_gtx_phy_family7_lp;

architecture rtl of wr_gtx_phy_family7_lp is

  component dmtd_sampler is
    generic (
      g_divide_input_by_2 : boolean;
      g_reverse           : boolean);
    port (
      clk_in_i      : in  std_logic;
      clk_dmtd_i    : in  std_logic;
      clk_sampled_o : out std_logic);
  end component dmtd_sampler;
  
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

  component gtx_comma_detect_lp is
    generic (
      g_ID : integer);
    port (
      clk_rx_i            : in  std_logic;
      rst_i               : in  std_logic;
      rx_data_raw_i       : in  std_logic_vector(19 downto 0);
      rx_data_raw_o       : out std_logic_vector(19 downto 0);
      comma_target_pos_i  : in  std_logic_vector(4 downto 0);
      comma_current_pos_o : out std_logic_vector(4 downto 0);
      comma_pos_valid_o   : out std_logic;
      link_up_o           : out std_logic;
      aligned_o           : out std_logic);
  end component gtx_comma_detect_lp;
  
  signal rst_n                         : std_logic;

  signal tx_out_clk                    : std_logic;
  signal tx_out_clk_sampled            : std_logic;
  signal rx_rec_clk                    : std_logic;
  signal rx_rec_clk_sampled            : std_logic;
  signal rx_rec_clk_bufin              : std_logic;
  signal tx_out_clk_bufin              : std_logic;

  signal serdes_ready_a                : std_logic;
  signal serdes_ready_txclk            : std_logic;
  signal serdes_ready_rxclk            : std_logic;

  signal rst_txclk_n                   : std_logic;
  signal rst_rxclk_n                   : std_logic;

  signal cpll_reset_a                  : std_logic;
  signal cpll_locked                   : std_logic;

  signal tx_data_synced                : std_logic_vector(15 downto 0);
  signal tx_k_synced                   : std_logic_vector(1 downto 0);
  signal run_disparity_q0              : std_logic;
  signal run_disparity_q1              : std_logic;
  signal run_disparity_reg             : std_logic;

  signal rx_data_int                   : std_logic_vector(19 downto 0);
  signal rx_k_int                      : std_logic_vector(1 downto 0);
  
  attribute keep                       : string;
  attribute keep of rx_data_int        : signal is "true";
  attribute keep of rx_k_int           : signal is "true";

  signal cur_disp                      : t_8b10b_disparity;

  signal tx_data_8b10b                 : std_logic_vector(19 downto 0);

  signal tx_enable_txclk               : std_logic;

  signal gtx_tx_reset_a                : std_logic;
  signal gtx_rx_reset_a                : std_logic;

  signal gtx_loopback                  : std_logic_vector(2 downto 0);

  signal rx_data_raw                   : std_logic_vector(19 downto 0);
  signal rx_data_decode                : std_logic_vector(19 downto 0);
  signal rx_code_err                   : std_logic_vector(1 downto 0);

  signal tx_rst_done                   : std_logic;
  signal txusrpll_locked               : std_logic;
  signal rx_rst_done                   : std_logic;

  signal lpdc_regs_out                 : t_lpdc_regs_master_out;
  signal lpdc_regs_in                  : t_lpdc_regs_master_in;
  signal drp_regs_in                   : t_wishbone_slave_out;
  signal drp_regs_out                  : t_wishbone_slave_in;

begin

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

  -- Near-end PMA loopback if loopen_i active
  gtx_loopback <= "010" when loopen_i = '1' else "000";

  U_SyncTxReset : gc_sync_ffs
    port map
    (
      clk_i    => clk_dmtd_i,
      rst_n_i  => '1',
      data_i   => lpdc_regs_out.CTRL_tx_sw_reset,
      synced_o => gtx_tx_reset_a
      );

  U_SyncTxEnable : gc_sync_ffs
    port map
    (
      clk_i    => tx_out_clk,
      rst_n_i  => '1',
      data_i   => lpdc_regs_out.CTRL_tx_enable,
      synced_o => tx_enable_txclk
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
      synced_o => cpll_reset_a
      );

  rst_n <= not rst_i;

  U_Sampler_RX : dmtd_sampler
    generic map (
      g_divide_input_by_2 => false,
      g_reverse           => true)
    port map (
      clk_in_i      => rx_rec_clk,
      clk_dmtd_i    => clk_dmtd_i,
      clk_sampled_o => rx_rec_clk_sampled);

  U_Sampler_TX : dmtd_sampler
    generic map (
      g_divide_input_by_2 => false,
      g_reverse           => true)
    port map (
      clk_in_i      => tx_out_clk,
      clk_dmtd_i    => clk_dmtd_i,
      clk_sampled_o => tx_out_clk_sampled);

  process(rx_rec_clk_sampled, tx_out_clk_sampled, lpdc_regs_out)
  begin
    case lpdc_regs_out.CTRL_dmtd_clk_sel is
      when "00" =>
        clk_sampled_o <= rx_rec_clk_sampled;
      when "01" =>
        clk_sampled_o <= tx_out_clk_sampled;
      when others =>
        clk_sampled_o <= '0';
    end case;
  end process;

  U_SyncReset : gc_sync_ffs
    port map
    (
      clk_i    => tx_out_clk,
      rst_n_i  => '1',
      data_i   => rst_n,
      synced_o => rst_txclk_n);

  U_BUF_RxRecClk : BUFG
    port map (
      I => rx_rec_clk_bufin,
      O => rx_rec_clk);

  rx_rbclk_o <= rx_rec_clk;

  -- clk_ref_i and tx_out_clk are phase locked but can have an offset.
  -- As a safety precaustion, resynchronize clk_ref_i domain signals tx_data_i and tx_k_i
  -- into the tx_out_clk domain.
  U_SyncTxData : gc_sync_register
    generic map
    (
      g_width => 16
      )
    port map
    (
      clk_i      => tx_out_clk,
      rst_n_a_i  => rst_txclk_n,
      d_i        => tx_data_i,
      q_o        => tx_data_synced
      );

 U_SyncTxK : gc_sync_register
    generic map
    (
      g_width => 2
      )
    port map
    (
      clk_i      => tx_out_clk,
      rst_n_a_i  => rst_txclk_n,
      d_i        => tx_k_i,
      q_o        => tx_k_synced
      );

  U_Enc1 : entity work.gc_enc_8b10b
    generic map
    (
      g_use_internal_running_disparity => false
      )
    port map (
      clk_i       => tx_out_clk,
      rst_n_i     => rst_txclk_n,
      in_8b_i     => tx_data_synced(15 downto 8),
      dispar_i    => run_disparity_reg,
      dispar_o    => run_disparity_q0,
      ctrl_i      => tx_k_synced(1),
      out_10b_o   => tx_data_8b10b(9 downto 0));

  U_Enc2 : entity work.gc_enc_8b10b
    generic map (
      g_use_internal_running_disparity => false
      )
    port map (
      clk_i       => tx_out_clk,
      rst_n_i     => rst_txclk_n,
      dispar_i    => run_disparity_q0,
      dispar_o    => run_disparity_q1,
      in_8b_i     => tx_data_synced(7 downto 0),
      ctrl_i      => tx_k_synced(0),
      out_10b_o   => tx_data_8b10b(19 downto 10));

  p_latch_disparity : process(tx_out_clk)
  begin

    if rising_edge(tx_out_clk) then
      if rst_txclk_n = '0' then
        run_disparity_reg <= '0';
      else
        run_disparity_reg <= run_disparity_q1;
      end if;
      
    end if;
  end process;

  U_GTX_INST : entity work.whiterabbit_gtxe2_channel_wrapper_GT_lp
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
      CPLLRESET_IN               => cpll_reset_a,
      -------------------------- Channel - Clocking Ports ------------------------
      GTREFCLK0_IN               => clk_gtx_i,
      ---------------------------- Channel - DRP Ports  --------------------------
      DRPADDR_IN                 => (Others => '0'),
      DRPCLK_IN                  => '0',
      DRPDI_IN                   => (Others => '0'),
      DRPDO_OUT                  => open,
      DRPEN_IN                   => '0',
      DRPRDY_OUT                 => open,
      DRPWE_IN                   => '0',
      ------------------------------- Clocking Ports -----------------------------
      QPLLCLK_IN                 => '0',
      QPLLREFCLK_IN              => '0',
      ------------------------------- Loopback Ports -----------------------------
      LOOPBACK_IN                => gtx_loopback,
      --------------------- RX Initialization and Reset Ports --------------------
      RXUSERRDY_IN               => '1',
      -------------------------- RX Margin Analysis Ports ------------------------
      EYESCANDATAERROR_OUT       => open,
      ------------------------- Receive Ports - CDR Ports ------------------------
      RXCDRLOCK_OUT              => open,
      RXCDRRESET_IN              => '0',   -- this port cannot be generated by the CoreGen GUI, it cannot be turned "on"                           : in   std_logic;
      ------------------ Receive Ports - FPGA RX Interface Ports -----------------
      RXUSRCLK_IN                => rx_rec_clk,
      RXUSRCLK2_IN               => rx_rec_clk,
      ------------------ Receive Ports - FPGA RX interface Ports -----------------
      RXDATA_OUT                 => rx_data_raw,
      --------------------------- Receive Ports - RX AFE -------------------------
      GTXRXP_IN                  => pad_rxp_i,
      ------------------------ Receive Ports - RX AFE Ports ----------------------
      GTXRXN_IN                  => pad_rxn_i,
      --------------------- Receive Ports - RX Equilizer Ports -------------------
      RXLPMHFHOLD_IN             => '0',          -- this port is always generated by the CoreGen GUI and cannot be turned "off"
      RXLPMLFHOLD_IN             => '0',          -- this port is always generated by the CoreGen GUI and cannot be turned "off"
      --------------- Receive Ports - RX Fabric Output Control Ports -------------
      RXOUTCLK_OUT               => rx_rec_clk_bufin,
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
      TXDATA_IN                  => tx_data_8b10b,
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

  U_BUF_TxOutClk : BUFG
    port map (
      I => tx_out_clk_bufin,
      O => tx_out_clk);

  tx_out_clk_o <= tx_out_clk;

  serdes_ready_a <= rst_n and tx_rst_done and rx_rst_done;

  U_Sync_Serdes_RDY1 : gc_sync_ffs
    port map (
      clk_i    => rx_rec_clk,
      rst_n_i  => '1',
      data_i   => serdes_ready_a,
      synced_o => serdes_ready_rxclk);

  U_Sync_Serdes_RDY2 : gc_sync_ffs
    port map (
      clk_i    => tx_out_clk,
      rst_n_i  => '1',
      data_i   => serdes_ready_a,
      synced_o => serdes_ready_txclk);

  U_Comma_Detect : gtx_comma_detect_lp
    generic map(
      g_id => 0
      )
    port map (
      clk_rx_i            => rx_rec_clk,
      rst_i               => lpdc_regs_out.CTRL_aux_reset,
      rx_data_raw_i       => rx_data_raw,
      rx_data_raw_o       => rx_data_decode,
      comma_target_pos_i  => lpdc_regs_out.CTRL_comma_target_pos(4 downto 0),
      comma_current_pos_o => lpdc_regs_in.STAT_comma_current_pos(4 downto 0),
      comma_pos_valid_o   => lpdc_regs_in.STAT_comma_pos_valid,
      link_up_o           => lpdc_regs_in.STAT_link_up,
      aligned_o           => lpdc_regs_in.STAT_link_aligned);

  U_Sync_RxReset : gc_sync_ffs
    port map (
      clk_i    => rx_rec_clk,
      rst_n_i  => '1',
      data_i   => rst_n,
      synced_o => rst_rxclk_n);

  U_Dec1 : gc_dec_8b10b
    port map (
      clk_i       => rx_rec_clk,
      rst_n_i     => rst_rxclk_n,
      in_10b_i    => (rx_data_decode(19 downto 10)),
      ctrl_o      => rx_k_int(1),
      code_err_o  => rx_code_err(1),
      rdisp_err_o => open,
      out_8b_o    => rx_data_int(15 downto 8));

  U_Dec2 : gc_dec_8b10b
    port map (
      clk_i       => rx_rec_clk,
      rst_n_i     => rst_rxclk_n,
      in_10b_i    => (rx_data_decode(9 downto 0)),
      ctrl_o      => rx_k_int(0),
      code_err_o  => rx_code_err(0),
      rdisp_err_o => open,
      out_8b_o    => rx_data_int(7 downto 0));

  lpdc_regs_in.STAT_pll_locked  <= cpll_locked;
  lpdc_regs_in.STAT_txusrpll_locked <= '1';     -- Not used. Signal pll_locked
  lpdc_regs_in.STAT_tx_rst_done <= tx_rst_done;
  lpdc_regs_in.STAT_rx_rst_done <= rx_rst_done;
  
  p_gen_rx_outputs : process(rx_rec_clk, rst_rxclk_n)
  begin
    if(rst_rxclk_n = '0') then
      rx_data_o        <= (others => '0');
      rx_k_o           <= (others => '0');
      rx_enc_err_o     <= '0';
    elsif rising_edge(rx_rec_clk) then
      if(serdes_ready_rxclk = '1') then
        rx_data_o        <= rx_data_int(7 downto 0) & rx_data_int(15 downto 8);
        rx_k_o           <= rx_k_int(0) & rx_k_int(1);
        rx_enc_err_o     <= rx_code_err(0) or rx_code_err(1);
      else
        rx_data_o        <= (others => '1');
        rx_k_o           <= (others => '1');
        rx_enc_err_o     <= '1';
      end if;
    end if;
  end process;

  p_gen_tx_disparity : process(tx_out_clk)
  begin
    if rising_edge(tx_out_clk) then
      -- synchronously enable calculation of tuning disparity
      if tx_enable_txclk = '0' then
        cur_disp <= RD_MINUS;
      else
        cur_disp <= f_next_8b10b_disparity16(cur_disp, tx_k_synced, tx_data_synced);
      end if;
    end if;
  end process;

  tx_disparity_o <= to_std_logic(cur_disp);

  fmon_clk_tx_o <= tx_out_clk;
  fmon_clk_tx2_o <= tx_out_clk;
  fmon_clk_rx_o <= rx_rec_clk;

  rx_bitslide_o <= (others => '0');

  rdy_o        <= serdes_ready_rxclk;
  tx_locked_o  <= cpll_locked;
  tx_enc_err_o <= '0';

end rtl;
