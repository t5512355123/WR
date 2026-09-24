--------------------------------------------------------------------------------
-- CERN
-- wr-cores/wr-streamers
-- https://www.ohwr.org/project/wr-cores
--------------------------------------------------------------------------------
--
-- unit name  : fixed_latency_delay.vhd
-- author     : Tomasz Wlostowski
-- description:
--
-- This module delays incoming data until the configured fixed
-- latency. The delayed data is stored in a dropping FIFO.
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
use work.genram_pkg.all;
use work.streamers_priv_pkg.all;
use work.streamers_pkg.all;

entity fixed_latency_delay is
  generic(
    g_data_width             : integer;
    g_buffer_size : integer;
    g_use_ref_clock_for_data : integer;
    g_clk_ref_rate           : integer;
    g_simulation             : integer := 0;
    g_sim_cycle_counter_range: integer := 125000000
    );
  port(
    rst_n_i : in std_logic;
    clk_sys_i : in std_logic;
    clk_ref_i : in std_logic;

    -- timing I/F, clk_ref_i clock domain
    tm_time_valid_i : in std_logic;
    tm_tai_i : in std_logic_vector(39 downto 0);
    tm_cycles_i     : in std_logic_vector(27 downto 0);

    -- input i/f (dropping buffer)
    d_data_i         : in std_logic_vector(g_data_width-1 downto 0);
    d_last_i         : in std_logic;
    d_sync_i         : in std_logic;
    d_target_ts_en_i : in std_logic;
    d_target_ts_tai_i    : in std_logic_vector(39 downto 0);
    d_target_ts_cycles_i : in std_logic_vector(27 downto 0);
    d_target_ts_error_i  : in std_logic;

    d_valid_i  : in  std_logic;
    d_drop_i   : in  std_logic;
    d_accept_i : in  std_logic;
    d_req_o    : out std_logic;
    d_full_o   : out std_logic;

    -- output data path (clk_ref_i/clk_sys_i clock domain for
    -- g_use_ref_clock_for_data = 1/0 respectively)
    rx_first_p1_o : out std_logic;
    rx_last_p1_o  : out std_logic;
    rx_data_o     : out std_logic_vector(g_data_width-1 downto 0);
    rx_valid_o    : out std_logic;
    rx_dreq_i     : in  std_logic;
    rx_late_o     : out std_logic;
    rx_timeout_o  : out std_logic;

    -- SYS clock domain
    stat_match_p1_o   : out std_logic;
    stat_late_p1_o    : out std_logic;
    stat_timeout_p1_o : out std_logic;

    rx_streamer_cfg_i : in t_rx_streamer_cfg
    );

end entity;

architecture rtl of fixed_latency_delay is

  type t_state is (IDLE, TS_SETUP_MATCH, TS_WAIT_MATCH, SEND);

  signal State: t_state;

  signal rst_n_ref : std_logic;
  signal wr_full            : std_logic;
  constant c_datapath_width : integer := g_data_width + 2 + 28 + 40 + 1 + 1;

  signal fifo_rd    : std_logic;

  signal dbuf_d : std_logic_vector(c_datapath_width-1 downto 0);
  signal dbuf_q : std_logic_vector(c_datapath_width-1 downto 0);
  signal fifo_q                                  : std_logic_vector(c_datapath_width-1 downto 0);
  signal dbuf_q_valid : std_logic;
  signal dbuf_req : std_logic;
  signal fifo_data                               : std_logic_vector(g_data_width-1 downto 0);
  signal fifo_sync, fifo_last, fifo_target_ts_en : std_logic;
  signal fifo_target_ts                          : std_logic_vector(27 downto 0);
  signal fifo_empty                              : std_logic;
  signal fifo_we                                 : std_logic;
  signal fifo_valid                              : std_logic;
  signal rx_valid : std_logic;

  signal delay_arm_p : std_logic;
  signal delay_match_p : std_logic;
  signal delay_miss_p : std_logic;
  signal delay_timeout_p : std_logic;

  signal fifo_target_ts_error : std_logic;
  signal fifo_target_ts_tai : std_logic_vector(39 downto 0);
  signal fifo_target_ts_cycles : std_logic_vector(27 downto 0);  

  signal clk_data : std_logic;
  signal rst_n_data : std_logic;

