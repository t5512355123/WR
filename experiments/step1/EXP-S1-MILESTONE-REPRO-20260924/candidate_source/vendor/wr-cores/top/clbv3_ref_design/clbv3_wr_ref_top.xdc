#   ---------------------------------------------------------------------------`
#   -- Clocks/resets
#   ---------------------------------------------------------------------------

#   -- Local oscillators
#Bank 15 VCCO - 2.5 V -- CVPD-922-124.992 MHz PLL reference
set_property PACKAGE_PIN J19 [get_ports clk_125m_dmtd_p_i]
set_property IOSTANDARD LVDS_25 [get_ports clk_125m_dmtd_p_i]
set_property PACKAGE_PIN H19 [get_ports clk_125m_dmtd_n_i]
set_property IOSTANDARD LVDS_25 [get_ports clk_125m_dmtd_n_i]

#Bank 15 VCCO - 2.5 V -- FRETHE025 5x25 MHz PLL reference
#set_property PACKAGE_PIN K18 [get_ports clk_125m_dmtd_p_i]
#set_property IOSTANDARD LVDS_25 [get_ports clk_125m_dmtd_p_i]
#set_property PACKAGE_PIN K19 [get_ports clk_125m_dmtd_n_i]
#set_property IOSTANDARD LVDS_25 [get_ports clk_125m_dmtd_n_i]

create_clock -period 8.000 -name clk_125m_dmtd_p_i -waveform {0.000 4.000} [get_ports clk_125m_dmtd_p_i]
#create_clock -period 8.000 -name clk_125m_dmtd_n_i -waveform {0.000 4.000} [get_ports clk_125m_dmtd_n_i]  # AR57109: "Only P side needs constraint"
create_generated_clock -name clk_dmtd -source [get_ports clk_125m_dmtd_p_i] -divide_by 2 [get_pins cmp_xwrc_board_clbv3/cmp_xwrc_platform/gen_default_plls.gen_kintex7_artix7_default_plls.gen_kintex7_artix7_direct_dmtd.clk_dmtd_reg/Q]

#Bank 216 -- 125.000 MHz GTP reference
set_property PACKAGE_PIN F6 [get_ports clk_125m_gtp_p_i]
set_property PACKAGE_PIN E6 [get_ports clk_125m_gtp_n_i]

create_clock -period 8.000 -name clk_125m_gtp_p_i -waveform {0.000 4.000} [get_ports clk_125m_gtp_p_i]
#create_clock -period 8.000 -name clk_125m_gtp_n_i -waveform {0.000 4.000} [get_ports clk_125m_gtp_n_i]  # AR57109: "Only P side needs constraint"

create_clock -period 16.000 -name RXOUTCLK -waveform {0.000 8.000} [get_pins cmp_xwrc_board_clbv3/cmp_xwrc_platform/gen_phy_artix7.cmp_gtp/U_GTP_INST/GT_INST/gtpe2_i/RXOUTCLK]
create_clock -period 16.000 -name TXOUTCLK -waveform {0.000 8.000} [get_pins cmp_xwrc_board_clbv3/cmp_xwrc_platform/gen_phy_artix7.cmp_gtp/U_GTP_INST/GT_INST/gtpe2_i/TXOUTCLK]
create_clock -period 100.000 -name dio_clk_p_i -waveform {0.000 50.000} [get_ports dio_clk_p_i]

set_clock_groups -asynchronous \
-group {clk_sys } \
-group {clk_dmtd } \
-group {clk_125m_dmtd_p_i } \
-group {clk_125m_gtp_p_i } \
-group {RXOUTCLK} \
-group {TXOUTCLK} \
-group {clk_ext_mul } \
-group {dio_clk_p_i}

#   ---------------------------------------------------------------------------
#   -- SPI interface to DACs
#   ---------------------------------------------------------------------------

  #Bank 16 VCCO - 3.3 V
set_property PACKAGE_PIN G21 [get_ports dac_dmtd_din_o]
set_property IOSTANDARD LVCMOS33 [get_ports dac_dmtd_din_o]
set_property PACKAGE_PIN G22 [get_ports dac_dmtd_sclk_o]
set_property IOSTANDARD LVCMOS33 [get_ports dac_dmtd_sclk_o]
set_property PACKAGE_PIN D22 [get_ports dac_dmtd_cs_n_o]
set_property IOSTANDARD LVCMOS33 [get_ports dac_dmtd_cs_n_o]
set_property PACKAGE_PIN E21 [get_ports dac_refclk_din_o]
set_property IOSTANDARD LVCMOS33 [get_ports dac_refclk_din_o]
set_property PACKAGE_PIN D21 [get_ports dac_refclk_sclk_o]
set_property IOSTANDARD LVCMOS33 [get_ports dac_refclk_sclk_o]
set_property PACKAGE_PIN B22 [get_ports dac_refclk_cs_n_o]
set_property IOSTANDARD LVCMOS33 [get_ports dac_refclk_cs_n_o]

#   ---------------------------------------------------------------------------
#   -- SFP I/O for transceiver
#   ---------------------------------------------------------------------------

  #Bank 216
