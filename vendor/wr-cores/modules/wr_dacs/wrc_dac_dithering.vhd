-------------------------------------------------------------------------------
-- Title      : WhiteRabbit PTP Core
-- Project    : WhiteRabbit
-------------------------------------------------------------------------------
-- File       : wrc_dac_dithering.vhd
-- Author     : Tomasz Wlostowski
-- Company    : CERN (BE-CO-HT)
-- Created    : 2023
-- Platform   : FPGA-generics
-- Standard   : VHDL
-------------------------------------------------------------------------------
-- Description:
-- A simple DAC driver module with dithering to improve the nonlinear behaviour
-- of the softpll for small noise amplitudes (i.e. on low jitter HW such as the 
-- WR2RF or eRTM). Takes a 24 bit DAC value from the SoftPLL, adds 8 bits of
-- white noise dither (xorshift2 method), rounds and drives the DAC at a fixed
-- update rate. Put between the wr_core and gc_serial_dac (or another DAC 
-- interface of your choice)
-------------------------------------------------------------------------------
--
-- Copyright (c) 2012 - 2023 CERN
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

entity wrc_dac_dithering is
  generic (
-- log2 of the amplitude of the dither: y = x + (2**g_dither_amplitude) * rand_range(-1,1)
-- example: for g_dither_amplitude_log2 == 7, dithering signal takes values from -128 to +127
    g_dither_amplitude_log2 : integer                       := 7;
-- DAC update rate config. The DAC is updated every
-- (2**g_dither_clock_div_log2) clk_sys_i cycles. Remember to use a much faster (e.g. 10 times)
-- update rate than the SPLL sampling frequency for the dithering to actually work.
    g_dither_clock_div_log2 : integer                       := 7;
-- Initial value for the random number generator.
    g_dither_init_value     : std_logic_vector(31 downto 0) := x"deadbeef"
    );
  port (
    clk_sys_i   : in std_logic;
    rst_sys_n_i : in std_logic;

-- undithered input from the SPLL
    x_valid_i : in std_logic;
    x_i       : in std_logic_vector(23 downto 0);

-- dithered 16-bit output to the DAC
    y_o       : out std_logic_vector(15 downto 0);
    y_valid_o : out std_logic
    );

end wrc_dac_dithering;

architecture rtl of wrc_dac_dithering is

  function f_xorshift32_next(x : std_logic_vector) return std_logic_vector is
    variable tmp : unsigned(31 downto 0);
  begin
    tmp := unsigned(x);
    tmp := tmp xor (tmp sll 13);
    tmp := tmp xor (tmp srl 17);
    tmp := tmp xor (tmp sll 5);
    return std_logic_vector(tmp);
  end f_xorshift32_next;

  signal sr_div_cnt : unsigned(15 downto 0);
  signal sr_div_p   : std_logic;

  signal rnd_state  : std_logic_vector(31 downto 0);
  signal x_latched  : signed(23 downto 0);
  signal dither     : signed(g_dither_amplitude_log2-1 downto 0);
begin

  dither <= signed(rnd_state(g_dither_amplitude_log2-1 downto 0));

  p_clock_div : process(clk_sys_i)
  begin
    if rising_edge(clk_sys_i) then
      if rst_sys_n_i = '0' then
        sr_div_cnt <= (others => '0');
        sr_div_p   <= '0';
      elsif sr_div_cnt(g_dither_clock_div_log2) = '1' then
        sr_div_cnt <= (others => '0');
        sr_div_p   <= '1';
      else
        sr_div_cnt <= sr_div_cnt + 1;
        sr_div_p   <= '0';
      end if;
    end if;
  end process;

  p_dither : process(clk_sys_i)
    variable y_dithered : signed(23 downto 0);
  begin
    if rising_edge(clk_sys_i) then
      if rst_sys_n_i = '0' then
        rnd_state <= g_dither_init_value;
        y_valid_o <= '0';
        x_latched <= x"000100";
      else
        if x_valid_i = '1' then
          x_latched <= signed(x_i);
        end if;

        if sr_div_p = '1' then
          rnd_state  <= f_xorshift32_next(rnd_state);

          y_dithered := x_latched + dither;
          y_o        <= std_logic_vector(y_dithered(23 downto 8));
          y_valid_o <= '1';
        else
          y_valid_o <= '0';
        end if;
      end if;
    end if;
  end process;
end rtl;
