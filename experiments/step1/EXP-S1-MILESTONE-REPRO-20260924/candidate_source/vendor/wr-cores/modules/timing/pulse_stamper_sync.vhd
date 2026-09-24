--------------------------------------------------------------------------------
-- CERN
-- wr-cores/timing
-- https://www.ohwr.org/project/wr-cores
--------------------------------------------------------------------------------
--
-- unit name  : pulse_stamper_sync.vhd
-- author     : Tomasz Wlostowski, based on pulse_stamper by Javier Serrano
-- description:
--
-- this module allows to time stamp pulses that are synchronous to clk_ref
-- domain, so in the domain of the WR time (i.e. tm_tai_i and tm_cycles_i).
-- The generated timestamp is then made available in the clk_sys domain.
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

entity pulse_stamper_sync is

  generic (
    -- reference clock frequency
    g_ref_clk_rate : integer := 125000000);

  port(
    clk_ref_i : in std_logic;           -- timing reference clock
    clk_sys_i : in std_logic;           -- data output reference clock
    rst_n_i   : in std_logic;           -- system reset

    pulse_i : in std_logic;  -- pulse to be stamped (ref clock domain)

    -------------------------------------------------------------------------------
    -- Timing input (from WRPC), clk_ref_i domain
    ------------------------------------------------------------------------------

    -- 1: time given on tm_utc_i and tm_cycles_i is valid (otherwise, don't timestamp)
    tm_time_valid_i : in std_logic;
    -- number of seconds
    tm_tai_i        : in std_logic_vector(39 downto 0);
    -- number of clk_ref_i cycles
    tm_cycles_i     : in std_logic_vector(27 downto 0);


    ---------------------------------------------------------------------------
    -- Time tag output (clk_sys_i domain)
    ---------------------------------------------------------------------------
    tag_tai_o    : out std_logic_vector(39 downto 0);
    tag_cycles_o : out std_logic_vector(27 downto 0);
    -- single-cycle pulse: strobe tag on tag_utc_o and tag_cycles_o
    tag_valid_o  : out std_logic;
    tag_error_o  : out std_logic  -- 1 when pulse came with tm_time_valid_i = 0
    );


end pulse_stamper_sync;

architecture rtl of pulse_stamper_sync is

  signal rst_n_ref : std_logic;
  signal pulse_d : std_logic;
  signal tag_ready_ref, tag_ready_ref_d, tag_ready_ref_p1 : std_logic;
  signal tag_time_valid_ref : std_logic;
  signal tag_ready_sys_p1 : std_logic;
  
  -- Time tagger signals
  signal tag_utc_ref    : std_logic_vector(39 downto 0);
  signal tag_cycles_ref : std_logic_vector(27 downto 0);

  -- One of two clocks is used in WR for timestamping: 125MHz or 62.5MHz
  -- This functions translates the cycle count into 125MHz-clock cycles
  -- in the case when 62.5MHz clock is used. As a result, timestamps are
  -- always in the same "clock domain". This is important, e.g. for streamers,
  -- in applicatinos where one WR Node works with 62.5MHz WR clock and
  -- another in 125MHz.
  function f_8ns_cycle_cnt (in_cyc : std_logic_vector; ref_clk : integer)
    return std_logic_vector is
    variable out_cyc : std_logic_vector(27 downto 0);
  begin

    if (ref_clk = 125000000) then
      out_cyc := in_cyc;
    elsif(ref_clk = 62500000) then
      out_cyc := in_cyc(26 downto 0) & '0';
    else
      assert false report
        "The only ref_clk_rate supported: 62.5MHz and 125MHz"
        severity failure;
    end if;

    return out_cyc;

  end f_8ns_cycle_cnt;

begin  -- architecture rtl

    U_sync_reset_ref : gc_sync_ffs
      generic map (
        g_sync_edge => "positive")
      port map (
        clk_i    => clk_ref_i,
        rst_n_i  => '1',
        data_i   => rst_n_i,
        synced_o => rst_n_ref);
    
  
  -- Time tagging of the pulse, still in the clk_ref_i domain
  p_tagger : process (clk_ref_i)
  begin
    if rising_edge(clk_ref_i) then
      if rst_n_ref = '0' then
        pulse_d          <= '0';
        tag_ready_ref    <= '0';
        tag_ready_ref_d  <= '0';
        tag_ready_ref_p1 <= '0';
      else
        pulse_d          <= pulse_i;
        tag_ready_ref_d  <= tag_ready_ref;
        tag_ready_ref_p1 <= not tag_ready_ref_d and tag_ready_ref;

        if pulse_i = '1' and pulse_d = '0' then
          tag_utc_ref        <= tm_tai_i;
          tag_cycles_ref     <= tm_cycles_i;
          tag_time_valid_ref <= tm_time_valid_i;
          tag_ready_ref      <= '1';
        else
          tag_ready_ref <= '0';
        end if;
      end if;
    end if;
  end process;

  U_SyncTagReady : gc_pulse_synchronizer2
    port map (
      clk_in_i    => clk_ref_i,
      rst_in_n_i  => rst_n_ref,
      clk_out_i   => clk_sys_i,
      rst_out_n_i => rst_n_i,
      d_ready_o   => open,
      d_p_i       => tag_ready_ref_p1,
      q_p_o       => tag_ready_sys_p1);

  -- Now we can take the time tags into the clk_sys_i domain
  p_sys_tags : process (clk_sys_i)
  begin
    if rising_edge(clk_sys_i) then
      if rst_n_i = '0' then
        tag_tai_o    <= (others => '0');
        tag_cycles_o <= (others => '0');
        tag_valid_o  <= '0';
        tag_error_o  <= '0';
      elsif tag_ready_sys_p1 = '1' then
        tag_tai_o    <= tag_utc_ref;
        tag_cycles_o <= f_8ns_cycle_cnt(tag_cycles_ref, g_ref_clk_rate);
        tag_valid_o  <= '1';
        tag_error_o  <= not tag_time_valid_ref;
      else
        tag_valid_o <= '0';
      end if;
    end if;
  end process;

end architecture rtl;
