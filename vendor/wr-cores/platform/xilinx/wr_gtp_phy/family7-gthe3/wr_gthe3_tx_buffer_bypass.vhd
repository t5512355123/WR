library ieee;
use ieee.std_logic_1164.all;

use work.gencores_pkg.all;

entity wr_gthe3_tx_buffer_bypass is
  port
    (
      clk_free_i : in std_logic;
      rst_i      : in std_logic;


      TXUSRCLK2_i   : in  std_logic;
      TXRESETDONE_i : in  std_logic;
      TXDLYSRESET_o : out std_logic;
      TXSYNCDONE_i  : in  std_logic;

      done_o : out std_logic
      );
end wr_gthe3_tx_buffer_bypass;


architecture rtl of wr_gthe3_tx_buffer_bypass is

  type t_state is (WAIT_RESTART, ASSERT_DLY_RESET, WAIT_SYNC_DONE, DONE);

  signal rst_txusrclk2 : std_logic;

  signal TXRESETDONE_clk_txusr   : std_logic;
  signal TXSYNCDONE_clk_txusr_p1 : std_logic;

  signal TXDLYSRESET_int : std_logic;

  signal done_int : std_logic;
  signal state    : t_state;
  signal rst_n    : std_logic;
begin

  rst_n <= not rst_i;

  U_Sync_Reset : entity work.gc_reset_synchronizer
    generic map (
      g_reset_active_out => '1')
    port map (
      clk_i    => TXUSRCLK2_i,
      rst_n_a_i  => rst_n,
      rst_synced_o => rst_txusrclk2);

  U_Sync_Done : gc_sync_ffs
    port map (
      clk_i    => clk_free_i,
      rst_n_i  => rst_n,
      data_i   => done_int,
      synced_o => done_o);

  U_Sync_TXRESETDONE : gc_sync_ffs
    port map (
      clk_i    => TXUSRCLK2_i,
      rst_n_i  => rst_n,
      data_i   => TXRESETDONE_i,
      synced_o => TXRESETDONE_clk_txusr);

  U_Sync_TXSYNCDONE : gc_sync_ffs
    port map (
      clk_i    => TXUSRCLK2_i,
      rst_n_i  => rst_n,
      data_i   => TXSYNCDONE_i,
      ppulse_o => TXSYNCDONE_clk_txusr_p1);

-- TX dly align procedure:
-- 
-- start on TXRESETDONE
-- txdlysreset_out = 1
-- txdlysreset_out = 0
-- wait for RE of txsyncdone

  p_tx_buffer_bypass : process(TXUSRCLK2_i, rst_txusrclk2)


  begin
    if rst_txusrclk2 = '1' then
      state           <= WAIT_RESTART;
      TXDLYSRESET_int <= '0';
      done_int        <= '0';

    elsif rising_edge(TXUSRCLK2_i) then
      if rst_txusrclk2 = '1' then
        state           <= WAIT_RESTART;
        TXDLYSRESET_int <= '0';
        done_int        <= '0';
      else
        TXDLYSRESET_int <= '0';
        done_int        <= '0';

        case state is
          when WAIT_RESTART =>
            if TXRESETDONE_i = '1' then
              state <= ASSERT_DLY_RESET;
            end if;

          when ASSERT_DLY_RESET =>
            TXDLYSRESET_int <= '1';
            state           <= WAIT_SYNC_DONE;

          when WAIT_SYNC_DONE =>
            TXDLYSRESET_int <= '0';

            if TXSYNCDONE_clk_txusr_p1 = '1' then
              state <= DONE;
            end if;

          when DONE =>
            done_int <= '1';


        end case;



      end if;
    end if;
  end process;

  txdlysreset_o <= TXDLYSRESET_int;

end rtl;

