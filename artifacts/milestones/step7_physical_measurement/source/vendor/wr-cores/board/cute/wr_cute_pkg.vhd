-------------------------------------------------------------------------------
-- Title      : WRPC Wrapper for CUTE package
-- Project    : WR PTP Core
-- URL        : http://www.ohwr.org/projects/wr-cores/wiki/Wrpc_core
-------------------------------------------------------------------------------
-- File       : wr_cute_pkg.vhd
-- Author(s)  : Hongming Li <lihm.thu@foxmail.com>
-- Company    : Tsinghua Univ. (DEP)
-- Created    : 2018-07-14
-- Last update: 2018-07-14
-- Standard   : VHDL'93
-------------------------------------------------------------------------------
-- Copyright (c) 2017 CERN
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

library work;
use work.wishbone_pkg.all;
use work.wrcore_pkg.all;
use work.wr_fabric_pkg.all;
use work.endpoint_pkg.all;
use work.wr_board_pkg.all;
use work.streamers_pkg.all;

package wr_cute_pkg is

  component xwrc_board_cute is
    generic(
      g_simulation                : integer              := 0;
      g_with_external_clock_input : boolean              := false;
      g_aux_clks                  : integer              := 0;
      g_fabric_iface              : t_board_fabric_iface := plain;
      g_streamers_op_mode         : t_streamers_op_mode  := TX_AND_RX;
      g_tx_streamer_params        : t_tx_streamer_params := c_tx_streamer_params_defaut;
      g_rx_streamer_params        : t_rx_streamer_params := c_rx_streamer_params_defaut;
      g_aux_sdb                   : t_sdb_device         := c_wrc_periph3_sdb;
      g_dpram_initf               : string               := "default_xilinx";
      g_diag_id                   : integer              := 0;
      g_diag_ver                  : integer              := 0;
      g_diag_ro_size              : integer              := 0;
      g_diag_rw_size              : integer              := 0;
      -- CUTE special
      g_cute_version              : string               := "2.2";
      g_sfp0_enable               : integer              := 1;
      g_sfp1_enable               : integer              := 0;
      g_phy_refclk_sel            : integer              := 0;
      g_multiboot_enable          : boolean              := false);
    port (
      areset_n_i          : in  std_logic;
      areset_edge_n_i     : in  std_logic := '1';
      clk_20m_vcxo_i      : in  std_logic;
      clk_125m_pllref_p_i : in  std_logic;
      clk_125m_pllref_n_i : in  std_logic;
      clk_125m_gtp0_p_i   : in  std_logic :='0';
      clk_125m_gtp0_n_i   : in  std_logic :='0';
      clk_125m_gtp1_p_i   : in  std_logic :='0';
      clk_125m_gtp1_n_i   : in  std_logic :='0';
      clk_aux_i           : in  std_logic_vector(g_aux_clks-1 downto 0) := (others => '0');
      clk_10m_ext_i       : in  std_logic                               := '0';
      pps_ext_i           : in  std_logic                               := '0';
      clk_sys_62m5_o      : out std_logic;
      clk_ref_125m_o      : out std_logic;
      clk_10m_ext_o       : out std_logic;
      rst_sys_62m5_n_o    : out std_logic;
      rst_ref_125m_n_o    : out std_logic;
      plldac_sclk_o       : out std_logic;
      plldac_din_o        : out std_logic;
      plldac_clr_n_o      : out std_logic;
      plldac_load_n_o     : out std_logic;
      plldac_sync_n_o     : out std_logic;
      sfp0_txp_o          : out std_logic;
      sfp0_txn_o          : out std_logic;
      sfp0_rxp_i          : in  std_logic := '0';
      sfp0_rxn_i          : in  std_logic := '0';
      sfp0_det_i          : in  std_logic := '0';
      sfp0_sda_i          : in  std_logic := '1';
      sfp0_sda_o          : out std_logic;
      sfp0_scl_i          : in  std_logic := '1';
      sfp0_scl_o          : out std_logic;
      sfp0_rate_select_o  : out std_logic;
      sfp0_tx_fault_i     : in  std_logic := '0';
      sfp0_tx_disable_o   : out std_logic;
      sfp0_los_i          : in  std_logic := '0';
      sfp1_txp_o          : out std_logic;
      sfp1_txn_o          : out std_logic;
      sfp1_rxp_i          : in  std_logic := '0';
      sfp1_rxn_i          : in  std_logic := '0';
      sfp1_det_i          : in  std_logic := '0';
      sfp1_sda_i          : in  std_logic := '1';
      sfp1_sda_o          : out std_logic;
      sfp1_scl_i          : in  std_logic := '1';
      sfp1_scl_o          : out std_logic;
      sfp1_rate_select_o  : out std_logic;
      sfp1_tx_fault_i     : in  std_logic := '0';
      sfp1_tx_disable_o   : out std_logic;
      sfp1_los_i          : in  std_logic := '0';
      eeprom_sda_i        : in  std_logic := '1';
      eeprom_sda_o        : out std_logic;
      eeprom_scl_i        : in  std_logic := '1';
      eeprom_scl_o        : out std_logic;
      onewire_i           : in  std_logic;
      onewire_oen_o       : out std_logic;
      uart_rxd_i          : in  std_logic;
      uart_txd_o          : out std_logic;
      flash_sclk_o        : out std_logic;
      flash_ncs_o         : out std_logic;
      flash_mosi_o        : out std_logic;
      flash_miso_i        : in  std_logic := '1';
      wb_slave_o          : out t_wishbone_slave_out;
      wb_slave_i          : in  t_wishbone_slave_in := cc_dummy_slave_in;
      aux_master_o        : out t_wishbone_master_out;
      aux_master_i        : in  t_wishbone_master_in := cc_dummy_master_in;
      wrf_src_o           : out t_wrf_source_out;
      wrf_src_i           : in  t_wrf_source_in := c_dummy_src_in;
      wrf_snk_o           : out t_wrf_sink_out;
      wrf_snk_i           : in  t_wrf_sink_in   := c_dummy_snk_in;
      wrs_tx_data_i       : in  std_logic_vector(g_tx_streamer_params.data_width-1 downto 0) := (others => '0');
      wrs_tx_valid_i      : in  std_logic                                        := '0';
      wrs_tx_dreq_o       : out std_logic;
      wrs_tx_last_i       : in  std_logic                                        := '1';
      wrs_tx_flush_i      : in  std_logic                                        := '0';
      wrs_tx_cfg_i        : in  t_tx_streamer_cfg                                := c_tx_streamer_cfg_default;
      wrs_rx_first_o      : out std_logic;
      wrs_rx_last_o       : out std_logic;
      wrs_rx_data_o       : out std_logic_vector(g_rx_streamer_params.data_width-1 downto 0);
      wrs_rx_valid_o      : out std_logic;
      wrs_rx_dreq_i       : in  std_logic                                        := '0';
      wrs_rx_cfg_i        : in t_rx_streamer_cfg                                 := c_rx_streamer_cfg_default;
      wb_eth_master_o     : out t_wishbone_master_out;
      wb_eth_master_i     : in  t_wishbone_master_in := cc_dummy_master_in;
      aux_diag_i          : in  t_generic_word_array(g_diag_ro_size-1 downto 0) := (others => (others => '0'));
      aux_diag_o          : out t_generic_word_array(g_diag_rw_size-1 downto 0);
      tm_dac_value_o       : out std_logic_vector(31 downto 0);
      tm_dac_wr_o          : out std_logic_vector(g_aux_clks-1 downto 0);
      tm_clk_aux_lock_en_i : in  std_logic_vector(g_aux_clks-1 downto 0) := (others => '0');
      tm_clk_aux_locked_o  : out std_logic_vector(g_aux_clks-1 downto 0);
      timestamps_o         : out t_txtsu_timestamp;
      timestamps_ack_i     : in  std_logic := '1';
      abscal_txts_o        : out std_logic;
      abscal_rxts_o        : out std_logic;
      fc_tx_pause_req_i    : in  std_logic                     := '0';
      fc_tx_pause_delay_i  : in  std_logic_vector(15 downto 0) := x"0000";
      fc_tx_pause_ready_o  : out std_logic;
      tm_link_up_o         : out std_logic;
      tm_time_valid_o      : out std_logic;
      tm_tai_o             : out std_logic_vector(39 downto 0);
      tm_cycles_o          : out std_logic_vector(27 downto 0);
      led_act_o            : out std_logic;
      led_link_o           : out std_logic;
      btn1_i               : in  std_logic := '1';
      btn2_i               : in  std_logic := '1';
      pps_p_o              : out std_logic;
      pps_led_o            : out std_logic;
      pps_csync_o          : out std_logic;
      link_ok_o            : out std_logic);
  end component xwrc_board_cute;

  constant c_xwb_tcpip_sdb : t_sdb_device := (
      abi_class     => x"0000",              -- undocumented device
      abi_ver_major => x"01",
      abi_ver_minor => x"01",
      wbd_endian    => c_sdb_endian_big,
      wbd_width     => x"4",                 -- 8/16/32-bit port granularity
      sdb_component => (
      addr_first  => x"0000000000000000",
      addr_last   => x"00000000000000ff",
      product     => (
      vendor_id => x"0000000000001103",  -- thu
      device_id => x"c0413599",
      version   => x"00000001",
      date      => x"20160424",
      name      => "wr-tcp-ip-stack    ")));

end wr_cute_pkg;