set_property PACKAGE_PIN B4 [get_ports sfp_txp_o]
set_property PACKAGE_PIN A4 [get_ports sfp_txn_o]
set_property PACKAGE_PIN B8 [get_ports sfp_rxp_i]
set_property PACKAGE_PIN A8 [get_ports sfp_rxn_i]

  #Bank 14 VCCO - 3.3 V  -- sfp detect
set_property PACKAGE_PIN W17 [get_ports sfp_mod_def0_i]
set_property IOSTANDARD LVCMOS33 [get_ports sfp_mod_def0_i]
  #Bank 14 VCCO - 3.3 V  -- scl
set_property PACKAGE_PIN AA18 [get_ports sfp_mod_def1_b]
set_property IOSTANDARD LVCMOS33 [get_ports sfp_mod_def1_b]
  #Bank 14 VCCO - 3.3 V  -- sda
set_property PACKAGE_PIN AB18 [get_ports sfp_mod_def2_b]
set_property IOSTANDARD LVCMOS33 [get_ports sfp_mod_def2_b]
  #Bank 14 VCCO - 3.3 V
set_property PACKAGE_PIN AB20 [get_ports sfp_rate_select_o]
set_property IOSTANDARD LVCMOS33 [get_ports sfp_rate_select_o]
  #Bank 14 VCCO - 3.3 V
set_property PACKAGE_PIN R19 [get_ports sfp_tx_fault_i]
set_property IOSTANDARD LVCMOS33 [get_ports sfp_tx_fault_i]
  #Bank 14 VCCO - 3.3 V
set_property PACKAGE_PIN P19 [get_ports sfp_tx_disable_o]
set_property IOSTANDARD LVCMOS33 [get_ports sfp_tx_disable_o]
  #Bank 14 VCCO - 3.3 V
set_property PACKAGE_PIN V17 [get_ports sfp_los_i]
set_property IOSTANDARD LVCMOS33 [get_ports sfp_los_i]

#   ---------------------------------------------------------------------------
#   -- Onewire interface
#   ---------------------------------------------------------------------------

  #Bank 14 VCCO - 3.3 V
set_property PACKAGE_PIN P16 [get_ports onewire_b]
set_property IOSTANDARD LVCMOS33 [get_ports onewire_b]

#   ---------------------------------------------------------------------------
#   -- UART
#   ---------------------------------------------------------------------------

#TEST & DEBUG
# Signal USB_TX is an output in the design and must be connected to pin 20/12 (RXD_I) of U26 (CP2105GM)
# Signal USB_RX is an input in the design and must be connected to pin 21/13 (TXD_O) of U26 (CP2105GM)
# Rx signals are pulled down so the USB on the CLB and the USB on the G-Board can be OR-ed
  #Bank 34 VCCO - 1.8 V
set_property PACKAGE_PIN W6 [get_ports uart_rxd_i]
set_property IOSTANDARD LVCMOS25 [get_ports uart_rxd_i]
set_property PULLDOWN true [get_ports uart_rxd_i]
set_property PACKAGE_PIN W5 [get_ports uart_txd_o]
set_property IOSTANDARD LVCMOS25 [get_ports uart_txd_o]

#USB Connection on Test&Debug Connector (J20)
  #Bank 16 VCCO - 3.3 V
#set_property PACKAGE_PIN D19 [get_ports uart_rxd_i]
#set_property IOSTANDARD LVCMOS33 [get_ports uart_rxd_i]
#set_property PULLDOWN true [get_ports uart_rxd_i]
#set_property PACKAGE_PIN E19 [get_ports uart_rxd_i]
#set_property IOSTANDARD LVCMOS33 [get_ports uart_rxd_i]

  #Bank 34 VCCO - 1.8 V
#set_property PACKAGE_PIN U6 [get_ports USB_RX2]
#set_property IOSTANDARD LVCMOS25 [get_ports USB_RX2]
#set_property PULLDOWN true [get_ports USB_RX2]
#set_property PACKAGE_PIN V5 [get_ports USB_TX2]
#set_property IOSTANDARD LVCMOS25 [get_ports USB_TX2]

#USB Connection on Test&Debug Connector (J20)
  #Bank 16 VCCO - 3.3 V
#set_property PACKAGE_PIN F19 [get_ports USBEXT_RX2]
#set_property IOSTANDARD LVCMOS33 [get_ports USBEXT_RX2]
#set_property PULLDOWN true [get_ports USBEXT_RX2]
#set_property PACKAGE_PIN F20 [get_ports USBEXT_TX2]
#set_property IOSTANDARD LVCMOS33 [get_ports USBEXT_TX2]

#   ---------------------------------------------------------------------------
#   -- Flash memory SPI interface
#   ---------------------------------------------------------------------------

#    flash_sclk_o : out std_logic;
#    flash_ncs_o  : out std_logic;
#    flash_mosi_o : out std_logic;
#    flash_miso_i : in  std_logic;

#   ---------------------------------------------------------------------------
#   -- Miscellanous CLBv3 pins
#   ---------------------------------------------------------------------------

  #Bank 14 VCCO - 3.3 V
