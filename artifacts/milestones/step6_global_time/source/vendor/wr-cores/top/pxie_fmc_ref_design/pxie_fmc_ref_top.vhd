-------------------------------------------------------------------------------
-- Title      : WRPC reference design for PXIe-FMC board
-- Project    : WR PTP Core
-- URL        : http://www.ohwr.org/projects/wr-cores/wiki/Wrpc_core
-------------------------------------------------------------------------------
-- File       : pxie_fmc_ref_top.vhd
-- Author(s)  : Greg Daniluk <grzegorz.daniluk@cern.ch>
-- Company    : CERN (BE-CO-HT)
-- Standard   : VHDL'93
-------------------------------------------------------------------------------
-- Description: Top-level file for the WRPC reference design on the PXIe-FMC
-- board.
--
-- This is a reference top HDL that instanciates the WR PTP Core together with
-- its peripherals to be run on a PXIe-FMC board.
--
-- There are two main usecases for this HDL file:
-- * let new users easily synthesize a WR PTP Core bitstream that can be run on
--   reference hardware
-- * provide a reference top HDL file showing how the WRPC can be instantiated
--   in HDL projects.
--
-- PXIe-FMC: https://ohwr.org/project/pxie-fmc
--
-------------------------------------------------------------------------------
-- Copyright (c) 2020 CERN
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
use work.wishbone_pkg.all;
use work.gn4124_core_pkg.all;
use work.wr_board_pkg.all;
use work.wr_pxie_fmc_pkg.all;

library unisim;
use unisim.vcomponents.all;

entity pxie_fmc_ref_top is
  generic (
    -- Simulation-mode enable parameter. Set by default (synthesis) to 0, and
    -- changed to non-zero in the instantiation of the top level DUT in the testbench.
    -- Its purpose is to reduce some internal counters/timeouts to speed up simulations.
    g_SIMULATION: integer := 0);
  port (
    ---------------------------------------------------------------------------
    -- Clocks/resets
    ---------------------------------------------------------------------------
    ps_por_i               : in std_logic;
    wr_clk_helper_125m_p_i : in  std_logic;
    wr_clk_helper_125m_n_i : in  std_logic;
    wr_clk_main_125m_p_i   : in  std_logic;
    wr_clk_main_125m_n_i   : in  std_logic;
    wr_clk_sfp_125m_p_i    : in  std_logic;
    wr_clk_sfp_125m_n_i    : in  std_logic;

    ---------------------------------------------------------------------------
    -- SPI interface to DACs
    ---------------------------------------------------------------------------
    plldac_sclk_o   : out std_logic;
    plldac_din_o    : out std_logic;
    pll25dac_cs_n_o : out std_logic;
    pll20dac_cs_n_o : out std_logic;

    ---------------------------------------------------------------------------
    -- SFP I/Os for transceiver
    ---------------------------------------------------------------------------
    sfp_txp_o         : out std_logic;
    sfp_txn_o         : out std_logic;
    sfp_rxp_i         : in  std_logic;
    sfp_rxn_i         : in  std_logic;
    sfp_det_i         : in  std_logic;
    sfp_sda_b         : inout std_logic;
    sfp_scl_b         : inout std_logic;
    sfp_tx_disable_o  : out std_logic;
    sfp_los_i         : in  std_logic;

    ---------------------------------------------------------------------------
    -- EEPROM I2C interface for storing configuration and accessing unique ID
    ---------------------------------------------------------------------------
    eeprom_sda_b  : inout std_logic;
    eeprom_scl_b  : inout std_logic;
    ---------------------------------------------------------------------------
    -- UART
    ---------------------------------------------------------------------------
    uart_rxd_i    : in  std_logic;
    uart_txd_o    : out std_logic;

    ---------------------------------------------------------------------------
    -- LEDs
    ---------------------------------------------------------------------------
    user_led_o    : out std_logic_vector(2 downto 0);
    pps_p_o    : out std_logic
  );
end entity pxie_fmc_ref_top;

architecture top of pxie_fmc_ref_top is

  signal rst_n : std_logic;
  signal clk_sys_62m5 : std_logic;

  signal sfp_scl_out, sfp_scl_in : std_logic;
  signal sfp_sda_out, sfp_sda_in : std_logic;
  signal eeprom_scl_out, eeprom_scl_in : std_logic;
  signal eeprom_sda_out, eeprom_sda_in : std_logic;

begin

  -- do not use PS_POR for now
  rst_n <= '1'; --not ps_por_i;

  user_led_o(2) <= '1';

  cmp_xwrc_board_pxie_fmc : xwrc_board_pxie_fmc
    generic map (
      g_simulation   => g_SIMULATION,
      g_dpram_initf  => "../../bin/wrpc/wrc_pxie.bram")
    port map (
      areset_n_i             => rst_n,
      wr_clk_helper_125m_p_i => wr_clk_helper_125m_p_i,
      wr_clk_helper_125m_n_i => wr_clk_helper_125m_n_i, 
      wr_clk_main_125m_p_i   => wr_clk_main_125m_p_i, 
      wr_clk_main_125m_n_i   => wr_clk_main_125m_n_i, 
      wr_clk_sfp_125m_p_i    => wr_clk_sfp_125m_p_i, 
      wr_clk_sfp_125m_n_i    => wr_clk_sfp_125m_n_i, 
      clk_sys_62m5_o         => clk_sys_62m5,
  
      plldac_sclk_o   => plldac_sclk_o,
      plldac_din_o    => plldac_din_o,
      pll25dac_cs_n_o => pll25dac_cs_n_o,
      pll20dac_cs_n_o => pll20dac_cs_n_o,
  
      sfp_txp_o       => sfp_txp_o,
      sfp_txn_o       => sfp_txn_o,
      sfp_rxp_i       => sfp_rxp_i,
      sfp_rxn_i       => sfp_rxn_i,
      sfp_det_i       => sfp_det_i,
      sfp_sda_i       => sfp_sda_in,
      sfp_sda_o       => sfp_sda_out,
      sfp_scl_i       => sfp_scl_in,
      sfp_scl_o       => sfp_scl_out,
      sfp_tx_disable_o => sfp_tx_disable_o,
      sfp_los_i        => sfp_los_i,
  
      eeprom_sda_i => eeprom_sda_in, 
      eeprom_sda_o => eeprom_sda_out, 
      eeprom_scl_i => eeprom_scl_in, 
      eeprom_scl_o => eeprom_scl_out, 
      uart_rxd_i   => uart_rxd_i, 
      uart_txd_o   => uart_txd_o, 
  
      led_act_o  => user_led_o(0),
      led_link_o => user_led_o(1),
      pps_p_o    => pps_p_o);


  sfp_scl_b <= '0' when sfp_scl_out = '0' else 'Z';
  sfp_sda_b <= '0' when sfp_sda_out = '0' else 'Z';
  sfp_scl_in <= sfp_scl_b;
  sfp_sda_in <= sfp_sda_b;

  eeprom_scl_b <= '0' when eeprom_scl_out = '0' else 'Z';
  eeprom_sda_b <= '0' when eeprom_sda_out = '0' else 'Z';
  eeprom_scl_in <= eeprom_scl_b;
  eeprom_sda_in <= eeprom_sda_b;

end top;
