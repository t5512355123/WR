library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity gtx_idle_detect_kintex7_lp is
  port (
    rst_rx_n_i    : in std_logic;
    clk_rx_62m5_i : in std_logic;
    clk_rx_250m_i : in std_logic;

    rx_data_raw_i : in std_logic_vector(39 downto 0);
    rx_data_raw_62m5_o : out std_logic_vector(19 downto 0);

    early_link_up_o : out std_logic;

    pat_latch_i : in  std_logic;
    pat_value_o : out std_logic_vector(239 downto 0)
    );

end gtx_idle_detect_kintex7_lp;

architecture rtl of gtx_idle_detect_kintex7_lp is

  constant c_LOOKAHEAD_BITS : integer := 10;
  constant c_OVERSAMPLE : integer := 4;

  constant c_TOTAL_BITS : integer := (20 + c_LOOKAHEAD_BITS) * c_OVERSAMPLE;
  constant c_SCAN_WINDOW_BITS : integer := ( 20 + c_LOOKAHEAD_BITS - 10 ) * c_OVERSAMPLE;
  constant c_NUM_COMMA_POS : integer := 20 * c_OVERSAMPLE;

  constant c_IDLE_LENGTH_UP   : integer                      := 500;
  constant c_IDLE_LENGTH_LOSS : integer                      := 10000;
  constant c_K28_5_PLUS       : std_logic_vector(9 downto 0) := "1010000011";

  signal rx_data_merged_x4_250m : std_logic_vector(c_TOTAL_BITS-1 downto 0);
  signal rx_data_merged_x4_62m_sh : std_logic_vector(c_TOTAL_BITS-1 downto 0);
  signal rx_data_merged_x4_62m  : std_logic_vector(c_TOTAL_BITS-1 downto 0);

  signal comma_found, comma_mask_first : std_logic_vector(c_NUM_COMMA_POS - 1 downto 0);

  attribute mark_debug : string;
  attribute mark_debug of rx_data_merged_x4_62m : signal is "true";
  attribute mark_debug of comma_found : signal is "true";

  type t_state is (SYNC_LOST, SYNC_CHECK, SYNC_ACQUIRED);

  signal cnt     : unsigned(15 downto 0);
  signal state   : t_state;
  signal link_up : std_logic;

  type t_comma_chk_array is array(integer range <>) of std_logic_vector(9 downto 0);
  signal commas_match_plus, commas_match_minus : t_comma_chk_array(0 to c_NUM_COMMA_POS-1);

  function f_reverse_bits (x : std_logic_vector) return std_logic_vector is
    variable rv : std_logic_vector(x'length-1 downto 0);
  begin
    for i in 0 to x'length-1 loop
      rv(x'length-1-i) := x(i);
    end loop;
    return rv;
  end f_reverse_bits;

  constant c_TARGET_BIT_OFFSET : integer := 2;

begin

  process(clk_rx_250m_i)
  begin
    if rising_edge(clk_rx_250m_i) then
-- 100 bits (25 bits effective)
      --rx_data_merged_x4_250m <= rx_data_merged_x4_250m(c_TOTAL_BITS-20-1 downto 0) & f_reverse_bits(rx_data_raw_i(19 downto 0));

      rx_data_merged_x4_250m <= rx_data_raw_i(19 downto 0) & rx_data_merged_x4_250m(c_TOTAL_BITS-1 downto 20);
    end if;
  end process;

  rx_data_merged_x4_62m_sh <= rx_data_merged_x4_62m(0) & rx_data_merged_x4_62m(rx_data_merged_x4_62m_sh'length-1 downto 1);

  process(clk_rx_62m5_i)
  begin
    if rising_edge(clk_rx_62m5_i) then
      rx_data_merged_x4_62m <= rx_data_merged_x4_250m;
    end if;
  end process;

  process(clk_rx_62m5_i)
  begin
    if rising_edge(clk_rx_62m5_i) then
      for i in 0 to 19 loop
        rx_data_raw_62m5_o(i) <= rx_data_merged_x4_62m(i*c_OVERSAMPLE+c_TARGET_BIT_OFFSET);
      end loop;
    end if;
  end process;


  p_look_for_loose_commas : process(clk_rx_62m5_i)
  begin
    if rising_edge(clk_rx_62m5_i) then

      for i in 0 to c_SCAN_WINDOW_BITS-1 loop
        for j in 0 to 9 loop
          if rx_data_merged_x4_62m(i+j*c_OVERSAMPLE) = c_K28_5_PLUS(j) then
            commas_match_plus(i mod c_NUM_COMMA_POS)(j) <= '1';
          else
            commas_match_plus(i mod c_NUM_COMMA_POS)(j) <= '0';
          end if;
        end loop;
      end loop;

      for i in 0 to c_SCAN_WINDOW_BITS-1 loop
        for j in 0 to 9 loop
          if rx_data_merged_x4_62m(i+j*c_OVERSAMPLE) = not c_K28_5_PLUS(j) then
            commas_match_minus(i mod c_NUM_COMMA_POS)(j) <= '1';
          else
            commas_match_minus(i mod c_NUM_COMMA_POS)(j) <= '0';
          end if;
        end loop;
      end loop;

      for i in 0 to c_NUM_COMMA_POS-1 loop
        if commas_match_minus(i) = "1111111111" or commas_match_plus(i) = "1111111111" then
          comma_found(i) <= '1';
        else
          comma_found (i) <= '0';
        end if;

      end loop;
    end if;
  end process;

  process(clk_rx_62m5_i)
  begin
    if rising_edge(clk_rx_62m5_i) then
      if rst_rx_n_i = '0' then
        state <= SYNC_LOST;
      else
        case state is
          when SYNC_LOST =>
            link_up <= '0';

            if unsigned(comma_found) /= 0 then
              comma_mask_first <= comma_found;
              state            <= SYNC_CHECK;
              cnt              <= to_unsigned(4, cnt'length);
            end if;

          when SYNC_CHECK =>
            if comma_found = comma_mask_first then
              cnt <= cnt + 4;
            elsif cnt > 0 then
              cnt <= cnt - 1;
              if cnt = 1 then
                state <= SYNC_LOST;
              end if;
            end if;

            if cnt >= c_IDLE_LENGTH_UP then
              state <= SYNC_ACQUIRED;
              cnt   <= (others => '0');
            end if;

          when SYNC_ACQUIRED =>
            link_up <= '1';

            if( unsigned(comma_found and comma_mask_first) /= 0) then
              cnt <= (others => '0');
            else
              cnt <= cnt + 1;
              if cnt = c_IDLE_LENGTH_LOSS then
                state <= SYNC_LOST;
              end if;
            end if;
        end case;
      end if;
    end if;
  end process;


  process(clk_rx_62m5_i)
  begin
    if rising_edge(clk_rx_62m5_i) then
      if pat_latch_i = '1' then
        pat_value_o(119 downto 0) <= rx_data_merged_x4_62m;
        pat_value_o(239 downto 120) <= (others => '0');
      end if;
    end if;
  end process;

  early_link_up_o <= link_up;

end rtl;