#set_property PACKAGE_PIN T20 [get_ports {GPIO_LED[0]}]
#set_property IOSTANDARD LVCMOS33 [get_ports {GPIO_LED[0]}]
set_property PACKAGE_PIN T20 [get_ports led_act_o]
set_property IOSTANDARD LVCMOS33 [get_ports led_act_o]
#set_property PACKAGE_PIN W21 [get_ports {GPIO_LED[1]}]
#set_property IOSTANDARD LVCMOS33 [get_ports {GPIO_LED[1]}]
#set_property PACKAGE_PIN W22 [get_ports {GPIO_LED[2]}]
#set_property IOSTANDARD LVCMOS33 [get_ports {GPIO_LED[2]}]
#set_property PACKAGE_PIN Y21 [get_ports {GPIO_LED[3]}]
#set_property IOSTANDARD LVCMOS33 [get_ports {GPIO_LED[3]}]
#set_property PACKAGE_PIN AA21 [get_ports {GPIO_LED[4]}]
#set_property IOSTANDARD LVCMOS33 [get_ports {GPIO_LED[4]}]
#set_property PACKAGE_PIN AA20 [get_ports {GPIO_LED[5]}]
#set_property IOSTANDARD LVCMOS33 [get_ports {GPIO_LED[5]}]
set_property PACKAGE_PIN AA20 [get_ports led_link_o]
set_property IOSTANDARD LVCMOS33 [get_ports led_link_o]

  #Bank 16 VCCO - 3.3 V
set_property PACKAGE_PIN C18 [get_ports reset_i]
set_property IOSTANDARD LVCMOS33 [get_ports reset_i]

  #Bank 14 VCCO - 3.3 V
set_property PACKAGE_PIN AB21 [get_ports suicide]
set_property IOSTANDARD LVCMOS33 [get_ports suicide]

  #Bank 16 VCCO - 3.3 V
set_property PACKAGE_PIN B20 [get_ports test_lemo]
set_property IOSTANDARD LVCMOS33 [get_ports test_lemo]

  #Bank 16 VCCO - 3.3 V  Monitoring signals output on External Debug Connector J35
set_property PACKAGE_PIN F18 [get_ports pps_mon]
set_property IOSTANDARD LVCMOS33 [get_ports pps_mon]
set_property PACKAGE_PIN E18 [get_ports ref_clk_mon]
set_property IOSTANDARD LVCMOS33 [get_ports ref_clk_mon]

#   ---------------------------------------------------------------------------
#   -- Digital I/O FMC Pins
#   -- used in this design to output WR-aligned 1-PPS (in Slave mode) and input
#   -- 10MHz & 1-PPS from external reference (in GrandMaster mode).
#   ---------------------------------------------------------------------------

#   -- Clock input from LEMO 5 on the mezzanine front panel. Used as 10MHz
#   -- external reference input.
  #CLK1_M2C_P
set_property PACKAGE_PIN R4 [get_ports dio_clk_p_i]
set_property IOSTANDARD LVDS_25 [get_ports dio_clk_p_i]
  #CLK1_M2C_N
set_property PACKAGE_PIN T4 [get_ports dio_clk_n_i]
set_property IOSTANDARD LVDS_25 [get_ports dio_clk_n_i]

#   -- Differential inputs, dio_p_i(N) inputs the current state of I/O (N+1) on
#   -- the mezzanine front panel.
  #LA00_P 
set_property PACKAGE_PIN J22 [get_ports {dio_p_i[4]}]
set_property IOSTANDARD LVDS_25 [get_ports {dio_p_i[4]}]
  #LA00_N 
set_property PACKAGE_PIN H22 [get_ports {dio_n_i[4]}]
set_property IOSTANDARD LVDS_25 [get_ports {dio_n_i[4]}]
  #LA03_P 
set_property PACKAGE_PIN M13 [get_ports {dio_p_i[3]}]
set_property IOSTANDARD LVDS_25 [get_ports {dio_p_i[3]}]
  #LA03_N 
set_property PACKAGE_PIN L13 [get_ports {dio_n_i[3]}]
set_property IOSTANDARD LVDS_25 [get_ports {dio_n_i[3]}]
  #LA16_P 
set_property PACKAGE_PIN T16 [get_ports {dio_p_i[2]}]
set_property IOSTANDARD LVDS_25 [get_ports {dio_p_i[2]}]
  #LA16_N 
set_property PACKAGE_PIN U16 [get_ports {dio_n_i[2]}]
set_property IOSTANDARD LVDS_25 [get_ports {dio_n_i[2]}]
  #LA20_P 
set_property PACKAGE_PIN AA10 [get_ports {dio_p_i[1]}]
set_property IOSTANDARD LVDS_25 [get_ports {dio_p_i[1]}]
  #LA20_N 
set_property PACKAGE_PIN AA11 [get_ports {dio_n_i[1]}]
set_property IOSTANDARD LVDS_25 [get_ports {dio_n_i[1]}]
  #LA33_P 
set_property PACKAGE_PIN R6 [get_ports {dio_p_i[0]}]
set_property IOSTANDARD LVDS_25 [get_ports {dio_p_i[0]}]
  #LA33_N 
set_property PACKAGE_PIN T6 [get_ports {dio_n_i[0]}]
set_property IOSTANDARD LVDS_25 [get_ports {dio_n_i[0]}]


