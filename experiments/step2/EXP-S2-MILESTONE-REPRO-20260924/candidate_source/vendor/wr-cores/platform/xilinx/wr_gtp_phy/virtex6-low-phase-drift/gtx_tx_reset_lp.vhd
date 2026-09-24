library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.gencores_pkg.all;

entity gtx_tx_reset_lp is

  port (
    -- uncorrelated clock (we use DDMTD here) to ensure repeated resetting of
    -- the TX path will sooner or later get to the TX divider bin we want
    clk_dmtd_i : in std_logic;

    -- TX clock
    clk_tx_i : in std_logic;

    -- Master reset (clk_tx_i domain)
    rst_i : in std_logic;

    -- Sw reset (treat as async)
    rst_sw_i : in std_logic;

    -- TX PLL lock detect
    txpll_lockdet_i : in std_logic;

    -- GTX TX divider reset
    gtx_test_o : out std_logic_vector(12 downto 0);

    -- GTX TX path reset (async)
    gtx_tx_reset_o : out std_logic;

    -- GTX TX reset done (also async)
    gtx_tx_reset_done_i : in std_logic;

    -- DOne indication
    done_o : out std_logic
    );

end gtx_tx_reset_lp;


architecture behavioral of gtx_tx_reset_lp is

  type t_state is (IDLE, PAUSE, FIRST_RST, PAUSE2, SECOND_RST, DONE);

  signal state   : t_state;
  signal counter : unsigned(15 downto 0);

begin  -- behavioral

  process(clk_tx_i)
  begin
    if rising_edge(clk_tx_i) then
      if rst_i = '1' then
        state   <= IDLE;
        counter <= (others => '0');

      else
        case state is
          when IDLE =>
            counter    <= (others => '0');
            gtx_test_o <= "1000000000000";

            if(txpll_lockdet_i = '1') then
              state <= PAUSE;
            end if;

          when PAUSE =>
            counter    <= counter + 1;
            gtx_test_o <= "1000000000000";
            if(counter = 1024) then
              state <= FIRST_RST;
            end if;

          when FIRST_RST =>
            counter    <= counter + 1;
            gtx_test_o <= "1000000000010";
            if(counter = 1024 + 256) then
              state <= PAUSE2;
            end if;
          when PAUSE2 =>
            counter    <= counter + 1;
            gtx_test_o <= "1000000000000";
            if(counter = 1024 + 2*256) then
              state <= SECOND_RST;
            end if;
          when SECOND_RST =>
            counter    <= counter + 1;
            gtx_test_o <= "1000000000010";
            if(counter = 1024 + 3*256) then
              state <= DONE;
            end if;

          when DONE =>
            gtx_test_o <= "1000000000000";

        end case;
      end if;
    end if;
  end process;

  U_SyncResetSW : gc_sync_ffs
    port map
    (
      clk_i    => clk_dmtd_i,
      rst_n_i  => '1',
      data_i   => rst_sw_i,
      ppulse_o => gtx_tx_reset_o);

  U_SyncTxResetDone : gc_sync_ffs
    port map
    (
      clk_i    => clk_tx_i,
      rst_n_i  => '1',
      data_i   => gtx_tx_reset_done_i,
      synced_o => done_o);

end behavioral;

