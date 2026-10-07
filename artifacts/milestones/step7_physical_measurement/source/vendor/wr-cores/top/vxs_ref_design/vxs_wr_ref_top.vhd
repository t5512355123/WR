-------------------------------------------------------------------------------
-- CERN
-- WR PTP Core
-- http://www.ohwr.org/projects/wr-cores/wiki/Wrpc_core
-------------------------------------------------------------------------------
-- vxs_wr_ref_top.vhd
-------------------------------------------------------------------------------
--
-- Description: Top-level file for the WRPC reference design on the VXS switch.
--
-------------------------------------------------------------------------------
-- Copyright (c) 2018 CERN
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
use work.wr_vxs_pkg.all;
use work.gn4124_core_pkg.all;

library unisim;
use unisim.vcomponents.all;

entity vxs_wr_ref_top is
  generic (
--     g_dpram_initf : string := "../../bin/wrpc/wrc_phy8.bram";
    g_dpram_initf : string  := "../../../binaries/wrc-VXS-support-v8.bram";
    -- Simulation-mode enable parameter. Set by default (synthesis) to 0, and
    -- changed to non-zero in the instantiation of the top level DUT in the testbench.
    -- Its purpose is to reduce some internal counters/timeouts to speed up simulations.
    g_simulation : integer := 0
  );
  port ( -- port description taken from EDA-02299-V2-VXS-Switch project
        ---------------------------------------------------------------
        -- WR-related IOs
        ---------------------------------------------------------------
        VCXO_MHZ20        : in    std_logic; -- clk_20m_vcxo_i
        VCXO_MHZ125_N     : in    std_logic; -- clk_125m_pllref_p_i
        VCXO_MHZ125_P     : in    std_logic; -- clk_125m_pllref_n_i
        GTP118_CLK_N      : in    std_logic; -- clk_125m_gtp_n_i
        GTP118_CLK_P      : in    std_logic; -- clk_125m_gtp_p_i
        DAC_PLL_SCLK      : out   std_logic; -- plldac_sclk_o
        DAC_PLL_DIN       : out   std_logic; -- plldac_din_o
        DAC_PLL20_SYNC_N  : out   std_logic; -- pll20dac_cs_n_o
        DAC_PLL125_SYNC_N : out   std_logic; -- pll25dac_cs_n_o

        DQ_WR             : inout std_logic; -- 1-wire
        UART_RXD          : in    std_logic; -- uart_rxd_i
        UART_TXD          : out   std_logic; -- uart_txd_o

        -- WR-dedicated SFP
        SFP2FPGA_P        : in std_logic; -- sfp_rxp_i
        SFP2FPGA_N        : in std_logic; -- sfp_rxn_i
        FPGA2SFP_N        : out std_logic;-- sfp_txn_o
        FPGA2SFP_P        : out std_logic;-- sfp_txp_o
        SFP3_PRSNT_N      : in std_logic;
        SFP3_LOS          : in std_logic;
        SFP3_SCL          : inout std_logic;
        SFP3_TX_DIS       : out std_logic;
        SFP3_SDA          : inout std_logic;

        --- backup SFP routred via switch FPGA (unused)
        FPGA2VXS2_N       : out std_logic;
        FPGA2VXS2_P       : out std_logic;
        VXS2FPGA2_N       : in std_logic;
        VXS2FPGA2_P       : in std_logic;
        SFP2_LOS          : in std_logic;
        SFP2_TX_DIS       : out std_logic;
        SFP2_SCL          : inout std_logic;
        SFP2_SDA          : inout std_logic;
        SFP2_PRSNT_N      : in std_logic;

        -- IOs
        FPGA_IO_Z1        : out std_logic;
        FPGA_IO_Z2        : out std_logic;
        FPGA_IO_E1_N      : out std_logic;
        FPGA_IO_E2_N      : out std_logic;
        FPGA_IO_OUT1      : out std_logic;
-- unused         FPGA_IO_OUT2      : out std_logic;
        FPGA_IO_IN1       : in std_logic;
        FPGA_IO_IN2       : in std_logic;

        -- control of SFP's leds
        LED_SFP_SDA       : inout std_logic;
        LED_SFP_SCL       : inout std_logic;
        POR               : in std_logic;


        LED_CLK_R         : out std_logic;
        LED_CLK_G         : out std_logic;

        -- flash
        FRAMMOSI          : out std_logic;
        FRAMSCLK          : out std_logic;
        FRAMWPDIS         : in std_logic; -- write protect input, use for sfp MUX
        FRAMWP_N          : out std_logic;
        FRAMMISO          : in std_logic;
        FRAMCS_N          : out std_logic;


        ---------------------------------------------------------------
        -- other IOs - unused in the WR ref design
        ---------------------------------------------------------------
        SYSRST_N          : in  std_logic;
        PP3_SCL           : in std_logic;
        PP2_SDA           : in std_logic;
        ACE_TDO_I         : in std_logic;
        PP2_SCL           : in std_logic;
        Q_MISO            : in std_logic;
        FP_JTAG_ENA_N     : out std_logic;
        XBAR_DATA         : inout std_logic_vector(7 downto 0 );
        PP1_SDA_I         : in std_logic;
        PP12_SDA          : in std_logic;
        PP12_SCL          : in std_logic;
        GAP_N             : in std_logic;
        XBAR_SET_N        : out std_logic;
        PP11_SDA          : in std_logic;
        PP11_SCL          : in std_logic;
        PP10_SDA          : in std_logic;
        PP10_SCL          : in std_logic;
        HWVERSION         : in std_logic_vector(3 downto 0 );
        GA_N              : in std_logic_vector(4 downto 0 );
        XBAR_RSTRX_N      : out std_logic_vector(1 downto 0 );
        PP9_SDA           : in std_logic;
        XBAR_CS_N         : out std_logic;
        PP9_SCL           : in std_logic;
        XBAR_PERROR       : in std_logic_vector(1 downto 0 );
        PP8_SDA           : in std_logic;
        SFP1_LOS          : in std_logic;
        SFP1_PRSNT_N      : in std_logic;
        PP8_SCL           : in std_logic;
        PP7_SDA           : in std_logic;
        SFP0_LOS          : in std_logic;
        PP7_SCL           : in std_logic;
        PP6_SDA           : in std_logic;
        SFP1_SCL          : inout std_logic;
        XBAR_RST_N        : out std_logic;
        XBAR_LOS          : in std_logic;
        PP6_SCL           : in std_logic;
        XBAR_ADDR         : out std_logic_vector(9 downto 0 );
        SFP1_SDA          : inout std_logic;
        PP5_SDA           : in std_logic;
        SFP0_SCL          : inout std_logic;
        XBAR_DS_N         : out std_logic;
        XBAR_RD           : out std_logic;
        PP5_SCL           : in std_logic;
        SW_SE1            : in std_logic;
        SW_SE2            : in std_logic;
        SW_SE3            : in std_logic;
        SW_SE4            : in std_logic;
        SW_SE5            : in std_logic;
        SW_SE6            : in std_logic;
        SW_SE7            : in std_logic;
        SW_SE8            : in std_logic;
        SFP0_SDA          : inout std_logic;
        PP4_SDA           : in std_logic;
        XBAR_DIS_N        : out std_logic;
        PP4_SCL           : in std_logic;
        PP3_SDA           : in std_logic;
        DQ                : inout std_logic;
        SFP0_PRSNT_N      : in std_logic

        -- pins commeted out in constraints to prevent warnings/errors
--         FPGA2VXS0_N       : out std_logic;
--         FPGA2VXS0_P       : out std_logic;
--         VXS2FPGA0_N       : in std_logic;
--         VXS2FPGA0_P       : in std_logic;
--         FPGA_MHZ100_N     : in std_logic;
--         FPGA_MHZ100_P     : in std_logic;
--         VXS2FPGA1_N       : in std_logic;
--         VXS2FPGA1_P       : in std_logic;
--         FPGA2VXS1_N       : out std_logic;
--         FPGA2VXS1_P       : out std_logic;
--         GTP122_CLK_N      : in std_logic;
--         GTP122_CLK_P      : in std_logic;
--         RF_CLK_FPGA_N     : in std_logic;
--         RF_CLK_FPGA_P     : in std_logic;
--         TAG_FPGA_N        : in std_logic;
--         TAG_FPGA_P        : in std_logic;
--         FPGA_MHZ200_N     : in std_logic;
--         FPGA_MHZ200_P     : in std_logic;
--         FPGA_MHZ50_N      : in std_logic;
--         FPGA_MHZ50_P      : in std_logic;
--         SW_RX_N           : in std_logic;
--         SW_RX_P           : in std_logic;
--         SW_TX_N           : out std_logic;
--         SW_TX_P           : out std_logic;
--         LED_SPARE_R       : out std_logic;
--         LED_SPARE_G       : out std_logic;
--         TESTPORT          : out std_logic_vector(15 downto 4 );
--         PP1_SDA_O_N       : out std_logic;
--         XBAR_SER          : out std_logic;
--         PP1_SCL_I         : in std_logic;
--         ACE_TDI_O         : out std_logic;
--         Q_CS_N            : out std_logic;
--         ACE_TMS_O         : out std_logic;
--         KEEPER            : out std_logic;
--         POWERDOWN         : out std_logic;
--         XBAR_ENRX_N       : out std_logic_vector(1 downto 0 );
--         ACE_TCK_O         : out std_logic;
--         SFP0_TX_DIS       : out std_logic;
--         Q_SCLK            : out std_logic;
--         SFP1_TX_DIS       : out std_logic;
--         PP1_SCL_O_N       : out std_logic;
--         Q_MOSI            : out std_logic;
--         XBAR_ENTX_N       : out std_logic_vector(1 downto 0 );
--         SEL_VXS           : out std_logic
        );