#   -- Differential outputs. When the I/O (N+1) is configured as output (i.e. when
#   -- dio_oe_n_o(N) = 0), the value of dio_p_o(N) determines the logic state
#   -- of I/O (N+1) on the front panel of the mezzanine
  #LA04_P
set_property PACKAGE_PIN M18 [get_ports {dio_p_o[4]}]
set_property IOSTANDARD LVDS_25 [get_ports {dio_p_o[4]}]
  #LA04_N
set_property PACKAGE_PIN L18 [get_ports {dio_n_o[4]}]
set_property IOSTANDARD LVDS_25 [get_ports {dio_n_o[4]}]
  #LA07_P
set_property PACKAGE_PIN N20 [get_ports {dio_p_o[3]}]
set_property IOSTANDARD LVDS_25 [get_ports {dio_p_o[3]}]
  #LA07_N
set_property PACKAGE_PIN M20 [get_ports {dio_n_o[3]}]
set_property IOSTANDARD LVDS_25 [get_ports {dio_n_o[3]}]
  #LA08_P
set_property PACKAGE_PIN N22 [get_ports {dio_p_o[2]}]
set_property IOSTANDARD LVDS_25 [get_ports {dio_p_o[2]}]
  #LA08_N
set_property PACKAGE_PIN M22 [get_ports {dio_n_o[2]}]
set_property IOSTANDARD LVDS_25 [get_ports {dio_n_o[2]}]
  #LA28_P
set_property PACKAGE_PIN AA9 [get_ports {dio_p_o[1]}]
set_property IOSTANDARD LVDS_25 [get_ports {dio_p_o[1]}]
  #LA28_N
set_property PACKAGE_PIN AB10 [get_ports {dio_n_o[1]}]
set_property IOSTANDARD LVDS_25 [get_ports {dio_n_o[1]}]
  #LA29_P
set_property PACKAGE_PIN W11 [get_ports {dio_p_o[0]}]
set_property IOSTANDARD LVDS_25 [get_ports {dio_p_o[0]}]
  #LA29_N
set_property PACKAGE_PIN W12 [get_ports {dio_n_o[0]}]
set_property IOSTANDARD LVDS_25 [get_ports {dio_n_o[0]}]

#   -- Output enable. When dio_oe_n_o(N) is 0, connector (N+1) on the front
#   -- panel is configured as an output.
#LA05_P
set_property PACKAGE_PIN V10 [get_ports {dio_oe_n_o[4]}]
set_property IOSTANDARD LVCMOS25 [get_ports {dio_oe_n_o[4]}]
  #LA11_P
set_property PACKAGE_PIN M15 [get_ports {dio_oe_n_o[3]}]
set_property IOSTANDARD LVCMOS25 [get_ports {dio_oe_n_o[3]}]
  #LA15_N
set_property PACKAGE_PIN W16 [get_ports {dio_oe_n_o[2]}]
set_property IOSTANDARD LVCMOS25 [get_ports {dio_oe_n_o[2]}]
  #LA24_N
set_property PACKAGE_PIN AB13 [get_ports {dio_oe_n_o[1]}]
set_property IOSTANDARD LVCMOS25 [get_ports {dio_oe_n_o[1]}]
  #LA30_P
set_property PACKAGE_PIN G17 [get_ports {dio_oe_n_o[0]}]
set_property IOSTANDARD LVCMOS25 [get_ports {dio_oe_n_o[0]}]

#   -- Termination enable. When dio_term_en_o(N) is 1, connector (N+1) on the front
#   -- panel is 50-ohm terminated
  #LA09_N
set_property PACKAGE_PIN V14 [get_ports {dio_term_en_o[4]}]
set_property IOSTANDARD LVCMOS25 [get_ports {dio_term_en_o[4]}]
  #LA09_P
set_property PACKAGE_PIN V13 [get_ports {dio_term_en_o[3]}]
set_property IOSTANDARD LVCMOS25 [get_ports {dio_term_en_o[3]}]
  #LA05_N
set_property PACKAGE_PIN W10 [get_ports {dio_term_en_o[2]}]
set_property IOSTANDARD LVCMOS25 [get_ports {dio_term_en_o[2]}]
  #LA06_N
set_property PACKAGE_PIN Y12 [get_ports {dio_term_en_o[1]}]
set_property IOSTANDARD LVCMOS25 [get_ports {dio_term_en_o[1]}]
  #LA30_N
set_property PACKAGE_PIN G18 [get_ports {dio_term_en_o[0]}]
set_property IOSTANDARD LVCMOS25 [get_ports {dio_term_en_o[0]}]

#    -- Two LEDs on the mezzanine panel. Only Top one is currently used - to
#    -- blink 1-PPS.
  #LA01_P
set_property PACKAGE_PIN AB11 [get_ports dio_led_top_o]
set_property IOSTANDARD LVCMOS25 [get_ports dio_led_top_o]
  #LA01_N
set_property PACKAGE_PIN AB12 [get_ports dio_led_bot_o]
set_property IOSTANDARD LVCMOS25 [get_ports dio_led_bot_o]

