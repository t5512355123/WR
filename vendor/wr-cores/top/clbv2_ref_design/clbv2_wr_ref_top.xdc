#   ---------------------------------------------------------------------------
#   -- Clocks/resets
#   ---------------------------------------------------------------------------

#   -- Local oscillators
#Bank 14 VCCO - 3.3 V -- 20MHz VCXO clock
set_property PACKAGE_PIN F22 [get_ports clk_20m_vcxo_i]
set_property IOSTANDARD LVCMOS33 [get_ports clk_20m_vcxo_i]

#Bank 116 -- 125 MHz GTX reference
set_property PACKAGE_PIN D6 [get_ports clk_125m_gtx_p_i]
set_property PACKAGE_PIN D5 [get_ports clk_125m_gtx_n_i]

create_clock -period 50.000 -name clk_20m_vcxo_i -waveform {0.000 25.000} [get_ports clk_20m_vcxo_i]
create_clock -period 8.000 -name clk_125m_gtx -waveform {0.000 4.000} [get_ports clk_125m_gtx_p_i]
#create_clock -period 8.000 -name clk_125m_gtx -waveform {0.000 4.000} [get_ports clk_125m_gtx_n_i]  # AR57109: "Only P side needs constraint"

create_clock -period 16.000 -name RXOUTCLK -waveform {0.000 8.000} [get_pins cmp_xwrc_board_clbv2/cmp_gtx_lp/U_GTX_INST/gtxe2_i/RXOUTCLK]
create_clock -period 16.000 -name TXOUTCLK -waveform {0.000 8.000} [get_pins cmp_xwrc_board_clbv2/cmp_gtx_lp/U_GTX_INST/gtxe2_i/TXOUTCLK]
create_clock -period 100.000 -name dio_clk_p_i -waveform {0.000 50.000} [get_ports dio_clk_p_i]

set_clock_groups -asynchronous \
-group clk_20m_vcxo_i \
-group clk_dmtd_pll \
-group clk_125m_gtx \
-group clk_125m_gtx_odiv2 \
-group RXOUTCLK \
-group TXOUTCLK \
-group clk_ext_mul \
-group dio_clk_p_i

#   ---------------------------------------------------------------------------
#   -- SPI interface to DACs
#   ---------------------------------------------------------------------------

  #Bank 16 VCCO - 3.3 V
set_property PACKAGE_PIN A13 [get_ports plldac_din_o]
set_property IOSTANDARD LVCMOS33 [get_ports plldac_din_o]
set_property PACKAGE_PIN A12 [get_ports plldac_sclk_o]
set_property IOSTANDARD LVCMOS33 [get_ports plldac_sclk_o]
set_property PACKAGE_PIN A14 [get_ports pll25dac_cs_n_o]
set_property IOSTANDARD LVCMOS33 [get_ports pll25dac_cs_n_o]
set_property PACKAGE_PIN A15 [get_ports pll20dac_cs_n_o]
set_property IOSTANDARD LVCMOS33 [get_ports pll20dac_cs_n_o]

#   ---------------------------------------------------------------------------
#   -- SFP I/O for transceiver
#   ---------------------------------------------------------------------------

  #Bank 116
set_property PACKAGE_PIN A4 [get_ports sfp_txp_o]
set_property PACKAGE_PIN A3 [get_ports sfp_txn_o]
set_property PACKAGE_PIN B6 [get_ports sfp_rxp_i]
set_property PACKAGE_PIN B5 [get_ports sfp_rxn_i]

  #Bank 14 VCCO - 3.3 V  -- sfp detect
set_property PACKAGE_PIN E26 [get_ports sfp_mod_def0_i]
set_property IOSTANDARD LVCMOS33 [get_ports sfp_mod_def0_i]
  #Bank 14 VCCO - 3.3 V  -- scl
set_property PACKAGE_PIN J26 [get_ports sfp_mod_def1_b]
set_property IOSTANDARD LVCMOS33 [get_ports sfp_mod_def1_b]
  #Bank 14 VCCO - 3.3 V  -- sda
set_property PACKAGE_PIN H26 [get_ports sfp_mod_def2_b]
set_property IOSTANDARD LVCMOS33 [get_ports sfp_mod_def2_b]
  #Bank 14 VCCO - 3.3 V
set_property PACKAGE_PIN G26 [get_ports sfp_rate_select_o]
set_property IOSTANDARD LVCMOS33 [get_ports sfp_rate_select_o]
  #Bank 14 VCCO - 3.3 V
set_property PACKAGE_PIN C26 [get_ports sfp_tx_fault_i]
set_property IOSTANDARD LVCMOS33 [get_ports sfp_tx_fault_i]
  #Bank 14 VCCO - 3.3 V
set_property PACKAGE_PIN D26 [get_ports sfp_tx_disable_o]
set_property IOSTANDARD LVCMOS33 [get_ports sfp_tx_disable_o]
  #Bank 14 VCCO - 3.3 V
set_property PACKAGE_PIN F25 [get_ports sfp_los_i]
set_property IOSTANDARD LVCMOS33 [get_ports sfp_los_i]

#   ---------------------------------------------------------------------------
#   -- Onewire interface
#   ---------------------------------------------------------------------------

  #Bank 14 VCCO - 3.3 V
set_property PACKAGE_PIN L23 [get_ports onewire_b]
set_property IOSTANDARD LVCMOS33 [get_ports onewire_b]

#   ---------------------------------------------------------------------------
#   -- UART
#   ---------------------------------------------------------------------------

#TEST & DEBUG
# Signal USB_TX is an output in the design and must be connected to pin 20/12 (RXD_I) of U34 (CP2105GM)
# Signal USB_RX is an input in the design and must be connected to pin 21/13 (TXD_O) of U34 (CP2105GM)
# Rx signals are pulled down so the USB on the CLB and the USB on the G-Board can be OR-ed
  #Bank 15 VCCO - 2.5 V
set_property PACKAGE_PIN D19 [get_ports uart_rxd_i]
set_property IOSTANDARD LVCMOS25 [get_ports uart_rxd_i]
set_property PULLDOWN true [get_ports uart_rxd_i]
set_property PACKAGE_PIN D20 [get_ports uart_txd_o]
set_property IOSTANDARD LVCMOS25 [get_ports uart_txd_o]

