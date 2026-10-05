-- Rejected Step7 diagnostic; archived here, not in the active Quartus project.
-- Restart the external clock IC and its controller together after FPGA load.
-- Use the independent board 50 MHz oscillator, never an SI5340 output clock.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity wr_si5340_startup_reset is
  generic (
    g_reset_cycles : positive := 50000;       -- 1 ms at 50 MHz
    g_settle_cycles : positive := 2500000     -- 50 ms after releasing RSTb
  );
  port (
    clk_i : in std_logic;
    board_reset_n_i : in std_logic;
    chip_reset_n_o : out std_logic;
    controller_reset_n_o : out std_logic
  );
end entity;

architecture rtl of wr_si5340_startup_reset is
  constant c_release : positive := g_reset_cycles + g_settle_cycles;
  -- Arria 10 implements this initial value at FPGA configuration, even when
  -- the external board reset pin remains high during a warm JTAG program.
  signal elapsed : natural range 0 to c_release := 0;
begin
  process(clk_i, board_reset_n_i)
  begin
    if board_reset_n_i = '0' then
      elapsed <= 0;
    elsif rising_edge(clk_i) then
      if elapsed < c_release then
        elapsed <= elapsed + 1;
      end if;
    end if;
  end process;

  chip_reset_n_o <= '1' when board_reset_n_i = '1' and
    elapsed >= g_reset_cycles else '0';
  controller_reset_n_o <= '1' when board_reset_n_i = '1' and
    elapsed = c_release else '0';
end architecture;
