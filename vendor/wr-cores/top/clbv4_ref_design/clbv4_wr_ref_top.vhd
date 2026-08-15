-------------------------------------------------------------------------------
-- Title      : WRPC reference design for KM3NeT Central Logic Board (CLBv4)
--            : based on kintex-7
-- Project    : WR PTP Core
-- URL        : http://www.ohwr.org/projects/wr-cores/wiki/Wrpc_core
-------------------------------------------------------------------------------
-- File       : clbv4_wr_ref_top.vhd
-- Author(s)  : Pascal Bos <bosp@nikhef.nl>
-- Company    : Nikhef
-- Created    : 2022-05-18
-- Last update: 2022-05-18
-- Standard   : VHDL'93
-------------------------------------------------------------------------------
-- Description: Top-level file for the WRPC reference design on the clbv4.
--
-- This is a reference top HDL that instanciates the WR PTP Core together with
-- its peripherals to be run on a CLB card.
--
-- There are two main usecases for this HDL file:
-- * let new users easily synthesize a WR PTP Core bitstream that can be run on
--   reference hardware
-- * provide a reference top HDL file showing how the WRPC can be instantiated
--   in HDL projects.
--
-------------------------------------------------------------------------------
-- Copyright (c) 2019 Nikhef
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
use work.wishbone_pkg.all;
use work.wr_board_pkg.all;
use work.wr_clbv4_pkg.all;

library unisim;
use unisim.vcomponents.all;

