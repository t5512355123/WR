-------------------------------------------------------------------------------
-- Title      : WRPC Wrapper for DI/OT System Board (Xilinx ZU-7)
-- Project    : WR PTP Core
-- URL        : http://www.ohwr.org/projects/wr-cores/wiki/Wrpc_core
-------------------------------------------------------------------------------
-- File       : xwrc_board_diot_simple.vhd
-- Author(s)  : Greg Daniluk <grzegorz.daniluk@cern.ch>
-- Company    : CERN (BE-CO-HT)
-- Standard   : VHDL'93
-------------------------------------------------------------------------------
-- Description: Top-level wrapper for WR PTP core including all the modules
-- needed to operate the core on the DI/OT System Board.
-- https://ohwr.org/project/diot-sb-zu
-------------------------------------------------------------------------------
-- Copyright (c) 2021 CERN
-------------------------------------------------------------------------------
-- GNU LESSER GENERAL PUBLIC LICENSE
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
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.gencores_pkg.all;
use work.wrcore_pkg.all;
use work.wishbone_pkg.all;
use work.wr_fabric_pkg.all;
use work.endpoint_pkg.all;
use work.streamers_pkg.all;
use work.wr_xilinx_pkg.all;
use work.wr_board_pkg.all;

entity wrc_board_diot_simple is
  generic (
    g_simulation                : integer              := 0);
  port (
    areset_n_i          : in  std_logic;
    emio_i  : in std_logic_vector(2 downto 0);
    -- Clock inputs from the board
    wr_clk_helper_62_5m_p_i : in  std_logic;
    wr_clk_helper_62_5m_n_i : in  std_logic;
    wr_clk_main_62_5m_p_i   : in  std_logic;
    wr_clk_main_62_5m_n_i   : in  std_logic;
    wr_clk_sfp_125m_p_i    : in  std_logic;
    wr_clk_sfp_125m_n_i    : in  std_logic;

    -- 62.5MHz sys clock output
    --clk_sys_62m5_o      : out std_logic;
    ---- 125MHz ref clock output
    --clk_ref_125m_o      : out std_logic;
    ---- active low reset outputs, synchronous to 62m5 and 125m clocks
    --rst_sys_62m5_n_o    : out std_logic;
    --rst_ref_125m_n_o    : out std_logic;

    plldac_sclk_o   : out std_logic;
    plldac_din_o    : out std_logic;
    pll25dac_cs_n_o : out std_logic;
    pll20dac_cs_n_o : out std_logic;

    eeprom_sda_i    : in  std_logic;
    eeprom_sda_o    : out std_logic;
    eeprom_scl_i    : in  std_logic;
    eeprom_scl_o    : out std_logic;

    board_sda_i   : in  std_logic;
    board_sda_t_o : out std_logic;
    board_sda_o   : out std_logic;
    board_scl_i   : in  std_logic;
    board_scl_t_o : out std_logic;
    board_scl_o   : out std_logic;

    sfp_txp_o         : out std_logic;
    sfp_txn_o         : out std_logic;
    sfp_rxp_i         : in  std_logic;
    sfp_rxn_i         : in  std_logic;
    sfp_los_i         : in  std_logic := '0';
    sfp_det_i         : in  std_logic;

    uart_rxd_i : in  std_logic;
    uart_txd_o : out std_logic;
  
    led_act_o  : out std_logic;
    led_link_o : out std_logic;
    -- 1PPS output
    pps_p_o    : out std_logic;
    pps_led_o  : out std_logic;

    ps_scl_i   : in std_logic;
    ps_scl_t_i : in std_logic;
    ps_scl_o   : out std_logic;
    ps_sda_i   : in std_logic;
    ps_sda_t_i : in std_logic;
    ps_sda_o   : out std_logic

  );
end entity wrc_board_diot_simple;

