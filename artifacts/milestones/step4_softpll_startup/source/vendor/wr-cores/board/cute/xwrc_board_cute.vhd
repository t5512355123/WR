-------------------------------------------------------------------------------
-- Title      : WRPC Wrapper for CUTE
-- Project    : WR PTP Core
-- URL        : http://www.ohwr.org/projects/wr-cores/wiki/Wrpc_core
-------------------------------------------------------------------------------
-- File       : xwrc_board_cute.vhd
-- Author(s)  : Hongming Li <lihm.thu@foxmail.com>, Greg Daniluk <grzegorz.daniluk@cern.ch>
-- Company    : Tsinghua Univ. (DEP), CERN
-- Standard   : VHDL'93
-------------------------------------------------------------------------------
-- Description: Top-level wrapper for WR PTP core including all the modules
-- needed to operate the core on the CUTE board.
-------------------------------------------------------------------------------
-- Copyright (c) 2017 CERN
-------------------------------------------------------------------------------
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
use ieee.numeric_std.all;

library work;
use work.gencores_pkg.all;
use work.wrcore_pkg.all;
use work.wishbone_pkg.all;
use work.wr_fabric_pkg.all;
use work.endpoint_pkg.all;
use work.streamers_pkg.all;
use work.wr_xilinx_pkg.all;
use work.wr_board_pkg.all;
use work.wr_cute_pkg.all;

library unisim;
use unisim.vcomponents.all;

