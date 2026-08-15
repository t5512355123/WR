-------------------------------------------------------------------------------
-- Title      : Deterministic Xilinx GTP wrapper - Virtex5 alignment detect
-- Project    : White Rabbit 
-------------------------------------------------------------------------------
-- File       : v5_gtp_align_detect.vhd
-- Author     : Tomasz Wlostowski
-- Company    : CERN BE-CO-HT
-- Created    : 2010-11-18
-- Last update: 2015-05-19
-- Platform   : FPGA-generic
-- Standard   : VHDL'93
-------------------------------------------------------------------------------
-- Description: Emulates RXBYTEISALIGNED signal on Virtex5 GTP upon detection
-- of valid Ethernet idle/autonegotiation pattern.
-------------------------------------------------------------------------------
--
-- Copyright (c) 2015 CERN 
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

entity v5_gtp_align_detect is

  port (
    clk_rx_i  : in  std_logic;
    rst_i     : in  std_logic;
    data_i    : in  std_logic_vector(7 downto 0);
    k_i       : in  std_logic;
    aligned_o : out std_logic);

end entity v5_gtp_align_detect;

architecture rtl of v5_gtp_align_detect is
  type t_state is (s_comma, s_idle, s_autoneg0, s_autoneg1);
  signal state         : t_state;
  signal valid_commas  : unsigned(1 downto 0);
  signal comma_timeout : unsigned(14 downto 0);
begin

  process(clk_rx_i, rst_i)
  begin
      if rst_i = '1' then
        state         <= s_comma;
        valid_commas  <= (others => '0');
        comma_timeout <= (others => '0');
        aligned_o <= '0';
      elsif  rising_edge(clk_rx_i) then
        case state is
          when s_comma =>
            if (k_i = '1' and data_i = x"bc") then
              state         <= s_idle;
              comma_timeout <= (others => '0');
            else
              comma_timeout <= comma_timeout + 1;

            end if;

            if(comma_timeout = 2000) then
              aligned_o    <= '0';
              valid_commas <= (others => '0');
            elsif valid_commas = 3 then
              aligned_o <= '1';
            end if;
            
          when s_idle =>
            if (k_i = '0') then
              if data_i = x"50" then
                if(valid_commas /= 3) then
                  valid_commas <= valid_commas + 1;
                end if;
                state <= s_comma;
              elsif data_i = x"42" or data_i = x"b5" then
                state <= s_autoneg0;
                if(valid_commas /= 3) then
                  valid_commas <= valid_commas + 1;
                end if;
              end if;
            end if;
          when s_autoneg0 =>
            state <= s_autoneg1;
          when s_autoneg1 =>
            state <= s_comma;
        end case;
      end if;
  end process;
  
end rtl;
