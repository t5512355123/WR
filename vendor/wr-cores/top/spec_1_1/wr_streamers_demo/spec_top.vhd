-------------------------------------------------------------------------------
-- Title      : WR Streamers demo
-- Project    : WR PTP Core
-- URL        : http://www.ohwr.org/projects/wr-cores/wiki/Wrpc_core
-------------------------------------------------------------------------------
-- File       : spec_top.vhd
-- Author(s)  : Tomasz Wlostowski (re-done by Maciej Lipinski, based on spec_top)
-- Company    : CERN (BE-CO-HT)
-------------------------------------------------------------------------------
-- Description:
--
-- White Rabbit Core Hands-On Course
--
-- Lesson 04a: Trivial streamer demo
--
-- Objectives:
-- - Show how to use streamer cores and WR timing interface.
-- - Measure packet latency
--
-- Brief description:
-- This firmware demonstrates a simple trigger distribution system. A pulse coming
-- to one of the cards is time tagged, the time tag is sent over WR network and
-- used by the receiver to reproduce the pulse with fixed delay. 
-- 
-- DIO Mezzanine connector assignment is:
-- I/O 1 - PPS output
-- I/O 2 - trigger pulse input
-- I/O 3 - recovered pulse output
--
-------------------------------------------------------------------------------
-- Copyright (c) 2016-2019 CERN
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

-- Use library UNISIM for PLL_BASE, IBUFGDS and BUFG simulation components.
library UNISIM;
use UNISIM.vcomponents.all;

library work;
-- Use the General Cores package (for gc_extend_pulse)
use work.gencores_pkg.all;
-- Use the streamers package for streamer configuration declarations
use work.streamers_pkg.all;
-- -- needed for c_etherbone_sdb
-- use work.etherbone_pkg.all;
-- needed for PIPELINED
use work.wishbone_pkg.all;
-- Needed for generic board support
use work.wr_board_pkg.all;
-- Needed for SPEC-specific board support
use work.wr_spec_pkg.all;
-- Needed for SDB description
use work.synthesis_descriptor.all;

