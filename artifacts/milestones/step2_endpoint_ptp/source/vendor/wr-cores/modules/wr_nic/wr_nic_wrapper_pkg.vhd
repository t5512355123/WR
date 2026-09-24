-------------------------------------------------------------------------------
-- Title      : WR-NIC Wrapper package
-- Project    : WR PTP Core
-- URL        : http://www.ohwr.org/projects/wr-cores/wiki/Wrpc_core
-------------------------------------------------------------------------------
-- File       : wr_nic_wrapper_pkg.vhd
-- Company    : Seven Solutions
-- Standard   : VHDL'93
-------------------------------------------------------------------------------
--
-- Copyright (c) 2019 CERN (www.cern.ch)
--
-- GNU LESSER GENERAL PUBLIC LICENSE
--
-- This source file is free software; you can redistribute it   
-- and/or modify it under the terms of the GNU Lesser General   
-- Public License as published by the Free Software Foundation; 
-- either version 2.1 of the License, or (at your option) any   
-- later version.                                               
--
-- This source is distributed in the hope that it will be       
-- useful, but WITHOUT ANY WARRANTY; without even the implied   
-- warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR      
-- PURPOSE.  See the GNU Lesser General Public License for more 
-- details.                                                     
--
-- You should have received a copy of the GNU Lesser General    
-- Public License along with this source; if not, download it   
-- from http://www.gnu.org/licenses/lgpl-2.1.html
-- 
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.gencores_pkg.all;
use work.wrcore_pkg.all;
use work.wishbone_pkg.all;
use work.wr_fabric_pkg.all;
use work.endpoint_pkg.all;

