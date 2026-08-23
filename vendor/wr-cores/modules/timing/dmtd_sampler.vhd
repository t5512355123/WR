-------------------------------------------------------------------------------
-- Title      : Digital DMTD (just the sampler)
-- Project    : White Rabbit
-------------------------------------------------------------------------------
-- File       : dmtd_sampler.vhd
-- Author     : Tomasz Wlostowski
-- Company    : CERN BE-Co-HT
-- Created    : 2010-02-25
-- Platform   : FPGA-generic
-- Standard   : VHDL '93
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
--
-- Copyright (c) 2009 - 2011 CERN
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
use ieee.NUMERIC_STD.all;

library work;
use work.gencores_pkg.all;

entity dmtd_sampler is
  generic (
    -- Divides the inputs by 2 (effectively passing the clock through a flip flop)
    -- before it gets to the DMTD, effectively removing Place&Route warnings
    -- (at the cost of detector bandwidth)
    g_divide_input_by_2 : boolean := false;

    -- reversed mode: samples clk_dmtd_i with clk_in_i.
    g_reverse : boolean := false;

    -- enables oversampling: in this case, clk_dmtd_over_i is used and the
    -- divider for picking the DDMTD tags must be supplied through r_oversample_div_i.
    g_with_oversampling : boolean := false
    );
  port (
    -- input clock
    clk_in_i : in std_logic;

    en_i : in std_logic := '1';

    -- DMTD sampling clock
    clk_dmtd_i : in std_logic;
    clk_dmtd_over_i : in std_logic := '0';

    -- Sync signal. if g_with_oversampling == TRUE, must be provided in the
    -- lk_dmtd_over_i clock domain
    sync_p1_i : in std_logic := '0';

    r_oversample_div_i : in std_logic_vector(5 downto 0) := (others => '0');

    -- Read-only diagnostic reset. This does not participate in the sampler
    -- data path; the default preserves standalone legacy instantiations.
    rst_n_i : in std_logic := '1';

    clk_sampled_o : out std_logic;
    -- Maximum consecutive HIGH samples of clk_in before the sampler pipeline.
    dbg_input_high_run_max_o : out std_logic_vector(15 downto 0);
    -- Maximum consecutive LOW samples of clk_in before the sampler pipeline.
    dbg_input_low_run_max_o : out std_logic_vector(15 downto 0);
    -- Maximum consecutive HIGH samples of clk_i_d1 after inversion/enable.
    -- This is read-only observability and does not feed clk_sampled_o.
    dbg_d1_high_run_max_o : out std_logic_vector(15 downto 0)
    );

end dmtd_sampler;