#   -- I2C interface for accessing EEPROM.
  #Bank 14 VCCO - 3.3 V
set_property PACKAGE_PIN V20 [get_ports eeprom_scl_b]
set_property IOSTANDARD LVCMOS33 [get_ports eeprom_scl_b]
set_property PACKAGE_PIN U20 [get_ports eeprom_sda_b]
set_property IOSTANDARD LVCMOS33 [get_ports eeprom_sda_b]

#   ---------------------------------------------------------------------------
#   -- Bulls-eye connector outputs
#   ---------------------------------------------------------------------------

#Bank 15 VCCO - 2.5 V -- BullsEye 1
set_property PACKAGE_PIN H13 [get_ports txts_p_o]
set_property IOSTANDARD LVDS_25 [get_ports txts_p_o]
#Bank 15 VCCO - 2.5 V -- BullsEye 2
set_property PACKAGE_PIN G13 [get_ports txts_n_o]
set_property IOSTANDARD LVDS_25 [get_ports txts_n_o]

#Bank 15 VCCO - 2.5 V -- BullsEye 3
set_property PACKAGE_PIN G15 [get_ports rxts_p_o]
set_property IOSTANDARD LVDS_25 [get_ports rxts_p_o]
#Bank 15 VCCO - 2.5 V -- BullsEye 4
set_property PACKAGE_PIN G16 [get_ports rxts_n_o]
set_property IOSTANDARD LVDS_25 [get_ports rxts_n_o]

#Bank 15 VCCO - 2.5 V -- BullsEye 5
set_property PACKAGE_PIN J15 [get_ports pps_p_o]
set_property IOSTANDARD LVDS_25 [get_ports pps_p_o]
#Bank 15 VCCO - 2.5 V -- BullsEye 6
set_property PACKAGE_PIN H15 [get_ports pps_n_o]
set_property IOSTANDARD LVDS_25 [get_ports pps_n_o]

#Bank 15 VCCO - 2.5 V -- BullsEye 7
set_property PACKAGE_PIN H17 [get_ports clk_ref_62m5_p_o]
set_property IOSTANDARD LVDS_25 [get_ports clk_ref_62m5_p_o]
#Bank 15 VCCO - 2.5 V -- BullsEye 8
set_property PACKAGE_PIN H18 [get_ports clk_ref_62m5_n_o]
set_property IOSTANDARD LVDS_25 [get_ports clk_ref_62m5_n_o]

#Bank 15 VCCO - 2.5 V -- BullsEye 12
set_property PACKAGE_PIN K21 [get_ports clk_dmtd_62m5_p_o]
set_property IOSTANDARD LVDS_25 [get_ports clk_dmtd_62m5_p_o]
#Bank 15 VCCO - 2.5 V -- BullsEye 13
set_property PACKAGE_PIN K22 [get_ports clk_dmtd_62m5_n_o]
set_property IOSTANDARD LVDS_25 [get_ports clk_dmtd_62m5_n_o]

#   ---------------------------------------------------------------------------
#   -- GPIO connector
#   ---------------------------------------------------------------------------
  #Bank ?? VCCO - ?.? V
#set_property PACKAGE_PIN ?? [get_ports {GPIO[1]}]
#set_property IOSTANDARD LVCMOS?? [get_ports {GPIO[1]}]
#set_property PACKAGE_PIN ?? [get_ports {GPIO[2]}]
#set_property IOSTANDARD LVCMOS?? [get_ports {GPIO[2]}]
#set_property PACKAGE_PIN ?? [get_ports {GPIO[3]}]
#set_property IOSTANDARD LVCMOS?? [get_ports {GPIO[3]}]
#set_property PACKAGE_PIN ?? [get_ports {GPIO[4]}]
#set_property IOSTANDARD LVCMOS?? [get_ports {GPIO[4]}]
#set_property PACKAGE_PIN ?? [get_ports {GPIO[5]}]
#set_property IOSTANDARD LVCMOS?? [get_ports {GPIO[5]}]
#set_property PACKAGE_PIN ?? [get_ports {GPIO[6]}]
#set_property IOSTANDARD LVCMOS?? [get_ports {GPIO[6]}]
#set_property PACKAGE_PIN ?? [get_ports {GPIO[7]}]
#set_property IOSTANDARD LVCMOS?? [get_ports {GPIO[7]}]
#set_property PACKAGE_PIN ?? [get_ports {GPIO[8]}]
#set_property IOSTANDARD LVCMOS?? [get_ports {GPIO[8]}]
#set_property PACKAGE_PIN ?? [get_ports {GPIO[9]}]
#set_property IOSTANDARD LVCMOS?? [get_ports {GPIO[9]}]
#set_property PACKAGE_PIN ?? [get_ports {GPIO[10]}]
#set_property IOSTANDARD LVCMOS?? [get_ports {GPIO[10]}]
#set_property PACKAGE_PIN ?? [get_ports {GPIO[11]}]
#set_property IOSTANDARD LVCMOS?? [get_ports {GPIO[11]}]
#set_property PACKAGE_PIN ?? [get_ports {GPIO[12]}]
#set_property IOSTANDARD LVCMOS?? [get_ports {GPIO[12]}]
#set_property PACKAGE_PIN ?? [get_ports {GPIO[13]}]
#set_property IOSTANDARD LVCMOS?? [get_ports {GPIO[13]}]
#set_property PACKAGE_PIN ?? [get_ports {GPIO[14]}]
#set_property IOSTANDARD LVCMOS?? [get_ports {GPIO[14]}]
#set_property PACKAGE_PIN ?? [get_ports {GPIO[15]}]
#set_property IOSTANDARD LVCMOS?? [get_ports {GPIO[15]}]
#set_property PACKAGE_PIN ?? [get_ports {GPIO[16]}]
#set_property IOSTANDARD LVCMOS?? [get_ports {GPIO[16]}]

