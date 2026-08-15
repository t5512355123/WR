-------------------------------------------------------------------------------
-- Title      : Deterministic Altera PHY wrapper - Arria 10
-- Project    : WR PTP Core
-- URL        : http://www.ohwr.org/projects/wr-cores/wiki/Wrpc_core
-------------------------------------------------------------------------------
-- File       : wr_arria10_phy.vhd
-- Authors    : A. Hahn
-- Company    : GSI
-- Created    : 2018-12-04
-- Last update: 2018-12-04
-- Standard   : VHDL'93
-------------------------------------------------------------------------------
-- Description: Single channel wrapper for deterministic PHY
-------------------------------------------------------------------------------
--
-- Copyright (c) 2018 GSI / A. Hahn
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
--
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.endpoint_pkg.all;
use work.wr_altera_pkg.all;
use work.gencores_pkg.all;
use work.altera_networks_pkg.all;

entity wr_arria10_transceiver is
  generic (
    g_family          : string;           -- Family/device, possible options are: "Arria 10 GX " or "Arria 10 GX E3P1"
    g_use_atx_pll     : boolean := true;  -- Use ATX PLL?
    g_use_cmu_pll     : boolean := false; -- Use CMU PLL?
    g_use_simple_wa   : boolean := false; -- Use simple word aligner (following altera/intel documentation)?
    g_use_det_phy     : boolean := true;  -- Use deterministic or standard PHY?
    g_use_sfp_los_rst : boolean := true;  -- Reset on SFP los (pulled out SFP, ...)?
    g_use_ext_loop    : boolean := true;  -- Enable internal loop (controlled by loopen_i)?
    g_use_ext_rst     : boolean := true); -- Enable external reset signal (triggerd by drop_link_i)?
  port (
    clk_ref_i              : in  std_logic := '0';                                 -- Input clock from WR extension [125Mhz]
    clk_phy_i              : in  std_logic := '0';                                 -- Input clock from WR extension [125Mhz]
    reconfig_write_i       : in  std_logic_vector(0 downto 0) := (others => '0');  -- Reconfig interface -> write
    reconfig_read_i        : in  std_logic_vector(0 downto 0) := (others => '0');  -- Reconfig interface -> read
    reconfig_address_i     : in  std_logic_vector(9 downto 0) := (others => '0');  -- Reconfig interface -> address
    reconfig_writedata_i   : in  std_logic_vector(31 downto 0) := (others => '0'); -- Reconfig interface -> data to write
    reconfig_readdata_o    : out std_logic_vector(31 downto 0);                    -- Reconfig interface -> read data from reconfig
    reconfig_waitrequest_o : out std_logic_vector(0 downto 0);                     -- Reconfig interface -> wait
    reconfig_clk_i         : in  std_logic_vector(0 downto 0) := (others => '0');  -- Reconfig interface -> input clock
    reconfig_reset_i       : in  std_logic_vector(0 downto 0) := (others => '0');  -- Reconfig interfacer -> reset
    ready_o                : out std_logic;                                        -- TX and RX ready
    drop_link_i            : in  std_logic := '0';                                 -- Drop link (reset)
    loopen_i               : in  std_logic := '0';                                 -- Loop enable
    sfp_los_i              : in  std_logic := '0';                                 -- SFP LOS
    tx_clk_o               : out std_logic;                                        -- TX clock to WR core
    tx_data_i              : in  std_logic_vector(7 downto 0) := (others => '0');  -- Data from WR core
    tx_ready_o             : out std_logic;                                        -- TX ready
    tx_disparity_o         : out std_logic;                                        -- Always zero
    tx_enc_err_o           : out std_logic;                                        -- Always zero
    tx_data_k_i            : in  std_logic := '0';                                 -- TX data k
    rx_clk_o               : out std_logic;                                        -- RX clock to WR core
    rx_data_o              : out std_logic_vector(7 downto 0);                     -- Data to WR core
    rx_ready_o             : out std_logic;                                        -- RX ready
    rx_data_k_o            : out std_logic;                                        -- RX data k
    rx_enc_err_o           : out std_logic;                                        -- RX Enc. error
    rx_bitslide_o          : out std_logic_vector(3 downto 0);                     -- RX bitslide
    rx_lockedtodata_o      : out std_logic;                                        -- RX CDR locked to data
    rx_lockedtoref_o       : out std_logic;                                        -- RX CDR locked to reference
    rx_disperr_o           : out std_logic;                                        -- RX disparity error
    rx_errdetect_o         : out std_logic;                                        -- RX 8b/10b error detect
    rx_syncstatus_o        : out std_logic;                                        -- RX word synchronizer status
    rx_patterndetect_o     : out std_logic;                                        -- RX comma/pattern detect
    rx_patterndetect_ready_o : out std_logic;                                      -- RX pattern alignment ready
    rx_runningdisp_o       : out std_logic;                                        -- RX running disparity
    debug_o                : out std_logic;                                        -- For debugging
    debug_i                : in  std_logic_vector(7 downto 0) := (others => '0');  -- For debugging
    pad_txp_o              : out std_logic;                                        -- SFP out
    pad_rxp_i              : in  std_logic := '0'                                  -- SFP in
  );
end wr_arria10_transceiver;

