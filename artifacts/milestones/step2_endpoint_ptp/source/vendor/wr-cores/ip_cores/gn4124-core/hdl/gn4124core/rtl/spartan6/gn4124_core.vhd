--------------------------------------------------------------------------------
-- CERN BE-CO-HT
-- GN4124 core for PCIe FMC carrier
-- http://www.ohwr.org/projects/gn4124-core
--------------------------------------------------------------------------------
--
-- unit name:   gn4124_core
--
-- description: GN4124 core top level. Version for spartan6 FPGAs.
--
--------------------------------------------------------------------------------
-- Copyright CERN 2010-2018
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
use work.gencores_pkg.all;

library UNISIM;
use UNISIM.vcomponents.all;


--==============================================================================
-- Entity declaration for GN4124 core (gn4124_core)
--==============================================================================
entity gn4124_core is
  generic (
    g_ACK_TIMEOUT : positive := 100                    -- Wishbone ACK timeout (in wishbone clock cycles)
    );
  port
    (
      ---------------------------------------------------------
      -- Control and status
      rst_n_a_i : in  std_logic;                      -- Asynchronous reset from GN4124
      status_o  : out std_logic_vector(31 downto 0);  -- Core status output

      ---------------------------------------------------------
      -- P2L Direction
      --
      -- Source Sync DDR related signals
      p2l_clk_p_i  : in  std_logic;                      -- Receiver Source Synchronous Clock+
      p2l_clk_n_i  : in  std_logic;                      -- Receiver Source Synchronous Clock-
      p2l_data_i   : in  std_logic_vector(15 downto 0);  -- Parallel receive data
      p2l_dframe_i : in  std_logic;                      -- Receive Frame
      p2l_valid_i  : in  std_logic;                      -- Receive Data Valid
      -- P2L Control
      p2l_rdy_o    : out std_logic;                      -- Rx Buffer Full Flag
      p_wr_req_i   : in  std_logic_vector(1 downto 0);   -- PCIe Write Request
      p_wr_rdy_o   : out std_logic_vector(1 downto 0);   -- PCIe Write Ready
      rx_error_o   : out std_logic;                      -- Receive Error
      vc_rdy_i     : in  std_logic_vector(1 downto 0);   -- Virtual channel ready

      ---------------------------------------------------------
      -- L2P Direction
      --
      -- Source Sync DDR related signals
      l2p_clk_p_o  : out std_logic;                      -- Transmitter Source Synchronous Clock+
      l2p_clk_n_o  : out std_logic;                      -- Transmitter Source Synchronous Clock-
      l2p_data_o   : out std_logic_vector(15 downto 0);  -- Parallel transmit data
      l2p_dframe_o : out std_logic;                      -- Transmit Data Frame
      l2p_valid_o  : out std_logic;                      -- Transmit Data Valid
      -- L2P Control
      l2p_edb_o    : out std_logic;                      -- Packet termination and discard
      l2p_rdy_i    : in  std_logic;                      -- Tx Buffer Full Flag
      l_wr_rdy_i   : in  std_logic_vector(1 downto 0);   -- Local-to-PCIe Write
      p_rd_d_rdy_i : in  std_logic_vector(1 downto 0);   -- PCIe-to-Local Read Response Data Ready
      tx_error_i   : in  std_logic;                      -- Transmit Error

      ---------------------------------------------------------
      -- Interrupt interface
      dma_irq_o : out std_logic_vector(1 downto 0);  -- Interrupts sources to IRQ manager
      irq_p_i   : in  std_logic;                     -- Interrupt request pulse from IRQ manager
      irq_p_o   : out std_logic;                     -- Interrupt request pulse to GN4124 GPIO

      ---------------------------------------------------------
      -- DMA registers wishbone interface (slave classic)
      dma_reg_rst_n_i : in  std_logic;
      dma_reg_clk_i   : in  std_logic;
      dma_reg_adr_i   : in  std_logic_vector(31 downto 0);
      dma_reg_dat_i   : in  std_logic_vector(31 downto 0);
      dma_reg_sel_i   : in  std_logic_vector(3 downto 0);
      dma_reg_stb_i   : in  std_logic;
      dma_reg_we_i    : in  std_logic;
      dma_reg_cyc_i   : in  std_logic;
      dma_reg_dat_o   : out std_logic_vector(31 downto 0);
      dma_reg_ack_o   : out std_logic;
      dma_reg_stall_o : out std_logic;

      ---------------------------------------------------------
      -- CSR wishbone interface (master pipelined)
      csr_rst_n_i : in  std_logic;
      csr_clk_i   : in  std_logic;
      csr_adr_o   : out std_logic_vector(31 downto 0);
      csr_dat_o   : out std_logic_vector(31 downto 0);
      csr_sel_o   : out std_logic_vector(3 downto 0);
      csr_stb_o   : out std_logic;
      csr_we_o    : out std_logic;
      csr_cyc_o   : out std_logic;
      csr_dat_i   : in  std_logic_vector(31 downto 0);
      csr_ack_i   : in  std_logic;
      csr_stall_i : in  std_logic;
      csr_err_i   : in  std_logic := '0';
      csr_rty_i   : in  std_logic := '0';      -- not used internally

      ---------------------------------------------------------
      -- DMA wishbone interface (master pipelined)
      dma_rst_n_i : in  std_logic;
      dma_clk_i   : in  std_logic;
      dma_adr_o   : out std_logic_vector(31 downto 0);
      dma_dat_o   : out std_logic_vector(31 downto 0);
      dma_sel_o   : out std_logic_vector(3 downto 0);
      dma_stb_o   : out std_logic;
      dma_we_o    : out std_logic;
      dma_cyc_o   : out std_logic;
      dma_dat_i   : in  std_logic_vector(31 downto 0);
      dma_ack_i   : in  std_logic;
      dma_stall_i : in  std_logic;
      dma_err_i   : in  std_logic := '0';      -- not used internally
      dma_rty_i   : in  std_logic := '0'       -- not used internally
      );
