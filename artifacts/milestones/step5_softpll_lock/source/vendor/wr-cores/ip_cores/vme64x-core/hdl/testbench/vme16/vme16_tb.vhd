--------------------------------------------------------------------------------
-- CERN (BE-CO-HT)
-- VME64x Core test bench
-- http://www.ohwr.org/projects/vme64x-core
--------------------------------------------------------------------------------
--
-- unit name:     top_tb
--
-- description:
--
--   Implement a VME master and test various scenarios. Set the g_SCENARIO
--   generic to select the test. See descriptions in the file.
--
--
-- dependencies:
--
--------------------------------------------------------------------------------
-- GNU LESSER GENERAL PUBLIC LICENSE
--------------------------------------------------------------------------------
-- This source file is free software; you can redistribute it and/or modify it
-- under the terms of the GNU Lesser General Public License as published by the
-- Free Software Foundation; either version 2.1 of the License, or (at your
-- option) any later version. This source is distributed in the hope that it
-- will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty
-- of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU Lesser General Public License for more details. You should have
-- received a copy of the GNU Lesser General Public License along with this
-- source; if not, download it from http://www.gnu.org/licenses/lgpl-2.1.html

entity vme16_tb is
  generic (g_SCENARIO : natural range 0 to 7 := 6);
end vme16_tb;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_textio.all;
use std.textio.all;

use work.vme64x_pkg.all;
use work.wishbone_pkg.all;