#USB Connection on Test&Debug Connector (J35)
  #Bank 16 VCCO - 3.3 V
#set_property PACKAGE_PIN F14 [get_ports uart_rxd_i]
#set_property IOSTANDARD LVCMOS33 [get_ports uart_rxd_i]
#set_property PULLDOWN true [get_ports uart_rxd_i]
#set_property PACKAGE_PIN F13 [get_ports uart_txd_o]
#set_property IOSTANDARD LVCMOS33 [get_ports uart_txd_o]

  #Bank 15 VCCO - 2.5 V
#set_property PACKAGE_PIN C19 [get_ports USB_RX2]
#set_property IOSTANDARD LVCMOS25 [get_ports USB_RX2]
#set_property PULLDOWN true [get_ports USB_RX2]
#set_property PACKAGE_PIN B19 [get_ports USB_TX2]
#set_property IOSTANDARD LVCMOS25 [get_ports USB_TX2]

#USB Connection on Test&Debug Connector (J35)
  #Bank 16 VCCO - 3.3 V
#set_property PACKAGE_PIN C14 [get_ports USBEXT_RX2]
#set_property IOSTANDARD LVCMOS33 [get_ports USBEXT_RX2]
#set_property PULLDOWN true [get_ports USBEXT_RX2]
#set_property PACKAGE_PIN C13 [get_ports USBEXT_TX2]
#set_property IOSTANDARD LVCMOS33 [get_ports USBEXT_TX2]

#   ---------------------------------------------------------------------------
#   -- Flash memory SPI interface
#   ---------------------------------------------------------------------------

#    flash_sclk_o : out std_logic;
#    flash_ncs_o  : out std_logic;
#    flash_mosi_o : out std_logic;
#    flash_miso_i : in  std_logic;

#   ---------------------------------------------------------------------------
#   -- Miscellaneous clbv2 pins
#   ---------------------------------------------------------------------------

  #Bank 15 VCCO - 2.5 V
#set_property PACKAGE_PIN C16 [get_ports {GPIO_LED[0]}]
#set_property IOSTANDARD LVCMOS25 [get_ports {GPIO_LED[0]}]
set_property PACKAGE_PIN C16 [get_ports led_act_o]
set_property IOSTANDARD LVCMOS25 [get_ports led_act_o]
#set_property PACKAGE_PIN B16 [get_ports {GPIO_LED[1]}]
#set_property IOSTANDARD LVCMOS25 [get_ports {GPIO_LED[1]}]
#set_property PACKAGE_PIN B17 [get_ports {GPIO_LED[2]}]
#set_property IOSTANDARD LVCMOS25 [get_ports {GPIO_LED[2]}]
#set_property PACKAGE_PIN A17 [get_ports {GPIO_LED[3]}]
#set_property IOSTANDARD LVCMOS25 [get_ports {GPIO_LED[3]}]
#set_property PACKAGE_PIN A18 [get_ports {GPIO_LED[4]}]
#set_property IOSTANDARD LVCMOS25 [get_ports {GPIO_LED[4]}]
#set_property PACKAGE_PIN A19 [get_ports {GPIO_LED[5]}]
#set_property IOSTANDARD LVCMOS25 [get_ports {GPIO_LED[5]}]
set_property PACKAGE_PIN A19 [get_ports led_link_o]
set_property IOSTANDARD LVCMOS25 [get_ports led_link_o]

  #Bank 16 VCCO - 3.3 V
set_property PACKAGE_PIN E11 [get_ports reset_i]
set_property IOSTANDARD LVCMOS33 [get_ports reset_i]

  #Bank 15 VCCO - 2.5 V
set_property PACKAGE_PIN K15 [get_ports suicide]
set_property IOSTANDARD LVCMOS25 [get_ports suicide]

  #Bank 16 VCCO - 3.3 V  Enable test-pad TP17, TP18 driver
set_property PACKAGE_PIN B11 [get_ports pll_oe_out_b]
set_property IOSTANDARD LVCMOS33 [get_ports pll_oe_out_b]

  #Bank 15 VCCO - 2.5 V  Monitoring signals output on test-pads and External Debug Connector J35
set_property PACKAGE_PIN C17 [get_ports pps_p]
set_property IOSTANDARD LVDS_25 [get_ports pps_p]
set_property PACKAGE_PIN C18 [get_ports pps_n]
set_property IOSTANDARD LVDS_25 [get_ports pps_n]
set_property PACKAGE_PIN D15 [get_ports ref_clk_p]
set_property IOSTANDARD LVDS_25 [get_ports ref_clk_p]
set_property PACKAGE_PIN D16 [get_ports ref_clk_n]
set_property IOSTANDARD LVDS_25 [get_ports ref_clk_n]

#   ---------------------------------------------------------------------------
#   -- Digital I/O FMC Pins
#   -- used in this design to output WR-aligned 1-PPS (in Slave mode) and input
#   -- 10MHz & 1-PPS from external reference (in GrandMaster mode).
#   ---------------------------------------------------------------------------

#   -- Clock input from LEMO 5 on the mezzanine front panel. Used as 10MHz
#   -- external reference input.
  #CLK1_M2C_P
set_property PACKAGE_PIN Y22 [get_ports dio_clk_p_i]
set_property IOSTANDARD LVDS_25 [get_ports dio_clk_p_i]
  #CLK1_M2C_N
set_property PACKAGE_PIN AA22 [get_ports dio_clk_n_i]
set_property IOSTANDARD LVDS_25 [get_ports dio_clk_n_i]

#   -- Differential inputs, dio_p_i(N) inputs the current state of I/O (N+1) on
#   -- the mezzanine front panel.
  #LA00_P 
set_property PACKAGE_PIN N21 [get_ports {dio_p_i[4]}]
set_property IOSTANDARD LVDS_25 [get_ports {dio_p_i[4]}]
  #LA00_N 
set_property PACKAGE_PIN N22 [get_ports {dio_n_i[4]}]
set_property IOSTANDARD LVDS_25 [get_ports {dio_n_i[4]}]
  #LA03_P 