entity spec_top is
  generic (
    g_dpram_initf : string := "../../bin/wrpc/wrc_phy8.bram";
    -- Simulation-mode enable parameter. Set by default (synthesis) to 0, and
    -- changed to non-zero in the instantiation of the top level DUT in the testbench.
    -- Its purpose is to reduce some internal counters/timeouts to speed up simulations.
    g_simulation : integer := 0;
    g_dpram_size : integer := (144*1024/4)
    );
  port (
    ---------------------------------------------------------------------------
    -- Clock signals
    ---------------------------------------------------------------------------

    -- Clock input: 125 MHz LVDS reference clock, coming from the CDCM61004
    -- PLL. The reference oscillator is a 25 MHz VCTCXO (VM53S), tunable by the
    -- DAC connected to CS0 SPI line (dac_main output of the WR Core).
    clk_125m_pllref_p_i : in std_logic;
    clk_125m_pllref_n_i : in std_logic;

    -- Dedicated clock for the Xilinx GTP transceiver. Same physical clock as
    -- clk_125m_pllref, just coming from another output of CDCM61004 PLL.
    clk_125m_gtp_n_i : in std_logic;
    clk_125m_gtp_p_i : in std_logic;

    -- Clock input, used to derive the DDMTD clock (check out the general presentation
    -- of WR for explanation of its purpose). The clock is produced by the
    -- other VCXO, tuned by the second AD5662 DAC, (which is connected to
    -- dac_helper output of the WR Core)
    clk_20m_vcxo_i : in std_logic;

    ---------------------------------------------------------------------------
    -- GN4124 PCIe bridge signals
    ---------------------------------------------------------------------------
    -- From GN4124 Local bus
    gn_rst_n : in std_logic; -- Reset from GN4124 (RSTOUT18_N)
    -- PCIe to Local [Inbound Data] - RX
    gn_p2l_clk_n  : in  std_logic;       -- Receiver Source Synchronous Clock-
    gn_p2l_clk_p  : in  std_logic;       -- Receiver Source Synchronous Clock+
    gn_p2l_rdy    : out std_logic;       -- Rx Buffer Full Flag
    gn_p2l_dframe : in  std_logic;       -- Receive Frame
    gn_p2l_valid  : in  std_logic;       -- Receive Data Valid
    gn_p2l_data   : in  std_logic_vector(15 downto 0);  -- Parallel receive data
    -- Inbound Buffer Request/Status
    gn_p_wr_req   : in  std_logic_vector(1 downto 0);  -- PCIe Write Request
    gn_p_wr_rdy   : out std_logic_vector(1 downto 0);  -- PCIe Write Ready
    gn_rx_error   : out std_logic;                     -- Receive Error
    -- Local to Parallel [Outbound Data] - TX
    gn_l2p_clkn   : out std_logic;       -- Transmitter Source Synchronous Clock-
    gn_l2p_clkp   : out std_logic;       -- Transmitter Source Synchronous Clock+
    gn_l2p_dframe : out std_logic;       -- Transmit Data Frame
    gn_l2p_valid  : out std_logic;       -- Transmit Data Valid
    gn_l2p_edb    : out std_logic;       -- Packet termination and discard
    gn_l2p_data   : out std_logic_vector(15 downto 0);  -- Parallel transmit data
    -- Outbound Buffer Status
    gn_l2p_rdy    : in std_logic;                     -- Tx Buffer Full Flag
    gn_l_wr_rdy   : in std_logic_vector(1 downto 0);  -- Local-to-PCIe Write
    gn_p_rd_d_rdy : in std_logic_vector(1 downto 0);  -- PCIe-to-Local Read Response Data Ready
    gn_tx_error   : in std_logic;                     -- Transmit Error
    gn_vc_rdy     : in std_logic_vector(1 downto 0);  -- Channel ready
    -- General Purpose Interface
    gn_gpio : inout std_logic_vector(1 downto 0);  -- gn_gpio[0] -> GN4124 GPIO8
                                                   -- gn_gpio[1] -> GN4124 GPIO9

    ---------------------------------------------------------------------------
    -- SFP pins
    ---------------------------------------------------------------------------

    -- TX gigabit output
    sfp_txp_o : out   std_logic;
    sfp_txn_o : out   std_logic;

    -- RX gigabit input
    sfp_rxp_i : in    std_logic;
    sfp_rxn_i : in    std_logic;

    -- SFP MOD_DEF0 pin (used as a tied-to-ground SFP insertion detect line)
    sfp_mod_def0_i    : in    std_logic;          -- sfp detect
    -- SFP MOD_DEF1 pin (SCL line of the I2C EEPROM inside the SFP)
    sfp_mod_def1_b    : inout std_logic;          -- scl
     -- SFP MOD_DEF1 pin (SDA line of the I2C EEPROM inside the SFP)
    sfp_mod_def2_b    : inout std_logic;          -- sda
    -- SFP RATE_SELECT pin. Unused for most SFPs, in our case tied to 0.
    sfp_rate_select_o : out   std_logic;
    -- SFP laser fault detection pin. Unused in our design.
    sfp_tx_fault_i    : in    std_logic;
    -- SFP laser disable line. In our case, tied to GND.
    sfp_tx_disable_o  : out   std_logic;
    -- SFP-provided loss-of-link detection. We don't use it as Ethernet PCS
    -- has its own loss-of-sync detection mechanism.
    sfp_los_i         : in    std_logic;

    ---------------------------------------------------------------------------
    -- Oscillator control pins
    ---------------------------------------------------------------------------

    -- A typical SPI bus shared betwen two AD5662 DACs. The first one (CS1) tunes
    -- the clk_ref oscillator, the second (CS2) - the clk_dmtd VCXO.
    plldac_sclk_o     : out std_logic;
    plldac_din_o      : out std_logic;
    pll25dac_cs_n_o : out std_logic; --cs1
    pll20dac_cs_n_o : out std_logic; --cs2

    ---------------------------------------------------------------------------
    -- Onewire interface
    ---------------------------------------------------------------------------
    -- One-wire interface to DS18B20 temperature sensor, which also provides an
    -- unique serial number, that WRPC uses to assign itself a unique MAC address.
    onewire_b : inout std_logic;

    ---------------------------------------------------------------------------
    -- UART
    ---------------------------------------------------------------------------
    -- UART pins (connected to the mini-USB port)
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
    -- Miscellanous SPEC pins
    ---------------------------------------------------------------------------
    -- Red LED next to the SFP: blinking indicates that packets are being
    -- transferred.
    led_act_o   : out std_logic;
    -- Green LED next to the SFP: indicates if the link is up.
    led_link_o : out std_logic;

    button1_i   : in  std_logic;

    ---------------------------------------------------------------------------
    -- Digital I/O FMC Pins
    -- used in this design to output WR-aligned 1-PPS (in Slave mode) and input
    -- 10MHz & 1-PPS from external reference (in GrandMaster mode).
    ---------------------------------------------------------------------------

    -- Clock input from LEMO 5 on the mezzanine front panel. Used as 10MHz
    -- external reference input.
    dio_clk_p_i : in std_logic;
    dio_clk_n_i : in std_logic;

    -- Differential inputs, dio_p_i(N) inputs the current state of I/O (N+1) on
    -- the mezzanine front panel.
    dio_n_i : in std_logic_vector(4 downto 0);
    dio_p_i : in std_logic_vector(4 downto 0);

    -- Differential outputs. When the I/O (N+1) is configured as output (i.e. when
    -- dio_oe_n_o(N) = 0), the value of dio_p_o(N) determines the logic state
    -- of I/O (N+1) on the front panel of the mezzanine
    dio_n_o : out std_logic_vector(4 downto 0);
    dio_p_o : out std_logic_vector(4 downto 0);

    -- Output enable. When dio_oe_n_o(N) is 0, connector (N+1) on the front
    -- panel is configured as an output.
    dio_oe_n_o : out std_logic_vector(4 downto 0);

    -- Termination enable. When dio_term_en_o(N) is 1, connector (N+1) on the front
    -- panel is 50-ohm terminated
    dio_term_en_o : out std_logic_vector(4 downto 0);

    -- Two LEDs on the mezzanine panel. Only Top one is currently used - to
    -- blink 1-PPS.
    dio_led_top_o : out std_logic;
    dio_led_bot_o : out std_logic;

    -- I2C interface for accessing FMC EEPROM. Deprecated, was used in
    -- pre-v3.0 releases to store WRPC configuration. Now we use Flash for this.
    dio_scl_b : inout std_logic;
    dio_sda_b : inout std_logic

  );