architecture rtl of dmtd_sampler is


  signal clk_in                                           : std_logic := '0';
  signal clk_i_d0, clk_i_d1, clk_i_d2, clk_i_d3, clk_i_dx : std_logic;

  attribute keep             : string;
  attribute keep of clk_in   : signal is "true";
  attribute keep of clk_i_d0 : signal is "true";
  attribute keep of clk_i_d1 : signal is "true";
  attribute keep of clk_i_d2 : signal is "true";
  attribute keep of clk_i_d3 : signal is "true";

  signal over_div_cnt : unsigned(5 downto 0);
  signal sync_p1_d : std_logic;
  signal over_div_p : std_logic;

  signal en_i_d0 : std_logic;

  signal dbg_input_high_run     : unsigned(15 downto 0) := (others => '0');
  signal dbg_input_high_run_max : unsigned(15 downto 0) := (others => '0');
  signal dbg_input_low_run      : unsigned(15 downto 0) := (others => '0');
  signal dbg_input_low_run_max  : unsigned(15 downto 0) := (others => '0');
  signal dbg_d1_high_run        : unsigned(15 downto 0) := (others => '0');
  signal dbg_d1_high_run_max    : unsigned(15 downto 0) := (others => '0');

  function f_sat_inc(value : unsigned) return unsigned is
    variable result  : unsigned(value'range) := value;
    variable maximum : unsigned(value'range);
  begin
    maximum := (others => '1');
    if value /= maximum then
      result := value + 1;
    end if;
    return result;
  end function;
  
begin  -- rtl

  -- This observation is deliberately outside the functional sampler and
  -- deglitcher logic. It records the longest run of sampled HIGH input levels
  -- seen at the sampler clock, so a short run is distinguishable from a
  -- later pipeline/inversion problem.
  dbg_input_high_run_max_o <= std_logic_vector(dbg_input_high_run_max);
  dbg_input_low_run_max_o <= std_logic_vector(dbg_input_low_run_max);
  dbg_d1_high_run_max_o <= std_logic_vector(dbg_d1_high_run_max);

  gen_debug_input_run_dmtd : if g_with_oversampling = false generate
    p_debug_input_run : process(clk_dmtd_i)
      variable next_run : unsigned(15 downto 0);
      variable next_d1_run : unsigned(15 downto 0);
    begin
      if rising_edge(clk_dmtd_i) then
        if rst_n_i = '0' then
          dbg_input_high_run <= (others => '0');
          dbg_input_high_run_max <= (others => '0');
          dbg_input_low_run <= (others => '0');
          dbg_input_low_run_max <= (others => '0');
          dbg_d1_high_run <= (others => '0');
          dbg_d1_high_run_max <= (others => '0');
        elsif clk_in = '1' then
          next_run := f_sat_inc(dbg_input_high_run);
          dbg_input_high_run <= next_run;
          if next_run > dbg_input_high_run_max then
            dbg_input_high_run_max <= next_run;
          end if;
          dbg_input_low_run <= (others => '0');
        else
          dbg_input_high_run <= (others => '0');
          next_run := f_sat_inc(dbg_input_low_run);
          dbg_input_low_run <= next_run;
          if next_run > dbg_input_low_run_max then
            dbg_input_low_run_max <= next_run;
          end if;
        end if;

        if rst_n_i = '0' then
          dbg_d1_high_run <= (others => '0');
          dbg_d1_high_run_max <= (others => '0');
        elsif clk_i_d1 = '1' then
          next_d1_run := f_sat_inc(dbg_d1_high_run);
          dbg_d1_high_run <= next_d1_run;
          if next_d1_run > dbg_d1_high_run_max then
            dbg_d1_high_run_max <= next_d1_run;
          end if;
        else
          dbg_d1_high_run <= (others => '0');
        end if;
      end if;
    end process;
  end generate gen_debug_input_run_dmtd;

  gen_debug_input_run_over : if g_with_oversampling = true generate
    p_debug_input_run : process(clk_dmtd_over_i)
      variable next_run : unsigned(15 downto 0);
      variable next_d1_run : unsigned(15 downto 0);
    begin
      if rising_edge(clk_dmtd_over_i) then
        if rst_n_i = '0' then
          dbg_input_high_run <= (others => '0');
          dbg_input_high_run_max <= (others => '0');
          dbg_input_low_run <= (others => '0');
          dbg_input_low_run_max <= (others => '0');
          dbg_d1_high_run <= (others => '0');
          dbg_d1_high_run_max <= (others => '0');
        elsif clk_in = '1' then
          next_run := f_sat_inc(dbg_input_high_run);
          dbg_input_high_run <= next_run;
          if next_run > dbg_input_high_run_max then
            dbg_input_high_run_max <= next_run;
          end if;
          dbg_input_low_run <= (others => '0');
        else
          dbg_input_high_run <= (others => '0');
          next_run := f_sat_inc(dbg_input_low_run);
          dbg_input_low_run <= next_run;
          if next_run > dbg_input_low_run_max then
            dbg_input_low_run_max <= next_run;
          end if;
        end if;

        if rst_n_i = '0' then
          dbg_d1_high_run <= (others => '0');
          dbg_d1_high_run_max <= (others => '0');
        elsif clk_i_d1 = '1' then
          next_d1_run := f_sat_inc(dbg_d1_high_run);
          dbg_d1_high_run <= next_d1_run;
          if next_d1_run > dbg_d1_high_run_max then
            dbg_d1_high_run_max <= next_d1_run;
          end if;
        else
          dbg_d1_high_run <= (others => '0');
        end if;
      end if;
    end process;
  end generate gen_debug_input_run_over;

  gen_straight_oversampled : if( g_with_oversampling = true and g_reverse = false ) generate

    clk_in <= clk_in_i;

    process(clk_dmtd_over_i)
    begin
      if rising_edge(clk_dmtd_over_i) then

        sync_p1_d <= sync_p1_i;

        if sync_p1_d = '1' then
          over_div_cnt <= (others => '0');
          over_div_p <= '1';
        elsif over_div_cnt = unsigned(r_oversample_div_i) then
          over_div_cnt <= (others => '0');
          over_div_p <= '1';
        else
          over_div_cnt <= over_div_cnt + 1;
          over_div_p <= '0';
        end if;
        
        clk_i_d0 <= clk_in;

        -- the actual DDMTD is right below
        if over_div_p = '1' then
          clk_i_d1 <= clk_i_d0;
        end if;

      end if;
    end process;

    p_the_dmtd_itself : process(clk_dmtd_i)
    begin
      if rising_edge(clk_dmtd_i) then
        clk_i_d2 <= clk_i_d1;
        clk_i_d3 <= clk_i_d2;
      end if;
    end process;

    clk_sampled_o <= clk_i_d3;

  end generate gen_straight_oversampled;


  gen_straight_nonoversampled : if(g_reverse = false and g_with_oversampling = false ) generate

    gen_input_div2 : if(g_divide_input_by_2 = true) generate
      p_divide_input_clock : process(clk_in_i)
      begin
        if rising_edge(clk_in_i) then
          clk_in <= not clk_in;
        end if;
      end process;
    end generate gen_input_div2;

    gen_input_straight : if(g_divide_input_by_2 = false) generate
      clk_in <= clk_in_i;
    end generate gen_input_straight;

    p_the_dmtd_itself : process(clk_dmtd_i)
    begin
      if rising_edge(clk_dmtd_i) then
        clk_i_d0 <= clk_in;
        en_i_d0 <= en_i;
        clk_i_d1 <= not( clk_i_d0 and en_i_d0 );
        clk_i_d2 <= clk_i_d1;
        clk_i_d3 <= clk_i_d2;
      end if;
    end process;

    clk_sampled_o <= clk_i_d3;


  end generate gen_straight_nonoversampled;

  gen_reverse_nonoversampled : if(g_reverse = true and g_with_oversampling = false) generate

    assert (not g_divide_input_by_2) report "dmtd_with_deglitcher: g_reverse implies g_divide_input_by_2 == false" severity failure;

    clk_in <= clk_in_i;

    p_the_dmtd_itself : process(clk_in)
    begin
      if rising_edge(clk_in) then
          clk_i_d0 <= clk_dmtd_i;
        if en_i = '1' then
          clk_i_d1 <= clk_i_d0;
        end if;
      end if;
    end process;

    inst_sync_1: entity work.gc_sync
      port map (
        clk_i     => clk_dmtd_i,
        rst_n_a_i => '1',
        d_i       => clk_i_d1,
        q_o       => clk_i_d3);

    clk_sampled_o <= not clk_i_d3;

  end generate gen_reverse_nonoversampled;


end rtl;