end entity vxs_wr_ref_top;

architecture top of vxs_wr_ref_top is

  -----------------------------------------------------------------------------
  -- Signals
  -----------------------------------------------------------------------------

  -- clock and reset
  signal clk_sys_62m5   : std_logic;
  signal rst_sys_62m5_n : std_logic;
  signal rst_ref_125m_n : std_logic;
  signal clk_ref_125m   : std_logic;
  signal clk_ext_10m    : std_logic;

  -- I2C EEPROM
  signal eeprom_sda_in  : std_logic;
  signal eeprom_sda_out : std_logic;
  signal eeprom_scl_in  : std_logic;
  signal eeprom_scl_out : std_logic;

  -- SFP I2C -> ch0 & ch1
  signal sfp_sda_in,  sfp1_sda_in  : std_logic;
  signal sfp_sda_out, sfp1_sda_out : std_logic;
  signal sfp_scl_in,  sfp1_scl_in  : std_logic;
  signal sfp_scl_out, sfp1_scl_out : std_logic;

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

  -- ChipScope for histogram readout/debugging

  component chipscope_virtex5_icon
  port (
    CONTROL0: inout std_logic_vector(35 downto 0));
  end component;

  component chipscope_virtex5_ila
  port (
    CONTROL: inout std_logic_vector(35 downto 0);
    CLK: in std_logic;
    TRIG0: in std_logic_vector(31 downto 0);
    TRIG1: in std_logic_vector(31 downto 0);
    TRIG2: in std_logic_vector(31 downto 0);
    TRIG3: in std_logic_vector(31 downto 0));
  end component;

  signal CONTROL0, CONTROL1, CONTROL2, CONTROL3 : std_logic_vector(35 downto 0);
  signal TRIG0, TRIG1, TRIG2, TRIG3 : std_logic_vector(31 downto 0);

  signal led_link : std_logic;
  signal led_ack  : std_logic;

  signal SFP3_TX_DIS_out, SFP3_LOS_in : std_logic;
  signal sfp_mux_sel: std_logic;