end gn4124_core;


--==============================================================================
-- Architecture declaration for GN4124 core (gn4124_core)
--==============================================================================
architecture rtl of gn4124_core is

  ------------------------------------------------------------------------------
  -- Signals declaration
  ------------------------------------------------------------------------------

  -- Clock
  signal sys_clk        : std_logic;
  signal io_clk         : std_logic;
  signal serdes_strobe  : std_logic;
  signal p2l_pll_locked : std_logic;

  attribute keep                 : string;
  attribute keep of sys_clk : signal is "TRUE";
  attribute keep of io_clk  : signal is "TRUE";

  -- Reset for all clk_p logic
  signal sys_rst_n  : std_logic;
  signal arst_pll   : std_logic;

  -------------------------------------------------------------
  -- P2L DataPath (from deserializer to packet decoder)
  -------------------------------------------------------------
  signal des_pd_valid  : std_logic;
  signal des_pd_dframe : std_logic;
  signal des_pd_data   : std_logic_vector(31 downto 0);

  -- Local bus control
  signal p_wr_rdy    : std_logic;
  signal p2l_rdy_wbm : std_logic;
  signal p2l_rdy_pdm : std_logic;

  -------------------------------------------------------------
  -- P2L DataPath (from packet decoder to Wishbone master and P2L DMA master)
  -------------------------------------------------------------
  signal p2l_hdr_start   : std_logic;
  signal p2l_hdr_length  : std_logic_vector(9 downto 0);
  signal p2l_hdr_cid     : std_logic_vector(1 downto 0);
  signal p2l_hdr_last    : std_logic;
  signal p2l_hdr_stat    : std_logic_vector(1 downto 0);
  signal p2l_target_mrd  : std_logic;
  signal p2l_target_mwr  : std_logic;
  signal p2l_master_cpld : std_logic;
  signal p2l_master_cpln : std_logic;
  signal p2l_d_valid     : std_logic;
  signal p2l_d_last      : std_logic;
  signal p2l_d           : std_logic_vector(31 downto 0);
  signal p2l_be          : std_logic_vector(3 downto 0);
  signal p2l_addr        : std_logic_vector(31 downto 0);
  signal p2l_addr_start  : std_logic;

  -------------------------------------------------------------
  -- L2P DataPath (from arbiter to serializer)
  -------------------------------------------------------------
  signal arb_ser_valid  : std_logic;
  signal arb_ser_dframe : std_logic;
  signal arb_ser_data   : std_logic_vector(31 downto 0);

  -- Local bus control
  signal l_wr_rdy_t    : std_logic;
  signal l_wr_rdy      : std_logic;
  signal p_rd_d_rdy_t  : std_logic;
  signal p_rd_d_rdy    : std_logic;
  signal l2p_rdy       : std_logic;
  signal l2p_edb       : std_logic;
  signal l2p_edb_d1    : std_logic;
  signal l2p_edb_d2    : std_logic;
  signal tx_error      : std_logic;

  -------------------------------------------------------------
  -- CSR wishbone master to arbiter
  -------------------------------------------------------------
  signal wbm_arb_valid  : std_logic;
  signal wbm_arb_dframe : std_logic;
  signal wbm_arb_data   : std_logic_vector(31 downto 0);
  signal wbm_arb_req    : std_logic;
  signal arb_wbm_gnt    : std_logic;

  -------------------------------------------------------------
  -- L2P DMA master to arbiter
  -------------------------------------------------------------
  signal ldm_arb_req    : std_logic;
  signal arb_ldm_gnt    : std_logic;
  signal ldm_arb_valid  : std_logic;
  signal ldm_arb_dframe : std_logic;
  signal ldm_arb_data   : std_logic_vector(31 downto 0);

  -------------------------------------------------------------
  -- P2L DMA master to arbiter
  -------------------------------------------------------------
  signal pdm_arb_valid  : std_logic;
  signal pdm_arb_dframe : std_logic;
  signal pdm_arb_data   : std_logic_vector(31 downto 0);
  signal pdm_arb_req    : std_logic;
  signal arb_pdm_gnt    : std_logic;

  -------------------------------------------------------------
  -- DMA controller
  -------------------------------------------------------------
  signal dma_ctrl_carrier_addr : std_logic_vector(31 downto 0);
  signal dma_ctrl_host_addr_h  : std_logic_vector(31 downto 0);
  signal dma_ctrl_host_addr_l  : std_logic_vector(31 downto 0);
  signal dma_ctrl_len          : std_logic_vector(31 downto 0);
  signal dma_ctrl_start_l2p    : std_logic;
  signal dma_ctrl_start_p2l    : std_logic;
  signal dma_ctrl_start_next   : std_logic;

  signal dma_ctrl_done      : std_logic;
  signal dma_ctrl_error     : std_logic;
  signal dma_ctrl_l2p_done  : std_logic;
  signal dma_ctrl_l2p_error : std_logic;
  signal dma_ctrl_p2l_done  : std_logic;
  signal dma_ctrl_p2l_error : std_logic;
  signal dma_ctrl_byte_swap : std_logic_vector(1 downto 0);
  signal dma_ctrl_abort     : std_logic;

  signal next_item_carrier_addr : std_logic_vector(31 downto 0);
  signal next_item_host_addr_h  : std_logic_vector(31 downto 0);
  signal next_item_host_addr_l  : std_logic_vector(31 downto 0);
  signal next_item_len          : std_logic_vector(31 downto 0);
  signal next_item_next_l       : std_logic_vector(31 downto 0);
  signal next_item_next_h       : std_logic_vector(31 downto 0);
  signal next_item_attrib       : std_logic_vector(31 downto 0);
  signal next_item_valid        : std_logic;

  signal dma_irq : std_logic_vector(1 downto 0);

  ------------------------------------------------------------------------------
  -- CSR wishbone bus
  ------------------------------------------------------------------------------
  signal csr_adr : std_logic_vector(30 downto 0);

  ------------------------------------------------------------------------------
  -- DMA wishbone bus
  ------------------------------------------------------------------------------
  signal l2p_dma_adr     : std_logic_vector(31 downto 0);
  signal l2p_dma_dat_s2m : std_logic_vector(31 downto 0);
  signal l2p_dma_dat_m2s : std_logic_vector(31 downto 0);
  signal l2p_dma_sel     : std_logic_vector(3 downto 0);
  signal l2p_dma_cyc     : std_logic;
  signal l2p_dma_stb     : std_logic;
  signal l2p_dma_we      : std_logic;
  signal l2p_dma_ack     : std_logic;
  signal l2p_dma_stall   : std_logic;

  signal p2l_dma_adr     : std_logic_vector(31 downto 0);
  signal p2l_dma_dat_s2m : std_logic_vector(31 downto 0);
  signal p2l_dma_dat_m2s : std_logic_vector(31 downto 0);
  signal p2l_dma_sel     : std_logic_vector(3 downto 0);
  signal p2l_dma_cyc     : std_logic;
  signal p2l_dma_stb     : std_logic;
  signal p2l_dma_we      : std_logic;
  signal p2l_dma_ack     : std_logic;
  signal p2l_dma_stall   : std_logic;