architecture rtl of wr_arria10_transceiver is

  signal s_pll_select              : std_logic_vector(0 downto 0);
  signal s_cal_busy                : std_logic_vector(0 downto 0);

  signal s_rx_clk                  : std_logic;
  signal s_tx_clk                  : std_logic;

  signal s_tx_pll_serial_clk       : std_logic;
  signal s_tx_pll_locked           : std_logic_vector(0 downto 0);
  signal s_tx_pll_cal_busy         : std_logic;
  signal s_tx_bonding_clocks       : std_logic_vector(5 downto 0);

  signal s_rst_ctl_powerdown       : std_logic_vector(0 downto 0);
  signal s_rst_ctl_rst             : std_logic;
  signal s_rst_ctl_tx_analogreset  : std_logic_vector(0 downto 0);
  signal s_rst_ctl_tx_digitalreset : std_logic_vector(0 downto 0);
  signal s_rst_ctl_rx_analogreset  : std_logic_vector(0 downto 0);
  signal s_rst_ctl_rx_digitalreset : std_logic_vector(0 downto 0);
  signal s_rst_ctl_tx_ready        : std_logic_vector(0 downto 0);
  signal s_rst_ctl_rx_ready        : std_logic_vector(0 downto 0);

  signal s_phy_tx_cal_busy         : std_logic_vector(0 downto 0);
  signal s_phy_rx_cal_busy         : std_logic_vector(0 downto 0);
  signal s_phy_rx_is_lockedtodata  : std_logic_vector(0 downto 0);
  signal s_phy_rx_is_lockedtoref   : std_logic_vector(0 downto 0);
  signal s_phy_rx_disperr          : std_logic_vector(0 downto 0);
  signal s_phy_rx_errdetect        : std_logic_vector(0 downto 0);

  signal s_reconfig_write          : std_logic_vector(0 downto 0);
  signal s_reconfig_read           : std_logic_vector(0 downto 0);
  signal s_reconfig_address        : std_logic_vector(9 downto 0);
  signal s_reconfig_writedata      : std_logic_vector(31 downto 0);
  signal s_reconfig_readdata       : std_logic_vector(31 downto 0);
  signal s_reconfig_waitrequest    : std_logic_vector(0 downto 0);

  signal s_rx_std_wa_patternalign  : std_logic;
  signal s_rx_std_wa_pa_ext        : std_logic;
  signal s_syncstatus              : std_logic;
  signal s_patterndetect           : std_logic;
  signal s_patterndetect_prev      : std_logic;
  signal s_patterndetect_ready     : std_logic;
  signal s_reset_aligner           : std_logic;
  signal s_scan_cnt                : std_logic_vector (5 downto 0);
  signal s_scan_wdg                : std_logic_vector (7 downto 0);
  signal s_tx_data                 : std_logic_vector(7 downto 0);
  signal s_rx_data                 : std_logic_vector(7 downto 0);
  signal s_rx_data_k               : std_logic;
  signal s_tx_data_k               : std_logic;
  signal s_rx_data_delayed         : std_logic_vector(7 downto 0);
  signal s_rx_data_delayed_prev    : std_logic_vector(7 downto 0);
  signal s_wait_cnt                : std_logic_vector (3 downto 0);
  signal s_found_k28_7_pattern     : std_logic;
  signal s_loop_en                 : std_logic;
  signal s_phy_ready               : std_logic;
  signal s_ready_synced            : std_logic;
  signal s_ready_synced_rx         : std_logic;
  signal s_ready_synced_tx         : std_logic;
  signal s_rst_ctl_rst_sync        : std_logic;
  signal s_rst_ctl_rst_sync_rx     : std_logic;

  signal s_debug_reset             : std_logic;
  signal s_sfp_los_reset           : std_logic;
  signal s_ext_reset               : std_logic;

  signal s_rx_runningdisp          : std_logic;
  signal s_rx_bs_dump              : std_logic;

  signal s_reconf_dirty_sync_count : std_logic_vector (9 downto 0);

  type   t_state is (SCAN_K28_5, BITSLIP, BITSLIP_EXTENT_ONE, IDLE, SYNC);
  signal bit_slip_state : t_state := SCAN_K28_5;

  type   lcr_fake_state is (IDLE, FOUND_K28_5, FAKE_FD, FAKE_ACK);
  signal s_rx_fake_link_state : lcr_fake_state := IDLE;
  signal s_tx_fake_link_state : lcr_fake_state := IDLE;

  constant c_d21_5 : std_logic_vector(7 downto 0) := "10110101"; -- 0xb5
  constant c_d2_2  : std_logic_vector(7 downto 0) := "01000010"; -- 0x42
  constant c_d5_6  : std_logic_vector(7 downto 0) := "11000101"; -- 0xc5
  constant c_d16_2 : std_logic_vector(7 downto 0) := "01010000"; -- 0x50

  constant c_k28_5 : std_logic_vector(7 downto 0) := "10111100"; -- 0xbc
  constant c_k23_7 : std_logic_vector(7 downto 0) := "11110111"; -- 0xf7
  constant c_k27_7 : std_logic_vector(7 downto 0) := "11111011"; -- 0xfb
  constant c_k29_7 : std_logic_vector(7 downto 0) := "11111101"; -- 0xfd
  constant c_k30_7 : std_logic_vector(7 downto 0) := "11111110"; -- 0xfe
  constant c_k28_7 : std_logic_vector(7 downto 0) := "11111100"; -- 0xfc

