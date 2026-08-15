--------------------------------------------------------------------------------
-- CERN
-- wr-cores/wr-streamers
-- https://www.ohwr.org/project/wr-cores
--------------------------------------------------------------------------------
--
-- unit name  : fifo_showahead_adapter.vhd
-- author     : Tomasz Wlostowski
-- description:
--
-- Emulation of show-ahead FIFO, used if the show-ahead feature in a FIFO
-- is not supported.
--
--
--------------------------------------------------------------------------------
-- Copyright (c) 2019 CERN BE/CO/HT
--------------------------------------------------------------------------------
-- GNU LESSER GENERAL PUBLIC LICENSE
--------------------------------------------------------------------------------
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
-- details
--
-- You should have received a copy of the GNU Lesser General
-- Public License along with this source; if not, download it
-- from http://www.gnu.org/licenses/lgpl-2.1.html
--
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

entity fifo_showahead_adapter is
  generic (
    g_width : integer);
  port (
    clk_i   : in std_logic;
    rst_n_i : in std_logic;

    fifo_q_i     : in  std_logic_vector(g_width-1 downto 0);
    fifo_empty_i : in  std_logic;
    fifo_rd_o    : out std_logic;

    q_o     : out std_logic_vector(g_width-1 downto 0);
    valid_o : out std_logic;
    rd_i    : in  std_logic
    );

end fifo_showahead_adapter;

architecture rtl of fifo_showahead_adapter is

  signal rd, rd_d : std_logic;
  signal valid_int : std_logic;
  
begin

  process(clk_i)
  begin
    if rising_edge(clk_i) then
      if rst_n_i = '0' then
        rd_d <= '0';
        valid_int <= '0';
      else
        rd_d <= rd;

        if rd = '1' then
          valid_int <= '1';
        elsif rd_i = '1' then
          valid_int <= not fifo_empty_i;
        end if;
      end if;
    end if;
  end process;

  rd <= not fifo_empty_i when valid_int = '0' else rd_i and not fifo_empty_i;

  q_o <= fifo_q_i; 

  fifo_rd_o <= rd;
  valid_o <= valid_int;

end rtl;


