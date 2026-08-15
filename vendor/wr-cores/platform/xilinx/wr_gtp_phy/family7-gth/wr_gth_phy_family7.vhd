-------------------------------------------------------------------------------
-- Title      : Deterministic Xilinx GTX wrapper - kintex-7 top module
-- Project    : White Rabbit Switch
-------------------------------------------------------------------------------
-- File       : wr_gth_phy_family7.vhd
-- Author     : Peter Jansweijer, Muriel van der Spek, Tomasz Wlostowski
-- Company    : CERN BE-CO-HT
-- Created    : 2017-02-02
-- Last update: 2017-02-02
-- Platform   : FPGA-generic
-- Standard   : VHDL'93
-------------------------------------------------------------------------------
-- Description: Dual channel wrapper for Xilinx Virtex-7 GTH adapted for
-- deterministic delays at 1.25 Gbps.
-------------------------------------------------------------------------------
--
-- Copyright (c) 2010 CERN / Tomasz Wlostowski
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
-- Revisions  :
-- Date        Version  Author    Description
-- 2017-02-02  0.1      PeterJ    Initial release based on "wr_gtx_phy_kintex7.vhd"
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.gencores_pkg.all;

library unisim;
use unisim.vcomponents.all;

library work;
use work.disparity_gen_pkg.all;

entity wr_gth_phy_family7 is
  generic(
    -- set to non-zero value to speed up the simulation by reducing some delays
    g_simulation    : integer := 0);
  port (
    -- Dedicated reference 125 MHz clock for the GTX transceiver
    clk_gth_i       : in     std_logic;

    -- TX path, synchronous to tx_out_clk_o (62.5 MHz):
    tx_out_clk_o    : out    std_logic;
    tx_locked_o     : out    std_logic;

    -- data input (8 bits, not 8b10b-encoded)
    tx_data_i       : in     std_logic_vector(15 downto 0);
    
    -- 1 when tx_data_i contains a control code, 0 when it's a data byte
    tx_k_i          : in     std_logic_vector(1 downto 0);

    -- disparity of the currently transmitted 8b10b code (1 = plus, 0 = minus).
    -- Necessary for the PCS to generate proper frame termination sequences.
    -- Generated for the 2nd byte (LSB) of tx_data_i.
    tx_disparity_o  : out    std_logic;

    -- Encoding error indication (1 = error, 0 = no error)
    tx_enc_err_o    : out    std_logic;

    -- RX path, synchronous to rx_rbclk_o.

    -- RX recovered clock
    rx_rbclk_o      : out    std_logic;
    
    -- 8b10b-decoded data output. The data output must be kept invalid before
    -- the transceiver is locked on the incoming signal to prevent the EP from
    -- detecting a false carrier.
    rx_data_o       : out    std_logic_vector(15 downto 0);
    
    -- 1 when the byte on rx_data_o is a control code
    rx_k_o          : out    std_logic_vector(1 downto 0);

    -- encoding error indication
    rx_enc_err_o    : out    std_logic;

    -- RX bitslide indication, indicating the delay of the RX path of the
    -- transceiver (in UIs). Must be valid when ch0_rx_data_o is valid.
    rx_bitslide_o   : out    std_logic_vector(4 downto 0);

    -- reset input, active hi
    rst_i           : in     std_logic;
    
    -- GTH loopback and PRBS generator control signals
    loopen_i        : in     std_logic_vector(2 downto 0);
    tx_prbs_sel_i   : in     std_logic_vector(2 downto 0);

    -- High speed serial differential transmit and receive pins
    pad_txn_o       : out    std_logic;
    pad_txp_o       : out    std_logic;

    pad_rxn_i       : in     std_logic;
    pad_rxp_i       : in     std_logic;

    -- PHY ready 
    rdy_o           : out    std_logic);
end entity wr_gth_phy_family7;