begin

  -- Reconf interface, clock crossing ignored (only for debugging)
  reconf_dirty_sync : process(clk_phy_i, s_rst_ctl_rst_sync) is
  begin
    if s_rst_ctl_rst_sync = '1' then
      s_reconf_dirty_sync_count <= (others => '0');
      s_reconfig_write          <= (others => '0');
      s_reconfig_read           <= (others => '0');
      s_reconfig_address        <= (others => '0');
      s_reconfig_writedata      <= (others => '0');
    elsif rising_edge(clk_phy_i) then
      s_reconf_dirty_sync_count <= std_logic_vector(unsigned(s_reconf_dirty_sync_count) + 1);
      if s_reconf_dirty_sync_count = "1111111111" then
        s_reconfig_write     <= reconfig_write_i;
        s_reconfig_read      <= reconfig_read_i;
        s_reconfig_address   <= reconfig_address_i;
        s_reconfig_writedata <= reconfig_writedata_i;
      end if;
    end if;
  end process;
  reconfig_readdata_o    <= s_reconfig_readdata;
  reconfig_waitrequest_o <= s_reconfig_waitrequest;

  mgmt_rst_sync : gc_sync_ffs
    port map (
      clk_i    => clk_phy_i,
      rst_n_i  => '1',
      data_i   => s_rst_ctl_rst,
      synced_o => s_rst_ctl_rst_sync
    );

  det_phy : if g_use_det_phy generate
    scu4_phy: if (g_family = "Arria 10 GX SCU4") generate
      inst_phy : wr_arria10_scu4_det_phy
        port map (
          tx_analogreset(0)                     => s_rst_ctl_tx_analogreset(0),
          tx_digitalreset(0)                    => s_rst_ctl_tx_digitalreset(0),
          rx_analogreset(0)                     => s_rst_ctl_rx_analogreset(0),
          rx_digitalreset(0)                    => s_rst_ctl_rx_digitalreset(0),
          tx_cal_busy(0)                        => s_phy_tx_cal_busy(0),
          rx_cal_busy(0)                        => s_phy_rx_cal_busy(0),
          tx_bonding_clocks                     => s_tx_bonding_clocks,
          rx_cdr_refclk0                        => clk_phy_i,
          tx_serial_data(0)                     => pad_txp_o,
          rx_serial_data(0)                     => pad_rxp_i,
          rx_is_lockedtoref                     => s_phy_rx_is_lockedtoref,
          rx_is_lockedtodata                    => s_phy_rx_is_lockedtodata,
          tx_coreclkin(0)                       => clk_ref_i,
          rx_coreclkin(0)                       => clk_ref_i,
          tx_clkout(0)                          => s_tx_clk,
          rx_clkout(0)                          => s_rx_clk,
          tx_parallel_data                      => s_tx_data,
          rx_parallel_data                      => s_rx_data,
          rx_datak                              => s_rx_data_k,
          rx_disperr                            => s_phy_rx_disperr(0),
          rx_errdetect                          => s_phy_rx_errdetect(0),
          rx_patterndetect                      => s_patterndetect,
          rx_runningdisp                        => s_rx_runningdisp,
          rx_syncstatus                         => s_syncstatus,
          tx_datak                              => s_tx_data_k,
          unused_rx_parallel_data               => open,
          reconfig_clk(0)                       => clk_phy_i,
          reconfig_reset(0)                     => s_rst_ctl_rst_sync,
          reconfig_write                        => s_reconfig_write,
          reconfig_read                         => s_reconfig_read,
          reconfig_address                      => s_reconfig_address,
          reconfig_writedata                    => s_reconfig_writedata,
          reconfig_readdata                     => s_reconfig_readdata,
          reconfig_waitrequest                  => s_reconfig_waitrequest,
          tx_std_bitslipboundarysel             => "00000",
          rx_std_bitslipboundarysel(3 downto 0) => rx_bitslide_o(3 downto 0),
          rx_std_bitslipboundarysel(4)          => s_rx_bs_dump,
          rx_seriallpbken(0)                    => s_loop_en
        );
    end generate scu4_phy;

    ftm4_phy: if (g_family = "Arria 10 GX FTM4") generate
      inst_phy : wr_arria10_ftm4_det_phy
        port map (
          tx_analogreset(0)                     => s_rst_ctl_tx_analogreset(0),
          tx_digitalreset(0)                    => s_rst_ctl_tx_digitalreset(0),
          rx_analogreset(0)                     => s_rst_ctl_rx_analogreset(0),
          rx_digitalreset(0)                    => s_rst_ctl_rx_digitalreset(0),
          tx_cal_busy(0)                        => s_phy_tx_cal_busy(0),
          rx_cal_busy(0)                        => s_phy_rx_cal_busy(0),
          tx_bonding_clocks                     => s_tx_bonding_clocks,
          rx_cdr_refclk0                        => clk_phy_i,
          tx_serial_data(0)                     => pad_txp_o,
          rx_serial_data(0)                     => pad_rxp_i,
          rx_is_lockedtoref                     => s_phy_rx_is_lockedtoref,
          rx_is_lockedtodata                    => s_phy_rx_is_lockedtodata,
          tx_coreclkin(0)                       => clk_ref_i,
          rx_coreclkin(0)                       => clk_ref_i,
          tx_clkout(0)                          => s_tx_clk,
          rx_clkout(0)                          => s_rx_clk,
          tx_parallel_data                      => s_tx_data,
          rx_parallel_data                      => s_rx_data,
          rx_datak                              => s_rx_data_k,
          rx_disperr                            => s_phy_rx_disperr(0),
          rx_errdetect                          => s_phy_rx_errdetect(0),
          rx_patterndetect                      => s_patterndetect,
          rx_runningdisp                        => s_rx_runningdisp,
          rx_syncstatus                         => s_syncstatus,
          tx_datak                              => s_tx_data_k,
          unused_rx_parallel_data               => open,
          reconfig_clk(0)                       => clk_phy_i,
          reconfig_reset(0)                     => s_rst_ctl_rst_sync,
          reconfig_write                        => s_reconfig_write,
          reconfig_read                         => s_reconfig_read,
          reconfig_address                      => s_reconfig_address,
          reconfig_writedata                    => s_reconfig_writedata,
          reconfig_readdata                     => s_reconfig_readdata,
          reconfig_waitrequest                  => s_reconfig_waitrequest,
          tx_std_bitslipboundarysel             => "00000",
          rx_std_bitslipboundarysel(3 downto 0) => rx_bitslide_o(3 downto 0),
          rx_std_bitslipboundarysel(4)          => s_rx_bs_dump,
          rx_seriallpbken(0)                    => s_loop_en
        );
    end generate ftm4_phy;

      pex10_phy: if (g_family = "Arria 10 GX PEX10") generate
        inst_phy : wr_arria10_pex10_det_phy
          port map (
            tx_analogreset(0)                     => s_rst_ctl_tx_analogreset(0),
            tx_digitalreset(0)                    => s_rst_ctl_tx_digitalreset(0),
            rx_analogreset(0)                     => s_rst_ctl_rx_analogreset(0),
            rx_digitalreset(0)                    => s_rst_ctl_rx_digitalreset(0),
            tx_cal_busy(0)                        => s_phy_tx_cal_busy(0),
            rx_cal_busy(0)                        => s_phy_rx_cal_busy(0),
            tx_bonding_clocks                     => s_tx_bonding_clocks,
            rx_cdr_refclk0                        => clk_phy_i,
            tx_serial_data(0)                     => pad_txp_o,
            rx_serial_data(0)                     => pad_rxp_i,
            rx_is_lockedtoref                     => s_phy_rx_is_lockedtoref,
            rx_is_lockedtodata                    => s_phy_rx_is_lockedtodata,
            tx_coreclkin(0)                       => clk_ref_i,
            rx_coreclkin(0)                       => clk_ref_i,
            tx_clkout(0)                          => s_tx_clk,
            rx_clkout(0)                          => s_rx_clk,
            tx_parallel_data                      => s_tx_data,
            rx_parallel_data                      => s_rx_data,
            rx_datak                              => s_rx_data_k,
            rx_disperr                            => s_phy_rx_disperr(0),
            rx_errdetect                          => s_phy_rx_errdetect(0),
            rx_patterndetect                      => s_patterndetect,
            rx_runningdisp                        => s_rx_runningdisp,
            rx_syncstatus                         => s_syncstatus,
            tx_datak                              => s_tx_data_k,
            unused_rx_parallel_data               => open,
            reconfig_clk(0)                       => clk_phy_i,
            reconfig_reset(0)                     => s_rst_ctl_rst_sync,
            reconfig_write                        => s_reconfig_write,
            reconfig_read                         => s_reconfig_read,
            reconfig_address                      => s_reconfig_address,
            reconfig_writedata                    => s_reconfig_writedata,
            reconfig_readdata                     => s_reconfig_readdata,
            reconfig_waitrequest                  => s_reconfig_waitrequest,
            tx_std_bitslipboundarysel             => "00000",
            rx_std_bitslipboundarysel(3 downto 0) => rx_bitslide_o(3 downto 0),
            rx_std_bitslipboundarysel(4)          => s_rx_bs_dump,
            rx_seriallpbken(0)                    => s_loop_en
          );
      end generate pex10_phy;

        ftm10_phy: if (g_family = "Arria 10 GX FTM10") generate
          inst_phy : wr_arria10_ftm10_det_phy
            port map (
              tx_analogreset(0)                     => s_rst_ctl_tx_analogreset(0),
              tx_digitalreset(0)                    => s_rst_ctl_tx_digitalreset(0),
              rx_analogreset(0)                     => s_rst_ctl_rx_analogreset(0),
              rx_digitalreset(0)                    => s_rst_ctl_rx_digitalreset(0),
              tx_cal_busy(0)                        => s_phy_tx_cal_busy(0),
              rx_cal_busy(0)                        => s_phy_rx_cal_busy(0),
              tx_bonding_clocks                     => s_tx_bonding_clocks,
              rx_cdr_refclk0                        => clk_phy_i,
              tx_serial_data(0)                     => pad_txp_o,
              rx_serial_data(0)                     => pad_rxp_i,
              rx_is_lockedtoref                     => s_phy_rx_is_lockedtoref,
              rx_is_lockedtodata                    => s_phy_rx_is_lockedtodata,
              tx_coreclkin(0)                       => clk_ref_i,
              rx_coreclkin(0)                       => clk_ref_i,
              tx_clkout(0)                          => s_tx_clk,
              rx_clkout(0)                          => s_rx_clk,
              tx_parallel_data                      => s_tx_data,
              rx_parallel_data                      => s_rx_data,
              rx_datak                              => s_rx_data_k,
              rx_disperr                            => s_phy_rx_disperr(0),
              rx_errdetect                          => s_phy_rx_errdetect(0),
              rx_patterndetect                      => s_patterndetect,
              rx_runningdisp                        => s_rx_runningdisp,
              rx_syncstatus                         => s_syncstatus,
              tx_datak                              => s_tx_data_k,
              unused_rx_parallel_data               => open,
              reconfig_clk(0)                       => clk_phy_i,
              reconfig_reset(0)                     => s_rst_ctl_rst_sync,
              reconfig_write                        => s_reconfig_write,
              reconfig_read                         => s_reconfig_read,
              reconfig_address                      => s_reconfig_address,
              reconfig_writedata                    => s_reconfig_writedata,
              reconfig_readdata                     => s_reconfig_readdata,
              reconfig_waitrequest                  => s_reconfig_waitrequest,
              tx_std_bitslipboundarysel             => "00000",
              rx_std_bitslipboundarysel(3 downto 0) => rx_bitslide_o(3 downto 0),
              rx_std_bitslipboundarysel(4)          => s_rx_bs_dump,
              rx_seriallpbken(0)                    => s_loop_en
            );
        end generate ftm10_phy;

    e3p1_phy: if (g_family = "Arria 10 GX E3P1") generate
      inst_phy : wr_arria10_e3p1_det_phy
        port map (
          tx_analogreset(0)                     => s_rst_ctl_tx_analogreset(0),
          tx_digitalreset(0)                    => s_rst_ctl_tx_digitalreset(0),
          rx_analogreset(0)                     => s_rst_ctl_rx_analogreset(0),
          rx_digitalreset(0)                    => s_rst_ctl_rx_digitalreset(0),
          tx_cal_busy(0)                        => s_phy_tx_cal_busy(0),
          rx_cal_busy(0)                        => s_phy_rx_cal_busy(0),
          tx_serial_clk0(0)                     => s_tx_pll_serial_clk,
          rx_cdr_refclk0                        => clk_phy_i,
          tx_serial_data(0)                     => pad_txp_o,
          rx_serial_data(0)                     => pad_rxp_i,
          rx_is_lockedtoref                     => s_phy_rx_is_lockedtoref,
          rx_is_lockedtodata                    => s_phy_rx_is_lockedtodata,
          tx_coreclkin(0)                       => clk_ref_i,
          rx_coreclkin(0)                       => clk_ref_i,
          tx_clkout(0)                          => s_tx_clk,
          rx_clkout(0)                          => s_rx_clk,
          tx_parallel_data                      => s_tx_data,
          rx_parallel_data                      => s_rx_data,
          rx_datak                              => s_rx_data_k,
          rx_disperr                            => s_phy_rx_disperr(0),
          rx_errdetect                          => s_phy_rx_errdetect(0),
          rx_patterndetect                      => s_patterndetect,
          rx_runningdisp                        => s_rx_runningdisp,
          rx_syncstatus                         => s_syncstatus,
          tx_datak                              => s_tx_data_k,
          rx_std_wa_patternalign(0)             => s_rx_std_wa_patternalign,
          reconfig_clk(0)                       => clk_phy_i,
          reconfig_reset(0)                     => s_rst_ctl_rst_sync,
          reconfig_write                        => s_reconfig_write,
          reconfig_read                         => s_reconfig_read,
          reconfig_address                      => s_reconfig_address,
          reconfig_writedata                    => s_reconfig_writedata,
          reconfig_readdata                     => s_reconfig_readdata,
          reconfig_waitrequest                  => s_reconfig_waitrequest,
          rx_std_bitslipboundarysel(3 downto 0) => rx_bitslide_o(3 downto 0),
          rx_std_bitslipboundarysel(4)          => s_rx_bs_dump,
          rx_seriallpbken(0)                    => s_loop_en
        );
    end generate e3p1_phy;

      tx_clk_o <= s_tx_clk;
      rx_clk_o <= s_rx_clk;
      s_tx_data   <= tx_data_i;
      s_tx_data_k <= tx_data_k_i;
      rx_data_o   <= s_rx_data;
      rx_data_k_o <= s_rx_data_k;
      rx_lockedtodata_o <= s_phy_rx_is_lockedtodata(0);
      rx_lockedtoref_o <= s_phy_rx_is_lockedtoref(0);
      rx_disperr_o <= s_phy_rx_disperr(0);
      rx_errdetect_o <= s_phy_rx_errdetect(0);
      rx_syncstatus_o <= s_syncstatus;
      rx_patterndetect_o <= s_patterndetect;
      rx_patterndetect_ready_o <= s_patterndetect_ready;
      rx_runningdisp_o <= s_rx_runningdisp;

    complex_wa : if not(g_use_simple_wa) generate

      -- Pattern align watchdog
      pattern_align_wdg : process(s_rx_clk, s_rst_ctl_rst_sync) is
      begin
        if s_rst_ctl_rst = '1' then
          s_reset_aligner <= '0';
          s_scan_wdg      <= (others => '0');
        elsif rising_edge(s_rx_clk) then
          if s_rst_ctl_rx_digitalreset(0) = '0' then
            s_scan_wdg      <= std_logic_vector(unsigned(s_scan_wdg) + 1);
            if (s_scan_wdg = "11111111" and s_patterndetect_ready = '0') then
              s_reset_aligner <= '1';
            else
              s_reset_aligner <= '0';
            end if;
          end if;
        end if;
      end process;

      -- Follow recommended wa_patternalign control
      pattern_align : process(s_rx_clk, s_rst_ctl_rst_sync) is
      begin
        if s_rst_ctl_rst_sync = '1' then
          s_rx_std_wa_patternalign <= '0';
          s_scan_cnt               <= (others => '0');
        elsif rising_edge(s_rx_clk) then
          if s_rst_ctl_rx_digitalreset(0) = '0' then
            s_scan_cnt <= std_logic_vector(unsigned(s_scan_cnt) + 1);
            if s_scan_cnt = "000000" then
              if s_patterndetect_ready = '0' then
                s_rx_std_wa_patternalign <= '1';
              else
                s_rx_std_wa_patternalign <= '0';
              end if;
            elsif s_scan_cnt = "000001" then
              if s_rx_std_wa_patternalign = '1' then
                s_rx_std_wa_patternalign <= '1';
              else
                s_rx_std_wa_patternalign <= '0';
              end if;
            else
              s_rx_std_wa_patternalign <= '0';
            end if;
          else
            s_rx_std_wa_patternalign <= '0';
            s_scan_cnt <= (others => '0');
          end if; -- RST/CLK
        end if; --Rising CLK
      end process;

      patterndetect_extend : process(s_rx_clk, s_rst_ctl_rst_sync) is -- generic!
      begin
        if s_rst_ctl_rst_sync = '1' then
          s_patterndetect_ready <= '0';
        elsif rising_edge(s_rx_clk) then
          if s_rst_ctl_rx_digitalreset(0) = '0' then
            if s_syncstatus = '1' and s_patterndetect = '1' then
              s_patterndetect_ready <= '1';
            elsif s_reset_aligner = '1' then
              s_patterndetect_ready <= '0';
            end if;
          end if;
        end if;
      end process;
	end generate complex_wa;

  simple_wa : if g_use_simple_wa generate
    simple_wa_mode : process(s_rx_clk, s_rst_ctl_rst_sync) is
      begin
        if s_rst_ctl_rst_sync = '1' then
          s_patterndetect_ready    <= '0';
          s_rx_std_wa_patternalign <= '0';
        elsif rising_edge(s_rx_clk) then
          if s_rst_ctl_rx_digitalreset(0) = '0' then
            if s_syncstatus = '1' and s_patterndetect = '1' then
              s_patterndetect_ready    <= '1';
              s_rx_std_wa_patternalign <= '0';
           elsif s_phy_rx_errdetect(0) = '1' then
              s_patterndetect_ready    <= '0';
              s_rx_std_wa_patternalign <= '1';
           elsif s_phy_rx_disperr(0) = '1' then
              s_patterndetect_ready    <= '0';
              s_rx_std_wa_patternalign <= '1';
          elsif s_patterndetect_ready = '0' then
              s_patterndetect_ready    <= '0';
              s_rx_std_wa_patternalign <= '1';
          end if;
        end if;
      end if;
    end process;
  end generate simple_wa;

    scu4_pll_and_reset: if (g_family = "Arria 10 GX SCU4") generate
      inst_rst_ctl : wr_arria10_scu4_rst_ctl
        port map (
          clock                 => clk_ref_i,
          reset                 => s_rst_ctl_rst,
          pll_powerdown(0)      => s_rst_ctl_powerdown(0), -- Missing at Intel documentation -> Connection Guidelines for a CPRI PHY Design
          tx_analogreset(0)     => s_rst_ctl_tx_analogreset(0),
          tx_digitalreset(0)    => s_rst_ctl_tx_digitalreset(0),
          tx_ready(0)           => s_rst_ctl_tx_ready(0),
          pll_locked(0)         => s_tx_pll_locked(0),
          pll_select(0)         => s_pll_select(0),
          tx_cal_busy(0)        => s_cal_busy(0),
          rx_analogreset(0)     => s_rst_ctl_rx_analogreset(0),
          rx_digitalreset(0)    => s_rst_ctl_rx_digitalreset(0),
          rx_ready(0)           => s_rst_ctl_rx_ready(0),
          rx_is_lockedtodata(0) => s_phy_rx_is_lockedtodata(0),
          rx_cal_busy(0)        => s_phy_rx_cal_busy(0)
        );

      atx_pll : if g_use_atx_pll generate
        inst_atx_pll : wr_arria10_scu4_atx_pll
          port map (
           pll_refclk0       => clk_ref_i,
           pll_powerdown     => s_rst_ctl_powerdown(0), -- Missing at Intel documentation -> Connection Guidelines for a CPRI PHY Design
           pll_locked        => s_tx_pll_locked(0),
           tx_serial_clk     => s_tx_pll_serial_clk,
           pll_cal_busy      => s_tx_pll_cal_busy,
           mcgb_rst          => s_rst_ctl_powerdown(0),
           tx_bonding_clocks => s_tx_bonding_clocks
          );
        end generate atx_pll;

      cmu_pll : if g_use_cmu_pll generate
        inst_cmu_pll : wr_arria10_scu4_cmu_pll
          port map (
            pll_refclk0   => clk_phy_i,
            pll_powerdown => s_rst_ctl_powerdown(0), -- Missing at Intel documentation -> Connection Guidelines for a CPRI PHY Design
            pll_locked    => s_tx_pll_locked(0),
            tx_serial_clk => s_tx_pll_serial_clk,
            pll_cal_busy  => s_tx_pll_cal_busy
          );
        end generate cmu_pll;
    end generate scu4_pll_and_reset;

    ftm4_pll_and_reset: if (g_family = "Arria 10 GX FTM4") generate
      inst_rst_ctl : wr_arria10_ftm4_rst_ctl
        port map (
          clock                 => clk_ref_i,
          reset                 => s_rst_ctl_rst,
          pll_powerdown(0)      => s_rst_ctl_powerdown(0), -- Missing at Intel documentation -> Connection Guidelines for a CPRI PHY Design
          tx_analogreset(0)     => s_rst_ctl_tx_analogreset(0),
          tx_digitalreset(0)    => s_rst_ctl_tx_digitalreset(0),
          tx_ready(0)           => s_rst_ctl_tx_ready(0),
          pll_locked(0)         => s_tx_pll_locked(0),
          pll_select(0)         => s_pll_select(0),
          tx_cal_busy(0)        => s_cal_busy(0),
          rx_analogreset(0)     => s_rst_ctl_rx_analogreset(0),
          rx_digitalreset(0)    => s_rst_ctl_rx_digitalreset(0),
          rx_ready(0)           => s_rst_ctl_rx_ready(0),
          rx_is_lockedtodata(0) => s_phy_rx_is_lockedtodata(0),
          rx_cal_busy(0)        => s_phy_rx_cal_busy(0)
        );

      atx_pll : if g_use_atx_pll generate
        inst_atx_pll : wr_arria10_ftm4_atx_pll
          port map (
            pll_refclk0       => clk_ref_i,
            pll_powerdown     => s_rst_ctl_powerdown(0), -- Missing at Intel documentation -> Connection Guidelines for a CPRI PHY Design
            pll_locked        => s_tx_pll_locked(0),
            tx_serial_clk     => s_tx_pll_serial_clk,
            pll_cal_busy      => s_tx_pll_cal_busy,
            mcgb_rst          => s_rst_ctl_powerdown(0),
            tx_bonding_clocks => s_tx_bonding_clocks
          );
        end generate atx_pll;

      cmu_pll : if g_use_cmu_pll generate
        inst_cmu_pll : wr_arria10_ftm4_cmu_pll
          port map (
            pll_refclk0   => clk_phy_i,
            pll_powerdown => s_rst_ctl_powerdown(0), -- Missing at Intel documentation -> Connection Guidelines for a CPRI PHY Design
            pll_locked    => s_tx_pll_locked(0),
            tx_serial_clk => s_tx_pll_serial_clk,
            pll_cal_busy  => s_tx_pll_cal_busy
          );
        end generate cmu_pll;
    end generate ftm4_pll_and_reset;

    pex10_pll_and_reset: if (g_family = "Arria 10 GX PEX10") generate
      inst_rst_ctl : wr_arria10_pex10_rst_ctl
        port map (
          clock                 => clk_ref_i,
          reset                 => s_rst_ctl_rst,
          pll_powerdown(0)      => s_rst_ctl_powerdown(0), -- Missing at Intel documentation -> Connection Guidelines for a CPRI PHY Design
          tx_analogreset(0)     => s_rst_ctl_tx_analogreset(0),
          tx_digitalreset(0)    => s_rst_ctl_tx_digitalreset(0),
          tx_ready(0)           => s_rst_ctl_tx_ready(0),
          pll_locked(0)         => s_tx_pll_locked(0),
          pll_select(0)         => s_pll_select(0),
          tx_cal_busy(0)        => s_cal_busy(0),
          rx_analogreset(0)     => s_rst_ctl_rx_analogreset(0),
          rx_digitalreset(0)    => s_rst_ctl_rx_digitalreset(0),
          rx_ready(0)           => s_rst_ctl_rx_ready(0),
          rx_is_lockedtodata(0) => s_phy_rx_is_lockedtodata(0),
          rx_cal_busy(0)        => s_phy_rx_cal_busy(0)
        );

      atx_pll : if g_use_atx_pll generate
        inst_atx_pll : wr_arria10_pex10_atx_pll
          port map (
            pll_refclk0       => clk_ref_i,
            pll_powerdown     => s_rst_ctl_powerdown(0), -- Missing at Intel documentation -> Connection Guidelines for a CPRI PHY Design
            pll_locked        => s_tx_pll_locked(0),
            tx_serial_clk     => s_tx_pll_serial_clk,
            pll_cal_busy      => s_tx_pll_cal_busy,
            mcgb_rst          => s_rst_ctl_powerdown(0),
            tx_bonding_clocks => s_tx_bonding_clocks
          );
        end generate atx_pll;

      cmu_pll : if g_use_cmu_pll generate
        inst_cmu_pll : wr_arria10_pex10_cmu_pll
          port map (
            pll_refclk0   => clk_phy_i,
            pll_powerdown => s_rst_ctl_powerdown(0), -- Missing at Intel documentation -> Connection Guidelines for a CPRI PHY Design
            pll_locked    => s_tx_pll_locked(0),
            tx_serial_clk => s_tx_pll_serial_clk,
            pll_cal_busy  => s_tx_pll_cal_busy
          );
        end generate cmu_pll;
    end generate pex10_pll_and_reset;

    ftm10_pll_and_reset: if (g_family = "Arria 10 GX FTM10") generate
      inst_rst_ctl : wr_arria10_ftm10_rst_ctl
        port map (
          clock                 => clk_ref_i,
          reset                 => s_rst_ctl_rst,
          pll_powerdown(0)      => s_rst_ctl_powerdown(0), -- Missing at Intel documentation -> Connection Guidelines for a CPRI PHY Design
          tx_analogreset(0)     => s_rst_ctl_tx_analogreset(0),
          tx_digitalreset(0)    => s_rst_ctl_tx_digitalreset(0),
          tx_ready(0)           => s_rst_ctl_tx_ready(0),
          pll_locked(0)         => s_tx_pll_locked(0),
          pll_select(0)         => s_pll_select(0),
          tx_cal_busy(0)        => s_cal_busy(0),
          rx_analogreset(0)     => s_rst_ctl_rx_analogreset(0),
          rx_digitalreset(0)    => s_rst_ctl_rx_digitalreset(0),
          rx_ready(0)           => s_rst_ctl_rx_ready(0),
          rx_is_lockedtodata(0) => s_phy_rx_is_lockedtodata(0),
          rx_cal_busy(0)        => s_phy_rx_cal_busy(0)
        );

      atx_pll : if g_use_atx_pll generate
        inst_atx_pll : wr_arria10_ftm10_atx_pll
          port map (
            pll_refclk0       => clk_ref_i,
            pll_powerdown     => s_rst_ctl_powerdown(0), -- Missing at Intel documentation -> Connection Guidelines for a CPRI PHY Design
            pll_locked        => s_tx_pll_locked(0),
            tx_serial_clk     => s_tx_pll_serial_clk,
            pll_cal_busy      => s_tx_pll_cal_busy,
            mcgb_rst          => s_rst_ctl_powerdown(0),
            tx_bonding_clocks => s_tx_bonding_clocks
          );
        end generate atx_pll;

      cmu_pll : if g_use_cmu_pll generate
        inst_cmu_pll : wr_arria10_ftm10_cmu_pll
          port map (
            pll_refclk0   => clk_phy_i,
            pll_powerdown => s_rst_ctl_powerdown(0), -- Missing at Intel documentation -> Connection Guidelines for a CPRI PHY Design
            pll_locked    => s_tx_pll_locked(0),
            tx_serial_clk => s_tx_pll_serial_clk,
            pll_cal_busy  => s_tx_pll_cal_busy
          );
        end generate cmu_pll;
    end generate ftm10_pll_and_reset;

    e3p1_pll_and_reset: if (g_family = "Arria 10 GX E3P1") generate
    inst_rst_ctl : wr_arria10_e3p1_rst_ctl
      port map (
        clock                 => clk_ref_i,
        reset                 => s_rst_ctl_rst,
        pll_powerdown(0)      => s_rst_ctl_powerdown(0), -- Missing at Intel documentation -> Connection Guidelines for a CPRI PHY Design
        tx_analogreset(0)     => s_rst_ctl_tx_analogreset(0),
        tx_digitalreset(0)    => s_rst_ctl_tx_digitalreset(0),
        tx_ready(0)           => s_rst_ctl_tx_ready(0),
        pll_locked(0)         => s_tx_pll_locked(0),
        pll_select(0)         => s_pll_select(0),
        tx_cal_busy(0)        => s_cal_busy(0),
        rx_analogreset(0)     => s_rst_ctl_rx_analogreset(0),
        rx_digitalreset(0)    => s_rst_ctl_rx_digitalreset(0),
        rx_ready(0)           => s_rst_ctl_rx_ready(0),
        rx_is_lockedtodata(0) => s_phy_rx_is_lockedtodata(0),
        rx_cal_busy(0)        => s_phy_rx_cal_busy(0)
      );

  atx_pll : if g_use_atx_pll generate
    inst_atx_pll : wr_arria10_e3p1_atx_pll
      port map (
        pll_refclk0   => clk_phy_i,
        pll_powerdown => s_rst_ctl_powerdown(0), -- Missing at Intel documentation -> Connection Guidelines for a CPRI PHY Design
        pll_locked    => s_tx_pll_locked(0),
        tx_serial_clk => s_tx_pll_serial_clk,
        pll_cal_busy  => s_tx_pll_cal_busy
      );
    end generate atx_pll;

    cmu_pll : if g_use_cmu_pll generate
      inst_cmu_pll : wr_arria10_e3p1_cmu_pll
        port map (
          pll_refclk0   => clk_phy_i,
          pll_powerdown => s_rst_ctl_powerdown(0), -- Missing at Intel documentation -> Connection Guidelines for a CPRI PHY Design
          pll_locked    => s_tx_pll_locked(0),
          tx_serial_clk => s_tx_pll_serial_clk,
          pll_cal_busy  => s_tx_pll_cal_busy
        );
      end generate cmu_pll;
    end generate e3p1_pll_and_reset;

      s_cal_busy(0) <= s_phy_tx_cal_busy(0) or s_tx_pll_cal_busy;
  end generate det_phy;

  phy_rst_ext : if g_use_ext_rst generate
    s_ext_reset <= drop_link_i;
  end generate phy_rst_ext;

  phy_rst_int : if not g_use_ext_rst generate
    s_ext_reset <= '0';
  end generate phy_rst_int;

  phy_rst_los : if g_use_sfp_los_rst generate
    s_sfp_los_reset <= sfp_los_i;
  end generate phy_rst_los;

  phy_rst_ignore_los : if not g_use_sfp_los_rst generate
    s_sfp_los_reset <= '0';
  end generate phy_rst_ignore_los;

  phy_ext_loop_yes : if g_use_ext_loop generate
    s_loop_en <= loopen_i;
  end generate phy_ext_loop_yes;

  phy_ext_loop_no : if not g_use_ext_loop generate
    s_loop_en <= '0';
  end generate phy_ext_loop_no;

  s_rst_ctl_rst <= s_sfp_los_reset or s_ext_reset;

  s_pll_select <= (others => '0');

  -- Additional outputs
  tx_ready_o     <= s_rst_ctl_tx_ready(0);
  rx_ready_o     <= s_rst_ctl_rx_ready(0);
  s_phy_ready    <= s_rst_ctl_tx_ready(0) and s_rst_ctl_rx_ready(0); -- and s_patterndetect_ready;
  tx_disparity_o <= '0';
  tx_enc_err_o   <= '0';
  rx_enc_err_o   <= s_phy_rx_disperr(0) or s_phy_rx_errdetect(0);

  cmp_gc_sync_ffs_phy_ready : gc_sync_ffs
    port map (
      clk_i    => s_rx_clk,
      rst_n_i  => '1',
      data_i   => s_phy_ready,
      synced_o => s_ready_synced
    );

  ready_o <= s_ready_synced;
  debug_o <= s_patterndetect_ready or s_rx_runningdisp or s_rx_bs_dump;

end rtl;
