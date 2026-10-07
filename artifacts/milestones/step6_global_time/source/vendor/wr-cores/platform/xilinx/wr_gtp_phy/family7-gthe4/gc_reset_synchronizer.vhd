library ieee;
use ieee.std_logic_1164.all;

entity gc_reset_synchronizer is
  generic (
    g_reset_active_out : std_logic := '0');
  port (
    clk_i        : in  std_logic;
    rst_n_a_i    : in  std_logic;
    rst_synced_o : out std_logic);
end gc_reset_synchronizer;

architecture rtl of gc_reset_synchronizer is

  signal gc_sync_ffs_sync0, gc_sync_ffs_sync1, gc_sync_ffs_sync2 : std_logic;

  attribute shreg_extract                      : string;
  attribute shreg_extract of gc_sync_ffs_sync0 : signal is "no";
  attribute shreg_extract of gc_sync_ffs_sync1 : signal is "no";

  attribute keep                      : string;
  attribute keep of gc_sync_ffs_sync0 : signal is "true";
  attribute keep of gc_sync_ffs_sync1 : signal is "true";

  -- synchronizer attribute for Vivado
  attribute ASYNC_REG                      : string;
  attribute ASYNC_REG of gc_sync_ffs_sync0 : signal is "true";
  attribute ASYNC_REG of gc_sync_ffs_sync1 : signal is "true";

begin

  process(clk_i, rst_n_a_i)
  begin
    if(rst_n_a_i = '0') then
      gc_sync_ffs_sync0 <= '0';
      gc_sync_ffs_sync1 <= '0';
      gc_sync_ffs_sync2 <= '0';
      rst_synced_o          <= g_reset_active_out;
    elsif rising_edge(clk_i) then
      gc_sync_ffs_sync0 <= not rst_n_a_i;
      gc_sync_ffs_sync1 <= gc_sync_ffs_sync0;
      rst_synced_o          <= gc_sync_ffs_sync1;
    end if;
  end process;

end rtl;
