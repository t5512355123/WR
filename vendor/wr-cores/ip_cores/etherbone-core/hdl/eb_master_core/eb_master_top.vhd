--! @file eb_master_top.vhd
--! @brief EtherBone Master (EBM) v1.2, turns Wishbone Operations into Etherbone over UDP
--!
--! Copyright (C) 2013-2015 GSI Helmholtz Centre for Heavy Ion Research GmbH 
--!
--! The Hardware Etherbone Master turns Wishbone Operations into Etherbone Records,
--! creates a UDP package and sends it over a fabric interface. 
--!
--! Before addressing a new WB device remotely, the ADR_HI register must always be set
--! to the base address of the target device. When switching between control and 
--! data adr range of the master, the cycle line MUST be lowered for at least one cycle.  
--!
--! Wishbone Ops need to be acknowledged before a cycle ends. This is relatively easy for
--! write operations as it can be done instantly. Read Ops, however, deliver the read data with
--! the ack. This would span the latency over network round trip time and it is unsure if they
--! are acknowledged at all, holding the danger of hanging the bus.
--! Read operations are therefore expected as write operations with an address offset.
--! EBM will analyse incoming requests and create new records accordingly. EBM record options will
--! be copied in from the EB-OPT register. 
--! The  Cycle Hold bit will be kept Hi as long as Ops are written in the same Wishbone Cycle.
--! Dropping the cycle line between Ops forces a new record and the previous record's
--! Cycle Hold bit to go low.
--!
--! When all desired operations are written to data range and the cycle line is dropped,
--! writing '1' to the flush register will send the packet.
--! Writing '1' to the clear register at any time will clear all buffers.
--!
--! In case of Overflow (bytecount > MTU, Status OVF bit set), all further writes to data
--! will cause errors. Flush will not send the data in this case, but clear the buffers instead.
--!  
--! 
--! internal address layout: 
--!     
--!  |____________________
--! 0|          |  Regs         
--!  |  ctrl    |  ...        
--!  |          |     
--!  |__________|_________
--! 1|        10|  Reads   
--!  |          |_________
--!  |  data  11|  Writes  
--!  |__________|_________ 
--!
--! -> data address range is write only! 
--! -> drop cycle before switching betwenn ctrl & data!
--!

--! Ctrl Register map
--!--------------------------------------------------------------------------------------
--! 0x00 wo CLEAR          writing '1' here will clear all data buffers        
--!
--! 0x04 wo FLUSH          writing '1' here will send the packet. 
--!                        Will err when buffer empty or overflow
--!
--! 0x08 ro STATUS         b31..b16  Payload byte count 
--!                        b15..b01  reserved
--!                             b00  Buffer Overflow                               
--!
--! 0x0C rw SRC_MAC_HI              bytes 1-4 of source MAC address  
--! 0x10 rw SRC_MAC_LO     b15..b00 bytes 5-6 of source MAC address  
--!
--! 0x14 rw SRC_IPV4       source IPV4 address
--!
--! 0x18 rw SRC_UDP_PORT   b15..b00 source UDP port number 
--!
--! 0x1C rw DST_MAC_HI              bytes 1-4 of destination MAC address    
--! 0x20 rw DST_MAC_LO     b15..b00 bytes 5-6 of destination MAC address
--!
--! 0x24 rw DST_IPV4       destination IPV4 address
--!
--! 0x28 rw DST_UDP_PORT   b15..b00 destination UDP port number 
--!
--! 0x2C rw MTU            Maximum payload byte length
--!
--! 0x30 rw ADR_HI         b31..b31-g_adr_hi  High bits of the data address lines
--!
--! 0x34 rw OPS_MAX        Maximum payload wishbone operations (implementation pending)     
--!
--! 0x40 rw EB_OPT         Etherbone Record options
--!
--! 0x44 rw SEMA           Semaphore register, can be used to indicate current owner of EBM
--! 
--! 0x48 rw UDP_MODE       writing '1' bypasses Etherbone logic, enabling direct input of UDP payload,
--!                        resetting to '0' sends the packet.      
--! 
--! 0x4C wo UDP_DATA       Data interface for direct input of UDP payload
--! @author Mathias Kreider <m.kreider@gsi.de>
--!
--------------------------------------------------------------------------------
--! This library is free software; you can redistribute it and/or
--! modify it under the terms of the GNU Lesser General Public
--! License as published by the Free Software Foundation; either
--! version 3 of the License, or (at your option) any later version.
--!
--! This library is distributed in the hope that it will be useful,
--! but WITHOUT ANY WARRANTY; without even the implied warranty of
--! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
--! Lesser General Public License for more details.
--!  
--! You should have received a copy of the GNU Lesser General Public
--! License along with this library. If not, see <http://www.gnu.org/licenses/>.
---------------------------------------------------------------------------------

