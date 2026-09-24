library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity v5_gtp_comma_detect is
  port (
    clk_rx_i : in std_logic;
    rst_n_i  : in std_logic;

    rx_data_raw_i : in std_logic_vector(9 downto 0);

    rx_is_comma_o : out std_logic;
    link_up_o : out std_logic;
    aligned_o : out std_logic
    );

end v5_gtp_comma_detect;

architecture rtl of v5_gtp_comma_detect is

  type t_state is (SYNC_LOST, SYNC_CHECK, SYNC_ACQUIRED);

  constant c_IDLE_LENGTH_UP   : integer := 500;
  constant c_IDLE_LENGTH_LOSS : integer := 1000;

  constant c_COMMA_SHIFT_WE_WANT : integer := 0;
-- fixme

  signal rx_data_d0     : std_logic_vector(9 downto 0);
  signal rx_data_merged : std_logic_vector(19 downto 0);

  signal first_comma : std_logic_vector(4 downto 0);
  signal cnt         : unsigned(15 downto 0);
  signal state       : t_state;
  signal comma_found : std_logic_vector(9 downto 0);

  
  function f_onehot_encode (x : std_logic_vector; output_bits : integer)return std_logic_vector is
    variable rv : std_logic_vector(output_bits-1 downto 0);
  begin
    for i in 0 to x'length-1 loop
      if x(i) = '1' then
        rv := std_logic_vector(to_unsigned(i, output_bits));
        return rv;
      end if;
    end loop;

    return std_logic_vector(to_unsigned(0, output_bits));
  end f_onehot_encode;

  constant c_K28_5_PLUS : std_logic_vector(9 downto 0) := "1100000101"; --"1010000011";

  signal comma_pos            : std_logic_vector(4 downto 0);
  signal prev_comma_pos       : std_logic_vector(4 downto 0);
  signal prev_comma_pos_valid : std_logic;
  signal comma_pos_valid      : std_logic;
  signal link_up : std_logic;
  signal link_aligned : std_logic;
  
begin


  process(clk_rx_i)
  begin
    if rising_edge(clk_rx_i) then
      if rst_n_i = '0' then
        comma_found <= (others => '0');
      else
        rx_data_d0                  <= rx_data_raw_i;
        rx_data_merged(19 downto 0) <= rx_data_d0 & rx_data_raw_i;
        for i in 0 to 9 loop
          if rx_data_merged(i + 9 downto i) = c_K28_5_PLUS or
            rx_data_merged(i + 9 downto i) = (not c_K28_5_PLUS) then
            comma_found(i) <= '1';
          else
            comma_found(i) <= '0';
          end if;
        end loop;

        comma_pos <= f_onehot_encode(comma_found, comma_pos'length);

        if unsigned(comma_found) /= 0 then
          comma_pos_valid <= '1';
        else
          comma_pos_valid <= '0';
        end if;
      end if;
    end if;
  end process;

  process(clk_rx_i)
  begin
    if rising_edge(clk_rx_i) then
      if rst_n_i = '0' then
        link_aligned <= '0';
      else
        if comma_pos_valid = '1' then
          if unsigned(comma_pos) = c_COMMA_SHIFT_WE_WANT then
            link_aligned <= '1';
          else
            link_aligned <= '0';
          end if;
        end if;
      end if;
    end if;
  end process;

  rx_is_comma_o <= '1' when unsigned(comma_found) /= 0 else '0';

  aligned_o <= link_aligned;
  link_up_o <= link_up;
  
end rtl;

