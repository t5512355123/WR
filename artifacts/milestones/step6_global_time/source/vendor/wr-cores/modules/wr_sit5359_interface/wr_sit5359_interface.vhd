-------------------------------------------------------------------------------
-- Title      : SiTime Sit5359 oscillator I2C controller
-- Project    : White Rabbit
-------------------------------------------------------------------------------
-- File       : wr_sit5359_interface.vhd
-- Author     : Peter Jansweijer (inspired by Tomasz Wlostowski)
-- Company    : Nikhef/CERN BE-Co-HT
-- Created    : 2022-01-10
-- Last update: 2022-01-10
-- Platform   : FPGA-generic
-- Standard   : VHDL '93
-------------------------------------------------------------------------------
-- Description: SiTime Sit5359 MEMS- oscillator hardware interface for the WR
-- Core SoftPLL, allowing it to discipline Sit5359 oscillators to WR clock.
-- The core performs two tasks:
-- - allows the WR core to access I2C registers of attached Sit5359 oscillator
--   through bit-banging (e.g. to set base frequency)
-- - controls the Sit5359 PLL tuning in atomic (HW-only) way via tm_dac_value port.
--   The tuning value is added to pre-programmed RFREQ bias value set via
--   Wishbone.
-------------------------------------------------------------------------------
--
-- Copyright (c) 2013 CERN
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

use work.wishbone_pkg.all;
use work.sit5359_wbgen2_pkg.all;

entity wr_sit5359_interface is
  
  generic (
    g_simulation     : integer := 0;
    g_sys_clock_freq : integer := 62500000;
    g_i2c_freq       : integer := 400000;
    g_dac_bits       : integer range 1 to 26 := 16  -- SiTime 5359 Frequency Control word = 26 bits
    );

  port (
    clk_sys_i : in std_logic;
    rst_n_i   : in std_logic;

    -- WR Core timing interface: aux clock tune port
    tm_dac_value_i    : in std_logic_vector(g_dac_bits-1 downto 0) := (others => '0');
    tm_dac_value_wr_i : in std_logic := '0';

    -- I2C bus: output enable (active low)
    scl_pad_oen_o : out std_logic;
    sda_pad_oen_o : out std_logic;

    -- I2C bus: input pads
    scl_pad_i : in std_logic;
    sda_pad_i : in std_logic;

    -- Wishbone
    wb_adr_i   : in  std_logic_vector(c_wishbone_address_width-1 downto 0)   := (others => '0');
    wb_dat_i   : in  std_logic_vector(c_wishbone_data_width-1 downto 0)      := (others => '0');
    wb_dat_o   : out std_logic_vector(c_wishbone_data_width-1 downto 0);
    wb_sel_i   : in  std_logic_vector(c_wishbone_address_width/8-1 downto 0) := (others => '0');
    wb_we_i    : in  std_logic                                               := '0';
    wb_cyc_i   : in  std_logic                                               := '0';
    wb_stb_i   : in  std_logic                                               := '0';
    wb_ack_o   : out std_logic;
    wb_err_o   : out std_logic;
    wb_stall_o : out std_logic
    );

end wr_sit5359_interface;