set_property PACKAGE_PIN P16 [get_ports {dio_p_i[3]}]
set_property IOSTANDARD LVDS_25 [get_ports {dio_p_i[3]}]
  #LA03_N 
set_property PACKAGE_PIN N17 [get_ports {dio_n_i[3]}]
set_property IOSTANDARD LVDS_25 [get_ports {dio_n_i[3]}]
  #LA16_P 
set_property PACKAGE_PIN AB26 [get_ports {dio_p_i[2]}]
set_property IOSTANDARD LVDS_25 [get_ports {dio_p_i[2]}]
  #LA16_N 
set_property PACKAGE_PIN AC26 [get_ports {dio_n_i[2]}]
set_property IOSTANDARD LVDS_25 [get_ports {dio_n_i[2]}]
  #LA20_P 
set_property PACKAGE_PIN K20 [get_ports {dio_p_i[1]}]
set_property IOSTANDARD LVDS_25 [get_ports {dio_p_i[1]}]
  #LA20_N 
set_property PACKAGE_PIN J20 [get_ports {dio_n_i[1]}]
set_property IOSTANDARD LVDS_25 [get_ports {dio_n_i[1]}]
  #LA33_P 
set_property PACKAGE_PIN P19 [get_ports {dio_p_i[0]}]
set_property IOSTANDARD LVDS_25 [get_ports {dio_p_i[0]}]
  #LA33_N 
set_property PACKAGE_PIN P20 [get_ports {dio_n_i[0]}]
set_property IOSTANDARD LVDS_25 [get_ports {dio_n_i[0]}]

#   -- Differential outputs. When the I/O (N+1) is configured as output (i.e. when
#   -- dio_oe_n_o(N) = 0), the value of dio_p_o(N) determines the logic state
#   -- of I/O (N+1) on the front panel of the mezzanine
  #LA04_P
set_property PACKAGE_PIN N18 [get_ports {dio_p_o[4]}]
set_property IOSTANDARD LVDS_25 [get_ports {dio_p_o[4]}]
  #LA04_N
set_property PACKAGE_PIN M19 [get_ports {dio_n_o[4]}]
set_property IOSTANDARD LVDS_25 [get_ports {dio_n_o[4]}]
  #LA07_P
set_property PACKAGE_PIN U19 [get_ports {dio_p_o[3]}]
set_property IOSTANDARD LVDS_25 [get_ports {dio_p_o[3]}]
  #LA07_N
set_property PACKAGE_PIN U20 [get_ports {dio_n_o[3]}]
set_property IOSTANDARD LVDS_25 [get_ports {dio_n_o[3]}]
  #LA08_P
set_property PACKAGE_PIN W20 [get_ports {dio_p_o[2]}]
set_property IOSTANDARD LVDS_25 [get_ports {dio_p_o[2]}]
  #LA08_N
set_property PACKAGE_PIN Y21 [get_ports {dio_n_o[2]}]
set_property IOSTANDARD LVDS_25 [get_ports {dio_n_o[2]}]
  #LA28_P
set_property PACKAGE_PIN M21 [get_ports {dio_p_o[1]}]
set_property IOSTANDARD LVDS_25 [get_ports {dio_p_o[1]}]
  #LA28_N
set_property PACKAGE_PIN M22 [get_ports {dio_n_o[1]}]
set_property IOSTANDARD LVDS_25 [get_ports {dio_n_o[1]}]
  #LA29_P
set_property PACKAGE_PIN N19 [get_ports {dio_p_o[0]}]
set_property IOSTANDARD LVDS_25 [get_ports {dio_p_o[0]}]
  #LA29_N
set_property PACKAGE_PIN M20 [get_ports {dio_n_o[0]}]
set_property IOSTANDARD LVDS_25 [get_ports {dio_n_o[0]}]

#   -- Output enable. When dio_oe_n_o(N) is 0, connector (N+1) on the front
#   -- panel is configured as an output.
#LA05_P
set_property PACKAGE_PIN AE22 [get_ports {dio_oe_n_o[4]}]
set_property IOSTANDARD LVCMOS25 [get_ports {dio_oe_n_o[4]}]
  #LA11_P
set_property PACKAGE_PIN U26 [get_ports {dio_oe_n_o[3]}]
set_property IOSTANDARD LVCMOS25 [get_ports {dio_oe_n_o[3]}]
  #LA15_N
set_property PACKAGE_PIN AB25 [get_ports {dio_oe_n_o[2]}]
set_property IOSTANDARD LVCMOS25 [get_ports {dio_oe_n_o[2]}]
  #LA24_N
set_property PACKAGE_PIN N23 [get_ports {dio_oe_n_o[1]}]
set_property IOSTANDARD LVCMOS25 [get_ports {dio_oe_n_o[1]}]
  #LA30_P
set_property PACKAGE_PIN P24 [get_ports {dio_oe_n_o[0]}]
set_property IOSTANDARD LVCMOS25 [get_ports {dio_oe_n_o[0]}]

#   -- Termination enable. When dio_term_en_o(N) is 1, connector (N+1) on the front
#   -- panel is 50-ohm terminated
  #LA09_N
set_property PACKAGE_PIN P25 [get_ports {dio_term_en_o[4]}]
set_property IOSTANDARD LVCMOS25 [get_ports {dio_term_en_o[4]}]
  #LA09_P
set_property PACKAGE_PIN R25 [get_ports {dio_term_en_o[3]}]
set_property IOSTANDARD LVCMOS25 [get_ports {dio_term_en_o[3]}]
  #LA05_N
set_property PACKAGE_PIN AF22 [get_ports {dio_term_en_o[2]}]
set_property IOSTANDARD LVCMOS25 [get_ports {dio_term_en_o[2]}]
  #LA06_N
set_property PACKAGE_PIN AF25 [get_ports {dio_term_en_o[1]}]
set_property IOSTANDARD LVCMOS25 [get_ports {dio_term_en_o[1]}]
  #LA30_N
set_property PACKAGE_PIN N24 [get_ports {dio_term_en_o[0]}]
set_property IOSTANDARD LVCMOS25 [get_ports {dio_term_en_o[0]}]

#    -- Two LEDs on the mezzanine panel. Only Top one is currently used - to
#    -- blink 1-PPS.
  #LA01_P