architecture behaviour of vme16_tb is
  subtype cfg_addr_t is std_logic_vector (19 downto 0);
  subtype byte_t is std_logic_vector (7 downto 0);
  subtype word_t is std_logic_vector (15 downto 0);
  subtype lword_t is std_logic_vector (31 downto 0);
  subtype qword_t is std_logic_vector (63 downto 0);

  type word_array_t is array (natural range <>) of word_t;
  type lword_array_t is array (natural range <>) of lword_t;
  type qword_array_t is array (natural range <>) of qword_t;

  subtype vme_am_t is std_logic_vector (5 downto 0);

  function hex1 (v : std_logic_vector (3 downto 0)) return character is
  begin
    case v is
      when x"0" => return '0';
      when x"1" => return '1';
      when x"2" => return '2';
      when x"3" => return '3';
      when x"4" => return '4';
      when x"5" => return '5';
      when x"6" => return '6';
      when x"7" => return '7';
      when x"8" => return '8';
      when x"9" => return '9';
      when x"a" => return 'a';
      when x"b" => return 'b';
      when x"c" => return 'c';
      when x"d" => return 'd';
      when x"e" => return 'e';
      when x"f" => return 'f';
      when "ZZZZ" => return 'Z';
      when "XXXX" => return 'X';
      when others => return '?';
    end case;
  end hex1;

  function hex (v : std_logic_vector) return string
  is
    constant ndigits : natural := v'length / 4;
    subtype av_t is std_logic_vector (ndigits * 4 - 1 downto 0);
    alias av : av_t is v;
    variable res : string (ndigits downto 1);
  begin
    for i in res'range loop
      res (i) := hex1 (av (i * 4 - 1 downto i * 4 - 4));
    end loop;
    return res;
  end hex;

  function Image_AM (am : natural range 0 to 63) return string is
  begin
    case am is
      when 16#3f# => return "A24S-BLT";
      when 16#3e# => return "A24S-PRG";
      when 16#3d# => return "A24S-DAT";
      when 16#3c# => return "A24S-MBL";
      when 16#3b# => return "A24U-BLT";
      when 16#3a# => return "A24U-PRG";
      when 16#39# => return "A24U-DAT";
      when 16#38# => return "A24U-MBL";

      when 16#37# => return "A40x-BLT";
      when 16#36# => return "Resvd-46";
      when 16#35# => return "A40x-LCK";
      when 16#34# => return "A40x-TFR";
      when 16#33# => return "Resvd-33";
      when 16#32# => return "A24x-LCK";
      when 16#31# => return "Resvd-31";
      when 16#30# => return "Resvd-30";

      when 16#2f# => return "CR-CSR  ";
      when 16#2e# => return "Resvd-2e";
      when 16#2d# => return "A16S    ";
      when 16#2c# => return "A16x-LCK";
      when 16#2b# => return "Resvd-2b";
      when 16#2a# => return "Resvd-2a";
      when 16#29# => return "A16U    ";
      when 16#28# => return "Resvd-28";

      when 16#27# downto 16#20# => return "Resvd-2x";
      when 16#1f# downto 16#10# => return "UD-1x";

      when 16#0f# => return "A32S-BLT";
      when 16#0e# => return "A32S-PRG";
      when 16#0d# => return "A32S-DAT";
      when 16#0c# => return "A32S-MBL";
      when 16#0b# => return "A32U-BLT";
      when 16#0a# => return "A32U-PRG";
      when 16#09# => return "A32U-DAT";
      when 16#08# => return "A32U-MBL";

      when 16#07# => return "Resvd-07";
      when 16#06# => return "Resvd-06";
      when 16#05# => return "A32x-LCK";
      when 16#04# => return "A64x-LCK";
      when 16#03# => return "A64x-BLT";
      when 16#02# => return "Resvd-02";
      when 16#01# => return "A64x-TFR";
      when 16#00# => return "A64x-MBL";
    end case;
  end Image_AM;

  --  Clock
  constant g_CLOCK_PERIOD : natural := 10;  -- in ns

  --  VME core
  signal clk_i           : std_logic;
  signal rst_n_i         : std_logic;
  signal rst_n_o         : std_logic;
  signal VME_AS_n_i      : std_logic;
  signal VME_RST_n_i     : std_logic;
  signal VME_WRITE_n_i   : std_logic;
  signal VME_AM_i        : std_logic_vector(5 downto 0);
  signal VME_DS_n_i      : std_logic_vector(1 downto 0);
  signal VME_GA_i        : std_logic_vector(5 downto 0);
  signal VME_BERR_n_o    : std_logic;
  signal VME_DTACK_n_o   : std_logic;
  signal VME_RETRY_n_o   : std_logic;
  signal VME_LWORD_n_i   : std_logic;
  signal VME_LWORD_n_o   : std_logic;
  signal VME_ADDR_i      : std_logic_vector(31 downto 1);
  signal VME_ADDR_o      : std_logic_vector(31 downto 1);
  signal VME_DATA_i      : std_logic_vector(31 downto 0);
  signal VME_DATA_o      : std_logic_vector(31 downto 0);
  signal VME_IRQ_n_o     : std_logic_vector(6 downto 0);
  signal VME_IACKIN_n_i  : std_logic;
  signal VME_IACK_n_i    : std_logic;
  signal VME_IACKOUT_n_o : std_logic;
  signal VME_DTACK_OE_o  : std_logic;
  signal VME_DATA_DIR_o  : std_logic;
  signal VME_DATA_OE_N_o : std_logic;
  signal VME_ADDR_DIR_o  : std_logic;
  signal VME_ADDR_OE_N_o : std_logic;
  signal VME_RETRY_OE_o  : std_logic;
  signal DAT_i           : std_logic_vector(31 downto 0);
  signal DAT_o           : std_logic_vector(31 downto 0);
  signal ADR_o           : std_logic_vector(31 downto 0);
  signal CYC_o           : std_logic;
  signal ERR_i           : std_logic;
  signal SEL_o           : std_logic_vector(3 downto 0);
  signal STB_o           : std_logic;
  signal ACK_i           : std_logic;
  signal WE_o            : std_logic;
  signal STALL_i         : std_logic;
  signal rty_i           : std_logic := '0';
  signal irq_level_i     : std_logic_vector(2 downto 0)  := "010";
  signal irq_vector_i    : std_logic_vector(7 downto 0)  := x"5e";
  signal user_csr_addr_o : std_logic_vector(18 downto 2);
  signal user_csr_data_i : std_logic_vector(7 downto 0)  := (others => '0');
  signal user_csr_data_o : std_logic_vector(7 downto 0);
  signal user_csr_we_o   : std_logic;
  signal user_cr_addr_o  : std_logic_vector(18 downto 2);
  signal user_cr_data_i  : std_logic_vector( 7 downto 0)  := (others => '0');
  signal irq_ack_o       : std_logic;
  signal irq_i           : std_logic;

  constant slave_ga : std_logic_vector (4 downto 0) := b"0_1101";

  signal bus_timer : std_logic;
  signal end_tb : boolean := false;
