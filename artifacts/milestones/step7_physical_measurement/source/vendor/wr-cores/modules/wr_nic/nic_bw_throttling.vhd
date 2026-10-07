-------------------------------------------------------------------------------
-- Title      : Rx bandwidth throttling
-- Project    : WhiteRabbit Switch
-------------------------------------------------------------------------------
-- File       : nic_bw_throttling.vhd
-- Author     : Grzegorz Daniluk
-- Company    : CERN BE-Co-HT
-- Created    : 2016-07-28
-- Platform   : FPGA-generic
-- Standard   : VHDL
-------------------------------------------------------------------------------
-- Description:
-- Module implementing Random Early Detection algorithm for throttling the
-- bandwidth of RX traffic on NIC.
-------------------------------------------------------------------------------
--
-- Copyright (c) 2016 CERN / BE-CO-HT
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
-- Revisions  :
-- Date        Version  Author          Description
-- 2016-08-01  1.0      greg.d          Created
-------------------------------------------------------------------------------
library IEEE;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.wr_fabric_pkg.all;

entity nic_bw_throttling is
  port (
    clk_sys_i   : in  std_logic;
    rst_n_i     : in  std_logic;

    pps_p_i     : in std_logic;
    pps_valid_i : in std_logic;

    snk_i   : in  t_wrf_sink_in;
    snk_o   : out t_wrf_sink_out;
    src_o   : out t_wrf_source_out;
    src_i   : in  t_wrf_source_in;

    en_i         : in std_logic;
    new_limit_i  : in std_logic;
    bwmax_kbps_i : in  unsigned(15 downto 0);
    bw_bps_o     : out std_logic_vector(31 downto 0));
end nic_bw_throttling;

architecture behav of nic_bw_throttling is

  signal bw_bps_cnt : unsigned(31 downto 0);
  signal is_data    : std_logic;
  signal src_out    : t_wrf_source_out;

  signal drop_frame : std_logic;
  type t_fwd_fsm is (WAIT_FRAME, FLUSH, PASS, DROP);
  signal state_fwd : t_fwd_fsm;
  signal wrf_reg   : t_wrf_sink_in;

  signal rnd_reg  : unsigned(7 downto 0);

  constant c_LFSR_START   : unsigned(7 downto 0) := x"A5";
  constant c_DROP_STEP    : unsigned(7 downto 0) := x"20"; --32
  constant c_DROP_THR_MAX : unsigned(8 downto 0) := to_unsigned(256, 9);
  signal drop_thr   : unsigned(8 downto 0); -- 1 more bit than rnd_reg
  -- so that we can have drop_thr larger than any random number and drop the
  -- whole traffic.
  signal bwmin_kbps    : unsigned(15 downto 0);
  signal bwcur_kbps    : unsigned(31 downto 0);
  signal last_thr_kbps : unsigned(31 downto 0);
  signal thr_step_kbps : unsigned(15 downto 0);