set_property PACKAGE_PIN R21 [get_ports dio_led_top_o]
set_property IOSTANDARD LVCMOS25 [get_ports dio_led_top_o]
  #LA01_N
set_property PACKAGE_PIN P21 [get_ports dio_led_bot_o]
set_property IOSTANDARD LVCMOS25 [get_ports dio_led_bot_o]

#   -- I2C interface for accessing EEPROM.
  #Bank 14 VCCO - 3.3 V
set_property PACKAGE_PIN D24 [get_ports eeprom_scl_b]
set_property IOSTANDARD LVCMOS33 [get_ports eeprom_scl_b]
set_property PACKAGE_PIN D23 [get_ports eeprom_sda_b]
set_property IOSTANDARD LVCMOS33 [get_ports eeprom_sda_b]

#   ---------------------------------------------------------------------------
#   -- GPIO connector
#   ---------------------------------------------------------------------------
  #Bank 16 VCCO - 3.3 V
#set_property PACKAGE_PIN H8 [get_ports {GPIO[1]}]
#set_property IOSTANDARD LVCMOS33 [get_ports {GPIO[1]}]
#set_property PACKAGE_PIN J8 [get_ports {GPIO[2]}]
#set_property IOSTANDARD LVCMOS33 [get_ports {GPIO[2]}]
#set_property PACKAGE_PIN G9 [get_ports {GPIO[3]}]
#set_property IOSTANDARD LVCMOS33 [get_ports {GPIO[3]}]
#set_property PACKAGE_PIN H9 [get_ports {GPIO[4]}]
#set_property IOSTANDARD LVCMOS33 [get_ports {GPIO[4]}]
#set_property PACKAGE_PIN F8 [get_ports {GPIO[5]}]
#set_property IOSTANDARD LVCMOS33 [get_ports {GPIO[5]}]
#set_property PACKAGE_PIN G10 [get_ports {GPIO[6]}]
#set_property IOSTANDARD LVCMOS33 [get_ports {GPIO[6]}]
#set_property PACKAGE_PIN F9 [get_ports {GPIO[7]}]
#set_property IOSTANDARD LVCMOS33 [get_ports {GPIO[7]}]
#set_property PACKAGE_PIN F10 [get_ports {GPIO[8]}]
#set_property IOSTANDARD LVCMOS33 [get_ports {GPIO[8]}]
#set_property PACKAGE_PIN D9 [get_ports {GPIO[9]}]
#set_property IOSTANDARD LVCMOS33 [get_ports {GPIO[9]}]
#set_property PACKAGE_PIN D8 [get_ports {GPIO[10]}]
#set_property IOSTANDARD LVCMOS33 [get_ports {GPIO[10]}]
#set_property PACKAGE_PIN B9 [get_ports {GPIO[11]}]
#set_property IOSTANDARD LVCMOS33 [get_ports {GPIO[11]}]
#set_property PACKAGE_PIN C9 [get_ports {GPIO[12]}]
#set_property IOSTANDARD LVCMOS33 [get_ports {GPIO[12]}]
#set_property PACKAGE_PIN A9 [get_ports {GPIO[13]}]
#set_property IOSTANDARD LVCMOS33 [get_ports {GPIO[13]}]
#set_property PACKAGE_PIN A8 [get_ports {GPIO[14]}]
#set_property IOSTANDARD LVCMOS33 [get_ports {GPIO[14]}]
#set_property PACKAGE_PIN A10 [get_ports {GPIO[15]}]
#set_property IOSTANDARD LVCMOS33 [get_ports {GPIO[15]}]
#set_property PACKAGE_PIN B10 [get_ports {GPIO[16]}]
#set_property IOSTANDARD LVCMOS33 [get_ports {GPIO[16]}]

#FMC SIGNALS CLK LPC
  #Bank 12 VCCO - 2.5 V
#set_property PACKAGE_PIN Y23 [get_ports FMC_CLK0_M2C_P]
#set_property IOSTANDARD LVDS_25 [get_ports FMC_CLK0_M2C_P]
#set_property DIFF_TERM TRUE [get_ports FMC_CLK0_M2C_P]
#set_property PACKAGE_PIN AA24 [get_ports FMC_CLK0_M2C_N]
#set_property IOSTANDARD LVDS_25 [get_ports FMC_CLK0_M2C_N]
#set_property DIFF_TERM TRUE [get_ports FMC_CLK0_M2C_N]
#set_property PACKAGE_PIN Y22 [get_ports FMC_CLK1_M2C_P]
#set_property IOSTANDARD LVDS_25 [get_ports FMC_CLK1_M2C_P]
#set_property DIFF_TERM TRUE [get_ports FMC_CLK1_M2C_P]
#set_property PACKAGE_PIN AA22 [get_ports FMC_CLK1_M2C_N]
#set_property IOSTANDARD LVDS_25 [get_ports FMC_CLK1_M2C_N]
#set_property DIFF_TERM TRUE [get_ports FMC_CLK1_M2C_N]

  #Bank 13 VCCO - 2.5 V  FMC_XM105 J1 pin 1
#set_property PACKAGE_PIN N21 [get_ports FMC_LA00_CC_P]
#set_property IOSTANDARD LVDS_25 [get_ports FMC_LA00_CC_P]
#set_property DIFF_TERM TRUE [get_ports FMC_LA00_CC_P]
  #Bank 13 VCCO - 2.5 V  FMC_XM105 J1 pin 3
#set_property PACKAGE_PIN N22 [get_ports FMC_LA00_CC_N]
#set_property IOSTANDARD LVDS_25 [get_ports FMC_LA00_CC_N]
#set_property DIFF_TERM TRUE [get_ports FMC_LA00_CC_N]
  #Bank 13 VCCO - 2.5 V  FMC_XM105 J1 pin 5
#set_property PACKAGE_PIN R21 [get_ports FMC_LA01_CC_P]
#set_property IOSTANDARD LVDS_25 [get_ports FMC_LA01_CC_P]
#set_property DIFF_TERM TRUE [get_ports FMC_LA01_CC_P]
  #Bank 13 VCCO - 2.5 V  FMC_XM105 J1 pin 7
