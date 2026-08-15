-------------------------------------------------------------------------------
-- Title      : Deterministic Xilinx GTX wrapper - kintex-7 top module
-- Project    : White Rabbit Switch
-------------------------------------------------------------------------------
-- File       : wr_gtx_phy_family7.vhd
-- Author     : Peter Jansweijer, Tomasz Wlostowski
-- Company    : CERN BE-CO-HT
-- Created    : 2013-04-08
-- Last update: 2019-06-14
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
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

library work;
use work.gencores_pkg.all;
use work.disparity_gen_pkg.all;

entity wr_gtx_phy_kintex7_lp_qpll is

  generic (
    -- set to non-zero value to speed up the simulation by reducing some delays
    g_simulation : integer := 0
    );

  port (
    rst_i : in std_logic;

    -- Dedicated reference 125 MHz clock for the GTX transceiver
    clk_gtx_i : in std_logic;

    -- systme clock (for lock detector)
    clk_sys_i : in std_logic;

    qpll_clk_o     : out std_logic;
    qpll_ref_clk_o : out std_logic;

    locked_o : out std_logic

    -- debug_i : in  std_logic_vector(15 downto 0) := x"0000";
    -- debug_o : out std_logic_vector(15 downto 0)

    );
end wr_gtx_phy_kintex7_lp_qpll;

architecture rtl of wr_gtx_phy_kintex7_lp_qpll is
  
  impure function conv_qpll_fbdiv_top (qpllfbdiv_top : in integer) return bit_vector is
  begin
    if (qpllfbdiv_top = 16) then
      return "0000100000";
    elsif (qpllfbdiv_top = 20) then
      return "0000110000";
    elsif (qpllfbdiv_top = 32) then
      return "0001100000";
    elsif (qpllfbdiv_top = 40) then
      return "0010000000";
    elsif (qpllfbdiv_top = 64) then
      return "0011100000";
    elsif (qpllfbdiv_top = 66) then
      return "0101000000";
    elsif (qpllfbdiv_top = 80) then
      return "0100100000";
    elsif (qpllfbdiv_top = 100) then
      return "0101110000";
    else
      return "0000000000";
    end if;
  end function;

  impure function conv_qpll_fbdiv_ratio (qpllfbdiv_top : in integer) return bit is
  begin
    if (qpllfbdiv_top = 16) then
      return '1';
    elsif (qpllfbdiv_top = 20) then
      return '1';
    elsif (qpllfbdiv_top = 32) then
      return '1';
    elsif (qpllfbdiv_top = 40) then
      return '1';
    elsif (qpllfbdiv_top = 64) then
      return '1';
    elsif (qpllfbdiv_top = 66) then
      return '0';
    elsif (qpllfbdiv_top = 80) then
      return '1';
    elsif (qpllfbdiv_top = 100) then
      return '1';
    else
      return '1';
    end if;
  end function;

  constant QPLL_FBDIV_TOP   : integer                := 80;
  constant QPLL_FBDIV_IN    : bit_vector(9 downto 0) := conv_qpll_fbdiv_top(QPLL_FBDIV_TOP);
  constant QPLL_FBDIV_RATIO : bit                    := conv_qpll_fbdiv_ratio(QPLL_FBDIV_TOP);

signal qpll_reset : std_logic;
  
begin  -- rtl

  qpll_reset <= rst_i; -- or debug_i(0);

  gtxe2_common_i : GTXE2_COMMON
    generic map
    (
      -- Simulation attributes
      SIM_RESET_SPEEDUP  => "TRUE",
      SIM_QPLLREFCLK_SEL => ("001"),
      SIM_VERSION        => "4.0",

      ------------------COMMON BLOCK Attributes---------------
      BIAS_CFG                 => (x"0000040000001000"),
      COMMON_CFG               => (x"00000000"),
      QPLL_CFG                 => (x"0680181"),
      QPLL_CLKOUT_CFG          => ("0000"),
      QPLL_COARSE_FREQ_OVRD    => ("010000"),
      QPLL_COARSE_FREQ_OVRD_EN => ('0'),
      QPLL_CP                  => ("0000011111"),
      QPLL_CP_MONITOR_EN       => ('0'),
      QPLL_DMONITOR_SEL        => ('0'),
      QPLL_FBDIV               => (QPLL_FBDIV_IN),
      QPLL_FBDIV_MONITOR_EN    => ('0'),
      QPLL_FBDIV_RATIO         => (QPLL_FBDIV_RATIO),
      QPLL_INIT_CFG            => (x"000006"),
      QPLL_LOCK_CFG            => (x"21E8"),
      QPLL_LPF                 => ("1111"),
      QPLL_REFCLK_DIV          => (1)
      )
    port map
    (
      ------------- Common Block  - Dynamic Reconfiguration Port (DRP) -----------
      DRPADDR          => "00000000",
      DRPCLK           => '0',
      DRPDI            => x"0000",
      DRPDO            => open,
      DRPEN            => '0',
      DRPRDY           => open,
      DRPWE            => '0',
      ---------------------- Common Block  - Ref Clock Ports ---------------------
      GTGREFCLK        => '0',
      GTNORTHREFCLK0   => '0',
      GTNORTHREFCLK1   => '0',
      GTREFCLK0        => clk_gtx_i,
      GTREFCLK1        => '0',
      GTSOUTHREFCLK0   => '0',
      GTSOUTHREFCLK1   => '0',
      ------------------------- Common Block -  QPLL Ports -----------------------
      QPLLDMONITOR     => open,
      ----------------------- Common Block - Clocking Ports ----------------------
      QPLLOUTCLK       => qpll_clk_o,
      QPLLOUTREFCLK    => qpll_ref_clk_o,
      REFCLKOUTMONITOR => open,
      ------------------------- Common Block - QPLL Ports ------------------------
      QPLLFBCLKLOST    => open,
      QPLLLOCK         => locked_o,
      QPLLLOCKDETCLK   => clk_sys_i,
      QPLLLOCKEN       => '1',
      QPLLOUTRESET     => '0',
      QPLLPD           => '0',
      QPLLREFCLKLOST   => open,
      QPLLREFCLKSEL    => "001",
      QPLLRESET        => qpll_reset,
      QPLLRSVD1        => "0000000000000000",
      QPLLRSVD2        => "11111",
      --------------------------------- QPLL Ports -------------------------------
      BGBYPASSB        => '1',
      BGMONITORENB     => '1',
      BGPDB            => '1',
      BGRCALOVRD       => "11111",
      PMARSVD          => "00000000",
      RCALENB          => '1'
      );

end rtl;
