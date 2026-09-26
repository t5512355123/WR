#   ---------------------------------------------------------------------------`
#   -- Clocks/resets
#   ---------------------------------------------------------------------------

#   -- Local oscillators
    #Bank 15 VCCO - 2.5 V -- CVPD-922-124.992 MHz PLL reference
set_property PACKAGE_PIN F17 [get_ports clk_125m_dmtd_p_i]
set_property IOSTANDARD LVDS_25 [get_ports clk_125m_dmtd_p_i]
set_property PACKAGE_PIN E17 [get_ports clk_125m_dmtd_n_i]
set_property IOSTANDARD LVDS_25 [get_ports clk_125m_dmtd_n_i]

create_clock -period 8.000 -name clk_125m_dmtd_p_i -waveform {0.000 4.000} [get_ports clk_125m_dmtd_p_i] 
#create_clock -period 8.000 -name clk_125m_dmtd_n_i -waveform {0.000 4.000} [get_ports clk_125m_dmtd_n_i] # AR57109: "Only P side needs constraint"
create_generated_clock -name clk_dmtd -source [get_ports clk_125m_dmtd_p_i] -divide_by 2 [get_pins cmp_xwrc_board_clbv4/clk_dmtd_reg/Q]

    #Bank 116 -- 125.000 MHz GTP reference
set_property PACKAGE_PIN D6 [get_ports clk_125m_gtx_p_i]
set_property PACKAGE_PIN D5 [get_ports clk_125m_gtx_n_i] 

create_clock -period 8.000 -name clk_125m_gtx_p_i -waveform {0.000 4.000} [get_ports clk_125m_gtx_p_i]
#create_clock -period 8.000 -name clk_125m_gtx_n_i -waveform {0.000 4.000} [get_ports clk_125m_gtx_n_i] # AR57109: "Only P side needs constraint"

create_clock -period 16.000 -name RXOUTCLK -waveform {0.000 8.000} [get_pins cmp_xwrc_board_clbv4/cmp_gtx_lp/U_GTX_INST/gtxe2_i/RXOUTCLK]
create_clock -period 16.000 -name TXOUTCLK -waveform {0.000 8.000} [get_pins cmp_xwrc_board_clbv4/cmp_gtx_lp/U_GTX_INST/gtxe2_i/TXOUTCLK]
create_clock -period 100.000 -name dio_clk_p_i -waveform {0.000 50.000} [get_ports dio_clk_p_i]

set_clock_groups -asynchronous \
-group {clk_dmtd } \
-group {clk_125m_dmtd_p_i } \
-group {clk_125m_gtx_p_i } \
-group {RXOUTCLK} \
-group {TXOUTCLK} \
-group {clk_ext_mul } \
-group {dio_clk_p_i}

#   ---------------------------------------------------------------------------
#   -- SPI interface to DACs
#   ---------------------------------------------------------------------------

    #Bank 16 VCCO - 3.3 V
set_property PACKAGE_PIN B15 [get_ports dac_dmtd_din_o]
set_property IOSTANDARD LVCMOS33 [get_ports dac_dmtd_din_o]
set_property PACKAGE_PIN B14 [get_ports dac_dmtd_sclk_o]
set_property IOSTANDARD LVCMOS33 [get_ports dac_dmtd_sclk_o]
set_property PACKAGE_PIN A15 [get_ports dac_dmtd_cs_n_o]
set_property IOSTANDARD LVCMOS33 [get_ports dac_dmtd_cs_n_o]
set_property PACKAGE_PIN A13 [get_ports dac_refclk_din_o]
set_property IOSTANDARD LVCMOS33 [get_ports dac_refclk_din_o]
set_property PACKAGE_PIN A12 [get_ports dac_refclk_sclk_o]
set_property IOSTANDARD LVCMOS33 [get_ports dac_refclk_sclk_o]
set_property PACKAGE_PIN A14 [get_ports dac_refclk_cs_n_o]
set_property IOSTANDARD LVCMOS33 [get_ports dac_refclk_cs_n_o]

#   ---------------------------------------------------------------------------
#   -- SFP I/O for transceiver
#   ---------------------------------------------------------------------------

    #Bank 116