#set_property PACKAGE_PIN P21 [get_ports FMC_LA01_CC_N]
#set_property IOSTANDARD LVDS_25 [get_ports FMC_LA01_CC_N]
#set_property DIFF_TERM TRUE [get_ports FMC_LA01_CC_N]
  #Bank 13 VCCO - 2.5 V  FMC_XM105 J1 pin 30
#set_property PACKAGE_PIN R22 [get_ports FMC_LA17_CC_P]
#set_property IOSTANDARD LVDS_25 [get_ports FMC_LA17_CC_P]
#set_property DIFF_TERM TRUE [get_ports FMC_LA17_CC_P]
  #Bank 13 VCCO - 2.5 V  FMC_XM105 J1 pin 32 *
#set_property PACKAGE_PIN R23 [get_ports FMC_LA17_CC_N]
#set_property IOSTANDARD LVDS_25 [get_ports FMC_LA17_CC_N]
#set_property DIFF_TERM TRUE [get_ports FMC_LA17_CC_N]
  #Bank 12 VCCO - 2.5 V  FMC_XM105 J1 pin 34 *
#set_property PACKAGE_PIN AA23 [get_ports FMC_LA18_CC_P]
#set_property IOSTANDARD LVDS_25 [get_ports FMC_LA18_CC_P]
#set_property DIFF_TERM TRUE [get_ports FMC_LA18_CC_P]
  #Bank 12 VCCO - 2.5 V  FMC_XM105 J1 pin 36 *
#set_property PACKAGE_PIN AB24 [get_ports FMC_LA18_CC_N]
#set_property IOSTANDARD LVDS_25 [get_ports FMC_LA18_CC_N]
#set_property DIFF_TERM TRUE [get_ports FMC_LA18_CC_N]

########################################################

#FMC SIGNALS LPC
  #Bank 14 VCCO - 3.3 V
#set_property PACKAGE_PIN K21 [get_ports FMC_PRSNT_B]
#set_property IOSTANDARD LVCMOS33 [get_ports FMC_PRSNT_B]
  #Bank 15 VCCO - 2.5 V  FMC_XM105 J1 pin 9 *
#set_property PACKAGE_PIN H19 [get_ports FMC_LA02_P]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA02_P]
  #Bank 15 VCCO - 2.5 V  FMC_XM105 J1 pin 11 *
#set_property PACKAGE_PIN G20 [get_ports FMC_LA02_N]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA02_N]
  #Bank 13 VCCO - 2.5 V  FMC_XM105 J1 pin 13
#set_property PACKAGE_PIN P16 [get_ports FMC_LA03_P]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA03_P]
  #Bank 13 VCCO - 2.5 V  FMC_XM105 J1 pin 15
#set_property PACKAGE_PIN N17 [get_ports FMC_LA03_N]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA03_N]
  #Bank 13 VCCO - 2.5 V  FMC_XM105 J1 pin 17
#set_property PACKAGE_PIN N18 [get_ports FMC_LA04_P]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA04_P]
  #Bank 13 VCCO - 2.5 V  FMC_XM105 J1 pin 19
#set_property PACKAGE_PIN M19 [get_ports FMC_LA04_N]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA04_N]
  #Bank 12 VCCO - 2.5 V  FMC_XM105 J1 pin 21
#set_property PACKAGE_PIN AE22 [get_ports FMC_LA05_P]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA05_P]
  #Bank 12 VCCO - 2.5 V  FMC_XM105 J1 pin 23
#set_property PACKAGE_PIN AF22 [get_ports FMC_LA05_N]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA05_N]
  #Bank 12 VCCO - 2.5 V  FMC_XM105 J1 pin 25 *
#set_property PACKAGE_PIN AF24 [get_ports FMC_LA06_P]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA06_P]
  #Bank 12 VCCO - 2.5 V  FMC_XM105 J1 pin 27
#set_property PACKAGE_PIN AF25 [get_ports FMC_LA06_N]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA06_N]
  #Bank 13 VCCO - 2.5 V  FMC_XM105 J1 pin 29
#set_property PACKAGE_PIN U19 [get_ports FMC_LA07_P]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA07_P]
  #Bank 13 VCCO - 2.5 V  FMC_XM105 J1 pin 31
#set_property PACKAGE_PIN U20 [get_ports FMC_LA07_N]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA07_N]
  #Bank 12 VCCO - 2.5 V  FMC_XM105 J1 pin 33
#set_property PACKAGE_PIN W20 [get_ports FMC_LA08_P]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA08_P]
  #Bank 12 VCCO - 2.5 V  FMC_XM105 J1 pin 35
#set_property PACKAGE_PIN Y21 [get_ports FMC_LA08_N]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA08_N]
  #Bank 13 VCCO - 2.5 V  FMC_XM105 J1 pin 37
#set_property PACKAGE_PIN R25 [get_ports FMC_LA09_P]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA09_P]
  #Bank 13 VCCO - 2.5 V  FMC_XM105 J1 pin 39
#set_property PACKAGE_PIN P25 [get_ports FMC_LA09_N]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA09_N]
  #Bank 12 VCCO - 2.5 V  FMC_XM105 J1 pin 2 *
#set_property PACKAGE_PIN U24 [get_ports FMC_LA10_P]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA10_P]
  #Bank 12 VCCO - 2.5 V  FMC_XM105 J1 pin 4 *
#set_property PACKAGE_PIN U25 [get_ports FMC_LA10_N]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA10_N]
  #Bank 12 VCCO - 2.5 V  FMC_XM105 J1 pin 6
#set_property PACKAGE_PIN U26 [get_ports FMC_LA11_P]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA11_P]
  #Bank 12 VCCO - 2.5 V  FMC_XM105 J1 pin 8 *
#set_property PACKAGE_PIN V26 [get_ports FMC_LA11_N]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA11_N]
  #Bank 13 VCCO - 2.5 V  FMC_XM105 J1 pin 10 *
#set_property PACKAGE_PIN R26 [get_ports FMC_LA12_P]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA12_P]
  #Bank 13 VCCO - 2.5 V  FMC_XM105 J1 pin 12 *
#set_property PACKAGE_PIN P26 [get_ports FMC_LA12_N]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA12_N]
  #Bank 12 VCCO - 2.5 V  FMC_XM105 J1 pin 14 *