begin  -- architecture top

  -----------------------------------------------------------------------------
  -- The WR PTP core board package
  -----------------------------------------------------------------------------

  cmp_xwrc_board_vxs : xwrc_board_vxs
    generic map (
      g_simulation                => g_simulation,
      g_with_external_clock_input => FALSE,
      g_gtp_enable_ch0            => 1,
      g_gtp_enable_ch1            => 1,
      g_gtp_mux_enable            => TRUE,
      g_dpram_initf               => g_dpram_initf)
    port map (
      areset_n_i          => std_logic(not POR), -- Power
      areset_edge_n_i     => '1', -- not use
      clk_20m_vcxo_i      => VCXO_MHZ20,
      clk_125m_pllref_p_i => VCXO_MHZ125_P,
      clk_125m_pllref_n_i => VCXO_MHZ125_N,
      clk_125m_gtp_n_i    => GTP118_CLK_N,
      clk_125m_gtp_p_i    => GTP118_CLK_P,

      clk_sys_62m5_o      => clk_sys_62m5,
      clk_ref_125m_o      => clk_ref_125m,
      rst_sys_62m5_n_o    => rst_sys_62m5_n,
      rst_ref_125m_n_o    => rst_ref_125m_n,

      plldac_sclk_o       => DAC_PLL_SCLK,
      plldac_din_o        => DAC_PLL_DIN,
      pll25dac_cs_n_o     => DAC_PLL125_SYNC_N,
      pll20dac_cs_n_o     => DAC_PLL20_SYNC_N,

      -- ch0 : backup
      sfp_txp_o           => FPGA2VXS2_P,
      sfp_txn_o           => FPGA2VXS2_N,
      sfp_rxp_i           => VXS2FPGA2_P,
      sfp_rxn_i           => VXS2FPGA2_N,
      sfp_det_i           => SFP2_PRSNT_N,
      sfp_sda_i           => sfp_sda_in,
      sfp_sda_o           => sfp_sda_out,
      sfp_scl_i           => sfp_scl_in,
      sfp_scl_o           => sfp_scl_out,
      sfp_rate_select_o   => open, -- connect later
      sfp_tx_fault_i      => open,
      sfp_tx_disable_o    => SFP2_TX_DIS,
      sfp_los_i           => SFP2_LOS,

      sfp_mux_sel_i       => sfp_mux_sel,

      -- ch1 : dedicated to WR
      sfp1_txp_o           => FPGA2SFP_P,
      sfp1_txn_o           => FPGA2SFP_N,
      sfp1_rxp_i           => SFP2FPGA_P,
      sfp1_rxn_i           => SFP2FPGA_N,
      sfp1_det_i           => SFP3_PRSNT_N,
      sfp1_sda_i           => sfp1_sda_in,
      sfp1_sda_o           => sfp1_sda_out,
      sfp1_scl_i           => sfp1_scl_in,
      sfp1_scl_o           => sfp1_scl_out,
      sfp1_rate_select_o   => open, -- connect later
      sfp1_tx_fault_i      => open,
      sfp1_tx_disable_o    => SFP3_TX_DIS_out,
      sfp1_los_i           => SFP3_LOS_in,

      eeprom_sda_i        => '1',
      eeprom_sda_o        => open,
      eeprom_scl_i        => '1',
      eeprom_scl_o        => open,

      onewire_i           => onewire_data,
      onewire_oen_o       => onewire_oe,
      -- Uart
      uart_rxd_i          => UART_RXD,
      uart_txd_o          => UART_TXD,

      -- SPI Flash
      flash_sclk_o        => FRAMSCLK,
      flash_ncs_o         => FRAMCS_N,
      flash_mosi_o        => FRAMMOSI,
      flash_miso_i        => FRAMMISO,

      pps_p_o             => wrc_pps_out,
      pps_led_o           => wrc_pps_led,
      led_link_o          => led_link,
      led_act_o           => led_ack
      );

  LED_CLK_G               <= led_link;
  LED_CLK_R               <= led_ack;

  -- Tristates for SFP EEPROM
  -- ch0 - backup
  SFP2_SCL                <= '0' when sfp_scl_out = '0' else 'Z';
  SFP2_SDA                <= '0' when sfp_sda_out = '0' else 'Z';
  sfp_scl_in              <= SFP2_SCL;
  sfp_sda_in              <= SFP2_SDA;
  -- ch1 - dedicated to wr:
  SFP3_SCL                <= '0' when sfp1_scl_out = '0' else 'Z';
  SFP3_SDA                <= '0' when sfp1_sda_out = '0' else 'Z';
  sfp1_scl_in             <= SFP3_SCL;
  sfp1_sda_in             <= SFP3_SDA;

  SFP3_LOS_in             <= SFP3_LOS;
  SFP3_TX_DIS             <= SFP3_TX_DIS_out;

  -- tri-state onewire access
  DQ_WR    <= '0' when (onewire_oe = '1') else 'Z';
  onewire_data <= DQ_WR;

  -- enable JTAG
  FP_JTAG_ENA_N <= '0';

  -- make sure that switch-bar (M21141G-24) is disabled
  XBAR_SET_N   <= '1';
  XBAR_RST_N   <= '0';
  XBAR_CS_N    <= '1';
  XBAR_ADDR    <= (others => '0');
  XBAR_DS_N    <= '1';
  XBAR_RD      <= '1';
  XBAR_RSTRX_N <= "00";
  XBAR_DIS_N   <= '0';

  -- outputs
  FPGA_IO_E1_N <= '0'; -- enable output buffer of IO1 (active low)
  FPGA_IO_E2_N <= '1'; -- enable output buffer of IO2 (active low)
  FPGA_IO_Z1   <= '0'; -- disable terminatin 50 ohm termination (active high)
  FPGA_IO_Z2   <= '0'; -- disable terminatin 50 ohm termination (active high)
  FPGA_IO_OUT1 <= wrc_pps_out;