entity xwrc_board_cute is
  generic(
    -- set to 1 to speed up some initialization processes during simulation
    g_simulation                : integer              := 0;
    -- Select whether to include external ref clock input
    g_with_external_clock_input : boolean              := false;
    -- Number of aux clocks syntonized by WRPC to WR timebase
    g_aux_clks                  : integer              := 0;
    -- plain     = expose WRC fabric interface
    -- streamers = attach WRC streamers to fabric interface
    -- etherbone = attach Etherbone slave to fabric interface
    g_fabric_iface              : t_board_fabric_iface := plain;
    -- parameters configuration when g_fabric_iface = "streamers" (otherwise ignored)
    g_streamers_op_mode        : t_streamers_op_mode  := TX_AND_RX;
    g_tx_streamer_params       : t_tx_streamer_params := c_tx_streamer_params_defaut;
    g_rx_streamer_params       : t_rx_streamer_params := c_rx_streamer_params_defaut;
    g_aux_sdb                   : t_sdb_device         := c_wrc_periph3_sdb;
    -- memory initialisation file for embedded CPU
    g_dpram_initf               : string               := "default_xilinx";
    -- identification (id and ver) of the layout of words in the generic diag interface
    g_diag_id                   : integer              := 0;
    g_diag_ver                  : integer              := 0;
    -- size the generic diag interface
    g_diag_ro_size              : integer              := 0;
    g_diag_rw_size              : integer              := 0;
    ---------------------------------------------------------------------------
    -- cute special
    ---------------------------------------------------------------------------
    g_cute_version              : string               := "2.2";
    g_sfp0_enable               : integer              := 1;
    g_sfp1_enable               : integer              := 0;
    g_phy_refclk_sel            : integer              := 0;
    g_multiboot_enable          : boolean              := false
    );
  port (
    ---------------------------------------------------------------------------
    -- Clocks/resets
    ---------------------------------------------------------------------------
    -- Reset input (active low, can be async)
    areset_n_i          : in  std_logic;
    -- Optional reset input active low with rising edge detection. Does not
    -- reset PLLs.
    areset_edge_n_i     : in  std_logic := '1';
    -- Clock inputs from the board
    clk_20m_vcxo_i      : in  std_logic;
    clk_125m_pllref_p_i : in  std_logic;
    clk_125m_pllref_n_i : in  std_logic;
    clk_125m_gtp0_p_i   : in  std_logic :='0';
    clk_125m_gtp0_n_i   : in  std_logic :='0';
    clk_125m_gtp1_p_i   : in  std_logic :='0';
    clk_125m_gtp1_n_i   : in  std_logic :='0';
    -- Aux clocks, which can be disciplined by the WR Core
    clk_aux_i           : in  std_logic_vector(g_aux_clks-1 downto 0) := (others => '0');
    -- 10MHz ext ref clock input (g_with_external_clock_input = TRUE)
    clk_10m_ext_i       : in  std_logic                               := '0';
    -- External PPS input (g_with_external_clock_input = TRUE)
    pps_ext_i           : in  std_logic                               := '0';
    -- 62.5MHz sys clock output
    clk_sys_62m5_o      : out std_logic;
    -- 125MHz ref clock output
    clk_ref_125m_o      : out std_logic;
    -- 10MHz ext clock output
    clk_10m_ext_o       : out std_logic;
    -- active low reset outputs, synchronous to 62m5 and 125m clocks
    rst_sys_62m5_n_o    : out std_logic;
    rst_ref_125m_n_o    : out std_logic;

    ---------------------------------------------------------------------------
    -- SPI interface to DACs
    ---------------------------------------------------------------------------
    plldac_sclk_o   : out std_logic;
    plldac_din_o    : out std_logic;
    plldac_clr_n_o  : out std_logic;
    plldac_load_n_o : out std_logic;
    plldac_sync_n_o : out std_logic;

    ---------------------------------------------------------------------------
    -- SFP I/O for transceiver and SFP management info
    ---------------------------------------------------------------------------
    sfp0_txp_o         : out std_logic;
    sfp0_txn_o         : out std_logic;
    sfp0_rxp_i         : in  std_logic := '0';
    sfp0_rxn_i         : in  std_logic := '0';
    sfp0_det_i         : in  std_logic := '1';
    sfp0_sda_i         : in  std_logic := '1';
    sfp0_sda_o         : out std_logic;
    sfp0_scl_i         : in  std_logic := '1';
    sfp0_scl_o         : out std_logic;
    sfp0_rate_select_o : out std_logic;
    sfp0_tx_fault_i    : in  std_logic := '0';
    sfp0_tx_disable_o  : out std_logic;
    sfp0_los_i         : in  std_logic := '0';

    sfp1_txp_o         : out std_logic;
    sfp1_txn_o         : out std_logic;
    sfp1_rxp_i         : in  std_logic := '0';
    sfp1_rxn_i         : in  std_logic := '0';
    sfp1_det_i         : in  std_logic := '1';
    sfp1_sda_i         : in  std_logic := '1';
    sfp1_sda_o         : out std_logic;
    sfp1_scl_i         : in  std_logic := '1';
    sfp1_scl_o         : out std_logic;
    sfp1_rate_select_o : out std_logic;
    sfp1_tx_fault_i    : in  std_logic := '0';
    sfp1_tx_disable_o  : out std_logic;
    sfp1_los_i         : in  std_logic := '0';

    ---------------------------------------------------------------------------
    -- I2C EEPROM
    ---------------------------------------------------------------------------
    eeprom_sda_i : in  std_logic;
    eeprom_sda_o : out std_logic;
    eeprom_scl_i : in  std_logic;
    eeprom_scl_o : out std_logic;

    ---------------------------------------------------------------------------
    -- Onewire interface
    ---------------------------------------------------------------------------
    onewire_i     : in  std_logic;
    onewire_oen_o : out std_logic;

    ---------------------------------------------------------------------------
    -- UART
    ---------------------------------------------------------------------------
    uart_rxd_i : in  std_logic;
    uart_txd_o : out std_logic;

    ---------------------------------------------------------------------------
    -- Flash memory SPI interface
    ---------------------------------------------------------------------------
    flash_sclk_o : out std_logic;
    flash_ncs_o  : out std_logic;
    flash_mosi_o : out std_logic;
    flash_miso_i : in  std_logic;

    ---------------------------------------------------------------------------
    -- External WB interface
    ---------------------------------------------------------------------------
    wb_slave_o : out t_wishbone_slave_out;
    wb_slave_i : in  t_wishbone_slave_in := cc_dummy_slave_in;

    aux_master_o : out t_wishbone_master_out;
    aux_master_i : in  t_wishbone_master_in := cc_dummy_master_in;

    ---------------------------------------------------------------------------
    -- WR fabric interface (when g_fabric_iface = "plainfbrc")
    ---------------------------------------------------------------------------
    wrf_src_o : out t_wrf_source_out;
    wrf_src_i : in  t_wrf_source_in := c_dummy_src_in;
    wrf_snk_o : out t_wrf_sink_out;
    wrf_snk_i : in  t_wrf_sink_in   := c_dummy_snk_in;

    ---------------------------------------------------------------------------
    -- WR streamers (when g_fabric_iface = "streamers")
    ---------------------------------------------------------------------------
    wrs_tx_data_i  : in  std_logic_vector(g_tx_streamer_params.data_width-1 downto 0) := (others => '0');
    wrs_tx_valid_i : in  std_logic                                        := '0';
    wrs_tx_dreq_o  : out std_logic;
    wrs_tx_last_i  : in  std_logic                                        := '1';
    wrs_tx_flush_i : in  std_logic                                        := '0';
    wrs_tx_cfg_i   : in  t_tx_streamer_cfg                                := c_tx_streamer_cfg_default;
    wrs_rx_first_o : out std_logic;
    wrs_rx_last_o  : out std_logic;
    wrs_rx_data_o  : out std_logic_vector(g_rx_streamer_params.data_width-1 downto 0);
    wrs_rx_valid_o : out std_logic;
    wrs_rx_dreq_i  : in  std_logic                                        := '0';
    wrs_rx_cfg_i   : in t_rx_streamer_cfg                                 := c_rx_streamer_cfg_default;
    ---------------------------------------------------------------------------
    -- Etherbone WB master interface (when g_fabric_iface = "etherbone")
    ---------------------------------------------------------------------------
    wb_eth_master_o : out t_wishbone_master_out;
    wb_eth_master_i : in  t_wishbone_master_in := cc_dummy_master_in;

    ---------------------------------------------------------------------------
    -- Generic diagnostics interface (access from WRPC via SNMP or uart console
    ---------------------------------------------------------------------------
    aux_diag_i : in  t_generic_word_array(g_diag_ro_size-1 downto 0) := (others => (others => '0'));
    aux_diag_o : out t_generic_word_array(g_diag_rw_size-1 downto 0);

    ---------------------------------------------------------------------------
    -- Aux clocks control
    ---------------------------------------------------------------------------
    tm_dac_value_o       : out std_logic_vector(31 downto 0);
    tm_dac_wr_o          : out std_logic_vector(g_aux_clks-1 downto 0);
    tm_clk_aux_lock_en_i : in  std_logic_vector(g_aux_clks-1 downto 0) := (others => '0');
    tm_clk_aux_locked_o  : out std_logic_vector(g_aux_clks-1 downto 0);

    ---------------------------------------------------------------------------
    -- External Tx Timestamping I/F
    ---------------------------------------------------------------------------
    timestamps_o     : out t_txtsu_timestamp;
    timestamps_ack_i : in  std_logic := '1';

    -----------------------------------------
    -- Timestamp helper signals, used for Absolute Calibration
    -----------------------------------------
    abscal_txts_o       : out std_logic;
    abscal_rxts_o       : out std_logic;

    ---------------------------------------------------------------------------
    -- Pause Frame Control
    ---------------------------------------------------------------------------
    fc_tx_pause_req_i   : in  std_logic                     := '0';
    fc_tx_pause_delay_i : in  std_logic_vector(15 downto 0) := x"0000";
    fc_tx_pause_ready_o : out std_logic;

    ---------------------------------------------------------------------------
    -- Timecode I/F
    ---------------------------------------------------------------------------
    tm_link_up_o    : out std_logic;
    tm_time_valid_o : out std_logic;
    tm_tai_o        : out std_logic_vector(39 downto 0);
    tm_cycles_o     : out std_logic_vector(27 downto 0);

    ---------------------------------------------------------------------------
    -- Buttons, LEDs and PPS output
    ---------------------------------------------------------------------------
    led_act_o  : out std_logic;
    led_link_o : out std_logic;
    btn1_i     : in  std_logic := '1';
    btn2_i     : in  std_logic := '1';
    -- 1PPS output
    pps_p_o    : out std_logic;
    pps_led_o  : out std_logic;
    pps_csync_o: out std_logic;
    -- Link ok indication
    link_ok_o  : out std_logic
    );

end entity xwrc_board_cute;

architecture struct of xwrc_board_cute is

------------------------------------------------------------------------------
-- components declaration
------------------------------------------------------------------------------
  component cute_serial_dac_arb is
    generic(
      g_invert_sclk    : boolean;
      g_num_extra_bits : integer);
    port(
      clk_i   : in std_logic;
      rst_n_i : in std_logic;
  
      val1_i  : in std_logic_vector(15 downto 0);
      load1_i : in std_logic;
      val2_i  : in std_logic_vector(15 downto 0);
      load2_i : in std_logic;
  
      dac_ldac_n_o : out std_logic;
      dac_clr_n_o  : out std_logic;
      dac_sync_n_o : out std_logic;
      dac_sclk_o   : out std_logic;
      dac_din_o    : out std_logic);
  end component cute_serial_dac_arb;

  component oserdes_4_to_1 is
    generic(
      sys_w : integer := 1;
      dev_w : integer := 4); 
    port(
      data_out_from_device : in  std_logic_vector(dev_w-1 downto 0); 
      data_out_to_pins     : out std_logic_vector(sys_w-1 downto 0); 
      delay_reset          : in  std_logic;
      clk_in     : in std_logic;
      pll_locked : in std_logic;
      clk_div_in : in std_logic;
      io_reset   : in std_logic);
  end component;

  -----------------------------------------------------------------------------
  -- Signals
  -----------------------------------------------------------------------------
  constant c_AUX_500M_CFG : t_auxpll_cfg := (
    enabled  => TRUE,
    bufg_en  => FALSE,
    divide   => 2);
  constant c_AUX_CFG_ARRAY : t_auxpll_cfg_array := (0=>c_AUX_500M_CFG, others=>c_AUXPLL_CFG_DEFAULT);

  -- IBUFDS
  signal clk_125m_pllref_buf : std_logic;

  -- PLLs, clocks
  signal clk_125m_gtp_p : std_logic;
  signal clk_125m_gtp_n : std_logic;
  signal clk_pll_62m5 : std_logic;
  signal clk_pll_125m : std_logic;
  signal clk_pll_20m  : std_logic;
  signal clk_pll_dmtd : std_logic;
  signal pll_locked   : std_logic;
  signal clk_10m_ext  : std_logic;
  signal clk_pll_aux_out : std_logic_vector(3 downto 0);

  -- Reset logic
  signal areset_edge_ppulse : std_logic;
  signal rst_62m5_n         : std_logic;
  signal rstlogic_arst_n    : std_logic;
  signal rstlogic_clk_in    : std_logic_vector(1 downto 0);
  signal rstlogic_rst_out   : std_logic_vector(1 downto 0);

  -- PLL DAC ARB
  signal dac_hpll_load_p1 : std_logic;
  signal dac_hpll_data    : std_logic_vector(15 downto 0);
  signal dac_dpll_load_p1 : std_logic;
  signal dac_dpll_data    : std_logic_vector(15 downto 0);
  signal dac_val1_data    : std_logic_vector(15 downto 0);
  signal dac_val2_data    : std_logic_vector(15 downto 0);
  signal dac_val1_load    : std_logic;
  signal dac_val2_load    : std_logic;

  -- OneWire
  signal onewire_in : std_logic_vector(1 downto 0);
  signal onewire_en : std_logic_vector(1 downto 0);

  -- PHY
  signal phy8_to_wrc   : t_phy_8bits_to_wrc;
  signal phy8_from_wrc : t_phy_8bits_from_wrc;

  -- External reference
  signal ext_ref_mul         : std_logic;
  signal ext_ref_mul_locked  : std_logic;
  signal ext_ref_mul_stopped : std_logic;
  signal ext_ref_rst         : std_logic;

  -- CUTE-WR specific stuff
  signal sfp_txp_out         : std_logic;
  signal sfp_txn_out         : std_logic;
  signal sfp_rxp_in          : std_logic;
  signal sfp_rxn_in          : std_logic;
  signal sfp_det_in          : std_logic;
  signal sfp_sda_in          : std_logic;
  signal sfp_sda_out         : std_logic;
  signal sfp_scl_in          : std_logic;
  signal sfp_scl_out         : std_logic;
  signal sfp_tx_fault_in     : std_logic;
  signal sfp_tx_disable_out  : std_logic;
  signal sfp_los_in          : std_logic;

  signal tm_time_valid : std_logic;

  -- ext 10M clock output
  constant c_DATA_W   : integer := 4;  -- parallel data width going to serdes
  constant c_HALF     : integer := 25; -- default high/low width for 10MHz
  signal rst_oserdes  : std_logic;
  signal pll_aux_locked : std_logic;
  signal sd_out       : std_logic_vector(0 downto 0);

  signal sd_data      : std_logic_vector(c_DATA_W-1 downto 0);
  signal aux_half_high: unsigned(15 downto 0);
  signal aux_half_low : unsigned(15 downto 0);
  signal aux_shift    : unsigned(15 downto 0);
  signal clk_realign  : std_logic;
  signal tm_time_valid_d1 : std_logic;
  signal pps_csync    : std_logic;
 
  signal aux_master_out  :  t_wishbone_master_out;
  signal aux_master_in   :  t_wishbone_master_in := cc_dummy_master_in;

  signal multiboot_slave_out : t_wishbone_slave_out;
  signal multiboot_slave_in  : t_wishbone_slave_in := cc_dummy_slave_in;

  signal multiboot_wb_out  : t_wishbone_master_out;
  signal multiboot_wb_in   : t_wishbone_master_in;

  signal clk_pll_aux_locked : std_logic;

begin  -- architecture struct

  -----------------------------------------------------------------------------
  -- Platform-dependent part (PHY, PLLs, buffers, etc)
  -----------------------------------------------------------------------------

  cmp_ibufgds_pllref : IBUFGDS
    generic map (
      DIFF_TERM    => TRUE,
      IBUF_LOW_PWR => TRUE,
      IOSTANDARD   => "DEFAULT")
    port map (
      O  => clk_125m_pllref_buf,
      I  => clk_125m_pllref_p_i,
      IB => clk_125m_pllref_n_i);

  cmp_xwrc_platform : xwrc_platform_xilinx
    generic map (
      g_fpga_family               => "spartan6",
      g_with_external_clock_input => g_with_external_clock_input,
      g_use_default_plls          => TRUE,
      g_aux_pll_cfg               => c_AUX_CFG_ARRAY,
      g_gtp_enable_ch0            => 0,
      g_gtp_enable_ch1            => 1,
      g_phy_refclk_sel            => g_phy_refclk_sel,
      g_simulation                => g_simulation)
    port map (
      areset_n_i            => areset_n_i,
      clk_10m_ext_i         => clk_10m_ext_i,
      clk_20m_vcxo_i        => clk_20m_vcxo_i,
      clk_125m_pllref_i     => clk_125m_pllref_buf,
      clk_125m_gtp_p_i      => clk_125m_gtp_p,
      clk_125m_gtp_n_i      => clk_125m_gtp_n,
      sfp_txn_o             => sfp_txn_out,
      sfp_txp_o             => sfp_txp_out,
      sfp_rxn_i             => sfp_rxn_in,
      sfp_rxp_i             => sfp_rxp_in,
      sfp_tx_fault_i        => sfp_tx_fault_in,
      sfp_los_i             => sfp_los_in,
      sfp_tx_disable_o      => sfp_tx_disable_out,
      clk_pll_aux_o         => clk_pll_aux_out,
      clk_62m5_sys_o        => clk_pll_62m5,
      clk_125m_ref_o        => clk_pll_125m,
      clk_20m_o             => clk_pll_20m,
      clk_62m5_dmtd_o       => clk_pll_dmtd,
      pll_locked_o          => pll_locked,
      pll_aux_locked_o      => pll_aux_locked,
      clk_10m_ext_o         => clk_10m_ext,
      phy8_o                => phy8_to_wrc,
      phy8_i                => phy8_from_wrc,
      ext_ref_mul_o         => ext_ref_mul,
      ext_ref_mul_locked_o  => ext_ref_mul_locked,
      ext_ref_mul_stopped_o => ext_ref_mul_stopped,
      ext_ref_rst_i         => ext_ref_rst);

  clk_sys_62m5_o <= clk_pll_62m5;
  clk_ref_125m_o <= clk_pll_125m;

  -----------------------------------------------------------------------------
  -- SFP0/1 selection
  -----------------------------------------------------------------------------
  
  GEN_GTP0: if g_sfp0_enable = 1 generate
    clk_125m_gtp_p  <= clk_125m_gtp0_p_i;
    clk_125m_gtp_n  <= clk_125m_gtp0_n_i;

    sfp0_txp_o         <= sfp_txp_out;
    sfp0_txn_o         <= sfp_txn_out;
    sfp0_sda_o         <= sfp_sda_out;
    sfp0_scl_o         <= sfp_scl_out;
    sfp0_tx_disable_o  <= sfp_tx_disable_out;
    sfp_rxp_in         <= sfp0_rxp_i;
    sfp_rxn_in         <= sfp0_rxn_i;
    sfp_det_in         <= sfp0_det_i;
    sfp_sda_in         <= sfp0_sda_i;
    sfp_scl_in         <= sfp0_scl_i;
    sfp_tx_fault_in    <= sfp0_tx_fault_i;
    sfp_los_in         <= sfp0_los_i;
  end generate;

  GEN_GTP1: if g_sfp1_enable = 1 generate
    clk_125m_gtp_p <= clk_125m_gtp1_p_i;
    clk_125m_gtp_n <= clk_125m_gtp1_n_i;

    sfp1_txp_o         <= sfp_txp_out;
    sfp1_txn_o         <= sfp_txn_out;
    sfp1_sda_o         <= sfp_sda_out;
    sfp1_scl_o         <= sfp_scl_out;
    sfp1_tx_disable_o  <= sfp_tx_disable_out;
    sfp_rxp_in         <= sfp1_rxp_i;
    sfp_rxn_in         <= sfp1_rxn_i;
    sfp_det_in         <= sfp1_det_i;
    sfp_sda_in         <= sfp1_sda_i;
    sfp_scl_in         <= sfp1_scl_i;
    sfp_tx_fault_in    <= sfp1_tx_fault_i;
    sfp_los_in         <= sfp1_los_i;
  end generate;

  sfp0_rate_select_o <= '1';
  sfp1_rate_select_o <= '1';

  -----------------------------------------------------------------------------
  -- Reset logic
  -----------------------------------------------------------------------------
  -- Detect when areset_edge_n_i goes high (end of reset) and use this edge to
  -- generate rstlogic_arst_n. This is needed to connect optional reset like PCIe
  -- reset. When baord runs standalone, we need to ignore PCIe reset being
  -- constantly low.
  cmp_arst_edge: gc_sync_ffs
    generic map (
      g_sync_edge => "positive")
    port map (
      clk_i    => clk_pll_62m5,
      rst_n_i  => '1',
      data_i   => areset_edge_n_i,
      ppulse_o => areset_edge_ppulse);

  -- logic AND of all async reset sources (active low)
  rstlogic_arst_n <= pll_locked and areset_n_i and (not areset_edge_ppulse);

  -- concatenation of all clocks required to have synced resets
  rstlogic_clk_in(0) <= clk_pll_62m5;
  rstlogic_clk_in(1) <= clk_pll_125m;

  cmp_rstlogic_reset : gc_reset
    generic map (
      g_clocks    => 2,                           -- 62.5MHz, 125MHz
      g_logdelay  => 4,                           -- 16 clock cycles
      g_syncdepth => 3)                           -- length of sync chains
    port map (
      free_clk_i => clk_125m_pllref_buf,
      locked_i   => rstlogic_arst_n,
      clks_i     => rstlogic_clk_in,
      rstn_o     => rstlogic_rst_out);

  -- distribution of resets (already synchronized to their clock domains)
  rst_62m5_n <= rstlogic_rst_out(0);

  rst_sys_62m5_n_o <= rst_62m5_n;
  rst_ref_125m_n_o <= rstlogic_rst_out(1);

  -----------------------------------------------------------------------------
  -- Double-channel SPI DAC
  -----------------------------------------------------------------------------
  GEN_DAC_DEFAULT: if g_cute_version /= "2.1" generate
    dac_val1_data <= dac_dpll_data;
    dac_val1_load <= dac_dpll_load_p1;
    dac_val2_data <= dac_hpll_data;
    dac_val2_load <= dac_hpll_load_p1;
  end generate;

  GEN_DAC_CUTE_2_1: if g_cute_version = "2.1" generate
    -- Cute 2.1 had hpll and dpll DACs swapped
    dac_val1_data <= dac_hpll_data;
    dac_val1_load <= dac_hpll_load_p1;
    dac_val2_data <= dac_dpll_data;
    dac_val2_load <= dac_dpll_load_p1;
  end generate;

  cmp_dac_arb: cute_serial_dac_arb
    generic map (
      g_invert_sclk    => FALSE,
      g_num_extra_bits => 8)
    port map (
      clk_i         => clk_pll_62m5,
      rst_n_i       => rst_62m5_n,
      val1_i        => dac_val1_data,
      load1_i       => dac_val1_load,
      val2_i        => dac_val2_data,
      load2_i       => dac_val2_load,
      dac_sync_n_o  => plldac_sync_n_o,
      dac_ldac_n_o  => plldac_load_n_o,
      dac_clr_n_o   => plldac_clr_n_o,
      dac_sclk_o    => plldac_sclk_o,
      dac_din_o     => plldac_din_o);

  -----------------------------------------------------------------------------
  -- The WR PTP core with optional fabric interface attached
  -----------------------------------------------------------------------------

  cmp_board_common : xwrc_board_common
    generic map (
      g_simulation                => g_simulation,
      g_with_external_clock_input => g_with_external_clock_input,
      g_board_name                => "CUTE",
      g_ram_address_space_size_kb => 256,
      g_flash_secsz_kb            => 64,         -- sector size for M25P32
      g_flash_sdbfs_baddr         => 16#2e0000#, -- sdbfs after multiboot bitstream
      g_phys_uart                 => TRUE,
      g_virtual_uart              => TRUE,
      g_aux_clks                  => g_aux_clks,
      g_ep_rxbuf_size             => 1024,
      g_tx_runt_padding           => TRUE,
      g_dpram_initf               => g_dpram_initf,
      g_dpram_size                => 144*1024/4,
      g_interface_mode            => PIPELINED,
      g_address_granularity       => BYTE,
      g_aux_sdb                   => g_aux_sdb,
      g_softpll_enable_debugger   => FALSE,
      g_vuart_fifo_size           => 1024,
      g_pcs_16bit                 => FALSE,
      g_diag_id                   => g_diag_id,
      g_diag_ver                  => g_diag_ver,
      g_diag_ro_size              => g_diag_ro_size,
      g_diag_rw_size              => g_diag_rw_size,
      g_streamers_op_mode         => g_streamers_op_mode,
      g_tx_streamer_params        => g_tx_streamer_params,
      g_rx_streamer_params        => g_rx_streamer_params,
      g_fabric_iface              => g_fabric_iface
      )
    port map (
      clk_sys_i            => clk_pll_62m5,
      clk_dmtd_i           => clk_pll_dmtd,
      clk_ref_i            => clk_pll_125m,
      clk_aux_i            => clk_aux_i,
      clk_10m_ext_i        => clk_10m_ext,
      clk_ext_mul_i        => ext_ref_mul,
      clk_ext_mul_locked_i => ext_ref_mul_locked,
      clk_ext_stopped_i    => ext_ref_mul_stopped,
      clk_ext_rst_o        => ext_ref_rst,
      pps_ext_i            => pps_ext_i,
      rst_n_i              => rst_62m5_n,
      dac_hpll_load_p1_o   => dac_hpll_load_p1,
      dac_hpll_data_o      => dac_hpll_data,
      dac_dpll_load_p1_o   => dac_dpll_load_p1,
      dac_dpll_data_o      => dac_dpll_data,
      phy8_o               => phy8_from_wrc,
      phy8_i               => phy8_to_wrc,
      scl_o                => eeprom_scl_o,
      scl_i                => eeprom_scl_i,
      sda_o                => eeprom_sda_o,
      sda_i                => eeprom_sda_i,
      sfp_scl_o            => sfp_scl_out,
      sfp_scl_i            => sfp_scl_in,
      sfp_sda_o            => sfp_sda_out,
      sfp_sda_i            => sfp_sda_in,
      sfp_det_i            => sfp_det_in,
      spi_sclk_o           => flash_sclk_o,
      spi_ncs_o            => flash_ncs_o,
      spi_mosi_o           => flash_mosi_o,
      spi_miso_i           => flash_miso_i,
      uart_rxd_i           => uart_rxd_i,
      uart_txd_o           => uart_txd_o,
      owr_pwren_o          => open,
      owr_en_o             => onewire_en,
      owr_i                => onewire_in,
      wb_slave_i           => wb_slave_i,
      wb_slave_o           => wb_slave_o,
      aux_master_o         => aux_master_out,
      aux_master_i         => aux_master_in,
      wrf_src_o            => wrf_src_o,
      wrf_src_i            => wrf_src_i,
      wrf_snk_o            => wrf_snk_o,
      wrf_snk_i            => wrf_snk_i,
      wrs_tx_data_i        => wrs_tx_data_i,
      wrs_tx_valid_i       => wrs_tx_valid_i,
      wrs_tx_dreq_o        => wrs_tx_dreq_o,
      wrs_tx_last_i        => wrs_tx_last_i,
      wrs_tx_flush_i       => wrs_tx_flush_i,
      wrs_tx_cfg_i         => wrs_tx_cfg_i,
      wrs_rx_first_o       => wrs_rx_first_o,
      wrs_rx_last_o        => wrs_rx_last_o,
      wrs_rx_data_o        => wrs_rx_data_o,
      wrs_rx_valid_o       => wrs_rx_valid_o,
      wrs_rx_dreq_i        => wrs_rx_dreq_i,
      wrs_rx_cfg_i         => wrs_rx_cfg_i,
      wb_eth_master_o      => wb_eth_master_o,
      wb_eth_master_i      => wb_eth_master_i,
      aux_diag_i           => aux_diag_i,
      aux_diag_o           => aux_diag_o,
      tm_dac_value_o       => tm_dac_value_o,
      tm_dac_wr_o          => tm_dac_wr_o,
      tm_clk_aux_lock_en_i => tm_clk_aux_lock_en_i,
      tm_clk_aux_locked_o  => tm_clk_aux_locked_o,
      timestamps_o         => timestamps_o,
      timestamps_ack_i     => timestamps_ack_i,
      abscal_txts_o        => abscal_txts_o,
      abscal_rxts_o        => abscal_rxts_o,
      fc_tx_pause_req_i    => fc_tx_pause_req_i,
      fc_tx_pause_delay_i  => fc_tx_pause_delay_i,
      fc_tx_pause_ready_o  => fc_tx_pause_ready_o,
      tm_link_up_o         => tm_link_up_o,
      tm_time_valid_o      => tm_time_valid,
      tm_tai_o             => tm_tai_o,
      tm_cycles_o          => tm_cycles_o,
      led_act_o            => led_act_o,
      led_link_o           => led_link_o,
      btn1_i               => btn1_i,
      btn2_i               => btn2_i,
      pps_p_o              => pps_p_o,
      pps_csync_o          => pps_csync,
      pps_led_o            => pps_led_o,
      link_ok_o            => link_ok_o);

  tm_time_valid_o <= tm_time_valid;
  pps_csync_o     <= pps_csync;

  onewire_oen_o <= onewire_en(0);
  onewire_in(0) <= onewire_i;
  onewire_in(1) <= '1';

U_WRPC_MULTIBOOT: if (g_multiboot_enable = true) generate

  multiboot_slave_in   <= aux_master_out;
  aux_master_in        <= multiboot_slave_out;
  aux_master_o         <= cc_dummy_master_out;

  cmp_clock_crossing: xwb_clock_crossing
    port map (
      slave_clk_i     => clk_pll_62m5,
      slave_rst_n_i   => rst_62m5_n,
      slave_i         => multiboot_slave_in,
      slave_o         => multiboot_slave_out,
      master_clk_i    => clk_pll_20m,
      master_rst_n_i  => '1',
      master_i        => multiboot_wb_in,
      master_o        => multiboot_wb_out);

  u_multiboot: xwb_xil_multiboot
    port map (
      clk_i   => clk_pll_20m,
      rst_n_i => '1',
      wbs_i   => multiboot_wb_out,
      wbs_o   => multiboot_wb_in,
      spi_cs_n_o => open,
      spi_sclk_o => open,
      spi_mosi_o => open,
      spi_miso_i => '0');

end generate;

U_WRPC_NO_MULTIBOOT: if (g_multiboot_enable = false) generate
  aux_master_o   <= aux_master_out;
  aux_master_in  <= aux_master_i;
end generate;

  -----------------------------------------------------------------------------
  -- 10MHz output generation
  -----------------------------------------------------------------------------
  aux_half_high <= to_unsigned(c_HALF, aux_half_high'length);
  aux_half_low  <= to_unsigned(c_HALF, aux_half_low'length);
  aux_shift     <= to_unsigned(11, aux_half_low'length);
  rst_oserdes   <= not pll_aux_locked;
  clk_10m_ext_o <= sd_out(0);

  cmp_pll_aux_locked: gc_sync_ffs
    generic map (
      g_sync_edge => "positive")
    port map (
      clk_i    => clk_pll_125m,
      rst_n_i  => rstlogic_rst_out(1),
      data_i   => pll_aux_locked,
      synced_o => clk_pll_aux_locked);

  process(clk_pll_125m)
  begin
    if rising_edge(clk_pll_125m) then
      if(rstlogic_rst_out(1) = '0' or clk_pll_aux_locked = '0') then
        tm_time_valid_d1 <= '0';
      elsif(pps_csync = '1') then
        tm_time_valid_d1 <= tm_time_valid;
      end if;
    end if;
  end process;
  clk_realign <= (not tm_time_valid_d1) and tm_time_valid and pps_csync;

  process(clk_pll_125m)
    variable rest  : integer range 0 to 65535;
    variable v_bit : std_logic;
  begin
    if rising_edge(clk_pll_125m) then
      if (rstlogic_rst_out(1)='0' or clk_pll_aux_locked='0' or clk_realign='1') then
          rest := to_integer(aux_half_high - aux_shift);
          v_bit := '1';
      else
        for i in 0 to c_DATA_W-1 loop
          if(rest /= 0) then
            sd_data(i) <= v_bit;
            rest := rest - 1;
          elsif(v_bit = '1') then
            sd_data(i) <= '0';
            v_bit := '0';
            rest := to_integer(aux_half_low-1); -- because here we already wrote first bit
                                    -- from this group
          elsif(v_bit = '0') then
            sd_data(i) <= '1';
            v_bit := '1';
            rest := to_integer(aux_half_high-1);
          end if;
        end loop;
      end if;
    end if;
  end process;

  U_10MHZ_SERDES: oserdes_4_to_1
  generic map(
    dev_w => c_DATA_W)
  port map(
    data_out_from_device => sd_data,
    data_out_to_pins     => sd_out,
    delay_reset          => '0',
    clk_in               => clk_pll_aux_out(0), --500MHz
    pll_locked           => pll_aux_locked,
    clk_div_in           => clk_pll_125m,
    io_reset             => rst_oserdes);

end architecture struct;