end entity spec_top;

architecture top of spec_top is

  -----------------------------------------------------------------------------
  -- Constants
  -----------------------------------------------------------------------------
  -- Trigger-to-output value, in 8 ns ticks. Set by default to 20us to work
  -- for 10km+ fibers.
  constant c_PULSE_DELAY : integer := 20000/8;

  constant tx_streamer_params : t_tx_streamer_params := (
      -- We send each timestamp (40 TAI bits + 28
      -- cycle bits) as a single parallel data word of 68 bits. Since data width
      -- must be a multiple of 16 bits, we round it up to 80 bits).
      data_width          => 80,
      buffer_size         => 256,--default
      -- TX threshold = 4 data words. (it's anyway ignored because of
      -- g_tx_timeout setting  below)
      threshold           => 4,
      max_words_per_frame => 256,--default
      -- minimum timeout: sends packets asap to minimize latency (but it's not
      -- good for large amounts of data due to encapsulation overhead)
      timeout             => 1,
      use_ref_clk_for_data=> 0,   --default
      escape_code_disable => FALSE--default
      );
  constant rx_streamer_params : t_rx_streamer_params := (
      -- data width must be identical as in the TX streamer - otherwise, we'll be receiving
      -- rubbish
      data_width            => 80,
      buffer_size           => 256,  --default
      escape_code_disable   => FALSE,--default
      use_ref_clk_for_data  => 0,    --default
      expected_words_number => 0     --default
      );

  -----------------------------------------------------------------------------
  -- Component declarations
  -----------------------------------------------------------------------------

  component spec_reset_gen
    port (
      clk_sys_i        : in  std_logic;
      rst_pcie_n_a_i   : in  std_logic;
      rst_button_n_a_i : in  std_logic;
      rst_n_o          : out std_logic);
  end component;

  component pulse_stamper
    generic (
      g_ref_clk_rate : integer);
    port (
      clk_ref_i       : in  std_logic;
      clk_sys_i       : in  std_logic;
      rst_n_i         : in  std_logic;
      pulse_a_i       : in  std_logic;
      tm_time_valid_i : in  std_logic;
      tm_tai_i        : in  std_logic_vector(39 downto 0);
      tm_cycles_i     : in  std_logic_vector(27 downto 0);
      tag_tai_o       : out std_logic_vector(39 downto 0);
      tag_cycles_o    : out std_logic_vector(27 downto 0);
      tag_valid_o     : out std_logic);
  end component;

  component pulse_gen
    generic (
      g_ref_clk_rate : integer);
    port (
      clk_ref_i       : in  std_logic;
      clk_sys_i       : in  std_logic;
      rst_n_i         : in  std_logic;
      pulse_o         : out std_logic;
      tm_time_valid_i : in  std_logic;
      tm_tai_i        : in  std_logic_vector(39 downto 0);
      tm_cycles_i     : in  std_logic_vector(27 downto 0);
      trig_ready_o    : out std_logic;
      trig_tai_i      : in  std_logic_vector(39 downto 0);
      trig_cycles_i   : in  std_logic_vector(27 downto 0);
      trig_valid_i    : in  std_logic);
  end component;

  component timestamp_adder
    generic (
      g_ref_clk_rate : integer);
    port (
      clk_i      : in  std_logic;
      rst_n_i    : in  std_logic;
      valid_i    : in  std_logic;
      a_tai_i    : in  std_logic_vector(39 downto 0);
      a_cycles_i : in  std_logic_vector(27 downto 0);
      b_tai_i    : in  std_logic_vector(39 downto 0);
      b_cycles_i : in  std_logic_vector(27 downto 0);
      valid_o    : out std_logic;
      q_tai_o    : out std_logic_vector(39 downto 0);
      q_cycles_o : out std_logic_vector(27 downto 0));
  end component;

  -----------------------------------------------------------------------------
  -- Signals
  -----------------------------------------------------------------------------

  -- clock and reset
  signal clk_sys_62m5   : std_logic;
  signal rst_sys_62m5_n : std_logic;
  signal rst_ref_125m_n : std_logic;
  signal clk_ref_125m   : std_logic;
  signal clk_ref_div2   : std_logic;
  signal clk_ext_10m    : std_logic;

  -- I2C EEPROM
  signal eeprom_sda_in  : std_logic;
  signal eeprom_sda_out : std_logic;
  signal eeprom_scl_in  : std_logic;
  signal eeprom_scl_out : std_logic;

  -- SFP
  signal sfp_sda_in  : std_logic;
  signal sfp_sda_out : std_logic;
  signal sfp_scl_in  : std_logic;
  signal sfp_scl_out : std_logic;

  -- OneWire
  signal onewire_data : std_logic;
  signal onewire_oe   : std_logic;

  -- LEDs and GPIO
  signal wrc_abscal_txts_out : std_logic;
  signal wrc_abscal_rxts_out : std_logic;
  signal wrc_pps_out : std_logic;
  signal wrc_pps_led : std_logic;
  signal wrc_pps_in  : std_logic;
  signal svec_led    : std_logic_vector(15 downto 0);

  -- DIO Mezzanine
  signal dio_in  : std_logic_vector(4 downto 0);
  signal dio_out : std_logic_vector(4 downto 0);

  -- Timing interface
  signal tm_time_valid : std_logic;
  signal tm_tai        : std_logic_vector(39 downto 0);
  signal tm_cycles     : std_logic_vector(27 downto 0);

  -- TX streamer signals
  signal tx_tag_tai                    : std_logic_vector(39 downto 0);
  signal tx_tag_cycles                 : std_logic_vector(27 downto 0);
  signal tx_tag_valid                  : std_logic;
  signal tx_data                       : std_logic_vector(79 downto 0);
  signal tx_valid, tx_dreq, tx_dreq_d0 : std_logic;

  -- RX streamer signals
  signal rx_data  : std_logic_vector(79 downto 0);
  signal rx_valid : std_logic;

  -- Trigger timestamp adjusted with delay
  signal adjusted_ts_valid  : std_logic;
  signal adjusted_ts_tai    : std_logic_vector(39 downto 0);
  signal adjusted_ts_cycles : std_logic_vector(27 downto 0);

  signal pulse_out, pulse_out_long, pulse_in, pulse_in_synced, pps_long : std_logic;

  signal tx_streamer_cfg      : t_tx_streamer_cfg := c_tx_streamer_cfg_default;
  signal rx_streamer_cfg      : t_rx_streamer_cfg := c_rx_streamer_cfg_default;

  -- ChipScope for histogram readout/debugging

  component chipscope_icon
    port (
      CONTROL0 : inout std_logic_vector(35 downto 0));
  end component;

  component chipscope_ila
    port (
      CONTROL : inout std_logic_vector(35 downto 0);
      CLK     : in    std_logic;
      TRIG0   : in    std_logic_vector(31 downto 0);
      TRIG1   : in    std_logic_vector(31 downto 0);
      TRIG2   : in    std_logic_vector(31 downto 0);
      TRIG3   : in    std_logic_vector(31 downto 0));
  end component;

  signal control0                   : std_logic_vector(35 downto 0);
  signal trig0, trig1, trig2, trig3 : std_logic_vector(31 downto 0);



