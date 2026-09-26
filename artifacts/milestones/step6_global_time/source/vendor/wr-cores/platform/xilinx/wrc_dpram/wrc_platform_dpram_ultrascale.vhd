library ieee;
use ieee.std_logic_1164.all;

use work.wishbone_pkg.all;
use work.genram_pkg.all;
use work.wrcore_pkg.all;

library xpm;
use xpm.vcomponents.all;

entity wrc_platform_dpram is

  generic (
    g_size                  : natural := 16384;
    g_init_file             : string  := "";
    g_must_have_init_file   : boolean := true);

  port (
    clk_sys_i : in  std_logic;
    rst_n_i   : in  std_logic;
    slave1_i  : in  t_wishbone_slave_in;
    slave1_o  : out t_wishbone_slave_out;

-- warning: port slave2 is unimplemented as it's not used by the WRCore
    slave2_i  : in  t_wishbone_slave_in;
    slave2_o  : out t_wishbone_slave_out);

end entity wrc_platform_dpram;

architecture wrapper of wrc_platform_dpram is
  constant c_ADDR_WIDTH : integer := f_log2_size(g_size);

  signal dina, douta, doutb : std_logic_vector(31 downto 0);
  signal ena, enb : std_logic;
  signal bwea : std_logic_vector(3 downto 0);
  signal addra, addrb : std_logic_vector(c_ADDR_WIDTH-1 downto 0);

  signal slave1_out : t_wishbone_slave_out;
  signal slave1_in : t_wishbone_slave_in;
  
begin

  slave1_in <= slave1_i;


  
  inst_wrapped_dpram : xpm_memory_sdpram
    generic map (
      ADDR_WIDTH_A            => c_ADDR_WIDTH,
      ADDR_WIDTH_B            => c_ADDR_WIDTH,
      AUTO_SLEEP_TIME         => 0,
      BYTE_WRITE_WIDTH_A      => 8,            
      CLOCKING_MODE           => "common_clock",
      ECC_MODE                => "no_ecc",
      MEMORY_INIT_FILE        => "none",
      MEMORY_INIT_PARAM       => "0", 
      MEMORY_OPTIMIZATION     => "true",
      MEMORY_PRIMITIVE        => "ultra",
      MEMORY_SIZE             => g_size * 32,
      MESSAGE_CONTROL         => 0,     -- DECIMAL
      READ_DATA_WIDTH_B       => 32,
      READ_LATENCY_B          => 1,     -- DECIMAL
      READ_RESET_VALUE_B      => "0",   -- String
      USE_EMBEDDED_CONSTRAINT => 0,     -- DECIMAL
      USE_MEM_INIT            => 0,     -- DECIMAL
      WAKEUP_TIME             => "disable_sleep",                  -- String
      WRITE_DATA_WIDTH_A      => 32,
      WRITE_MODE_B            => "read_first"           
      )
    port map (
      doutb    => doutb,  
      addra => addra, 
      addrb => addrb, 
      clka  => clk_sys_i,
      clkb => clk_sys_i, 
      dina => dina, 
      ena  => '1', 
      enb => '1',
      injectdbiterra => '0',  
      injectsbiterra => '0',  
      regceb => '1', 
      rstb => '0',  
      sleep  => '0',
      wea => bwea 
      );

  addra <= slave1_in.adr(f_log2_size(g_size)+1 downto 2);
  addrb <= slave1_in.adr(f_log2_size(g_size)+1 downto 2);
  dina <= slave1_in.dat;
  slave1_out.dat <= doutb;
  bwea <= slave1_in.sel when (slave1_in.cyc = '1' and slave1_in.stb  = '1' and slave1_in.we = '1') else"0000";


  process(clk_sys_i)
  begin
    if(rising_edge(clk_sys_i)) then
      if(rst_n_i = '0') then
        slave1_out.ack <= '0';
      else
        slave1_out.ack <= slave1_in.cyc and slave1_in.stb;
      end if;
    end if;
  end process;

  slave1_out.stall <= '0';
  slave1_out.err   <= '0';
  slave1_out.rty   <= '0';
  
  slave1_o <= slave1_out;
  
end wrapper;