package wr_nic_wrapper_pkg is

  -----------------------------------------------------------------------------
  -- Components
  -----------------------------------------------------------------------------

  -- Network Interface Core (NIC) component
  component xwr_nic
    generic(
      g_interface_mode      : t_wishbone_interface_mode      := CLASSIC;
      g_address_granularity : t_wishbone_address_granularity := WORD;
      g_src_cyc_on_stall    : boolean                        := false;
      g_port_mask_bits      : integer                        := 32;  --should be num_ports+1
      g_rmon_events_pp      : integer                        := 1);
    port (
      clk_sys_i           : in  std_logic;
      rst_n_i             : in  std_logic;
      pps_p_i             : in  std_logic;
      pps_valid_i         : in  std_logic;
      snk_i               : in  t_wrf_sink_in;
      snk_o               : out t_wrf_sink_out;
      src_i               : in  t_wrf_source_in;
      src_o               : out t_wrf_source_out;
      rtu_dst_port_mask_o : out std_logic_vector(g_port_mask_bits-1 downto 0);
      rtu_prio_o          : out std_logic_vector(2 downto 0);
      rtu_drop_o          : out std_logic;
      rtu_rsp_valid_o     : out std_logic;
      rtu_rsp_ack_i       : in  std_logic;
      wb_i                : in  t_wishbone_slave_in;
      wb_o                : out t_wishbone_slave_out;
      int_o               : out std_logic;
      rmon_events_o       : out std_logic_vector(g_port_mask_bits*g_rmon_events_pp-1 downto 0));
  end component;

  -- Transimission TimeStamp Unit (TxTSU) component
  component xwr_tx_tsu
    generic(
      g_num_ports           : integer                        := 10;
      g_interface_mode      : t_wishbone_interface_mode      := CLASSIC;
      g_address_granularity : t_wishbone_address_granularity := WORD);
    port(
      clk_sys_i        : in  std_logic;
      rst_n_i          : in  std_logic;
      timestamps_i     : in  t_txtsu_timestamp_array(g_num_ports-1 downto 0);
      timestamps_ack_o : out std_logic_vector(g_num_ports -1 downto 0);
      wb_i             : in  t_wishbone_slave_in;
      wb_o             : out t_wishbone_slave_out;
      int_o            : out std_logic);
  end component;

  component wr_nic_wrapper
    generic(
      -- Number of peripheral interrupt lines
      g_num_irqs  : integer := 3;
      -- Number of ports for the TxTSU module
      g_num_ports : integer := 1
      );
    port(
      ---------------------------------------------------------------------------
      -- Global ports (Clocks & Resets)
      ---------------------------------------------------------------------------
      -- System clock
      clk_sys_i : in std_logic;
      -- Global reset (active low)
      resetn_i  : in std_logic;

      ---------------------------------------------------------------------------
      -- External WB slave interface
      ---------------------------------------------------------------------------
      ext_slave_i : in  t_wishbone_slave_in;
      ext_slave_o : out t_wishbone_slave_out;

      ---------------------------------------------------------------------------
      -- NIC fabric data buses
      ---------------------------------------------------------------------------
      nic_snk_i : in  t_wrf_sink_in;
      nic_snk_o : out t_wrf_sink_out;
      nic_src_i : in  t_wrf_source_in;
      nic_src_o : out t_wrf_source_out;

      -- PPS-related signal for NIC core
      pps_p_i     : in std_logic := '0';
      pps_valid_i : in std_logic := '0';

      ---------------------------------------------------------------------------
      -- VIC ports (peripheral interrupts lines and global interrupt output)
      ---------------------------------------------------------------------------
      vic_irqs_i : in  std_logic_vector(g_num_irqs-1 downto 0);
      vic_int_o  : out std_logic;

      ---------------------------------------------------------------------------
      -- TxTSU ports (Timestamp trigger and acknowlegdement signal)
      ---------------------------------------------------------------------------
      txtsu_timestamps_i     : in  t_txtsu_timestamp_array(g_num_ports-1 downto 0);
      txtsu_timestamps_ack_o : out std_logic_vector(g_num_ports -1 downto 0)
      );
  end component;

  -----------------------------------------------------------------------------
  -- Constants
  -----------------------------------------------------------------------------

  -- SDB constants for NIC and TxTSU
  constant c_xwr_nic_sdb : t_sdb_device := (
    abi_class     => x"0000",           -- undocumented device
    abi_ver_major => x"01",
    abi_ver_minor => x"01",
    wbd_endian    => c_sdb_endian_big,
    wbd_width     => x"7",              -- 8/16/32-bit port granularity
    sdb_component => (
      addr_first    => x"0000000000000000",
      addr_last     => x"000000000000ffff",  -- I think this is overestimated (orig. 1ffff, wrsw_hdl. ffff)
      product       => (
        vendor_id     => x"000000000000CE42",  -- CERN
        device_id     => x"00000012",
        version       => x"00000001",
        date          => x"20000101",       -- UNKNOWN
        name          => "WR-NIC             ")));

  constant c_xwr_txtsu_sdb : t_sdb_device := (
    abi_class     => x"0000",              -- undocumented device
    abi_ver_major => x"01",
    abi_ver_minor => x"01",
    wbd_endian    => c_sdb_endian_big,
    wbd_width     => x"7",                 -- 8/16/32-bit port granularity
    sdb_component => (
      addr_first    => x"0000000000000000",
      addr_last     => x"00000000000000ff",
      product       => (
        vendor_id     => x"000000000000CE42",  -- CERN
        device_id     => x"00000014",
        version       => x"00000001",
        date          => x"20120316",
        name          => "WR-TXTSU           ")));

  -- WB Crossbar constants
  constant c_NIC_WRAPPER_XBAR_REGISTERED : boolean := true;
  constant c_NIC_WRAPPER_XBAR_WRAPAROUND : boolean := true;

  constant c_NIC_WRAPPER_XBAR_NUM_MASTERS : integer := 1;
  constant c_NIC_WRAPPER_XBAR_MASTER_EXT  : integer := 0;

  constant c_NIC_WRAPPER_XBAR_NUM_SLAVES  : integer := 3;
  constant c_NIC_WRAPPER_XBAR_SLAVE_NIC   : integer := 0;
  constant c_NIC_WRAPPER_XBAR_SLAVE_VIC   : integer := 1;
  constant c_NIC_WRAPPER_XBAR_SLAVE_TXTSU : integer := 2;

  -- Crossbar memory layout
  constant c_nic_wrapper_xbar_layout : t_sdb_record_array(c_NIC_WRAPPER_XBAR_NUM_SLAVES-1 downto 0) := (
    c_NIC_WRAPPER_XBAR_SLAVE_NIC   => f_sdb_embed_device(c_xwr_nic_sdb, x"00000000"),
    c_NIC_WRAPPER_XBAR_SLAVE_VIC   => f_sdb_embed_device(c_xwb_vic_sdb, x"00010000"),
    c_NIC_WRAPPER_XBAR_SLAVE_TXTSU => f_sdb_embed_device(c_xwr_txtsu_sdb, x"00010100")
    );
  -- Crossbar SDB entry address
  constant c_nic_wrapper_xbar_sdb_address : t_wishbone_address := x"00011000";
  constant c_nic_wrapper_xbar_bridge_sdb  : t_sdb_bridge :=
    f_xwb_bridge_layout_sdb(true, c_nic_wrapper_xbar_layout, c_nic_wrapper_xbar_sdb_address);

end wr_nic_wrapper_pkg;

package body wr_nic_wrapper_pkg is
end package body wr_nic_wrapper_pkg;
