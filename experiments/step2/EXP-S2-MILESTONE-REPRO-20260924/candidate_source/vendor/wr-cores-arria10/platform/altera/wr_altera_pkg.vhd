-------------------------------------------------------------------------------
-- Title      : Altera-specific components required by WR PTP Core package
-- Project    : WR PTP Core
-- URL        : http://www.ohwr.org/projects/wr-cores/wiki/Wrpc_core
-------------------------------------------------------------------------------
-- File       : wr_altera_pkg.vhd
-- Author(s)  : Dimitrios Lampridis  <dimitrios.lampridis@cern.ch>
-- Company    : CERN (BE-CO-HT)
-- Created    : 2016-11-21
-- Last update: 2017-04-27
-- Standard   : VHDL'93
-------------------------------------------------------------------------------
-- Copyright (c) 2016-2017 CERN
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
use work.endpoint_pkg.all;

package wr_altera_pkg is

  component xwrc_platform_altera is
    generic (
      g_fpga_family               : string  := "arria5";
      g_with_external_clock_input : boolean := FALSE;
      g_use_default_plls          : boolean := TRUE;
      g_pcs_16bit                 : boolean := FALSE);
    port (
      areset_n_i            : in  std_logic             := '1';
      clk_10m_ext_i         : in  std_logic             := '0';
      clk_20m_vcxo_i        : in  std_logic             := '0';
      clk_125m_pllref_i     : in  std_logic             := '0';
      clk_62m5_dmtd_i       : in  std_logic             := '0';
      clk_dmtd_locked_i     : in  std_logic             := '1';
      clk_62m5_sys_i        : in  std_logic             := '0';
      clk_sys_locked_i      : in  std_logic             := '1';
      clk_125m_ref_i        : in  std_logic             := '0';
      clk_125m_ext_i        : in  std_logic             := '0';
      clk_ext_locked_i      : in  std_logic             := '1';
      clk_ext_stopped_i     : in  std_logic             := '0';
      clk_ext_rst_o         : out std_logic;
      sfp_tx_o              : out std_logic;
      sfp_rx_i              : in  std_logic;
      sfp_tx_fault_i        : in  std_logic             := '0';
      sfp_los_i             : in  std_logic             := '0';
      sfp_tx_disable_o      : out std_logic;
      clk_62m5_sys_o        : out std_logic;
      clk_125m_ref_o        : out std_logic;
      clk_62m5_dmtd_o       : out std_logic;
      pll_locked_o          : out std_logic;
      clk_10m_ext_o         : out std_logic;
      phy8_o                : out t_phy_8bits_to_wrc;
      phy8_i                : in  t_phy_8bits_from_wrc  := c_dummy_phy8_from_wrc;
      phy16_o               : out t_phy_16bits_to_wrc;
      phy16_i               : in  t_phy_16bits_from_wrc := c_dummy_phy16_from_wrc;
      ext_ref_mul_o         : out std_logic;
      ext_ref_mul_locked_o  : out std_logic;
      ext_ref_mul_stopped_o : out std_logic;
      ext_ref_rst_i         : in  std_logic             := '0');
  end component xwrc_platform_altera;

  component wr_arria2_phy
    generic (
      g_tx_latch_edge : std_logic := '1';
      g_rx_latch_edge : std_logic := '0');
    port (
      clk_reconf_i   : in  std_logic;
      clk_pll_i      : in  std_logic;
      clk_cru_i      : in  std_logic;
      clk_free_i     : in  std_logic;
      rst_i          : in  std_logic;
      locked_o       : out std_logic;
      loopen_i       : in  std_logic;
      drop_link_i    : in  std_logic;
      tx_clk_i       : in  std_logic;
      tx_data_i      : in  std_logic_vector(7 downto 0);
      tx_k_i         : in  std_logic;
      tx_disparity_o : out std_logic;
      tx_enc_err_o   : out std_logic;
      rx_rbclk_o     : out std_logic;
      rx_data_o      : out std_logic_vector(7 downto 0);
      rx_k_o         : out std_logic;
      rx_enc_err_o   : out std_logic;
      rx_bitslide_o  : out std_logic_vector(3 downto 0);
      pad_txp_o      : out std_logic;
      pad_rxp_i      : in  std_logic := '0');
  end component;

  component wr_arria5_phy is
    generic (
      g_pcs_16bit : boolean := FALSE);
    port (
      clk_reconf_i   : in  std_logic;
      clk_phy_i      : in  std_logic;
      ready_o        : out std_logic;
      loopen_i       : in  std_logic;
      drop_link_i    : in  std_logic;
      tx_clk_o       : out std_logic;
      tx_data_i      : in  std_logic_vector(f_pcs_data_width(g_pcs_16bit)-1 downto 0);
      tx_k_i         : in  std_logic_vector(f_pcs_k_width(g_pcs_16bit)-1 downto 0);
      tx_disparity_o : out std_logic;
      tx_enc_err_o   : out std_logic;
      rx_rbclk_o     : out std_logic;
      rx_data_o      : out std_logic_vector(f_pcs_data_width(g_pcs_16bit)-1 downto 0);
      rx_k_o         : out std_logic_vector(f_pcs_k_width(g_pcs_16bit)-1 downto 0);
      rx_enc_err_o   : out std_logic;
      rx_bitslide_o  : out std_logic_vector(f_pcs_bts_width(g_pcs_16bit)-1 downto 0);
      pad_txp_o      : out std_logic;
      pad_rxp_i      : in  std_logic := '0');
  end component;

  component arria5_phy_reconf is
    port (
      reconfig_busy             : out std_logic;
      mgmt_clk_clk              : in  std_logic                     := '0';
      mgmt_rst_reset            : in  std_logic                     := '0';
      reconfig_mgmt_address     : in  std_logic_vector(6 downto 0)  := (others => '0');
      reconfig_mgmt_read        : in  std_logic                     := '0';
      reconfig_mgmt_readdata    : out std_logic_vector(31 downto 0);
      reconfig_mgmt_waitrequest : out std_logic;
      reconfig_mgmt_write       : in  std_logic                     := '0';
      reconfig_mgmt_writedata   : in  std_logic_vector(31 downto 0) := (others => '0');
      reconfig_to_xcvr          : out std_logic_vector(139 downto 0);
      reconfig_from_xcvr        : in  std_logic_vector(91 downto 0) := (others => '0'));
  end component;

  component arria5_phy8 is
    port (
      phy_mgmt_clk                : in  std_logic                      := '0';
      phy_mgmt_clk_reset          : in  std_logic                      := '0';
      phy_mgmt_address            : in  std_logic_vector(8 downto 0)   := (others => '0');
      phy_mgmt_read               : in  std_logic                      := '0';
      phy_mgmt_readdata           : out std_logic_vector(31 downto 0);
      phy_mgmt_waitrequest        : out std_logic;
      phy_mgmt_write              : in  std_logic                      := '0';
      phy_mgmt_writedata          : in  std_logic_vector(31 downto 0)  := (others => '0');
      tx_ready                    : out std_logic;
      rx_ready                    : out std_logic;
      pll_ref_clk                 : in  std_logic_vector(0 downto 0)   := (others => '0');
      tx_serial_data              : out std_logic_vector(0 downto 0);
      tx_bitslipboundaryselect    : in  std_logic_vector(4 downto 0)   := (others => '0');
      pll_locked                  : out std_logic_vector(0 downto 0);
      rx_serial_data              : in  std_logic_vector(0 downto 0)   := (others => '0');
      rx_runningdisp              : out std_logic_vector(0 downto 0);
      rx_disperr                  : out std_logic_vector(0 downto 0);
      rx_errdetect                : out std_logic_vector(0 downto 0);
      rx_bitslipboundaryselectout : out std_logic_vector(4 downto 0);
      tx_clkout                   : out std_logic_vector(0 downto 0);
      rx_clkout                   : out std_logic_vector(0 downto 0);
      tx_parallel_data            : in  std_logic_vector(7 downto 0)   := (others => '0');
      tx_datak                    : in  std_logic_vector(0 downto 0)   := (others => '0');
      rx_parallel_data            : out std_logic_vector(7 downto 0);
      rx_datak                    : out std_logic_vector(0 downto 0);
      reconfig_from_xcvr          : out std_logic_vector(91 downto 0);
      reconfig_to_xcvr            : in  std_logic_vector(139 downto 0) := (others => '0'));
  end component;

  component arria5_phy16 is
    port (
      phy_mgmt_clk                : in  std_logic                      := '0';
      phy_mgmt_clk_reset          : in  std_logic                      := '0';
      phy_mgmt_address            : in  std_logic_vector(8 downto 0)   := (others => '0');
      phy_mgmt_read               : in  std_logic                      := '0';
      phy_mgmt_readdata           : out std_logic_vector(31 downto 0);
      phy_mgmt_waitrequest        : out std_logic;
      phy_mgmt_write              : in  std_logic                      := '0';
      phy_mgmt_writedata          : in  std_logic_vector(31 downto 0)  := (others => '0');
      tx_ready                    : out std_logic;
      rx_ready                    : out std_logic;
      pll_ref_clk                 : in  std_logic_vector(0 downto 0)   := (others => '0');
      tx_serial_data              : out std_logic_vector(0 downto 0);
      tx_bitslipboundaryselect    : in  std_logic_vector(4 downto 0)   := (others => '0');
      pll_locked                  : out std_logic_vector(0 downto 0);
      rx_serial_data              : in  std_logic_vector(0 downto 0)   := (others => '0');
      rx_runningdisp              : out std_logic_vector(1 downto 0);
      rx_disperr                  : out std_logic_vector(1 downto 0);
      rx_errdetect                : out std_logic_vector(1 downto 0);
      rx_bitslipboundaryselectout : out std_logic_vector(4 downto 0);
      tx_clkout                   : out std_logic_vector(0 downto 0);
      rx_clkout                   : out std_logic_vector(0 downto 0);
      tx_parallel_data            : in  std_logic_vector(15 downto 0)  := (others => '0');
      tx_datak                    : in  std_logic_vector(1 downto 0)   := (others => '0');
      rx_parallel_data            : out std_logic_vector(15 downto 0);
      rx_datak                    : out std_logic_vector(1 downto 0);
      reconfig_from_xcvr          : out std_logic_vector(91 downto 0);
      reconfig_to_xcvr            : in  std_logic_vector(139 downto 0) := (others => '0'));
  end component;

  component wr_arria10_transceiver is
    generic (
      g_family          : string;
      g_use_atx_pll     : boolean := true;
      g_use_cmu_pll     : boolean := false;
      g_use_simple_wa   : boolean := false;
      g_use_det_phy     : boolean := true;
      g_use_sfp_los_rst : boolean := true;
      g_use_ext_loop    : boolean := true;
      g_use_ext_rst     : boolean := true);
    port (
      clk_ref_i              : in  std_logic := '0';
      clk_phy_i              : in  std_logic := '0';
      reconfig_write_i       : in  std_logic_vector(0 downto 0) := (others => '0');
      reconfig_read_i        : in  std_logic_vector(0 downto 0) := (others => '0');
      reconfig_address_i     : in  std_logic_vector(9 downto 0) := (others => '0');
      reconfig_writedata_i   : in  std_logic_vector(31 downto 0) := (others => '0');
      reconfig_readdata_o    : out std_logic_vector(31 downto 0);
      reconfig_waitrequest_o : out std_logic_vector(0 downto 0);
      reconfig_clk_i         : in  std_logic_vector(0 downto 0) := (others => '0');
      reconfig_reset_i       : in  std_logic_vector(0 downto 0) := (others => '0');
      ready_o                : out std_logic := '0';
      drop_link_i            : in  std_logic;
      loopen_i               : in  std_logic;
      sfp_los_i              : in  std_logic;
      tx_clk_o               : out std_logic;
      tx_data_i              : in  std_logic_vector(7 downto 0):= (others => '0');
      tx_data_k_i            : in  std_logic;
      tx_ready_o             : out std_logic := '0';
      tx_disparity_o         : out std_logic := '0';
      tx_enc_err_o           : out std_logic := '0';
      rx_clk_o               : out std_logic;
      rx_data_o              : out std_logic_vector(7 downto 0);
      rx_ready_o             : out std_logic;
      rx_data_k_o            : out std_logic;
      rx_enc_err_o           : out std_logic;
      rx_bitslide_o          : out std_logic_vector(3 downto 0);
      debug_o                : out std_logic;
      debug_i                : in  std_logic_vector(7 downto 0):= (others => '0');
      pad_txp_o              : out std_logic;
      pad_rxp_i              : in  std_logic := '0'
      );
  end component wr_arria10_transceiver;

  component wr_arria10_phy is
    port (
      rx_analogreset          : in  std_logic_vector(0 downto 0) := (others => 'X');
      rx_cal_busy             : out std_logic_vector(0 downto 0);
      rx_cdr_refclk0          : in  std_logic := 'X';
      rx_clkout               : out std_logic_vector(0 downto 0);
      rx_coreclkin            : in  std_logic_vector(0 downto 0) := (others => 'X');
      rx_digitalreset         : in  std_logic_vector(0 downto 0) := (others => 'X');
      rx_is_lockedtodata      : out std_logic_vector(0 downto 0);
      rx_is_lockedtoref       : out std_logic_vector(0 downto 0);
      rx_parallel_data        : out std_logic_vector(7 downto 0);
      rx_serial_data          : in  std_logic_vector(0 downto 0) := (others => 'X');
      tx_analogreset          : in  std_logic_vector(0 downto 0) := (others => 'X');
      tx_cal_busy             : out std_logic_vector(0 downto 0);
      tx_clkout               : out std_logic_vector(0 downto 0);
      tx_coreclkin            : in  std_logic_vector(0 downto 0) := (others => 'X');
      tx_digitalreset         : in  std_logic_vector(0 downto 0) := (others => 'X');
      tx_parallel_data        : in  std_logic_vector(7 downto 0) := (others => 'X');
      tx_serial_clk0          : in  std_logic_vector(0 downto 0) := (others => 'X');
      tx_serial_data          : out std_logic_vector(0 downto 0);
      rx_set_locktodata       : in  std_logic_vector(0 downto 0) := (others => 'X');
      rx_set_locktoref        : in  std_logic_vector(0 downto 0) := (others => 'X');
      unused_tx_parallel_data : in  std_logic_vector(119 downto 0) := (others => 'X');
      unused_rx_parallel_data : out std_logic_vector(119 downto 0)
    );
  end component wr_arria10_phy;

  component wr_arria10_e3p1_phy is
    port (
      rx_analogreset          : in  std_logic_vector(0 downto 0) := (others => 'X');
      rx_cal_busy             : out std_logic_vector(0 downto 0);
      rx_cdr_refclk0          : in  std_logic := 'X';
      rx_clkout               : out std_logic_vector(0 downto 0);
      rx_coreclkin            : in  std_logic_vector(0 downto 0) := (others => 'X');
      rx_digitalreset         : in  std_logic_vector(0 downto 0) := (others => 'X');
      rx_is_lockedtodata      : out std_logic_vector(0 downto 0);
      rx_is_lockedtoref       : out std_logic_vector(0 downto 0);
      rx_parallel_data        : out std_logic_vector(7 downto 0);
      rx_serial_data          : in  std_logic_vector(0 downto 0) := (others => 'X');
      tx_analogreset          : in  std_logic_vector(0 downto 0) := (others => 'X');
      tx_cal_busy             : out std_logic_vector(0 downto 0);
      tx_clkout               : out std_logic_vector(0 downto 0);
      tx_coreclkin            : in  std_logic_vector(0 downto 0) := (others => 'X');
      tx_digitalreset         : in  std_logic_vector(0 downto 0) := (others => 'X');
      tx_parallel_data        : in  std_logic_vector(7 downto 0) := (others => 'X');
      tx_serial_clk0          : in  std_logic_vector(0 downto 0) := (others => 'X');
      tx_serial_data          : out std_logic_vector(0 downto 0);
      rx_set_locktodata       : in  std_logic_vector(0 downto 0) := (others => 'X');
      rx_set_locktoref        : in  std_logic_vector(0 downto 0) := (others => 'X');
      unused_tx_parallel_data : in  std_logic_vector(119 downto 0) := (others => 'X');
      unused_rx_parallel_data : out std_logic_vector(119 downto 0)
    );
  end component wr_arria10_e3p1_phy;

  component wr_arria10_e3p1_det_phy is
    port (
      reconfig_write            : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- write
      reconfig_read             : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- read
      reconfig_address          : in  std_logic_vector(9 downto 0)   := (others => 'X'); -- address
      reconfig_writedata        : in  std_logic_vector(31 downto 0)  := (others => 'X'); -- writedata
      reconfig_readdata         : out std_logic_vector(31 downto 0);                     -- readdata
      reconfig_waitrequest      : out std_logic_vector(0 downto 0);                      -- waitrequest
      reconfig_clk              : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- clk
      reconfig_reset            : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- reset
      rx_analogreset            : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- rx_analogreset
      rx_cal_busy               : out std_logic_vector(0 downto 0);                      -- rx_cal_busy
      rx_cdr_refclk0            : in  std_logic                      := 'X';             -- clk
      rx_clkout                 : out std_logic_vector(0 downto 0);                      -- clk
      rx_coreclkin              : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- clk
      rx_datak                  : out std_logic;                                         -- rx_datak
      rx_digitalreset           : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- rx_digitalreset
      rx_disperr                : out std_logic;                                         -- rx_disperr
      rx_errdetect              : out std_logic;                                         -- rx_errdetect
      rx_is_lockedtodata        : out std_logic_vector(0 downto 0);                      -- rx_is_lockedtodata
      rx_is_lockedtoref         : out std_logic_vector(0 downto 0);                      -- rx_is_lockedtoref
      rx_parallel_data          : out std_logic_vector(7 downto 0);                      -- rx_parallel_data
      rx_patterndetect          : out std_logic;                                         -- rx_patterndetect
      rx_runningdisp            : out std_logic;                                         -- rx_runningdisp
      rx_serial_data            : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- rx_serial_data
      rx_std_bitslipboundarysel : out std_logic_vector(4 downto 0);                      -- rx_std_bitslipboundarysel
      rx_std_wa_patternalign    : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- rx_std_wa_patternalign
      rx_syncstatus             : out std_logic;                                         -- rx_syncstatus
      tx_analogreset            : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- tx_analogreset
      tx_cal_busy               : out std_logic_vector(0 downto 0);                      -- tx_cal_busy
      tx_clkout                 : out std_logic_vector(0 downto 0);                      -- clk
      tx_coreclkin              : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- clk
      tx_datak                  : in  std_logic                      := 'X';             -- tx_datak
      tx_digitalreset           : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- tx_digitalreset
      tx_parallel_data          : in  std_logic_vector(7 downto 0)   := (others => 'X'); -- tx_parallel_data
      tx_serial_clk0            : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- clk
      tx_serial_data            : out std_logic_vector(0 downto 0);                      -- tx_serial_data
      unused_rx_parallel_data   : out std_logic_vector(113 downto 0);                    -- unused_rx_parallel_data
      unused_tx_parallel_data   : in  std_logic_vector(118 downto 0) := (others => 'X'); -- unused_tx_parallel_data
      rx_seriallpbken           : in  std_logic_vector(0 downto 0)   := (others => 'X')  -- rx_seriallpbken
    );
  end component wr_arria10_e3p1_det_phy;

  component wr_arria10_scu4_det_phy is
    port (
      reconfig_write            : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- write
      reconfig_read             : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- read
      reconfig_address          : in  std_logic_vector(9 downto 0)   := (others => 'X'); -- address
      reconfig_writedata        : in  std_logic_vector(31 downto 0)  := (others => 'X'); -- writedata
      reconfig_readdata         : out std_logic_vector(31 downto 0);                     -- readdata
      reconfig_waitrequest      : out std_logic_vector(0 downto 0);                      -- waitrequest
      reconfig_clk              : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- clk
      reconfig_reset            : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- reset
      rx_analogreset            : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- rx_analogreset
      rx_cal_busy               : out std_logic_vector(0 downto 0);                      -- rx_cal_busy
      rx_cdr_refclk0            : in  std_logic                      := 'X';             -- clk
      rx_clkout                 : out std_logic_vector(0 downto 0);                      -- clk
      rx_coreclkin              : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- clk
      rx_datak                  : out std_logic;                                         -- rx_datak
      rx_digitalreset           : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- rx_digitalreset
      rx_disperr                : out std_logic;                                         -- rx_disperr
      rx_errdetect              : out std_logic;                                         -- rx_errdetect
      rx_is_lockedtodata        : out std_logic_vector(0 downto 0);                      -- rx_is_lockedtodata
      rx_is_lockedtoref         : out std_logic_vector(0 downto 0);                      -- rx_is_lockedtoref
      rx_parallel_data          : out std_logic_vector(7 downto 0);                      -- rx_parallel_data
      rx_patterndetect          : out std_logic;                                         -- rx_patterndetect
      rx_runningdisp            : out std_logic;                                         -- rx_runningdisp
      rx_serial_data            : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- rx_serial_data
      rx_std_bitslipboundarysel : out std_logic_vector(4 downto 0);                      -- rx_std_bitslipboundarysel
      rx_syncstatus             : out std_logic;                                         -- rx_syncstatus
      tx_analogreset            : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- tx_analogreset
      tx_cal_busy               : out std_logic_vector(0 downto 0);                      -- tx_cal_busy
      tx_clkout                 : out std_logic_vector(0 downto 0);                      -- clk
      tx_coreclkin              : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- clk
      tx_datak                  : in  std_logic                      := 'X';             -- tx_datak
      tx_digitalreset           : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- tx_digitalreset
      tx_parallel_data          : in  std_logic_vector(7 downto 0)   := (others => 'X'); -- tx_parallel_data
      tx_serial_data            : out std_logic_vector(0 downto 0);                      -- tx_serial_data
      tx_std_bitslipboundarysel : in  std_logic_vector(4 downto 0)   := (others => 'X'); -- tx_std_bitslipboundarysel
      unused_rx_parallel_data   : out std_logic_vector(113 downto 0);                    -- unused_rx_parallel_data
      unused_tx_parallel_data   : in  std_logic_vector(118 downto 0) := (others => 'X'); -- unused_tx_parallel_data
      rx_seriallpbken           : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- rx_seriallpbken
      tx_bonding_clocks         : in  std_logic_vector(5 downto 0)   := (others => 'X')
    );
  end component wr_arria10_scu4_det_phy;

  component wr_arria10_scu4_transceiver is
    generic (
      g_use_atx_pll : boolean := TRUE);
    port (
      clk_ref_i      : in  std_logic := '0';
      tx_clk_o       : out std_logic;
      tx_data_i      : in  std_logic_vector(7 downto 0):= (others => '0');
      rx_clk_o       : out std_logic;
      rx_data_o      : out std_logic_vector(7 downto 0);
      pad_txp_o      : out std_logic;
      pad_rxp_i      : in  std_logic := '0'
      );
  end component wr_arria10_scu4_transceiver;

    component wr_arria10_scu4_phy is
      port (
        rx_analogreset          : in  std_logic_vector(0 downto 0) := (others => 'X');
        rx_cal_busy             : out std_logic_vector(0 downto 0);
        rx_cdr_refclk0          : in  std_logic := 'X';
        rx_clkout               : out std_logic_vector(0 downto 0);
        rx_coreclkin            : in  std_logic_vector(0 downto 0) := (others => 'X');
        rx_digitalreset         : in  std_logic_vector(0 downto 0) := (others => 'X');
        rx_is_lockedtodata      : out std_logic_vector(0 downto 0);
        rx_is_lockedtoref       : out std_logic_vector(0 downto 0);
        rx_parallel_data        : out std_logic_vector(7 downto 0);
        rx_serial_data          : in  std_logic_vector(0 downto 0) := (others => 'X');
        tx_analogreset          : in  std_logic_vector(0 downto 0) := (others => 'X');
        tx_cal_busy             : out std_logic_vector(0 downto 0);
        tx_clkout               : out std_logic_vector(0 downto 0);
        tx_coreclkin            : in  std_logic_vector(0 downto 0) := (others => 'X');
        tx_digitalreset         : in  std_logic_vector(0 downto 0) := (others => 'X');
        tx_parallel_data        : in  std_logic_vector(7 downto 0) := (others => 'X');
        tx_serial_clk0          : in  std_logic_vector(0 downto 0) := (others => 'X');
        tx_serial_data          : out std_logic_vector(0 downto 0);
        --rx_set_locktodata       : in  std_logic_vector(0 downto 0) := (others => 'X');
        --rx_set_locktoref        : in  std_logic_vector(0 downto 0) := (others => 'X');
        unused_tx_parallel_data : in  std_logic_vector(119 downto 0) := (others => 'X');
        unused_rx_parallel_data : out std_logic_vector(119 downto 0)
      );
    end component wr_arria10_scu4_phy;

    component wr_arria10_ftm4_det_phy is
      port (
        reconfig_write            : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- write
        reconfig_read             : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- read
        reconfig_address          : in  std_logic_vector(9 downto 0)   := (others => 'X'); -- address
        reconfig_writedata        : in  std_logic_vector(31 downto 0)  := (others => 'X'); -- writedata
        reconfig_readdata         : out std_logic_vector(31 downto 0);                     -- readdata
        reconfig_waitrequest      : out std_logic_vector(0 downto 0);                      -- waitrequest
        reconfig_clk              : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- clk
        reconfig_reset            : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- reset
        rx_analogreset            : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- rx_analogreset
        rx_cal_busy               : out std_logic_vector(0 downto 0);                      -- rx_cal_busy
        rx_cdr_refclk0            : in  std_logic                      := 'X';             -- clk
        rx_clkout                 : out std_logic_vector(0 downto 0);                      -- clk
        rx_coreclkin              : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- clk
        rx_datak                  : out std_logic;                                         -- rx_datak
        rx_digitalreset           : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- rx_digitalreset
        rx_disperr                : out std_logic;                                         -- rx_disperr
        rx_errdetect              : out std_logic;                                         -- rx_errdetect
        rx_is_lockedtodata        : out std_logic_vector(0 downto 0);                      -- rx_is_lockedtodata
        rx_is_lockedtoref         : out std_logic_vector(0 downto 0);                      -- rx_is_lockedtoref
        rx_parallel_data          : out std_logic_vector(7 downto 0);                      -- rx_parallel_data
        rx_patterndetect          : out std_logic;                                         -- rx_patterndetect
        rx_runningdisp            : out std_logic;                                         -- rx_runningdisp
        rx_serial_data            : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- rx_serial_data
        rx_std_bitslipboundarysel : out std_logic_vector(4 downto 0);                      -- rx_std_bitslipboundarysel
        rx_syncstatus             : out std_logic;                                         -- rx_syncstatus
        tx_analogreset            : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- tx_analogreset
        tx_cal_busy               : out std_logic_vector(0 downto 0);                      -- tx_cal_busy
        tx_clkout                 : out std_logic_vector(0 downto 0);                      -- clk
        tx_coreclkin              : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- clk
        tx_datak                  : in  std_logic                      := 'X';             -- tx_datak
        tx_digitalreset           : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- tx_digitalreset
        tx_parallel_data          : in  std_logic_vector(7 downto 0)   := (others => 'X'); -- tx_parallel_data
        tx_serial_data            : out std_logic_vector(0 downto 0);                      -- tx_serial_data
        tx_std_bitslipboundarysel : in  std_logic_vector(4 downto 0)   := (others => 'X'); -- tx_std_bitslipboundarysel
        unused_rx_parallel_data   : out std_logic_vector(113 downto 0);                    -- unused_rx_parallel_data
        unused_tx_parallel_data   : in  std_logic_vector(118 downto 0) := (others => 'X'); -- unused_tx_parallel_data
        rx_seriallpbken           : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- rx_seriallpbken
        tx_bonding_clocks         : in  std_logic_vector(5 downto 0)   := (others => 'X')
      );
    end component wr_arria10_ftm4_det_phy;

    component wr_arria10_ftm4_transceiver is
      generic (
        g_use_atx_pll : boolean := TRUE);
      port (
        clk_ref_i      : in  std_logic := '0';
        tx_clk_o       : out std_logic;
        tx_data_i      : in  std_logic_vector(7 downto 0):= (others => '0');
        rx_clk_o       : out std_logic;
        rx_data_o      : out std_logic_vector(7 downto 0);
        pad_txp_o      : out std_logic;
        pad_rxp_i      : in  std_logic := '0'
        );
    end component wr_arria10_ftm4_transceiver;

      component wr_arria10_ftm4_phy is
        port (
          rx_analogreset          : in  std_logic_vector(0 downto 0) := (others => 'X');
          rx_cal_busy             : out std_logic_vector(0 downto 0);
          rx_cdr_refclk0          : in  std_logic := 'X';
          rx_clkout               : out std_logic_vector(0 downto 0);
          rx_coreclkin            : in  std_logic_vector(0 downto 0) := (others => 'X');
          rx_digitalreset         : in  std_logic_vector(0 downto 0) := (others => 'X');
          rx_is_lockedtodata      : out std_logic_vector(0 downto 0);
          rx_is_lockedtoref       : out std_logic_vector(0 downto 0);
          rx_parallel_data        : out std_logic_vector(7 downto 0);
          rx_serial_data          : in  std_logic_vector(0 downto 0) := (others => 'X');
          tx_analogreset          : in  std_logic_vector(0 downto 0) := (others => 'X');
          tx_cal_busy             : out std_logic_vector(0 downto 0);
          tx_clkout               : out std_logic_vector(0 downto 0);
          tx_coreclkin            : in  std_logic_vector(0 downto 0) := (others => 'X');
          tx_digitalreset         : in  std_logic_vector(0 downto 0) := (others => 'X');
          tx_parallel_data        : in  std_logic_vector(7 downto 0) := (others => 'X');
          tx_serial_clk0          : in  std_logic_vector(0 downto 0) := (others => 'X');
          tx_serial_data          : out std_logic_vector(0 downto 0);
          --rx_set_locktodata       : in  std_logic_vector(0 downto 0) := (others => 'X');
          --rx_set_locktoref        : in  std_logic_vector(0 downto 0) := (others => 'X');
          unused_tx_parallel_data : in  std_logic_vector(119 downto 0) := (others => 'X');
          unused_rx_parallel_data : out std_logic_vector(119 downto 0)
        );
      end component wr_arria10_ftm4_phy;

    component wr_arria10_pex10_det_phy is
      port (
        reconfig_write            : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- write
        reconfig_read             : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- read
        reconfig_address          : in  std_logic_vector(9 downto 0)   := (others => 'X'); -- address
        reconfig_writedata        : in  std_logic_vector(31 downto 0)  := (others => 'X'); -- writedata
        reconfig_readdata         : out std_logic_vector(31 downto 0);                     -- readdata
        reconfig_waitrequest      : out std_logic_vector(0 downto 0);                      -- waitrequest
        reconfig_clk              : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- clk
        reconfig_reset            : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- reset
        rx_analogreset            : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- rx_analogreset
        rx_cal_busy               : out std_logic_vector(0 downto 0);                      -- rx_cal_busy
        rx_cdr_refclk0            : in  std_logic                      := 'X';             -- clk
        rx_clkout                 : out std_logic_vector(0 downto 0);                      -- clk
        rx_coreclkin              : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- clk
        rx_datak                  : out std_logic;                                         -- rx_datak
        rx_digitalreset           : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- rx_digitalreset
        rx_disperr                : out std_logic;                                         -- rx_disperr
        rx_errdetect              : out std_logic;                                         -- rx_errdetect
        rx_is_lockedtodata        : out std_logic_vector(0 downto 0);                      -- rx_is_lockedtodata
        rx_is_lockedtoref         : out std_logic_vector(0 downto 0);                      -- rx_is_lockedtoref
        rx_parallel_data          : out std_logic_vector(7 downto 0);                      -- rx_parallel_data
        rx_patterndetect          : out std_logic;                                         -- rx_patterndetect
        rx_runningdisp            : out std_logic;                                         -- rx_runningdisp
        rx_serial_data            : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- rx_serial_data
        rx_std_bitslipboundarysel : out std_logic_vector(4 downto 0);                      -- rx_std_bitslipboundarysel
        rx_syncstatus             : out std_logic;                                         -- rx_syncstatus
        tx_analogreset            : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- tx_analogreset
        tx_cal_busy               : out std_logic_vector(0 downto 0);                      -- tx_cal_busy
        tx_clkout                 : out std_logic_vector(0 downto 0);                      -- clk
        tx_coreclkin              : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- clk
        tx_datak                  : in  std_logic                      := 'X';             -- tx_datak
        tx_digitalreset           : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- tx_digitalreset
        tx_parallel_data          : in  std_logic_vector(7 downto 0)   := (others => 'X'); -- tx_parallel_data
        tx_serial_data            : out std_logic_vector(0 downto 0);                      -- tx_serial_data
        tx_std_bitslipboundarysel : in  std_logic_vector(4 downto 0)   := (others => 'X'); -- tx_std_bitslipboundarysel
        unused_rx_parallel_data   : out std_logic_vector(113 downto 0);                    -- unused_rx_parallel_data
        unused_tx_parallel_data   : in  std_logic_vector(118 downto 0) := (others => 'X'); -- unused_tx_parallel_data
        rx_seriallpbken           : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- rx_seriallpbken
        tx_bonding_clocks         : in  std_logic_vector(5 downto 0)   := (others => 'X')
        );
    end component wr_arria10_pex10_det_phy;

    component wr_arria10_pex10_transceiver is
      generic (
        g_use_atx_pll : boolean := TRUE);
      port (
        clk_ref_i      : in  std_logic := '0';
        tx_clk_o       : out std_logic;
        tx_data_i      : in  std_logic_vector(7 downto 0):= (others => '0');
        rx_clk_o       : out std_logic;
        rx_data_o      : out std_logic_vector(7 downto 0);
        pad_txp_o      : out std_logic;
        pad_rxp_i      : in  std_logic := '0'
        );
    end component wr_arria10_pex10_transceiver;

      component wr_arria10_pex10_phy is
        port (
          rx_analogreset          : in  std_logic_vector(0 downto 0) := (others => 'X');
          rx_cal_busy             : out std_logic_vector(0 downto 0);
          rx_cdr_refclk0          : in  std_logic := 'X';
          rx_clkout               : out std_logic_vector(0 downto 0);
          rx_coreclkin            : in  std_logic_vector(0 downto 0) := (others => 'X');
          rx_digitalreset         : in  std_logic_vector(0 downto 0) := (others => 'X');
          rx_is_lockedtodata      : out std_logic_vector(0 downto 0);
          rx_is_lockedtoref       : out std_logic_vector(0 downto 0);
          rx_parallel_data        : out std_logic_vector(7 downto 0);
          rx_serial_data          : in  std_logic_vector(0 downto 0) := (others => 'X');
          tx_analogreset          : in  std_logic_vector(0 downto 0) := (others => 'X');
          tx_cal_busy             : out std_logic_vector(0 downto 0);
          tx_clkout               : out std_logic_vector(0 downto 0);
          tx_coreclkin            : in  std_logic_vector(0 downto 0) := (others => 'X');
          tx_digitalreset         : in  std_logic_vector(0 downto 0) := (others => 'X');
          tx_parallel_data        : in  std_logic_vector(7 downto 0) := (others => 'X');
          tx_serial_clk0          : in  std_logic_vector(0 downto 0) := (others => 'X');
          tx_serial_data          : out std_logic_vector(0 downto 0);
          --rx_set_locktodata       : in  std_logic_vector(0 downto 0) := (others => 'X');
          --rx_set_locktoref        : in  std_logic_vector(0 downto 0) := (others => 'X');
          unused_tx_parallel_data : in  std_logic_vector(119 downto 0) := (others => 'X');
          unused_rx_parallel_data : out std_logic_vector(119 downto 0)
        );
      end component wr_arria10_pex10_phy;

      component wr_arria10_ftm10_det_phy is
        port (
          reconfig_write            : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- write
          reconfig_read             : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- read
          reconfig_address          : in  std_logic_vector(9 downto 0)   := (others => 'X'); -- address
          reconfig_writedata        : in  std_logic_vector(31 downto 0)  := (others => 'X'); -- writedata
          reconfig_readdata         : out std_logic_vector(31 downto 0);                     -- readdata
          reconfig_waitrequest      : out std_logic_vector(0 downto 0);                      -- waitrequest
          reconfig_clk              : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- clk
          reconfig_reset            : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- reset
          rx_analogreset            : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- rx_analogreset
          rx_cal_busy               : out std_logic_vector(0 downto 0);                      -- rx_cal_busy
          rx_cdr_refclk0            : in  std_logic                      := 'X';             -- clk
          rx_clkout                 : out std_logic_vector(0 downto 0);                      -- clk
          rx_coreclkin              : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- clk
          rx_datak                  : out std_logic;                                         -- rx_datak
          rx_digitalreset           : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- rx_digitalreset
          rx_disperr                : out std_logic;                                         -- rx_disperr
          rx_errdetect              : out std_logic;                                         -- rx_errdetect
          rx_is_lockedtodata        : out std_logic_vector(0 downto 0);                      -- rx_is_lockedtodata
          rx_is_lockedtoref         : out std_logic_vector(0 downto 0);                      -- rx_is_lockedtoref
          rx_parallel_data          : out std_logic_vector(7 downto 0);                      -- rx_parallel_data
          rx_patterndetect          : out std_logic;                                         -- rx_patterndetect
          rx_runningdisp            : out std_logic;                                         -- rx_runningdisp
          rx_serial_data            : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- rx_serial_data
          rx_std_bitslipboundarysel : out std_logic_vector(4 downto 0);                      -- rx_std_bitslipboundarysel
          rx_syncstatus             : out std_logic;                                         -- rx_syncstatus
          tx_analogreset            : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- tx_analogreset
          tx_cal_busy               : out std_logic_vector(0 downto 0);                      -- tx_cal_busy
          tx_clkout                 : out std_logic_vector(0 downto 0);                      -- clk
          tx_coreclkin              : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- clk
          tx_datak                  : in  std_logic                      := 'X';             -- tx_datak
          tx_digitalreset           : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- tx_digitalreset
          tx_parallel_data          : in  std_logic_vector(7 downto 0)   := (others => 'X'); -- tx_parallel_data
          tx_serial_data            : out std_logic_vector(0 downto 0);                      -- tx_serial_data
          tx_std_bitslipboundarysel : in  std_logic_vector(4 downto 0)   := (others => 'X'); -- tx_std_bitslipboundarysel
          unused_rx_parallel_data   : out std_logic_vector(113 downto 0);                    -- unused_rx_parallel_data
          unused_tx_parallel_data   : in  std_logic_vector(118 downto 0) := (others => 'X'); -- unused_tx_parallel_data
          rx_seriallpbken           : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- rx_seriallpbken
          tx_bonding_clocks         : in  std_logic_vector(5 downto 0)   := (others => 'X')
        );
      end component wr_arria10_ftm10_det_phy;

      component wr_arria10_ftm10_transceiver is
        generic (
          g_use_atx_pll : boolean := TRUE);
        port (
          clk_ref_i      : in  std_logic := '0';
          tx_clk_o       : out std_logic;
          tx_data_i      : in  std_logic_vector(7 downto 0):= (others => '0');
          rx_clk_o       : out std_logic;
          rx_data_o      : out std_logic_vector(7 downto 0);
          pad_txp_o      : out std_logic;
          pad_rxp_i      : in  std_logic := '0'
          );
      end component wr_arria10_ftm10_transceiver;

        component wr_arria10_ftm10_phy is
          port (
            rx_analogreset          : in  std_logic_vector(0 downto 0) := (others => 'X');
            rx_cal_busy             : out std_logic_vector(0 downto 0);
            rx_cdr_refclk0          : in  std_logic := 'X';
            rx_clkout               : out std_logic_vector(0 downto 0);
            rx_coreclkin            : in  std_logic_vector(0 downto 0) := (others => 'X');
            rx_digitalreset         : in  std_logic_vector(0 downto 0) := (others => 'X');
            rx_is_lockedtodata      : out std_logic_vector(0 downto 0);
            rx_is_lockedtoref       : out std_logic_vector(0 downto 0);
            rx_parallel_data        : out std_logic_vector(7 downto 0);
            rx_serial_data          : in  std_logic_vector(0 downto 0) := (others => 'X');
            tx_analogreset          : in  std_logic_vector(0 downto 0) := (others => 'X');
            tx_cal_busy             : out std_logic_vector(0 downto 0);
            tx_clkout               : out std_logic_vector(0 downto 0);
            tx_coreclkin            : in  std_logic_vector(0 downto 0) := (others => 'X');
            tx_digitalreset         : in  std_logic_vector(0 downto 0) := (others => 'X');
            tx_parallel_data        : in  std_logic_vector(7 downto 0) := (others => 'X');
            tx_serial_clk0          : in  std_logic_vector(0 downto 0) := (others => 'X');
            tx_serial_data          : out std_logic_vector(0 downto 0);
            --rx_set_locktodata       : in  std_logic_vector(0 downto 0) := (others => 'X');
            --rx_set_locktoref        : in  std_logic_vector(0 downto 0) := (others => 'X');
            unused_tx_parallel_data : in  std_logic_vector(119 downto 0) := (others => 'X');
            unused_rx_parallel_data : out std_logic_vector(119 downto 0)
          );
        end component wr_arria10_ftm10_phy;

  component wr_arria10_e3p1_tx_pll is
    port (
      pll_refclk0   : in  std_logic := 'X';
      pll_powerdown : in  std_logic := 'X';
      pll_locked    : out std_logic;
      tx_serial_clk : out std_logic;
      pll_cal_busy  : out std_logic
    );
  end component wr_arria10_e3p1_tx_pll;

  component wr_arria10_e3p1_atx_pll is
    port (
      pll_refclk0   : in  std_logic := 'X';
      pll_powerdown : in  std_logic := 'X';
      pll_locked    : out std_logic;
      tx_serial_clk : out std_logic;
      pll_cal_busy  : out std_logic
    );
  end component wr_arria10_e3p1_atx_pll;

  component wr_arria10_e3p1_cmu_pll is
    port (
      pll_powerdown : in  std_logic := 'X';
      pll_refclk0   : in  std_logic := 'X';
      tx_serial_clk : out std_logic;
      pll_locked    : out std_logic;
      pll_cal_busy  : out std_logic
    );
  end component wr_arria10_e3p1_cmu_pll;

  component wr_arria10_scu4_atx_pll is
    port (
      pll_cal_busy      : out std_logic;                           -- pll_cal_busy
      pll_locked        : out std_logic;                           -- pll_locked
      pll_powerdown     : in  std_logic                    := 'X'; -- pll_powerdown
      pll_refclk0       : in  std_logic                    := 'X'; -- clk
      tx_serial_clk     : out std_logic;                           -- clk
      mcgb_rst          : in  std_logic                    := 'X'; -- mcgb_rst
      tx_bonding_clocks : out std_logic_vector(5 downto 0)         -- clk
    );
  end component wr_arria10_scu4_atx_pll;

  component wr_arria10_scu4_cmu_pll is
    port (
      pll_powerdown : in  std_logic := 'X';
      pll_refclk0   : in  std_logic := 'X';
      tx_serial_clk : out std_logic;
      pll_locked    : out std_logic;
      pll_cal_busy  : out std_logic
    );
  end component wr_arria10_scu4_cmu_pll;

  component wr_arria10_ftm4_atx_pll is
    port (
      pll_cal_busy      : out std_logic;                           -- pll_cal_busy
      pll_locked        : out std_logic;                           -- pll_locked
      pll_powerdown     : in  std_logic                    := 'X'; -- pll_powerdown
      pll_refclk0       : in  std_logic                    := 'X'; -- clk
      tx_serial_clk     : out std_logic;                           -- clk
      mcgb_rst          : in  std_logic                    := 'X'; -- mcgb_rst
      tx_bonding_clocks : out std_logic_vector(5 downto 0)         -- clk
    );
  end component wr_arria10_ftm4_atx_pll;

  component wr_arria10_ftm4_cmu_pll is
    port (
      pll_powerdown : in  std_logic := 'X';
      pll_refclk0   : in  std_logic := 'X';
      tx_serial_clk : out std_logic;
      pll_locked    : out std_logic;
      pll_cal_busy  : out std_logic
    );
  end component wr_arria10_ftm4_cmu_pll;

  component wr_arria10_pex10_atx_pll is
    port (
      pll_cal_busy      : out std_logic;                           -- pll_cal_busy
      pll_locked        : out std_logic;                           -- pll_locked
      pll_powerdown     : in  std_logic                    := 'X'; -- pll_powerdown
      pll_refclk0       : in  std_logic                    := 'X'; -- clk
      tx_serial_clk     : out std_logic;                           -- clk
      mcgb_rst          : in  std_logic                    := 'X'; -- mcgb_rst
      tx_bonding_clocks : out std_logic_vector(5 downto 0)         -- clk
    );
  end component wr_arria10_pex10_atx_pll;

  component wr_arria10_pex10_cmu_pll is
    port (
      pll_powerdown : in  std_logic := 'X';
      pll_refclk0   : in  std_logic := 'X';
      tx_serial_clk : out std_logic;
      pll_locked    : out std_logic;
      pll_cal_busy  : out std_logic
    );
  end component wr_arria10_pex10_cmu_pll;

  component wr_arria10_ftm10_atx_pll is
    port (
      pll_cal_busy      : out std_logic;                           -- pll_cal_busy
      pll_locked        : out std_logic;                           -- pll_locked
      pll_powerdown     : in  std_logic                    := 'X'; -- pll_powerdown
      pll_refclk0       : in  std_logic                    := 'X'; -- clk
      tx_serial_clk     : out std_logic;                           -- clk
      mcgb_rst          : in  std_logic                    := 'X'; -- mcgb_rst
      tx_bonding_clocks : out std_logic_vector(5 downto 0)         -- clk
    );
  end component wr_arria10_ftm10_atx_pll;

  component wr_arria10_ftm10_cmu_pll is
    port (
      pll_powerdown : in  std_logic := 'X';
      pll_refclk0   : in  std_logic := 'X';
      tx_serial_clk : out std_logic;
      pll_locked    : out std_logic;
      pll_cal_busy  : out std_logic
    );
  end component wr_arria10_ftm10_cmu_pll;

  component wr_arria10_atx_pll is
    port (
      pll_powerdown : in  std_logic := 'X';
      pll_refclk0   : in  std_logic := 'X';
      tx_serial_clk : out std_logic;
      pll_locked    : out std_logic;
      pll_cal_busy  : out std_logic
    );
  end component wr_arria10_atx_pll;

  component wr_arria10_tx_pll is
    port (
      pll_refclk0   : in  std_logic := 'X';
      pll_powerdown : in  std_logic := 'X';
      pll_locked    : out std_logic;
      tx_serial_clk : out std_logic;
      pll_cal_busy  : out std_logic
    );
  end component wr_arria10_tx_pll;

  -------------------------------------------------------------------------------

  component wr_arria10_rst_ctl is
    port (
      clock              : in  std_logic := 'X';
      reset              : in  std_logic := 'X';
      pll_powerdown      : out std_logic_vector(0 downto 0);
      tx_analogreset     : out std_logic_vector(0 downto 0);
      tx_digitalreset    : out std_logic_vector(0 downto 0);
      tx_ready           : out std_logic_vector(0 downto 0);
      pll_locked         : in  std_logic_vector(0 downto 0) := (others => 'X');
      pll_select         : in  std_logic_vector(0 downto 0) := (others => 'X');
      tx_cal_busy        : in  std_logic_vector(0 downto 0) := (others => 'X');
      rx_analogreset     : out std_logic_vector(0 downto 0);
      rx_digitalreset    : out std_logic_vector(0 downto 0);
      rx_ready           : out std_logic_vector(0 downto 0);
      rx_is_lockedtodata : in  std_logic_vector(0 downto 0) := (others => 'X');
      rx_cal_busy        : in  std_logic_vector(0 downto 0) := (others => 'X')
    );
  end component wr_arria10_rst_ctl;

  component wr_arria10_e3p1_rst_ctl is
    port (
      clock              : in  std_logic := 'X';
      reset              : in  std_logic := 'X';
      pll_powerdown      : out std_logic_vector(0 downto 0);
      tx_analogreset     : out std_logic_vector(0 downto 0);
      tx_digitalreset    : out std_logic_vector(0 downto 0);
      tx_ready           : out std_logic_vector(0 downto 0);
      pll_locked         : in  std_logic_vector(0 downto 0) := (others => 'X');
      pll_select         : in  std_logic_vector(0 downto 0) := (others => 'X');
      tx_cal_busy        : in  std_logic_vector(0 downto 0) := (others => 'X');
      rx_analogreset     : out std_logic_vector(0 downto 0);
      rx_digitalreset    : out std_logic_vector(0 downto 0);
      rx_ready           : out std_logic_vector(0 downto 0);
      rx_is_lockedtodata : in  std_logic_vector(0 downto 0) := (others => 'X');
      rx_cal_busy        : in  std_logic_vector(0 downto 0) := (others => 'X')
    );
  end component wr_arria10_e3p1_rst_ctl;

  component wr_arria10_scu4_rst_ctl is
    port (
      clock              : in  std_logic := 'X';
      reset              : in  std_logic := 'X';
      pll_powerdown      : out std_logic_vector(0 downto 0);
      tx_analogreset     : out std_logic_vector(0 downto 0);
      tx_digitalreset    : out std_logic_vector(0 downto 0);
      tx_ready           : out std_logic_vector(0 downto 0);
      pll_locked         : in  std_logic_vector(0 downto 0) := (others => 'X');
      pll_select         : in  std_logic_vector(0 downto 0) := (others => 'X');
      tx_cal_busy        : in  std_logic_vector(0 downto 0) := (others => 'X');
      rx_analogreset     : out std_logic_vector(0 downto 0);
      rx_digitalreset    : out std_logic_vector(0 downto 0);
      rx_ready           : out std_logic_vector(0 downto 0);
      rx_is_lockedtodata : in  std_logic_vector(0 downto 0) := (others => 'X');
      rx_cal_busy        : in  std_logic_vector(0 downto 0) := (others => 'X')
    );
  end component wr_arria10_scu4_rst_ctl;

  component wr_arria10_ftm4_rst_ctl is
    port (
      clock              : in  std_logic := 'X';
      reset              : in  std_logic := 'X';
      pll_powerdown      : out std_logic_vector(0 downto 0);
      tx_analogreset     : out std_logic_vector(0 downto 0);
      tx_digitalreset    : out std_logic_vector(0 downto 0);
      tx_ready           : out std_logic_vector(0 downto 0);
      pll_locked         : in  std_logic_vector(0 downto 0) := (others => 'X');
      pll_select         : in  std_logic_vector(0 downto 0) := (others => 'X');
      tx_cal_busy        : in  std_logic_vector(0 downto 0) := (others => 'X');
      rx_analogreset     : out std_logic_vector(0 downto 0);
      rx_digitalreset    : out std_logic_vector(0 downto 0);
      rx_ready           : out std_logic_vector(0 downto 0);
      rx_is_lockedtodata : in  std_logic_vector(0 downto 0) := (others => 'X');
      rx_cal_busy        : in  std_logic_vector(0 downto 0) := (others => 'X')
    );
  end component wr_arria10_ftm4_rst_ctl;

  component wr_arria10_pex10_rst_ctl is
    port (
      clock              : in  std_logic := 'X';
      reset              : in  std_logic := 'X';
      pll_powerdown      : out std_logic_vector(0 downto 0);
      tx_analogreset     : out std_logic_vector(0 downto 0);
      tx_digitalreset    : out std_logic_vector(0 downto 0);
      tx_ready           : out std_logic_vector(0 downto 0);
      pll_locked         : in  std_logic_vector(0 downto 0) := (others => 'X');
      pll_select         : in  std_logic_vector(0 downto 0) := (others => 'X');
      tx_cal_busy        : in  std_logic_vector(0 downto 0) := (others => 'X');
      rx_analogreset     : out std_logic_vector(0 downto 0);
      rx_digitalreset    : out std_logic_vector(0 downto 0);
      rx_ready           : out std_logic_vector(0 downto 0);
      rx_is_lockedtodata : in  std_logic_vector(0 downto 0) := (others => 'X');
      rx_cal_busy        : in  std_logic_vector(0 downto 0) := (others => 'X')
    );
  end component wr_arria10_pex10_rst_ctl;

  component wr_arria10_ftm10_rst_ctl is
    port (
      clock              : in  std_logic := 'X';
      reset              : in  std_logic := 'X';
      pll_powerdown      : out std_logic_vector(0 downto 0);
      tx_analogreset     : out std_logic_vector(0 downto 0);
      tx_digitalreset    : out std_logic_vector(0 downto 0);
      tx_ready           : out std_logic_vector(0 downto 0);
      pll_locked         : in  std_logic_vector(0 downto 0) := (others => 'X');
      pll_select         : in  std_logic_vector(0 downto 0) := (others => 'X');
      tx_cal_busy        : in  std_logic_vector(0 downto 0) := (others => 'X');
      rx_analogreset     : out std_logic_vector(0 downto 0);
      rx_digitalreset    : out std_logic_vector(0 downto 0);
      rx_ready           : out std_logic_vector(0 downto 0);
      rx_is_lockedtodata : in  std_logic_vector(0 downto 0) := (others => 'X');
      rx_cal_busy        : in  std_logic_vector(0 downto 0) := (others => 'X')
    );
  end component wr_arria10_ftm10_rst_ctl;

  component arria5_dmtd_pll_default is
    port (
      refclk   : in  std_logic := '0';
      rst      : in  std_logic := '0';
      outclk_0 : out std_logic;
      locked   : out std_logic);
  end component;

  component arria5_sys_pll_default is
    port (
      refclk   : in  std_logic := '0';
      rst      : in  std_logic := '0';
      outclk_0 : out std_logic;
      outclk_1 : out std_logic;
      locked   : out std_logic);
  end component;

  component arria5_ext_ref_pll_default is
    port (
      refclk   : in  std_logic := '0';
      rst      : in  std_logic := '0';
      outclk_0 : out std_logic;
      locked   : out std_logic);
  end component arria5_ext_ref_pll_default;

end wr_altera_pkg;