--   FPGA_IO_OUT2 <= clk_ref_125m; -- not sure output fast-enough

  -- FLASH
  FRAMWP_N <= '1'; -- not write protected

  U_sync_with_clk : gc_sync_ffs
    port map (
      clk_i          => clk_sys_62m5,
      rst_n_i        => rst_sys_62m5_n,
      data_i         => FRAMWPDIS,
      synced_o       => sfp_mux_sel);

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
  CS_ICON : chipscope_virtex5_icon
    port map (
      CONTROL0 => CONTROL0);
  CS_ILA : chipscope_virtex5_ila
    port map (
      CONTROL => CONTROL0,
      CLK     => clk_sys_62m5,
      TRIG0   => TRIG0,
      TRIG1   => TRIG1,
      TRIG2   => TRIG2,
      TRIG3   => TRIG3);

  trig0(0)           <= SFP2_PRSNT_N;
  trig0(1)           <= SFP2_LOS;
  trig0(2)           <= onewire_data;
  trig0(3)           <= led_link;
  trig0(4)           <= led_ack;
  trig0(5)           <= SFP3_PRSNT_N;
  trig0(6)           <= SFP3_LOS;
  trig0(7)           <= SFP3_TX_DIS_out;
  trig0(8)           <= wrc_pps_out;
  trig0(9)           <= wrc_pps_led;
  trig0(10)          <= sfp_mux_sel;
  trig0(11)          <= FRAMWPDIS;

end architecture top;
