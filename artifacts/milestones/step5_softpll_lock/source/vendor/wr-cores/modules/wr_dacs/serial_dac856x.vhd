library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity serial_dac856x is
  generic (
    --  SCLK is CLK / (g_sclk_div + 1)
    g_sclk_div : positive := 1;
    g_internal_ref : std_logic := '1'
  );
  port (
    clk_i     :     std_logic;
    rst_n_i   :     std_logic;

    --  Value to be sent for output A.
    value_a_i :     std_logic_vector (15 downto 0);
    wr_a_i    :     std_logic;

    value_b_i :     std_logic_vector (15 downto 0);
    wr_b_i    :     std_logic;

    --  SPI interface
    sclk_o    : out std_logic;
    d_o       : out std_logic;
    sync_n_o  : out std_logic
  );
end serial_dac856x;

architecture behav of serial_dac856x is
  --  Initialization state machine.
  type t_state is (S_WAIT, S_CMD_SYNC, S_CMD_REF, S_CMD_GAIN, S_DONE);
  signal state : t_state;

  --  Serial clock generation.
  signal sclk_p : std_logic;
  signal sclk_cnt : natural range g_sclk_div - 1 downto 0;

  --  Data to be sent.
  signal set_a, set_b : std_logic;
  signal val_a, val_b : std_logic_vector(15 downto 0);

  subtype t_clk_count is natural range (24 + 4) - 1 downto 0;
  signal clk_count : t_clk_count;
  signal edge : std_logic;
  signal buf : std_logic_vector(23 downto 0);
  signal busy : std_logic;
begin
  --  Clock divider.
  process (clk_i)
  begin
    if rising_edge(clk_i) then
      sclk_p <= '0';

      if rst_n_i = '0' or busy = '0' then
        sclk_cnt <= g_sclk_div - 1;
      else
        if sclk_cnt = 0 then
          sclk_p <= '1';
          sclk_cnt <= g_sclk_div - 1;
        else
          sclk_cnt <= sclk_cnt - 1;
        end if;
      end if;
    end if;
  end process;

  --  General state machine
  process (clk_i)
  begin
    if rising_edge(clk_i) then
      if rst_n_i = '0' then
        busy <= '0';
        sclk_o <= '1';
        sync_n_o <= '1';
        d_o <= '0';
        set_a <= '0';
        set_b <= '0';

        state <= S_WAIT;
        clk_count <= 16;
      else
        --  Accept values.  Will overwrite but not corrupt current values.
        if wr_a_i = '1' then
          val_a <= value_a_i;
          set_a <= '1';
        end if;
        if wr_b_i = '1' then
          val_b <= value_b_i;
          set_b <= '1';
        end if;

        if busy = '1' then
          --  Transmit, but only on clock divider pulses.
          --  Send 24 bits and then wait for 4 cycles.
          --  Set the data on the rising edge (it is sampled on the falling edge)
          if sclk_p = '1' then
            if clk_count > 3 then
              sclk_o <= edge;
            else
              --  Stop the clock after 24 bits, and make it silent.
              sclk_o <= '1';
            end if;
            if edge = '1' then
              if clk_count > 3 then
                sync_n_o <= '0';
                d_o <= buf(buf'high);
                buf <= buf(buf'high - 1 downto buf'low) & '0';
              else
                sync_n_o <= '1';
                d_o <= '0';
              end if;
            else
              if clk_count = 0 then
                busy <= '0';
              else
                clk_count <= clk_count - 1;
              end if;
            end if;
            edge <= not edge;
          end if;
        else
          clk_count <= t_clk_count'high;
          edge <= '1';
          case state is
            when S_WAIT =>
              if clk_count = 0 then
                state <= S_CMD_SYNC;
              else
                --  This overwrites clk_count!
                clk_count <= clk_count - 1;
              end if;
            when S_CMD_SYNC =>
              -- synchronous mode for dac-a and dac-b
              buf <= "XX" & "110" & "XXX" & "XXXXXXXXXXXXXX11";
              busy <= '1';
              state <= S_CMD_REF;
            when S_CMD_REF =>
              --  Set reference
              buf <= "XX" & "111" & "XXX" & "XXXXXXXXXXXXXXX" & g_internal_ref;
              busy <= '1';
              state <= S_CMD_GAIN;
            when S_CMD_GAIN =>
              --  Set gain (1 on both channels)
              buf <= "XX" & "010" & "XXX" & "XXXXXXXXXXXXXX" & "11";
              busy <= '1';
              state <= S_DONE;
            when S_DONE =>
              --  Choose (with implicit priority the new data to be transmitted).
              if set_a = '1' then
                buf <= b"00_011_000" & val_a;
                busy <= '1';
                set_a <= '0';
              elsif set_b = '1' then
                buf <= b"00_011_001" & val_b;
                busy <= '1';
                set_b <= '0';
              end if;
          end case;
        end if;
      end if;
    end if;
  end process;
end behav;
