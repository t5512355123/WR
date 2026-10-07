-------------------------------------------------------------------------------
-- Title      : Deterministic Xilinx GTHE4X wrapper - UltraScale+ top module
-- Project    : White Rabbit Switch
-------------------------------------------------------------------------------
-- File       : wr_gthe4_phy_family7_lp.vhd
-- Author     : Peter Jansweijer, Tomasz Wlostowski
-- Company    : CERN BE-CO-HT
-- Created    : 2013-04-08
-- Last update: 2023-06-06
-- Platform   : FPGA-generic
-- Standard   : VHDL'93
-------------------------------------------------------------------------------
-- Description: Wrapper for Xilinx UltraScale+ GTH adapted for
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
-- 2013-04-08  0.1      PeterJ    Initial release based on "wr_gtx_phy_virtex6.vhd" and "wr_gtx_phy_family7_lp.vhd"
-- 2013-06-06  0.2      PeterJ    use WB bus for LPDC regs
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

use work.gencores_pkg.all;
use work.disparity_gen_pkg.all;
use work.wishbone_pkg.all;
use work.lpdc_mdio_regs_pkg.all;

entity wr_gthe4_phy_family7_lp is

  generic (
    -- set to non-zero value to speed up the simulation by reducing some delays
    g_simulation         : integer := 0;
    g_use_gclk_as_refclk : boolean);

  port (
    -- Dedicated reference 125 MHz clock for the GTH transceiver
    clk_gth_i            : in std_logic;

    -- DMTD clock for phase measurements (done in the PHY module as we need to
    -- multiplex between several GTH clock outputs)
    -- Note: DMTD clock is also used as free running clock
    clk_dmtd_i           : in std_logic;

    -- systemc clock for MDIO registers
    clk_sys_i            : in std_logic;
    rst_sys_n_i          : in std_logic;

    -- TX path, synchronous to tx_out_clk_o (62.5 MHz):
    tx_out_clk_o         : out std_logic;
    tx_locked_o          : out std_logic;

    -- data input (8 bits, not 8b10b-encoded)
    tx_data_i            : in std_logic_vector(15 downto 0);

    -- 1 when tx_data_i contains a control code, 0 when it's a data byte
    tx_k_i               : in std_logic_vector(1 downto 0);

    -- disparity of the currently transmitted 8b10b code (1 = plus, 0 = minus).
    -- Necessary for the PCS to generate proper frame termination sequences.
    -- Generated for the 2nd byte (LSB) of tx_data_i.
    tx_disparity_o       : out std_logic;

    -- Encoding error indication (1 = error, 0 = no error)
    tx_enc_err_o         : out std_logic;

    -- RX path, synchronous to ch0_rx_rbclk_o.

    -- RX recovered clock
    rx_rbclk_o           : out std_logic;

    clk_sampled_o        : out std_logic;
    
    -- 8b10b-decoded data output. The data output must be kept invalid before
    -- the transceiver is locked on the incoming signal to prevent the EP from
    -- detecting a false carrier.
    rx_data_o            : out std_logic_vector(15 downto 0);

    -- 1 when the byte on rx_data_o is a control code
    rx_k_o               : out std_logic_vector(1 downto 0);

    -- encoding error indication
    rx_enc_err_o         : out std_logic;

    -- RX bitslide indication, indicating the delay of the RX path of the
    -- transceiver (in UIs). Must be valid when ch0_rx_data_o is valid.
    -- In this "low-phase-drift" implementaion rx alignment is fixed by
    -- throwing the dice until it is on "comma_target_pos".
    -- rx_bitslide is not used and set to zero.
    rx_bitslide_o        : out std_logic_vector(4 downto 0);

    -- reset input, active hi
    rst_i                : in std_logic;
    loopen_i             : in std_logic;
    tx_prbs_sel_i        : in std_logic_vector(2 downto 0);
    
    pad_txn_o            : out std_logic;
    pad_txp_o            : out std_logic;

    pad_rxn_i            : in std_logic := '0';
    pad_rxp_i            : in std_logic := '0';

    rdy_o                : out std_logic;

    mdio_slave_i         : in  t_wishbone_slave_in;
    mdio_slave_o         : out t_wishbone_slave_out
    );
end wr_gthe4_phy_family7_lp;