#set_property PACKAGE_PIN AE23 [get_ports FMC_LA13_P]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA13_P]
  #Bank 12 VCCO - 2.5 V  FMC_XM105 J1 pin 16 *
#set_property PACKAGE_PIN AF23 [get_ports FMC_LA13_N]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA13_N]
  #Bank 12 VCCO - 2.5 V  FMC_XM105 J1 pin 18 *
#set_property PACKAGE_PIN AD23 [get_ports FMC_LA14_P]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA14_P]
  #Bank 12 VCCO - 2.5 V  FMC_XM105 J1 pin 20 *
#set_property PACKAGE_PIN AD24 [get_ports FMC_LA14_N]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA14_N]
  #Bank 12 VCCO - 2.5 V  FMC_XM105 J1 pin 22 *
#set_property PACKAGE_PIN AA25 [get_ports FMC_LA15_P]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA15_P]
  #Bank 12 VCCO - 2.5 V  FMC_XM105 J1 pin 24
#set_property PACKAGE_PIN AB25 [get_ports FMC_LA15_N]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA15_N]
  #Bank 12 VCCO - 2.5 V  FMC_XM105 J1 pin 26
#set_property PACKAGE_PIN AB26 [get_ports FMC_LA16_P]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA16_P]
  #Bank 12 VCCO - 2.5 V  FMC_XM105 J1 pin 28
#set_property PACKAGE_PIN AC26 [get_ports FMC_LA16_N]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA16_N]
  #Bank 12 VCCO - 2.5 V  FMC_XM105 J1 pin 38 *
#set_property PACKAGE_PIN W23 [get_ports FMC_LA19_P]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA19_P]
  #Bank 12 VCCO - 2.5 V  FMC_XM105 J1 pin 40 *
#set_property PACKAGE_PIN W24 [get_ports FMC_LA19_N]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA19_N]
  #Bank 15 VCCO - 2.5 V
#set_property PACKAGE_PIN K20 [get_ports FMC_LA20_P]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA20_P]
  #Bank 15 VCCO - 2.5 V
#set_property PACKAGE_PIN J20 [get_ports FMC_LA20_N]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA20_N]
  #Bank 13 VCCO - 2.5 V
#set_property PACKAGE_PIN M25 [get_ports FMC_LA21_P]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA21_P]
  #Bank 13 VCCO - 2.5 V
#set_property PACKAGE_PIN L25 [get_ports FMC_LA21_N]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA21_N]
  #Bank 15 VCCO - 2.5 V
#set_property PACKAGE_PIN L19 [get_ports FMC_LA22_P]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA22_P]
  #Bank 15 VCCO - 2.5 V
#set_property PACKAGE_PIN L20 [get_ports FMC_LA22_N]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA22_N]
  #Bank 13 VCCO - 2.5 V
#set_property PACKAGE_PIN K25 [get_ports FMC_LA23_P]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA23_P]
  #Bank 13 VCCO - 2.5 V
#set_property PACKAGE_PIN K26 [get_ports FMC_LA23_N]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA23_N]
  #Bank 13 VCCO - 2.5 V
#set_property PACKAGE_PIN P23 [get_ports FMC_LA24_P]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA24_P]
  #Bank 13 VCCO - 2.5 V
#set_property PACKAGE_PIN N23 [get_ports FMC_LA24_N]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA24_N]
  #Bank 13 VCCO - 2.5 V
#set_property PACKAGE_PIN N26 [get_ports FMC_LA25_P]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA25_P]
  #Bank 13 VCCO - 2.5 V
#set_property PACKAGE_PIN M26 [get_ports FMC_LA25_N]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA25_N]
  #Bank 13 VCCO - 2.5 V
#set_property PACKAGE_PIN T22 [get_ports FMC_LA26_P]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA26_P]
  #Bank 13 VCCO - 2.5 V
#set_property PACKAGE_PIN T23 [get_ports FMC_LA26_N]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA26_N]
  #Bank 12 VCCO - 2.5 V
#set_property PACKAGE_PIN V23 [get_ports FMC_LA27_P]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA27_P]
  #Bank 12 VCCO - 2.5 V
#set_property PACKAGE_PIN V24 [get_ports FMC_LA27_N]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA27_N]
  #Bank 13 VCCO - 2.5 V
#set_property PACKAGE_PIN M21 [get_ports FMC_LA28_P]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA28_P]
  #Bank 13 VCCO - 2.5 V
#set_property PACKAGE_PIN M22 [get_ports FMC_LA28_N]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA28_N]
  #Bank 13 VCCO - 2.5 V
#set_property PACKAGE_PIN N19 [get_ports FMC_LA29_P]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA29_P]
  #Bank 13 VCCO - 2.5 V
#set_property PACKAGE_PIN M20 [get_ports FMC_LA29_N]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA29_N]
  #Bank 13 VCCO - 2.5 V
#set_property PACKAGE_PIN P24 [get_ports FMC_LA30_P]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA30_P]
  #Bank 13 VCCO - 2.5 V
#set_property PACKAGE_PIN N24 [get_ports FMC_LA30_N]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA30_N]
  #Bank 13 VCCO - 2.5 V
#set_property PACKAGE_PIN M24 [get_ports FMC_LA31_P]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA31_P]
  #Bank 13 VCCO - 2.5 V
#set_property PACKAGE_PIN L24 [get_ports FMC_LA31_N]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA31_N]
  #Bank 13 VCCO - 2.5 V
#set_property PACKAGE_PIN T20 [get_ports FMC_LA32_P]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA32_P]
  #Bank 13 VCCO - 2.5 V
#set_property PACKAGE_PIN R20 [get_ports FMC_LA32_N]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA32_N]
  #Bank 13 VCCO - 2.5 V
#set_property PACKAGE_PIN P19 [get_ports FMC_LA33_P]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA33_P]
  #Bank 13 VCCO - 2.5 V
#set_property PACKAGE_PIN P20 [get_ports FMC_LA33_N]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA33_N]