#FMC SIGNALS CLK LPC
  #Bank 34 VCCO - 2.5 V
#set_property PACKAGE_PIN T5 [get_ports FMC_CLK0_M2C_P]
#set_property IOSTANDARD LVDS_25 [get_ports FMC_CLK0_M2C_P]
#set_property DIFF_TERM TRUE [get_ports FMC_CLK0_M2C_P]
#set_property PACKAGE_PIN T5 [get_ports FMC_CLK0_M2C_N]
#set_property IOSTANDARD LVDS_25 [get_ports FMC_CLK0_M2C_N]
#set_property DIFF_TERM TRUE [get_ports FMC_CLK0_M2C_N]
#set_property PACKAGE_PIN T5 [get_ports FMC_CLK1_M2C_P]
#set_property IOSTANDARD LVDS_25 [get_ports FMC_CLK1_M2C_P]
#set_property DIFF_TERM TRUE [get_ports FMC_CLK1_M2C_P]
#set_property PACKAGE_PIN T5 [get_ports FMC_CLK1_M2C_N]
#set_property IOSTANDARD LVDS_25 [get_ports FMC_CLK1_M2C_N]
#set_property DIFF_TERM TRUE [get_ports FMC_CLK1_M2C_N]

  #Bank 15 VCCO - 2.5 V  FMC_XM105 J1 pin 1
#set_property PACKAGE_PIN J22 [get_ports FMC_LA00_CC_P]
#set_property IOSTANDARD LVDS_25 [get_ports FMC_LA00_CC_P]
#set_property DIFF_TERM TRUE [get_ports FMC_LA00_CC_P]
  #Bank 15 VCCO - 2.5 V  FMC_XM105 J1 pin 3
#set_property PACKAGE_PIN H22 [get_ports FMC_LA00_CC_N]
#set_property IOSTANDARD LVDS_25 [get_ports FMC_LA00_CC_N]
#set_property DIFF_TERM TRUE [get_ports FMC_LA00_CC_N]
  #Bank 13 VCCO - 2.5 V  FMC_XM105 J1 pin 5
#set_property PACKAGE_PIN AB11 [get_ports FMC_LA01_CC_P]
#set_property IOSTANDARD LVDS_25 [get_ports FMC_LA01_CC_P]
#set_property DIFF_TERM TRUE [get_ports FMC_LA01_CC_P]
  #Bank 13 VCCO - 2.5 V  FMC_XM105 J1 pin 7
#set_property PACKAGE_PIN AB12 [get_ports FMC_LA01_CC_N]
#set_property IOSTANDARD LVDS_25 [get_ports FMC_LA01_CC_N]
#set_property DIFF_TERM TRUE [get_ports FMC_LA01_CC_N]
  #Bank 15 VCCO - 2.5 V  FMC_XM105 J1 pin 30
#set_property PACKAGE_PIN J20 [get_ports FMC_LA17_CC_P]
#set_property IOSTANDARD LVDS_25 [get_ports FMC_LA17_CC_P]
#set_property DIFF_TERM TRUE [get_ports FMC_LA17_CC_P]
  #Bank 15 VCCO - 2.5 V  FMC_XM105 J1 pin 32 *
#set_property PACKAGE_PIN J21 [get_ports FMC_LA17_CC_N]
#set_property IOSTANDARD LVDS_25 [get_ports FMC_LA17_CC_N]
#set_property DIFF_TERM TRUE [get_ports FMC_LA17_CC_N]
  #Bank 15 VCCO - 2.5 V  FMC_XM105 J1 pin 34 *
#set_property PACKAGE_PIN L19 [get_ports FMC_LA18_CC_P]
#set_property IOSTANDARD LVDS_25 [get_ports FMC_LA18_CC_P]
#set_property DIFF_TERM TRUE [get_ports FMC_LA18_CC_P]
  #Bank 15 VCCO - 2.5 V  FMC_XM105 J1 pin 36 *
#set_property PACKAGE_PIN L20 [get_ports FMC_LA18_CC_N]
#set_property IOSTANDARD LVDS_25 [get_ports FMC_LA18_CC_N]
#set_property DIFF_TERM TRUE [get_ports FMC_LA18_CC_N]

########################################################

#FMC SIGNALS LPC
  #Bank 14 VCCO - 3.3 V
#set_property PACKAGE_PIN W20 [get_ports FMC_PRSNT_B]
#set_property IOSTANDARD LVCMOS33 [get_ports FMC_PRSNT_B]
  #Bank 15 VCCO - 2.5 V  FMC_XM105 J1 pin 9 *
