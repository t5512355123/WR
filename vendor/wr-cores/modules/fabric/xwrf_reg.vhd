-------------------------------------------------------------------------------
-- Title      : Simple WB Fabric register
-- Project    : WhiteRabbit
-------------------------------------------------------------------------------
-- File       : xwrf_mux.vhd
-- Author     : Grzegorz Daniluk
-- Company    : CERN BE-CO-HT
-- Platform   : FPGA-generics
-- Standard   : VHDL
-------------------------------------------------------------------------------
-- Copyright (c) 2014 CERN
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

use work.wr_fabric_pkg.all;

entity xwrf_reg is
  generic(
    g_adr_width : integer := 2;
    g_dat_width : integer :=16);
  port(
    rst_n_i : in  std_logic;
    clk_i   : in  std_logic;
    snk_i   : in  t_wrf_sink_in;
    snk_o   : out t_wrf_sink_out;
    src_i   : in 	t_wrf_source_in;
    src_o   : out t_wrf_source_out);
end xwrf_reg;

architecture behav of xwrf_reg is
  type t_reg_fsm is (PASS, STALL, FLUSH);
  signal state : t_reg_fsm;
  signal temp : t_wrf_sink_in;
begin

  process(clk_i)
  begin
    if rising_edge(clk_i) then
      snk_o <= src_i;
    end if;
  end process;

  process(clk_i)
  begin
    if rising_edge(clk_i) then
      if(rst_n_i = '0') then
        state <= PASS;
        src_o <= c_dummy_snk_in;
      else
        case state is
          when PASS =>
            if (src_i.stall = '0') then
              src_o <= snk_i;
            else
              temp <= snk_i;
              state <= STALL;
            end if;
          when STALL =>
            if (src_i.stall = '0') then
              src_o <= temp;
              state <= FLUSH;
            end if;
          when FLUSH =>
            if (src_i.stall = '0') then
              src_o <= snk_i;
              state <= PASS;
            else
              temp <= snk_i;
              state <= STALL;
            end if;
        end case;
      end if;
    end if;
  end process;

end behav;
