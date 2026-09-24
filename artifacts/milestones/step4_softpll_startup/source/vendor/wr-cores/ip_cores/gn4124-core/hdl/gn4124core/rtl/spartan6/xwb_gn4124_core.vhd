--------------------------------------------------------------------------------
-- CERN BE-CO-HT
-- GN4124 core for PCIe FMC carrier
-- http://www.ohwr.org/projects/gn4124-core
--------------------------------------------------------------------------------
--
-- unit name:   xwb_gn4124_core
--
-- description: GN4124 core top level using WB records and slave adapters.
--
-- Version for Spartan6 FPGAs.
--
--------------------------------------------------------------------------------
-- Copyright CERN 2018
--------------------------------------------------------------------------------
-- Copyright and related rights are licensed under the Solderpad Hardware
-- License, Version 2.0 (the "License"); you may not use this file except
-- in compliance with the License. You may obtain a copy of the License at
-- http://solderpad.org/licenses/SHL-2.0.
-- Unless required by applicable law or agreed to in writing, software,
-- hardware and materials distributed under this License is distributed on an
-- "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express
-- or implied. See the License for the specific language governing permissions
-- and limitations under the License.
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use work.gn4124_core_pkg.all;
use work.wishbone_pkg.all;

entity xwb_gn4124_core is
  generic (
    g_WB_MASTER_MODE         : t_wishbone_interface_mode      := PIPELINED;
    g_WB_MASTER_GRANULARITY  : t_wishbone_address_granularity := BYTE;
    g_WB_DMA_CFG_MODE        : t_wishbone_interface_mode      := PIPELINED;
    g_WB_DMA_CFG_GRANULARITY : t_wishbone_address_granularity := BYTE;
    g_WB_DMA_DAT_MODE        : t_wishbone_interface_mode      := PIPELINED;
    g_WB_DMA_DAT_GRANULARITY : t_wishbone_address_granularity := BYTE;
    -- Wishbone ACK timeout (in wishbone clock cycles)
    g_ACK_TIMEOUT            : positive                       := 100);
  port (
    ---------------------------------------------------------
    -- Control and status
    rst_n_a_i : in  std_logic;  -- Asynchronous reset from GN4124
    status_o  : out std_logic_vector(31 downto 0);  -- Core status output

    ---------------------------------------------------------
    -- P2L Direction
    --
    -- Source Sync DDR related signals
    p2l_clk_p_i  : in  std_logic;  -- Receiver Source Synchronous Clock+
    p2l_clk_n_i  : in  std_logic;  -- Receiver Source Synchronous Clock-
    p2l_data_i   : in  std_logic_vector(15 downto 0);  -- Parallel receive data
    p2l_dframe_i : in  std_logic;  -- Receive Frame
    p2l_valid_i  : in  std_logic;  -- Receive Data Valid
    -- P2L Control
    p2l_rdy_o    : out std_logic;  -- Rx Buffer Full Flag
    p_wr_req_i   : in  std_logic_vector(1 downto 0);   -- PCIe Write Request
    p_wr_rdy_o   : out std_logic_vector(1 downto 0);   -- PCIe Write Ready
    rx_error_o   : out std_logic;  -- Receive Error
    vc_rdy_i     : in  std_logic_vector(1 downto 0);   -- Virtual channel ready

    ---------------------------------------------------------
    -- L2P Direction
    --
    -- Source Sync DDR related signals
    l2p_clk_p_o  : out std_logic;  -- Transmitter Source Synchronous Clock+
    l2p_clk_n_o  : out std_logic;  -- Transmitter Source Synchronous Clock-
    l2p_data_o   : out std_logic_vector(15 downto 0);  -- Parallel transmit data
    l2p_dframe_o : out std_logic;  -- Transmit Data Frame
    l2p_valid_o  : out std_logic;  -- Transmit Data Valid
    -- L2P Control
    l2p_edb_o    : out std_logic;  -- Packet termination and discard
    l2p_rdy_i    : in  std_logic;  -- Tx Buffer Full Flag
    l_wr_rdy_i   : in  std_logic_vector(1 downto 0);  -- Local-to-PCIe Write
    p_rd_d_rdy_i : in  std_logic_vector(1 downto 0);  -- PCIe-to-Local Read Response Data Ready
    tx_error_i   : in  std_logic;  -- Transmit Error

    ---------------------------------------------------------
    -- Interrupt interface
    dma_irq_o : out std_logic_vector(1 downto 0);  -- Interrupts sources to IRQ manager
    irq_p_i   : in  std_logic;  -- Interrupt request pulse from IRQ manager
    irq_p_o   : out std_logic;  -- Interrupt request pulse to GN4124 GPIO

    ---------------------------------------------------------
    -- Main master wishbone interface (to all downstream slaves)
    wb_master_clk_i   : in  std_logic;
    wb_master_rst_n_i : in  std_logic;
    wb_master_i       : in  t_wishbone_master_in;
    wb_master_o       : out t_wishbone_master_out;

    ---------------------------------------------------------
    -- DMA configuration slave wishbone interface
    wb_dma_cfg_clk_i   : in  std_logic;
    wb_dma_cfg_rst_n_i : in  std_logic;
    wb_dma_cfg_i       : in  t_wishbone_slave_in;
    wb_dma_cfg_o       : out t_wishbone_slave_out;

    ---------------------------------------------------------
    -- Dedicated DMA data master wishbone interface
    wb_dma_dat_clk_i   : in  std_logic;
    wb_dma_dat_rst_n_i : in  std_logic;
    wb_dma_dat_i       : in  t_wishbone_master_in;
    wb_dma_dat_o       : out t_wishbone_master_out);