architecture rtl of wr_gth_phy_family7 is

  component whiterabbit_gthe2_channel_wrapper_gt is
    generic (
      -- Simulation attributes
      GT_SIM_GTRESET_SPEEDUP    : string   := "TRUE"); -- Set to "true" to speed up sim reset
    port (
      RST_IN                                  : in   std_logic; -- Connect to System Reset
      --------------------------------- CPLL Ports -------------------------------
      CPLLFBCLKLOST_OUT                       : out  std_logic;
      CPLLLOCK_OUT                            : out  std_logic;
      CPLLLOCKDETCLK_IN                       : in   std_logic;
      CPLLREFCLKLOST_OUT                      : out  std_logic;
      CPLLRESET_IN                            : in   std_logic;
      -------------------------- Channel - Clocking Ports ------------------------
      GTREFCLK0_IN                            : in   std_logic;
      ---------------------------- Channel - DRP Ports  --------------------------
      DRPADDR_IN                              : in   std_logic_vector(8 downto 0);
      DRPCLK_IN                               : in   std_logic;
      DRPDI_IN                                : in   std_logic_vector(15 downto 0);
      DRPDO_OUT                               : out  std_logic_vector(15 downto 0);
      DRPEN_IN                                : in   std_logic;
      DRPRDY_OUT                              : out  std_logic;
      DRPWE_IN                                : in   std_logic;
      ------------------------------- Clocking Ports -----------------------------
      QPLLCLK_IN                              : in   std_logic;
      QPLLREFCLK_IN                           : in   std_logic;
      ------------------------------- Loopback Ports -----------------------------
      LOOPBACK_IN                             : in   std_logic_vector(2 downto 0);
      ------------------------------ Power-Down Ports ----------------------------
      RXPD_IN                                 : in   std_logic_vector(1 downto 0);
      TXPD_IN                                 : in   std_logic_vector(1 downto 0);
      --------------------- RX Initialization and Reset Ports --------------------
      RXUSERRDY_IN                            : in   std_logic;
      ------------------------- Receive Ports - CDR Ports ------------------------
      RXCDRLOCK_OUT                           : out  std_logic;
      RXCDRRESET_IN                           : in  std_logic;
      --------------- Receive Ports - Comma Detection and Alignment --------------
      RXSLIDE_IN                              : in   std_logic;
      ------------------ Receive Ports - FPGA RX Interface Ports -----------------
      RXUSRCLK_IN                             : in   std_logic;
      RXUSRCLK2_IN                            : in   std_logic;
      ------------------ Receive Ports - FPGA RX interface Ports -----------------
      RXDATA_OUT                              : out  std_logic_vector(15 downto 0);
      ------------------ Receive Ports - RX 8B/10B Decoder Ports -----------------
      RXDISPERR_OUT                           : out  std_logic_vector(1 downto 0);
      RXNOTINTABLE_OUT                        : out  std_logic_vector(1 downto 0);
      ------------------------ Receive Ports - RX AFE Ports ----------------------
      GTHRXP_IN                               : in   std_logic;
      GTHRXN_IN                               : in   std_logic;
      -------------- Receive Ports - RX Byte and Word Alignment Ports ------------
      RXBYTEISALIGNED_OUT                     : out  std_logic;
      RXCOMMADET_OUT                          : out  std_logic;
      --------------- Receive Ports - RX Fabric Output Control Ports -------------
      RXOUTCLK_OUT                            : out  std_logic;
      ------------- Receive Ports - RX Initialization and Reset Ports ------------
      GTRXRESET_IN                            : in   std_logic;
      RXPCSRESET_IN                           : in   std_logic;
      ------------------- Receive Ports - RX8B/10B Decoder Ports -----------------
      RXCHARISCOMMA_OUT                       : out  std_logic_vector(1 downto 0);
      RXCHARISK_OUT                           : out  std_logic_vector(1 downto 0);
      -------------- Receive Ports -RX Initialization and Reset Ports ------------
      RXRESETDONE_OUT                         : out  std_logic;
      --------------------- TX Initialization and Reset Ports --------------------
      GTTXRESET_IN                            : in   std_logic;
      TXUSERRDY_IN                            : in   std_logic;
      ---------------- Transmit Ports - 8b10b Encoder Control Ports --------------
      TXCHARDISPMODE_IN                       : in   std_logic_vector(1 downto 0);
      TXCHARDISPVAL_IN                        : in   std_logic_vector(1 downto 0);
      ------------------ Transmit Ports - FPGA TX Interface Ports ----------------
      TXUSRCLK_IN                             : in   std_logic;
      TXUSRCLK2_IN                            : in   std_logic;
      ------------------ Transmit Ports - TX Data Path interface -----------------
      TXDATA_IN                               : in   std_logic_vector(15 downto 0);
      ---------------- Transmit Ports - TX Driver and OOB signaling --------------
      GTHTXN_OUT                              : out  std_logic;
      GTHTXP_OUT                              : out  std_logic;
      ----------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
      TXOUTCLK_OUT                            : out  std_logic;
      ------------- Transmit Ports - TX Initialization and Reset Ports -----------
      TXPCSRESET_IN                           : in   std_logic;
      TXRESETDONE_OUT                         : out  std_logic;
      ------------------ Transmit Ports - pattern Generator Ports ----------------
      TXPRBSSEL_IN                            : in   std_logic_vector(2 downto 0);
      ----------- Transmit Transmit Ports - 8b10b Encoder Control Ports ----------
      TXCHARISK_IN                            : in   std_logic_vector(1 downto 0));
  end component;
    
  component gtp_bitslide is
    generic (
      g_simulation : integer;
      g_target     : string := "virtex7");
    port (
      gtp_rst_i                : in std_logic;
      gtp_rx_clk_i             : in std_logic;
      gtp_rx_comma_det_i       : in std_logic;
      gtp_rx_byte_is_aligned_i : in std_logic;
      serdes_ready_i           : in std_logic;
      gtp_rx_slide_o           : out std_logic;
      gtp_rx_cdr_rst_o         : out std_logic;
      bitslide_o               : out std_logic_vector(4 downto 0);
      synced_o                 : out std_logic);
  end component;

  signal rx_rec_clk_bufin         : std_logic;
  signal rx_rec_clk               : std_logic;
  signal tx_out_clk_bufin         : std_logic;
  signal tx_out_clk               : std_logic;

  signal tx_rst_done, rx_rst_done : std_logic;
  signal pll_lockdet              : std_logic;
  signal cpll_lockdet             : std_logic;
  signal gtreset                  : std_logic;

  signal rx_comma_det             : std_logic;
  signal rx_byte_is_aligned       : std_logic;
  signal rx_lost_lock             : std_logic;

  signal serdes_ready              : std_logic := '0';
  signal rx_slide                 : std_logic := '0';
  signal rx_cdr_rst               : std_logic;
  signal rx_synced                : std_logic;
  signal rst_done                 : std_logic;
  signal rst_done_n               : std_logic;

  signal rx_k_int                 : std_logic_vector(1 downto 0);
  signal rx_data_int              : std_logic_vector(15 downto 0) := (others => '0');

  signal rx_disp_err, rx_code_err : std_logic_vector(1 downto 0);

  signal tx_is_k_swapped          : std_logic_vector(1 downto 0) := (others => '0');
  signal tx_data_swapped          : std_logic_vector(15 downto 0);

  signal cur_disp                 : t_8b10b_disparity;