begin

  -------------------------------------------------
  --      Pseudo-random number generation        --
  --   based on LSFR x^8 + x^6 + x^5 + x^4 + 1   --
  -------------------------------------------------
  process(clk_sys_i)
  begin
    if rising_edge(clk_sys_i) then
      if rst_n_i = '0' then
        rnd_reg(7 downto 0) <= c_LFSR_START;
      else
        rnd_reg(0) <= rnd_reg(7) xor rnd_reg(5) xor rnd_reg(4) xor rnd_reg(3);
        rnd_reg(7 downto 1) <= rnd_reg(6 downto 0);
      end if;
    end if;
  end process;


  -------------------------------------------------
  -- Monitoring b/w and generating drop decisions--
  -------------------------------------------------
  drop_frame <= '1' when (rnd_reg < drop_thr) else
                '0';

  -- set min b/w from which we start the throttling
  -- set it to half of the required max b/w
  bwmin_kbps <= shift_right(bwmax_kbps_i, 1);

  -- convert current b/w to KBps
  -- it's bw_bps_cnt divided by 1024 (2^10)
  bwcur_kbps <= shift_right(bw_bps_cnt, 10);
  
  process(clk_sys_i)
  begin
    if rising_edge(clk_sys_i) then
      if rst_n_i = '0' or new_limit_i = '1' then
        drop_thr      <= (others=>'0');
        last_thr_kbps <= x"0000" & bwmin_kbps;
        thr_step_kbps <= shift_right(bwmax_kbps_i - bwmin_kbps, 3);
      -- both max and min b/w we divide by 8 (because we want 8 steps like with
      -- c_DROP_STEP = 64 for range 0-255)
      elsif en_i = '1' then
        if (bwcur_kbps > last_thr_kbps and drop_thr < c_DROP_THR_MAX) then
        -- current b/w is larger than the last crossed threshold
        -- we increase the probability of drop
          drop_thr      <= drop_thr + c_DROP_STEP;
          last_thr_kbps <= last_thr_kbps + thr_step_kbps;

        elsif (bwcur_kbps + thr_step_kbps < last_thr_kbps and drop_thr > 0) then
        -- current b/w has dropped below the last crossed threshold,
        -- we decrease the probability of drop
          drop_thr      <= drop_thr - c_DROP_STEP;
          last_thr_kbps <= last_thr_kbps - thr_step_kbps;
        end if;

      else
        -- If the module is disabled, keep drop_thr at 0 so that we don't drop
        -- any frames.
        drop_thr <= (others=>'0');

      end if;
    end if;
  end process;


  -------------------------------------------------
  --        Forwarding or dropping frames        --
  -------------------------------------------------
  process(clk_sys_i)
  begin
    if rising_edge(clk_sys_i) then
      if rst_n_i = '0' then
        state_fwd <= WAIT_FRAME;
        wrf_reg <= c_dummy_snk_in;

        snk_o   <= c_dummy_src_in;
        src_out <= c_dummy_snk_in;
      else
        case state_fwd is
          when WAIT_FRAME =>
            snk_o.ack   <= '0';
            snk_o.err   <= '0';
            snk_o.rty   <= '0';
            src_out     <= c_dummy_snk_in;
            if (snk_i.cyc='1' and snk_i.stb='1') then
              -- new frame is transmitted
              snk_o.stall <= '1';
              wrf_reg <= snk_i;

              if (drop_frame = '0') then
                state_fwd <= FLUSH;
              elsif (drop_frame = '1') then
                state_fwd <= DROP;
              end if;
            else
              snk_o.stall <= '0';
            end if;

          when FLUSH =>
            -- flush wrf_reg stored on stall or in WAIT_FRAME
            snk_o <= src_i;
            if (src_i.stall = '0') then
              src_out   <= wrf_reg;
              state_fwd <= PASS;
            end if;

          when PASS =>
            snk_o <= src_i;
            if (src_i.stall = '0') then
              src_out <= snk_i;
              if (snk_i.cyc='0' and snk_i.stb='0') then
                state_fwd <= WAIT_FRAME;
              end if;
            else
              wrf_reg   <= snk_i;
              state_fwd <= FLUSH;
            end if;

          when DROP =>
            -- ack everything from SNK, pass nothing to SRC
            snk_o.stall <= '0';
            snk_o.err   <= '0';
            snk_o.rty   <= '0';
            src_out     <= c_dummy_snk_in;
            if (snk_i.stb='1') then
              snk_o.ack <= '1';
            else
              snk_o.ack <= '0';
            end if;

            if (snk_i.cyc='0' and snk_i.stb='0') then
              state_fwd <= WAIT_FRAME;
            end if;
        end case;
      end if;
    end if;
  end process;

  src_o <= src_out;

  -------------------------------------------------
  -- Calculating bandwidth actually going to ARM --
  -------------------------------------------------

  is_data <= '1' when (src_out.adr=c_WRF_DATA and src_out.cyc='1' and src_out.stb='1' and src_i.stall='0') else
             '0';

  process(clk_sys_i)
  begin
    if rising_edge(clk_sys_i) then
      if rst_n_i = '0' or pps_valid_i = '0' then
        bw_bps_cnt   <= (others=>'0');
        bw_bps_o <= (others=>'0');
      elsif pps_p_i = '1' then
        bw_bps_cnt   <= (others=>'0');
        bw_bps_o <= std_logic_vector(bw_bps_cnt);
      elsif is_data = '1' then
        -- we count incoming bytes here
        if src_out.sel(0) = '1' then
          -- 16bits carry valid data
          bw_bps_cnt <= bw_bps_cnt + 2;
        elsif src_out.sel(0) = '0' then
          -- only 8bits carry valid data
          bw_bps_cnt <= bw_bps_cnt + 1;
        end if;
      end if;
    end if;
  end process;
  
end behav;
