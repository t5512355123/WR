------------------------------------------------------------------------------
-- Title      : Deterministic Xilinx GTP wrapper - TX phase alignment
-- Project    : White Rabbit Switch
-------------------------------------------------------------------------------
-- File       : gtp_phase_align.vhd
-- Author     : Tomasz Wlostowski
-- Company    : CERN BE-CO-HT
-- Created    : 2010-11-18
-- Last update: 2011-09-12
-- Platform   : FPGA-generic
-- Standard   : VHDL'93
-------------------------------------------------------------------------------
-- Description: TX phase alignment state machine, as recommended by Xilinx.
-------------------------------------------------------------------------------
--
-- Original EASE design (c) 2010 NIKHEF / Peter Jansweijer and Henk Peek
-- VHDL port (c) 2010 CERN
--
-- This source file is free software; you can redistribute it
-- and/or modify it under the terms of the GNU Lesser General
-- Public License as published by the Free Software Foundation;
-- either version 2.1 of the License, or (at your option) any
-- later version
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
-- Revisions  :
-- Date        Version  Author    Description
-- 2010-11-18  0.4      twlostow  Ported EASE design to VHDL 
-- 2011-02-07  0.5      twlostow  Verified on Spartan6 GTP
-- 2011-09-12  0.6      twlostow  Virtex6 port
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity gtp_phase_align_virtex6 is
  generic
    (g_simulation : integer);
  
  port (
    gtp_rst_i    : in std_logic;
    gtp_tx_clk_i : in std_logic;

    gtp_tx_en_pma_phase_align_o : out std_logic;
    gtp_tx_pma_set_phase_o      : out std_logic;
    gtp_tx_dly_align_disable_o  : out std_logic;
    gtp_tx_dly_align_reset_o    : out std_logic;

    align_en_i   : in  std_logic;
    align_done_o : out std_logic
    );

end gtp_phase_align_virtex6;

architecture behavioral of gtp_phase_align_virtex6 is

  constant c_dly_align_reset_time : integer := 16;
  constant c_wait_set_phase_align : integer := 32;
  constant c_phase_align_duration : integer := 8192;


  type t_align_state is (S_ALIGN_IDLE, S_DLY_ALIGN_RESET, S_ALIGN_WAIT, S_ALIGN_SET_PHASE, S_ALIGN_DONE);

  signal counter : unsigned(13 downto 0);
  signal state   : t_align_state;

  
begin  -- behavioral

  p_align : process(gtp_tx_clk_i, gtp_rst_i)
  begin
    if rising_edge(gtp_tx_clk_i) then
      if gtp_rst_i = '1' then
        gtp_tx_en_pma_phase_align_o <= '0';
        gtp_tx_pma_set_phase_o      <= '0';
        gtp_tx_dly_align_reset_o    <= '0';
        gtp_tx_dly_align_disable_o  <= '1';
        counter                     <= (others => '0');
        align_done_o                <= '0';
        state                       <= S_ALIGN_IDLE;
      else
        if(align_en_i = '0') then
          state <= S_ALIGN_IDLE;
        else

          case (state) is
            when S_ALIGN_IDLE =>
              gtp_tx_en_pma_phase_align_o <= '0';
              gtp_tx_pma_set_phase_o      <= '0';
              gtp_tx_dly_align_reset_o    <= '0';
              gtp_tx_dly_align_disable_o  <= '1';

              counter      <= (others => '0');
              align_done_o <= '0';

              if(align_en_i = '1') then
                state <= S_DLY_ALIGN_RESET;
              end if;

            when S_DLY_ALIGN_RESET =>
              counter                    <= counter + 1;
              gtp_tx_dly_align_reset_o   <= '1';
              gtp_tx_dly_align_disable_o <= '1';

              if(counter = to_unsigned(c_dly_align_reset_time, counter'length)) then
                state <= S_ALIGN_WAIT;
              end if;

            when S_ALIGN_WAIT =>
              gtp_tx_dly_align_reset_o    <= '0';
              gtp_tx_dly_align_disable_o  <= '1';
              gtp_tx_en_pma_phase_align_o <= '1';

              counter <= counter + 1;
              if(counter = to_unsigned(c_dly_align_reset_time + c_wait_set_phase_align, counter'length)) then
                state <= S_ALIGN_SET_PHASE;
              end if;

            when S_ALIGN_SET_PHASE =>
              counter                <= counter +1;
              gtp_tx_pma_set_phase_o <= '1';

              if(counter = to_unsigned(c_dly_align_reset_time + c_wait_set_phase_align + c_phase_align_duration, counter'length)) then
                state <= S_ALIGN_DONE;
              end if;

            when S_ALIGN_DONE =>
              gtp_tx_pma_set_phase_o     <= '0';
              gtp_tx_dly_align_disable_o <= '0';
              counter                    <= (others => '0');
              align_done_o               <= '1';
            when others => null;
          end case;
        end if;
      end if;
    end if;
  end process;
  

end behavioral;