begin
  set_ga: block
  begin
    VME_GA_i (4 downto 0) <= not slave_ga;
    VME_GA_i (5) <= (slave_ga (4) xor slave_ga (3) xor slave_ga (2)
                     xor slave_ga (1) xor slave_ga (0));
  end block;

  vme64xcore: entity work.vme64x_core
    generic map (g_CLOCK_PERIOD => g_CLOCK_PERIOD,
                 g_DECODE_AM => (g_SCENARIO /= 9),
                 g_ENABLE_CR_CSR => False,
                 g_WB_GRANULARITY => WORD,
                 g_USER_CSR_EXT   => false,
                 g_VME32          => false,

                 g_MANUFACTURER_ID => c_CERN_ID,
                 g_BOARD_ID        => c_SVEC_ID,
                 g_REVISION_ID     => c_SVEC_REVISION_ID,
                 g_PROGRAM_ID      => c_SVEC_PROGRAM_ID,

                 g_ASCII_PTR     => x"000000",
                 g_BEG_USER_CR   => x"000000",
                 g_END_USER_CR   => x"000000",
                 g_BEG_CRAM      => x"000000",
                 g_END_CRAM      => x"000000",
                 g_BEG_USER_CSR  => x"07ff33",
                 g_END_USER_CSR  => x"07ff5f",
                 g_BEG_SN        => x"000000",
                 g_END_SN        => x"000000",

                 g_decoder_0_adem  => x"fff00000",
                 g_decoder_0_amcap => x"ee000000_00000000",
                 g_decoder_0_dawpr => x"83",
                 g_decoder_1_adem  => x"00000000",
                 g_decoder_1_amcap => x"00000000_00000000",
                 g_decoder_1_dawpr => x"83",
                 g_decoder_2_adem  => x"00000000",
                 g_decoder_2_amcap => x"00000000_00000000",
                 g_decoder_2_dawpr => x"84",
                 g_decoder_3_adem  => x"00000000",
                 g_decoder_3_amcap => x"00000000_00000000",
                 g_decoder_3_dawpr => x"84",
                 g_decoder_4_adem  => x"00000000",
                 g_decoder_4_amcap => x"00000000_00000000",
                 g_decoder_4_dawpr => x"84",
                 g_decoder_5_adem  => x"00000000",
                 g_decoder_5_amcap => x"00000000_00000000",
                 g_decoder_5_dawpr => x"84",
                 g_decoder_6_adem  => x"00000000",
                 g_decoder_6_amcap => x"00000000_00000000",
                 g_decoder_6_dawpr => x"84",
                 g_decoder_7_adem  => x"00000000",
                 g_decoder_7_amcap => x"00000000_00000000",
                 g_decoder_7_dawpr => x"84")
    port map (
        clk_i           => clk_i,
        rst_n_i         => rst_n_i,
        rst_n_o         => rst_n_o,
        VME_AS_n_i      => VME_AS_n_i,
        VME_RST_n_i     => VME_RST_n_i,
        VME_WRITE_n_i   => VME_WRITE_n_i,
        VME_AM_i        => VME_AM_i,
        VME_DS_n_i      => VME_DS_n_i,
        VME_GA_i        => VME_GA_i,
        VME_BERR_n_o    => VME_BERR_n_o,
        VME_DTACK_n_o   => VME_DTACK_n_o,
        VME_RETRY_n_o   => VME_RETRY_n_o,
        VME_LWORD_n_i   => VME_LWORD_n_i,
        VME_LWORD_n_o   => VME_LWORD_n_o,
        VME_ADDR_i      => VME_ADDR_i,
        VME_ADDR_o      => VME_ADDR_o,
        VME_DATA_i      => VME_DATA_i,
        VME_DATA_o      => VME_DATA_o,
        VME_IRQ_n_o     => VME_IRQ_n_o,
        VME_IACKIN_n_i  => VME_IACKIN_n_i,
        VME_IACK_n_i    => VME_IACK_n_i,
        VME_IACKOUT_n_o => VME_IACKOUT_n_o,
        VME_DTACK_OE_o  => VME_DTACK_OE_o,
        VME_DATA_DIR_o  => VME_DATA_DIR_o,
        VME_DATA_OE_N_o => VME_DATA_OE_N_o,
        VME_ADDR_DIR_o  => VME_ADDR_DIR_o,
        VME_ADDR_OE_N_o => VME_ADDR_OE_N_o,
        VME_RETRY_OE_o  => VME_RETRY_OE_o,
        wb_DAT_i        => DAT_i,
        wb_DAT_o        => DAT_o,
        wb_ADR_o        => ADR_o,
        wb_CYC_o        => CYC_o,
        wb_ERR_i        => ERR_i,
        wb_SEL_o        => SEL_o,
        wb_STB_o        => STB_o,
        wb_ACK_i        => ACK_i,
        wb_WE_o         => WE_o,
        wb_STALL_i      => STALL_i,
        wb_rty_i        => rty_i,
        int_i           => irq_i,
        irq_level_i     => irq_level_i,
        irq_vector_i    => irq_vector_i,
        user_csr_addr_o => user_csr_addr_o,
        user_csr_data_i => user_csr_data_i,
        user_csr_data_o => user_csr_data_o,
        user_csr_we_o   => user_csr_we_o,
        user_cr_addr_o  => user_cr_addr_o,
        user_cr_data_i  => user_cr_data_i,
        irq_ack_o       => irq_ack_o);

  clk_gen: process
  begin
    clk_i <= '0';
    wait for (g_CLOCK_PERIOD / 2) * 1 ns;
    clk_i <= '1';
    wait for (g_CLOCK_PERIOD / 2) * 1 ns;
    if end_tb then
      wait;
    end if;
  end process;

  --  Bus timer.  See VME spec 2.3.3 Bus Timer
  bus_timer_proc : process (clk_i)
    type state_t is (IDLE, WAIT_DS, COUNTING, WAIT_END, ERR);
    variable state : state_t;
    variable count : natural;
  begin
    if rising_edge (clk_i) then
      if VME_RST_n_i = '0' then
        state := IDLE;
        bus_timer <= '0';
      else
        bus_timer <= '0';

        case state is
          when IDLE =>
            if VME_AS_n_i = '0' then
              state := WAIT_DS;
            end if;
          when WAIT_DS =>
            count := 20;
            if VME_DS_n_i /= "11" then
              state := COUNTING;
            end if;
          when COUNTING =>
            if VME_DS_n_i = "11" then
              state := WAIT_END;
            else
              if count = 0 then
                state := ERR;
              else
                count := count - 1;
              end if;
            end if;
          when WAIT_END =>
            if VME_AS_n_i = '1' then
              state := IDLE;
            end if;

          when ERR =>
            bus_timer <= '1';
            -- VITAL 1 Rule 2.60
            -- Once it has driven BERR* low, the bus timer MUST NOT release
            -- BERR* until it detected both DS0* and DS1* high.
            if VME_DS_n_i = "11" then
              state := IDLE;
            end if;
        end case;
      end if;
    end if;
  end process;

  --  WB slave: a simple sram
  --  WBaddr   VMEaddr
  --  0-0x3ff  0-0xfff  sram
  --  0x2000   0x8000   counter
  --  0x2001   0x8004   BERR
  wb_p : process (clk_i)
    constant sram_addr_wd : natural := 10;
    type sram_array is array (0 to 2**sram_addr_wd - 1)
      of std_logic_vector (15 downto 0);
    variable sram : sram_array := (0 => x"0000",
                                   1 => x"0001",
                                   2 => x"0002",
                                   3 => x"0003",

                                   4 => x"0004",
                                   5 => x"0500",
                                   6 => x"0006",
                                   7 => x"0700",
                                   others => x"4321");
    variable idx : natural;
    variable int_cnt : natural range 0 to 2**8 - 1;
  begin
    if rising_edge (clk_i) then
      if rst_n_o = '0' then
        ERR_i <= '0';
        STALL_i <= '0';
        ACK_i <= '0';

        int_cnt := 0;
      else
        ACK_i <= '0';
        ERR_i <= '0';

        -- Interrupt timer
        irq_i <= '0';
        if int_cnt > 0 then
          int_cnt := int_cnt - 1;
          if int_cnt = 0 then
            irq_i <= '1';
          end if;
        end if;

        if STB_o = '1' then
          ACK_i <= '1';
          idx := to_integer (unsigned (ADR_o (sram_addr_wd - 1 downto 0)));

          if ADR_o (14) = '1' then
            if ADR_o (0) = '0' then
              if WE_o = '0' then
                -- Read counter
                DAT_i (15 downto 0) <= std_logic_vector (to_unsigned (int_cnt, 16));
              else
                -- Write counter
                if SEL_o (0) = '1' then
                  int_cnt := to_integer(unsigned(DAT_o(7 downto 0)));
                end if;
              end if;
            else
              --  BERR
              ACK_i <= '0';
              ERR_i <= '1';
            end if;
          else
            if WE_o = '0' then
              --  Read SRAM
              DAT_i (15 downto 0) <= sram (idx);
            else
              -- Write SRAM
              for i in 1 downto 0 loop
                if SEL_o(i) = '1' then
                  sram(idx)(8*i + 7 downto 8*i) := DAT_o (8*i + 7 downto 8*i);
                end if;
              end loop;
            end if;
          end if;
        end if;
      end if;
    end if;
  end process;

  VME_IACKIN_n_i <= VME_IACK_n_i;

  tb: process
    constant c_log : boolean := false;

    procedure read_setup_addr (addr : std_logic_vector (31 downto 0);
                               am : vme_am_t) is
    begin
      VME_ADDR_i <= addr (31 downto 1);
      VME_AM_i <= am;
      VME_IACK_n_i <= '1';
      wait for 35 ns;
      VME_AS_n_i <= '0';
      VME_WRITE_n_i <= '1';
      if not (VME_DTACK_OE_o = '0' and VME_BERR_n_o = '1') then
        wait until VME_DTACK_OE_o = '0' and VME_BERR_n_o = '1';
      end if;
    end read_setup_addr;

    procedure read_wait_dtack is
    begin
      wait until (VME_DTACK_OE_o = '1' and VME_DTACK_n_o = '0')
        or bus_timer = '1';
      if bus_timer = '0' then
        assert VME_DATA_DIR_o = '1' report "bad data_dir_o";
        assert VME_DATA_OE_N_o = '0' report "bad data_oe_n_o";
      end if;
    end read_wait_dtack;

    procedure read_release is
    begin
      --  Release
      VME_AS_n_i <= '1';
      VME_DS_n_i <= "11";
    end read_release;

    procedure read8 (addr : std_logic_vector (31 downto 0);
                     am : vme_am_t;
                     variable data : out byte_t)
    is
      variable res : byte_t;
    begin
      if c_log then
        write (output, "read8 at 0x" & hex (addr) & " ["
               & Image_AM (to_integer (unsigned (am))) & " ]" & LF);
      end if;

      VME_LWORD_n_i <= '1';
      read_setup_addr (addr, am);

      if addr (0) = '0' then
        VME_DS_n_i <= "01";
      else
        VME_DS_n_i <= "10";
      end if;
      read_wait_dtack;
      if bus_timer = '0' then
        if addr (0) = '0' then
          res := VME_DATA_o (15 downto 8);
        else
          res := VME_DATA_o (7 downto 0);
        end if;
      else
        res := (others => 'X');
      end if;
      data := res;

      read_release;

      if c_log then
        write (output, " => 0x" & hex(res) & LF);
      end if;
    end read8;

    procedure read16 (addr : std_logic_vector (31 downto 0);
                     am : vme_am_t;
                     variable data : out word_t)
    is
      variable res : word_t;
    begin
      if c_log then
        write (output, "read16 at 0x" & hex (addr) & " ["
               & Image_AM (to_integer (unsigned (am))) & " ]" & LF);
      end if;

      VME_LWORD_n_i <= '1';
      read_setup_addr (addr, am);

      assert addr (0) = '0' report "unaligned read16" severity error;
      VME_DS_n_i <= "00";
      read_wait_dtack;
      if bus_timer = '0' then
        res := VME_DATA_o (15 downto 0);
      else
        res := (others => 'X');
      end if;
      data := res;

      read_release;

      if c_log then
        write (output, " => 0x" & hex(res) & LF);
      end if;
    end read16;

    procedure read_blt_end_cycle is
    begin
      VME_DS_n_i <= "11";
      wait until (VME_DTACK_OE_o = '0' or VME_DTACK_n_o = '1')
        and VME_BERR_n_o = '1';
    end read_blt_end_cycle;

    procedure read16_blt (addr : std_logic_vector (31 downto 0);
                          am : vme_am_t;
                          variable data : out word_array_t) is
    begin
      VME_LWORD_n_i <= '1';
      read_setup_addr (addr, am);

      assert addr (0) = '0' report "unaligned read16_blt" severity error;
      for i in data'range loop
        VME_DS_n_i <= "00";
        read_wait_dtack;
        if bus_timer = '0' then
          data (i) := VME_DATA_o (15 downto 0);
        else
          data (i) := (others => 'X');
        end if;
        if i /= data'right then
          read_blt_end_cycle;
        end if;
      end loop;

      read_release;
    end read16_blt;

    procedure write_setup_addr (addr : std_logic_vector (31 downto 0);
                                lword_n : std_logic;
                                am : vme_am_t) is
    begin
      if not (VME_DTACK_OE_o = '0' and VME_BERR_n_o = '1') then
        wait until VME_DTACK_OE_o = '0' and VME_BERR_n_o = '1';
      end if;
      VME_ADDR_i <= addr(31 downto 1);
      VME_AM_i <= am;
      VME_LWORD_n_i <= lword_n;
      VME_IACK_n_i <= '1';
      wait for 35 ns;
      VME_AS_n_i <= '0';
      VME_WRITE_n_i <= '0';
    end write_setup_addr;

    procedure write_wait_dtack_pulse is
    begin
      wait until VME_DTACK_OE_o = '1' and VME_DTACK_n_o = '0';
      VME_DS_n_i <= "11";

      wait until VME_DTACK_OE_o = '0' or VME_DTACK_n_o = '1';
    end write_wait_dtack_pulse;

    procedure write_wait_dtack is
    begin
      write_wait_dtack_pulse;

      VME_AS_n_i <= '1';
    end write_wait_dtack;

    procedure write8 (addr : std_logic_vector (31 downto 0);
                      am : vme_am_t;
                      data : byte_t) is
    begin
      write_setup_addr (addr, '1', am);

      if addr (0) = '0' then
        VME_DS_n_i <= "01";
        VME_DATA_i (15 downto 8) <= data;
      else
        VME_DS_n_i <= "10";
        VME_DATA_i (7 downto 0) <= data;
      end if;

      write_wait_dtack;
    end write8;

    procedure write16 (addr : std_logic_vector (31 downto 0);
                       am : vme_am_t;
                       data : word_t) is
    begin
      assert addr(0) = '0' report "unaligned write16" severity error;

      write_setup_addr (addr, '1', am);

      VME_DS_n_i <= "00";
      VME_DATA_i (15 downto 0) <= data;

      write_wait_dtack;
    end write16;

    procedure ack_int (vec : out byte_t) is
    begin
      if VME_IRQ_n_o = "1111111" then
        vec := (others => 'X');
        return;
      end if;

      for i in 6 downto 0 loop
        if VME_IRQ_n_o (i) = '0' then
          VME_ADDR_i (3 downto 1) <= std_logic_vector (to_unsigned (i + 1, 3));
          exit;
        end if;
      end loop;
      VME_IACK_n_i <= '0';
      VME_WRITE_n_i <= '1';
      wait for 35 ns;
      VME_AS_n_i <= '0';
      if not (VME_DTACK_OE_o = '0' and VME_BERR_n_o = '1') then
        wait until VME_DTACK_OE_o = '0' and VME_BERR_n_o = '1';
      end if;

      VME_DS_n_i <= "10";
      read_wait_dtack;
      if bus_timer = '0' then
        vec := VME_DATA_o (7 downto 0);
      else
        vec := (others => 'X');
      end if;

      read_release;
      VME_IACK_n_i <= '1';
    end ack_int;

    variable d8 : byte_t;
    variable d16 : word_t;
    variable v16 : word_array_t (0 to 16);
  begin
    --  Each scenario starts with a reset.
    --  VME reset
    rst_n_i <= '0';
    VME_RST_n_i <= '0';
    VME_AS_n_i <= '1';
    VME_ADDR_i <= (others => '1');
    VME_AM_i <= (others => '1');
    VME_DS_n_i <= "11";
    for i in 1 to 2 loop
      wait until rising_edge (clk_i);
    end loop;
    VME_RST_n_i <= '1';
    rst_n_i <= '1';
    for i in 1 to 8 loop
      wait until rising_edge (clk_i);
    end loop;

    case g_SCENARIO is
      when 0 =>
        null;

      when 1 =>
        --  WB data access
        report "scenario 1: WB data access";

        --  WB read
        read8 (x"00_d0_00_00", c_AM_A24, d8);
        assert d8 = x"00" report "bad read at 000" severity error;

        read8 (x"00_d0_00_07", c_AM_A24, d8);
        assert d8 = x"03" report "bad read at 007" severity error;
        report "read data: " & hex (d8);

        read16 (x"00_d0_00_04", c_AM_A24, d16);
        assert d16 = x"0002" report "bad read at 004" severity error;

        -- WB write
        write8 (x"00_d0_00_10", c_AM_A24, x"1f");
        read16 (x"00_d0_00_10", c_AM_A24, d16);
        assert d16 = x"1f21" report "bad read at 010 (2)" severity error;

        write16 (x"00_d0_00_12", c_AM_A24, x"abcd");
        read16 (x"00_d0_00_12", c_AM_A24, d16);
        assert d16 = x"abcd" report "bad read at 012 (3)" severity error;

      when 2 =>
        -- Test interrupts

        write8 (x"00_d0_80_01", c_AM_A24, x"02");
        wait for 2 * g_CLOCK_PERIOD * 1 ns;
        assert VME_IRQ_n_o = "1111101" report "IRQ incorrectly reported"
          severity error;

        ack_int (d8);
        assert d8 = x"5e" report "incorrect vector" severity error;
        assert VME_IRQ_n_o = "1111111" report "IRQ not disabled after ack"
          severity error;

        write8 (x"00_d0_80_01", c_AM_A24, x"20");
        assert VME_IRQ_n_o = "1111111" report "IRQ not expected"
          severity error;
        wait for 32 * g_CLOCK_PERIOD * 1 ns;
        assert VME_IRQ_n_o = "1111101" report "IRQ incorrectly reported"
          severity error;

        ack_int (d8);
        assert d8 = x"5e" report "incorrect vector" severity error;
        assert VME_IRQ_n_o = "1111111" report "IRQ not disabled after ack"
          severity error;

      when 3 =>
        -- Test block transfers

        --  D16 BLT not supported
        read16_blt (x"00_d0_00_04", c_AM_A24_BLT, v16 (0 to 5));
        assert v16 (0) = x"0002"
          and v16 (1) = x"0003"
          and v16 (2) = x"0004"
          and v16 (3) = x"0500"
          and v16 (4) = x"0006"
          and v16 (5) = x"0700"
          report "incorrect BLT data 16" severity error;

      when 4 =>
        --  A24 tests
        --  A24 with weird MSBs in address
        null;

      when 5 =>
        -- Test err_i => BERR

        read16 (x"00_d0_80_02", c_AM_A24, d16);
        assert d16  = (15 downto 0 => 'X')
          report "incorrect read 16" severity error;

      when 6 =>
        null;

      when 7 =>
        --  Delayed DS

        -- Read 16 at 0x0100
        VME_LWORD_n_i <= '1';
        read_setup_addr (x"67_00_01_00", c_AM_A32);

        wait for 50 ns;
        VME_DS_n_i <= "0X";
        wait for 20 ns; --  Constraint 13.
        VME_DS_n_i <= "00";
        read_wait_dtack;
        if bus_timer = '0' then
          d16 := VME_DATA_o (15 downto 0);
        else
          d16 := (others => 'X');
        end if;
        read_release;
        assert d16 = x"8765" report "bad read16 with delayed DS"
          severity error;
    end case;

    wait for 4 * g_CLOCK_PERIOD * 1 ns;
    end_tb <= true;
    assert false report "end of simulation" severity note;
    wait;
  end process;
end behaviour;
