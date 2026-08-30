-- DE5a White Rabbit Slave top level with a JTAG Wishbone diagnostic mailbox.
-- The WRPC firmware image is generated from vendor/wrpc-sw and loaded by
-- xwr_core's internal RISC-V dual-port RAM.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.wishbone_pkg.all;

entity DE5a_wr_slave_jtag is
  port (
    CLK_50_B2J       : in    std_logic;
    CPU_RESET_n      : in    std_logic;
    BUTTON           : in    std_logic_vector(3 downto 0);
    LED              : out   std_logic_vector(3 downto 0);
    LED_BRACKET      : out   std_logic_vector(3 downto 0);

    QSFPA_INTERRUPT_n : in    std_logic;
    QSFPA_LP_MODE     : out   std_logic;
    QSFPA_MOD_PRS_n   : in    std_logic;
    QSFPA_MOD_SEL_n   : out   std_logic;
    QSFPA_REFCLK_p    : in    std_logic;
    QSFPB_REFCLK_p    : in    std_logic;
    QSFPA_RST_n       : out   std_logic;
    QSFPA_RX_p        : in    std_logic_vector(3 downto 0);
    QSFPA_SCL         : inout std_logic;
    QSFPA_SDA         : inout std_logic;
    QSFPA_TX_p        : out   std_logic_vector(3 downto 0);

    SI5340A_I2C_SCL   : out   std_logic;
    SI5340A_I2C_SDA   : inout std_logic;
    SI5340A_INTR      : in    std_logic;
    SI5340A_OE_n      : out   std_logic;
    SI5340A_RST_n     : out   std_logic;
    SMA_CLKOUT        : out   std_logic;

    -- Board RS422 transceiver pins used to expose the WRPC physical UART.
    RS422_DE          : out   std_logic;
    RS422_DIN         : in    std_logic;
    RS422_DOUT        : out   std_logic;
    RS422_RE_n        : out   std_logic
  );
end DE5a_wr_slave_jtag;