--! Standard library
library IEEE;
--! Standard packages   
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.wishbone_pkg.all;
use work.eb_internals_pkg.all;
use work.eb_hdr_pkg.all;
use work.etherbone_pkg.all;
use work.wr_fabric_pkg.all;

entity eb_master_top is
generic(g_adr_bits_hi : natural := 8;
        g_mtu : natural := 32);
port(
  clk_i         : in  std_logic;
  rst_n_i       : in  std_logic;

  slave_i       : in  t_wishbone_slave_in;
  slave_o       : out t_wishbone_slave_out;
  
  framer_in     : out t_wishbone_slave_in; -- sim debug only, not to be connected in hardware
  framer_out    : out t_wishbone_slave_out;-- sim debug only, not to be connected in hardware
  
  src_i         : in  t_wrf_source_in;
  src_o         : out t_wrf_source_out
);
end eb_master_top;

architecture rtl of eb_master_top is

   constant slaves   : natural := 2;
   constant masters  : natural := 1;

   signal s_adr_hi         : std_logic_vector(g_adr_bits_hi-1 downto 0);
   signal s_cfg_rec_hdr    : t_rec_hdr;
  
   signal r_drain          : std_logic;
   signal s_rst_n          : std_logic;
   signal wb_rst_n         : std_logic;
   signal s_tx_send_now    : std_logic;
   signal s_byte_cnt : std_logic_vector(15 downto 0);
   signal s_ovf : std_logic;
   signal s_his_mac,  s_my_mac  : std_logic_vector(47 downto 0);
   signal s_his_ip,   s_my_ip   : std_logic_vector(31 downto 0);
   signal s_his_port, s_my_port : std_logic_vector(15 downto 0);
   
   signal s_tx_stb         : std_logic;
   signal s_clear, s_test          : std_logic;
   signal s_tx_flush       : std_logic;
   signal s_udp, r_udp_raw : std_logic;
  
   signal s_skip_stb       : std_logic;
   signal s_length         : unsigned(15 downto 0); -- of UDP in words
   signal s_max_ops        : unsigned(15 downto 0); -- max eb ops count per packet
   
   
   signal s_udp_raw_o   : std_logic;
   signal s_udp_we_o    : std_logic;
   signal s_udp_valid_i : std_logic;   
   signal s_udp_data_o  : std_logic_vector(31 downto 0);
   
   --wb signals
   signal s_framer_in      : t_wishbone_slave_in; 
   signal s_framer_out     : t_wishbone_slave_out; 
   signal s_ctrl_in        : t_wishbone_slave_in; 
   signal s_ctrl_out       : t_wishbone_slave_out;  

   signal s_narrow_in      : t_wishbone_master_out;
   signal s_narrow_out     : t_wishbone_master_in;
   signal s_framer2narrow  : t_wishbone_master_out;
   signal s_narrow2framer  : t_wishbone_master_in;
   signal s_narrow2tx      : t_wishbone_master_out;
   signal s_tx2narrow      : t_wishbone_master_in;
   
   signal cbar_slaveport_in   : t_wishbone_slave_in_array (masters-1 downto 0); 
   signal cbar_slaveport_out  : t_wishbone_slave_out_array(masters-1 downto 0);
   signal cbar_masterport_in  : t_wishbone_master_in_array (slaves-1 downto 0); 
   signal cbar_masterport_out : t_wishbone_master_out_array(slaves-1 downto 0);
     
   --constant c_dat_bit : natural := t_wishbone_address'left - g_adr_bits_hi +2;
   constant c_rw_bit  : natural := t_wishbone_address'left - g_adr_bits_hi +1;
 
   function f_framer_adr return std_logic_vector is
      variable ret : std_logic_vector(31 downto 0) := (others => '0');
   begin
      ret := (others => '0');
      ret(31 - g_adr_bits_hi +2) := '1';
      return ret;
   end function;
   
   function f_ctrl_msk return std_logic_vector is
      variable ret : std_logic_vector(31 downto 0) := (others => '0');
   begin
      ret := (others => '0');
      ret(31 - g_adr_bits_hi +2 downto 8)  := (others => '1');
      return ret;
   end function;
   
   function f_framer_msk return std_logic_vector is
      variable ret : std_logic_vector(31 downto 0) := (others => '0');
   begin
      ret := (others => '0');
      ret(31 - g_adr_bits_hi +2 downto 31 - g_adr_bits_hi +2) := ( others => '1');
      return ret;
   end function;
 
   constant c_ctrl_adr : std_logic_vector(31 downto 0) := x"00000000"; 
   constant c_ctrl_msk : std_logic_vector(31 downto 0) := f_ctrl_msk;
   constant c_framer_adr : std_logic_vector(31 downto 0) := f_framer_adr;
   constant c_framer_msk : std_logic_vector(31 downto 0) := f_framer_msk;

