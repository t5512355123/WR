library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.wishbone_pkg.all;
use work.wr_fabric_pkg.all;

package ez_usb_pkg is

   component ez_usb is
     generic(
       g_sdb_address  : t_wishbone_address;
       g_clock_period : integer := 16; -- clk_sys_i in ns
       g_board_delay  : integer := 2;  -- path length from FPGA to chip
       g_margin       : integer := 4;  -- too lazy to consider FPGA timing constraints? increase this.
       g_sys_freq     : natural := 62500); -- kHz
     port(
       clk_sys_i : in  std_logic;
       rstn_i    : in  std_logic;

       -- Wishbone interface
       master_i  : in  t_wishbone_master_in;
       master_o  : out t_wishbone_master_out;
       
       -- USB Console
       uart_o    : out std_logic;
       uart_i    : in  std_logic;

       -- External signals
       rstn_o    : out std_logic;
       ebcyc_i   : in  std_logic;
       speed_i   : in  std_logic;
       shift_i   : in  std_logic;
       fifoadr_o : out std_logic_vector(1 downto 0);
       readyn_i  : in  std_logic;
       fulln_i   : in  std_logic;
       emptyn_i  : in  std_logic;
       sloen_o   : out std_logic;
       slrdn_o   : out std_logic;
       slwrn_o   : out std_logic;
       pktendn_o : out std_logic;
       fd_i      : in  std_logic_vector(7 downto 0);
       fd_o      : out std_logic_vector(7 downto 0);
       fd_oen_o  : out std_logic);
   end component;
   
   component ez_usb_fifos is
     generic(
       g_clock_period : integer := 16; -- clk_sys_i in ns
       g_board_delay  : integer := 2;  -- path length from FPGA to chip
       g_margin       : integer := 4;  -- too lazy to consider FPGA timing constraints? increase this.
       g_fifo_width   : integer := 8;  -- # of FIFO data pins connected (8 or 16)
       g_num_fifos    : integer := 4); -- always 4 for FX2LP (EP2, EP4, EP6, EP8)
     port(
       clk_sys_i : in  std_logic;
       rstn_i    : in  std_logic;

       -- Wishbone interface
       slave_i   : in  t_wishbone_slave_in_array (g_num_fifos-1 downto 0);
       slave_o   : out t_wishbone_slave_out_array(g_num_fifos-1 downto 0);

       -- External signals
       fifoadr_o : out std_logic_vector(f_ceil_log2(g_num_fifos)-1 downto 0);
       readyn_i  : in  std_logic;
       fulln_i   : in  std_logic;
       emptyn_i  : in  std_logic;
       sloen_o   : out std_logic;
       slrdn_o   : out std_logic;
       slwrn_o   : out std_logic;
       pktendn_o : out std_logic;
       fd_i      : in  std_logic_vector(g_fifo_width-1 downto 0);
       fd_o      : out std_logic_vector(g_fifo_width-1 downto 0);
       fd_oen_o  : out std_logic);

   end component;
   
end ez_usb_pkg;
