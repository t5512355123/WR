--------------------------------------------------------------------------------
-- CERN
-- wr-cores/wr-streamers
-- https://www.ohwr.org/project/wr-cores
--------------------------------------------------------------------------------
--
-- unit name  : ts_restore_tai.vhd
-- author     : Tomasz Wlostowski
-- description:
--
-- This module restores full TAI timestamp from the timestamp
-- received in WR_streamer frame
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
use ieee.numeric_std.all;

use work.gencores_pkg.all;

entity ts_restore_tai is
  generic
    (
      g_tm_sample_period        : integer := 20;
      g_clk_ref_rate            : integer;
      g_simulation              : integer := 0;
      g_sim_cycle_counter_range : integer := 125000000
      );

  port (
    clk_sys_i : in std_logic;
    clk_ref_i : in std_logic;
    rst_n_i   : in std_logic;

    -- Timing I/F, clk_ref_i clock domain
    tm_time_valid_i : in std_logic;
    tm_tai_i        : in std_logic_vector(39 downto 0);
    tm_cycles_i     : in std_logic_vector(27 downto 0);

    -- Timestamp I/F, clk_sys_i clock domain
    ts_valid_i  : in std_logic;
    ts_cycles_i : in std_logic_vector(27 downto 0);

    ts_valid_o  : out std_logic;
    ts_cycles_o : out std_logic_vector(27 downto 0);
    ts_error_o  : out std_logic;
    ts_tai_o    : out std_logic_vector(39 downto 0)
    );

end entity;

architecture rtl of ts_restore_tai is
  signal tm_cycles_sys, tm_cycles_ref, tm_cycles_ref_d : std_logic_vector(27 downto 0);
  signal tm_tai_sys, tm_tai_ref, tm_tai_ref_d       : std_logic_vector(39 downto 0);
  signal tm_valid_sys, tm_valid_ref, tm_valid_ref_d   : std_logic;

  signal tm_sample_cnt   : unsigned(5 downto 0);
  signal tm_sample_p_ref : std_logic;
  signal tm_sample_p_sys : std_logic;

  impure function f_cycles_counter_range return integer is
  begin
    if g_simulation = 1 then
      if g_clk_ref_rate = 62500000 then
        return 2*g_sim_cycle_counter_range;
      else
        return g_sim_cycle_counter_range;
      end if;

    else
      return 125000000;
    end if;
  end function;

  constant c_rollover_threshold_lo : integer := f_cycles_counter_range / 4;
  constant c_rollover_threshold_hi : integer := f_cycles_counter_range * 3 / 4;


  signal rst_n_ref : std_logic;

begin

  U_SyncReset_to_RefClk : gc_sync_ffs
    port map (
      clk_i    => clk_ref_i,
      rst_n_i  => '1',
      data_i   => rst_n_i,
      synced_o => rst_n_ref);


  p_sample_tm_ref : process(clk_ref_i)
  begin
    if rising_edge(clk_ref_i) then
      if rst_n_ref = '0' then
        tm_sample_p_ref <= '0';
        tm_sample_cnt   <= (others => '0');
      else

          tm_cycles_ref   <= tm_cycles_ref_d;
          tm_tai_ref     <= tm_tai_ref_d;
          tm_valid_ref    <= tm_valid_ref_d;

        if tm_sample_cnt = g_tm_sample_period-1 then
          tm_sample_p_ref <= '1';
          tm_cycles_ref_d   <= tm_cycles_i;
          tm_tai_ref_d      <= tm_tai_i;
          tm_valid_ref_d    <= tm_time_valid_i;
          tm_sample_cnt   <= (others => '0');
        else
          tm_sample_p_ref <= '0';
          tm_sample_cnt   <= tm_sample_cnt + 1;
        end if;
      end if;
    end if;
  end process;


  U_Sync_Sample_Pulse : gc_pulse_synchronizer2
    port map (
      clk_in_i    => clk_ref_i,
      rst_in_n_i  => rst_n_ref,
      clk_out_i   => clk_sys_i,
      rst_out_n_i => rst_n_i,
      d_ready_o   => open,
      d_p_i       => tm_sample_p_ref,
      q_p_o       => tm_sample_p_sys);

  p_sample_tm_sys : process(clk_sys_i)
  begin
    if rising_edge(clk_sys_i) then
      if rst_n_i = '0' then
        tm_valid_sys <= '0';
      elsif tm_sample_p_sys = '1' then
        tm_tai_sys    <= tm_tai_ref;
        tm_cycles_sys <= tm_cycles_ref;
        tm_valid_sys  <= tm_valid_ref;
      end if;
    end if;
  end process;

  p_process : process(clk_sys_i)
  begin
    if rising_edge(clk_sys_i) then
      if rst_n_i = '0' then
        ts_valid_o <= '0';

      else

        if ts_valid_i = '1' then

          if unsigned(ts_cycles_i) > c_rollover_threshold_hi and unsigned(tm_cycles_sys) < c_rollover_threshold_lo then
            ts_tai_o <= std_logic_vector(unsigned(tm_tai_sys) - 1);
          else
            ts_tai_o <= tm_tai_sys;
          end if;

          ts_cycles_o <= ts_cycles_i;
          ts_error_o  <= not tm_valid_sys;
          ts_valid_o  <= '1';
        else
          ts_valid_o <= '0';
        end if;

      end if;
    end if;
  end process;

end rtl;