--==============================================================================
-- Architecture begin (gn4124_core)
--==============================================================================
begin

  ------------------------------------------------------------------------------
  -- Status output assignment
  ------------------------------------------------------------------------------
  status_o(0)           <= p2l_pll_locked;
  status_o(31 downto 1) <= (others => '0');

  ------------------------------------------------------------------------------
  -- Clock Input. Generate ioclocks and system clock via BUFPLL
  ------------------------------------------------------------------------------
  cmp_clk_in : entity work.serdes_1_to_n_clk_pll_s2_diff
    generic map(
      CLKIN_PERIOD => 5.000,
      PLLD         => 1,
      PLLX         => 2,
      S            => 2,
      BS           => false)
    port map (
      clkin_p         => p2l_clk_p_i,
      clkin_n         => p2l_clk_n_i,
      rxioclk         => io_clk,
      pattern1        => "10",
      pattern2        => "10",
      rx_serdesstrobe => serdes_strobe,
      rx_bufg_pll_x1  => sys_clk,
      bitslip         => open,
      reset           => arst_pll,
      datain          => open,
      rx_bufpll_lckd  => p2l_pll_locked) ;

  ------------------------------------------------------------------------------
  -- Reset aligned to core clock
  ------------------------------------------------------------------------------

  cmp_core_rst_sync: gc_sync_ffs
    port map (
      clk_i    => sys_clk,
      rst_n_i  => rst_n_a_i,
      data_i   => p2l_pll_locked,
      synced_o => sys_rst_n);

  -- Always active high reset for PLL and SERDES
  arst_pll <= not(rst_n_a_i);

  ------------------------------------------------------------------------------
  -- IRQ pulse forward to GN4124 GPIO
  ------------------------------------------------------------------------------
  irq_p_o <= irq_p_i;

  --============================================================================
  -- P2L DataPath
  --============================================================================

  -----------------------------------------------------------------------------
  -- p2l_des: Deserialize the P2L DDR inputs
  -----------------------------------------------------------------------------
  cmp_p2l_des : entity work.p2l_des
    port map
    (
      ---------------------------------------------------------
      -- Clocks and reset
      rst_a_i         => arst_pll,
      sys_clk_i       => sys_clk,
      io_clk_i        => io_clk,
      serdes_strobe_i => serdes_strobe,

      ---------------------------------------------------------
      -- P2L DDR inputs
      p2l_valid_i  => p2l_valid_i,
      p2l_dframe_i => p2l_dframe_i,
      p2l_data_i   => p2l_data_i,

      ---------------------------------------------------------
      -- P2L SDR outputs
      p2l_valid_o  => des_pd_valid,
      p2l_dframe_o => des_pd_dframe,
      p2l_data_o   => des_pd_data
      );

  ------------------------------------------------------------------------------
  -- P2L local bus control signals
  ------------------------------------------------------------------------------
  -- de-asserted to pause transfer from GN4124
  p2l_rdy_o <= p2l_rdy_wbm and p2l_rdy_pdm;

  -----------------------------------------------------------------------------
  -- p2l_decode32: Decode the output of the p2l_des
  -----------------------------------------------------------------------------
  cmp_p2l_decode32 : entity work.p2l_decode32
    port map
    (
      ---------------------------------------------------------
      -- Clock/Reset
      clk_i   => sys_clk,
      rst_n_i => sys_rst_n,

      ---------------------------------------------------------
      -- Input from the Deserializer
      --
      des_p2l_valid_i  => des_pd_valid,
      des_p2l_dframe_i => des_pd_dframe,
      des_p2l_data_i   => des_pd_data,

      ---------------------------------------------------------
      -- Decoder Outputs
      --
      -- Header
      p2l_hdr_start_o   => p2l_hdr_start,
      p2l_hdr_length_o  => p2l_hdr_length,
      p2l_hdr_cid_o     => p2l_hdr_cid,
      p2l_hdr_last_o    => p2l_hdr_last,
      p2l_hdr_stat_o    => p2l_hdr_stat,
      p2l_target_mrd_o  => p2l_target_mrd,
      p2l_target_mwr_o  => p2l_target_mwr,
      p2l_master_cpld_o => p2l_master_cpld,
      p2l_master_cpln_o => p2l_master_cpln,
      --
      -- Address
      p2l_addr_start_o  => p2l_addr_start,
      p2l_addr_o        => p2l_addr,
      --
      -- Data
      p2l_d_valid_o     => p2l_d_valid,
      p2l_d_last_o      => p2l_d_last,
      p2l_d_o           => p2l_d,
      p2l_be_o          => p2l_be
      );


  --===========================================================================
  -- Core Logic Blocks
  --===========================================================================

  -----------------------------------------------------------------------------
  -- Wishbone master
  -----------------------------------------------------------------------------
  cmp_wbmaster32 : entity work.wbmaster32
    generic map(
      g_ACK_TIMEOUT => g_ACK_TIMEOUT
      )
    port map
    (
      ---------------------------------------------------------
      -- Clock/Reset
      clk_i   => sys_clk,
      rst_n_i => sys_rst_n,

      ---------------------------------------------------------
      -- From P2L Decoder
      --
      -- Header
      pd_wbm_hdr_start_i  => p2l_hdr_start,
      pd_wbm_hdr_length_i => p2l_hdr_length,
      pd_wbm_hdr_cid_i    => p2l_hdr_cid,
      pd_wbm_target_mrd_i => p2l_target_mrd,
      pd_wbm_target_mwr_i => p2l_target_mwr,
      --
      -- Address
      pd_wbm_addr_start_i => p2l_addr_start,
      pd_wbm_addr_i       => p2l_addr,
      --
      -- Data
      pd_wbm_data_valid_i => p2l_d_valid,
      pd_wbm_data_last_i  => p2l_d_last,
      pd_wbm_data_i       => p2l_d,
      pd_wbm_be_i         => p2l_be,

      ---------------------------------------------------------
      -- P2L Control
      p_wr_rdy_o   => p_wr_rdy_o,
      p2l_rdy_o    => p2l_rdy_wbm,
      p_rd_d_rdy_i => p_rd_d_rdy,

      ---------------------------------------------------------
      -- To the L2P Interface
      wbm_arb_valid_o  => wbm_arb_valid,
      wbm_arb_dframe_o => wbm_arb_dframe,
      wbm_arb_data_o   => wbm_arb_data,
      wbm_arb_req_o    => wbm_arb_req,
      arb_wbm_gnt_i    => arb_wbm_gnt,

      ---------------------------------------------------------
      -- Wishbone Interface
      wb_rst_n_i => csr_rst_n_i,
      wb_clk_i   => csr_clk_i,
      wb_adr_o   => csr_adr,
      wb_dat_i   => csr_dat_i,
      wb_dat_o   => csr_dat_o,
      wb_sel_o   => csr_sel_o,
      wb_cyc_o   => csr_cyc_o,
      wb_stb_o   => csr_stb_o,
      wb_we_o    => csr_we_o,
      wb_ack_i   => csr_ack_i,
      wb_stall_i => csr_stall_i,
      wb_err_i   => csr_err_i,
      wb_rty_i   => csr_rty_i
      );

  -- Adapt address bus width for top level
  csr_adr_o <= '0' & csr_adr;

  -----------------------------------------------------------------------------
  -- DMA controller
  -----------------------------------------------------------------------------
  cmp_dma_controller : entity work.dma_controller
    port map
    (
      clk_i   => sys_clk,
      rst_n_i => sys_rst_n,

      dma_ctrl_irq_o => dma_irq,

      dma_ctrl_carrier_addr_o => dma_ctrl_carrier_addr,
      dma_ctrl_host_addr_h_o  => dma_ctrl_host_addr_h,
      dma_ctrl_host_addr_l_o  => dma_ctrl_host_addr_l,
      dma_ctrl_len_o          => dma_ctrl_len,
      dma_ctrl_start_l2p_o    => dma_ctrl_start_l2p,
      dma_ctrl_start_p2l_o    => dma_ctrl_start_p2l,
      dma_ctrl_start_next_o   => dma_ctrl_start_next,
      dma_ctrl_done_i         => dma_ctrl_done,
      dma_ctrl_error_i        => dma_ctrl_error,
      dma_ctrl_byte_swap_o    => dma_ctrl_byte_swap,
      dma_ctrl_abort_o        => dma_ctrl_abort,

      next_item_carrier_addr_i => next_item_carrier_addr,
      next_item_host_addr_h_i  => next_item_host_addr_h,
      next_item_host_addr_l_i  => next_item_host_addr_l,
      next_item_len_i          => next_item_len,
      next_item_next_l_i       => next_item_next_l,
      next_item_next_h_i       => next_item_next_h,
      next_item_attrib_i       => next_item_attrib,
      next_item_valid_i        => next_item_valid,

      wb_rst_n_i => dma_reg_rst_n_i,
      wb_clk_i   => dma_reg_clk_i,
      wb_adr_i   => dma_reg_adr_i(3 downto 0),
      wb_dat_o   => dma_reg_dat_o,
      wb_dat_i   => dma_reg_dat_i,
      wb_sel_i   => dma_reg_sel_i,
      wb_cyc_i   => dma_reg_cyc_i,
      wb_stb_i   => dma_reg_stb_i,
      wb_we_i    => dma_reg_we_i,
      wb_ack_o   => dma_reg_ack_o
      );

  -- DMA registers is a classic wishbone slave supporting single pipelined cycles
  dma_reg_stall_o <= '0';

  -- Status signals from DMA masters
  dma_ctrl_done  <= dma_ctrl_l2p_done or dma_ctrl_p2l_done;
  dma_ctrl_error <= dma_ctrl_l2p_error or dma_ctrl_p2l_error;

  -- Synchronise DMA IRQ pulse to csr_clk_i clock domain
  l_dma_irq_sync : for I in 0 to dma_irq'length-1 generate
    cmp_dma_irq_sync : gc_pulse_synchronizer2
      port map(
        clk_in_i    => sys_clk,
        rst_in_n_i  => sys_rst_n,
        clk_out_i   => csr_clk_i,
        rst_out_n_i => csr_rst_n_i,
        d_p_i       => dma_irq(I),
        d_ready_o   => open,
        q_p_o       => dma_irq_o(I)
        );
  end generate l_dma_irq_sync;

  -----------------------------------------------------------------------------
  -- L2P DMA master
  -----------------------------------------------------------------------------
  cmp_l2p_dma_master : entity work.l2p_dma_master
    port map
    (
      clk_i   => sys_clk,
      rst_n_i => sys_rst_n,

      dma_ctrl_target_addr_i => dma_ctrl_carrier_addr,
      dma_ctrl_host_addr_h_i => dma_ctrl_host_addr_h,
      dma_ctrl_host_addr_l_i => dma_ctrl_host_addr_l,
      dma_ctrl_len_i         => dma_ctrl_len,
      dma_ctrl_start_l2p_i   => dma_ctrl_start_l2p,
      dma_ctrl_done_o        => dma_ctrl_l2p_done,
      dma_ctrl_error_o       => dma_ctrl_l2p_error,
      dma_ctrl_byte_swap_i   => dma_ctrl_byte_swap,
      dma_ctrl_abort_i       => dma_ctrl_abort,

      ldm_arb_valid_o  => ldm_arb_valid,
      ldm_arb_dframe_o => ldm_arb_dframe,
      ldm_arb_data_o   => ldm_arb_data,
      ldm_arb_req_o    => ldm_arb_req,
      arb_ldm_gnt_i    => arb_ldm_gnt,

      l2p_edb_o  => l2p_edb,
      l_wr_rdy_i => l_wr_rdy,
      l2p_rdy_i  => l2p_rdy,
      tx_error_i => tx_error,

      l2p_dma_rst_n_i => dma_rst_n_i,
      l2p_dma_clk_i   => dma_clk_i,
      l2p_dma_adr_o   => l2p_dma_adr,
      l2p_dma_dat_i   => l2p_dma_dat_s2m,
      l2p_dma_dat_o   => l2p_dma_dat_m2s,
      l2p_dma_sel_o   => l2p_dma_sel,
      l2p_dma_cyc_o   => l2p_dma_cyc,
      l2p_dma_stb_o   => l2p_dma_stb,
      l2p_dma_we_o    => l2p_dma_we,
      l2p_dma_ack_i   => l2p_dma_ack,
      l2p_dma_stall_i => l2p_dma_stall,
      p2l_dma_cyc_i   => p2l_dma_cyc
      );

  -----------------------------------------------------------------------------
  -- P2L DMA  master
  -----------------------------------------------------------------------------
  cmp_p2l_dma_master : entity work.p2l_dma_master
    port map
    (
      clk_i   => sys_clk,
      rst_n_i => sys_rst_n,

      dma_ctrl_carrier_addr_i => dma_ctrl_carrier_addr,
      dma_ctrl_host_addr_h_i  => dma_ctrl_host_addr_h,
      dma_ctrl_host_addr_l_i  => dma_ctrl_host_addr_l,
      dma_ctrl_len_i          => dma_ctrl_len,
      dma_ctrl_start_p2l_i    => dma_ctrl_start_p2l,
      dma_ctrl_start_next_i   => dma_ctrl_start_next,
      dma_ctrl_done_o         => dma_ctrl_p2l_done,
      dma_ctrl_error_o        => dma_ctrl_p2l_error,
      dma_ctrl_byte_swap_i    => dma_ctrl_byte_swap,
      dma_ctrl_abort_i        => dma_ctrl_abort,

      pd_pdm_hdr_start_i   => p2l_hdr_start,
      pd_pdm_hdr_length_i  => p2l_hdr_length,
      pd_pdm_hdr_cid_i     => p2l_hdr_cid,
      pd_pdm_master_cpld_i => p2l_master_cpld,
      pd_pdm_master_cpln_i => p2l_master_cpln,

      pd_pdm_data_valid_i => p2l_d_valid,
      pd_pdm_data_last_i  => p2l_d_last,
      pd_pdm_data_i       => p2l_d,
      pd_pdm_be_i         => p2l_be,

      p2l_rdy_o  => p2l_rdy_pdm,
      rx_error_o => rx_error_o,

      pdm_arb_valid_o  => pdm_arb_valid,
      pdm_arb_dframe_o => pdm_arb_dframe,
      pdm_arb_data_o   => pdm_arb_data,
      pdm_arb_req_o    => pdm_arb_req,
      arb_pdm_gnt_i    => arb_pdm_gnt,

      p2l_dma_rst_n_i => dma_rst_n_i,
      p2l_dma_clk_i   => dma_clk_i,
      p2l_dma_adr_o   => p2l_dma_adr,
      p2l_dma_dat_i   => p2l_dma_dat_s2m,
      p2l_dma_dat_o   => p2l_dma_dat_m2s,
      p2l_dma_sel_o   => p2l_dma_sel,
      p2l_dma_cyc_o   => p2l_dma_cyc,
      p2l_dma_stb_o   => p2l_dma_stb,
      p2l_dma_we_o    => p2l_dma_we,
      p2l_dma_ack_i   => p2l_dma_ack,
      p2l_dma_stall_i => p2l_dma_stall,
      l2p_dma_cyc_i   => l2p_dma_cyc,

      next_item_carrier_addr_o => next_item_carrier_addr,
      next_item_host_addr_h_o  => next_item_host_addr_h,
      next_item_host_addr_l_o  => next_item_host_addr_l,
      next_item_len_o          => next_item_len,
      next_item_next_l_o       => next_item_next_l,
      next_item_next_h_o       => next_item_next_h,
      next_item_attrib_o       => next_item_attrib,
      next_item_valid_o        => next_item_valid
      );

  p_dma_wb_mux : process (l2p_dma_adr, l2p_dma_cyc, l2p_dma_dat_m2s,
                          l2p_dma_sel, l2p_dma_stb, l2p_dma_we, p2l_dma_adr,
                          p2l_dma_cyc, p2l_dma_dat_m2s, p2l_dma_sel,
                          p2l_dma_stb, p2l_dma_we)
  begin
    if (l2p_dma_cyc = '1') then
      dma_adr_o <= l2p_dma_adr;
      dma_dat_o <= l2p_dma_dat_m2s;
      dma_sel_o <= l2p_dma_sel;
      dma_cyc_o <= l2p_dma_cyc;
      dma_stb_o <= l2p_dma_stb;
      dma_we_o  <= l2p_dma_we;
    elsif (p2l_dma_cyc = '1') then
      dma_adr_o <= p2l_dma_adr;
      dma_dat_o <= p2l_dma_dat_m2s;
      dma_sel_o <= p2l_dma_sel;
      dma_cyc_o <= p2l_dma_cyc;
      dma_stb_o <= p2l_dma_stb;
      dma_we_o  <= p2l_dma_we;
    else
      dma_adr_o <= (others => '0');
      dma_dat_o <= (others => '0');
      dma_sel_o <= (others => '0');
      dma_cyc_o <= '0';
      dma_stb_o <= '0';
      dma_we_o  <= '0';
    end if;
  end process p_dma_wb_mux;

  l2p_dma_dat_s2m <= dma_dat_i;
  p2l_dma_dat_s2m <= dma_dat_i;
  l2p_dma_ack     <= dma_ack_i;
  p2l_dma_ack     <= dma_ack_i;
  l2p_dma_stall   <= dma_stall_i;
  p2l_dma_stall   <= dma_stall_i;


  --===========================================================================
  -- L2P DataPath
  --===========================================================================

  -----------------------------------------------------------------------------
  -- Resync GN412x L2P status signals
  -----------------------------------------------------------------------------

  -- must be checked before l2p_dma_master issues a master write.
  -- l2p_dma_master only checks if the signal equals "11", so it is safe to
  -- use an AND gate and resync a single bit.
  l_wr_rdy_t <= l_wr_rdy_i(1) and l_wr_rdy_i(0);
  cmp_sync_l_wr_rdy : gc_sync_ffs
    port map (
      clk_i    => sys_clk,
      rst_n_i  => sys_rst_n,
      data_i   => l_wr_rdy_t,
      synced_o => l_wr_rdy);

  -- must be checked before wbmaster32 sends read completion with data
  -- wbmaster32 only checks if the signal equals "11", so it is safe to
  -- use an AND gate and resync a single bit.
  p_rd_d_rdy_t <= p_rd_d_rdy_i(1) and p_rd_d_rdy_i(0);
  cmp_sync_p_rd_d_rdy : gc_sync_ffs
    port map (
      clk_i    => sys_clk,
      rst_n_i  => sys_rst_n,
      data_i   => p_rd_d_rdy_t,
      synced_o => p_rd_d_rdy);

  -- when de-asserted, l2p_dma_master must stop sending data
  -- (de-assert l2p_valid) within 3 (or 7 ?) clock cycles
  cmp_sync_l2p_rdy : gc_sync_ffs
    port map (
      clk_i    => sys_clk,
      rst_n_i  => sys_rst_n,
      data_i   => l2p_rdy_i,
      synced_o => l2p_rdy);

  -- when asserted, stop dma transfer. Should never be asserted
  -- under normal operation conditions!
  cmp_sync_tx_error : gc_sync_ffs
    port map (
      clk_i    => sys_clk,
      rst_n_i  => sys_rst_n,
      data_i   => tx_error_i,
      synced_o => tx_error);

  -- assert when packet badly ends (e.g. dma abort)
  -- delay output by 3 cycles
  -- NOTE: this was here before the rehauling of resets and synchronizers.
  -- l2p_edb is driven by sys_clk, no need to resync. I left it in order
  -- to preserve the sequencing of the outputs. Not sure if it is needed.
  p_l2p_edb_d3 : process (sys_clk) is
  begin
    if rising_edge(sys_clk) then
      if sys_rst_n = '0' then
        l2p_edb_d1 <= '0';
        l2p_edb_d2 <= '0';
      else
        l2p_edb_d1 <= l2p_edb;
        l2p_edb_d2 <= l2p_edb_d1;
        l2p_edb_o  <= l2p_edb_d2;
      end if;
    end if;
  end process p_l2p_edb_d3;

  -----------------------------------------------------------------------------
  -- L2P arbiter, arbitrates access to GN4124
  -----------------------------------------------------------------------------
  cmp_l2p_arbiter : entity work.l2p_arbiter
    port map
    (
      ---------------------------------------------------------
      -- Clock/Reset
      clk_i   => sys_clk,
      rst_n_i => sys_rst_n,

      ---------------------------------------------------------
      -- From Wishbone master (wbm) to arbiter (arb)
      wbm_arb_valid_i  => wbm_arb_valid,
      wbm_arb_dframe_i => wbm_arb_dframe,
      wbm_arb_data_i   => wbm_arb_data,
      wbm_arb_req_i    => wbm_arb_req,
      arb_wbm_gnt_o    => arb_wbm_gnt,

      ---------------------------------------------------------
      -- From DMA controller (pdm) to arbiter (arb)
      pdm_arb_valid_i  => pdm_arb_valid,
      pdm_arb_dframe_i => pdm_arb_dframe,
      pdm_arb_data_i   => pdm_arb_data,
      pdm_arb_req_i    => pdm_arb_req,
      arb_pdm_gnt_o    => arb_pdm_gnt,

      ---------------------------------------------------------
      -- From L2P DMA master (ldm) to arbiter (arb)
      ldm_arb_valid_i  => ldm_arb_valid,
      ldm_arb_dframe_i => ldm_arb_dframe,
      ldm_arb_data_i   => ldm_arb_data,
      ldm_arb_req_i    => ldm_arb_req,
      arb_ldm_gnt_o    => arb_ldm_gnt,

      ---------------------------------------------------------
      -- From arbiter (arb) to serializer (ser)
      arb_ser_valid_o  => arb_ser_valid,
      arb_ser_dframe_o => arb_ser_dframe,
      arb_ser_data_o   => arb_ser_data
      );



  -----------------------------------------------------------------------------
  -- L2P_SER: Generate the L2P DDR Outputs
  -----------------------------------------------------------------------------
  cmp_l2p_ser : entity work.l2p_ser
    port map
    (
      ---------------------------------------------------------
      -- Clocks and reset
      rst_a_i         => arst_pll,
      sys_clk_i       => sys_clk,
      io_clk_i        => io_clk,
      serdes_strobe_i => serdes_strobe,

      ---------------------------------------------------------
      -- L2P SDR inputs
      l2p_valid_i  => arb_ser_valid,
      l2p_dframe_i => arb_ser_dframe,
      l2p_data_i   => arb_ser_data,

      ---------------------------------------------------------
      -- L2P DDR outputs
      l2p_clk_p_o  => l2p_clk_p_o,
      l2p_clk_n_o  => l2p_clk_n_o,
      l2p_valid_o  => l2p_valid_o,
      l2p_dframe_o => l2p_dframe_o,
      l2p_data_o   => l2p_data_o
      );


end rtl;
--==============================================================================
-- Architecture end (gn4124_core)
--==============================================================================

