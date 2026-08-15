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
    
    clk_sampled_o : out std_logic
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
  
begin  -- rtl

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