architecture rtl of DE5a_wr_slave_jtag is
  component si5340a_controller_dco is
    generic (
      ENABLE_SAME_CODE_TEST : integer := 0;
      ENABLE_JTAG_HPLL_BURST : integer := 0;
      ENABLE_NORMAL_HPLL_TRACKER : integer := 1;
      ENABLE_STEP5_BOOTSTRAP : integer := 0;
      STEP5_BOOTSTRAP_STEPS : integer := 6336;
      HPLL_TRACKER_CODE_PER_PHYSICAL_STEP : integer := 34;
      JTAG_HPLL_BURST_SIZE : integer := 32
    );
    port (
      iCLK                  : in    std_logic;
      iRST_n                : in    std_logic;
      iStart                : in    std_logic;
      iPLL_OUT0_FREQ_SEL    : in    std_logic_vector(2 downto 0);
      iPLL_OUT1_FREQ_SEL    : in    std_logic_vector(2 downto 0);
      iPLL_OUT2_FREQ_SEL    : in    std_logic_vector(2 downto 0);
      iPLL_OUT3_FREQ_SEL    : in    std_logic_vector(2 downto 0);
      iDPLL_LOAD            : in    std_logic;
      iDPLL_DATA            : in    std_logic_vector(15 downto 0);
      iHPLL_LOAD            : in    std_logic;
      iHPLL_DATA            : in    std_logic_vector(15 downto 0);
      iFORCE_HPLL_ONE_STEP  : in    std_logic;
      iFORCE_HPLL_REVERSE   : in    std_logic;
      iFORCE_HPLL_BURST_SIZE : in   std_logic_vector(15 downto 0);
      I2C_CLK               : out   std_logic;
      I2C_DATA              : inout std_logic;
      oPLL_I2C_ID_READ_ERROR: out   std_logic;
      oPLL_REG_CONFIG_DONE  : out   std_logic;
      oDCO_BUSY             : out   std_logic;
      oDCO_ERROR            : out   std_logic;
      oDCO_STEP_COUNT       : out   std_logic_vector(15 downto 0);
      oDCO_DEBUG            : out   std_logic_vector(63 downto 0);
      oDEBUG_STATIC_STATE   : out   std_logic_vector(7 downto 0);
      oDEBUG_STATIC_CONFIG_DONE_PULSE : out std_logic;
      oDEBUG_STATIC_ACCESS_START : out std_logic;
      oDEBUG_RUNTIME_STATE  : out   std_logic_vector(2 downto 0);
      oDEBUG_BUS_STATE      : out   std_logic;
      oDEBUG_BUS_DONE       : out   std_logic;
      oDEBUG_RUNTIME_START  : out   std_logic;
      oDEBUG_RUNTIME_BUS_ENABLE : out std_logic;
      oDEBUG_SYSTEM_START   : out   std_logic;
      oDCO_STEP5_DEBUG      : out   std_logic_vector(63 downto 0);
      oDCO_STEP5_BURST_DEBUG : out std_logic_vector(63 downto 0);
      oDCO_STEP5_BURST_WIDE_DEBUG : out std_logic_vector(63 downto 0);
      oDCO_STEP5_TRACKER_DEBUG : out std_logic_vector(63 downto 0);
      oDCO_STEP5_BOOTSTRAP_DEBUG : out std_logic_vector(63 downto 0);
      oDCO_STEP5_POSITION_DEBUG : out std_logic_vector(63 downto 0);
      oDCO_STEP5_POSITION_ACCOUNTING_DEBUG : out std_logic_vector(63 downto 0);
      oDCO_STEP5_POLARITY_ACTIVE : out std_logic
    );
  end component;

  component wr_arria10_transceiver is
    generic (
      g_family          : string;
      g_use_atx_pll     : boolean := true;
      g_use_cmu_pll     : boolean := false;
      g_use_simple_wa   : boolean := false;
      g_use_det_phy     : boolean := true;
      g_use_sfp_los_rst : boolean := true;
      g_use_ext_loop    : boolean := true;
      g_use_ext_rst     : boolean := true
    );
    port (
      clk_ref_i              : in  std_logic := '0';
      clk_phy_i              : in  std_logic := '0';
      reconfig_write_i       : in  std_logic_vector(0 downto 0) := (others => '0');
      reconfig_read_i        : in  std_logic_vector(0 downto 0) := (others => '0');
      reconfig_address_i     : in  std_logic_vector(9 downto 0) := (others => '0');
      reconfig_writedata_i   : in  std_logic_vector(31 downto 0) := (others => '0');
      reconfig_readdata_o    : out std_logic_vector(31 downto 0);
      reconfig_waitrequest_o : out std_logic_vector(0 downto 0);
      reconfig_clk_i         : in  std_logic_vector(0 downto 0) := (others => '0');
      reconfig_reset_i       : in  std_logic_vector(0 downto 0) := (others => '0');
      ready_o                : out std_logic;
      drop_link_i            : in  std_logic := '0';
      loopen_i               : in  std_logic := '0';
      sfp_los_i              : in  std_logic := '0';
      tx_clk_o               : out std_logic;
      tx_data_i              : in  std_logic_vector(7 downto 0) := (others => '0');
      tx_ready_o             : out std_logic;
      tx_disparity_o         : out std_logic;
      tx_enc_err_o           : out std_logic;
      tx_data_k_i            : in  std_logic := '0';
      rx_clk_o               : out std_logic;
      rx_data_o              : out std_logic_vector(7 downto 0);
      rx_ready_o             : out std_logic;
      rx_data_k_o            : out std_logic;
      rx_enc_err_o           : out std_logic;
      rx_bitslide_o          : out std_logic_vector(3 downto 0);
      rx_lockedtodata_o      : out std_logic;
      rx_lockedtoref_o       : out std_logic;
      rx_disperr_o           : out std_logic;
      rx_errdetect_o         : out std_logic;
      rx_syncstatus_o        : out std_logic;
      rx_patterndetect_o     : out std_logic;
      rx_patterndetect_ready_o : out std_logic;
      rx_runningdisp_o       : out std_logic;
      debug_o                : out std_logic;
      debug_i                : in  std_logic_vector(7 downto 0) := (others => '0');
      pad_txp_o              : out std_logic;
      pad_rxp_i              : in  std_logic := '0'
    );
  end component;

  component wr_sys_clk_625 is
    port (
      i_clk_50  : in  std_logic;
      i_reset_n : in  std_logic;
      o_clk_625 : out std_logic;
      o_locked  : out std_logic
    );
  end component;

  component altsource_probe is
    generic (
      enable_metastability    : string  := "NO";
      instance_id             : string  := "UNUSED";
      lpm_hint                : string  := "altsource_probe";
      lpm_type                : string  := "altsource_probe";
      probe_width             : natural := 1;
      sld_auto_instance_index : string  := "YES";
      sld_instance_index      : natural := 0;
      source_initial_value    : string  := "0";
      source_width            : natural := 1
    );
    port (
      probe      : in  std_logic_vector(probe_width-1 downto 0);
      source     : out std_logic_vector(source_width-1 downto 0);
      source_clk : in  std_logic := '0';
      source_ena : in  std_logic := '1'
    );
  end component;

  constant SI5340_POWER_DOWN : std_logic_vector(2 downto 0) := "000";
  constant SI5340_125M        : std_logic_vector(2 downto 0) := "110";
  constant SI5340_124M992     : std_logic_vector(2 downto 0) := "111";

  signal si_config_done       : std_logic;
  signal si_id_error          : std_logic;
  signal wr_ready             : std_logic;
  signal wr_tx_ready          : std_logic;
  signal wr_rx_ready          : std_logic;
  signal wr_tx_clk            : std_logic;
  signal wr_rx_clk            : std_logic;
  signal wr_tx_disparity      : std_logic;
  signal wr_tx_enc_err        : std_logic;
  signal wr_rx_enc_err        : std_logic;
  signal wr_rx_data_k         : std_logic;
  signal wr_rx_data           : std_logic_vector(7 downto 0);
  signal wr_rx_bitslide       : std_logic_vector(3 downto 0);
  signal wr_debug             : std_logic;
  signal wr_rx_locked_to_data : std_logic;
  signal wr_rx_locked_to_ref  : std_logic;
  signal wr_rx_disperr        : std_logic;
  signal wr_rx_errdetect      : std_logic;
  signal wr_rx_syncstatus     : std_logic;
  signal wr_rx_patterndetect  : std_logic;
  signal wr_rx_pattern_ready  : std_logic;
  signal wr_rx_runningdisp    : std_logic;

  signal core_tx_data         : std_logic_vector(7 downto 0);
  signal core_tx_k            : std_logic_vector(0 downto 0);
  signal core_phy_rst         : std_logic;
  signal core_phy_loopen      : std_logic;
  signal core_phy_tx_disable  : std_logic;
  signal core_tm_link_up      : std_logic;
  signal core_tm_time_valid   : std_logic;
  signal core_pps_valid       : std_logic;
  signal core_link_ok         : std_logic;
  signal cpu_pc               : std_logic_vector(31 downto 0);
  signal cpu_reset            : std_logic;
  signal cpu_software_reset   : std_logic;
  signal cpu_fault            : std_logic;
  signal cpu_im_valid         : std_logic;
  signal cpu_boot_stage_value : std_logic_vector(31 downto 0);
  signal cpu_boot_stage_seen  : std_logic;
  signal cpu_entry_p          : std_logic_vector(31 downto 0);
  signal cpu_entry_generation : std_logic_vector(31 downto 0);
  signal cpu_last_store_addr  : std_logic_vector(31 downto 0);
  signal cpu_last_store_data  : std_logic_vector(31 downto 0);
  signal cpu_last_store_seen  : std_logic;
  signal cpu_internal_store_count : std_logic_vector(31 downto 0);
  signal cpu_mepc              : std_logic_vector(31 downto 0);
  signal cpu_mcause            : std_logic_vector(31 downto 0);
  signal sync_probe           : std_logic_vector(63 downto 0);
  signal dco_probe            : std_logic_vector(63 downto 0);
  signal dco_debug            : std_logic_vector(63 downto 0);
  signal dco_step5_debug_probe : std_logic_vector(63 downto 0);
  signal dco_step5_burst_debug_probe : std_logic_vector(63 downto 0);
  signal dco_step5_burst_wide_debug_probe : std_logic_vector(63 downto 0);
  signal dco_step5_tracker_debug_probe : std_logic_vector(63 downto 0);
  signal dco_step5_bootstrap_debug_probe : std_logic_vector(63 downto 0);
  signal dco_step5_position_debug_probe : std_logic_vector(63 downto 0);
  signal dco_step5_position_accounting_debug_probe : std_logic_vector(63 downto 0);
  signal step5_polarity_probe : std_logic_vector(63 downto 0);
  signal step5_polarity_source : std_logic_vector(0 downto 0);
  signal step5_burst_size_source : std_logic_vector(15 downto 0);
  signal step5_polarity_active : std_logic;
  signal clock_activity_probe : std_logic_vector(63 downto 0);
  signal ref_activity_div     : unsigned(7 downto 0) := (others => '0');
  signal dmtd_activity_div    : unsigned(7 downto 0) := (others => '0');
  signal rx_activity_div      : unsigned(7 downto 0) := (others => '0');
  signal ref_activity_toggle  : std_logic := '0';
  signal dmtd_activity_toggle : std_logic := '0';
  signal rx_activity_toggle   : std_logic := '0';
  signal ref_activity_meta    : std_logic := '0';
  signal ref_activity_sync    : std_logic := '0';
  signal ref_activity_prev    : std_logic := '0';
  signal dmtd_activity_meta   : std_logic := '0';
  signal dmtd_activity_sync   : std_logic := '0';
  signal dmtd_activity_prev   : std_logic := '0';
  signal rx_activity_meta     : std_logic := '0';
  signal rx_activity_sync     : std_logic := '0';
  signal rx_activity_prev     : std_logic := '0';
  signal ref_activity_count   : unsigned(15 downto 0) := (others => '0');
  signal dmtd_activity_count  : unsigned(15 downto 0) := (others => '0');
  signal rx_activity_count    : unsigned(15 downto 0) := (others => '0');
  signal core_wb_i            : t_wishbone_slave_in;
  signal core_wb_o            : t_wishbone_slave_out;
  signal sync_source          : std_logic_vector(0 downto 0);
  signal force_hpll_source    : std_logic_vector(0 downto 0);
  signal cpu_debug_probe      : std_logic_vector(63 downto 0);
  signal cpu_debug_source     : std_logic_vector(0 downto 0);
  signal cpu_marker_probe     : std_logic_vector(63 downto 0);
  signal cpu_marker_source    : std_logic_vector(0 downto 0);
  signal cpu_entry_probe      : std_logic_vector(63 downto 0);
  signal cpu_store_probe       : std_logic_vector(63 downto 0);
  signal cpu_store_source      : std_logic_vector(0 downto 0);
  signal cpu_store_count_probe : std_logic_vector(63 downto 0);
  signal cpu_store_count_source : std_logic_vector(0 downto 0);
  signal cpu_exception_probe   : std_logic_vector(63 downto 0);
  signal cpu_exception_source  : std_logic_vector(0 downto 0);
  signal reset_sticky_probe    : std_logic_vector(63 downto 0);
  signal reset_sticky_source   : std_logic_vector(0 downto 0);
  signal reset_diag_armed      : std_logic := '0';
  signal reset_diag_arm_count  : unsigned(7 downto 0) := (others => '0');
  signal cpu_reset_seen        : std_logic := '0';
  signal wr_core_reset_seen    : std_logic := '0';
  signal external_reset_seen   : std_logic := '0';
  signal si_config_drop_seen   : std_logic := '0';
  signal sys_pll_drop_seen     : std_logic := '0';
  signal software_reset_seen   : std_logic := '0';
  signal phy_reset_seen        : std_logic := '0';
  signal wr_ready_drop_seen    : std_logic := '0';
  signal cpu_reset_count       : unsigned(7 downto 0) := (others => '0');
  signal wr_core_reset_count   : unsigned(7 downto 0) := (others => '0');
  signal external_reset_count  : unsigned(7 downto 0) := (others => '0');
  signal si_config_drop_count  : unsigned(7 downto 0) := (others => '0');
  signal sys_pll_drop_count    : unsigned(7 downto 0) := (others => '0');
  signal software_reset_count  : unsigned(7 downto 0) := (others => '0');
  signal cpu_reset_meta        : std_logic := '0';
  signal cpu_reset_sync        : std_logic := '0';
  signal cpu_reset_prev        : std_logic := '0';
  signal wr_core_reset_meta    : std_logic := '0';
  signal wr_core_reset_sync    : std_logic := '0';
  signal wr_core_reset_prev    : std_logic := '0';
  signal external_reset_meta   : std_logic := '0';
  signal external_reset_sync   : std_logic := '0';
  signal external_reset_prev   : std_logic := '0';
  signal si_config_drop_meta   : std_logic := '0';
  signal si_config_drop_sync   : std_logic := '0';
  signal si_config_drop_prev   : std_logic := '0';
  signal sys_pll_drop_meta     : std_logic := '0';
  signal sys_pll_drop_sync     : std_logic := '0';
  signal sys_pll_drop_prev     : std_logic := '0';
  signal software_reset_meta   : std_logic := '0';
  signal software_reset_sync   : std_logic := '0';
  signal software_reset_prev   : std_logic := '0';
  signal cpu_reset_event       : std_logic;
  signal wr_core_reset_event   : std_logic;
  signal external_reset_event  : std_logic;
  signal si_config_drop_event  : std_logic;
  signal sys_pll_drop_event    : std_logic;
  signal software_reset_event  : std_logic;
  signal phy_reset_event       : std_logic;
  signal wr_ready_drop_event   : std_logic;
  signal cpu_data_diag_addr_payload : std_logic_vector(63 downto 0);
  signal cpu_data_diag_meta_payload : std_logic_vector(63 downto 0);
  signal cpu_data_diag_addr_probe : std_logic_vector(63 downto 0);
  signal cpu_data_diag_meta_probe : std_logic_vector(63 downto 0);
  signal cpu_ram_diag_addr_payload : std_logic_vector(63 downto 0);
  signal cpu_ram_diag_q_payload : std_logic_vector(63 downto 0);
  signal cpu_ram_diag_meta_payload : std_logic_vector(63 downto 0);
  signal cpu_ram_diag_q0_payload : std_logic_vector(63 downto 0);
  signal cpu_ram_diag_addr_probe : std_logic_vector(63 downto 0);
  signal cpu_ram_diag_q_probe : std_logic_vector(63 downto 0);
  signal cpu_ram_diag_meta_probe : std_logic_vector(63 downto 0);
  signal cpu_ram_diag_q0_probe : std_logic_vector(63 downto 0);
  signal cpu_ram_init_diag_payload0 : std_logic_vector(63 downto 0);
  signal cpu_ram_init_diag_payload1 : std_logic_vector(63 downto 0);
  signal cpu_ram_init_diag_payload2 : std_logic_vector(63 downto 0);
  signal cpu_ram_init_diag_payload3 : std_logic_vector(63 downto 0);
  signal cpu_ram_init_diag_meta_payload : std_logic_vector(63 downto 0);
  signal cpu_ram_init_diag_probe0 : std_logic_vector(63 downto 0);
  signal cpu_ram_init_diag_probe1 : std_logic_vector(63 downto 0);
  signal cpu_ram_init_diag_probe2 : std_logic_vector(63 downto 0);
  signal cpu_ram_init_diag_probe3 : std_logic_vector(63 downto 0);
  signal cpu_ram_init_diag_meta_probe : std_logic_vector(63 downto 0);
  signal cpu_ram_primitive_diag_payload0 : std_logic_vector(63 downto 0);
  signal cpu_ram_primitive_diag_payload1 : std_logic_vector(63 downto 0);
  signal cpu_ram_primitive_diag_meta_payload : std_logic_vector(63 downto 0);
  signal cpu_ram_primitive_diag_probe0 : std_logic_vector(63 downto 0);
  signal cpu_ram_primitive_diag_probe1 : std_logic_vector(63 downto 0);
  signal cpu_ram_primitive_diag_meta_probe : std_logic_vector(63 downto 0);
  signal cpu_ram_port_a_diag_payload0 : std_logic_vector(63 downto 0);
  signal cpu_ram_port_a_diag_payload1 : std_logic_vector(63 downto 0);
  signal cpu_ram_port_a_diag_meta_payload : std_logic_vector(63 downto 0);
  signal cpu_ram_port_a_diag_probe0 : std_logic_vector(63 downto 0);
  signal cpu_ram_port_a_diag_probe1 : std_logic_vector(63 downto 0);
  signal cpu_ram_port_a_diag_meta_probe : std_logic_vector(63 downto 0);
  signal dac_hpll_load        : std_logic;
  signal dac_hpll_data        : std_logic_vector(15 downto 0);
  signal dac_dpll_load        : std_logic;
  signal dac_dpll_data        : std_logic_vector(15 downto 0);
  signal dac_hpll_count       : unsigned(11 downto 0) := (others => '0');
  signal dac_dpll_count       : unsigned(11 downto 0) := (others => '0');
  signal uart_txd              : std_logic := '1';
  signal uart_txd_prev         : std_logic := '1';
  signal sfp_scl_prev          : std_logic := '1';
  signal uart_toggle_count     : unsigned(7 downto 0) := (others => '0');
  signal sfp_scl_toggle_count  : unsigned(7 downto 0) := (others => '0');
  signal dco_busy              : std_logic;
  signal dco_error             : std_logic;
  signal dco_step_count        : std_logic_vector(15 downto 0);
  signal dco_static_state       : std_logic_vector(7 downto 0);
  signal dco_static_done_pulse  : std_logic;
  signal dco_static_access_start : std_logic;
  signal dco_runtime_state      : std_logic_vector(2 downto 0);
  signal dco_bus_state          : std_logic;
  signal dco_bus_done           : std_logic;
  signal dco_runtime_start      : std_logic;
  signal dco_runtime_bus_enable : std_logic;
  signal dco_system_start       : std_logic;

  signal si_corr_probe0         : std_logic_vector(63 downto 0);
  signal si_corr_probe1         : std_logic_vector(63 downto 0);
  signal si_corr_probe2         : std_logic_vector(63 downto 0);
  signal si_corr_probe3         : std_logic_vector(63 downto 0);
  signal si_corr_probe4         : std_logic_vector(63 downto 0);
  signal si_corr_probe5         : std_logic_vector(63 downto 0);
  signal si_corr_probe6         : std_logic_vector(63 downto 0);
  signal si_corr_probe7         : std_logic_vector(63 downto 0);
  signal si_corr_source0        : std_logic_vector(0 downto 0);
  signal si_corr_source1        : std_logic_vector(0 downto 0);
  signal si_corr_source2        : std_logic_vector(0 downto 0);
  signal si_corr_source3        : std_logic_vector(0 downto 0);
  signal si_corr_source4        : std_logic_vector(0 downto 0);
  signal si_corr_source5        : std_logic_vector(0 downto 0);
  signal si_corr_source6        : std_logic_vector(0 downto 0);
  signal si_corr_source7        : std_logic_vector(0 downto 0);
  signal si_corr_timestamp      : unsigned(31 downto 0) := (others => '0');
  signal si_corr_post_arm_count : unsigned(17 downto 0) := (others => '0');
  signal si_corr_post_armed     : std_logic := '0';
  signal si_corr_startup_system_start : unsigned(31 downto 0) := (others => '0');
  signal si_corr_startup_static_complete : unsigned(31 downto 0) := (others => '0');
  signal si_corr_post_arm_timestamp : unsigned(31 downto 0) := (others => '0');
  signal si_corr_startup_ready_final : std_logic := '0';
  signal si_corr_static_prev    : std_logic_vector(7 downto 0) := (others => '0');
  signal si_corr_ready_prev     : std_logic := '0';
  signal si_corr_config_prev    : std_logic := '0';
  signal si_corr_wr_reset_prev  : std_logic := '0';
  signal si_corr_cpu_reset_prev : std_logic := '0';
  signal si_corr_t_dac_load     : unsigned(31 downto 0) := (others => '0');
  signal si_corr_t_runtime_start : unsigned(31 downto 0) := (others => '0');
  signal si_corr_t_bus_done     : unsigned(31 downto 0) := (others => '0');
  signal si_corr_t_static_done  : unsigned(31 downto 0) := (others => '0');
  signal si_corr_t_state_leave  : unsigned(31 downto 0) := (others => '0');
  signal si_corr_t_ready_drop   : unsigned(31 downto 0) := (others => '0');
  signal si_corr_t_config_drop  : unsigned(31 downto 0) := (others => '0');
  signal si_corr_t_wr_reset     : unsigned(31 downto 0) := (others => '0');
  signal si_corr_t_cpu_reset    : unsigned(31 downto 0) := (others => '0');
  signal si_corr_t_system_start : unsigned(31 downto 0) := (others => '0');
  signal si_corr_static_before  : std_logic_vector(7 downto 0) := (others => '0');
  signal si_corr_static_after   : std_logic_vector(7 downto 0) := (others => '0');

  signal reconfig_read        : std_logic_vector(0 downto 0) := (others => '0');
  signal reconfig_write       : std_logic_vector(0 downto 0) := (others => '0');
  signal reconfig_address     : std_logic_vector(9 downto 0) := (others => '0');
  signal reconfig_writedata   : std_logic_vector(31 downto 0) := (others => '0');
  signal reconfig_readdata    : std_logic_vector(31 downto 0);
  signal reconfig_waitrequest : std_logic_vector(0 downto 0);
  signal reconfig_clk         : std_logic_vector(0 downto 0) := (others => '0');
  signal reconfig_reset       : std_logic_vector(0 downto 0);

  signal sfp_sda_o            : std_logic;
  signal sfp_sda_i            : std_logic;
  signal sfp_scl_o            : std_logic;
  signal sfp_scl_i            : std_logic;
  signal wr_core_reset_n      : std_logic := '0';
  signal wr_reset_delay       : unsigned(7 downto 0) := (others => '0');
  signal clk_sys_625           : std_logic;
  signal clk_sys_625_locked    : std_logic;
  signal clk_dmtd_62m496       : std_logic := '0';