#OCTOPUS SMALL
#NET "IIC1_SDA"       LOC =       | IOSTANDARD = LVCMOS33;    #Bank ?? VCCO - ?.? V
#NET "IIC1_SCL"       LOC =       | IOSTANDARD = LVCMOS33;    #Bank ?? VCCO - ?.? V
#NET "EN_SCLK"        LOC =       | IOSTANDARD = LVCMOS33;    #Bank ?? VCCO - ?.? V
#NET "PMT_P[0]"       LOC =       | IOSTANDARD = LVDS | DIFF_TERM = "TRUE";    #Bank ?? VCCO - ?.? V
#NET "PMT_N[0]"       LOC =       | IOSTANDARD = LVDS | DIFF_TERM = "TRUE";    #Bank ?? VCCO - ?.? V
#NET "PMT_P[1]"       LOC =       | IOSTANDARD = LVDS | DIFF_TERM = "TRUE";    #Bank ?? VCCO - ?.? V
#NET "PMT_N[1]"       LOC =       | IOSTANDARD = LVDS | DIFF_TERM = "TRUE";    #Bank ?? VCCO - ?.? V
#NET "PMT_P[2]"       LOC =       | IOSTANDARD = LVDS | DIFF_TERM = "TRUE";    #Bank ?? VCCO - ?.? V
#NET "PMT_N[2]"       LOC =       | IOSTANDARD = LVDS | DIFF_TERM = "TRUE";    #Bank ?? VCCO - ?.? V
#NET "PMT_P[3]"       LOC =       | IOSTANDARD = LVDS | DIFF_TERM = "TRUE";    #Bank ?? VCCO - ?.? V
#NET "PMT_N[3]"       LOC =       | IOSTANDARD = LVDS | DIFF_TERM = "TRUE";    #Bank ?? VCCO - ?.? V
#NET "PMT_P[4]"       LOC =       | IOSTANDARD = LVDS | DIFF_TERM = "TRUE";    #Bank ?? VCCO - ?.? V
#NET "PMT_N[4]"       LOC =       | IOSTANDARD = LVDS | DIFF_TERM = "TRUE";    #Bank ?? VCCO - ?.? V
#NET "PMT_P[5]"       LOC =       | IOSTANDARD = LVDS | DIFF_TERM = "TRUE";    #Bank ?? VCCO - ?.? V
#NET "PMT_N[5]"       LOC =       | IOSTANDARD = LVDS | DIFF_TERM = "TRUE";    #Bank ?? VCCO - ?.? V
#NET "PMT_P[6]"       LOC =       | IOSTANDARD = LVDS | DIFF_TERM = "TRUE";    #Bank ?? VCCO - ?.? V
#NET "PMT_N[6]"       LOC =       | IOSTANDARD = LVDS | DIFF_TERM = "TRUE";    #Bank ?? VCCO - ?.? V
#NET "PMT_P[7]"       LOC =       | IOSTANDARD = LVDS | DIFF_TERM = "TRUE";    #Bank ?? VCCO - ?.? V
#NET "PMT_N[7]"       LOC =       | IOSTANDARD = LVDS | DIFF_TERM = "TRUE";    #Bank ?? VCCO - ?.? V
#NET "PMT_P[8]"       LOC =       | IOSTANDARD = LVDS | DIFF_TERM = "TRUE";    #Bank ?? VCCO - ?.? V
#NET "PMT_N[8]"       LOC =       | IOSTANDARD = LVDS | DIFF_TERM = "TRUE";    #Bank ?? VCCO - ?.? V
#NET "PMT_P[9]"       LOC =       | IOSTANDARD = LVDS | DIFF_TERM = "TRUE";    #Bank ?? VCCO - ?.? V
#NET "PMT_N[9]"       LOC =       | IOSTANDARD = LVDS | DIFF_TERM = "TRUE";    #Bank ?? VCCO - ?.? V
#NET "PMT_P[10]"      LOC =       | IOSTANDARD = LVDS | DIFF_TERM = "TRUE";    #Bank ?? VCCO - ?.? V
#NET "PMT_N[10]"      LOC =       | IOSTANDARD = LVDS | DIFF_TERM = "TRUE";    #Bank ?? VCCO - ?.? V
#NET "PMT_P[11]"      LOC =       | IOSTANDARD = LVDS | DIFF_TERM = "TRUE";    #Bank ?? VCCO - ?.? V
#NET "PMT_N[11]"      LOC =       | IOSTANDARD = LVDS | DIFF_TERM = "TRUE";    #Bank ?? VCCO - ?.? V
#NET "SPMT_SPA0P"     LOC =       | IOSTANDARD = LVDS | DIFF_TERM = "TRUE";    #Bank ?? VCCO - ?.? V
#NET "SPMT_SPA0N"     LOC =       | IOSTANDARD = LVDS | DIFF_TERM = "TRUE";    #Bank ?? VCCO - ?.? V
#NET "SPMT_SPA1P"     LOC =       | IOSTANDARD = LVDS | DIFF_TERM = "TRUE";    #Bank ?? VCCO - ?.? V
#NET "SPMT_SPA1N"     LOC =       | IOSTANDARD = LVDS | DIFF_TERM = "TRUE";    #Bank ?? VCCO - ?.? V
#NET "SPMT_SPA2P"     LOC =       | IOSTANDARD = LVDS | DIFF_TERM = "TRUE";    #Bank ?? VCCO - ?.? V
#NET "SPMT_SPA2N"     LOC =       | IOSTANDARD = LVDS | DIFF_TERM = "TRUE";    #Bank ?? VCCO - ?.? V