architecture rtl of wr_gthe4_phy_family7_lp is

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

  component gtwizard_ultrascale_2 is
    port (
      gtwiz_userclk_tx_reset_in            : in   std_logic;
      gtwiz_userclk_tx_srcclk_out          : out  std_logic;
      gtwiz_userclk_tx_usrclk_out          : out  std_logic;
      gtwiz_userclk_tx_usrclk2_out         : out  std_logic;
      gtwiz_userclk_tx_active_out          : out  std_logic;
      gtwiz_userclk_rx_reset_in            : in   std_logic;
      gtwiz_userclk_rx_srcclk_out          : out  std_logic;
      gtwiz_userclk_rx_usrclk_out          : out  std_logic;
      gtwiz_userclk_rx_usrclk2_out         : out  std_logic;
      gtwiz_userclk_rx_active_out          : out  std_logic;
      gtwiz_buffbypass_tx_reset_in         : in   std_logic;
      gtwiz_buffbypass_tx_start_user_in    : in   std_logic;
      gtwiz_buffbypass_tx_done_out         : out  std_logic;
      gtwiz_buffbypass_tx_error_out        : out  std_logic;
      gtwiz_buffbypass_rx_reset_in         : in   std_logic;
      gtwiz_buffbypass_rx_start_user_in    : in   std_logic;
      gtwiz_buffbypass_rx_done_out         : out  std_logic;
      gtwiz_buffbypass_rx_error_out        : out  std_logic;
      gtwiz_reset_clk_freerun_in           : in   std_logic;
      gtwiz_reset_all_in                   : in   std_logic;
      gtwiz_reset_tx_pll_and_datapath_in   : in   std_logic;
      gtwiz_reset_tx_datapath_in           : in   std_logic;
      gtwiz_reset_rx_pll_and_datapath_in   : in   std_logic;
      gtwiz_reset_rx_datapath_in           : in   std_logic;
      gtwiz_reset_rx_cdr_stable_out        : out  std_logic;
      gtwiz_reset_tx_done_out              : out  std_logic;
      gtwiz_reset_rx_done_out              : out  std_logic;
      gtwiz_userdata_tx_in                 : in   std_logic_vector(19 downto 0);
      gtwiz_userdata_rx_out                : out  std_logic_vector(19 downto 0);
      cpllrefclksel_in                     : in   std_logic_vector(2 downto 0);
      drpaddr_in                           : in   std_logic_vector(9 downto 0);
      drpclk_in                            : in   std_logic;
      drpdi_in                             : in   std_logic_vector(15 downto 0);
      drpen_in                             : in   std_logic;
      drpwe_in                             : in   std_logic;
      eyescanreset_in                      : in   std_logic;
      gthrxn_in                            : in   std_logic;
      gthrxp_in                            : in   std_logic;
      gtrefclk0_in                         : in   std_logic;
      loopback_in                          : in   std_logic_vector(2 downto 0);
      rxlpmen_in                           : in   std_logic;
      rxrate_in                            : in   std_logic_vector(2 downto 0);
      rxslide_in                           : in   std_logic;
      txdiffctrl_in                        : in   std_logic_vector(4 downto 0);
      txpostcursor_in                      : in   std_logic_vector(4 downto 0);
      txprecursor_in                       : in   std_logic_vector(4 downto 0);
      drpdo_out                            : out  std_logic_vector(15 downto 0);
      drprdy_out                           : out  std_logic;
      gthtxn_out                           : out  std_logic;
      gthtxp_out                           : out  std_logic;
      gtpowergood_out                      : out  std_logic;
      rxpmaresetdone_out                   : out  std_logic;
      rxresetdone_out                      : out  std_logic;
      txpmaresetdone_out                   : out  std_logic;
      txprgdivresetdone_out                : out  std_logic;
      txresetdone_out                      : out  std_logic);
  end component gtwizard_ultrascale_2;

  signal rst_n                         : std_logic;

  signal tx_out_clk                    : std_logic;
  signal tx_out_clk_sampled            : std_logic;
  signal rx_rec_clk                    : std_logic;
  signal rx_rec_clk_sampled            : std_logic;

  signal serdes_ready_a                : std_logic;
  signal serdes_ready_txclk            : std_logic;
  signal serdes_ready_rxclk            : std_logic;

  signal rst_txclk_n                   : std_logic;
  signal rst_rxclk_n                   : std_logic;
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

  signal tx_enable_txclk    : std_logic;

  signal gth_tx_reset_a     : std_logic;
  signal gth_rx_reset_a     : std_logic;
  
  signal gth_loopback       : std_logic_vector(2 downto 0) := "000";
  signal rx_data_raw        : std_logic_vector(19 downto 0);
  signal rx_data_decode     : std_logic_vector(19 downto 0);
  signal rx_code_err        : std_logic_vector(1 downto 0);

  signal tx_rst_done        : std_logic;
  signal txusrpll_locked    : std_logic;
  signal rx_rst_done        : std_logic;

  signal lpdc_regs_out      : t_lpdc_regs_master_out;
  signal lpdc_regs_in       : t_lpdc_regs_master_in;
  signal drp_regs_in        : t_wishbone_slave_out;
  signal drp_regs_out       : t_wishbone_slave_in;

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
  gth_loopback <= "010" when loopen_i = '1' else "000";

  U_SyncTxReset : gc_sync_ffs
    port map
    (
      clk_i    => clk_dmtd_i,
      rst_n_i  => '1',
      data_i   => lpdc_regs_out.CTRL_tx_sw_reset,
      synced_o => gth_tx_reset_a
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
      synced_o => gth_rx_reset_a
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

  rx_rbclk_o   <= rx_rec_clk;

  -- WR reference clock domain clk_ref and tx_out_clk are phase locked but can have an offset.
  -- As a safety precaustion, resynchronize clk_ref domain signals tx_data_i and tx_k_i
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

  U_gtwizard_gthe4 : gtwizard_ultrascale_2
    port map (
      gtwiz_userclk_tx_reset_in            => '0',
      gtwiz_userclk_tx_srcclk_out          => open,
      gtwiz_userclk_tx_usrclk_out          => open,
      gtwiz_userclk_tx_usrclk2_out         => tx_out_clk,
      gtwiz_userclk_tx_active_out          => open,
      gtwiz_userclk_rx_reset_in            => '0',
      gtwiz_userclk_rx_srcclk_out          => open,
      gtwiz_userclk_rx_usrclk_out          => open,
      gtwiz_userclk_rx_usrclk2_out         => rx_rec_clk,
      gtwiz_userclk_rx_active_out          => open,
      gtwiz_buffbypass_tx_reset_in         => '0',
      gtwiz_buffbypass_tx_start_user_in    => '0',
      gtwiz_buffbypass_tx_done_out         => open,
      gtwiz_buffbypass_tx_error_out        => open,
      gtwiz_buffbypass_rx_reset_in         => '0',
      gtwiz_buffbypass_rx_start_user_in    => '0',
      gtwiz_buffbypass_rx_done_out         => open,
      gtwiz_buffbypass_rx_error_out        => open,
      gtwiz_reset_clk_freerun_in           => clk_dmtd_i,
      gtwiz_reset_all_in                   => gth_tx_reset_a,
      gtwiz_reset_tx_pll_and_datapath_in   => '0',
      gtwiz_reset_tx_datapath_in           => '0',
      gtwiz_reset_rx_pll_and_datapath_in   => '0',
      gtwiz_reset_rx_datapath_in           => gth_rx_reset_a,
      gtwiz_reset_rx_cdr_stable_out        => open,
      gtwiz_reset_tx_done_out              => open,
      gtwiz_reset_rx_done_out              => open,
      gtwiz_userdata_tx_in                 => tx_data_8b10b,
      gtwiz_userdata_rx_out                => rx_data_raw,
      cpllrefclksel_in                     => "001",           -- select GTREFCLK0
      drpaddr_in                           => (others => '0'),
      drpclk_in                            => clk_dmtd_i,
      drpdi_in                             => (others => '0'),
      drpen_in                             => '0',
      drpwe_in                             => '0',
      eyescanreset_in                      => '0',
      gthrxn_in                            => pad_rxn_i,
      gthrxp_in                            => pad_rxp_i,
      gtrefclk0_in                         => clk_gth_i,
      loopback_in                          => gth_loopback,
      rxlpmen_in                           => '1',
      rxrate_in                            => "000",
      rxslide_in                           => '0',
      txdiffctrl_in                        => "11000",
      txpostcursor_in                      => "00000",
      txprecursor_in                       => "00000",
      drpdo_out                            => open,
      drprdy_out                           => open,
      gthtxn_out                           => pad_txn_o,
      gthtxp_out                           => pad_txp_o,
      gtpowergood_out                      => open,
      rxpmaresetdone_out                   => open,
      rxresetdone_out                      => rx_rst_done,
      txpmaresetdone_out                   => open,
      txprgdivresetdone_out                => open,
      txresetdone_out                      => tx_rst_done
      );

  tx_out_clk_o   <= tx_out_clk;

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

  lpdc_regs_in.STAT_pll_locked  <= '1';         -- Not used. Signal pll_locked
  lpdc_regs_in.STAT_txusrpll_locked <= '1';     -- Not used. Signal pll_locked
  lpdc_regs_in.STAT_tx_rst_done <= tx_rst_done;
  lpdc_regs_in.STAT_rx_rst_done <= rx_rst_done;

  p_gen_rx_outputs : process(rx_rec_clk, rst_rxclk_n)
  begin
    if(rst_rxclk_n = '0') then
      rx_data_o    <= (others => '0');
      rx_k_o       <= (others => '0');
      rx_enc_err_o <= '0';
    elsif rising_edge(rx_rec_clk) then
      if(serdes_ready_rxclk = '1') then
        rx_data_o    <= rx_data_int(7 downto 0) & rx_data_int(15 downto 8);
        rx_k_o       <= rx_k_int(0) & rx_k_int(1);
        rx_enc_err_o <= rx_code_err(0) or rx_code_err(1);
      else
        rx_data_o    <= (others => '1');
        rx_k_o       <= (others => '1');
        rx_enc_err_o <= '1';
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

  rx_bitslide_o <= (others => '0');

  rdy_o        <= serdes_ready_rxclk;
  tx_locked_o  <= '1';
  tx_enc_err_o <= '0';

end rtl;