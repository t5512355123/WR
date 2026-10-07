-------------------------------------------------------------------------------
-- Title      : White Rabbit NIC wrapper
-- Project    : WR PTP Core
-- URL        : http://www.ohwr.org/projects/wr-cores/wiki/Wrpc_core
-------------------------------------------------------------------------------
-- File       : wr_nic_wrapper.vhd
-- Company    : Seven Solutions
-- Standard   : VHDL'93
-------------------------------------------------------------------------------
-- Description: Wrapper for WR NIC modules: NIC, VIC, TxTSU and a Wishbone
-- Crossbar.
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
use work.wr_nic_wrapper_pkg.all;

entity wr_nic_wrapper is
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
end entity wr_nic_wrapper;

architecture struct of wr_nic_wrapper is
  -----------------------------------------------------------------------------
  -- Constants
  -----------------------------------------------------------------------------

  -- NIC constants
  constant c_NIC_INTERFACE_MODE      : t_wishbone_interface_mode      := PIPELINED;
  constant c_NIC_ADDRESS_GRANULARITY : t_wishbone_address_granularity := BYTE;
  constant c_NIC_SRC_CYC_ON_STALL    : boolean                        := true;
  constant c_NIC_PORT_MASK_BITS      : integer                        := g_num_ports+1;
  constant c_NIC_RMON_EVENTS_PP      : integer                        := 1;

  -- VIC constants
  constant c_VIC_INTERFACE_MODE      : t_wishbone_interface_mode      := PIPELINED;
  constant c_VIC_ADDRESS_GRANULARITY : t_wishbone_address_granularity := BYTE;
  constant c_VIC_EXTRA_IRQS          : integer                        := 3;
  constant c_VIC_NUM_IRQS            : integer                        := g_num_irqs+c_VIC_EXTRA_IRQS;
  constant c_VIC_IRQ_TXTSU           : integer                        := 0;
  constant c_VIC_IRQ_NIC             : integer                        := 1;
  constant c_VIC_IRQ_PPS             : integer                        := 2;

  -- TxTSU constants
  constant c_TXTSU_NUM_PORTS           : integer                        := g_num_ports;
  constant c_TXTSU_INTERFACE_MODE      : t_wishbone_interface_mode      := PIPELINED;
  constant c_TXTSU_ADDRESS_GRANULARITY : t_wishbone_address_granularity := BYTE;

  -----------------------------------------------------------------------------
  -- Signals
  -----------------------------------------------------------------------------

  -- Wishbone crossbar buses
  signal cbar_slave_i  : t_wishbone_slave_in_array(c_NIC_WRAPPER_XBAR_NUM_MASTERS-1 downto 0);
  signal cbar_slave_o  : t_wishbone_slave_out_array(c_NIC_WRAPPER_XBAR_NUM_MASTERS-1 downto 0);
  signal cbar_master_i : t_wishbone_master_in_array(c_NIC_WRAPPER_XBAR_NUM_SLAVES-1 downto 0);
  signal cbar_master_o : t_wishbone_master_out_array(c_NIC_WRAPPER_XBAR_NUM_SLAVES-1 downto 0);

  -- Interrupts
  signal txtsu_int     : std_logic;
  signal nic_int       : std_logic;
  signal vic_vec_int_i : std_logic_vector(c_VIC_NUM_IRQS-1 downto 0);

