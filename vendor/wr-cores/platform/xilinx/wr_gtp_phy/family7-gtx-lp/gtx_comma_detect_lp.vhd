-------------------------------------------------------------------------------
-- Title      : Comma detection for Low Phase noise GTX implermentation
-- Project    : White Rabbit
-------------------------------------------------------------------------------
-- File       : gtx_comma_detect_lp.vhd
-- Author     : Tomasz Wlostowski
-- Company    : CERN BE-CO-HT
-- Created    : 2019-03-29
-- Last update: 2020-08-04
-- Platform   : FPGA-generic
-- Standard   : VHDL'93
-------------------------------------------------------------------------------
-- Description: Low Phase noise GTX implementation does not use the serializer
-- 8B/10B decoder. gtx_comma_detect_lp scans for a valid comma in the
-- 20 bit received raw data.
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
-- 2019-03-29  0.1      tomasz    Initial release
-- 2020-08-04  0.2      peterj    Cleaned up and added this header
-------------------------------------------------------------------------------

library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity gtx_comma_detect_lp is
  generic (
    g_ID : integer
    );
  port (
    clk_rx_i : in std_logic;
    rst_i    : in std_logic;

    rx_data_raw_i : in std_logic_vector(19 downto 0);
    rx_data_raw_o : out std_logic_vector(19 downto 0);

    comma_target_pos_i : in std_logic_vector(4 downto 0);
    comma_current_pos_o : out std_logic_vector(4 downto 0);
    comma_pos_valid_o : out std_logic;
    
    link_up_o : out std_logic;
    aligned_o : out std_logic
    );

end gtx_comma_detect_lp;

architecture rtl of gtx_comma_detect_lp is

  type t_state is (SYNC_LOST, SYNC_CHECK, SYNC_ACQUIRED);

  constant c_IDLE_LENGTH_UP   : integer := 500;
  constant c_IDLE_LENGTH_LOSS : integer := 1000;

  signal rx_data_d0     : std_logic_vector(19 downto 0);
  signal rx_data_merged : std_logic_vector(39 downto 0);

  signal first_comma : std_logic_vector(4 downto 0);
  signal cnt         : unsigned(15 downto 0);
  signal state       : t_state;
  signal comma_found : std_logic_vector(19 downto 0);

  component chipscope_ila_v6 is
    port (
      CONTROL : inout std_logic_vector(35 downto 0);
      CLK     : in    std_logic;
      TRIG0   : in    std_logic_vector(63 downto 0));
  end component chipscope_ila_v6;

  component chipscope_icon_v6 is
    port (
      CONTROL0 : inout std_logic_vector(35 downto 0));
  end component chipscope_icon_v6;

  signal CONTROL : std_logic_vector(35 downto 0);
  signal TRIG0   : std_logic_vector(63 downto 0);
  
  function f_onehot_encode (x : std_logic_vector; output_bits : integer)return std_logic_vector is
    variable rv : std_logic_vector(output_bits-1 downto 0);
  begin
    for i in 0 to x'length-1 loop
      if x(i) = '1' then
        rv := std_logic_vector(to_unsigned(i, output_bits));
        return rv;
      end if;
    end loop;

    return std_logic_vector(to_unsigned(0, output_bits));
  end f_onehot_encode;

  constant c_K28_5_PLUS : std_logic_vector(9 downto 0) := "1010000011";

  signal comma_pos            : std_logic_vector(4 downto 0);
  signal comma_pos_valid      : std_logic;
  signal link_up : std_logic;
  signal link_aligned : std_logic;
  
begin

  process(clk_rx_i)
    variable comma_pos_comb : std_logic_vector(4 downto 0);
  begin
    if rising_edge(clk_rx_i) then
      if rst_i = '1' then
        comma_found <= (others => '0');
      else
        rx_data_d0                  <= rx_data_raw_i;
        rx_data_merged(39 downto 0) <= rx_data_d0 & rx_data_raw_i;
        for i in 0 to 19 loop
          if rx_data_merged(i + 9 downto i) = c_K28_5_PLUS or
            rx_data_merged(i + 9 downto i) = (not c_K28_5_PLUS) then
            comma_found(i) <= '1';
          else
            comma_found(i) <= '0';
          end if;
        end loop;

        comma_pos_comb := f_onehot_encode(comma_found, comma_pos'length);

        if unsigned(comma_found) /= 0 then
          comma_pos_valid <= '1';
          comma_pos_valid_o <= '1';
          comma_pos <= comma_pos_comb;
          comma_current_pos_o <= comma_pos_comb;
        else
          comma_pos_valid <= '0';
          comma_pos_valid_o <= '0';
        end if;
      end if;
	end if;
  end process;

  process(clk_rx_i)
  begin
    if rising_edge(clk_rx_i) then
      if rst_i = '1' then
        state <= SYNC_LOST;
      else
        case state is
          when SYNC_LOST =>
            link_up <= '0';
            link_aligned <= '0';

            if comma_pos_valid = '1' then
              first_comma <= comma_pos;
              state       <= SYNC_CHECK;
              cnt         <= to_unsigned(4, cnt'length);
            end if;

          when SYNC_CHECK =>
            if comma_pos = first_comma and comma_pos_valid = '1' then
              cnt <= cnt + 4;
            elsif cnt > 0 then
              cnt <= cnt - 1;
              if cnt = 1 then
                state <= SYNC_LOST;
              end if;
            end if;

            if cnt >= c_IDLE_LENGTH_UP then
              state <= SYNC_ACQUIRED;
              cnt   <= (others => '0');
            end if;

          when SYNC_ACQUIRED =>
            link_up <= '1';

            if(comma_pos_valid = '1' and comma_pos = first_comma) then
              if( unsigned(comma_pos) = unsigned(comma_target_pos_i) ) then
                link_aligned <= '1';
              end if;

              cnt <= (others => '0');
            else

              cnt <= cnt + 1;
              if cnt = c_IDLE_LENGTH_LOSS then
                state <= SYNC_LOST;
              end if;
            end if;
        end case;
      end if;
    end if;
  end process;

  -- generate mux shifted output depending on comma_target_pos_i
  process(rx_data_merged, comma_target_pos_i)
    variable comma_pos_int : integer range 0 to 19;
  begin
    comma_pos_int := to_integer(unsigned(comma_target_pos_i));
	rx_data_raw_o(19 downto 0) <= rx_data_merged(comma_pos_int + 19 downto comma_pos_int);
  end process;

  aligned_o <= link_aligned;
  link_up_o <= link_up;
  
end rtl;