begin
  u_sys_clk_625 : wr_sys_clk_625
    port map (
      i_clk_50  => CLK_50_B2J,
      i_reset_n => CPU_RESET_n,
      o_clk_625 => clk_sys_625,
      o_locked  => clk_sys_625_locked
    );

  -- Core-side DMTD offset clock: 124.992 MHz -> 62.496 MHz, matching
  -- the upstream board/platform clock topology.
  p_dmtd_core_div2 : process(QSFPB_REFCLK_p)
  begin
    if rising_edge(QSFPB_REFCLK_p) then
      clk_dmtd_62m496 <= not clk_dmtd_62m496;
    end if;
  end process;

  -- Keep the known 9f startup clock/reset behavior for Step 2.
  p_release_wr_core_reset : process(clk_sys_625)
  begin
    if rising_edge(clk_sys_625) then
      if CPU_RESET_n = '0' or clk_sys_625_locked = '0' then
        wr_reset_delay  <= (others => '0');
        wr_core_reset_n <= '0';
      elsif si_config_done = '0' then
        wr_reset_delay  <= (others => '0');
        wr_core_reset_n <= '0';
      elsif wr_reset_delay /= x"FF" then
        wr_reset_delay  <= wr_reset_delay + 1;
        wr_core_reset_n <= '0';
      else
        wr_core_reset_n <= '1';
      end if;
    end if;
  end process;

  reconfig_reset(0) <= not wr_core_reset_n;

  -- The core exposes the final CPU reset.  Once the external WR core reset
  -- is released, the remaining contributor is the CPU CSR software-reset bit.
  -- Keeping this derivation at the diagnostic top level avoids changing the
  -- shared WR core interfaces.
  cpu_software_reset <= cpu_reset and wr_core_reset_n;

  -- Read-only activity markers. Each source clock toggles one bit every
  -- 256 cycles; the markers are synchronized into the 50 MHz observer clock
  -- and counted there. They do not drive WR timing or reset behavior.
  p_ref_activity : process(QSFPA_REFCLK_p)
  begin
    if rising_edge(QSFPA_REFCLK_p) then
      if CPU_RESET_n = '0' then
        ref_activity_div <= (others => '0');
        ref_activity_toggle <= '0';
      elsif ref_activity_div = x"FF" then
        ref_activity_div <= (others => '0');
        ref_activity_toggle <= not ref_activity_toggle;
      else
        ref_activity_div <= ref_activity_div + 1;
      end if;
    end if;
  end process;

  p_dmtd_activity : process(QSFPB_REFCLK_p)
  begin
    if rising_edge(QSFPB_REFCLK_p) then
      if CPU_RESET_n = '0' then
        dmtd_activity_div <= (others => '0');
        dmtd_activity_toggle <= '0';
      elsif dmtd_activity_div = x"FF" then
        dmtd_activity_div <= (others => '0');
        dmtd_activity_toggle <= not dmtd_activity_toggle;
      else
        dmtd_activity_div <= dmtd_activity_div + 1;
      end if;
    end if;
  end process;

  p_rx_activity : process(wr_rx_clk)
  begin
    if rising_edge(wr_rx_clk) then
      if CPU_RESET_n = '0' then
        rx_activity_div <= (others => '0');
        rx_activity_toggle <= '0';
      elsif rx_activity_div = x"FF" then
        rx_activity_div <= (others => '0');
        rx_activity_toggle <= not rx_activity_toggle;
      else
        rx_activity_div <= rx_activity_div + 1;
      end if;
    end if;
  end process;

  p_activity_observer : process(CLK_50_B2J)
  begin
    if rising_edge(CLK_50_B2J) then
      if CPU_RESET_n = '0' then
        ref_activity_meta <= '0';
        ref_activity_sync <= '0';
        ref_activity_prev <= '0';
        dmtd_activity_meta <= '0';
        dmtd_activity_sync <= '0';
        dmtd_activity_prev <= '0';
        rx_activity_meta <= '0';
        rx_activity_sync <= '0';
        rx_activity_prev <= '0';
        ref_activity_count <= (others => '0');
        dmtd_activity_count <= (others => '0');
        rx_activity_count <= (others => '0');
      else
        ref_activity_meta <= ref_activity_toggle;
        ref_activity_sync <= ref_activity_meta;
        ref_activity_prev <= ref_activity_sync;
        dmtd_activity_meta <= dmtd_activity_toggle;
        dmtd_activity_sync <= dmtd_activity_meta;
        dmtd_activity_prev <= dmtd_activity_sync;
        rx_activity_meta <= rx_activity_toggle;
        rx_activity_sync <= rx_activity_meta;
        rx_activity_prev <= rx_activity_sync;
        if ref_activity_sync /= ref_activity_prev then
          ref_activity_count <= ref_activity_count + 1;
        end if;
        if dmtd_activity_sync /= dmtd_activity_prev then
          dmtd_activity_count <= dmtd_activity_count + 1;
        end if;
        if rx_activity_sync /= rx_activity_prev then
          rx_activity_count <= rx_activity_count + 1;
        end if;
      end if;
    end if;
  end process;

  clock_activity_probe(15 downto 0) <= std_logic_vector(ref_activity_count);
  clock_activity_probe(31 downto 16) <= std_logic_vector(dmtd_activity_count);
  clock_activity_probe(47 downto 32) <= std_logic_vector(rx_activity_count);
  clock_activity_probe(48) <= ref_activity_sync;
  clock_activity_probe(49) <= dmtd_activity_sync;
  clock_activity_probe(50) <= rx_activity_sync;
  clock_activity_probe(51) <= wr_ready;
  clock_activity_probe(52) <= wr_rx_locked_to_ref;
  clock_activity_probe(53) <= wr_rx_locked_to_data;
  clock_activity_probe(63 downto 54) <= (others => '0');

  -- Diagnostic only: count SoftPLL DAC update requests.  The counters are
  -- readable through the existing 64-bit JTAG probe and do not drive pins.
  p_dac_request_counters : process(CLK_50_B2J)
  begin
    if rising_edge(CLK_50_B2J) then
      if CPU_RESET_n = '0' then
        dac_hpll_count <= (others => '0');
        dac_dpll_count <= (others => '0');
        uart_txd_prev <= '1';
        sfp_scl_prev <= '1';
        uart_toggle_count <= (others => '0');
        sfp_scl_toggle_count <= (others => '0');
      else
        if dac_hpll_load = '1' then
          dac_hpll_count <= dac_hpll_count + 1;
        end if;
        if dac_dpll_load = '1' then
          dac_dpll_count <= dac_dpll_count + 1;
        end if;
        if uart_txd /= uart_txd_prev then
          uart_toggle_count <= uart_toggle_count + 1;
        end if;
        if sfp_scl_o /= sfp_scl_prev then
          sfp_scl_toggle_count <= sfp_scl_toggle_count + 1;
        end if;
        uart_txd_prev <= uart_txd;
        sfp_scl_prev <= sfp_scl_o;
      end if;
    end if;
  end process;

  -- Arm only after the normal configuration/reset settle window.  This arm
  -- state is diagnostic-only and never gates any functional reset.
  p_reset_diag_arm : process(CLK_50_B2J)
  begin
    if rising_edge(CLK_50_B2J) then
      if CPU_RESET_n = '1' and wr_core_reset_n = '1' and
         si_config_done = '1' and clk_sys_625_locked = '1' and
         cpu_reset = '0' then
        if reset_diag_arm_count /= x"FF" then
          reset_diag_arm_count <= reset_diag_arm_count + 1;
        else
          reset_diag_armed <= '1';
        end if;
      else
        reset_diag_arm_count <= (others => '0');
        reset_diag_armed <= '0';
      end if;
    end if;
  end process;

  cpu_reset_event      <= cpu_reset and reset_diag_armed;
  wr_core_reset_event  <= (not wr_core_reset_n) and reset_diag_armed;
  external_reset_event <= (not CPU_RESET_n) and reset_diag_armed;
  si_config_drop_event <= (not si_config_done) and reset_diag_armed;
  sys_pll_drop_event   <= (not clk_sys_625_locked) and reset_diag_armed;
  software_reset_event <= cpu_software_reset and reset_diag_armed;
  phy_reset_event      <= core_phy_rst and reset_diag_armed;
  wr_ready_drop_event  <= (not wr_ready) and reset_diag_armed;

  -- This observer-domain process has no CPU/WR reset input.  FPGA
  -- configuration initializes the registers to zero.  Sticky bits use
  -- asynchronous event sets; synchronized edge counters are auxiliary and
  -- are explicitly not width-independent evidence.
  p_reset_source_sticky : process(CLK_50_B2J,
                                  cpu_reset_event, wr_core_reset_event,
                                  external_reset_event, si_config_drop_event,
                                  sys_pll_drop_event, software_reset_event,
                                  phy_reset_event, wr_ready_drop_event)
  begin
    if cpu_reset_event = '1' then
      cpu_reset_seen <= '1';
    end if;
    if wr_core_reset_event = '1' then
      wr_core_reset_seen <= '1';
    end if;
    if external_reset_event = '1' then
      external_reset_seen <= '1';
    end if;
    if si_config_drop_event = '1' then
      si_config_drop_seen <= '1';
    end if;
    if sys_pll_drop_event = '1' then
      sys_pll_drop_seen <= '1';
    end if;
    if software_reset_event = '1' then
      software_reset_seen <= '1';
    end if;
    if phy_reset_event = '1' then
      phy_reset_seen <= '1';
    end if;
    if wr_ready_drop_event = '1' then
      wr_ready_drop_seen <= '1';
    end if;

    if rising_edge(CLK_50_B2J) then
      cpu_reset_meta <= cpu_reset;
      cpu_reset_sync <= cpu_reset_meta;
      cpu_reset_prev <= cpu_reset_sync;
      wr_core_reset_meta <= not wr_core_reset_n;
      wr_core_reset_sync <= wr_core_reset_meta;
      wr_core_reset_prev <= wr_core_reset_sync;
      external_reset_meta <= not CPU_RESET_n;
      external_reset_sync <= external_reset_meta;
      external_reset_prev <= external_reset_sync;
      si_config_drop_meta <= not si_config_done;
      si_config_drop_sync <= si_config_drop_meta;
      si_config_drop_prev <= si_config_drop_sync;
      sys_pll_drop_meta <= not clk_sys_625_locked;
      sys_pll_drop_sync <= sys_pll_drop_meta;
      sys_pll_drop_prev <= sys_pll_drop_sync;
      software_reset_meta <= cpu_software_reset;
      software_reset_sync <= software_reset_meta;
      software_reset_prev <= software_reset_sync;

      if cpu_reset_sync = '1' and cpu_reset_prev = '0' and
         cpu_reset_count /= x"FF" then
        cpu_reset_count <= cpu_reset_count + 1;
      end if;
      if wr_core_reset_sync = '1' and wr_core_reset_prev = '0' and
         wr_core_reset_count /= x"FF" then
        wr_core_reset_count <= wr_core_reset_count + 1;
      end if;
      if external_reset_sync = '1' and external_reset_prev = '0' and
         external_reset_count /= x"FF" then
        external_reset_count <= external_reset_count + 1;
      end if;
      if si_config_drop_sync = '1' and si_config_drop_prev = '0' and
         si_config_drop_count /= x"FF" then
        si_config_drop_count <= si_config_drop_count + 1;
      end if;
      if sys_pll_drop_sync = '1' and sys_pll_drop_prev = '0' and
         sys_pll_drop_count /= x"FF" then
        sys_pll_drop_count <= sys_pll_drop_count + 1;
      end if;
      if software_reset_sync = '1' and software_reset_prev = '0' and
         software_reset_count /= x"FF" then
        software_reset_count <= software_reset_count + 1;
      end if;
    end if;
  end process;

  -- JTAG-readable hardware reset/drop evidence.  Bits 1..8 are sticky
  -- flags; each following byte is a saturating synchronized-edge counter.
  reset_sticky_probe(0) <= reset_diag_armed;
  reset_sticky_probe(1) <= cpu_reset_seen;
  reset_sticky_probe(2) <= wr_core_reset_seen;
  reset_sticky_probe(3) <= external_reset_seen;
  reset_sticky_probe(4) <= si_config_drop_seen;
  reset_sticky_probe(5) <= sys_pll_drop_seen;
  reset_sticky_probe(6) <= software_reset_seen;
  reset_sticky_probe(7) <= phy_reset_seen;
  reset_sticky_probe(8) <= wr_ready_drop_seen;
  reset_sticky_probe(15 downto 9) <= (others => '0');
  reset_sticky_probe(23 downto 16) <= std_logic_vector(cpu_reset_count);
  reset_sticky_probe(31 downto 24) <= std_logic_vector(wr_core_reset_count);
  reset_sticky_probe(39 downto 32) <= std_logic_vector(external_reset_count);
  reset_sticky_probe(47 downto 40) <= std_logic_vector(si_config_drop_count);
  reset_sticky_probe(55 downto 48) <= std_logic_vector(sys_pll_drop_count);
  reset_sticky_probe(63 downto 56) <= std_logic_vector(software_reset_count);

  u_reset_sticky_probe : altsource_probe
    generic map (
      instance_id             => "WR_RESET_STICKY_SLAVE",
      probe_width             => 64,
      sld_auto_instance_index => "NO",
      sld_instance_index      => 27,
      source_width            => 1
    )
    port map (
      probe      => reset_sticky_probe,
      source     => reset_sticky_source,
      source_clk => CLK_50_B2J,
      source_ena => '1'
    );

  -- Read-only SI5340/runtime correlation observer.  This process is clocked
  -- by CLK_50_B2J and deliberately has no CPU/WR reset in its sensitivity
  -- list, so a reset under investigation cannot erase the first-event trace.
  p_si_corr_observer : process(CLK_50_B2J)
    variable now_tick : unsigned(31 downto 0);
  begin
    if rising_edge(CLK_50_B2J) then
      now_tick := si_corr_timestamp + 1;
      si_corr_timestamp <= now_tick;

      -- Preserve the normal startup provenance independently of the
      -- post-startup runtime-only recorder.
      if si_corr_startup_system_start = x"00000000" and
         dco_system_start = '1' then
        si_corr_startup_system_start <= now_tick;
      end if;
      if si_corr_startup_system_start /= x"00000000" and
         si_corr_startup_static_complete = x"00000000" and
         dco_static_state = x"00" and si_config_done = '1' and
         wr_core_reset_n = '1' and cpu_reset = '0' and
         dco_bus_state = '0' and dco_runtime_state = "000" then
        si_corr_startup_static_complete <= now_tick;
      end if;

      -- A 5 ms stable window at the 50 MHz observer clock proves that the
      -- diagnostic recorder is armed after startup, not during it.
      if si_corr_post_armed = '0' then
        if si_corr_startup_system_start /= x"00000000" and
           si_corr_startup_static_complete /= x"00000000" and
           dco_static_state = x"00" and si_config_done = '1' and
           wr_core_reset_n = '1' and cpu_reset = '0' and
           dco_bus_state = '0' and dco_runtime_state = "000" then
          si_corr_startup_ready_final <= '1';
          if si_corr_post_arm_count = to_unsigned(249999, 18) then
            si_corr_post_armed <= '1';
            si_corr_post_arm_timestamp <= now_tick;
            si_corr_t_dac_load <= (others => '0');
            si_corr_t_runtime_start <= (others => '0');
            si_corr_t_bus_done <= (others => '0');
            si_corr_t_static_done <= (others => '0');
            si_corr_t_state_leave <= (others => '0');
            si_corr_t_ready_drop <= (others => '0');
            si_corr_t_config_drop <= (others => '0');
            si_corr_t_wr_reset <= (others => '0');
            si_corr_t_cpu_reset <= (others => '0');
            si_corr_t_system_start <= (others => '0');
            si_corr_static_before <= (others => '0');
            si_corr_static_after <= (others => '0');
          else
            si_corr_post_arm_count <= si_corr_post_arm_count + 1;
          end if;
        else
          si_corr_post_arm_count <= (others => '0');
        end if;
      else
        if si_corr_t_dac_load = x"00000000" and
           (dac_dpll_load = '1' or dac_hpll_load = '1') then
          si_corr_t_dac_load <= now_tick;
        end if;
        if si_corr_t_runtime_start = x"00000000" and
           dco_runtime_start = '1' then
          si_corr_t_runtime_start <= now_tick;
        end if;
        if si_corr_t_bus_done = x"00000000" and dco_bus_done = '1' then
          si_corr_t_bus_done <= now_tick;
        end if;
        if si_corr_t_static_done = x"00000000" and
           dco_static_done_pulse = '1' then
          si_corr_t_static_done <= now_tick;
        end if;
        if si_corr_t_state_leave = x"00000000" and
           si_corr_static_prev = x"00" and dco_static_state /= x"00" then
          si_corr_t_state_leave <= now_tick;
          si_corr_static_before <= si_corr_static_prev;
          si_corr_static_after <= dco_static_state;
        end if;
        if si_corr_t_ready_drop = x"00000000" and
           si_corr_ready_prev = '1' and si_config_done = '0' then
          si_corr_t_ready_drop <= now_tick;
        end if;
        if si_corr_t_config_drop = x"00000000" and
           si_corr_config_prev = '1' and si_config_done = '0' then
          si_corr_t_config_drop <= now_tick;
        end if;
        if si_corr_t_wr_reset = x"00000000" and
           si_corr_wr_reset_prev = '1' and wr_core_reset_n = '0' then
          si_corr_t_wr_reset <= now_tick;
        end if;
        if si_corr_t_cpu_reset = x"00000000" and
           si_corr_cpu_reset_prev = '0' and cpu_reset = '1' then
          si_corr_t_cpu_reset <= now_tick;
        end if;
        if si_corr_t_system_start = x"00000000" and
           dco_system_start = '1' then
          si_corr_t_system_start <= now_tick;
        end if;
      end if;

      si_corr_static_prev <= dco_static_state;
      si_corr_ready_prev <= si_config_done;
      si_corr_config_prev <= si_config_done;
      si_corr_wr_reset_prev <= wr_core_reset_n;
      si_corr_cpu_reset_prev <= cpu_reset;
    end if;
  end process;

  -- Correlation probes: timestamp pairs are in little-endian low/high
  -- halves; probe 5 carries the state transition and a live snapshot.
  si_corr_probe0(31 downto 0) <= std_logic_vector(si_corr_t_dac_load);
  si_corr_probe0(63 downto 32) <= std_logic_vector(si_corr_t_runtime_start);
  si_corr_probe1(31 downto 0) <= std_logic_vector(si_corr_t_bus_done);
  si_corr_probe1(63 downto 32) <= std_logic_vector(si_corr_t_static_done);
  si_corr_probe2(31 downto 0) <= std_logic_vector(si_corr_t_state_leave);
  si_corr_probe2(63 downto 32) <= std_logic_vector(si_corr_t_ready_drop);
  si_corr_probe3(31 downto 0) <= std_logic_vector(si_corr_t_config_drop);
  si_corr_probe3(63 downto 32) <= std_logic_vector(si_corr_t_wr_reset);
  si_corr_probe4(31 downto 0) <= std_logic_vector(si_corr_t_cpu_reset);
  si_corr_probe4(63 downto 32) <= std_logic_vector(si_corr_t_system_start);
  si_corr_probe5(7 downto 0) <= si_corr_static_before;
  si_corr_probe5(15 downto 8) <= si_corr_static_after;
  si_corr_probe5(23 downto 16) <= dco_static_state;
  si_corr_probe5(24) <= si_corr_post_armed;
  si_corr_probe5(25) <= si_config_done;
  si_corr_probe5(26) <= wr_core_reset_n;
  si_corr_probe5(27) <= cpu_reset;
  si_corr_probe5(28) <= dco_runtime_start;
  si_corr_probe5(29) <= dco_bus_done;
  si_corr_probe5(30) <= dco_static_done_pulse;
  si_corr_probe5(31) <= dco_static_access_start;
  si_corr_probe5(34 downto 32) <= dco_runtime_state;
  si_corr_probe5(35) <= dco_bus_state;
  si_corr_probe5(36) <= dco_runtime_bus_enable;
  si_corr_probe5(37) <= dco_system_start;
  si_corr_probe5(63 downto 38) <= (others => '0');
  si_corr_probe6(31 downto 0) <= std_logic_vector(si_corr_post_arm_timestamp);
  si_corr_probe6(63 downto 32) <= std_logic_vector(si_corr_startup_system_start);
  si_corr_probe7(31 downto 0) <= std_logic_vector(si_corr_startup_static_complete);
  si_corr_probe7(32) <= si_corr_startup_ready_final;
  si_corr_probe7(33) <= si_corr_post_armed;
  si_corr_probe7(63 downto 34) <= (others => '0');

  u_si_corr_probe0 : altsource_probe
    generic map (instance_id => "WR_SI_CORRELATION_0_SLAVE", probe_width => 64,
                 sld_auto_instance_index => "NO", sld_instance_index => 28,
                 source_width => 1)
    port map (probe => si_corr_probe0, source => si_corr_source0,
              source_clk => CLK_50_B2J, source_ena => '1');
  u_si_corr_probe1 : altsource_probe
    generic map (instance_id => "WR_SI_CORRELATION_1_SLAVE", probe_width => 64,
                 sld_auto_instance_index => "NO", sld_instance_index => 29,
                 source_width => 1)
    port map (probe => si_corr_probe1, source => si_corr_source1,
              source_clk => CLK_50_B2J, source_ena => '1');
  u_si_corr_probe2 : altsource_probe
    generic map (instance_id => "WR_SI_CORRELATION_2_SLAVE", probe_width => 64,
                 sld_auto_instance_index => "NO", sld_instance_index => 30,
                 source_width => 1)
    port map (probe => si_corr_probe2, source => si_corr_source2,
              source_clk => CLK_50_B2J, source_ena => '1');
  u_si_corr_probe3 : altsource_probe
    generic map (instance_id => "WR_SI_CORRELATION_3_SLAVE", probe_width => 64,
                 sld_auto_instance_index => "NO", sld_instance_index => 31,
                 source_width => 1)
    port map (probe => si_corr_probe3, source => si_corr_source3,
              source_clk => CLK_50_B2J, source_ena => '1');
  u_si_corr_probe4 : altsource_probe
    generic map (instance_id => "WR_SI_CORRELATION_4_SLAVE", probe_width => 64,
                 sld_auto_instance_index => "NO", sld_instance_index => 32,
                 source_width => 1)
    port map (probe => si_corr_probe4, source => si_corr_source4,
              source_clk => CLK_50_B2J, source_ena => '1');
  u_si_corr_probe5 : altsource_probe
    generic map (instance_id => "WR_SI_CORRELATION_5_SLAVE", probe_width => 64,
                 sld_auto_instance_index => "NO", sld_instance_index => 33,
                 source_width => 1)
    port map (probe => si_corr_probe5, source => si_corr_source5,
              source_clk => CLK_50_B2J, source_ena => '1');
  u_si_corr_probe6 : altsource_probe
    generic map (instance_id => "WR_SI_CORRELATION_6_SLAVE", probe_width => 64,
                 sld_auto_instance_index => "NO", sld_instance_index => 34,
                 source_width => 1)
    port map (probe => si_corr_probe6, source => si_corr_source6,
              source_clk => CLK_50_B2J, source_ena => '1');
  u_si_corr_probe7 : altsource_probe
    generic map (instance_id => "WR_SI_CORRELATION_7_SLAVE", probe_width => 64,
                 sld_auto_instance_index => "NO", sld_instance_index => 35,
                 source_width => 1)
    port map (probe => si_corr_probe7, source => si_corr_source7,
              source_clk => CLK_50_B2J, source_ena => '1');

  -- JTAG-readable status: bit 0 is the least-significant status bit.
  sync_probe(15 downto 0) <= CPU_RESET_n & wr_tx_enc_err & wr_rx_enc_err & si_id_error &
                             core_phy_rst & core_phy_tx_disable & QSFPA_INTERRUPT_n &
                             QSFPA_MOD_PRS_n & wr_tx_ready & wr_rx_ready &
                             core_pps_valid & core_tm_time_valid & core_link_ok &
                             core_tm_link_up & wr_ready & si_config_done;
  sync_probe(23 downto 16) <= wr_rx_data;
  sync_probe(27 downto 24) <= wr_rx_bitslide;
  sync_probe(28) <= wr_rx_data_k;
  sync_probe(29) <= wr_debug;
  sync_probe(30) <= core_phy_loopen;
  sync_probe(31) <= '0';
  sync_probe(39 downto 32) <= wr_rx_runningdisp & wr_rx_pattern_ready &
                              wr_rx_patterndetect & wr_rx_syncstatus &
                              wr_rx_errdetect & wr_rx_disperr &
                              wr_rx_locked_to_ref & wr_rx_locked_to_data;
  -- The load counters below observe raw WR SoftPLL DAC requests.  They are
  -- intentionally separate from the SI5340 transaction step counter.
  sync_probe(47 downto 40) <= std_logic_vector(uart_toggle_count);
  sync_probe(55 downto 48) <= std_logic_vector(sfp_scl_toggle_count);
  sync_probe(59 downto 56) <= std_logic_vector(dac_dpll_count(3 downto 0));
  sync_probe(63 downto 60) <= std_logic_vector(dac_hpll_count(3 downto 0));

  u_wr_sync_probe : altsource_probe
    generic map (
      instance_id             => "WR_SYNC_SLAVE",
      probe_width             => 64,
      sld_auto_instance_index => "NO",
      sld_instance_index      => 0,
      source_width            => 1
    )
    port map (
      probe      => sync_probe,
      source     => sync_source,
      source_clk => CLK_50_B2J,
      source_ena => '1'
    );

  u_clock_activity_probe : altsource_probe
    generic map (
      instance_id             => "WR_CLOCK_ACTIVITY_SLAVE",
      probe_width             => 64,
      sld_auto_instance_index => "NO",
      sld_instance_index      => 7,
      source_width            => 1
    )
    port map (
      probe      => clock_activity_probe,
      source     => open,
      source_clk => CLK_50_B2J,
      source_ena => '1'
    );

  -- 唯讀 DCO probe。只觀察 clean-9f controller 的 request、I2C state、
  -- step count 與輸入資料，不參與 WR、SoftPLL 或 SI5340 控制。
  dco_probe <= dco_debug;

  u_dco_probe : altsource_probe
    generic map (
      instance_id             => "WR_DCO_ACTIVITY_CLEAN9F_SLAVE",
      probe_width             => 64,
      sld_auto_instance_index => "NO",
      sld_instance_index      => 8,
      source_width            => 1
    )
    port map (
      probe      => dco_probe,
      source     => open,
      source_clk => CLK_50_B2J,
      source_ena => '1'
    );

  -- JTAG-controlled Step5 experiment probe.  The probe is read-only on the
  -- 64-bit status path and exposes one dedicated source bit to the DCO.
  u_step5_trigger_probe : altsource_probe
    generic map (
      instance_id             => "WR_STEP5_TRIGGER_DEBUG_SLAVE",
      probe_width             => 64,
      sld_auto_instance_index => "NO",
      sld_instance_index      => 36,
      source_initial_value    => "0",
      source_width            => 1
    )
    port map (
      probe      => dco_step5_debug_probe,
      source     => force_hpll_source,
      source_clk => CLK_50_B2J,
      source_ena => '1'
    );

  u_step5_burst_debug_probe : altsource_probe
    generic map (
      instance_id             => "WR_STEP5_BURST_DEBUG_SLAVE",
      probe_width             => 64,
      sld_auto_instance_index => "NO",
      sld_instance_index      => 37,
      source_width            => 1
    )
    port map (
      probe      => dco_step5_burst_debug_probe,
      source     => open,
      source_clk => CLK_50_B2J,
      source_ena => '1'
    );

  step5_polarity_probe(0) <= step5_polarity_source(0);
  step5_polarity_probe(1) <= step5_polarity_active;
  step5_polarity_probe(63 downto 2) <= (others => '0');

  u_step5_polarity_probe : altsource_probe
    generic map (
      instance_id             => "WR_STEP5_POLARITY_SELECT_SLAVE",
      probe_width             => 64,
      sld_auto_instance_index => "NO",
      sld_instance_index      => 38,
      source_initial_value    => "0",
      source_width            => 1
    )
    port map (
      probe      => step5_polarity_probe,
      source     => step5_polarity_source,
      source_clk => CLK_50_B2J,
      source_ena => '1'
    );

  u_step5_tracker_debug_probe : altsource_probe
    generic map (
      instance_id             => "WR_STEP5_TRACKER_DEBUG_SLAVE",
      probe_width             => 64,
      sld_auto_instance_index => "NO",
      sld_instance_index      => 39,
      source_width            => 1
    )
    port map (
      probe      => dco_step5_tracker_debug_probe,
      source     => open,
      source_clk => CLK_50_B2J,
      source_ena => '1'
    );

  -- Calibration-only source: select a bounded forced physical-step count
  -- without changing the fixed Step5 probe indices above.
  u_step5_burst_size_source : altsource_probe
    generic map (
      instance_id             => "WR_STEP5_BURST_SIZE_SOURCE_SLAVE",
      probe_width             => 64,
      sld_auto_instance_index => "NO",
      sld_instance_index      => 40,
      source_initial_value    => "0000000000000000",
      source_width            => 16
    )
    port map (
      probe      => (others => '0'),
      source     => step5_burst_size_source,
      source_clk => CLK_50_B2J,
      source_ena => '1'
    );

  u_step5_burst_wide_debug_probe : altsource_probe
    generic map (
      instance_id             => "WR_STEP5_BURST_WIDE_DEBUG_SLAVE",
      probe_width             => 64,
      sld_auto_instance_index => "NO",
      sld_instance_index      => 41,
      source_width            => 1
    )
    port map (
      probe      => dco_step5_burst_wide_debug_probe,
      source     => open,
      source_clk => CLK_50_B2J,
      source_ena => '1'
    );

  u_step5_bootstrap_debug_probe : altsource_probe
    generic map (
      instance_id             => "WR_STEP5_BOOTSTRAP_DEBUG_SLAVE",
      probe_width             => 64,
      sld_auto_instance_index => "NO",
      sld_instance_index      => 42,
      source_width            => 1
    )
    port map (
      probe      => dco_step5_bootstrap_debug_probe,
      source     => open,
      source_clk => CLK_50_B2J,
      source_ena => '1'
    );

  u_step5_position_debug_probe : altsource_probe
    generic map (
      instance_id             => "WR_STEP5_POSITION_DEBUG_SLAVE",
      probe_width             => 64,
      sld_auto_instance_index => "NO",
      sld_instance_index      => 43,
      source_width            => 1
    )
    port map (
      probe      => dco_step5_position_debug_probe,
      source     => open,
      source_clk => CLK_50_B2J,
      source_ena => '1'
    );

  u_step5_position_accounting_debug_probe : altsource_probe
    generic map (
      instance_id             => "WR_STEP5_POSITION_ACCOUNTING_DEBUG_SLAVE",
      probe_width             => 64,
      sld_auto_instance_index => "NO",
      sld_instance_index      => 44,
      source_width            => 1
    )
    port map (
      probe      => dco_step5_position_accounting_debug_probe,
      source     => open,
      source_clk => CLK_50_B2J,
      source_ena => '1'
    );

  -- CPU 執行觀測：[31:0] PC、bit 32 reset、bit 33 fault、bit 34
  -- instruction-valid。此 probe 只讀取，不參與 WR 時序。
  cpu_debug_probe(31 downto 0) <= cpu_pc;
  cpu_debug_probe(32) <= cpu_reset;
  cpu_debug_probe(33) <= cpu_fault;
  cpu_debug_probe(34) <= cpu_im_valid;
  cpu_debug_probe(35) <= CPU_RESET_n;
  cpu_debug_probe(36) <= wr_core_reset_n;
  cpu_debug_probe(37) <= si_config_done;
  cpu_debug_probe(38) <= clk_sys_625_locked;
  cpu_debug_probe(63 downto 39) <= (others => '0');

  u_cpu_debug_probe : altsource_probe
    generic map (
      instance_id             => "WR_CPU_DEBUG_SLAVE",
      probe_width             => 64,
      sld_auto_instance_index => "NO",
      sld_instance_index      => 2,
      source_width            => 1
    )
    port map (
      probe      => cpu_debug_probe,
      source     => cpu_debug_source,
      source_clk => CLK_50_B2J,
      source_ena => '1'
    );

  cpu_marker_probe(31 downto 0) <= cpu_boot_stage_value;
  cpu_marker_probe(32) <= cpu_boot_stage_seen;
  cpu_marker_probe(63 downto 33) <= (others => '0');

  u_cpu_marker_probe : altsource_probe
    generic map (
      instance_id             => "WR_CPU_MARKER_SLAVE",
      probe_width             => 64,
      sld_auto_instance_index => "NO",
      sld_instance_index      => 3,
      source_width            => 1
    )
    port map (
      probe      => cpu_marker_probe,
      source     => cpu_marker_source,
      source_clk => CLK_50_B2J,
      source_ena => '1'
    );

  -- Passive pre-CRT entry snapshot: [31:0] p at entry and [63:32]
  -- boot-generation.  This direct probe never controls or accesses the CPU.
  cpu_entry_probe(31 downto 0) <= cpu_entry_p;
  cpu_entry_probe(63 downto 32) <= cpu_entry_generation;

  u_cpu_entry_probe : altsource_probe
    generic map (
      instance_id             => "WR_CPU_ENTRY_SLAVE",
      probe_width             => 64,
      sld_auto_instance_index => "NO",
      sld_instance_index      => 26,
      source_width            => 1
    )
    port map (
      probe      => cpu_entry_probe,
      source     => open,
      source_clk => CLK_50_B2J,
      source_ena => '1'
    );

  cpu_store_probe(31 downto 0) <= cpu_last_store_addr;
  cpu_store_probe(63 downto 32) <= cpu_last_store_data;

  u_cpu_store_probe : altsource_probe
    generic map (
      instance_id             => "WR_CPU_STORE_SLAVE",
      probe_width             => 64,
      sld_auto_instance_index => "NO",
      sld_instance_index      => 4,
      source_width            => 1
    )
    port map (
      probe      => cpu_store_probe,
      source     => cpu_store_source,
      source_clk => CLK_50_B2J,
      source_ena => '1'
    );

  cpu_store_count_probe(31 downto 0) <= cpu_internal_store_count;
  cpu_store_count_probe(63 downto 32) <= (others => '0');

  u_cpu_store_count_probe : altsource_probe
    generic map (
      instance_id             => "WR_CPU_STORE_COUNT_SLAVE",
      probe_width             => 64,
      sld_auto_instance_index => "NO",
      sld_instance_index      => 5,
      source_width            => 1
    )
    port map (
      probe      => cpu_store_count_probe,
      source     => cpu_store_count_source,
      source_clk => CLK_50_B2J,
      source_ena => '1'
    );

  cpu_exception_probe(31 downto 0) <= cpu_mepc;
  cpu_exception_probe(63 downto 32) <= cpu_mcause;

  u_cpu_exception_probe : altsource_probe
    generic map (
      instance_id             => "WR_CPU_EXCEPTION_SLAVE",
      probe_width             => 64,
      sld_auto_instance_index => "NO",
      sld_instance_index      => 6,
      source_width            => 1
    )
    port map (
      probe      => cpu_exception_probe,
      source     => cpu_exception_source,
      source_clk => CLK_50_B2J,
      source_ena => '1'
    );

  -- CPU data-port identity diagnostic.  The address probe carries the
  -- captured request address in [31:0] and the next-cycle RAM return word in
  -- [63:32].  The metadata probe carries byte enable [3:0], request-seen bit
  -- 4, return-seen bit 5, and expected-address match bit 6.
  cpu_data_diag_addr_probe <= cpu_data_diag_addr_payload;
  cpu_data_diag_meta_probe <= cpu_data_diag_meta_payload;

  u_cpu_data_diag_addr_probe : altsource_probe
    generic map (
      instance_id             => "WR_CPU_DATA_DIAG_ADDR_SLAVE",
      probe_width             => 64,
      sld_auto_instance_index => "NO",
      sld_instance_index      => 9,
      source_width            => 1
    )
    port map (
      probe      => cpu_data_diag_addr_probe,
      source     => open,
      source_clk => CLK_50_B2J,
      source_ena => '1'
    );

  u_cpu_data_diag_meta_probe : altsource_probe
    generic map (
      instance_id             => "WR_CPU_DATA_DIAG_META_SLAVE",
      probe_width             => 64,
      sld_auto_instance_index => "NO",
      sld_instance_index      => 10,
      source_width            => 1
    )
    port map (
      probe      => cpu_data_diag_meta_probe,
      source     => open,
      source_clk => CLK_50_B2J,
      source_ena => '1'
    );

  -- RAM port-B request/return pipeline diagnostic.  Probe 11 carries the
  -- request address in [31:0] and the next-cycle registered-address mirror in
  -- [63:32].  Probe 12 carries q cycle 1 in [31:0] and q cycle 2 in [63:32].
  -- Probe 13 carries byte enable [3:0], request/q1/q2 seen bits [4:6], and
  -- expected-address match bit 7.
  cpu_ram_diag_addr_probe <= cpu_ram_diag_addr_payload;
  cpu_ram_diag_q_probe <= cpu_ram_diag_q_payload;
  cpu_ram_diag_meta_probe <= cpu_ram_diag_meta_payload;

  u_cpu_ram_diag_addr_probe : altsource_probe
    generic map (
      instance_id             => "WR_CPU_RAM_DIAG_ADDR_SLAVE",
      probe_width             => 64,
      sld_auto_instance_index => "NO",
      sld_instance_index      => 11,
      source_width            => 1
    )
    port map (
      probe      => cpu_ram_diag_addr_probe,
      source     => open,
      source_clk => CLK_50_B2J,
      source_ena => '1'
    );

  u_cpu_ram_diag_q_probe : altsource_probe
    generic map (
      instance_id             => "WR_CPU_RAM_DIAG_Q_SLAVE",
      probe_width             => 64,
      sld_auto_instance_index => "NO",
      sld_instance_index      => 12,
      source_width            => 1
    )
    port map (
      probe      => cpu_ram_diag_q_probe,
      source     => open,
      source_clk => CLK_50_B2J,
      source_ena => '1'
    );

  u_cpu_ram_diag_meta_probe : altsource_probe
    generic map (
      instance_id             => "WR_CPU_RAM_DIAG_META_SLAVE",
      probe_width             => 64,
      sld_auto_instance_index => "NO",
      sld_instance_index      => 13,
      source_width            => 1
    )
    port map (
      probe      => cpu_ram_diag_meta_probe,
      source     => open,
      source_clk => CLK_50_B2J,
      source_ena => '1'
    );

  -- Probe 14 carries the previous port-B address-register input in [63:32]
  -- and the q value visible before the update at the request edge (q cycle 0)
  -- in [31:0].
  cpu_ram_diag_q0_probe <= cpu_ram_diag_q0_payload;

  u_cpu_ram_diag_q0_probe : altsource_probe
    generic map (
      instance_id             => "WR_CPU_RAM_DIAG_Q0_SLAVE",
      probe_width             => 64,
      sld_auto_instance_index => "NO",
      sld_instance_index      => 14,
      source_width            => 1
    )
    port map (
      probe      => cpu_ram_diag_q0_probe,
      source     => open,
      source_clk => CLK_50_B2J,
      source_ena => '1'
    );

  -- RAM port-B reset/release initial-q diagnostic.  Probes 15..18 carry
  -- q while reset, four post-release samples, and q immediately
  -- before/at the first internal load.  Probe 19 carries capture flags.
  cpu_ram_init_diag_probe0 <= cpu_ram_init_diag_payload0;
  cpu_ram_init_diag_probe1 <= cpu_ram_init_diag_payload1;
  cpu_ram_init_diag_probe2 <= cpu_ram_init_diag_payload2;
  cpu_ram_init_diag_probe3 <= cpu_ram_init_diag_payload3;
  cpu_ram_init_diag_meta_probe <= cpu_ram_init_diag_meta_payload;

  u_cpu_ram_init_diag_probe0 : altsource_probe
    generic map (
      instance_id             => "WR_CPU_RAM_INIT_DIAG_0_SLAVE",
      probe_width             => 64,
      sld_auto_instance_index => "NO",
      sld_instance_index      => 15,
      source_width            => 1
    )
    port map (
      probe      => cpu_ram_init_diag_probe0,
      source     => open,
      source_clk => CLK_50_B2J,
      source_ena => '1'
    );

  u_cpu_ram_init_diag_probe1 : altsource_probe
    generic map (
      instance_id             => "WR_CPU_RAM_INIT_DIAG_1_SLAVE",
      probe_width             => 64,
      sld_auto_instance_index => "NO",
      sld_instance_index      => 16,
      source_width            => 1
    )
    port map (
      probe      => cpu_ram_init_diag_probe1,
      source     => open,
      source_clk => CLK_50_B2J,
      source_ena => '1'
    );

  u_cpu_ram_init_diag_probe2 : altsource_probe
    generic map (
      instance_id             => "WR_CPU_RAM_INIT_DIAG_2_SLAVE",
      probe_width             => 64,
      sld_auto_instance_index => "NO",
      sld_instance_index      => 17,
      source_width            => 1
    )
    port map (
      probe      => cpu_ram_init_diag_probe2,
      source     => open,
      source_clk => CLK_50_B2J,
      source_ena => '1'
    );

  u_cpu_ram_init_diag_probe3 : altsource_probe
    generic map (
      instance_id             => "WR_CPU_RAM_INIT_DIAG_3_SLAVE",
      probe_width             => 64,
      sld_auto_instance_index => "NO",
      sld_instance_index      => 18,
      source_width            => 1
    )
    port map (
      probe      => cpu_ram_init_diag_probe3,
      source     => open,
      source_clk => CLK_50_B2J,
      source_ena => '1'
    );

  u_cpu_ram_init_diag_meta_probe : altsource_probe
    generic map (
      instance_id             => "WR_CPU_RAM_INIT_DIAG_META_SLAVE",
      probe_width             => 64,
      sld_auto_instance_index => "NO",
      sld_instance_index      => 19,
      source_width            => 1
    )
    port map (
      probe      => cpu_ram_init_diag_meta_probe,
      source     => open,
      source_clk => CLK_50_B2J,
      source_ena => '1'
    );

  -- Direct raw q_b versus wrapper dm_mem_rdata diagnostic.  Probe 20 carries
  -- primitive q before/at the first internal load, probe 21 carries
  -- primitive q after the load and dm_mem_rdata at the load, and probe 22
  -- carries capture flags.
  cpu_ram_primitive_diag_probe0 <= cpu_ram_primitive_diag_payload0;
  cpu_ram_primitive_diag_probe1 <= cpu_ram_primitive_diag_payload1;
  cpu_ram_primitive_diag_meta_probe <= cpu_ram_primitive_diag_meta_payload;

  u_cpu_ram_primitive_diag_probe0 : altsource_probe
    generic map (
      instance_id             => "WR_CPU_RAM_PRIMITIVE_DIAG_0_SLAVE",
      probe_width             => 64,
      sld_auto_instance_index => "NO",
      sld_instance_index      => 20,
      source_width            => 1
    )
    port map (
      probe      => cpu_ram_primitive_diag_probe0,
      source     => open,
      source_clk => CLK_50_B2J,
      source_ena => '1'
    );

  u_cpu_ram_primitive_diag_probe1 : altsource_probe
    generic map (
      instance_id             => "WR_CPU_RAM_PRIMITIVE_DIAG_1_SLAVE",
      probe_width             => 64,
      sld_auto_instance_index => "NO",
      sld_instance_index      => 21,
      source_width            => 1
    )
    port map (
      probe      => cpu_ram_primitive_diag_probe1,
      source     => open,
      source_clk => CLK_50_B2J,
      source_ena => '1'
    );

  u_cpu_ram_primitive_diag_meta_probe : altsource_probe
    generic map (
      instance_id             => "WR_CPU_RAM_PRIMITIVE_DIAG_META_SLAVE",
      probe_width             => 64,
      sld_auto_instance_index => "NO",
      sld_instance_index      => 22,
      source_width            => 1
    )
    port map (
      probe      => cpu_ram_primitive_diag_meta_probe,
      source     => open,
      source_clk => CLK_50_B2J,
      source_ena => '1'
    );

  -- First port-B load same-edge port-A activity diagnostic.  Probe 23 carries
  -- port-A byte address and write data, probe 24 carries port-B byte address
  -- and primitive q_b, and probe 25 carries port-A write/byte-enable flags.
  cpu_ram_port_a_diag_probe0 <= cpu_ram_port_a_diag_payload0;
  cpu_ram_port_a_diag_probe1 <= cpu_ram_port_a_diag_payload1;
  cpu_ram_port_a_diag_meta_probe <= cpu_ram_port_a_diag_meta_payload;

  u_cpu_ram_port_a_diag_probe0 : altsource_probe
    generic map (
      instance_id             => "WR_CPU_RAM_PORT_A_DIAG_0_SLAVE",
      probe_width             => 64,
      sld_auto_instance_index => "NO",
      sld_instance_index      => 23,
      source_width            => 1
    )
    port map (
      probe      => cpu_ram_port_a_diag_probe0,
      source     => open,
      source_clk => CLK_50_B2J,
      source_ena => '1'
    );

  u_cpu_ram_port_a_diag_probe1 : altsource_probe
    generic map (
      instance_id             => "WR_CPU_RAM_PORT_A_DIAG_1_SLAVE",
      probe_width             => 64,
      sld_auto_instance_index => "NO",
      sld_instance_index      => 24,
      source_width            => 1
    )
    port map (
      probe      => cpu_ram_port_a_diag_probe1,
      source     => open,
      source_clk => CLK_50_B2J,
      source_ena => '1'
    );

  u_cpu_ram_port_a_diag_meta_probe : altsource_probe
    generic map (
      instance_id             => "WR_CPU_RAM_PORT_A_DIAG_META_SLAVE",
      probe_width             => 64,
      sld_auto_instance_index => "NO",
      sld_instance_index      => 25,
      source_width            => 1
    )
    port map (
      probe      => cpu_ram_port_a_diag_meta_probe,
      source     => open,
      source_clk => CLK_50_B2J,
      source_ena => '1'
    );

  -- The board's SFP I2C pins are open-drain.  WRPC drives only the output
  -- low and releases the line for a logic high.
  QSFPA_SDA <= '0' when sfp_sda_o = '0' else 'Z';
  sfp_sda_i <= QSFPA_SDA;
  QSFPA_SCL <= '0' when sfp_scl_o = '0' else 'Z';
  sfp_scl_i <= QSFPA_SCL;

  QSFPA_MOD_SEL_n <= '0';
  QSFPA_RST_n     <= CPU_RESET_n;
  QSFPA_TX_p(3 downto 1) <= (others => '0');
  SI5340A_OE_n    <= '0';
  SI5340A_RST_n   <= CPU_RESET_n;

  u_si5340a_controller : si5340a_controller_dco
    generic map (
      ENABLE_SAME_CODE_TEST => 0,
      ENABLE_JTAG_HPLL_BURST => 1,
      -- Step5 coherent closed-loop trajectory audit: retain the 6208-step
      -- bootstrap and re-enable the normal HPLL tracker. All other Step5
      -- control parameters remain unchanged.
      ENABLE_NORMAL_HPLL_TRACKER => 1,
      ENABLE_STEP5_BOOTSTRAP => 1,
      STEP5_BOOTSTRAP_STEPS => 6208,
      HPLL_TRACKER_CODE_PER_PHYSICAL_STEP => 64,
      JTAG_HPLL_BURST_SIZE => 32
    )
    port map (
      iCLK                   => CLK_50_B2J,
      iRST_n                 => CPU_RESET_n,
      iStart                 => not BUTTON(0),
      iPLL_OUT0_FREQ_SEL     => SI5340_125M,
      iPLL_OUT1_FREQ_SEL     => SI5340_124M992,
      iPLL_OUT2_FREQ_SEL     => SI5340_POWER_DOWN,
      iPLL_OUT3_FREQ_SEL     => SI5340_POWER_DOWN,
      iDPLL_LOAD             => dac_dpll_load,
      iDPLL_DATA             => dac_dpll_data,
      iHPLL_LOAD             => dac_hpll_load,
      iHPLL_DATA             => dac_hpll_data,
      iFORCE_HPLL_ONE_STEP   => force_hpll_source(0),
      iFORCE_HPLL_REVERSE    => step5_polarity_source(0),
      iFORCE_HPLL_BURST_SIZE => step5_burst_size_source,
      I2C_CLK                => SI5340A_I2C_SCL,
      I2C_DATA               => SI5340A_I2C_SDA,
      oPLL_I2C_ID_READ_ERROR => si_id_error,
      oPLL_REG_CONFIG_DONE   => si_config_done,
      oDCO_BUSY              => dco_busy,
      oDCO_ERROR             => dco_error,
      oDCO_STEP_COUNT        => dco_step_count,
      oDCO_DEBUG             => dco_debug,
      oDCO_STEP5_DEBUG       => dco_step5_debug_probe,
      oDCO_STEP5_BURST_DEBUG => dco_step5_burst_debug_probe,
      oDCO_STEP5_BURST_WIDE_DEBUG => dco_step5_burst_wide_debug_probe,
      oDCO_STEP5_TRACKER_DEBUG => dco_step5_tracker_debug_probe,
      oDCO_STEP5_BOOTSTRAP_DEBUG => dco_step5_bootstrap_debug_probe,
      oDCO_STEP5_POSITION_DEBUG => dco_step5_position_debug_probe,
      oDCO_STEP5_POSITION_ACCOUNTING_DEBUG => dco_step5_position_accounting_debug_probe,
      oDCO_STEP5_POLARITY_ACTIVE => step5_polarity_active,
      oDEBUG_STATIC_STATE    => dco_static_state,
      oDEBUG_STATIC_CONFIG_DONE_PULSE => dco_static_done_pulse,
      oDEBUG_STATIC_ACCESS_START => dco_static_access_start,
      oDEBUG_RUNTIME_STATE   => dco_runtime_state,
      oDEBUG_BUS_STATE       => dco_bus_state,
      oDEBUG_BUS_DONE        => dco_bus_done,
      oDEBUG_RUNTIME_START   => dco_runtime_start,
      oDEBUG_RUNTIME_BUS_ENABLE => dco_runtime_bus_enable,
      oDEBUG_SYSTEM_START    => dco_system_start
    );

  u_wr_arria10_transceiver : wr_arria10_transceiver
    generic map (
      g_family        => "Arria 10 GX E3P1",
      g_use_simple_wa => true
    )
    port map (
      clk_ref_i              => QSFPA_REFCLK_p,
      clk_phy_i              => QSFPA_REFCLK_p,
      reconfig_write_i       => reconfig_write,
      reconfig_read_i        => reconfig_read,
      reconfig_address_i     => reconfig_address,
      reconfig_writedata_i   => reconfig_writedata,
      reconfig_readdata_o    => reconfig_readdata,
      reconfig_waitrequest_o => reconfig_waitrequest,
      reconfig_clk_i         => reconfig_clk,
      reconfig_reset_i       => reconfig_reset,
      ready_o                => wr_ready,
      drop_link_i            => (not wr_core_reset_n) or core_phy_rst,
      loopen_i               => core_phy_loopen,
      sfp_los_i              => '0',
      tx_clk_o               => wr_tx_clk,
      tx_data_i              => core_tx_data,
      tx_ready_o             => wr_tx_ready,
      tx_disparity_o         => wr_tx_disparity,
      tx_enc_err_o           => wr_tx_enc_err,
      tx_data_k_i            => core_tx_k(0),
      rx_clk_o               => wr_rx_clk,
      rx_data_o              => wr_rx_data,
      rx_ready_o             => wr_rx_ready,
      rx_data_k_o            => wr_rx_data_k,
      rx_enc_err_o           => wr_rx_enc_err,
      rx_bitslide_o          => wr_rx_bitslide,
      rx_lockedtodata_o      => wr_rx_locked_to_data,
      rx_lockedtoref_o       => wr_rx_locked_to_ref,
      rx_disperr_o           => wr_rx_disperr,
      rx_errdetect_o         => wr_rx_errdetect,
      rx_syncstatus_o        => wr_rx_syncstatus,
      rx_patterndetect_o     => wr_rx_patterndetect,
      rx_patterndetect_ready_o => wr_rx_pattern_ready,
      rx_runningdisp_o       => wr_rx_runningdisp,
      debug_o                => wr_debug,
      debug_i                => (others => '0'),
      pad_txp_o              => QSFPA_TX_p(0),
      pad_rxp_i              => QSFPA_RX_p(0)
    );

  -- QSFP-A provides the 125 MHz PHY/reference clock. QSFP-B is unused as a
  -- data lane, but its on-board reference input carries the 124.992 MHz
  -- offset clock required by the DDMTD phase detector.
  -- JTAG-only runtime observation path. It does not participate in WR timing.
  u_jtag_wb_mailbox : entity work.wr_jtag_wb_mailbox
    generic map (
      g_instance_id => "WR_WB_SLAVE"
    )
    port map (
      i_clk        => clk_sys_625,
      i_reset_n    => wr_core_reset_n,
      i_wb_slave_o => core_wb_o,
      o_wb_slave_i => core_wb_i
    );

  u_xwr_core : entity work.xwr_core
    generic map (
      g_with_external_clock_input => false,
      g_board_name                => "DE5A",
      g_phys_uart                 => true,
      g_virtual_uart              => true,
      g_aux_clks                  => 0,
      g_dpram_initf               => "../../build/firmware/slave/wrc.mif",
      g_dpram_size                => 49152,
      g_use_platform_specific_dpram => false,
      g_ep_rxbuf_size             => 1024,
      g_pcs_16bit                 => false,
      g_with_clock_freq_monitor   => true
    )
    port map (
      clk_sys_i                  => clk_sys_625,
      clk_dmtd_i                 => clk_dmtd_62m496,
      clk_ref_i                  => QSFPA_REFCLK_p,
      clk_ext_rst_o              => open,
      rst_n_i                    => wr_core_reset_n,

      dac_hpll_load_p1_o         => dac_hpll_load,
      dac_hpll_data_o            => dac_hpll_data,
      dac_dpll_load_p1_o         => dac_dpll_load,
      dac_dpll_data_o            => dac_dpll_data,

      phy_ref_clk_i              => QSFPA_REFCLK_p,
      phy_tx_data_o              => core_tx_data,
      phy_tx_k_o                 => core_tx_k,
      phy_tx_disparity_i         => wr_tx_disparity,
      phy_tx_enc_err_i           => wr_tx_enc_err,
      phy_rx_data_i              => wr_rx_data,
      phy_rx_rbclk_i             => wr_rx_clk,
      phy_rx_rbclk_sampled_i     => wr_rx_clk,
      phy_rx_k_i(0)              => wr_rx_data_k,
      phy_rx_enc_err_i           => wr_rx_enc_err,
      phy_rx_bitslide_i          => wr_rx_bitslide,
      phy_mdio_master_o          => open,
      phy_rst_o                  => core_phy_rst,
      phy_rdy_i                  => wr_ready,
      phy_loopen_o               => core_phy_loopen,
      phy_loopen_vec_o           => open,
      phy_tx_prbs_sel_o          => open,
      phy_sfp_tx_disable_o       => core_phy_tx_disable,
      phy8_o                     => open,
      phy16_o                    => open,

      led_act_o                  => open,
      led_link_o                 => open,
      scl_o                      => open,
      sda_o                      => open,
      sfp_scl_o                  => sfp_scl_o,
      sfp_scl_i                  => sfp_scl_i,
      sfp_sda_o                  => sfp_sda_o,
      sfp_sda_i                  => sfp_sda_i,
      sfp_det_i                  => QSFPA_MOD_PRS_n,
      btn1_i                     => BUTTON(1),
      btn2_i                     => BUTTON(2),
      spi_sclk_o                 => open,
      spi_ncs_o                  => open,
      spi_mosi_o                 => open,
      uart_rxd_i                 => RS422_DIN,
      uart_txd_o                 => uart_txd,
      owr_pwren_o                => open,
      owr_en_o                   => open,

      slave_i                    => core_wb_i,
      slave_o                    => core_wb_o,
      aux_master_o               => open,
      wrf_src_o                  => open,
      wrf_snk_o                  => open,
      timestamps_o               => open,
      abscal_txts_o              => open,
      abscal_rxts_o              => open,
      fc_tx_pause_ready_o        => open,
      tm_link_up_o               => core_tm_link_up,
      tm_dac_value_o             => open,
      tm_time_valid_o            => core_tm_time_valid,
      tm_tai_o                   => open,
      tm_cycles_o                => open,
      pps_csync_o                => open,
      pps_valid_o                => core_pps_valid,
      pps_p_o                    => SMA_CLKOUT,
      pps_led_o                  => open,
      rst_aux_n_o                => open,
      aux_diag_o                 => open,
      link_ok_o                  => core_link_ok,
      cpu_pc_o                  => cpu_pc,
      cpu_reset_o               => cpu_reset,
      cpu_fault_o               => cpu_fault,
      cpu_im_valid_o            => cpu_im_valid,
      cpu_boot_stage_value_o    => cpu_boot_stage_value,
      cpu_boot_stage_seen_o     => cpu_boot_stage_seen,
      cpu_entry_p_o             => cpu_entry_p,
      cpu_entry_generation_o    => cpu_entry_generation,
      cpu_last_store_addr_o     => cpu_last_store_addr,
      cpu_last_store_data_o     => cpu_last_store_data,
      cpu_last_store_seen_o     => cpu_last_store_seen,
      cpu_internal_store_count_o => cpu_internal_store_count,
      cpu_mepc_o               => cpu_mepc,
      cpu_mcause_o             => cpu_mcause,
      cpu_data_diag_addr_payload_o => cpu_data_diag_addr_payload,
      cpu_data_diag_meta_payload_o => cpu_data_diag_meta_payload,
      cpu_ram_diag_addr_payload_o => cpu_ram_diag_addr_payload,
      cpu_ram_diag_q_payload_o => cpu_ram_diag_q_payload,
      cpu_ram_diag_meta_payload_o => cpu_ram_diag_meta_payload,
      cpu_ram_diag_q0_payload_o => cpu_ram_diag_q0_payload,
      cpu_ram_init_diag_payload0_o => cpu_ram_init_diag_payload0,
      cpu_ram_init_diag_payload1_o => cpu_ram_init_diag_payload1,
      cpu_ram_init_diag_payload2_o => cpu_ram_init_diag_payload2,
      cpu_ram_init_diag_payload3_o => cpu_ram_init_diag_payload3,
      cpu_ram_init_diag_meta_payload_o => cpu_ram_init_diag_meta_payload,
      cpu_ram_primitive_diag_payload0_o => cpu_ram_primitive_diag_payload0,
      cpu_ram_primitive_diag_payload1_o => cpu_ram_primitive_diag_payload1,
      cpu_ram_primitive_diag_meta_payload_o => cpu_ram_primitive_diag_meta_payload,
      cpu_ram_port_a_diag_payload0_o => cpu_ram_port_a_diag_payload0,
      cpu_ram_port_a_diag_payload1_o => cpu_ram_port_a_diag_payload1,
      cpu_ram_port_a_diag_meta_payload_o => cpu_ram_port_a_diag_meta_payload
    );

  QSFPA_LP_MODE <= core_phy_tx_disable;

  -- Enable both directions of the on-board full-duplex RS422 transceiver.
  RS422_DE   <= '1';
  RS422_RE_n <= '0';
  RS422_DOUT <= uart_txd;

  LED(0)         <= si_config_done;
  LED(1)         <= wr_ready;
  LED(2)         <= core_tm_link_up;
  LED(3)         <= core_link_ok;
  LED_BRACKET(0) <= core_tm_time_valid;
  LED_BRACKET(1) <= core_pps_valid;
  LED_BRACKET(2) <= wr_rx_ready;
  LED_BRACKET(3) <= wr_tx_ready and not si_id_error;
end rtl;