begin  -- architecture struct

  -----------------------------------------------------------------------------
  -- Wishbone Crossbar
  -----------------------------------------------------------------------------
  cmp_wb_xbar : xwb_sdb_crossbar
    generic map(
      g_num_masters => c_NIC_WRAPPER_XBAR_NUM_MASTERS,
      g_num_slaves  => c_NIC_WRAPPER_XBAR_NUM_SLAVES,
      g_registered  => c_NIC_WRAPPER_XBAR_REGISTERED,
      g_wraparound  => c_NIC_WRAPPER_XBAR_WRAPAROUND,
      g_layout      => c_nic_wrapper_xbar_layout,
      g_sdb_addr    => c_nic_wrapper_xbar_sdb_address)
    port map(
      clk_sys_i => clk_sys_i,
      rst_n_i   => resetn_i,
      slave_i   => cbar_slave_i,
      slave_o   => cbar_slave_o,
      master_i  => cbar_master_i,
      master_o  => cbar_master_o);

  -- Assign slave interface of the WB crossbar to external port
  cbar_slave_i(c_NIC_WRAPPER_XBAR_MASTER_EXT) <= ext_slave_i;
  ext_slave_o                                 <= cbar_slave_o(c_NIC_WRAPPER_XBAR_MASTER_EXT);

  -----------------------------------------------------------------------------
  -- WR-NIC module
  -----------------------------------------------------------------------------
  cmp_nic : xwr_nic
    generic map(
      g_interface_mode           => c_NIC_INTERFACE_MODE,
      g_address_granularity      => c_NIC_ADDRESS_GRANULARITY,
      g_src_cyc_on_stall         => c_NIC_SRC_CYC_ON_STALL,
      g_port_mask_bits => c_NIC_PORT_MASK_BITS,
      g_rmon_events_pp => c_NIC_RMON_EVENTS_PP)
    port map(
      clk_sys_i           => clk_sys_i,
      rst_n_i             => resetn_i,
      pps_p_i   => pps_p_i,
      pps_valid_i         => pps_valid_i,
      snk_i               => nic_snk_i,
      snk_o               => nic_snk_o,
      src_i               => nic_src_i,
      src_o               => nic_src_o,
      rtu_dst_port_mask_o => open,
      rtu_prio_o          => open,
      rtu_drop_o          => open,
      rtu_rsp_valid_o     => open,
      rtu_rsp_ack_i       => '1',
      wb_i                => cbar_master_o(c_NIC_WRAPPER_XBAR_SLAVE_NIC),
      wb_o                => cbar_master_i(c_NIC_WRAPPER_XBAR_SLAVE_NIC),
      int_o               => nic_int,
      rmon_events_o       => open);

  -----------------------------------------------------------------------------
  -- Wishbone VIC controller
  -----------------------------------------------------------------------------
  cmp_vic : xwb_vic
    generic map(
      g_interface_mode      => c_VIC_INTERFACE_MODE,
      g_address_granularity => c_VIC_ADDRESS_GRANULARITY,
      g_num_interrupts      => c_VIC_NUM_IRQS)
    port map(
      clk_sys_i    => clk_sys_i,
      rst_n_i      => resetn_i,
      slave_i      => cbar_master_o(c_NIC_WRAPPER_XBAR_SLAVE_VIC),
      slave_o      => cbar_master_i(c_NIC_WRAPPER_XBAR_SLAVE_VIC),
      irqs_i       => vic_vec_int_i,
      irq_master_o => vic_int_o);

  vic_vec_int_i(c_VIC_IRQ_TXTSU)                          <= txtsu_int;
  vic_vec_int_i(c_VIC_IRQ_NIC)                            <= nic_int;
  vic_vec_int_i(c_VIC_IRQ_PPS)                            <= pps_p_i;
  vic_vec_int_i(c_VIC_NUM_IRQS-1 downto c_VIC_EXTRA_IRQS) <= vic_irqs_i;

  -----------------------------------------------------------------------------
  -- TxTSU module
  -----------------------------------------------------------------------------
  cmp_txtsu : xwr_tx_tsu
    generic map(
      g_num_ports           => c_TXTSU_NUM_PORTS,
      g_interface_mode      => c_TXTSU_INTERFACE_MODE,
      g_address_granularity => c_TXTSU_ADDRESS_GRANULARITY)
    port map(
      clk_sys_i        => clk_sys_i,
      rst_n_i          => resetn_i,
      timestamps_i     => txtsu_timestamps_i,
      timestamps_ack_o => txtsu_timestamps_ack_o,
      wb_i             => cbar_master_o(c_NIC_WRAPPER_XBAR_SLAVE_TXTSU),
      wb_o             => cbar_master_i(c_NIC_WRAPPER_XBAR_SLAVE_TXTSU),
      int_o            => txtsu_int);

end architecture struct;