#set_property PACKAGE_PIN K17 [get_ports FMC_LA02_P]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA02_P]
  #Bank 15 VCCO - 2.5 V  FMC_XM105 J1 pin 11 *
#set_property PACKAGE_PIN J17 [get_ports FMC_LA02_N]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA02_N]
  #Bank 15 VCCO - 2.5 V  FMC_XM105 J1 pin 13
#set_property PACKAGE_PIN M13 [get_ports FMC_LA03_P]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA03_P]
  #Bank 15 VCCO - 2.5 V  FMC_XM105 J1 pin 15
#set_property PACKAGE_PIN L13 [get_ports FMC_LA03_N]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA03_N]
  #Bank 15 VCCO - 2.5 V  FMC_XM105 J1 pin 17
#set_property PACKAGE_PIN M18 [get_ports FMC_LA04_P]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA04_P]
  #Bank 15 VCCO - 2.5 V  FMC_XM105 J1 pin 19
#set_property PACKAGE_PIN L18 [get_ports FMC_LA04_N]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA04_N]
  #Bank 13 VCCO - 2.5 V  FMC_XM105 J1 pin 21
#set_property PACKAGE_PIN V10 [get_ports FMC_LA05_P]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA05_P]
  #Bank 13 VCCO - 2.5 V  FMC_XM105 J1 pin 23
#set_property PACKAGE_PIN W10 [get_ports FMC_LA05_N]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA05_N]
  #Bank 13 VCCO - 2.5 V  FMC_XM105 J1 pin 25 *
#set_property PACKAGE_PIN Y11 [get_ports FMC_LA06_P]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA06_P]
  #Bank 13 VCCO - 2.5 V  FMC_XM105 J1 pin 27
#set_property PACKAGE_PIN Y12 [get_ports FMC_LA06_N]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA06_N]
  #Bank 15 VCCO - 2.5 V  FMC_XM105 J1 pin 29
#set_property PACKAGE_PIN N20 [get_ports FMC_LA07_P]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA07_P]
  #Bank 15 VCCO - 2.5 V  FMC_XM105 J1 pin 31
#set_property PACKAGE_PIN M20 [get_ports FMC_LA07_N]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA07_N]
  #Bank 15 VCCO - 2.5 V  FMC_XM105 J1 pin 33
#set_property PACKAGE_PIN N22 [get_ports FMC_LA08_P]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA08_P]
  #Bank 15 VCCO - 2.5 V  FMC_XM105 J1 pin 35
#set_property PACKAGE_PIN M22 [get_ports FMC_LA08_N]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA08_N]
  #Bank 13 VCCO - 2.5 V  FMC_XM105 J1 pin 37
#set_property PACKAGE_PIN V13 [get_ports FMC_LA09_P]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA09_P]
  #Bank 13 VCCO - 2.5 V  FMC_XM105 J1 pin 39
#set_property PACKAGE_PIN V14 [get_ports FMC_LA09_N]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA09_N]
  #Bank 13 VCCO - 2.5 V  FMC_XM105 J1 pin 2 *
#set_property PACKAGE_PIN W14 [get_ports FMC_LA10_P]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA10_P]
  #Bank 13 VCCO - 2.5 V  FMC_XM105 J1 pin 4 *
#set_property PACKAGE_PIN Y14 [get_ports FMC_LA10_N]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA10_N]
  #Bank 15 VCCO - 2.5 V  FMC_XM105 J1 pin 6
#set_property PACKAGE_PIN M15 [get_ports FMC_LA11_P]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA11_P]
  #Bank 15 VCCO - 2.5 V  FMC_XM105 J1 pin 8 *
#set_property PACKAGE_PIN M16 [get_ports FMC_LA11_N]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA11_N]
  #Bank 15 VCCO - 2.5 V  FMC_XM105 J1 pin 10 *
#set_property PACKAGE_PIN N18 [get_ports FMC_LA12_P]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA12_P]
  #Bank 15 VCCO - 2.5 V  FMC_XM105 J1 pin 12 *
#set_property PACKAGE_PIN N19 [get_ports FMC_LA12_N]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA12_N]
  #Bank 13 VCCO - 2.5 V  FMC_XM105 J1 pin 14 *
#set_property PACKAGE_PIN U15 [get_ports FMC_LA13_P]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA13_P]
  #Bank 13 VCCO - 2.5 V  FMC_XM105 J1 pin 16 *
#set_property PACKAGE_PIN V15 [get_ports FMC_LA13_N]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA13_N]
  #Bank 13 VCCO - 2.5 V  FMC_XM105 J1 pin 18 *
#set_property PACKAGE_PIN T14 [get_ports FMC_LA14_P]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA14_P]
  #Bank 13 VCCO - 2.5 V  FMC_XM105 J1 pin 20 *
#set_property PACKAGE_PIN T15 [get_ports FMC_LA14_N]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA14_N]
  #Bank 13 VCCO - 2.5 V  FMC_XM105 J1 pin 22 *
#set_property PACKAGE_PIN W15 [get_ports FMC_LA15_P]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA15_P]
  #Bank 13 VCCO - 2.5 V  FMC_XM105 J1 pin 24
