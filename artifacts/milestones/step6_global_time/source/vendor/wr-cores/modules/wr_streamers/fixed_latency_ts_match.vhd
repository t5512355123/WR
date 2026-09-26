--------------------------------------------------------------------------------
-- CERN
-- wr-cores/wr-streamers
-- https://www.ohwr.org/project/wr-cores
--------------------------------------------------------------------------------
--
-- unit name  : fixed_latency_ts_match.vhd
-- author     : Tomasz Wlostowski
-- description:
--
-- Module that "fires" (pulse on match_o) when the current TAI time
-- is exactly input timestamped delayed by input latency, i.e.
-- current_TAI_time = ts_tai_i + ts_cycles_i + ts_latency_i
-- The module includes handling of timeout and "missed deadline", i.e. the
-- situation in which current TAI time is already passed the delayed timestamp.
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

entity fixed_latency_ts_match is
  generic
    (g_clk_ref_rate : integer;
     g_simulation : integer := 0;
     g_sim_cycle_counter_range : integer := 125000000;
     g_use_ref_clock_for_data : integer := 0

     );
  port
    (
      clk_ref_i       : in std_logic;
      clk_data_i      : in std_logic; -- either clk_sys_i or clk_ref_i
      rst_ref_n_i     : in std_logic;
      rst_data_n_i    : in std_logic;

      -- in clk_data (clk_sys_i or clk_ref_i) domain
      arm_p_i         : in std_logic;
      ts_tai_i        : in std_logic_vector(39 downto 0);
      ts_cycles_i     : in std_logic_vector(27 downto 0);

      -- in clk_sys_i domain
      ts_latency_i    : in std_logic_vector(27 downto 0);
      ts_timeout_i    : in std_logic_vector(27 downto 0);

      -- in clk_ref_i domain
      tm_time_valid_i : in std_logic := '0';
      tm_tai_i        : in std_logic_vector(39 downto 0) := x"0000000000";
      -- Fractional part of the second (in clk_ref_i cycles)
      tm_cycles_i     : in std_logic_vector(27 downto 0) := x"0000000";

      -- in clk_data (clk_sys_i or clk_ref_i) domain
      match_p_o       : out std_logic;
      late_p_o        : out std_logic;
      timeout_p_o     : out std_logic
      );

end entity;

architecture rtl of fixed_latency_ts_match is

  type t_state is (IDLE, WRAP_ADJ_TS, CHECK_LATE, WAIT_TRIG);

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

  signal ts_adjusted_cycles : unsigned(28 downto 0);
  signal ts_adjusted_tai    : unsigned(39 downto 0);
  signal ts_timeout_cycles  : unsigned(28 downto 0);
  signal ts_timeout_tai     : unsigned(39 downto 0);

  signal ts_adjusted_cycles_latched : unsigned(28 downto 0);
  signal ts_adjusted_tai_latched    : unsigned(39 downto 0);
  signal ts_timeout_cycles_latched  : unsigned(28 downto 0);
  signal ts_timeout_tai_latched     : unsigned(39 downto 0);

  signal tm_cycles_scaled  : unsigned(28 downto 0);
  signal ts_latency_scaled : unsigned(28 downto 0);
  signal ts_timeout_scaled : unsigned(28 downto 0);

  signal tm_cycles_scaled_d : unsigned(28 downto 0);
  signal tm_tai_d           : unsigned(39 downto 0);

  signal match, late, timeout         : std_logic;
  signal state                        : t_state;
  signal trig                         : std_logic;
  signal arm_synced_p, arm_synced_p_d : std_logic;
  signal wait_cnt                     : unsigned(23 downto 0);
  signal int_del_corr                 : unsigned(27 downto 0);