begin
-- instances:
-- eb_master_wb_if
-- eb_framer
-- eb_eth_tx
-- eb_stream_narrow

  s_rst_n <= rst_n_i and not s_clear;

  CON : xwb_crossbar 
  generic map(
    g_num_masters => masters,
    g_num_slaves  => slaves,
    g_registered  => true,
    -- Address of the slaves connected
    g_address(1)     => c_ctrl_adr,
    g_address(0)     => c_framer_adr,
    g_mask(1)        => c_ctrl_msk,
    g_mask(0)        => c_framer_msk)               
  port map(
     clk_sys_i     => clk_i,
     rst_n_i       => rst_n_i,
        -- Master connections (INTERCON is a slave)
     slave_i       => cbar_slaveport_in,
     slave_o       => cbar_slaveport_out,
     -- Slave connections (INTERCON is a master)
     master_i      => cbar_masterport_in,
     master_o      => cbar_masterport_out);

 
   cbar_slaveport_in(0) <= slave_i; 
   slave_o <= cbar_slaveport_out(0);  

   s_framer_in.cyc <= cbar_masterport_out(1).cyc;
   s_framer_in.stb <= cbar_masterport_out(1).stb; 
   s_framer_in.we  <= cbar_masterport_out(1).adr(c_rw_bit); 
   s_framer_in.adr <= s_adr_hi & cbar_masterport_out(1).adr(slave_i.adr'left-g_adr_bits_hi downto 0); 
   s_framer_in.dat <= cbar_masterport_out(1).dat;
   s_framer_in.sel <= cbar_masterport_out(1).sel; 
   cbar_masterport_in(1) <= s_framer_out;

   s_ctrl_in <= cbar_masterport_out(0);
   cbar_masterport_in(0) <= s_ctrl_out;

   wbif: eb_master_wb_if
   generic map (g_adr_bits_hi => g_adr_bits_hi,
                g_mtu => g_mtu)
   PORT MAP (
      clk_i       => clk_i,
      rst_n_i     => rst_n_i,

      slave_i     => s_ctrl_in,
      slave_o     => s_ctrl_out,

      byte_cnt_i  => s_byte_cnt,
      error_i(0)  => s_ovf,

      clear_o     => s_clear,
      flush_o     => s_tx_send_now,

      my_mac_o    => s_my_mac,
      my_ip_o     => s_my_ip,
      my_port_o   => s_my_port,

      his_mac_o   => s_his_mac, 
      his_ip_o    => s_his_ip,
      his_port_o  => s_his_port,
      length_o    => s_length,
      max_ops_o   => s_max_ops,
      adr_hi_o    => s_adr_hi,
      eb_opt_o    => s_cfg_rec_hdr,
		
		udp_raw_o   => s_udp_raw_o,
      udp_we_o    => s_udp_we_o,
      udp_valid_i => s_udp_valid_i,
      udp_data_o  => s_udp_data_o
   );
  
   framer: eb_framer 
   PORT MAP (
      clk_i           => clk_i,
      rst_n_i         => s_rst_n,

      slave_i         => s_framer_in,
      slave_o         => s_framer_out,

      master_o        => s_framer2narrow,
      master_i        => s_narrow2framer,

      byte_cnt_o      => s_byte_cnt,
      ovf_o           => s_ovf,

      tx_send_now_i   => s_tx_send_now,
      tx_flush_o      => s_tx_flush, 
      max_ops_i       => s_max_ops,
      length_i        => s_length,
      cfg_rec_hdr_i   => s_cfg_rec_hdr);  
 
 ---debug
  framer_in   <= s_framer_in;
  framer_out  <= s_framer_out;
 
 
 
   narrow : eb_stream_narrow
    generic map(
      g_slave_width  => 32,
      g_master_width => 16)
    port map(
      clk_i    => clk_i,
      rst_n_i  => s_rst_n,
      slave_i  => s_narrow_in, 
      slave_o  => s_narrow_out,
      master_i => s_tx2narrow,
      master_o => s_narrow2tx);


   MUX_RAW_UDP : process(s_udp_raw_o, s_udp_we_o, s_udp_data_o, s_narrow_out, s_framer2narrow)
   begin
      s_narrow_in.sel <= (others => '1');
      s_narrow_in.we  <= '1';
      s_narrow_in.adr <= (others => '0');
      
      if s_udp_raw_o = '1' then
         s_narrow_in.cyc <= s_udp_raw_o;
         s_narrow_in.stb <= s_udp_we_o;
         s_narrow_in.dat <= s_udp_data_o;
         s_udp_valid_i   <= s_udp_raw_o and s_udp_we_o and not s_narrow_out.stall;
         s_narrow2framer <= ('0', '0', '0', '0', (others => '0'));
      else
         s_udp_valid_i   <= '0';
         s_narrow_in.cyc <= s_framer2narrow.cyc;
         s_narrow_in.stb <= s_framer2narrow.stb;
         s_narrow_in.dat <= s_framer2narrow.dat;
         s_narrow2framer <= s_narrow_out;
      end if;
   end process; 
   -- be careful, don't use this if you don't know what you're doing

   RAW_UDP : process(clk_i)
   begin
      if(rising_edge(clk_i)) then
         r_udp_raw <= s_udp_raw_o;
      end if;
   end process;  

   s_udp <= s_udp_raw_o and not r_udp_raw; 

---TX IF
   s_tx_stb      <= s_tx_flush or s_udp;
  
   tx : eb_master_eth_tx
    generic map(
      g_mtu => g_mtu)
    port map(
      clk_i        => clk_i,
      rst_n_i      => s_rst_n,
      
      src_i        => src_i,
      src_o        => src_o,
      slave_o      => s_tx2narrow,
      slave_i      => s_narrow2tx,
      
      stb_i        => s_tx_stb,
      stall_o      => open,
      mac_i        => s_his_mac,
      ip_i         => s_his_ip,
      port_i       => s_his_port,
      skip_stb_i   => s_clear,
      skip_stall_o => open,
      my_mac_i     => s_my_mac,
      my_ip_i      => s_my_ip,
      my_port_i    => s_my_port);

end architecture;
