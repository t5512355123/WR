library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity gtx_comma_detect_lp is
  generic (
    g_ID : integer
    );
  port (
    clk_rx_i : in std_logic;
    rst_i    : in std_logic;

    rx_data_raw_i : in std_logic_vector(19 downto 0);

    link_up_o : out std_logic;
    aligned_o : out std_logic;

    rx_data_i : in std_logic_vector(15 downto 0);
    rx_k_i : in std_logic_vector(1 downto 0);
    rx_error_i : in std_logic
    );

end gtx_comma_detect_lp;

architecture rtl of gtx_comma_detect_lp is

  type t_state is (SYNC_LOST, SYNC_CHECK, SYNC_ACQUIRED);

  constant c_IDLE_LENGTH_UP   : integer := 500;
  constant c_IDLE_LENGTH_LOSS : integer := 10000;

  constant c_COMMA_SHIFT_WE_WANT : std_logic_vector(6 downto 0) := "0110000";
-- fixme

  signal rx_data_d0     : std_logic_vector(19 downto 0);
  signal rx_data_merged : std_logic_vector(49 downto 0);

  signal first_comma : std_logic_vector(4 downto 0);
  signal cnt         : unsigned(15 downto 0);
  signal state       : t_state;
  signal comma_found : std_logic_vector(19 downto 0);

  component chipscope_ila_v6 is
    port (
      CONTROL : inout std_logic_vector(35 downto 0);
      CLK     : in    std_logic;
      TRIG0   : in    std_logic_vector(63 downto 0));
  end component chipscope_ila_v6;

  component chipscope_icon_v6 is
    port (
      CONTROL0 : inout std_logic_vector(35 downto 0));
  end component chipscope_icon_v6;

  signal CONTROL : std_logic_vector(35 downto 0);
  signal TRIG0   : std_logic_vector(63 downto 0);
  
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

  constant c_K28_5_PLUS : std_logic_vector(9 downto 0) := "1010000011";

  signal comma_pos            : std_logic_vector(4 downto 0);
  signal prev_comma_pos       : std_logic_vector(4 downto 0);
  signal prev_comma_pos_valid : std_logic;
  signal comma_pos_valid      : std_logic;
  signal link_up : std_logic;
  signal link_aligned : std_logic;
  
begin


--  gen1 : if g_id = 0 generate
--     chipscope_icon_1 : chipscope_icon_v6
--      port map (
--        CONTROL0 => CONTROL);

--     chipscope_ila_1 : chipscope_ila_v6
--      port map (
--        CONTROL => CONTROL,
--        CLK     => clk_rx_i,
--        TRIG0   => TRIG0);
     
--    trig0 (19 downto 0) <= rx_data_raw_i;
--    trig0 (39 downto 20) <= comma_found;
--    trig0 (40) <= comma_pos_valid;
--    trig0 (41) <= link_up;
--    trig0 (42) <= link_aligned;
--    trig0 (43+15 downto 43) <= std_logic_vector(cnt);
--  end generate gen1;

  process(clk_rx_i)
  begin
    if rising_edge(clk_rx_i) then
      if rst_i = '1' then
        comma_found <= (others => '0');
      else
        rx_data_d0                  <= rx_data_raw_i;
        rx_data_merged(39 downto 0) <= rx_data_d0 & rx_data_raw_i;
        for i in 0 to 19 loop
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
      if rst_i = '1' then
        state <= SYNC_LOST;
      else
        case state is
          when SYNC_LOST =>
            link_up <= '0';
            link_aligned <= '0';

            if comma_pos_valid = '1' then
              first_comma <= comma_pos;
              state       <= SYNC_CHECK;
              cnt         <= to_unsigned(4, cnt'length);
            end if;

          when SYNC_CHECK =>
            if comma_pos = first_comma and comma_pos_valid = '1' then
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

            if(comma_pos_valid = '1' and comma_pos = first_comma) then
              if(unsigned(comma_pos) = 0) then
                link_aligned <= '1';
              end if;

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

  aligned_o <= link_aligned;
  link_up_o <= link_up;
  
end rtl;