architecture rtl of wr_sit5359_interface is

  component sit5359_if_wb
    port (
      rst_n_i    : in  std_logic;
      clk_sys_i  : in  std_logic;
      wb_adr_i   : in  std_logic_vector(1 downto 0);
      wb_dat_i   : in  std_logic_vector(31 downto 0);
      wb_dat_o   : out std_logic_vector(31 downto 0);
      wb_cyc_i   : in  std_logic;
      wb_sel_i   : in  std_logic_vector(3 downto 0);
      wb_stb_i   : in  std_logic;
      wb_we_i    : in  std_logic;
      wb_ack_o   : out std_logic;
      wb_stall_o : out std_logic;
      regs_i     : in  t_sit5359_in_registers;
      regs_o     : out t_sit5359_out_registers);
  end component;

  constant c_dac_half_scale : integer := 2**(g_dac_bits-1);

  signal regs_in  : t_sit5359_in_registers;
  signal regs_out : t_sit5359_out_registers;

  signal rfreq_new_p                   : std_logic;
  signal rfreq_current, rfreq_new      : unsigned(31 downto 0);

  signal tm_dac_value_wr_d  : std_logic;
  signal tm_dac_value_wr_d1 : std_logic;
  signal tm_dac_value       : std_logic_vector(g_dac_bits-1 downto 0);

  signal i2c_tick    : std_logic;
  signal i2c_divider : unsigned(7 downto 0);

  signal scl_int : std_logic;
  signal sda_int : std_logic;

  signal seq_count : unsigned(8 downto 0);

  type t_i2c_transaction is (START, STOP, SEND_BYTE);

  type t_state is (IDLE, SI_START0, SI_ADDR0, SI_REG0, SI_RF0, SI_RF1, SI_RF2, SI_RF3, SI_STOP0);

  signal state : t_state;

  signal scl_out_host, scl_out_fsm : std_logic;
  signal sda_out_host, sda_out_fsm : std_logic;

  procedure f_i2c_iterate(tick : std_logic; signal counter : inout unsigned; value : std_logic_vector(7 downto 0); trans_type : t_i2c_transaction; signal scl : out std_logic; signal sda : out std_logic; signal state_var : out t_state; next_state : t_state) is
    variable last : boolean;
  begin

    last := false;

    if(tick = '0') then
      return;
    end if;


    case trans_type is
      when START =>
        case counter(1 downto 0) is
          -- states 0..2: start condition
          when "00" =>
            scl <= '1';
            sda <= '1';
          when "01" =>
            sda <= '0';
          when "10" =>
            scl  <= '0';
            last := true;
          when others => null;
        end case;

      when STOP =>
        case counter(1 downto 0) is
          -- states 0..2: start condition
          when "00" =>
            sda <= '0';
          when "01" =>
            scl <= '1';
          when "10" =>
            sda  <= '1';
            last := true;
          when others => null;
        end case;
        
      when SEND_BYTE =>
        
        case counter(1 downto 0) is
          when "00" =>
            sda <= value(7-to_integer(counter(4 downto 2)));
          when "01" =>
            scl <= '1';
          when "10" =>
            scl <= '0';
            if(counter(5) = '1') then
              last := true;
            end if;
          when others => null;
        end case;
    end case;

    if(last) then
      state_var <= next_state;
      counter   <= "000000000";
    else
      counter <= counter + 1;
    end if;
    
  end f_i2c_iterate;


  function f_sign_extend( x : signed; l : integer ) return unsigned is
    variable rv : unsigned(l-1 downto 0);
  begin
    rv ( x'length-1 downto 0) := unsigned(x);
    rv( l-1 downto x'length ) := (others => x(x'length-1));
    return rv;
  end f_sign_extend;
  