begin
  tx_enc_err_o <= '0';

  U_BUF_TxOutClk : BUFG
  port map (
    I => tx_out_clk_bufin,
    O => tx_out_clk);

  tx_out_clk_o <= tx_out_clk;
  tx_locked_o  <= cpll_lockdet;

  U_BUF_RxRecClk : BUFG
  port map (
    I => rx_rec_clk_bufin,
    O => rx_rec_clk);

  rx_rbclk_o <= rx_rec_clk;

  tx_is_k_swapped <= tx_k_i(0) & tx_k_i(1);
  tx_data_swapped <= tx_data_i(7 downto 0) & tx_data_i(15 downto 8);

  U_GTH_INST : whiterabbit_gthe2_channel_wrapper_gt
  generic map (
    -- Simulation attributes
    GT_SIM_GTRESET_SPEEDUP    =>  "TRUE")
  port map (
    --____________________________CHANNEL PORTS________________________________
    RST_IN                        => rst_i,
    --------------------------------- CPLL Ports -------------------------------
    CPLLFBCLKLOST_OUT             => open,
    CPLLLOCK_OUT                  => cpll_lockdet,
    CPLLLOCKDETCLK_IN             => '0',
    CPLLREFCLKLOST_OUT            => open,
    CPLLRESET_IN                  => rst_i,
    ---------------------- Channel - Clocking Ports ------------------------
    GTREFCLK0_IN                  => clk_gth_i,  --refclock from the CPLL
    ------------------------------- Clocking Ports -----------------------------
    QPLLCLK_IN                    => '0',
    QPLLREFCLK_IN                 => '0',
    ------------------------ Channel - DRP Ports  --------------------------
    DRPADDR_IN                    => "000000000",
    DRPCLK_IN                     => clk_gth_i,
    DRPDI_IN                      => "0000000000000000",
    DRPDO_OUT                     => open,
    DRPEN_IN                      => '0',
    DRPRDY_OUT                    => open,
    DRPWE_IN                      => '0',
    --------------------------- Loopback Ports -----------------------------
    LOOPBACK_IN                   => loopen_i,
    -------------------------- Power-Down Ports ----------------------------
    RXPD_IN                       => (others => '0'),
    TXPD_IN                       => (others => '0'),
    ----------------- RX Initialization and Reset Ports --------------------
    RXUSERRDY_IN                  => pll_lockdet,
    --------------------- Receive Ports - CDR Ports ------------------------
    RXCDRLOCK_OUT                 => open, 
    RXCDRRESET_IN                 => rx_cdr_rst,
    -------------- Receive Ports - FPGA RX Interface Ports -----------------
    RXDATA_OUT                    => rx_data_int,
    RXUSRCLK_IN                   => rx_rec_clk,
    RXUSRCLK2_IN                  => rx_rec_clk,
    -------------- Receive Ports - RX 8B/10B Decoder Ports -----------------
    RXCHARISCOMMA_OUT              => open,
    RXCHARISK_OUT                  => rx_k_int, 
    RXDISPERR_OUT                  => rx_disp_err,
    RXNOTINTABLE_OUT               => rx_code_err,
    -------------------- Receive Ports - RX AFE Ports ----------------------
    GTHRXN_IN                      => pad_rxn_i,
    GTHRXP_IN                      => pad_rxp_i,
    ---------- Receive Ports - RX Byte and Word Alignment Ports ------------
    RXBYTEISALIGNED_OUT            => rx_byte_is_aligned,
    RXCOMMADET_OUT                 => rx_comma_det,
    RXSLIDE_IN                     => rx_slide,
    ----------- Receive Ports - RX Fabric Output Control Ports -------------
    RXOUTCLK_OUT                   => rx_rec_clk_bufin,
    --------- Receive Ports - RX Initialization and Reset Ports ------------
    GTRXRESET_IN                   => gtreset, 
    RXPCSRESET_IN                  => '0',
    ---------- Receive Ports -RX Initialization and Reset Ports ------------
    RXRESETDONE_OUT                => rx_rst_done,
    ----------------- TX Initialization and Reset Ports --------------------
    GTTXRESET_IN                   => gtreset,
    TXUSERRDY_IN                   => pll_lockdet,
    ------------ Transmit Ports - 8b10b Encoder Control Ports --------------
    TXCHARDISPMODE_IN              => (others => '0'),
    TXCHARDISPVAL_IN               => (others => '0'),
    -------------- Transmit Ports - FPGA TX Interface Ports ----------------
    TXDATA_IN                      => tx_data_swapped,
    TXUSRCLK_IN                    => tx_out_clk,
    TXUSRCLK2_IN                   => tx_out_clk, 
    -------------- Transmit Ports - TX 8B/10B Encoder Ports ----------------
    TXCHARISK_IN                   => tx_is_k_swapped,
    ----------- Transmit Ports - TX Configurable Driver Ports --------------
    GTHTXN_OUT                     => pad_txn_o,
    GTHTXP_OUT                     => pad_txp_o,
    ------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
    TXOUTCLK_OUT                   => tx_out_clk_bufin,
    --------- Transmit Ports - TX Initialization and Reset Ports -----------
    TXPCSRESET_IN                  => '0',
    TXRESETDONE_OUT                => tx_rst_done,
    -------------- Transmit Ports - pattern Generator Ports ----------------
    TXPRBSSEL_IN                   => tx_prbs_sel_i);

  -- This component will count the times rx_slide_o is high. Rx_bitslide_o represents
  -- the number of bits that has to be shiftet for synchronisation.
  gtp_bitslide_i : gtp_bitslide
    generic map (
      g_simulation => g_simulation,
      g_target     => "virtex7")
    port map (
      gtp_rst_i                =>  rst_done_n,
      gtp_rx_clk_i             =>  rx_rec_clk,
      gtp_rx_comma_det_i       =>  rx_comma_det,
      gtp_rx_byte_is_aligned_i =>  rx_byte_is_aligned,
      serdes_ready_i           =>  serdes_ready,
      gtp_rx_slide_o           =>  rx_slide,
      gtp_rx_cdr_rst_o         =>  rx_cdr_rst,
      bitslide_o               =>  rx_bitslide_o,
      synced_o                 =>  rx_synced);
    
  pll_lockdet    <= cpll_lockdet and not rx_lost_lock;
  gtreset       <= not cpll_lockdet;
  rst_done      <= rx_rst_done and tx_rst_done;
  rst_done_n    <= not rst_done;   
  serdes_ready  <= rst_done and pll_lockdet;
  rdy_o         <= serdes_ready;

  -- The signal RXCDRLOCK_OUT can't be used to clarify if the PLL is in
  -- lock, because the CDR isn't a reliable source. It loses its when data  
  -- is offered to the receiver. Note that the status of RXCDRLOCK is marked
  -- "reserved" in 7 Series FPGAs GTX/GTH Transceivers User Guide (ug476) table 4-15.
  -- Work-Around: use RXNOTINTABLE_OUT which is connected to "rx_code_err"
  -- This signal is high on the bite on rx_data thats can't be used for 8B/10B encoding.
  p_detect_cdr_lock : process(rx_rec_clk, rst_i) is
  begin
    if rst_i = '1' then
      rx_lost_lock <= '1';
    elsif rising_edge(rx_rec_clk) then
      if rx_synced = '1' then
        if rx_code_err > "00" then
          rx_lost_lock <= '1';
        else
          rx_lost_lock <= '0';
        end if;
      else
        rx_lost_lock <= '0';
      end if;
    end if;
  end process;  
 
  p_gen_rx_outputs : process(rx_rec_clk, rst_done_n)
  begin
    if(rst_done_n = '1') then -- reset is not finished
      rx_data_o    <= (others => '0');
      rx_k_o       <= (others => '0');
      rx_enc_err_o <= '0';
    elsif rising_edge(rx_rec_clk) then 
      if serdes_ready = '1' and rx_synced = '1' then
        rx_data_o    <= rx_data_int(7 downto 0) & rx_data_int(15 downto 8);
        rx_k_o       <= rx_k_int(0) & rx_k_int(1);
        rx_enc_err_o <= rx_disp_err(0) or rx_disp_err(1) or rx_code_err(0) or rx_code_err(1);
      else
        rx_data_o    <= (others => '1');
        rx_k_o       <= (others => '1');
        rx_enc_err_o <= '1';
      end if;
    end if;
  end process; 

  p_gen_tx_disparity : process(tx_out_clk, rst_done_n)
  begin
    if rising_edge(tx_out_clk) then
      if rst_done_n = '1' then
        cur_disp <= RD_MINUS;
      else
        cur_disp <= f_next_8b10b_disparity16(cur_disp, tx_k_i, tx_data_i);
      end if;
    end if;
  end process;

  tx_disparity_o     <= to_std_logic(cur_disp);
end architecture rtl ; -- of wr_gth_phy_family7