end xwb_gn4124_core;

architecture arch of xwb_gn4124_core is

  signal wb_master_in   : t_wishbone_master_in;
  signal wb_master_out  : t_wishbone_master_out;
  signal wb_dma_cfg_in  : t_wishbone_slave_in;
  signal wb_dma_cfg_out : t_wishbone_slave_out;
  signal wb_dma_dat_in  : t_wishbone_master_in;
  signal wb_dma_dat_out : t_wishbone_master_out;

begin

  ------------------------------------------------------------------------------
  -- WB slave adadters
  ------------------------------------------------------------------------------
  cmp_wb_master_adapter : wb_slave_adapter
    generic map (
      g_master_use_struct  => TRUE,
      g_master_mode        => g_WB_MASTER_MODE,
      g_master_granularity => g_WB_MASTER_GRANULARITY,
      g_slave_use_struct   => TRUE,
      g_slave_mode         => PIPELINED,
      g_slave_granularity  => WORD)
    port map (
      clk_sys_i => wb_master_clk_i,
      rst_n_i   => wb_master_rst_n_i,
      slave_i   => wb_master_out,
      slave_o   => wb_master_in,
      master_i  => wb_master_i,
      master_o  => wb_master_o);

  cmp_wb_dma_cfg_adapter : wb_slave_adapter
    generic map (
      g_master_use_struct  => TRUE,
      g_master_mode        => CLASSIC,
      g_master_granularity => WORD,
      g_slave_use_struct   => TRUE,
      g_slave_mode         => g_WB_DMA_CFG_MODE,
      g_slave_granularity  => g_WB_DMA_CFG_GRANULARITY)
    port map (
      clk_sys_i => wb_dma_cfg_clk_i,
      rst_n_i   => wb_dma_cfg_rst_n_i,
      slave_i   => wb_dma_cfg_i,
      slave_o   => wb_dma_cfg_o,
      master_i  => wb_dma_cfg_out,
      master_o  => wb_dma_cfg_in);

  cmp_wb_dma_dat_adapter : wb_slave_adapter
    generic map (
      g_master_use_struct  => TRUE,
      g_master_mode        => g_WB_DMA_DAT_MODE,
      g_master_granularity => g_WB_DMA_DAT_GRANULARITY,
      g_slave_use_struct   => TRUE,
      g_slave_mode         => PIPELINED,
      g_slave_granularity  => BYTE)
    port map (
      clk_sys_i => wb_dma_dat_clk_i,
      rst_n_i   => wb_dma_dat_rst_n_i,
      slave_i   => wb_dma_dat_out,
      slave_o   => wb_dma_dat_in,
      master_i  => wb_dma_dat_i,
      master_o  => wb_dma_dat_o);

  ------------------------------------------------------------------------------
  -- Wrapped GN4124 Core
  ------------------------------------------------------------------------------

  cmp_wrapped_gn4124 : gn4124_core
    generic map (
      g_ACK_TIMEOUT => g_ACK_TIMEOUT)
    port map (
      rst_n_a_i       => rst_n_a_i,
      status_o        => status_o,
      p2l_clk_p_i     => p2l_clk_p_i,
      p2l_clk_n_i     => p2l_clk_n_i,
      p2l_data_i      => p2l_data_i,
      p2l_dframe_i    => p2l_dframe_i,
      p2l_valid_i     => p2l_valid_i,
      p2l_rdy_o       => p2l_rdy_o,
      p_wr_req_i      => p_wr_req_i,
      p_wr_rdy_o      => p_wr_rdy_o,
      rx_error_o      => rx_error_o,
      vc_rdy_i        => vc_rdy_i,
      l2p_clk_p_o     => l2p_clk_p_o,
      l2p_clk_n_o     => l2p_clk_n_o,
      l2p_data_o      => l2p_data_o,
      l2p_dframe_o    => l2p_dframe_o,
      l2p_valid_o     => l2p_valid_o,
      l2p_edb_o       => l2p_edb_o,
      l2p_rdy_i       => l2p_rdy_i,
      l_wr_rdy_i      => l_wr_rdy_i,
      p_rd_d_rdy_i    => p_rd_d_rdy_i,
      tx_error_i      => tx_error_i,
      dma_irq_o       => dma_irq_o,
      irq_p_i         => irq_p_i,
      irq_p_o         => irq_p_o,
      dma_reg_rst_n_i => wb_dma_cfg_rst_n_i,
      dma_reg_clk_i   => wb_dma_cfg_clk_i,
      dma_reg_adr_i   => wb_dma_cfg_in.adr,
      dma_reg_dat_i   => wb_dma_cfg_in.dat,
      dma_reg_sel_i   => wb_dma_cfg_in.sel,
      dma_reg_stb_i   => wb_dma_cfg_in.stb,
      dma_reg_we_i    => wb_dma_cfg_in.we,
      dma_reg_cyc_i   => wb_dma_cfg_in.cyc,
      dma_reg_dat_o   => wb_dma_cfg_out.dat,
      dma_reg_ack_o   => wb_dma_cfg_out.ack,
      dma_reg_stall_o => wb_dma_cfg_out.stall,
      csr_rst_n_i     => wb_master_rst_n_i,
      csr_clk_i       => wb_master_clk_i,
      csr_adr_o       => wb_master_out.adr,
      csr_dat_o       => wb_master_out.dat,
      csr_sel_o       => wb_master_out.sel,
      csr_stb_o       => wb_master_out.stb,
      csr_we_o        => wb_master_out.we,
      csr_cyc_o       => wb_master_out.cyc,
      csr_dat_i       => wb_master_in.dat,
      csr_ack_i       => wb_master_in.ack,
      csr_stall_i     => wb_master_in.stall,
      csr_err_i       => wb_master_in.err,
      csr_rty_i       => wb_master_in.rty,
      dma_rst_n_i     => wb_dma_dat_rst_n_i,
      dma_clk_i       => wb_dma_dat_clk_i,
      dma_adr_o       => wb_dma_dat_out.adr,
      dma_dat_o       => wb_dma_dat_out.dat,
      dma_sel_o       => wb_dma_dat_out.sel,
      dma_stb_o       => wb_dma_dat_out.stb,
      dma_we_o        => wb_dma_dat_out.we,
      dma_cyc_o       => wb_dma_dat_out.cyc,
      dma_dat_i       => wb_dma_dat_in.dat,
      dma_ack_i       => wb_dma_dat_in.ack,
      dma_stall_i     => wb_dma_dat_in.stall,
      dma_err_i       => wb_dma_dat_in.err,
      dma_rty_i       => wb_dma_dat_in.rty);

  -- drive unused outputs
  wb_dma_cfg_out.err <= '0';
  wb_dma_cfg_out.rty <= '0';

end architecture arch;