architecture struct of wrc_board_diot_simple is

  signal wrc_sfp_sda_out, wrc_sfp_sda_in : std_logic;
  signal wrc_sfp_scl_out, wrc_sfp_scl_in : std_logic;

  signal rst_n : std_logic;

  signal cnt : unsigned(31 downto 0);
  signal rst_ref : std_logic;
  signal pps_led : std_logic;

  -- PLLs, clocks
  signal clk_62_5m_pllref_buf : std_logic;
  signal clk_62_5m_dmtd_buf   : std_logic;
  signal clk_pll_62m5        : std_logic;
  signal clk_pll_125m        : std_logic;
  signal clk_pll_dmtd        : std_logic;
  signal pll_locked          : std_logic;

  -- Reset logic
  signal rst_62m5_n         : std_logic;
  signal rstlogic_arst      : std_logic;
  signal rstlogic_clk_in    : std_logic_vector(1 downto 0);
  signal rstlogic_rst_out   : std_logic_vector(1 downto 0);

  -- PLL DAC ARB
  signal dac_hpll_load_p1 : std_logic;
  signal dac_hpll_data    : std_logic_vector(15 downto 0);
  signal dac_dpll_load_p1 : std_logic;
  signal dac_dpll_data    : std_logic_vector(15 downto 0);

  -- PHY
  signal phy16_to_wrc   : t_phy_16bits_to_wrc;
  signal phy16_from_wrc : t_phy_16bits_from_wrc;

