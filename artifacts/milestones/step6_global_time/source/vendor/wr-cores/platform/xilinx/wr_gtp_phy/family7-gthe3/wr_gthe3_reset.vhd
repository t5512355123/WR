library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.gencores_pkg.all;

entity wr_gthe3_reset is
  port (
    rst_i      : in std_logic;
    clk_free_i : in std_logic;

    -- CPLL reset I/O
    CPLLPD_o   : out std_logic;
    CPLLLOCK_i : in  std_logic;

    -- RX path resets
    RXCDRLOCK_i      : in  std_logic;
    RXRESETDONE_i    : in  std_logic;
    GTRXRESET_o      : out std_logic;
    RXPROGDIVRESET_o : out std_logic;
    RXUSERRDY_o      : out std_logic;

    -- TX path resets
    GTTXRESET_o      : out std_logic;
    TXRESETDONE_i    : in  std_logic;
    TXPROGDIVRESET_o : out std_logic;
    TXUSERRDY_o      : out std_logic;



    rx_active_i : in std_logic;
    tx_active_i : in std_logic;

    done_o : out std_logic
    );

end wr_gthe3_reset;

architecture rtl of wr_gthe3_reset is

  constant c_RESET_TIMEOUT : integer := 1000;

  type t_state is (RESTART, DONE, CPLL_WAIT_LOCK, CPLL_RESET_TIMEOUT, CDR_WAIT_LOCK, TX_ACTIVE_WAIT, RX_ACTIVE_WAIT, TX_RESET_DONE_WAIT, RX_RESET_DONE_WAIT, TX_RESET_TIMER_WAIT);
  
  signal state                                 : t_state;
  signal rst_master_clk_free                   : std_logic;
  signal CPLLLOCK_clk_free, tx_active_clk_free : std_logic;
  signal rx_active_clk_free                    : std_logic;
  signal TXRESETDONE_clk_free                  : std_logic;
  signal RXRESETDONE_clk_free                  : std_logic;
  signal RXCDRLOCK_clk_free                    : std_logic;

  signal timeout_cnt : unsigned(15 downto 0);
begin

  U_SyncResetAll : gc_sync_ffs
    generic map (
      g_sync_edge => "positive")
    port map (
      clk_i    => clk_free_i,
      rst_n_i  => '1',
      data_i   => rst_i,
      synced_o => rst_master_clk_free);

  U_SyncCPLLLOCK : gc_sync_ffs
    generic map (
      g_sync_edge => "positive")
    port map (
      clk_i    => clk_free_i,
      rst_n_i  => '1',
      data_i   => CPLLLOCK_i,
      synced_o => CPLLLOCK_clk_free);

  U_SyncTxActive : gc_sync_ffs
    generic map (
      g_sync_edge => "positive")
    port map (
      clk_i    => clk_free_i,
      rst_n_i  => '1',
      data_i   => tx_active_i,
      synced_o => tx_active_clk_free);

  U_SyncRxActive : gc_sync_ffs
    generic map (
      g_sync_edge => "positive")
    port map (
      clk_i    => clk_free_i,
      rst_n_i  => '1',
      data_i   => rx_active_i,
      synced_o => rx_active_clk_free);

  U_SyncRxResetDone : gc_sync_ffs
    generic map (
      g_sync_edge => "positive")
    port map (
      clk_i    => clk_free_i,
      rst_n_i  => '1',
      data_i   => RXRESETDONE_i,
      synced_o => RXRESETDONE_clk_free);

  U_SyncTxResetDone : gc_sync_ffs
    generic map (
      g_sync_edge => "positive")
    port map (
      clk_i    => clk_free_i,
      rst_n_i  => '1',
      data_i   => TXRESETDONE_i,
      synced_o => TXRESETDONE_clk_free);

  U_SyncRxCdrLock : gc_sync_ffs
    generic map (
      g_sync_edge => "positive")
    port map (
      clk_i    => clk_free_i,
      rst_n_i  => '1',
      data_i   => RXCDRLOCK_i,
      synced_o => RXCDRLOCK_clk_free);

  TXPROGDIVRESET_o <= not CPLLLOCK_clk_free;

-- TX side:

-- - assert pllreset_tx, gttxreset
-- - wait for lock (plllock_tx, pllreset_tx -> 0)
-- - gttxreset -> 0
-- - wait for tx_active
-- - wait for txresetdone
-- - we're done

-- RX side:
-- - assert pllreset_rx, rxprogdivreset, gtrxreset
-- - wait for plllock_rx, pllreset_rx->0
-- - deassert gtrxreset
-- - wait for cdr lock
-- - deassert progdiv reset
-- - wait for rx_active
-- - wait for rxresetdone
-- - we're done


  process(clk_free_i)
  begin
    if rising_edge(clk_free_i)then
      if rst_master_clk_free = '1' then
        state            <= RESTART;
        done_o           <= '0';
        GTTXRESET_o      <= '1';
        GTRXRESET_o      <= '1';
        RXPROGDIVRESET_o <= '1';
        TXUSERRDY_o      <= '0';
        RXUSERRDY_o      <= '0';

      else
        done_o <= '0';

        case state is
          when RESTART =>
            CPLLPD_o <= '1';  -- assert both TX and RX PLL reset (we're using the
            -- CPLL that serves both)

            GTTXRESET_o      <= '1';
            GTRXRESET_o      <= '1';
            RXPROGDIVRESET_o <= '1';
            TXUSERRDY_o      <= '0';
            RXUSERRDY_o      <= '0';

            state       <= CPLL_WAIT_LOCK;
            timeout_cnt <= to_unsigned(c_RESET_TIMEOUT, 16);

          when CPLL_RESET_TIMEOUT =>

            timeout_cnt <= timeout_cnt - 1;

            if timeout_cnt = 0 then
              CPLLPD_o <= '0';
              state    <= CPLL_WAIT_LOCK;
            end if;


          when CPLL_WAIT_LOCK =>
            CPLLPD_o <= '0';

            if CPLLLOCK_clk_free = '1' then
              GTTXRESET_o <= '1';
              GTRXRESET_o <= '1';
              timeout_cnt <= to_unsigned(c_RESET_TIMEOUT, 16);
              state       <= TX_RESET_TIMER_WAIT;
            end if;

          when TX_RESET_TIMER_WAIT =>
            timeout_cnt <= timeout_cnt - 1;

            if timeout_cnt = 0 then
              GTTXRESET_o <= '0';
              GTRXRESET_o <= '0';
              state <= TX_ACTIVE_WAIT;
            end if;


          when TX_ACTIVE_WAIT =>
            if tx_active_clk_free = '1' then
              state       <= TX_RESET_DONE_WAIT;
              TXUSERRDY_o <= '1';
            end if;

          when TX_RESET_DONE_WAIT =>
            if TXRESETDONE_clk_free = '1' then
              state <= CDR_WAIT_LOCK;
            end if;

          when CDR_WAIT_LOCK =>
            if RXCDRLOCK_clk_free = '1' then
              RXPROGDIVRESET_o <= '0';
              state            <= RX_ACTIVE_WAIT;
            end if;

          when RX_ACTIVE_WAIT =>
            if rx_active_clk_free = '1' then
              state       <= RX_RESET_DONE_WAIT;
              RXUSERRDY_o <= '1';
            end if;

          when RX_RESET_DONE_WAIT =>
            if RXRESETDONE_clk_free = '1' then
              state <= DONE;
            end if;

          when DONE =>
            done_o <= '1';

        end case;
      end if;
    end if;
  end process;



end rtl;