set_property PACKAGE_PIN B5 [get_ports sfp_rxn_i]
set_property PACKAGE_PIN B6 [get_ports sfp_rxp_i]
set_property PACKAGE_PIN A3 [get_ports sfp_txn_o]
set_property PACKAGE_PIN A4 [get_ports sfp_txp_o]

    ##Bank 14 VCCO - 3.3 V  -- sfp detect NOT PRESENT
#set_property PACKAGE_PIN E26 [get_ports sfp_mod_def0_i]
#set_property IOSTANDARD LVCMOS33 [get_ports sfp_mod_def0_i]
    #Bank 14 VCCO - 3.3 V  -- scl
set_property PACKAGE_PIN J26 [get_ports sfp_mod_def1_b]
set_property IOSTANDARD LVCMOS33 [get_ports sfp_mod_def1_b]
    #Bank 14 VCCO - 3.3 V  -- sda
set_property PACKAGE_PIN H26 [get_ports sfp_mod_def2_b]
set_property IOSTANDARD LVCMOS33 [get_ports sfp_mod_def2_b]
    #Bank 14 VCCO - 3.3 V NOT PRESENT
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
# Signal uart_rxd_i is an input in the design and must be connected to pin 21/13 (TXD_SCI) of U26 (CP2105)
# Signal uart_txd_o is an output in the design and must be connected to pin 20/12 (RXD_SCI) of U26 (CP2105)
# Rx signals are pulled down so the USB on the CLB and the USB on the G-Board can be OR-ed
    #Bank 15 VCCO - 2.5 V
set_property PACKAGE_PIN D19 [get_ports uart_rxd_i]
set_property IOSTANDARD LVCMOS25 [get_ports uart_rxd_i]
set_property PULLDOWN true [get_ports uart_rxd_i]
set_property PACKAGE_PIN D20 [get_ports uart_txd_o]
set_property IOSTANDARD LVCMOS25 [get_ports uart_txd_o]

#USB Connection on Test&Debug Connector (J35)
    #Bank 16 VCCO - 3.3 V
#set_property PACKAGE_PIN F13 [get_ports uart_rxd_i]
#set_property IOSTANDARD LVCMOS33 [get_ports uart_rxd_i]
#set_property PULLDOWN true [get_ports uart_rxd_i]
#set_property PACKAGE_PIN F14 [get_ports uart_rxd_i]
#set_property IOSTANDARD LVCMOS33 [get_ports uart_rxd_i]

    #Bank 15 VCCO - 1.8 V
#set_property PACKAGE_PIN B19 [get_ports USB_RX2]
#set_property IOSTANDARD LVCMOS25 [get_ports USB_RX2]
#set_property PULLDOWN true [get_ports USB_RX2]
#set_property PACKAGE_PIN C19 [get_ports USB_TX2]
#set_property IOSTANDARD LVCMOS25 [get_ports USB_TX2]

#USB Connection on Test&Debug Connector (J35)
    #Bank 16 VCCO - 3.3 V
#set_property PACKAGE_PIN C13 [get_ports USBEXT_RX2]
#set_property IOSTANDARD LVCMOS33 [get_ports USBEXT_RX2]
#set_property PULLDOWN true [get_ports USBEXT_RX2]
#set_property PACKAGE_PIN C14 [get_ports USBEXT_TX2]
#set_property IOSTANDARD LVCMOS33 [get_ports USBEXT_TX2]

#   ---------------------------------------------------------------------------
#   -- WATCHDOG
#   ---------------------------------------------------------------------------
set_property PACKAGE_PIN G12 [get_ports WDI]      
set_property IOSTANDARD LVCMOS33 [get_ports WDI]
set_property PACKAGE_PIN F12 [get_ports {WD_SET[0]}]      
set_property IOSTANDARD LVCMOS33 [get_ports {WD_SET[0]}]
set_property PACKAGE_PIN D14 [get_ports {WD_SET[1]}]      
set_property IOSTANDARD LVCMOS33 [get_ports {WD_SET[1]}] 
set_property PACKAGE_PIN D13 [get_ports {WD_SET[2]}]      
set_property IOSTANDARD LVCMOS33 [get_ports {WD_SET[2]}] 

#   ---------------------------------------------------------------------------
#   -- Miscellanous CLBv4 pins
#   ---------------------------------------------------------------------------

  #Bank 15 VCCO - 3.3 V
