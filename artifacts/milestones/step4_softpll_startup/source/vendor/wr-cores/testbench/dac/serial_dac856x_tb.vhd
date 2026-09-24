library ieee;
use ieee.std_logic_1164.all;

entity serial_dac856x_tb is
end;

architecture arch of serial_dac856x_tb is
  signal clk, rst_n : std_logic;
  signal din, sync_n, sclk : std_logic;
  signal value_a, value_b : std_logic_vector(15 downto 0);
  signal wr_a, wr_b : std_logic;
begin
  inst_dut: entity work.serial_dac856x
    generic map (
      g_sclk_div => 1
      )
    port map (
      clk_i => clk,
      rst_n_i => rst_n,
      value_a_i => value_a,
      wr_a_i => wr_a,
      value_b_i => value_b,
      wr_b_i => wr_b,

      sclk_o => sclk,
      d_o => din,
      sync_n_o => sync_n
      );

  process
  begin
    clk <= '0';
    wait for 4 ns;
    clk <= '1';
    wait for 4 ns;
  end process;

  rst_n <= '0', '1' after 8 ns;

  process
  begin
    wr_a <= '0';
    wr_b <= '0';
    wait until rising_edge(clk) and rst_n = '1';
    value_a <= x"f549";
    wr_a <= '1';
    wait until rising_edge(clk);

    value_a <= (others => 'X');
    wr_a <= '0';
    wait until rising_edge(clk);

    --  TODO: real test
    wait;
  end process;

  process (sclk, sync_n)
    variable buf : std_logic_vector(23 downto 0);
    variable cnt : natural;
  begin
    if sync_n = '1' then
      cnt := 0;
    elsif falling_edge(sclk) then
      buf := buf(22 downto 0) & din;
      cnt := cnt + 1;
      if cnt = 24 then
        report "received:" & to_string(buf) & " " & to_hstring(buf);
      end if;
    end if;
  end process;
end;
