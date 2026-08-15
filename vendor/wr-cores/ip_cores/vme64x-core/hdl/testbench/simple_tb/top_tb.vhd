--------------------------------------------------------------------------------
-- CERN (BE-CO-HT)
-- VME64x Core test bench
-- http://www.ohwr.org/projects/vme64x-core
--------------------------------------------------------------------------------
--
-- unit name:     top_tb
--
-- author:        Tristan Gingold <tristan.gingold@cern.ch>
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

entity top_tb is
  generic (g_SCENARIO : natural range 0 to 11 := 6);
end top_tb;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_textio.all;
use std.textio.all;

use work.vme64x_pkg.all;
use work.wishbone_pkg.all;

architecture behaviour of top_tb is
  subtype cfg_addr_t is std_logic_vector (19 downto 0);
  subtype byte_t is std_logic_vector (7 downto 0);
  subtype word_t is std_logic_vector (15 downto 0);
  subtype lword_t is std_logic_vector (31 downto 0);
  subtype qword_t is std_logic_vector (63 downto 0);

  type word_array_t is array (natural range <>) of word_t;
  type lword_array_t is array (natural range <>) of lword_t;
  type qword_array_t is array (natural range <>) of qword_t;

  subtype vme_am_t is std_logic_vector (5 downto 0);
  subtype vme_xam_t is std_logic_vector (7 downto 0);

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

  function hex2 (v : byte_t) return string is
  begin
    return hex1 (v(7 downto 4)) & hex1 (v(3 downto 0));
  end hex2;

  function hex6 (v : std_logic_vector (23 downto 0)) return string is
    variable res : string (6 downto 1);
  begin
    for i in res'range loop
      res (i) := hex1 (v (i * 4 - 1 downto i * 4 - 4));
    end loop;
    return res;
  end hex6;

  function hex8 (v : std_logic_vector (31 downto 0)) return string is
    variable res : string (8 downto 1);
  begin
    for i in res'range loop
      res (i) := hex1 (v (i * 4 - 1 downto i * 4 - 4));
    end loop;
    return res;
  end hex8;

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

  --  Decode DAWPR byte
  function Disp_DAWPR (v : byte_t) return string is
  begin
    case v is
      when x"81" => return "D08(O)";
      when x"82" => return "D08(EO)";
      when x"83" => return "D16 + D08";
      when x"84" => return "D32 + D16 + D08";
      when x"85" => return "MD32 + D16 + D08";
      when others => return "??";
    end case;
  end Disp_DAWPR;

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

  procedure Disp_AMCAP (cap : std_logic_vector (63 downto 0)) is
  begin
    if cap = (cap'range => '0') then
      write (output, " -");
    else
      for i in cap'range loop
        if cap (i) = '1' then
          write (output, " ");
          write (output, Image_AM (i));
        end if;
      end loop;
    end if;
  end Disp_AMCAP;

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
  signal irq_level_i     : std_logic_vector(2 downto 0)  := (others => '0');
  signal irq_vector_i    : std_logic_vector(7 downto 0)  := (others => '0');
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

  signal err_8000 : natural := 0;
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
                 g_WB_GRANULARITY => WORD,
                 g_USER_CSR_EXT   => false,
                 g_VME_2e         => True,

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

                 g_decoder_0_adem  => x"ff000000",
                 g_decoder_0_amcap => x"00000001_0000ff00",
                 g_decoder_0_dawpr => x"84",
                 g_decoder_1_adem  => x"fff80000",
                 g_decoder_1_amcap => x"ff000001_00000000",
                 g_decoder_1_dawpr => x"84",
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
            count := 60;
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
  --  Note: WB is using word granularity for addresses.
  --  VME       WB
  --  0x0XXX    0x0XXX
  --   0-0xfff  sram
  --  0x4XXX    0x1XXX
  --   0x4000   counter
  --   0x4004   BERR
  --  0x8XXX    0x2XXX
  --   0x8000   invalid (use to detect wrap-arounds on prefetch)
  --  0xcXXX    0x3XXX
  --    0-0xfff  patterns with delayed ACK
  wb_p : process (clk_i)
    constant sram_addr_wd : natural := 10;
    type sram_array is array (0 to 2**sram_addr_wd - 1)
      of std_logic_vector (31 downto 0);
    variable sram : sram_array := (0 => x"0000_0000",
                                   1 => x"0000_0001",
                                   2 => x"0000_0002",
                                   3 => x"0000_0003",

                                   4 => x"0000_0004",
                                   5 => x"0000_0500",
                                   6 => x"0006_0000",
                                   7 => x"0700_0000",
                                   others => x"8765_4321");
    variable idx : natural;
    variable int_cnt : natural;
    variable ack_cnt : natural;
  begin
    if rising_edge (clk_i) then
      if rst_n_o = '0' then
        ERR_i <= '0';
        STALL_i <= '0';
        ACK_i <= '0';

        int_cnt := 0;
        err_8000 <= 0;
        ack_cnt := 0;
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

        if STB_o = '1' and CYC_o = '1' then
          ACK_i <= '1';

          case ADR_o(15 downto 12) is
            when "0000" =>
              idx := to_integer (unsigned (ADR_o (sram_addr_wd - 1 downto 0)));
              if WE_o = '0' then
                --  Read SRAM
                DAT_i <= sram (idx);
              else
                -- Write SRAM
                for i in 3 downto 0 loop
                  if SEL_o(i) = '1' then
                    sram(idx)(8*i + 7 downto 8*i) := DAT_o (8*i + 7 downto 8*i);
                  end if;
                end loop;
              end if;
            when "0001" =>
              if ADR_o (0) = '0' then
                if WE_o = '0' then
                  -- Read counter
                  DAT_i <= std_logic_vector (to_unsigned (int_cnt, 32));
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
            when "0010" =>
              -- report hex8(ADR_o);
              if ADR_o (8 downto 0) = b"0_0000_0000" then
                err_8000 <= err_8000 + 1;
              end if;
              DAT_i <= x"8000" & ADR_o(15 downto 0);
            when "0011" =>
              DAT_i <= x"c000" & ADR_o(15 downto 0);
              if ACK_i = '1' then
                --  Was ack'ed, waiting until cyc/stb are deasserted.
                null;
              elsif ack_cnt = 16 then
                --  End of delay (note that ACK was set)
                ack_cnt := 0;
              else
                --  Ack is being delayed.  As ACK was set, clear it.
                ack_cnt := ack_cnt + 1;
                ACK_i <= '0';
              end if;
            when others =>
              DAT_i <= (others => '0');
          end case;
        else
          assert ack_cnt = 0 report "cyc/stb interrupted" severity warning;
        end if;
      end if;
    end if;
  end process;

  VME_IACKIN_n_i <= VME_IACK_n_i;

  tb: process
    constant c_log : boolean := False;

    -- Convert a CR/CSR address to the VME address: insert GA.
    -- The ADDR is on 20 bits (so the x"" notation can be used), but as
    -- ADDR(19) is stipped, it must be '0'.
    function to_vme_cfg_addr (addr : cfg_addr_t)
      return std_logic_vector is
    begin
      assert addr (19) = '0' report "a19 is discarded" severity error;
      return x"00" & slave_ga & addr (18 downto 0);
    end to_vme_cfg_addr;

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
        --  Simulate propagation.
        wait for 50 ns;
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

    procedure read32 (addr : std_logic_vector (31 downto 0);
                      am : vme_am_t;
                      variable data : out lword_t)
    is
      variable res : lword_t;
    begin
      if c_log then
        write (output, "read32 at 0x" & hex (addr) & " ["
               & Image_AM (to_integer (unsigned (am))) & " ]" & LF);
      end if;

      VME_LWORD_n_i <= '0';
      read_setup_addr (addr, am);

      assert addr (1 downto 0) = "00" report "unaligned read32" severity error;
      VME_DS_n_i <= "00";
      read_wait_dtack;
      if bus_timer = '0' then
        res := VME_DATA_o (31 downto 0);
      else
        if c_log then
          write (output, " TIMEOUT!" & LF);
        end if;
        res := (others => 'X');
        wait for 1 ns;
      end if;
      data := res;

      read_release;

      if c_log then
        write (output, " => 0x" & hex(res) & LF);
      end if;
    end read32;

    procedure read8_conf (addr : cfg_addr_t;
                          variable data : out byte_t) is
    begin
      read8 (to_vme_cfg_addr (addr), c_AM_CR_CSR, data);
    end read8_conf;

    procedure read8_conf_mb (addr : cfg_addr_t;
                             variable data : out std_logic_vector)
    is
      variable ad : cfg_addr_t := addr;
      constant bsize : natural := data'length / 8;
      subtype d_type is std_logic_vector (bsize * 8 - 1 downto 0);
      alias d : d_type is data;
    begin
      assert data'length mod 8 = 0 report "data is not a multiple of bytes"
        severity error;
      for i in bsize - 1 downto 0 loop
        read8_conf (ad, d (i * 8 + 7 downto i * 8));
        ad := cfg_addr_t (unsigned(ad) + 4);
      end loop;
    end read8_conf_mb;

    procedure read_blt_end_cycle is
    begin
      VME_DS_n_i <= "11";
      wait until (VME_DTACK_OE_o = '0' or VME_DTACK_n_o = '1')
        and VME_BERR_n_o = '1';
    end read_blt_end_cycle;

    procedure read32_blt (addr : std_logic_vector (31 downto 0);
                          am : vme_am_t;
                          variable data : out lword_array_t) is
    begin
      VME_LWORD_n_i <= '0';
      read_setup_addr (addr, am);

      assert addr (1 downto 0) = "00"
        report "unaligned read32_blt" severity error;
      for i in data'range loop
        VME_DS_n_i <= "00";
        read_wait_dtack;
        if bus_timer = '0' then
          data (i) := VME_DATA_o (31 downto 0);
        else
          data (i) := (others => 'X');
        end if;
        if i /= data'right then
          read_blt_end_cycle;
        end if;
      end loop;

      read_release;
    end read32_blt;

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

    procedure read64_mblt (addr : std_logic_vector (31 downto 0);
                           am : vme_am_t;
                           variable data : out qword_array_t) is
    begin
      VME_LWORD_n_i <= '0';
      read_setup_addr (addr, am);
      VME_DS_n_i <= "00";
      read_wait_dtack;
      read_blt_end_cycle;

      assert addr (2 downto 0) = "000"
        report "unaligned read64_mblt" severity error;
      for i in data'range loop
        wait for 50 ns;
        VME_DS_n_i <= "00";
        read_wait_dtack;
        if bus_timer = '0' then
          data (i) := VME_ADDR_o & VME_LWORD_n_o & VME_DATA_o;
        else
          data (i) := (others => 'X');
          VME_DS_n_i <= "11";
          exit;
        end if;
        if i /= data'right then
          read_blt_end_cycle;
        end if;
      end loop;

      read_release;
    end read64_mblt;

    procedure read64_2esst (addr : std_logic_vector (31 downto 0);
                            xam : vme_xam_t;
                            variable data : out qword_array_t)
    is
      variable odd : boolean;
    begin
      assert addr (3 downto 0) = "0000"
        report "unaligned read64_2e" severity error;
      assert data'length mod 2 = 0 severity error;

      --  Phase 1.
      VME_LWORD_n_i <= xam(0);
      read_setup_addr (addr (31 downto 8) & xam (7 downto 1) & '0', b"10_0000");
      VME_DATA_i <= x"0000_0000";
      VME_DS_n_i <= "10";
      wait until (VME_DTACK_OE_o = '1' and VME_DTACK_n_o = '0')
        or bus_timer = '1';
      --  Phase 2.
      VME_ADDR_i <= x"01" & x"00" & std_logic_vector(to_unsigned(data'length / 2, 8)) & addr (7 downto 1);
      VME_DATA_i <= x"00_00_00_0" & x"0";
      VME_LWORD_n_i <= addr (0);
      wait for 5 ns;
      VME_DS_n_i <= "11";
      wait until (VME_DTACK_OE_o = '1' and VME_DTACK_n_o = '1')
        or bus_timer = '1';
      --  Phase 3.
      VME_ADDR_i <= (others => '0');
      VME_DATA_i <= x"0000_0000";
      wait for 5 ns;
      VME_DS_n_i <= "10";
      wait until (VME_DTACK_OE_o = '1' and VME_DTACK_n_o = '0')
        or bus_timer = '1';

      VME_DS_n_i <= "00";

      odd := true;
      for i in data'range loop
        if odd then
          wait until (VME_DTACK_OE_o = '1' and VME_DTACK_n_o = '1')
            or bus_timer = '1';
        else
          wait until (VME_DTACK_OE_o = '1' and VME_DTACK_n_o = '0')
            or bus_timer = '1';
        end if;
        odd := not odd;
        data (i) := VME_ADDR_o & VME_LWORD_n_o & VME_DATA_o;
      end loop;

      --  2eSST 2.8 Transfer termination
      --  Transfers always terminate on an even beat.
      --
      --  The slave terminates a read transfer by stopping the
      --  data transmission and then asserting RETRY*/RESP* and
      --  BERR*.
      wait until (VME_BERR_n_o = '0' and VME_RETRY_n_o = '0' and VME_RETRY_OE_o = '1');

      --  The master will respond by negating DS0*
      VME_DS_n_i <= "11";

      read_release;
    end read64_2esst;

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

    procedure write32 (addr : std_logic_vector (31 downto 0);
                       am : vme_am_t;
                       data : lword_t) is
    begin
      assert addr(1 downto 0) = "00"
        report "unaligned write16" severity error;

      write_setup_addr (addr, '0', am);

      VME_DS_n_i <= "00";
      VME_DATA_i (31 downto 0) <= data;

      write_wait_dtack;
    end write32;

    procedure write32_blt (addr : std_logic_vector (31 downto 0);
                           am : vme_am_t;
                           data : lword_array_t) is
    begin
      assert addr(1 downto 0) = "00"
        report "unaligned write32" severity error;

      write_setup_addr (addr, '0', am);

      for i in data'range loop
        VME_DS_n_i <= "00";
        VME_DATA_i (31 downto 0) <= data (i);

        write_wait_dtack_pulse;
      end loop;

      VME_AS_n_i <= '1';
    end write32_blt;

    procedure write64_mblt (addr : std_logic_vector (31 downto 0);
                            am : vme_am_t;
                            data : qword_array_t) is
    begin
      assert addr(2 downto 0) = "000"
        report "unaligned write64" severity error;

      write_setup_addr (addr, '0', am);
      VME_DS_n_i <= "00";
      write_wait_dtack_pulse;

      for i in data'range loop
        VME_DS_n_i <= "00";
        VME_DATA_i (31 downto 0) <= data (i)(31 downto 0);
        VME_LWORD_n_i <= data (i)(32);
        VME_ADDR_i <= data(i)(63 downto 33);

        write_wait_dtack_pulse;
      end loop;

      VME_AS_n_i <= '1';
    end write64_mblt;

    procedure write8_conf (addr : cfg_addr_t;
                           data : byte_t)
    is
      variable li : line;
    begin
      if c_log then
        write (li, string'("write8_conf at 0x"));
        hwrite (li, addr);
        write (li, string'(" <= "));
        hwrite (li, data);
        writeline (output, li);
      end if;

      write8(to_vme_cfg_addr (addr), c_AM_CR_CSR, data);
    end write8_conf;

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

    procedure Dump_CR
    is
      variable d : byte_t;
      variable b3 : std_logic_vector (23 downto 0);
      variable w : std_logic_vector (31 downto 0);
      variable b8 : std_logic_vector (63 downto 0);
      variable b32 : std_logic_vector (255 downto 0);
    begin
      read8_conf (x"0_0003", d);
      write (output, "CR checksum:     0x" & hex2 (d) & LF);

      read8_conf (x"0_0013", d);
      assert d = x"81" report "invalid data width at 0x13" severity error;
      write (output, "CR data width:   0x" & hex2 (d) & LF);

      read8_conf (x"0_0017", d);
      assert d = x"81" report "invalid data width at 0x17" severity error;
      write (output, "CSR data width:  0x" & hex2 (d) & LF);

      read8_conf (x"0_001b", d);
      assert d = x"02" report "invalid spec ID at 0x1b" severity error;
      write (output, "CR/CSR version:  0x" & hex2 (d) & LF);

      read8_conf (x"0_001f", d);
      assert d = x"43" report "invalid valid CR byte at 0x1f" severity error;
      write (output, "CR valid 'C':    0x" & hex2 (d) & LF);

      read8_conf (x"0_0023", d);
      assert d = x"52" report "invalid valid CR byte at 0x23" severity error;
      write (output, "CR valid 'R':    0x" & hex2 (d) & LF);

      read8_conf_mb (x"0_0027", b3);
      write (output, "CR Manu ID:      0x" & hex6 (b3) & LF);

      read8_conf_mb (x"0_0033", w);
      write (output, "CR Board ID:     0x" & hex8 (w) & LF);

      read8_conf_mb (x"0_0043", w);
      write (output, "CR Rev ID:       0x" & hex8 (w) & LF);

      read8_conf_mb (x"0_0053", b3);
      write (output, "CR ASCII ptr:    0x" & hex6 (b3) & LF);

      read8_conf (x"0_007F", d);
      write (output, "CR Program ID:   0x" & hex2 (d) & LF);

      --  VME64x
      read8_conf_mb (x"0_0083", b3);
      write (output, "CR BEG_USER_CR:  0x" & hex6 (b3) & LF);

      read8_conf_mb (x"0_008F", b3);
      write (output, "CR END_USER_CR:  0x" & hex6 (b3) & LF);

      read8_conf_mb (x"0_009B", b3);
      write (output, "CR BEG_CRAM:     0x" & hex6 (b3) & LF);

      read8_conf_mb (x"0_00A7", b3);
      write (output, "CR END_CRAM:     0x" & hex6 (b3) & LF);

      read8_conf_mb (x"0_00B3", b3);
      write (output, "CR BEG_USER_CSR: 0x" & hex6 (b3) & LF);

      read8_conf_mb (x"0_00B3", b3);
      write (output, "CR END_USER_CSR: 0x" & hex6 (b3) & LF);

      read8_conf_mb (x"0_00CB", b3);
      write (output, "CR BEG_SN:       0x" & hex6 (b3) & LF);

      read8_conf_mb (x"0_00D7", b3);
      write (output, "CR END_SN:       0x" & hex6 (b3) & LF);

      read8_conf (x"0_00E3", d);
      write (output, "CR Slave charac: 0x" & hex2 (d) & LF);

      read8_conf (x"0_00E7", d);
      write (output, "CR user-def:     0x" & hex2 (d) & LF);

      read8_conf (x"0_00EB", d);
      write (output, "CR master chara: 0x" & hex2 (d) & LF);

      read8_conf (x"0_00EF", d);
      write (output, "CR user-def:     0x" & hex2 (d) & LF);

      read8_conf (x"0_00F3", d);
      write (output, "CR INT hand cap: 0x" & hex2 (d) & LF);

      read8_conf (x"0_00F7", d);
      write (output, "CR INT cap:      0x" & hex2 (d) & LF);

      read8_conf (x"0_00FF", d);
      write (output, "CR CRAM acc wd:  0x" & hex2 (d) & LF);

      for i in 0 to 7 loop
        read8_conf (std_logic_vector (unsigned'(x"0_0103") + i * 4), d);
        write (output, "CR FN" & natural'image (i) & " DAW:     0x"
               & hex2 (d) & "  [" & Disp_DAWPR (d) & ']' & LF);
      end loop;

      for i in 0 to 7 loop
        read8_conf_mb (std_logic_vector (unsigned'(x"0_0123") + i * 32), b8);
        write (output, "CR FN" & natural'image (i) & " AMCAP:    0x"
               & hex (b8) & " [");
        Disp_AMCAP (b8);
        write (output, " ]" & LF);
      end loop;


      read8_conf_mb (x"0_0223", b32);
      write (output, "CR FN0 XAMCAP:   0x" & hex (b32) & LF);
      read8_conf_mb (x"0_02a3", b32);
      write (output, "CR FN1 XAMCAP:   0x" & hex (b32) & LF);
      --  ...

      read8_conf_mb (x"0_0623", w);
      write (output, "CR FN0 ADEM:     0x" & hex (w) & LF);
      read8_conf_mb (x"0_0633", w);
      write (output, "CR FN1 ADEM:     0x" & hex (w) & LF);
      -- ...

      read8_conf_mb (x"7_FF63", w);
      write (output, "CR FN0 ADER:     0x" & hex (w) & LF);
      read8_conf_mb (x"7_FF73", w);
      write (output, "CR FN1 ADER:     0x" & hex (w) & LF);

      read8_conf (x"0_06af", d);
      write (output, "CR master DAWPR: 0x" & hex2 (d) & LF);

      read8_conf_mb (x"0_06b3", b8);
      write (output, "CR master AMCAP: 0x" & hex (b8) & LF);

      read8_conf_mb (x"0_06d3", b32);
      write (output, "CR mastr XAMCAP: 0x" & hex (b32) & LF);
    end Dump_CR;

    variable d8 : byte_t;
    variable d16 : word_t;
    variable d32 : lword_t;

    variable v64 : qword_array_t (0 to 16);
    variable v32 : lword_array_t (0 to 16);
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
        --  Disp CR/CSR

        --  Read CSR
        read8_conf (x"7_FFFF", d8);
        assert d8 = slave_ga & "000"
          report "bad CR/CSR BAR value" severity error;

        read8_conf (x"7_FFFB", d8);
        write (output, "CSR bit reg:     0x" & hex (d8) & LF);
        read8_conf (x"7_FFEF", d8);
        write (output, "CSR usr bit reg: 0x" & hex (d8) & LF);

        --  READ CR
        Dump_CR;

      when 1 =>
        --  WB data access

        --  Check ADER is 0
        read8_conf (x"7_ff63", d8);
        assert d8 = x"00" report "bad initial ADER0 value" severity error;

        -- Set ADER
        write8_conf (x"7_ff63", x"56");
        write8_conf (x"7_ff6f", c_AM_A32 & "00");
        read8_conf  (x"7_ff63", d8);
        assert d8 = x"56" report "bad ADER0 value" severity error;

        -- Try to read (but card is not yet enabled)
        read8 (x"56_00_00_00", c_AM_A32, d8);
        assert d8 = "XXXXXXXX" report "unexpected reply" severity error;

        -- Enable card
        write8_conf (x"7_fffb", b"0001_0000");
        read8_conf  (x"7_fffb", d8);
        assert d8 = b"0001_0000" report "module must be enabled"
          severity error;
        report "read data: " & hex (d8);

        --  WB read
        read8 (x"56_00_00_00", c_AM_A32, d8);
        assert d8 = x"00" report "bad read at 000" severity error;

        read8 (x"56_00_00_07", c_AM_A32, d8);
        assert d8 = x"01" report "bad read at 007" severity error;
        report "read data: " & hex (d8);

        read16 (x"56_00_00_12", c_AM_A32, d16);
        assert d16 = x"0004" report "bad read at 012" severity error;

        read16 (x"56_00_00_14", c_AM_A32, d16);
        assert d16 = x"0000" report "bad read at 012" severity error;

        read32 (x"56_00_00_14", c_AM_A32, d32);
        assert d32 = x"0000_0500" report "bad read at 014" severity error;

        -- WB write
        write8 (x"56_00_00_14", c_AM_A32, x"1f");
        read32 (x"56_00_00_14", c_AM_A32, d32);
        assert d32 = x"1f00_0500" report "bad read at 014 (2)" severity error;

        write16 (x"56_00_00_16", c_AM_A32, x"abcd");
        read32 (x"56_00_00_14", c_AM_A32, d32);
        assert d32 = x"1f00_abcd" report "bad read at 014 (3)" severity error;

        read32 (x"56_00_00_18", c_AM_A32, d32);
        assert d32 = x"0006_0000" report "bad read at 018 (1)" severity error;

        write32 (x"56_00_00_18", c_AM_A32, x"2345_6789");
        read32 (x"56_00_00_18", c_AM_A32, d32);
        assert d32 = x"2345_6789" report "bad read at 018 (2)" severity error;

      when 2 =>
        -- Test interrupts

        -- Set ADER
        write8_conf (x"7_ff63", x"67");
        write8_conf (x"7_ff6f", c_AM_A32 & "00");

        -- Enable card
        write8_conf (x"7_fffb", b"0001_0000");

        -- Set IRQ level
        write8_conf (x"7_ff5b", x"03");

        write8 (x"67_00_40_03", c_AM_A32, x"02");
        wait for 2 * g_CLOCK_PERIOD * 1 ns;
        assert VME_IRQ_n_o = "1111011" report "IRQ incorrectly reported"
          severity error;

        ack_int (d8);
        assert d8 = x"00" report "incorrect vector" severity error;
        assert VME_IRQ_n_o = "1111111" report "IRQ not disabled after ack"
          severity error;

        -- Set IRQ vector
        write8_conf (x"7_ff5f", x"a3");

        write8 (x"67_00_40_03", c_AM_A32, x"20");
        assert VME_IRQ_n_o = "1111111" report "IRQ not expected"
          severity error;
        wait for 32 * g_CLOCK_PERIOD * 1 ns;
        assert VME_IRQ_n_o = "1111011" report "IRQ incorrectly reported"
          severity error;

        ack_int (d8);
        assert d8 = x"a3" report "incorrect vector" severity error;
        assert VME_IRQ_n_o = "1111111" report "IRQ not disabled after ack"
          severity error;

      when 3 =>
        -- Test block transfers

        -- Set ADER
        write8_conf (x"7_ff63", x"64");
        write8_conf (x"7_ff6f", c_AM_A32_BLT & "00");

        -- Enable card
        write8_conf (x"7_fffb", b"0001_0000");

        read32_blt (x"64_00_00_10", c_AM_A32_BLT, v32 (0 to 4));
        assert v32 (0) = x"0000_0004"
          and  v32 (1) = x"0000_0500"
          and  v32 (2) = x"0006_0000"
          and  v32 (3) = x"0700_0000"
          and  v32 (4) = x"8765_4321"
          report "incorrect BLT data 32" severity error;

        if false then
          --  D16 BLT not supported
          read16_blt (x"64_00_00_14", c_AM_A32_BLT, v16 (0 to 5));
          assert v16 (0) = x"0000"
            and v16 (1) = x"0500"
            and v16 (2) = x"0006"
            and v16 (3) = x"0000"
            and v16 (4) = x"0700"
            and v16 (5) = x"0000"
            report "incorrect BLT data 16" severity error;
        end if;

        v32 (0 to 3) := (x"00_11_22_33",
                         x"44_55_66_77",
                         x"88_99_aa_bb",
                         x"cc_dd_ee_ff");
        write32_blt (x"64_00_01_00", c_AM_A32_BLT, v32 (0 to 3));
        read32_blt (x"64_00_01_00", c_AM_A32_BLT, v32 (0 to 4));
        assert v32 (0 to 4) = (x"00_11_22_33",
                               x"44_55_66_77",
                               x"88_99_aa_bb",
                               x"cc_dd_ee_ff",
                               x"87_65_43_21")
          report "incorrect BLT data 32 r/w" severity error;

      when 4 =>
        --  A24 tests
        --  A24 with weird MSBs in address

        -- Set ADER
        write8_conf (x"7_ff73", x"00");
        write8_conf (x"7_ff77", x"20");
        write8_conf (x"7_ff7f", c_AM_A24 & "00");

        -- Enable card
        write8_conf (x"7_fffb", b"0001_0000");

        read32 (x"00_20_00_10", c_AM_A24, d32);
        assert d32  = x"0000_0004"
          report "incorrect read 32" severity error;

        read32 (x"13_20_00_14", c_AM_A24, d32);
        assert d32  = x"0000_0500"
          report "incorrect read 32" severity error;

      when 5 =>
        -- Test err_i => BERR

        -- Set ADER
        write8_conf (x"7_ff73", x"00");
        write8_conf (x"7_ff77", x"20");
        write8_conf (x"7_ff7f", c_AM_A24 & "00");

        -- Enable card
        write8_conf (x"7_fffb", b"0001_0000");

        read32 (x"00_20_40_04", c_AM_A24, d32);
        assert d32  = (31 downto 0 => 'X')
          report "incorrect read 32" severity error;

      when 6 =>
        -- Test MBLT

        -- Set ADER
        write8_conf (x"7_ff63", x"64");
        write8_conf (x"7_ff6f", c_AM_A32_MBLT & "00");

        -- Enable card
        write8_conf (x"7_fffb", b"0001_0000");

        read64_mblt (x"64_00_00_10", c_AM_A32_MBLT, v64 (0 to 1));
        report "at 04: " & hex8 (v64(0)(63 downto 32));
        report "at 05: " & hex8 (v64(0)(31 downto  0));
        report "at 06: " & hex8 (v64(1)(63 downto 32));
        report "at 07: " & hex8 (v64(1)(31 downto  0));
        assert v64 (0) = x"0000_0004_0000_0500"
          and  v64 (1) = x"0006_0000_0700_0000"
          report "incorrect MBLT data 64" severity error;

        v64 (0 to 3) := (x"00_11_22_33_44_55_66_77",
                         x"88_99_aa_bb_cc_dd_ee_ff",
                         x"01_23_45_67_89_ab_cd_ef",
                         x"fe_dc_ba_98_76_54_32_10");
        write64_mblt (x"64_00_01_00", c_AM_A32_MBLT, v64 (0 to 3));
        read64_mblt (x"64_00_01_00", c_AM_A32_MBLT, v64 (0 to 3));
        report "at 40: " & hex8 (v64(0)(63 downto 32));
        report "at 41: " & hex8 (v64(0)(31 downto  0));
        report "at 42: " & hex8 (v64(1)(63 downto 32));
        report "at 43: " & hex8 (v64(1)(31 downto  0));
        assert v64 (0 to 3) = (x"00_11_22_33_44_55_66_77",
                               x"88_99_aa_bb_cc_dd_ee_ff",
                               x"01_23_45_67_89_ab_cd_ef",
                               x"fe_dc_ba_98_76_54_32_10")
          report "incorrect MBLT data 64 r/w" severity error;

        --  Check prefetching.
        assert err_8000 = 0
         report "no 0x8000 error expected" severity error;
        read64_mblt (x"64_00_87_e0", c_AM_A32_MBLT, v64 (0 to 3));
        report "at e0: " & hex8 (v64(0)(63 downto 32));
        report "at e8: " & hex8 (v64(0)(31 downto  0));
        report "at f0: " & hex8 (v64(1)(63 downto 32));
        report "at f8: " & hex8 (v64(1)(31 downto  0));
        assert v64 (0 to 3) = (x"80_00_21_f8_80_00_21_f9",
                               x"80_00_21_fa_80_00_21_fb",
                               x"80_00_21_fc_80_00_21_fd",
                               x"80_00_21_fe_80_00_21_ff")
          report "incorrect MBLT data 64" severity error;
        assert err_8000 = 0
          report "no 0x8000 error expected" severity error;

      when 7 =>
        --  Delayed DS

        -- Set ADER
        write8_conf (x"7_ff63", x"67");
        write8_conf (x"7_ff6f", c_AM_A32 & "00");

        -- Enable card
        write8_conf (x"7_fffb", b"0001_0000");

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

      when 8 | 9 =>
        --  Check AM decoders (8: DECODE_AM = true, 9: DECODE_AM = false)

        -- Set ADER
        write8_conf (x"7_ff63", x"56");
        write8_conf (x"7_ff6f", c_AM_A32 & "00");
        read8_conf  (x"7_ff63", d8);
        assert d8 = x"56" report "bad ADER0 value" severity error;

        -- Enable card
        write8_conf (x"7_fffb", b"0001_0000");

        --  WB read
        read8 (x"56_00_00_00", c_AM_A32, d8);
        assert d8 = x"00" report "bad read at 000" severity error;

        -- Try to read with a wrong AM.
        read8 (x"56_00_00_00", c_AM_A32_SUP, d8);
        if g_SCENARIO = 8 then
          assert d8 = "XXXXXXXX" report "unexpected reply (a32sup)" severity error;
        else
          assert d8 = x"00"
            report "bad read at 000 (no AM decode)" severity error;
        end if;

        --  However, the A24 decoder is not enabled.
        read8 (x"56_00_00_00", c_AM_A24, d8);
        if g_SCENARIO = 8 then
          assert d8 = "XXXXXXXX" report "unexpected reply (a24s)" severity error;
        else
          assert d8 = x"00"
            report "bad read at 000 (no AM decode)" severity error;
        end if;

      when 10 =>
        -- Test 2eSST

        -- Set ADER
        write8_conf (x"7_ff63", x"64");
        write8_conf (x"7_ff6f", c_AM_2eVME_6U & "00");

        -- Enable card
        write8_conf (x"7_fffb", b"0001_0000");

        read64_2esst (x"64_00_00_10", c_XAM_A32_2ESST, v64 (0 to 1));
        report "at 04: " & hex8 (v64(0)(63 downto 32));
        report "at 05: " & hex8 (v64(0)(31 downto  0));
        report "at 06: " & hex8 (v64(1)(63 downto 32));
        report "at 07: " & hex8 (v64(1)(31 downto  0));
        assert v64 (0) = x"0000_0004_0000_0500"
          and  v64 (1) = x"0006_0000_0700_0000"
          report "incorrect MBLT data 64" severity error;

      when 11 =>
          -- Test MBLT prefetching

          -- Set ADER
          write8_conf (x"7_ff63", x"64");
          write8_conf (x"7_ff6f", c_AM_A32_MBLT & "00");

          write8_conf (x"7_ff73", x"00");
          write8_conf (x"7_ff77", x"30");
          write8_conf (x"7_ff7f", c_AM_A24 & "00");

          -- Enable card
          write8_conf (x"7_fffb", b"0001_0000");

          assert err_8000 = 0
           report "no 0x8000 error expected" severity error;
          read64_mblt (x"64_00_87_e0", c_AM_A32_MBLT, v64 (0 to 3));
          report "at e0: " & hex8 (v64(0)(63 downto 32));
          report "at e8: " & hex8 (v64(0)(31 downto  0));
          report "at f0: " & hex8 (v64(1)(63 downto 32));
          report "at f8: " & hex8 (v64(1)(31 downto  0));
          assert v64 (0 to 3) = (x"80_00_21_f8_80_00_21_f9",
                                 x"80_00_21_fa_80_00_21_fb",
                                 x"80_00_21_fc_80_00_21_fd",
                                 x"80_00_21_fe_80_00_21_ff")
            report "incorrect MBLT data 64" severity error;
          assert err_8000 = 0
            report "no 0x8000 error expected" severity error;

          read64_mblt (x"64_00_c0_00", c_AM_A32_MBLT, v64 (0 to 3));
          report "at 00: " & hex8 (v64(0)(63 downto 32));
          report "at 08: " & hex8 (v64(0)(31 downto  0));
          report "at 00: " & hex8 (v64(1)(63 downto 32));
          report "at 08: " & hex8 (v64(1)(31 downto  0));
          assert v64 (0 to 3) = (x"c0_00_30_00_c0_00_30_01",
                                 x"c0_00_30_02_c0_00_30_03",
                                 x"c0_00_30_04_c0_00_30_05",
                                 x"c0_00_30_06_c0_00_30_07")
            report "incorrect MBLT data 64" severity error;

          read32 (x"00_30_c0_10", c_AM_A24, d32);
          report "at 10: " & hex8(d32);
          assert d32  = x"C000_3004"
            report "incorrect read 32" severity error;

          --  TODO: check IACK propagation.
    end case;

    wait for 4 * g_CLOCK_PERIOD * 1 ns;
    end_tb <= true;
    assert false report "end of simulation" severity note;
    wait;
  end process;
end behaviour;
