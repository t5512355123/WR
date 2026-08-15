-- DE5a White Rabbit Master top level.
-- The WRPC firmware image is generated from vendor/wrpc-sw and loaded by
-- xwr_core's internal RISC-V dual-port RAM.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity DE5a_wr_slave is
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
    QSFPA_SCL         : out   std_logic;
    QSFPA_SDA         : inout std_logic;
    QSFPA_TX_p        : out   std_logic_vector(3 downto 0);

    SI5340A_I2C_SCL   : out   std_logic;
    SI5340A_I2C_SDA   : inout std_logic;
    SI5340A_INTR      : in    std_logic;
    SI5340A_OE_n      : out   std_logic;
    SI5340A_RST_n     : out   std_logic;
    SMA_CLKOUT        : out   std_logic
  );
end DE5a_wr_slave;

architecture rtl of DE5a_wr_slave is
  component si5340a_controller is
    port (
      iCLK                  : in    std_logic;
      iRST_n                : in    std_logic;
      iStart                : in    std_logic;
      iPLL_OUT0_FREQ_SEL    : in    std_logic_vector(2 downto 0);
      iPLL_OUT1_FREQ_SEL    : in    std_logic_vector(2 downto 0);
      iPLL_OUT2_FREQ_SEL    : in    std_logic_vector(2 downto 0);
      iPLL_OUT3_FREQ_SEL    : in    std_logic_vector(2 downto 0);
      I2C_CLK               : out   std_logic;
      I2C_DATA              : inout std_logic;
      oPLL_I2C_ID_READ_ERROR: out   std_logic;
      oPLL_REG_CONFIG_DONE  : out   std_logic
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
  signal sync_probe           : std_logic_vector(63 downto 0);
  signal sync_source          : std_logic_vector(0 downto 0);
  signal dac_hpll_load        : std_logic;
  signal dac_hpll_data        : std_logic_vector(15 downto 0);
  signal dac_dpll_load        : std_logic;
  signal dac_dpll_data        : std_logic_vector(15 downto 0);
  signal dac_hpll_count       : unsigned(11 downto 0) := (others => '0');
  signal dac_dpll_count       : unsigned(11 downto 0) := (others => '0');

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

begin
  reconfig_reset(0) <= not CPU_RESET_n;

  -- Diagnostic only: count SoftPLL DAC update requests.  The counters are
  -- readable through the existing 64-bit JTAG probe and do not drive pins.
  p_dac_request_counters : process(CLK_50_B2J)
  begin
    if rising_edge(CLK_50_B2J) then
      if CPU_RESET_n = '0' then
        dac_hpll_count <= (others => '0');
        dac_dpll_count <= (others => '0');
      else
        if dac_hpll_load = '1' then
          dac_hpll_count <= dac_hpll_count + 1;
        end if;
        if dac_dpll_load = '1' then
          dac_dpll_count <= dac_dpll_count + 1;
        end if;
      end if;
    end if;
  end process;

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
  sync_probe(51 downto 40) <= std_logic_vector(dac_hpll_count);
  sync_probe(63 downto 52) <= std_logic_vector(dac_dpll_count);

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

  -- The board's SFP I2C pins are open-drain.  WRPC drives only the output
  -- low and releases the line for a logic high.
  QSFPA_SDA <= '0' when sfp_sda_o = '0' else 'Z';
  sfp_sda_i <= QSFPA_SDA;
  sfp_scl_i <= '1';

  QSFPA_MOD_SEL_n <= '0';
  QSFPA_RST_n     <= CPU_RESET_n;
  QSFPA_TX_p(3 downto 1) <= (others => '0');
  QSFPA_SCL       <= sfp_scl_o;
  SI5340A_OE_n    <= '0';
  SI5340A_RST_n   <= CPU_RESET_n;

  u_si5340a_controller : si5340a_controller
    port map (
      iCLK                   => CLK_50_B2J,
      iRST_n                 => CPU_RESET_n,
      iStart                 => not BUTTON(0),
      iPLL_OUT0_FREQ_SEL     => SI5340_125M,
      iPLL_OUT1_FREQ_SEL     => SI5340_124M992,
      iPLL_OUT2_FREQ_SEL     => SI5340_POWER_DOWN,
      iPLL_OUT3_FREQ_SEL     => SI5340_POWER_DOWN,
      I2C_CLK                => SI5340A_I2C_SCL,
      I2C_DATA               => SI5340A_I2C_SDA,
      oPLL_I2C_ID_READ_ERROR => si_id_error,
      oPLL_REG_CONFIG_DONE   => si_config_done
    );

  u_wr_arria10_transceiver : wr_arria10_transceiver
    generic map (
      g_family => "Arria 10 GX E3P1"
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
      drop_link_i            => (not CPU_RESET_n) or core_phy_rst,
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
  u_xwr_core : entity work.xwr_core
    generic map (
      g_with_external_clock_input => false,
      g_board_name                => "DE5A",
      g_phys_uart                 => false,
      g_virtual_uart              => true,
      g_aux_clks                  => 0,
      g_dpram_initf               => "firmware/wrc_de5a_slave_nosfpmatch.mif",
      g_dpram_size                => 49152,
      g_use_platform_specific_dpram => false,
      g_ep_rxbuf_size             => 1024,
      g_pcs_16bit                 => false,
      g_with_clock_freq_monitor   => true
    )
    port map (
      clk_sys_i                  => CLK_50_B2J,
      clk_dmtd_i                 => QSFPB_REFCLK_p,
      clk_ref_i                  => QSFPA_REFCLK_p,
      clk_ext_rst_o              => open,
      rst_n_i                    => CPU_RESET_n,

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
      uart_txd_o                 => open,
      owr_pwren_o                => open,
      owr_en_o                   => open,

      slave_o                    => open,
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
      link_ok_o                  => core_link_ok
    );

  QSFPA_LP_MODE <= core_phy_tx_disable;

  LED(0)         <= si_config_done;
  LED(1)         <= wr_ready;
  LED(2)         <= core_tm_link_up;
  LED(3)         <= core_link_ok;
  LED_BRACKET(0) <= core_tm_time_valid;
  LED_BRACKET(1) <= core_pps_valid;
  LED_BRACKET(2) <= wr_rx_ready;
  LED_BRACKET(3) <= wr_tx_ready and not si_id_error;
end rtl;