begin

  process(clk_ref_i)
  begin
    if rising_edge(clk_ref_i) then
      tm_cycles_scaled_d <= tm_cycles_scaled;
      tm_tai_d           <= unsigned(tm_tai_i);
    end if;
  end process;

  -- Compensate for internal delays of streamers. The reference signals are
  -- rx_valid_o and tx_valid_i in xwr_streamers. The numbers were obtained
  -- by measuring the delay between these two signal in simulation and in
  -- hardware. The delay depends whether the ref_clk is used for data or not.
  -- NOTE: the compensation values are in a range that is unlikely to be set
  -- as desired fixed_latency, thus the corrected value of fixed_latency
  -- will be still a positive value. No need for prevention means (additinal
  -- 'if').
  gen_data_synchronous_to_wr_corr : if g_use_ref_clock_for_data /= 0 generate
    int_del_corr <= to_unsigned(3, 28);
  end generate ;

  gen_data_asynchronous_to_wr_corr : if g_use_ref_clock_for_data = 0 generate
    int_del_corr <= to_unsigned(12, 28);
  end generate ;

  -- clk_ref_i domain: tm_cycles_i
  -- sys_clk   domain: ts_latency_i & ts_timeout_i
  -- scale the cycle counts depending what clack is used as ref_clk.
  -- The software input assumes 125MHz clock (8ns cycle).
  process(tm_cycles_i, ts_latency_i, ts_timeout_i)
  begin
    if g_clk_ref_rate = 62500000 then
      tm_cycles_scaled <= unsigned(tm_cycles_i & '0');
      ts_latency_scaled <= unsigned(ts_latency_i & '0') - unsigned(int_del_corr & '0');
      ts_timeout_scaled <= unsigned(ts_timeout_i & '0');
    elsif g_clk_ref_rate = 125000000 then
      tm_cycles_scaled <= unsigned('0' & tm_cycles_i);
      ts_latency_scaled <= unsigned('0' & ts_latency_i) - unsigned('0' & int_del_corr);
      ts_timeout_scaled <= unsigned('0' & ts_timeout_i);
    else
      report "Unsupported g_clk_ref_rate (62.5 / 125 MHz)" severity failure;
    end if;
  end process;

  --ML: this seems unsed
  process(clk_ref_i)
  begin
    if rising_edge(clk_ref_i) then
      if rst_ref_n_i = '0' then
        wait_cnt <= (others => '0');
        trig     <= '0';
      else

        case State is
          when IDLE =>
            wait_cnt <= (others => '0');
            trig     <= '0';

          when others =>
            wait_cnt <= wait_cnt + 1;

            if wait_cnt = 3000 then
              trig <= '1';
            end if;
        end case;
      end if;
    end if;
  end process;

  ------------------------------------------------------------------------------
  -- FSM that always works in clk_ref_i domain because it compares the current
  -- WR TAI/cycles value with the expected value whent the fixed-latency is
  -- reached. It also handles the cases when 
  -- 1) it's already too late, in such case it notifies with late_o
  -- 2) the latency was not achieved in a configured timeout amount of time,
  --    in such case it notifies with timeout_p_o
  -- If all goes well and the delayed TAI/cycles were reached, it notifes with
  -- match_p_o
  ------------------------------------------------------------------------------
  process(clk_ref_i)
  begin
    if rising_edge(clk_ref_i) then
      if rst_ref_n_i = '0' then
        late <= '0';
        match  <= '0';
        State  <= IDLE;

      else

        case State is
          when IDLE =>
            match   <= '0';
            late    <= '0';
            timeout <= '0';

            -- save the configuration when starting to receive frame to be 
            -- fixed-latency delayed
            if arm_synced_p_d = '1' then
              ts_adjusted_tai    <= ts_adjusted_tai_latched;
              ts_adjusted_cycles <= ts_adjusted_cycles_latched;
              ts_timeout_tai     <= ts_timeout_tai_latched;
              ts_timeout_cycles  <= ts_timeout_cycles_latched;
              State              <= WRAP_ADJ_TS;
            end if;

          when WRAP_ADJ_TS =>
            -- adjust TAI seconds if the delayed latency timestamp is in the next TAI second
            if ts_adjusted_cycles >= f_cycles_counter_range then
              ts_adjusted_cycles <= ts_adjusted_cycles - f_cycles_counter_range;
              ts_adjusted_tai    <= ts_adjusted_tai + 1;
            end if;

            -- adjust TAI seconds if the delayed timeout timestamp is in the next TAI second
            if ts_timeout_cycles >= f_cycles_counter_range then
              ts_timeout_cycles  <= ts_timeout_cycles - f_cycles_counter_range;
              ts_timeout_tai     <= ts_timeout_tai + 1;
            end if;

            state <= CHECK_LATE;

          when CHECK_LATE => -- handle all the late cases

            -- if the time is temporarily incorrect, we assume we are late, send the info out
            if tm_time_valid_i = '0' then
              late  <= '1';
              state <= IDLE;
            end if;

             -- if we are in the future relateive to the delayed timestamp, we are definitely late
            if ts_adjusted_tai < tm_tai_d then
              late  <= '1';
              State <= IDLE;
            elsif ts_adjusted_tai = tm_tai_d and ts_adjusted_cycles <= tm_cycles_scaled_d then
              late  <= '1';
              State <= IDLE;
            else
              State <= WAIT_TRIG;
            end if;

          when WAIT_TRIG => -- wait for the correct timestamp for exposing the data, or timeout

            if tm_tai_d > ts_timeout_tai or
              (ts_timeout_tai = tm_tai_d and tm_cycles_scaled_d > ts_timeout_cycles) then
              timeout <= '1';
              State   <= IDLE;
            end if;

            if ts_adjusted_cycles = tm_cycles_scaled_d and ts_adjusted_tai = tm_tai_d then
              match <= '1';
              State <= IDLE;
            end if;

        end case;
      end if;
    end if;
  end process;

  ------------------------------------------------------------------------------
  -- clk_data_i == clk_ref_i | data is in the ref_clk domain
  ------------------------------------------------------------------------------
  gen_data_synchronous_to_wr : if g_use_ref_clock_for_data /= 0 generate
    match_p_o    <= match;
    late_p_o     <= late;
    timeout_p_o  <= timeout;
    arm_synced_p <= arm_p_i;

    process(clk_ref_i)
    begin
      if rising_edge(clk_ref_i) then

        arm_synced_p_d <= arm_synced_p;
        if arm_synced_p = '1' then
          ts_adjusted_cycles_latched <= resize(unsigned(ts_cycles_i) + unsigned(ts_latency_scaled), 29);
          ts_adjusted_tai_latched    <= resize(unsigned(ts_tai_i), 40);
          ts_timeout_cycles_latched  <= resize(unsigned(ts_cycles_i) + unsigned(ts_timeout_scaled), 29);
          ts_timeout_tai_latched     <= resize(unsigned(ts_tai_i), 40);
        end if;
      end if;
    end process;
    
  end generate;

  ------------------------------------------------------------------------------
  -- clk_data_i != clk_ref_i | data is in the sys_clk domain
  ------------------------------------------------------------------------------
  gen_data_asynchronous_to_wr : if g_use_ref_clock_for_data = 0 generate

    U_Sync1: entity work.gc_pulse_synchronizer2
      port map (
        clk_in_i    => clk_data_i,
        clk_out_i   => clk_ref_i,
        rst_in_n_i  => rst_data_n_i,
        rst_out_n_i => rst_ref_n_i,
        d_ready_o   => open,
        d_p_i       => arm_p_i,
        q_p_o       => arm_synced_p_d);

    U_Sync2: entity work.gc_pulse_synchronizer2
      port map (
        clk_in_i    => clk_ref_i,
        clk_out_i   => clk_data_i,
        rst_in_n_i  => rst_ref_n_i,
        rst_out_n_i => rst_data_n_i,
        d_ready_o   => open,
        d_p_i       => match,
        q_p_o       => match_p_o);

    U_Sync3: entity work.gc_pulse_synchronizer2
      port map (
        clk_in_i    => clk_ref_i,
        clk_out_i   => clk_data_i,
        rst_in_n_i  => rst_ref_n_i,
        rst_out_n_i => rst_data_n_i,
        d_ready_o   => open,
        d_p_i       => late,
        q_p_o       => late_p_o);

    U_Sync4: entity work.gc_pulse_synchronizer2
      port map (
        clk_in_i    => clk_ref_i,
        clk_out_i   => clk_data_i,
        rst_in_n_i  => rst_ref_n_i,
        rst_out_n_i => rst_data_n_i,
        d_ready_o   => open,
        d_p_i       => timeout,
        q_p_o       => timeout_p_o);

    process(clk_data_i)
    begin
      if rising_edge(clk_data_i) then
        if arm_p_i = '1' then
          ts_adjusted_cycles_latched <= resize(unsigned(ts_cycles_i) + unsigned(ts_latency_scaled), 29);
          ts_adjusted_tai_latched    <= resize(unsigned(ts_tai_i), 40);
          ts_timeout_cycles_latched  <= resize(unsigned(ts_cycles_i) + unsigned(ts_timeout_scaled), 29);
          ts_timeout_tai_latched     <= resize(unsigned(ts_tai_i), 40);
        end if;
      end if;
    end process;
  end generate;

end rtl;