begin

  U_SyncReset_to_RefClk : gc_sync_ffs
    port map (
      clk_i    => clk_ref_i,
      rst_n_i  => '1',
      data_i   => rst_n_i,
      synced_o => rst_n_ref);

  -- choose which clock to use as clk_data
  clk_data   <= clk_sys_i when g_use_ref_clock_for_data = 0 else clk_ref_i;
  rst_n_data <= rst_n_i   when g_use_ref_clock_for_data = 0 else rst_n_ref;

  -- Pack input data to the FIFO in clk_sys_i clock domain
  dbuf_d(g_data_width-1 downto 0)                       <= d_data_i;
  dbuf_d(g_data_width)                                  <= d_last_i;
  dbuf_d(g_data_width+1)                                <= d_sync_i;
  dbuf_d(g_data_width+2)                                <= d_target_ts_en_i;
  dbuf_d(g_data_width+3+27 downto g_data_width+3)       <= d_target_ts_cycles_i;
  dbuf_d(g_data_width+3+28+39 downto g_data_width+3+28) <= d_target_ts_tai_i;
  dbuf_d(g_data_width+3+28+40)                          <= d_target_ts_error_i;

  U_DropBuffer : entity work.dropping_buffer
    generic map (
      g_size       => g_buffer_size,
      g_data_width => c_datapath_width)
    port map (
      clk_i      => clk_sys_i,
      rst_n_i    => rst_n_i,
      d_i        => dbuf_d,
      d_req_o    => d_req_o,
      d_drop_i   => d_drop_i,
      d_accept_i => d_accept_i,
      d_valid_i  => d_valid_i,
      d_full_o   => d_full_o,
      d_o        => dbuf_q,
      d_valid_o  => dbuf_q_valid,
      d_req_i    => dbuf_req);

  dbuf_req <= not wr_full;
  fifo_we  <= dbuf_q_valid and not wr_full;

  U_ClockSyncFifo : generic_async_fifo
    generic map (
      g_data_width => c_datapath_width,
      g_size       => 16,
      g_show_ahead => false)
    port map (
      rst_n_i    => rst_n_i,
      clk_wr_i   => clk_sys_i,
      d_i        => dbuf_q,
      we_i       => dbuf_q_valid,
      wr_full_o  => wr_full,
      clk_rd_i   => clk_data,
      q_o        => fifo_q,
      rd_i       => fifo_rd,
      rd_empty_o => fifo_empty);

  -- FSM that controls the readout from the FIFO and the delaying of
  -- exposing the data to the user.
  p_fsm_seq: process(clk_data)
  begin
    if rising_edge(clk_data) then
      if rst_n_data = '0' then
        state <= IDLE;
        fifo_valid <= '0';
      else

        if fifo_rd = '1' and fifo_empty = '0' then
          fifo_valid <= '1';
        elsif rx_valid = '1' then
          fifo_valid <= '0';
        end if;

        case state is
          -- wait for data to come
          when IDLE =>
            if fifo_empty = '0' then
              state <= TS_SETUP_MATCH;
            end if;

          -- decide whether to delay the release of data or not, based on config
          when TS_SETUP_MATCH =>
            if fifo_valid = '1' then
              if fifo_target_ts_en = '1' and fifo_target_ts_error = '0' then
                state <= TS_WAIT_MATCH;
              else
                state <= SEND;
              end if;
            end if;

          -- wait for the correct time (fixed-delay per config)
          when TS_WAIT_MATCH =>
            if delay_miss_p = '1' or delay_match_p = '1' or delay_timeout_p = '1' then
              if fifo_last = '1' and fifo_empty = '0' then
                state <= TS_SETUP_MATCH;
              else
                state <= SEND;
              end if;

            end if;

          -- provide the data to the user
          when SEND =>
            if fifo_last = '1' and fifo_valid = '1' then
              if fifo_empty = '1' then
                state <= IDLE; -- nothing in the FIFO
              else
                state <= TS_SETUP_MATCH; -- new frame
              end if;
            elsif fifo_empty = '1' then
              state <= IDLE; -- nothing in the FIFO
            end if;
        end case;
      end if;
    end if;
  end process;

  -- the module that is used when fixed-delay is requested. In notifies
  -- the FSM when the configured fixed-latency has expired.
  U_Compare: entity work.fixed_latency_ts_match
    generic map (
      g_clk_ref_rate            => g_clk_ref_rate,
      g_sim_cycle_counter_range => g_sim_cycle_counter_range,
      g_simulation              => g_simulation,
      g_use_ref_clock_for_data  => g_use_ref_clock_for_data)
    port map (
      clk_ref_i       => clk_ref_i,
      clk_data_i      => clk_data,
      rst_ref_n_i     => rst_n_ref,
      rst_data_n_i    => rst_n_data,

      -- in clk_data (clk_sys_i or clk_ref_i) domain
      arm_p_i         => delay_arm_p,
      ts_tai_i        => fifo_target_ts_tai,
      ts_cycles_i     => fifo_target_ts_cycles,

      -- in clk_sys_i domain
      ts_latency_i    => rx_streamer_cfg_i.fixed_latency,
      ts_timeout_i    => rx_streamer_cfg_i.fixed_latency_timeout,

      -- in clk_ref_i domain
      tm_time_valid_i => tm_time_valid_i,
      tm_tai_i        => tm_tai_i,
      tm_cycles_i     => tm_cycles_i,

      -- in clk_data (clk_sys_i or clk_ref_i) domain
      timeout_p_o     => delay_timeout_p,
      match_p_o       => delay_match_p,
      late_p_o        => delay_miss_p);

  -- combinatorial part of the above FSM
  p_fsm_comb: process(state, rx_dreq_i, fifo_empty, delay_miss_p, fifo_last, delay_match_p, delay_timeout_p, fifo_target_ts_en, fifo_valid)
  begin
    case state is
      when IDLE =>
        delay_arm_p  <= '0';
        fifo_rd      <= not fifo_empty;
        rx_valid     <= '0';
        rx_late_o    <= '0';
        rx_timeout_o <= '0';

      when TS_SETUP_MATCH =>
        delay_arm_p  <= fifo_valid and fifo_target_ts_en and not fifo_target_ts_error;
        fifo_rd      <= '0';
        rx_valid     <= '0';
        rx_late_o    <= '0';
        rx_timeout_o <= '0';

      when TS_WAIT_MATCH =>
        delay_arm_p  <= '0';
        fifo_rd      <= (delay_match_p or delay_miss_p or delay_timeout_p) and not fifo_empty;
        rx_valid     <= delay_match_p or delay_miss_p;
        rx_late_o    <= delay_miss_p;
        rx_timeout_o <= delay_timeout_p;

      when SEND =>
        delay_arm_p  <= '0';
        fifo_rd      <= (rx_dreq_i or (fifo_last and fifo_valid)) and not fifo_empty;
        rx_valid     <= fifo_valid;
        rx_late_o    <= '0';
        rx_timeout_o <= '0';

    end case;
  end process;

  -----------------------------------------------------------------------------
  -- synchronize signals for stats counters that are in clk_sys_i domain
  -----------------------------------------------------------------------------
  U_Sync_RXMatch_Pulse : gc_pulse_synchronizer2
    port map (
      clk_in_i    => clk_data,
      rst_in_n_i  => rst_n_data,
      clk_out_i   => clk_sys_i,
      rst_out_n_i => rst_n_i,
      d_p_i       => delay_match_p,
      q_p_o       => stat_match_p1_o);

  U_Sync_RXLate_Pulse : gc_pulse_synchronizer2
    port map (
      clk_in_i    => clk_data,
      rst_in_n_i  => rst_n_data,
      clk_out_i   => clk_sys_i,
      rst_out_n_i => rst_n_i,
      d_p_i       => delay_miss_p,
      q_p_o       => stat_late_p1_o);

  U_Sync_RXTimeout_Pulse : gc_pulse_synchronizer2
    port map (
      clk_in_i    => clk_data,
      rst_in_n_i  => rst_n_data,
      clk_out_i   => clk_sys_i,
      rst_out_n_i => rst_n_i,
      d_p_i       => delay_timeout_p,
      q_p_o       => stat_timeout_p1_o);

  -- decode the data from FIFO in clk_data_i (clk_ref_i or clk_sys_i) domain
  fifo_data             <= fifo_q(g_data_width-1 downto 0);
  fifo_last             <= fifo_q(g_data_width);
  fifo_sync             <= fifo_q(g_data_width+1);
  fifo_target_ts_en     <= fifo_q(g_data_width+2);
  fifo_target_ts_cycles <= fifo_q(g_data_width+3+27 downto g_data_width+3);
  fifo_target_ts_tai    <= fifo_q(g_data_width+3+28+39 downto g_data_width+3+28);
  fifo_target_ts_error  <= fifo_q(g_data_width+3+28+40);

  -- signals that are outputs to the user
  rx_data_o     <= fifo_data;
  rx_valid_o    <= rx_valid;
  rx_first_p1_o <= fifo_sync and rx_valid;
  rx_last_p1_o  <= fifo_last and rx_valid;

end rtl;