begin  -- architecture top

  -----------------------------------------------------------------------------
  -- The WR PTP core board package
  -----------------------------------------------------------------------------

  cmp_xwrc_board_spec : entity work.xwrc_board_spec
    generic map (
      g_simulation                => g_simulation,
      g_with_external_clock_input => TRUE,
      g_dpram_initf               => g_dpram_initf,
      g_dpram_size                => g_dpram_size,
      g_fabric_iface              => STREAMERS,
      g_tx_streamer_params        => tx_streamer_params,
      g_rx_streamer_params        => rx_streamer_params)
    port map (
      areset_n_i          => button1_i,
      areset_edge_n_i     => gn_rst_n,
      clk_20m_vcxo_i      => clk_20m_vcxo_i,
      clk_125m_pllref_p_i => clk_125m_pllref_p_i,
      clk_125m_pllref_n_i => clk_125m_pllref_n_i,
      clk_125m_gtp_n_i    => clk_125m_gtp_n_i,
      clk_125m_gtp_p_i    => clk_125m_gtp_p_i,
      clk_10m_ext_i       => clk_ext_10m,
      clk_sys_62m5_o      => clk_sys_62m5,
      clk_ref_125m_o      => clk_ref_125m,
      rst_sys_62m5_n_o    => rst_sys_62m5_n,
      rst_ref_125m_n_o    => rst_ref_125m_n,

      plldac_sclk_o       => plldac_sclk_o,
      plldac_din_o        => plldac_din_o,
      pll25dac_cs_n_o     => pll25dac_cs_n_o,
      pll20dac_cs_n_o     => pll20dac_cs_n_o,

      sfp_txp_o           => sfp_txp_o,
      sfp_txn_o           => sfp_txn_o,
      sfp_rxp_i           => sfp_rxp_i,
      sfp_rxn_i           => sfp_rxn_i,
      sfp_det_i           => sfp_mod_def0_i,
      sfp_sda_i           => sfp_sda_in,
      sfp_sda_o           => sfp_sda_out,
      sfp_scl_i           => sfp_scl_in,
      sfp_scl_o           => sfp_scl_out,
      sfp_rate_select_o   => sfp_rate_select_o,
      sfp_tx_fault_i      => sfp_tx_fault_i,
      sfp_tx_disable_o    => sfp_tx_disable_o,
      sfp_los_i           => sfp_los_i,

      eeprom_sda_i        => eeprom_sda_in,
      eeprom_sda_o        => eeprom_sda_out,
      eeprom_scl_i        => eeprom_scl_in,
      eeprom_scl_o        => eeprom_scl_out,

      onewire_i           => onewire_data,
      onewire_oen_o       => onewire_oe,
      -- Uart
      uart_rxd_i          => uart_rxd_i,
      uart_txd_o          => uart_txd_o,
      -- SPI Flash
      flash_sclk_o        => flash_sclk_o,
      flash_ncs_o         => flash_ncs_o,
      flash_mosi_o        => flash_mosi_o,
      flash_miso_i        => flash_miso_i,

      wrs_tx_data_i       => tx_data,
      wrs_tx_valid_i      => tx_valid,
      wrs_tx_dreq_o       => tx_dreq,
      -- every data word we send is the last one, as a single transfer in our
      -- case contains only one 80-bit data word.
      wrs_tx_last_i       => '1',
      wrs_tx_flush_i      => '0',
      wrs_rx_first_o      => open,
      wrs_rx_last_o       => open,
      wrs_rx_data_o       => rx_data,
      wrs_rx_valid_o      => rx_valid,
      wrs_rx_dreq_i       => '1',
      wrs_tx_cfg_i        => tx_streamer_cfg,
      wrs_rx_cfg_i        => rx_streamer_cfg,

      tm_link_up_o        => open,
      tm_time_valid_o     => tm_time_valid,
      tm_tai_o            => tm_tai,
      tm_cycles_o         => tm_cycles,

      abscal_txts_o       => wrc_abscal_txts_out,
      abscal_rxts_o       => wrc_abscal_rxts_out,

      pps_ext_i           => wrc_pps_in,
      pps_p_o             => wrc_pps_out,
      pps_led_o           => wrc_pps_led,
      led_link_o          => led_link_o,
      led_act_o           => led_act_o);

  -- Tristates for SFP EEPROM
  sfp_mod_def1_b <= '0' when sfp_scl_out = '0' else 'Z';
  sfp_mod_def2_b <= '0' when sfp_sda_out = '0' else 'Z';
  sfp_scl_in     <= sfp_mod_def1_b;
  sfp_sda_in     <= sfp_mod_def2_b;

  -- tri-state onewire access
  onewire_b    <= '0' when (onewire_oe = '1') else 'Z';
  onewire_data <= onewire_b;

  -----------------------------------------------------------------------------
  -- Trigger distribution stuff - timestamping & packet transmission part
  -----------------------------------------------------------------------------
  
  U_Pulse_Stamper : pulse_stamper
    generic map (
      g_ref_clk_rate => 125000000)
    port map (
      clk_ref_i       => clk_ref_125m,
      clk_sys_i       => clk_sys_62m5,
      rst_n_i         => rst_sys_62m5_n,
      pulse_a_i       => pulse_in,           -- I/O 2 = our pulse input

      tm_time_valid_i => tm_time_valid,  -- timing ports of the WR Core
      tm_tai_i        => tm_tai,
      tm_cycles_i     => tm_cycles,

      tag_tai_o    => tx_tag_tai,       -- time tag of the latest pulse
      tag_cycles_o => tx_tag_cycles,
      tag_valid_o  => tx_tag_valid);

  -- Pack the time stamp into a 80-bit data word for the streamer
  tx_data(27 downto 0)       <= tx_tag_cycles;
  tx_data(32 + 39 downto 32) <= tx_tag_tai;
  -- avoid Xes (this may break simulations)
  tx_data(31 downto 28)      <= (others => '0');
  tx_data(79 downto 32+40)   <= (others => '0');

  -- Data valid signal: simply drop the timestamp if the streamer can't accept
  -- data for the moment.
  tx_valid <= tx_dreq_d0 and tx_tag_valid;

  -- tx_dreq_o output of the streamer is asserted one clock cycle in advance,
  -- while the line above drives the valid signal combinatorially. We need a delay.
  process(clk_sys_62m5)
  begin
    if rising_edge(clk_sys_62m5) then
      tx_dreq_d0 <= tx_dreq;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- Trigger distribution stuff - packet reception and pulse generation
  -----------------------------------------------------------------------------
  -- Add a fixed delay to the reveived trigger timestamp
  U_Add_Delay1 : timestamp_adder
    generic map (
      g_ref_clk_rate => 125000000)
    port map (
      clk_i   => clk_sys_62m5,
      rst_n_i => rst_sys_62m5_n,
      valid_i => rx_valid,

      a_tai_i    => rx_data(32 + 39 downto 32),
      a_cycles_i => rx_data(27 downto 0),

      b_tai_i    => (others => '0'),
      b_cycles_i => std_logic_vector(to_unsigned(c_PULSE_DELAY, 28)),

      valid_o    => adjusted_ts_valid,
      q_tai_o    => adjusted_ts_tai,
      q_cycles_o => adjusted_ts_cycles);

  -- And a pulse generator that produces a pulse at a time received by the
  -- streamer above adjusted with the delay
  U_Pulse_Generator : pulse_gen
    generic map (
      g_ref_clk_rate => 125000000)
    port map (
      clk_ref_i       => clk_ref_125m,
      clk_sys_i       => clk_sys_62m5,
      rst_n_i         => rst_sys_62m5_n,
      pulse_o         => pulse_out,
      tm_time_valid_i => tm_time_valid,
      tm_tai_i        => tm_tai,
      tm_cycles_i     => tm_cycles,
      trig_tai_i      => adjusted_ts_tai,
      trig_cycles_i   => adjusted_ts_cycles,
      trig_valid_i    => adjusted_ts_valid);



  -- pps_p signal from the WR core is 8ns- (single clk_ref cycle) wide. This is
  -- too short to drive outputs such as LEDs. Let's extend its length to some
  -- human-noticeable value
  U_Extend_PPS : gc_extend_pulse
    generic map (
      g_width => 10000000)              -- output length: 10000000x8ns = 80 ms.

    port map (
      clk_i      => clk_ref_125m,
      rst_n_i    => rst_ref_125m_n,
      pulse_i    => wrc_pps_out,
      extended_o => pps_long);

  U_Sync_Trigger_Pulse : gc_sync_ffs
    port map (
      clk_i    => clk_ref_125m,
      rst_n_i  => rst_ref_125m_n,
      data_i   => pulse_in,
      synced_o => pulse_in_synced);

  -- pulse_gen above generates pulses that are single-cycle long. This is too
  -- short to observe on a scope, particularly with slower time base (to see 2
  -- pulses simulatenously). Let's extend it a bit:
  U_Extend_Output_Pulse : gc_extend_pulse
    generic map (
      -- 1000 * 8ns = 8 us
      g_width => 1000)
    port map (
      clk_i      => clk_ref_125m,
      rst_n_i    => rst_ref_125m_n,
      pulse_i    => pulse_out,
      extended_o => pulse_out_long);


  ------------------------------------------------------------------------------
  -- Digital I/O FMC Mezzanine connections
  ------------------------------------------------------------------------------
  gen_dio_iobufs: for I in 0 to 4 generate
    U_ibuf: IBUFDS
      generic map (
        DIFF_TERM => true)
      port map (
        O  => dio_in(i),
        I  => dio_p_i(i),
        IB => dio_n_i(i));

    U_obuf : OBUFDS
      port map (
        I  => dio_out(i),
        O  => dio_p_o(i),
        OB => dio_n_o(i));
  end generate;

  -- DIO_0: (extended) PPS out
  dio_out(0)    <= pps_long;
  -- DIO_1: TX trigger pulse in
  pulse_in      <= dio_in(1);
  dio_out(1)    <= '0';
  -- DIO_2: (extended) Pulse out (delayed streamer reception)
  dio_out(2)    <= pulse_out_long;
  dio_out(3)    <= pulse_out_long;
  dio_out(4)    <= pulse_out_long;

  -- all DIO connectors except I/O 2 (trigger input) are outputs
  dio_oe_n_o(0)          <= '0';
  dio_oe_n_o(1)          <= '1';
  dio_oe_n_o(4 downto 2) <= (others => '0');

  -- terminate only the trigger input
  dio_oe_n_o(0)          <= '0';
  dio_oe_n_o(1)          <= '1';
  dio_oe_n_o(4 downto 2) <= (others => '0');

  dio_term_en_o(0)          <= '0';
  dio_term_en_o(1)          <= '1';
  dio_term_en_o(4 downto 2) <= (others => '0');


  -- EEPROM I2C tri-states
  dio_sda_b <= '0' when (eeprom_sda_out = '0') else 'Z';
  eeprom_sda_in <= dio_sda_b;
  dio_scl_b <= '0' when (eeprom_scl_out = '0') else 'Z';
  eeprom_scl_in <= dio_scl_b;

  -- Div by 2 reference clock to LEMO connector
  process(clk_ref_125m)
  begin
    if rising_edge(clk_ref_125m) then
      clk_ref_div2 <= not clk_ref_div2;
    end if;
  end process;

  cmp_ibugds_extref: IBUFGDS
    generic map (
      DIFF_TERM => true)
    port map (
      O  => clk_ext_10m,
      I  => dio_clk_p_i,
      IB => dio_clk_n_i);

  -- LEDs
  dio_led_top_o <= pps_long;

  U_Extend_Trigger_Pulse : gc_extend_pulse
    generic map (
      -- 1000 * 8ns = 8 us
      g_width => 1000)
    port map (
      clk_i      => clk_ref_125m,
      rst_n_i    => rst_ref_125m_n,
      pulse_i    => pulse_in_synced,
      extended_o => dio_led_bot_o);

  CS_ICON : chipscope_icon
    port map (
      CONTROL0 => CONTROL0);
  CS_ILA : chipscope_ila
    port map (
      CONTROL => CONTROL0,
      CLK     => clk_sys_62m5,
      TRIG0   => TRIG0,
      TRIG1   => TRIG1,
      TRIG2   => TRIG2,
      TRIG3   => TRIG3);



  trig1(31) <= tm_time_valid;
  trig1(27 downto 0) <= tm_cycles;
  trig1(30 downto 28) <= tm_tai(2 downto 0);

  trig2(31) <= adjusted_ts_valid;
  trig2(27 downto 0) <= adjusted_ts_cycles;
  trig2(30 downto 28) <= adjusted_ts_tai(2 downto 0);

  trig3(31) <= rx_valid;
  trig3(27 downto 0) <= rx_data(27 downto 0);
  trig3(30 downto 28) <= rx_data(32 + 2 downto 32);

end architecture top;