#set_property PACKAGE_PIN W16 [get_ports FMC_LA15_N]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA15_N]
  #Bank 13 VCCO - 2.5 V  FMC_XM105 J1 pin 26
#set_property PACKAGE_PIN T16 [get_ports FMC_LA16_P]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA16_P]
  #Bank 13 VCCO - 2.5 V  FMC_XM105 J1 pin 28
#set_property PACKAGE_PIN U16 [get_ports FMC_LA16_N]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA16_N]
  #Bank 13 VCCO - 2.5 V  FMC_XM105 J1 pin 38 *
#set_property PACKAGE_PIN Y16 [get_ports FMC_LA19_P]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA19_P]
  #Bank 13 VCCO - 2.5 V  FMC_XM105 J1 pin 40 *
#set_property PACKAGE_PIN AA16 [get_ports FMC_LA19_N]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA19_N]
  #Bank 13 VCCO - 2.5 V
#set_property PACKAGE_PIN AA10 [get_ports FMC_LA20_P]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA20_P]
  #Bank 13 VCCO - 2.5 V
#set_property PACKAGE_PIN AA11 [get_ports FMC_LA20_N]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA20_N]
  #Bank 13 VCCO - 2.5 V
#set_property PACKAGE_PIN Y13 [get_ports FMC_LA21_P]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA21_P]
  #Bank 13 VCCO - 2.5 V
#set_property PACKAGE_PIN AA14 [get_ports FMC_LA21_N]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA21_N]
  #Bank 13 VCCO - 2.5 V
#set_property PACKAGE_PIN AB16 [get_ports FMC_LA22_P]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA22_P]
  #Bank 13 VCCO - 2.5 V
#set_property PACKAGE_PIN AB17 [get_ports FMC_LA22_N]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA22_N]
  #Bank 15 VCCO - 2.5 V
#set_property PACKAGE_PIN K13 [get_ports FMC_LA23_P]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA23_P]
  #Bank 15 VCCO - 2.5 V
#set_property PACKAGE_PIN K14 [get_ports FMC_LA23_N]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA23_N]
  #Bank 13 VCCO - 2.5 V
#set_property PACKAGE_PIN AA13 [get_ports FMC_LA24_P]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA24_P]
  #Bank 13 VCCO - 2.5 V
#set_property PACKAGE_PIN AB13 [get_ports FMC_LA24_N]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA24_N]
  #Bank 13 VCCO - 2.5 V
#set_property PACKAGE_PIN AA15 [get_ports FMC_LA25_P]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA25_P]
  #Bank 13 VCCO - 2.5 V
#set_property PACKAGE_PIN AB15 [get_ports FMC_LA25_N]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA25_N]
  #Bank 15 VCCO - 2.5 V
#set_property PACKAGE_PIN L14 [get_ports FMC_LA26_P]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA26_P]
  #Bank 15 VCCO - 2.5 V
#set_property PACKAGE_PIN L15 [get_ports FMC_LA26_N]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA26_N]
  #Bank 15 VCCO - 2.5 V
#set_property PACKAGE_PIN L16 [get_ports FMC_LA27_P]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA27_P]
  #Bank 15 VCCO - 2.5 V
#set_property PACKAGE_PIN K16 [get_ports FMC_LA27_N]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA27_N]
  #Bank 13 VCCO - 2.5 V
#set_property PACKAGE_PIN AA9 [get_ports FMC_LA28_P]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA28_P]
  #Bank 13 VCCO - 2.5 V
#set_property PACKAGE_PIN AB10 [get_ports FMC_LA28_N]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA28_N]
  #Bank 13 VCCO - 2.5 V
#set_property PACKAGE_PIN W11 [get_ports FMC_LA29_P]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA29_P]
  #Bank 13 VCCO - 2.5 V
#set_property PACKAGE_PIN W12 [get_ports FMC_LA29_N]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA29_N]
  #Bank 15 VCCO - 2.5 V
#set_property PACKAGE_PIN G17 [get_ports FMC_LA30_P]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA30_P]
  #Bank 15 VCCO - 2.5 V
#set_property PACKAGE_PIN G18 [get_ports FMC_LA30_N]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA30_N]
  #Bank 34 VCCO - 2.5 V
#set_property PACKAGE_PIN R3 [get_ports FMC_LA31_P]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA31_P]
  #Bank 34 VCCO - 2.5 V
#set_property PACKAGE_PIN R2 [get_ports FMC_LA31_N]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA31_N]
  #Bank 34 VCCO - 2.5 V
#set_property PACKAGE_PIN W2 [get_ports FMC_LA32_P]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA32_P]
  #Bank 34 VCCO - 2.5 V
#set_property PACKAGE_PIN Y2 [get_ports FMC_LA32_N]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA32_N]
  #Bank 34 VCCO - 2.5 V
#set_property PACKAGE_PIN R6 [get_ports FMC_LA33_P]
#set_property IOSTANDARD LVCMOS25 [get_ports FMC_LA33_P]
  #Bank 34 VCCO - 2.5 V
#set_property PACKAGE_PIN T6 [get_ports FMC_LA33_N]
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