begin

  board_sda_o   <= ps_sda_i and wrc_sfp_sda_out;
  board_sda_t_o <= '1' when (ps_sda_t_i = '1' and wrc_sfp_sda_out = '1') else
                   '0';
  ps_sda_o      <= board_sda_i;
  wrc_sfp_sda_in<= board_sda_i;
  board_scl_o   <= ps_scl_i and wrc_sfp_scl_out;
  board_scl_t_o <= '1' when (ps_scl_t_i = '1' and wrc_sfp_scl_out = '1') else
                   '0';
  ps_scl_o      <= board_scl_i;
  wrc_sfp_scl_in<= board_scl_i;

  rst_n <= areset_n_i and emio_i(0);
  pps_led_o <= pps_led; --emio_i(2);

  -----------------------------------------------------------------------------
  -- Platform-dependent part (PHY, PLLs, buffers, etc)
  -----------------------------------------------------------------------------

  cmp_ibufgds_pllmain : IBUFDS
    port map (
      O  => clk_62_5m_pllref_buf,
      I  => wr_clk_main_62_5m_p_i,
      IB => wr_clk_main_62_5m_n_i);

  cmp_ibufgds_dmtd : IBUFDS
    port map (
      O  => clk_62_5m_dmtd_buf,
      I  => wr_clk_helper_62_5m_p_i,
      IB => wr_clk_helper_62_5m_n_i);

  cmp_xwrc_platform : xwrc_platform_xilinx
    generic map (
      g_fpga_family               => "zynqus_epll",
      g_with_external_clock_input => FALSE,
      g_use_default_plls          => TRUE,
      g_simulation                => g_simulation)
    port map (
      areset_n_i            => rst_n,
      clk_125m_pllref_i     => clk_62_5m_pllref_buf,
      clk_125m_gtp_p_i      => wr_clk_sfp_125m_p_i,
      clk_125m_gtp_n_i      => wr_clk_sfp_125m_n_i,
      clk_125m_dmtd_i       => clk_62_5m_dmtd_buf,
      sfp_txn_o             => sfp_txn_o,
      sfp_txp_o             => sfp_txp_o,
      sfp_rxn_i             => sfp_rxn_i,
      sfp_rxp_i             => sfp_rxp_i,
      sfp_tx_fault_i        => '0', --sfp_tx_fault_i,
      sfp_los_i             => sfp_los_i,
      sfp_tx_disable_o      => open, --sfp_tx_disable_o,
      clk_62m5_sys_o        => clk_pll_62m5,
      clk_125m_ref_o        => clk_pll_125m,
      clk_62m5_dmtd_o       => clk_pll_dmtd,
      pll_locked_o          => pll_locked,
      phy16_o               => phy16_to_wrc,
      phy16_i               => phy16_from_wrc);

  --clk_ref_125m_o <= clk_pll_125m;
  --clk_sys_62m5_o <= clk_pll_62m5;

  -----------------------------------------------------------------------------
  -- Reset logic
  -----------------------------------------------------------------------------
  -- Detect when areset_edge_n_i goes high (end of reset) and use this edge to
  -- generate rstlogic_arst. This is needed to connect optional reset like PCIe
  -- reset. When baord runs standalone, we need to ignore PCIe reset being
  -- constantly low.
  --cmp_arst_edge: gc_sync_ffs
  --  generic map (
  --    g_sync_edge => "positive")
  --  port map (
  --    clk_i    => clk_pll_62m5,
  --    rst_n_i  => '1',
  --    data_i   => areset_edge_n_i,
  --    ppulse_o => areset_edge_ppulse);

  -- logic OR of all async reset sources (active high)
  rstlogic_arst <= (not pll_locked) or (not areset_n_i);

  -- concatenation of all clocks required to have synced resets
  rstlogic_clk_in(0)          <= clk_pll_62m5;
  rstlogic_clk_in(1)          <= clk_pll_125m;

  cmp_rstlogic_reset : gc_reset_multi_aasd
    generic map (
      g_CLOCKS  => 2,   -- 62.5MHz, 125MHz
      g_RST_LEN => 16)  -- 16 clock cycles
    port map (
      arst_i  => rstlogic_arst,
      clks_i  => rstlogic_clk_in,
      rst_n_o => rstlogic_rst_out);

  -- distribution of resets (already synchronized to their clock domains)
  rst_62m5_n <= rstlogic_rst_out(0);

  --rst_sys_62m5_n_o <= rst_62m5_n;
  --rst_ref_125m_n_o <= rstlogic_rst_out(1);

  -----------------------------------------------------------------------------
  -- 2x SPI DAC
  -----------------------------------------------------------------------------

  cmp_dac_arb : spec_serial_dac_arb
    generic map (
      g_invert_sclk    => FALSE,
      g_num_extra_bits => 8)
    port map (
      clk_i         => clk_pll_62m5,
      rst_n_i       => rst_62m5_n,
      val1_i        => dac_dpll_data,
      load1_i       => dac_dpll_load_p1,
      val2_i        => dac_hpll_data,
      load2_i       => dac_hpll_load_p1,
      dac_cs_n_o(0) => pll25dac_cs_n_o,
      dac_cs_n_o(1) => pll20dac_cs_n_o,
      dac_sclk_o    => plldac_sclk_o,
      dac_din_o     => plldac_din_o);

  -----------------------------------------------------------------------------
  -- The WR PTP Core
  -----------------------------------------------------------------------------

  cmp_board_common : xwrc_board_common
    generic map (
      g_simulation                => g_simulation,
      g_verbose                   => TRUE,
      g_with_external_clock_input => TRUE,
      g_board_name                => "DIOT",
      g_phys_uart                 => TRUE,
      g_virtual_uart              => FALSE,
      g_aux_clks                  => 0,
      g_ep_rxbuf_size             => 1024,
      g_tx_runt_padding           => TRUE,
      g_dpram_initf               => "/home/greg/wr/wr-cores/bin/wrpc/wrc_pxie.bram",
      g_dpram_size                => 131072/4,
      g_interface_mode            => PIPELINED,
      g_address_granularity       => BYTE,
      --g_aux_sdb                   => g_aux_sdb,
      g_softpll_enable_debugger   => TRUE,
      g_vuart_fifo_size           => 1024,
      g_pcs_16bit                 => TRUE,
      --g_diag_id                   => g_diag_id,
      --g_diag_ver                  => g_diag_ver,
      --g_diag_ro_size              => g_diag_ro_size,
      --g_diag_rw_size              => g_diag_rw_size,
      --g_streamers_op_mode         => g_streamers_op_mode,
      --g_tx_streamer_params        => g_tx_streamer_params,
      --g_rx_streamer_params        => g_rx_streamer_params,
      g_fabric_iface              => plain)
    port map (
      clk_sys_i            => clk_pll_62m5,
      clk_dmtd_i           => clk_pll_dmtd,
      clk_ref_i            => clk_pll_125m,
      rst_n_i              => rst_62m5_n,
      dac_hpll_load_p1_o   => dac_hpll_load_p1,
      dac_hpll_data_o      => dac_hpll_data,
      dac_dpll_load_p1_o   => dac_dpll_load_p1,
      dac_dpll_data_o      => dac_dpll_data,
      phy16_o              => phy16_from_wrc,
      phy16_i              => phy16_to_wrc,
      scl_o                => eeprom_scl_o,
      scl_i                => eeprom_scl_i,
      sda_o                => eeprom_sda_o,
      sda_i                => eeprom_sda_i,
      sfp_scl_o            => wrc_sfp_scl_out,
      sfp_scl_i            => wrc_sfp_scl_in,
      sfp_sda_o            => wrc_sfp_sda_out,
      sfp_sda_i            => wrc_sfp_sda_in,
      sfp_det_i            => sfp_det_i,
      uart_rxd_i           => uart_rxd_i,
      uart_txd_o           => uart_txd_o,
      --wb_slave_i           => wb_slave_i,
      --wb_slave_o           => wb_slave_o,
      --aux_master_o         => aux_master_o,
      --aux_master_i         => aux_master_i,
      --wrf_src_o            => wrf_src_o,
      --wrf_src_i            => wrf_src_i,
      --wrf_snk_o            => wrf_snk_o,
      --wrf_snk_i            => wrf_snk_i,
      -- Streamers
      --wrs_tx_data_i        => wrs_tx_data_i,
      --wrs_tx_valid_i       => wrs_tx_valid_i,
      --wrs_tx_dreq_o        => wrs_tx_dreq_o,
      --wrs_tx_last_i        => wrs_tx_last_i,
      --wrs_tx_flush_i       => wrs_tx_flush_i,
      --wrs_tx_cfg_i         => wrs_tx_cfg_i,
      --wrs_rx_first_o       => wrs_rx_first_o,
      --wrs_rx_last_o        => wrs_rx_last_o,
      --wrs_rx_data_o        => wrs_rx_data_o,
      --wrs_rx_valid_o       => wrs_rx_valid_o,
      --wrs_rx_dreq_i        => wrs_rx_dreq_i,
      --wrs_rx_cfg_i         => wrs_rx_cfg_i,
      -- Etherbone WB master
      --wb_eth_master_o      => wb_eth_master_o,
      --wb_eth_master_i      => wb_eth_master_i,
      -- Generic diagnostics i/f
      --aux_diag_i           => aux_diag_i,
      --aux_diag_o           => aux_diag_o,
      -- Aux clocks control
      --tm_dac_value_o       => tm_dac_value_o,
      --tm_dac_wr_o          => tm_dac_wr_o,
      --tm_clk_aux_lock_en_i => tm_clk_aux_lock_en_i,
      --tm_clk_aux_locked_o  => tm_clk_aux_locked_o,
      -- External Tx Timestamping i/f
      --timestamps_o         => timestamps_o,
      --timestamps_ack_i     => timestamps_ack_i,
      -- Abscal signals
      --abscal_txts_o        => abscal_txts_o,
      --abscal_rxts_o        => abscal_rxts_o,
      --tm_link_up_o         => tm_link_up_o,
      --tm_time_valid_o      => tm_time_valid_o,
      --tm_tai_o             => tm_tai_o,
      --tm_cycles_o          => tm_cycles_o,
      led_act_o            => led_act_o,
      led_link_o           => led_link_o,
      pps_p_o              => pps_p_o,
      pps_led_o            => pps_led,
      link_ok_o            => open);

end struct;