entity clbv4_wr_ref_top is
  generic (
    g_dpram_initf : string := "../../../../bin/wrpc/wrc_phy16_direct_dmtd.bram";
    -- In Vivado Project-Mode, during a Synthesis run or an Implementation run, the Vivado working
    -- directory temporarily changes to the "project_name/project_name.runs/run_name" directory.

    -- Simulation-mode enable parameter. Set by default (synthesis) to 0, and
    -- changed to non-zero in the instantiation of the top level DUT in the testbench.
    -- Its purpose is to reduce some internal counters/timeouts to speed up simulations.
    g_simulation : integer := 0
  );
  port (
    ---------------------------------------------------------------------------`
    -- Clocks/resets
    ---------------------------------------------------------------------------

    -- Local oscillators

    clk_125m_dmtd_p_i : in std_logic;             -- 124.992 MHz PLL reference
    clk_125m_dmtd_n_i : in std_logic;

    clk_125m_gtx_n_i : in std_logic;              -- 125.000 MHz GTX reference
    clk_125m_gtx_p_i : in std_logic;

    ---------------------------------------------------------------------------
    -- SPI interface to DACs
    ---------------------------------------------------------------------------

    dac_refclk_cs_n_o : out std_logic;
    dac_refclk_sclk_o : out std_logic;
    dac_refclk_din_o  : out std_logic;

    dac_dmtd_cs_n_o   : out std_logic;
    dac_dmtd_sclk_o   : out std_logic;
    dac_dmtd_din_o    : out std_logic;

    ---------------------------------------------------------------------------
    -- SFP I/O for transceiver
    ---------------------------------------------------------------------------

    sfp_txp_o         : out   std_logic;
    sfp_txn_o         : out   std_logic;
    sfp_rxp_i         : in    std_logic;
    sfp_rxn_i         : in    std_logic;
    --sfp_mod_def0_i    : in    std_logic;        -- sfp detect not present on GlenAir module
    sfp_mod_def1_b    : inout std_logic;          -- scl
    sfp_mod_def2_b    : inout std_logic;          -- sda
    sfp_rate_select_o : out   std_logic;
    sfp_tx_fault_i    : in    std_logic;
    sfp_tx_disable_o  : out   std_logic;
    sfp_los_i         : in    std_logic;

    ---------------------------------------------------------------------------
    -- Onewire interface
    ---------------------------------------------------------------------------

    onewire_b : inout std_logic;

    ---------------------------------------------------------------------------
    -- UART
    ---------------------------------------------------------------------------

    uart_rxd_i : in  std_logic;
    uart_txd_o : out std_logic;

    ---------------------------------------------------------------------------
    -- No Flash memory SPI interface
    ---------------------------------------------------------------------------

    ---------------------------------------------------------------------------
    -- Miscellanous clbv4 pins
    ---------------------------------------------------------------------------
    -- Red LED next to the SFP: blinking indicates that packets are being
    -- transferred.
    led_act_o   : out std_logic;
    -- Green LED next to the SFP: indicates if the link is up.
    led_link_o  : out std_logic;
    
    -- Reset control
    reset_i     : in  std_logic;
    suicide     : out std_logic;
    WDI         : out std_logic;
    WD_SET      : out std_logic_vector(2 downto 0);
    
    -- test_lemo outputs PPS
    test_lemo   : out std_logic;
    -- Monitoring signals output on External Debug Connector J35
    pps_mon     : out std_logic;
    ref_clk_mon : out std_logic;

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
    dio_oe_n_o    : out std_logic_vector(4 downto 0);

    -- Termination enable. When dio_term_en_o(N) is 1, connector (N+1) on the front
    -- panel is 50-ohm terminated
    dio_term_en_o : out std_logic_vector(4 downto 0);

    -- Two LEDs on the mezzanine panel. Only Top one is currently used - to
    -- blink 1-PPS.
    dio_led_top_o : out std_logic;
    dio_led_bot_o : out std_logic;

    -- I2C interface for accessing EEPROM.
    eeprom_scl_b : inout std_logic;
    eeprom_sda_b : inout std_logic;

    -- Bulls-eye connector outputs
    txts_p_o : out std_logic;
    txts_n_o : out std_logic;

    rxts_p_o : out std_logic;
    rxts_n_o : out std_logic;

    pps_p_o : out std_logic;
    pps_n_o : out std_logic;

    clk_ref_62m5_p_o : out std_logic;
    clk_ref_62m5_n_o : out std_logic;

    clk_dmtd_62m5_p_o : out std_logic;
    clk_dmtd_62m5_n_o : out std_logic

  );
end entity clbv4_wr_ref_top;

architecture top of clbv4_wr_ref_top is
  -----------------------------------------------------------------------------
  -- Signals
  -----------------------------------------------------------------------------

  -- clock and reset
  signal reset_n        : std_logic;
  signal clk_sys_62m5   : std_logic;
  signal rst_sys_62m5_n : std_logic;
  signal rst_ref_62m5_n : std_logic;
  signal clk_ref_62m5   : std_logic;
  signal clk_dmtd_62m5  : std_logic;
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

  -- BullsEye connector outputs
  signal txts_oddr          : std_logic;
  signal rxts_oddr          : std_logic;
  signal pps_oddr           : std_logic;
  signal clk_ref_62m5_oddr  : std_logic;
  signal clk_dmtd_62m5_oddr : std_logic;

begin  -- architecture top

  suicide<= '1';
  reset_n <= not reset_i; -- Reset = high active on CLB
  WDI <= '0';
  WD_SET <="011"; --disable Watchdog
  
  -----------------------------------------------------------------------------
  -- The WR PTP core board package (WB Slave + WB Master)
  -----------------------------------------------------------------------------
  
  cmp_xwrc_board_clbv4 : xwrc_board_clbv4
    generic map (
      g_simulation                => g_simulation,
      g_with_external_clock_input => TRUE,
      g_dpram_initf               => g_dpram_initf,
      g_fabric_iface              => PLAIN)
    port map (
      areset_n_i          => reset_n,
      clk_125m_dmtd_n_i   => clk_125m_dmtd_n_i,
      clk_125m_dmtd_p_i   => clk_125m_dmtd_p_i,
      clk_125m_gtx_n_i    => clk_125m_gtx_n_i,
      clk_125m_gtx_p_i    => clk_125m_gtx_p_i,
      clk_10m_ext_i       => clk_ext_10m,
      clk_sys_62m5_o      => clk_sys_62m5,
      clk_ref_62m5_o      => clk_ref_62m5,
      clk_dmtd_62m5_o     => clk_dmtd_62m5,
      rst_sys_62m5_n_o    => rst_sys_62m5_n,
      rst_ref_62m5_n_o    => rst_ref_62m5_n,

      dac_refclk_cs_n_o   => dac_refclk_cs_n_o,
      dac_refclk_sclk_o   => dac_refclk_sclk_o,
      dac_refclk_din_o    => dac_refclk_din_o,
      dac_dmtd_cs_n_o     => dac_dmtd_cs_n_o,
      dac_dmtd_sclk_o     => dac_dmtd_sclk_o, 
      dac_dmtd_din_o      => dac_dmtd_din_o, 

      sfp_txp_o           => sfp_txp_o,
      sfp_txn_o           => sfp_txn_o,
      sfp_rxp_i           => sfp_rxp_i,
      sfp_rxn_i           => sfp_rxn_i,
      sfp_det_i           => '0',
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
  -- Configure Digital I/Os 0 to 2 as outputs
  dio_oe_n_o(2 downto 0) <= (others => '0');
  -- Configure Digital I/Os 3 and 4 as inputs for external reference
  dio_oe_n_o(3)          <= '1';  -- for external 1-PPS
  dio_oe_n_o(4)          <= '1';  -- for external 10MHz clock
  -- Configure Digital I/Os 3 to 4 inputs to be terminated.
  dio_term_en_o          <= "11000";

  -- EEPROM I2C tri-states
  eeprom_sda_b <= '0' when (eeprom_sda_out = '0') else 'Z';
  eeprom_sda_in <= eeprom_sda_b;
  eeprom_scl_b <= '0' when (eeprom_scl_out = '0') else 'Z';
  eeprom_scl_in <= eeprom_scl_b;

  -- Div by 2 reference clock to LEMO connector
  process(clk_ref_62m5)
  begin
    if rising_edge(clk_ref_62m5) then
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

  wrc_pps_in    <= dio_in(3);
  dio_out(0)    <= wrc_pps_out;
  dio_out(1)    <= wrc_abscal_rxts_out;
  dio_out(2)    <= wrc_abscal_txts_out;
  
  test_lemo   <= wrc_pps_out;
  pps_mon     <= wrc_pps_out;
  ref_clk_mon <= clk_ref_62m5;
  
  -- LEDs
  U_Extend_PPS : gc_extend_pulse
  generic map (
    g_width => 10000000)
  port map (
    clk_i      => clk_ref_62m5,
    rst_n_i    => rst_ref_62m5_n,
    pulse_i    => wrc_pps_led,
    extended_o => dio_led_top_o);

  dio_led_bot_o <= '0';

  ------------------------------------------------------------------------------
  -- BullsEye connector outputs
  ------------------------------------------------------------------------------

  -- tx timestamp for absolute calibration
  oddr_txts: ODDR
    generic map(
      DDR_CLK_EDGE => "SAME_EDGE",
      INIT         => '0',
      SRTYPE       => "SYNC")
    port map(
      Q  => txts_oddr,
      C  => clk_ref_62m5,
      CE => '1',
      D1 => wrc_abscal_txts_out,
      D2 => wrc_abscal_txts_out,
      R  => '0',
      S  => '0');
  
  obuf_txts: OBUFDS
  generic map(
    CAPACITANCE => "DONT_CARE",
    IOSTANDARD  => "DEFAULT",
    SLEW        => "SLOW")
  port map(
    O  => txts_p_o,
    OB => txts_n_o,
    I  => txts_oddr);

  -- rx timestamp for absolute calibration
  oddr_rxts: ODDR
    generic map(
      DDR_CLK_EDGE => "SAME_EDGE",
      INIT         => '0',
      SRTYPE       => "SYNC")
    port map(
      Q  => rxts_oddr,
      C  => clk_ref_62m5,
      CE => '1',
      D1 => wrc_abscal_rxts_out,
      D2 => wrc_abscal_rxts_out,
      R  => '0',
      S  => '0');
  
  obuf_rxts: OBUFDS
  generic map(
    CAPACITANCE => "DONT_CARE",
    IOSTANDARD  => "DEFAULT",
    SLEW        => "SLOW")
  port map(
    O  => rxts_p_o,
    OB => rxts_n_o,
    I  => rxts_oddr);

  -- PPS (also used for absolute calibration)
  oddr_pps: ODDR
    generic map(
      DDR_CLK_EDGE => "SAME_EDGE",
      INIT         => '0',
      SRTYPE       => "SYNC")
    port map(
      Q  => pps_oddr,
      C  => clk_ref_62m5,
      CE => '1',
      D1 => wrc_pps_out,
      D2 => wrc_pps_out,
      R  => '0',
      S  => '0');
  
  obuf_pps: OBUFDS
  generic map(
    CAPACITANCE => "DONT_CARE",
    IOSTANDARD  => "DEFAULT",
    SLEW        => "SLOW")
  port map(
    O  => pps_p_o,
    OB => pps_n_o,
    I  => pps_oddr);
 
  -- clk_ref_62m5
   oddr_clk_ref_62m5: ODDR
   generic map(
      DDR_CLK_EDGE => "SAME_EDGE",
      INIT         => '0',
      SRTYPE       => "SYNC")
   port map(
      Q  => clk_ref_62m5_oddr,
      C  => clk_ref_62m5,
      CE => '1',
      D1 => '1',
      D2 => '0',
      R  => '0',
      S  => '0');
  
   obuf_clk_ref_62m5: OBUFDS
   generic map(
     CAPACITANCE => "DONT_CARE",
     IOSTANDARD  => "DEFAULT",
     SLEW        => "SLOW")
   port map(
     O  => clk_ref_62m5_p_o,
     OB => clk_ref_62m5_n_o,
     I  => clk_ref_62m5_oddr);

  -- clk_dmtd_62m5 (debug purposes)
   oddr_clk_dmtd_62m5: ODDR
   generic map(
      DDR_CLK_EDGE => "SAME_EDGE",
      INIT         => '0',
      SRTYPE       => "SYNC")
   port map(
      Q  => clk_dmtd_62m5_oddr,
      C  => clk_dmtd_62m5,
      CE => '1',
      D1 => '1',
      D2 => '0',
      R  => '0',
      S  => '0');
  
   obuf_clk_dmtd_62m5: OBUFDS
   generic map(
     CAPACITANCE => "DONT_CARE",
     IOSTANDARD  => "DEFAULT",
     SLEW        => "SLOW")
   port map(
     O  => clk_dmtd_62m5_p_o,
     OB => clk_dmtd_62m5_n_o,
     I  => clk_dmtd_62m5_oddr);
  
end architecture top;