begin  -- rtl

  U_WB_Slave : sit5359_if_wb
    port map (
      rst_n_i    => rst_n_i,
      clk_sys_i  => clk_sys_i,
      wb_adr_i   => wb_adr_i(3 downto 2),
      wb_dat_i   => wb_dat_i,
      wb_dat_o   => wb_dat_o,
      wb_cyc_i   => wb_cyc_i,
      wb_sel_i   => wb_sel_i,
      wb_stb_i   => wb_stb_i,
      wb_we_i    => wb_we_i,
      wb_ack_o   => wb_ack_o,
      wb_stall_o => wb_stall_o,
      regs_i     => regs_in,
      regs_o     => regs_out);

  p_rfreq : process(clk_sys_i)
  begin
    if rising_edge(clk_sys_i) then
      if rst_n_i = '0' then
        rfreq_new_p <= '0';
        rfreq_new <= (others => '0');
        tm_dac_value_wr_d  <= '0';
        tm_dac_value_wr_d1 <= '0';
      else
        tm_dac_value_wr_d  <= tm_dac_value_wr_i;
        tm_dac_value_wr_d1 <= tm_dac_value_wr_d;
        
        -- latch on rising edge tm_dac_value_wr_i
        if(tm_dac_value_wr_i = '1' and tm_dac_value_wr_d = '0') then
          tm_dac_value <= tm_dac_value_i;
        end if;

        -- next pipeline stage, create fromatted frequency tune word
        if(tm_dac_value_wr_d = '1'  and tm_dac_value_wr_d1 = '0') then
          -- Sit5359 Freqency Control Word is 26 bits signed
          -- Convert "g_dac_bits" unsigned DAC value to signed and shift left DAC bits and pad with '0'
          -- to compose 26 bit Freqency Control Word (including Output Enable bit).
          rfreq_new <= "00000" & regs_out.cr_osc_oe_o & unsigned(signed(tm_dac_value) - to_signed(c_dac_half_scale, g_dac_bits)) & ((25-g_dac_bits) downto 0 => '0');
        end if;

        rfreq_new_p <= tm_dac_value_wr_d and not tm_dac_value_wr_d1 and regs_out.cr_spll_en_o;
      end if;
    end if;
  end process;

  p_i2c_divider : process(clk_sys_i)
  begin
    if rising_edge(clk_sys_i) then
      if rst_n_i = '0' then
        i2c_divider <= (others => '0');
        i2c_tick    <= '0';
      else
        if(i2c_divider = unsigned(regs_out.cr_clk_div_o)) then
          i2c_tick <= '1';
          i2c_divider <= (others => '0');
        else
          i2c_tick <= '0';
          i2c_divider <= i2c_divider + 1;
        end if;
      end if;
    end if;
  end process;

  p_i2c_fsm : process(clk_sys_i)
    variable i2c_last : boolean;
  begin
    if rising_edge(clk_sys_i) then
      if rst_n_i = '0' then
        state       <= IDLE;
        seq_count   <= (others => '0');
        scl_out_fsm <= '1';
        sda_out_fsm <= '1';
      else
        case state is
          when IDLE =>
            if(rfreq_new_p = '1') then
              state <= SI_START0;
              rfreq_current <= rfreq_new;
            end if;

          when SI_START0 =>
            f_i2c_iterate(i2c_tick, seq_count, x"00", START, scl_out_fsm, sda_out_fsm, state, SI_ADDR0);
          when SI_ADDR0 =>
            f_i2c_iterate(i2c_tick, seq_count, regs_out.cr_i2c_addr_o, SEND_BYTE, scl_out_fsm, sda_out_fsm, state, SI_REG0);
          when SI_REG0 =>
            f_i2c_iterate(i2c_tick, seq_count, x"00", SEND_BYTE, scl_out_fsm, sda_out_fsm, state, SI_RF0);
          when SI_RF0 =>
            f_i2c_iterate(i2c_tick, seq_count, std_logic_vector(rfreq_current(15 downto 8)), SEND_BYTE, scl_out_fsm, sda_out_fsm, state, SI_RF1);
          when SI_RF1 =>
            f_i2c_iterate(i2c_tick, seq_count, std_logic_vector(rfreq_current(7 downto 0)), SEND_BYTE, scl_out_fsm, sda_out_fsm, state, SI_RF2);
          when SI_RF2 =>
            f_i2c_iterate(i2c_tick, seq_count, std_logic_vector(rfreq_current(31 downto 24)), SEND_BYTE, scl_out_fsm, sda_out_fsm, state, SI_RF3);
          when SI_RF3 =>
            f_i2c_iterate(i2c_tick, seq_count, std_logic_vector(rfreq_current(23 downto 16)), SEND_BYTE, scl_out_fsm, sda_out_fsm, state, SI_STOP0);
          when SI_STOP0 =>
            f_i2c_iterate(i2c_tick, seq_count, x"00", STOP, scl_out_fsm, sda_out_fsm, state, IDLE);
            
          when others => null;
        end case;
      end if;
    end if;
  end process;

  regs_in.gpsr_scl_i <= scl_pad_i;
  regs_in.gpsr_sda_i <= sda_pad_i;

  p_host_i2c : process(clk_sys_i)
  begin
    if rising_edge(clk_sys_i) then
      if(rst_n_i = '0') then
        scl_out_host <= '1';
        sda_out_host <= '1';
      else
        if(regs_out.gpsr_scl_load_o = '1' and regs_out.gpsr_scl_o = '1') then
          scl_out_host <= '1';
        end if;

        if(regs_out.gpsr_sda_load_o = '1' and regs_out.gpsr_sda_o = '1') then
          sda_out_host <= '1';
        end if;

        if(regs_out.gpcr_scl_o = '1') then
          scl_out_host <= '0';
        end if;

        if(regs_out.gpcr_sda_o = '1') then
          sda_out_host <= '0';
        end if;
        
      end if;
    end if;
  end process;

  p_mux_i2c : process(clk_sys_i)
  begin
    if rising_edge(clk_sys_i) then
      if(state = IDLE) then
        scl_pad_oen_o <= scl_out_host;
        sda_pad_oen_o <= sda_out_host;
      else
        scl_pad_oen_o <= scl_out_fsm;
        sda_pad_oen_o <= sda_out_fsm;
      end if;
    end if;
  end process;

  wb_err_o <= '0';
  
end rtl;
