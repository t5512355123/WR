-- Minimal read-only I2C master for QSFP/SFP EEPROM diagnostics.
-- The reader accesses address 0x50, selects byte offset 0x14, and reads
-- eight bytes of the vendor-name field. The top level converts the two
-- drive-low outputs to open-drain pins.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sfp_eeprom_reader is
  port (
    i_clk          : in  std_logic;
    i_reset_n      : in  std_logic;
    i_start        : in  std_logic;
    i_scl          : in  std_logic;
    i_sda          : in  std_logic;
    o_scl_drive_low: out std_logic;
    o_sda_drive_low: out std_logic;
    o_busy         : out std_logic;
    o_done         : out std_logic;
    o_ack_error    : out std_logic;
    o_read_index   : out std_logic_vector(3 downto 0);
    o_data         : out std_logic_vector(63 downto 0)
  );
end entity;

architecture rtl of sfp_eeprom_reader is
  constant C_HALF_TICKS : integer := 249;
  constant C_EEPROM_OFFSET : std_logic_vector(7 downto 0) := x"14";

  type state_t is (
    ST_IDLE,
    ST_START_A,
    ST_START_B,
    ST_WRITE_BIT_SETUP,
    ST_WRITE_BIT_RISE,
    ST_WRITE_BIT_FALL,
    ST_WRITE_ACK_SETUP,
    ST_WRITE_ACK_RISE,
    ST_WRITE_ACK_SAMPLE,
    ST_WRITE_ACK_FALL,
    ST_RESTART_A,
    ST_RESTART_B,
    ST_RESTART_C,
    ST_READ_BIT_SETUP,
    ST_READ_BIT_RISE,
    ST_READ_BIT_SAMPLE,
    ST_READ_BIT_FALL,
    ST_READ_ACK_SETUP,
    ST_READ_ACK_RISE,
    ST_READ_ACK_FALL,
    ST_STOP_A,
    ST_STOP_B,
    ST_ERROR
  );

  signal state_r          : state_t := ST_IDLE;
  signal divider_r        : integer range 0 to C_HALF_TICKS := C_HALF_TICKS;
  signal busy_r           : std_logic := '0';
  signal done_r           : std_logic := '0';
  signal ack_error_r      : std_logic := '0';
  signal started_r        : std_logic := '0';
  signal scl_drive_low_r  : std_logic := '0';
  signal sda_drive_low_r  : std_logic := '0';
  signal bit_index_r      : integer range 0 to 7 := 7;
  signal read_index_r     : integer range 0 to 7 := 0;
  signal tx_stage_r       : integer range 0 to 2 := 0;
  signal tx_byte_r        : std_logic_vector(7 downto 0) := (others => '0');
  signal rx_shift_r       : std_logic_vector(7 downto 0) := (others => '0');
  signal data_r           : std_logic_vector(63 downto 0) := (others => '0');
  signal ack_bad_r        : std_logic := '0';