set_property PACKAGE_PIN C16 [get_ports led_act_o]
set_property IOSTANDARD LVCMOS25 [get_ports led_act_o]
#set_property PACKAGE_PIN C16 [get_ports {GPIO_LED[0]}]
#set_property IOSTANDARD LVCMOS25 [get_ports {GPIO_LED[0]}]
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
set_property PACKAGE_PIN B16 [get_ports led_link_o]
set_property IOSTANDARD LVCMOS25 [get_ports led_link_o]

  #Bank 16 VCCO - 3.3 V
set_property PACKAGE_PIN E11 [get_ports reset_i]
set_property IOSTANDARD LVCMOS33 [get_ports reset_i]

  #Bank 15 VCCO - 2.5 V
set_property PACKAGE_PIN K15 [get_ports suicide]
set_property IOSTANDARD LVCMOS25 [get_ports suicide]

  #Bank 16 VCCO - 3.3 V
set_property PACKAGE_PIN B11 [get_ports test_lemo]
set_property IOSTANDARD LVCMOS33 [get_ports test_lemo]

  #Bank 14 VCCO - 3.3 V  Monitoring signals output on External Debug Connector J35
set_property PACKAGE_PIN D25 [get_ports pps_mon]
set_property IOSTANDARD LVCMOS33 [get_ports pps_mon]
set_property PACKAGE_PIN F23 [get_ports ref_clk_mon]
set_property IOSTANDARD LVCMOS33 [get_ports ref_clk_mon]


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
#   -- Bulls-eye connector outputs
#   ---------------------------------------------------------------------------

#Bank 34 VCCO - 1.8 V -- BullsEye 1
set_property PACKAGE_PIN U6 [get_ports txts_p_o]
set_property IOSTANDARD LVDS [get_ports txts_p_o]
#Bank 34 VCCO - 1.8 V -- BullsEye 2
set_property PACKAGE_PIN U5 [get_ports txts_n_o]
set_property IOSTANDARD LVDS [get_ports txts_n_o]

#Bank 34 VCCO - 1.8 V -- BullsEye 3
set_property PACKAGE_PIN U2 [get_ports rxts_p_o]
set_property IOSTANDARD LVDS [get_ports rxts_p_o]
#Bank 34 VCCO - 1.8 V -- BullsEye 4
set_property PACKAGE_PIN U1 [get_ports rxts_n_o]
set_property IOSTANDARD LVDS [get_ports rxts_n_o]

#Bank 15 VCCO - 2.5 V -- BullsEye 5
set_property PACKAGE_PIN D15 [get_ports clk_ref_62m5_p_o]
set_property IOSTANDARD LVDS_25 [get_ports clk_ref_62m5_p_o]
#Bank 15 VCCO - 2.5 V -- BullsEye 6
set_property PACKAGE_PIN D16 [get_ports clk_ref_62m5_n_o]
set_property IOSTANDARD LVDS_25 [get_ports clk_ref_62m5_n_o]

#Bank 15 VCCO - 2.5 V -- BullsEye 7
set_property PACKAGE_PIN C17 [get_ports pps_p_o]
set_property IOSTANDARD LVDS_25 [get_ports pps_p_o]
#Bank 15 VCCO - 2.5 V -- BullsEye 8
set_property PACKAGE_PIN C18 [get_ports pps_n_o]
set_property IOSTANDARD LVDS_25 [get_ports pps_n_o]

#Bank 34 VCCO - 1.8 V -- BullsEye 12
set_property PACKAGE_PIN V3 [get_ports clk_dmtd_62m5_p_o]
set_property IOSTANDARD LVDS [get_ports clk_dmtd_62m5_p_o]
#Bank 34 VCCO - 1.8 V -- BullsEye 13
set_property PACKAGE_PIN W3 [get_ports clk_dmtd_62m5_n_o]
set_property IOSTANDARD LVDS [get_ports clk_dmtd_62m5_n_o]

#   ---------------------------------------------------------------------------`
#   -- FLASH PROM properties
#   ---------------------------------------------------------------------------

set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property BITSTREAM.CONFIG.SPI_32BIT_ADDR YES [current_design]