#OCTOPUS LARGE
#NET "IIC2_SDA"       LOC =       | IOSTANDARD = LVCMOS33;    #Bank 16 VCCO - ?.? V
#NET "IIC2_SCL"       LOC =       | IOSTANDARD = LVCMOS33;    #Bank 16 VCCO - ?.? V
#NET "EN_LCLK"        LOC =       | IOSTANDARD = LVCMOS33;    #Bank 16 VCCO - ?.? V
#NET "PMT_P[12]"      LOC =       | IOSTANDARD = LVDS | DIFF_TERM = "TRUE";     #Bank ?? VCCO - ?.? V
#NET "PMT_N[12]"      LOC =       | IOSTANDARD = LVDS | DIFF_TERM = "TRUE";     #Bank ?? VCCO - ?.? V
#NET "PMT_P[13]"      LOC =       | IOSTANDARD = LVDS | DIFF_TERM = "TRUE";     #Bank ?? VCCO - ?.? V
#NET "PMT_N[13]"      LOC =       | IOSTANDARD = LVDS | DIFF_TERM = "TRUE";     #Bank ?? VCCO - ?.? V
#NET "PMT_P[14]"      LOC =       | IOSTANDARD = LVDS | DIFF_TERM = "TRUE";     #Bank ?? VCCO - ?.? V
#NET "PMT_N[14]"      LOC =       | IOSTANDARD = LVDS | DIFF_TERM = "TRUE";     #Bank ?? VCCO - ?.? V
#NET "PMT_P[15]"      LOC =       | IOSTANDARD = LVDS | DIFF_TERM = "TRUE";     #Bank ?? VCCO - ?.? V
#NET "PMT_N[15]"      LOC =       | IOSTANDARD = LVDS | DIFF_TERM = "TRUE";     #Bank ?? VCCO - ?.? V
#NET "PMT_P[16]"      LOC =       | IOSTANDARD = LVDS | DIFF_TERM = "TRUE";     #Bank ?? VCCO - ?.? V
#NET "PMT_N[16]"      LOC =       | IOSTANDARD = LVDS | DIFF_TERM = "TRUE";     #Bank ?? VCCO - ?.? V
#NET "PMT_P[17]"      LOC =       | IOSTANDARD = LVDS | DIFF_TERM = "TRUE";     #Bank ?? VCCO - ?.? V
#NET "PMT_N[17]"      LOC =       | IOSTANDARD = LVDS | DIFF_TERM = "TRUE";     #Bank ?? VCCO - ?.? V
#NET "PMT_P[18]"      LOC =       | IOSTANDARD = LVDS | DIFF_TERM = "TRUE";     #Bank ?? VCCO - ?.? V
#NET "PMT_N[18]"      LOC =       | IOSTANDARD = LVDS | DIFF_TERM = "TRUE";     #Bank ?? VCCO - ?.? V
#NET "PMT_P[19]"      LOC =       | IOSTANDARD = LVDS | DIFF_TERM = "TRUE";     #Bank ?? VCCO - ?.? V
#NET "PMT_N[19]"      LOC =       | IOSTANDARD = LVDS | DIFF_TERM = "TRUE";     #Bank ?? VCCO - ?.? V
#NET "PMT_P[20]"      LOC =       | IOSTANDARD = LVDS | DIFF_TERM = "TRUE";     #Bank ?? VCCO - ?.? V
#NET "PMT_N[20]"      LOC =       | IOSTANDARD = LVDS | DIFF_TERM = "TRUE";     #Bank ?? VCCO - ?.? V
#NET "PMT_P[21]"      LOC =       | IOSTANDARD = LVDS | DIFF_TERM = "TRUE";     #Bank ?? VCCO - ?.? V
#NET "PMT_N[21]"      LOC =       | IOSTANDARD = LVDS | DIFF_TERM = "TRUE";     #Bank ?? VCCO - ?.? V
#NET "PMT_P[22]"      LOC =       | IOSTANDARD = LVDS | DIFF_TERM = "TRUE";     #Bank ?? VCCO - ?.? V
#NET "PMT_N[22]"      LOC =       | IOSTANDARD = LVDS | DIFF_TERM = "TRUE";     #Bank ?? VCCO - ?.? V
#NET "PMT_P[23]"      LOC =       | IOSTANDARD = LVDS | DIFF_TERM = "TRUE";     #Bank ?? VCCO - ?.? V
#NET "PMT_N[23]"      LOC =       | IOSTANDARD = LVDS | DIFF_TERM = "TRUE";     #Bank ?? VCCO - ?.? V
#NET "PMT_P[24]"      LOC =       | IOSTANDARD = LVDS | DIFF_TERM = "TRUE";     #Bank ?? VCCO - ?.? V
#NET "PMT_N[24]"      LOC =       | IOSTANDARD = LVDS | DIFF_TERM = "TRUE";     #Bank ?? VCCO - ?.? V
#NET "PMT_P[25]"      LOC =       | IOSTANDARD = LVDS | DIFF_TERM = "TRUE";     #Bank ?? VCCO - ?.? V
#NET "PMT_N[25]"      LOC =       | IOSTANDARD = LVDS | DIFF_TERM = "TRUE";     #Bank ?? VCCO - ?.? V
#NET "PMT_P[26]"      LOC =       | IOSTANDARD = LVDS | DIFF_TERM = "TRUE";     #Bank ?? VCCO - ?.? V
#NET "PMT_N[26]"      LOC =       | IOSTANDARD = LVDS | DIFF_TERM = "TRUE";     #Bank ?? VCCO - ?.? V
#NET "PMT_P[27]"      LOC =       | IOSTANDARD = LVDS | DIFF_TERM = "TRUE";     #Bank ?? VCCO - ?.? V
#NET "PMT_N[27]"      LOC =       | IOSTANDARD = LVDS | DIFF_TERM = "TRUE";     #Bank ?? VCCO - ?.? V
#NET "PMT_P[28]"      LOC =       | IOSTANDARD = LVDS | DIFF_TERM = "TRUE";     #Bank ?? VCCO - ?.? V
#NET "PMT_N[28]"      LOC =       | IOSTANDARD = LVDS | DIFF_TERM = "TRUE";     #Bank ?? VCCO - ?.? V
#NET "PMT_P[29]"      LOC =       | IOSTANDARD = LVDS | DIFF_TERM = "TRUE";     #Bank ?? VCCO - ?.? V
#NET "PMT_N[29]"      LOC =       | IOSTANDARD = LVDS | DIFF_TERM = "TRUE";     #Bank ?? VCCO - ?.? V
#NET "PMT_P[30]"      LOC =       | IOSTANDARD = LVDS | DIFF_TERM = "TRUE";     #Bank ?? VCCO - ?.? V
#NET "PMT_N[30]"      LOC =       | IOSTANDARD = LVDS | DIFF_TERM = "TRUE";     #Bank ?? VCCO - ?.? V

#   ---------------------------------------------------------------------------`
#   -- FLASH PROM properties
#   ---------------------------------------------------------------------------

set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property BITSTREAM.CONFIG.SPI_32BIT_ADDR YES [current_design]