begin
  o_scl_drive_low <= scl_drive_low_r;
  o_sda_drive_low <= sda_drive_low_r;
  o_busy          <= busy_r;
  o_done          <= done_r;
  o_ack_error     <= ack_error_r;
  o_read_index    <= std_logic_vector(to_unsigned(read_index_r, 4));
  o_data          <= data_r;

  process(i_clk)
  begin
    if rising_edge(i_clk) then
      if i_reset_n = '0' then
        state_r         <= ST_IDLE;
        divider_r       <= C_HALF_TICKS;
        busy_r          <= '0';
        done_r          <= '0';
        ack_error_r     <= '0';
        started_r       <= '0';
        scl_drive_low_r <= '0';
        sda_drive_low_r <= '0';
        bit_index_r     <= 7;
        read_index_r    <= 0;
        tx_stage_r      <= 0;
        tx_byte_r       <= (others => '0');
        rx_shift_r      <= (others => '0');
        data_r          <= (others => '0');
        ack_bad_r       <= '0';
      elsif divider_r /= 0 then
        divider_r <= divider_r - 1;
      else
        divider_r <= C_HALF_TICKS;

        case state_r is
          when ST_IDLE =>
            scl_drive_low_r <= '0';
            sda_drive_low_r <= '0';
            if (i_start = '1') and (started_r = '0') then
              busy_r      <= '1';
              done_r      <= '0';
              ack_error_r <= '0';
              tx_stage_r  <= 0;
              tx_byte_r   <= x"A0";
              bit_index_r <= 7;
              state_r     <= ST_START_A;
            end if;

          when ST_START_A =>
            scl_drive_low_r <= '0';
            sda_drive_low_r <= '1';
            state_r         <= ST_START_B;

          when ST_START_B =>
            scl_drive_low_r <= '1';
            sda_drive_low_r <= '1';
            state_r         <= ST_WRITE_BIT_SETUP;

          when ST_WRITE_BIT_SETUP =>
            scl_drive_low_r <= '1';
            if tx_byte_r(bit_index_r) = '0' then
              sda_drive_low_r <= '1';
            else
              sda_drive_low_r <= '0';
            end if;
            state_r <= ST_WRITE_BIT_RISE;

          when ST_WRITE_BIT_RISE =>
            scl_drive_low_r <= '0';
            state_r         <= ST_WRITE_BIT_FALL;

          when ST_WRITE_BIT_FALL =>
            scl_drive_low_r <= '1';
            if bit_index_r = 0 then
              state_r <= ST_WRITE_ACK_SETUP;
            else
              bit_index_r <= bit_index_r - 1;
              state_r     <= ST_WRITE_BIT_SETUP;
            end if;

          when ST_WRITE_ACK_SETUP =>
            scl_drive_low_r <= '1';
            sda_drive_low_r <= '0';
            state_r         <= ST_WRITE_ACK_RISE;

          when ST_WRITE_ACK_RISE =>
            scl_drive_low_r <= '0';
            state_r         <= ST_WRITE_ACK_SAMPLE;

          when ST_WRITE_ACK_SAMPLE =>
            if i_sda = '1' then
              ack_bad_r <= '1';
            else
              ack_bad_r <= '0';
            end if;
            state_r <= ST_WRITE_ACK_FALL;

          when ST_WRITE_ACK_FALL =>
            scl_drive_low_r <= '1';
            if ack_bad_r = '1' then
              state_r <= ST_ERROR;
            elsif tx_stage_r = 0 then
              tx_stage_r  <= 1;
              tx_byte_r   <= C_EEPROM_OFFSET;
              bit_index_r <= 7;
              state_r     <= ST_WRITE_BIT_SETUP;
            elsif tx_stage_r = 1 then
              state_r <= ST_RESTART_A;
            else
              read_index_r <= 0;
              bit_index_r  <= 7;
              rx_shift_r   <= (others => '0');
              state_r      <= ST_READ_BIT_SETUP;
            end if;

          when ST_RESTART_A =>
            scl_drive_low_r <= '0';
            sda_drive_low_r <= '0';
            state_r         <= ST_RESTART_B;

          when ST_RESTART_B =>
            scl_drive_low_r <= '0';
            sda_drive_low_r <= '1';
            state_r         <= ST_RESTART_C;

          when ST_RESTART_C =>
            scl_drive_low_r <= '1';
            sda_drive_low_r <= '1';
            tx_stage_r      <= 2;
            tx_byte_r       <= x"A1";
            bit_index_r     <= 7;
            state_r         <= ST_WRITE_BIT_SETUP;

          when ST_READ_BIT_SETUP =>
            scl_drive_low_r <= '1';
            sda_drive_low_r <= '0';
            state_r         <= ST_READ_BIT_RISE;

          when ST_READ_BIT_RISE =>
            scl_drive_low_r       <= '0';
            state_r               <= ST_READ_BIT_SAMPLE;

          when ST_READ_BIT_SAMPLE =>
            rx_shift_r(bit_index_r) <= i_sda;
            state_r                 <= ST_READ_BIT_FALL;

          when ST_READ_BIT_FALL =>
            scl_drive_low_r <= '1';
            if bit_index_r = 0 then
              state_r <= ST_READ_ACK_SETUP;
            else
              bit_index_r <= bit_index_r - 1;
              state_r     <= ST_READ_BIT_SETUP;
            end if;

          when ST_READ_ACK_SETUP =>
            scl_drive_low_r <= '1';
            if read_index_r = 7 then
              sda_drive_low_r <= '0';
            else
              sda_drive_low_r <= '1';
            end if;
            state_r <= ST_READ_ACK_RISE;

          when ST_READ_ACK_RISE =>
            scl_drive_low_r <= '0';
            state_r         <= ST_READ_ACK_FALL;

          when ST_READ_ACK_FALL =>
            scl_drive_low_r <= '1';
            data_r(read_index_r * 8 + 7 downto read_index_r * 8) <= rx_shift_r;
            if read_index_r = 7 then
              state_r <= ST_STOP_A;
            else
              read_index_r <= read_index_r + 1;
              bit_index_r  <= 7;
              rx_shift_r   <= (others => '0');
              state_r      <= ST_READ_BIT_SETUP;
            end if;

          when ST_STOP_A =>
            scl_drive_low_r <= '0';
            sda_drive_low_r <= '1';
            state_r         <= ST_STOP_B;

          when ST_STOP_B =>
            scl_drive_low_r <= '0';
            sda_drive_low_r <= '0';
            busy_r          <= '0';
            done_r          <= '1';
            started_r       <= '1';
            state_r         <= ST_IDLE;

          when ST_ERROR =>
            scl_drive_low_r <= '0';
            sda_drive_low_r <= '0';
            busy_r          <= '0';
            done_r          <= '1';
            ack_error_r     <= '1';
            started_r       <= '1';
            state_r         <= ST_IDLE;
        end case;
      end if;
    end if;
  end process;
end architecture;
