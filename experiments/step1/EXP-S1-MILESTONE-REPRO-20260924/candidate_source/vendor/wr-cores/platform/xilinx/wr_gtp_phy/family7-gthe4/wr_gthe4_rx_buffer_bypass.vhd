library ieee;
use ieee.std_logic_1164.all;

use work.gencores_pkg.all;

entity wr_gthe4_rx_buffer_bypass is
  port
    (
      clk_free_i : in std_logic;
      rst_i      : in std_logic;


      RXUSRCLK2_i   : in  std_logic;
      RXRESETDONE_i : in  std_logic;
      RXDLYSRESET_o : out std_logic;
      RXSYNCDONE_i  : in  std_logic;

      done_o : out std_logic
      );
end wr_gthe4_rx_buffer_bypass;


architecture rtl of wr_gthe4_rx_buffer_bypass is

  type t_state is (WAIT_RESTART, ASSERT_DLY_RESET, WAIT_SYNC_DONE, DONE);
  signal state : t_state;
  signal rst_rxusrclk2 : std_logic;

  signal RXRESETDONE_clk_free   : std_logic;
  signal RXSYNCDONE_clk_free_p1 : std_logic;

  signal done_int : std_logic;

begin

  U_Sync_Reset : gc_sync_ffs
    port map (
      clk_i    => RXUSRCLK2_i,
      rst_n_i  => '1',
      data_i   => rst_i,
      synced_o => rst_rxusrclk2);

  U_Sync_Done : gc_sync_ffs
    port map (
      clk_i    => clk_free_i,
      rst_n_i  => '1',
      data_i   => done_int,
      synced_o => done_o);

-- RX dly align procedure:
-- 
-- start on RXRESETDONE
-- rxdlysreset_out = 1
-- rxdlysreset_out = 0
-- wait for RE of rxsyncdone

  p_rx_buffer_bypass : process(RXUSRCLK2_i)
  begin
    if rising_edge(RXUSRCLK2_i) then
      if rst_rxusrclk2 = '1' then
        state         <= WAIT_RESTART;
        RXDLYSRESET_o <= '0';
        done_int      <= '0';

      else
        RXDLYSRESET_o <= '0';
        done_int      <= '0';

        case state is
          when WAIT_RESTART =>
            if RXRESETDONE_i = '1' then
              state <= ASSERT_DLY_RESET;
            end if;

          when ASSERT_DLY_RESET =>
            RXDLYSRESET_o <= '1';
            state <= WAIT_SYNC_DONE;

          when WAIT_SYNC_DONE =>
            RXDLYSRESET_o <= '0';

            if RXSYNCDONE_i = '1' then
              state <= DONE;
            end if;

          when DONE =>
            done_int <= '1';


        end case;



      end if;
    end if;
  end process;

end rtl;

