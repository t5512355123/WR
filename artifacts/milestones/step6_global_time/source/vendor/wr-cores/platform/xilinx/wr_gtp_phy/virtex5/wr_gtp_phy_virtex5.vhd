-------------------------------------------------------------------------------
-- Title      : Deterministic Xilinx GTP wrapper - Virtex-5 top module
-- Project    : White Rabbit Switch
-------------------------------------------------------------------------------
-- File       : wr_gtp_phy_virtex5.vhd
-- Author     : Tomasz Wlostowski
-- Company    : CERN BE-CO-HT
-- Created    : 2010-11-18
-- Last update: 2020-12-07
-- Platform   : FPGA-generic
-- Standard   : VHDL'93
-------------------------------------------------------------------------------
-- Description: Dual channel wrapper for Xilinx Virtex-5 GTP adapted for
-- deterministic delays at 1.25 Gbps.
-------------------------------------------------------------------------------
--
-- Copyright (c) 2010-2015 CERN 
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
-- 2010-11-18  0.4      twlostow  Initial release
-- 2011-02-07  0.5      twlostow  Verified on Spartan6 GTP (single channel only)
-- 2011-05-15  0.6      twlostow  Added reference clock output
-- 2015-03-17  1.0       jsimonin  Ported to Virtex5 GTP
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.all;

library work;
use work.gencores_pkg.all;
use work.disparity_gen_pkg.all;

entity wr_gtp_phy_virtex5 is

  generic (
    -- set to non-zero value to speed up the simulation by reducing some delays
    g_simulation      : integer := 0;
    g_force_disparity : integer := 0;
    g_enable_ch0      : integer := 1;
    g_enable_ch1      : integer := 1
    );

  port (
-- Clobal
    -- dedicated GTP clock input
    gtp_clk_i : in std_logic;

    -- CLOCK MUST BE PRESENT AT RESET TIME!
    -- TX path, synchronous to ch01_ref_clk_i
    ch01_ref_clk_i : in std_logic := '0';

    -- reset input, active hi
    ch01_ref_clk_rst_i : in std_logic := '0';

-- Port 0
    -- TX path, synchronous to ch0_ref_clk_i
    -- ch0_ref_clk_i : in std_logic := '0';

    -- data input (8 bits, not 8b10b-encoded)
    ch0_tx_data_i : in std_logic_vector(7 downto 0) := "00000000";

    -- 1 when tx_data_i contains a control code, 0 when it's a data byte
    ch0_tx_k_i : in std_logic := '0';

    -- disparity of the currently transmitted 8b10b code (1 = plus, 0 = minus).
    -- Necessary for the PCS to generate proper frame termination sequences.
    ch0_tx_disparity_o : out std_logic;

    -- Encoding error indication (1 = error, 0 = no error)
    ch0_tx_enc_err_o : out std_logic;

    -- RX path, synchronous to ch0_rx_rbclk_o.

    -- RX recovered clock
    ch0_rx_rbclk_o : out std_logic;

    -- 8b10b-decoded data output. The data output must be kept invalid before
    -- the transceiver is locked on the incoming signal to prevent the EP from
    -- detecting a false carrier.
    ch0_rx_data_o : out std_logic_vector(7 downto 0);

    -- 1 when the byte on rx_data_o is a control code
    ch0_rx_k_o : out std_logic;

    -- encoding error indication
    ch0_rx_enc_err_o : out std_logic;

    -- RX bitslide indication, indicating the delay of the RX path of the
    -- transceiver (in UIs). Must be valid when ch0_rx_data_o is valid.
    ch0_rx_bitslide_o : out std_logic_vector(3 downto 0);

    -- local loopback enable (Tx->Rx), active hi
    ch0_loopen_i : in std_logic := '0';

    -- ready signal
    ch0_rdy_o : out std_logic;

-- Port 1
    -- ch1_ref_clk_i : in std_logic;

    ch1_tx_data_i      : in  std_logic_vector(7 downto 0) := "00000000";
    ch1_tx_k_i         : in  std_logic                    := '0';
    ch1_tx_disparity_o : out std_logic;
    ch1_tx_enc_err_o   : out std_logic;

    ch1_rx_data_o     : out std_logic_vector(7 downto 0);
    ch1_rx_rbclk_o    : out std_logic;
    ch1_rx_k_o        : out std_logic;
    ch1_rx_enc_err_o  : out std_logic;
    ch1_rx_bitslide_o : out std_logic_vector(3 downto 0);

    ch1_loopen_i : in std_logic := '0';
    ch1_rdy_o    : out std_logic;

-- Serial I/O

    pad_txn0_o : out std_logic;
    pad_txp0_o : out std_logic;

    pad_rxn0_i : in std_logic := '0';
    pad_rxp0_i : in std_logic := '0';

    pad_txn1_o : out std_logic;
    pad_txp1_o : out std_logic;

    pad_rxn1_i : in std_logic := '0';
    pad_rxp1_i : in std_logic := '0';

-- Debug added by J.Simonin
    ch1_align_done_o : out std_logic;
    ch1_rx_synced_o  : out std_logic
    );


end wr_gtp_phy_virtex5;



architecture rtl of wr_gtp_phy_virtex5 is

  function To_Std_Logic(L : boolean) return std_logic is
  begin
    if L then
      return('1');
    else
      return('0');
    end if;
  end function To_Std_Logic;


  component WHITERABBITGTP_WRAPPER_TILE_VIRTEX5
    generic (
      TILE_SIM_MODE             : string;
      TILE_SIM_GTPRESET_SPEEDUP : integer;
      TILE_SIM_PLL_PERDIV2      : bit_vector;
      TILE_CHAN_BOND_MODE_0     : string;
      TILE_CHAN_BOND_LEVEL_0    : integer;
      TILE_CHAN_BOND_MODE_1     : string;
      TILE_CHAN_BOND_LEVEL_1    : integer);
    port (
      LOOPBACK0_IN         : in  std_logic_vector(2 downto 0);
      LOOPBACK1_IN         : in  std_logic_vector(2 downto 0);
      RXCHARISK0_OUT       : out std_logic;
      RXCHARISK1_OUT       : out std_logic;
      RXDISPERR0_OUT       : out std_logic;
      RXDISPERR1_OUT       : out std_logic;
      RXNOTINTABLE0_OUT    : out std_logic;
      RXNOTINTABLE1_OUT    : out std_logic;
      RXBYTEISALIGNED0_OUT : out std_logic;
      RXBYTEISALIGNED1_OUT : out std_logic;
      RXCOMMADET0_OUT      : out std_logic;
      RXCOMMADET1_OUT      : out std_logic;
      RXSLIDE0_IN          : in  std_logic;
      RXSLIDE1_IN          : in  std_logic;
      RXDATA0_OUT          : out std_logic_vector(7 downto 0);
      RXDATA1_OUT          : out std_logic_vector(7 downto 0);
      RXRECCLK0_OUT        : out std_logic;
      RXRECCLK1_OUT        : out std_logic;
      RXUSRCLK0_IN         : in  std_logic;
      RXUSRCLK1_IN         : in  std_logic;
      RXUSRCLK20_IN        : in  std_logic;
      RXUSRCLK21_IN        : in  std_logic;
      RXCDRRESET0_IN       : in  std_logic;
      RXCDRRESET1_IN       : in  std_logic;
      RXN0_IN              : in  std_logic;
      RXN1_IN              : in  std_logic;
      RXP0_IN              : in  std_logic;
      RXP1_IN              : in  std_logic;
      RXLOSSOFSYNC0_OUT    : out std_logic_vector(1 downto 0);
      RXLOSSOFSYNC1_OUT    : out std_logic_vector(1 downto 0);
      CLKIN_IN             : in  std_logic;
      GTPRESET_IN          : in  std_logic;
      PLLLKDET_OUT         : out std_logic;
      REFCLKOUT_OUT        : out std_logic;
      RESETDONE0_OUT       : out std_logic;
      RESETDONE1_OUT       : out std_logic;
      TXENPMAPHASEALIGN_IN : in  std_logic;
      TXPMASETPHASE_IN     : in  std_logic;
      TXCHARDISPVAL0_IN    : in  std_logic;
      TXCHARDISPVAL1_IN    : in  std_logic;
      TXCHARISK0_IN        : in  std_logic;
      TXCHARISK1_IN        : in  std_logic;
      TXDATA0_IN           : in  std_logic_vector(7 downto 0);
      TXDATA1_IN           : in  std_logic_vector(7 downto 0);
      TXUSRCLK0_IN         : in  std_logic;
      TXUSRCLK1_IN         : in  std_logic;
      TXUSRCLK20_IN        : in  std_logic;
      TXUSRCLK21_IN        : in  std_logic;
      TXN0_OUT             : out std_logic;
      TXN1_OUT             : out std_logic;
      TXP0_OUT             : out std_logic;
      TXP1_OUT             : out std_logic);
  end component;

  component BUFG
    port (
      O : out std_ulogic;
      I : in  std_ulogic);
  end component;

  component gtp_phase_align
    generic(
      g_simulation : integer);
    port (
      gtp_rst_i                   : in  std_logic;
      gtp_tx_clk_i                : in  std_logic;
      gtp_tx_en_pma_phase_align_o : out std_logic;
      gtp_tx_pma_set_phase_o      : out std_logic;
      align_en_i                  : in  std_logic;
      align_done_o                : out std_logic);
  end component;

  component v5_gtp_align_detect is
    port (
      clk_rx_i  : in  std_logic;
      rst_i     : in  std_logic;
      data_i    : in  std_logic_vector(7 downto 0);
      k_i       : in  std_logic;
      aligned_o : out std_logic);
  end component v5_gtp_align_detect;

  component gtp_bitslide
    generic(
      g_simulation : integer;
      g_target     : string := "virtex5");
    port (
      gtp_rst_i                : in  std_logic;
      gtp_rx_clk_i             : in  std_logic;
      gtp_rx_comma_det_i       : in  std_logic;
      gtp_rx_byte_is_aligned_i : in  std_logic;
      serdes_ready_i           : in  std_logic;
      gtp_rx_slide_o           : out std_logic;
      gtp_rx_cdr_rst_o         : out std_logic;
      bitslide_o               : out std_logic_vector(4 downto 0);
      synced_o                 : out std_logic);
  end component;

  signal ch0_gtp_reset      : std_logic;
  signal ch0_gtp_loopback   : std_logic_vector(2 downto 0) := "000";
  signal ch0_gtp_reset_done : std_logic;

  signal ch0_rx_data_raw_int                : std_logic_vector(9 downto 0);
  signal ch0_rx_data_raw_int_pre                : std_logic_vector(9 downto 0);
  signal ch1_rx_data_raw_int                : std_logic_vector(9 downto 0);
  signal ch1_rx_data_raw_int_pre                : std_logic_vector(9 downto 0);
  signal ch0_rx_data_int                : std_logic_vector(7 downto 0);

  signal ch0_rx_k_int                   : std_logic;
  signal ch0_rx_disperr, ch0_rx_invcode : std_logic;

  signal ch0_rx_byte_is_aligned : std_logic;
  signal ch0_rx_comma_det       : std_logic;
  signal ch0_rx_cdr_rst         : std_logic := '0';
  signal ch0_rx_rec_clk_pad     : std_logic;
  signal ch0_rx_rec_clk         : std_logic;
  signal ch0_rx_divclk          : std_logic;
  signal ch0_rx_slide           : std_logic := '0';

  signal ch0_rx_synced : std_logic;

  signal ch0_rx_enable_output, ch0_rx_enable_output_synced : std_logic;


  signal ch1_gtp_loopback   : std_logic_vector(2 downto 0) := "000";
  signal ch1_gtp_reset_done : std_logic;

  signal ch1_rx_data_int                : std_logic_vector(7 downto 0);
  signal ch1_rx_k_int                   : std_logic;
  signal ch1_rx_disperr, ch1_rx_invcode : std_logic;

  signal ch1_rx_byte_is_aligned : std_logic;
  signal ch1_rx_comma_det       : std_logic;
  signal ch1_rx_cdr_rst         : std_logic := '0';
  signal ch1_rx_rec_clk_pad     : std_logic;
  signal ch1_rx_rec_clk         : std_logic;
  signal ch1_rx_divclk          : std_logic;
  signal ch1_rx_slide           : std_logic := '0';

  signal ch1_rx_synced : std_logic;

  signal ch1_rx_enable_output, ch1_rx_enable_output_synced : std_logic;

  signal ch01_rst_synced    : std_logic;
  signal ch01_reset_counter : unsigned(9 downto 0);
  signal ch01_rst_d0 : std_logic;

  signal ch0_rx_bitslide_int : std_logic_vector(4 downto 0);
  signal ch1_rx_bitslide_int : std_logic_vector(4 downto 0);


  signal ch0_disparity_set : std_logic;
  signal ch1_disparity_set : std_logic;

  signal ch0_tx_chardispmode : std_logic;
  signal ch1_tx_chardispmode : std_logic;

  signal ch0_tx_chardispval : std_logic;
  signal ch1_tx_chardispval : std_logic;

  signal ch01_gtp_locked            : std_logic;
  signal ch0_gtp_locked_rxclk            : std_logic;
  signal ch1_gtp_locked_rxclk            : std_logic;
  signal ch01_align_done            : std_logic;
  signal ch01_gtp_clkout_int        : std_logic;
  signal ch01_tx_pma_set_phase      : std_logic := '0';
  signal ch01_tx_en_pma_phase_align : std_logic := '0';
  signal ch01_gtp_reset             : std_logic;
  signal ch01_gtp_pll_lockdet       : std_logic;
  signal ch01_ref_clk_in            : std_logic;

  signal ch0_cur_disp  : t_8b10b_disparity;
  signal ch0_disp_pipe : std_logic_vector(1 downto 0);
  signal ch1_cur_disp  : t_8b10b_disparity;
  signal ch1_disp_pipe : std_logic_vector(1 downto 0);

  signal ch0_gtp_reset_rxclk_n : std_logic;
  signal ch1_gtp_reset_rxclk_n : std_logic;
  signal ch0_gtp_reset_rxclk : std_logic;
  signal ch1_gtp_reset_rxclk : std_logic;
begin  -- rtl
  -------------------------------------------------------------------------------
  -- Channel 0 logic
  -------------------------------------------------------------------------------

  gc_reset_1: entity work.gc_reset
    generic map (
      g_clocks    => 1)
    port map (
      free_clk_i => ch01_ref_clk_i,
      locked_i   => ch0_gtp_reset_done,
      clks_i(0) => ch0_rx_rec_clk,
      rstn_o(0)     => ch0_gtp_reset_rxclk_n);

  ch0_gtp_reset_rxclk <= not ch0_gtp_reset_rxclk_n;

  gc_reset_2: entity work.gc_reset
    generic map (
      g_clocks    => 1)
    port map (
      free_clk_i => ch01_ref_clk_i,
      locked_i   => ch1_gtp_reset_done,
      clks_i(0) => ch1_rx_rec_clk,
      rstn_o(0)     => ch1_gtp_reset_rxclk_n);

  ch1_gtp_reset_rxclk <= not ch1_gtp_reset_rxclk_n;

  ch01_gtp_reset <= ch01_rst_synced or std_logic(not ch01_reset_counter(ch01_reset_counter'left));

  p_gen_reset : process(ch01_ref_clk_i)
  begin
    if rising_edge(ch01_ref_clk_i) then

      ch01_rst_d0     <= ch01_ref_clk_rst_i;
      ch01_rst_synced <= ch01_rst_d0;

      if(ch01_rst_synced = '1') then
        ch01_reset_counter <= (others => '0');
      else
        if(ch01_reset_counter(ch01_reset_counter'left) = '0') then
          ch01_reset_counter <= ch01_reset_counter + 1;
        end if;
      end if;
    end if;
  end process;


  
  gen_with_channel0 : if(g_enable_ch0 /= 0) generate
    ch0_tx_disparity_o <= ch0_disp_pipe(0);

    
    gen_disp_ch0 : process(ch01_ref_clk_i)
    begin
      if rising_edge(ch01_ref_clk_i) then
        if(ch0_tx_chardispmode = '1' or ch01_gtp_reset = '1') then
          if(g_force_disparity = 0) then
            ch0_cur_disp <= RD_MINUS;
          else
            ch0_cur_disp <= RD_PLUS;
          end if;
          ch0_disp_pipe <= (others => '0');
        else
          ch0_cur_disp     <= f_next_8b10b_disparity8(ch0_cur_disp, ch0_tx_k_i, ch0_tx_data_i);
          ch0_disp_pipe(0) <= to_std_logic(ch0_cur_disp);
          ch0_disp_pipe(1) <= ch0_disp_pipe(0);
        end if;
      end if;
    end process;

    U_Rbclk_bufg_ch0 : BUFG
      port map (
        I => ch0_rx_rec_clk_pad,        
        O => ch0_rx_rec_clk
        );

    ch0_tx_enc_err_o <= '0';

    ch0_rx_data_raw_int(0) <= ch0_rx_data_raw_int_pre(9);
    ch0_rx_data_raw_int(1) <= ch0_rx_data_raw_int_pre(8);
    ch0_rx_data_raw_int(2) <= ch0_rx_data_raw_int_pre(7);
    ch0_rx_data_raw_int(3) <= ch0_rx_data_raw_int_pre(6);
    ch0_rx_data_raw_int(4) <= ch0_rx_data_raw_int_pre(5);
    ch0_rx_data_raw_int(5) <= ch0_rx_data_raw_int_pre(4);
    ch0_rx_data_raw_int(6) <= ch0_rx_data_raw_int_pre(3);
    ch0_rx_data_raw_int(7) <= ch0_rx_data_raw_int_pre(2);
    ch0_rx_data_raw_int(8) <= ch0_rx_data_raw_int_pre(1);
    ch0_rx_data_raw_int(9) <= ch0_rx_data_raw_int_pre(0);

  
    gc_dec_8b10b_1: entity work.gc_dec_8b10b
      port map (
        clk_i       => ch0_rx_rec_clk,
        rst_n_i     => ch0_gtp_reset_rxclk_n,
        in_10b_i    => ch0_rx_data_raw_int_pre,
        ctrl_o      => ch0_rx_k_int,
        code_err_o  => ch0_rx_invcode,
        rdisp_err_o => open,
        out_8b_o    => ch0_rx_data_int);


    ch0_rx_disperr <= '0';

    v5_gtp_comma_detect_1: entity work.v5_gtp_comma_detect
      port map (
        clk_rx_i      => ch0_rx_rec_clk,
        rst_n_i         => ch0_gtp_reset_rxclk_n,
        rx_data_raw_i => ch0_rx_data_raw_int,
        rx_is_comma_o => ch0_rx_comma_det,
        aligned_o     => ch0_rx_byte_is_aligned);


  U_sync_3 : gc_sync_ffs
      generic map (
        g_sync_edge => "positive")
      port map (
        clk_i    => ch0_rx_rec_clk,
        rst_n_i  => '1',
        data_i   => ch01_gtp_locked,
        synced_o => ch0_gtp_locked_rxclk,
        npulse_o => open,
        ppulse_o => open);

    
    U_bitslide_ch0 : gtp_bitslide
      generic map (
        g_simulation => g_simulation)
      port map (
        gtp_rst_i                => ch0_gtp_reset_rxclk,
        gtp_rx_clk_i             => ch0_rx_rec_clk,
        gtp_rx_comma_det_i       => ch0_rx_comma_det,
        gtp_rx_byte_is_aligned_i => ch0_rx_byte_is_aligned,
        serdes_ready_i           => ch0_gtp_locked_rxclk,
        gtp_rx_slide_o           => ch0_rx_slide,
        gtp_rx_cdr_rst_o         => ch0_rx_cdr_rst,
        bitslide_o               => ch0_rx_bitslide_int,
        synced_o                 => ch0_rx_synced);

    ch0_rx_bitslide_o    <= ch0_rx_bitslide_int(3 downto 0);
    ch0_rx_enable_output <= ch0_rx_synced and ch01_align_done;

    U_sync_oen_ch0 : gc_sync_ffs
      generic map (
        g_sync_edge => "positive")
      port map (
        clk_i    => ch0_rx_rec_clk,
        rst_n_i  => '1',
        data_i   => ch0_rx_enable_output,
        synced_o => ch0_rx_enable_output_synced,
        npulse_o => open,
        ppulse_o => open);

    p_force_proper_disparity_ch0 : process(ch01_ref_clk_i, ch01_gtp_reset)
    begin
      if (ch01_gtp_reset = '1') then
        ch0_disparity_set   <= '0';
        ch0_tx_chardispval  <= '0';
        ch0_tx_chardispmode <= '0';
      elsif rising_edge(ch01_ref_clk_i) then
        if(ch0_disparity_set = '0' and ch0_tx_k_i = '1' and ch0_tx_data_i = x"bc" and ch01_align_done = '1') then
          ch0_disparity_set <= '1';
          if(g_force_disparity = 0) then
            ch0_tx_chardispval <= '0';
          else
            ch0_tx_chardispval <= '1';
          end if;
          ch0_tx_chardispmode <= '1';
        else
          ch0_tx_chardispmode <= '0';
          ch0_tx_chardispval  <= '0';
        end if;
      end if;
    end process;

    p_gen_output_ch0 : process(ch0_rx_rec_clk, ch0_gtp_reset_rxclk)
    begin
      if(ch0_gtp_reset_rxclk = '1') then
        ch0_rx_data_o    <= (others => '0');
        ch0_rx_k_o       <= '0';
        ch0_rx_enc_err_o <= '0';
        
      elsif rising_edge(ch0_rx_rec_clk) then
        if(ch0_rx_enable_output_synced = '0') then
-- make sure the output data is invalid when the link is down and that it will
-- trigger the sync loss detection
          ch0_rx_data_o    <= (others => '0');
          ch0_rx_k_o       <= '1';
          ch0_rx_enc_err_o <= '1';
        else
          ch0_rx_data_o    <= ch0_rx_data_int after 1ns;
          ch0_rx_k_o       <= ch0_rx_k_int after 1ns;
          ch0_rx_enc_err_o <= (ch0_rx_disperr or ch0_rx_invcode) after 1ns;
        end if;
      end if;
    end process;


-- drive the recovered clock output
    ch0_rx_rbclk_o <= ch0_rx_rec_clk;

  end generate gen_with_channel0;

  ch0_gtp_loopback <= "000";

  -------------------------------------------------------------------------------
  -- Channel 1 logic
  -------------------------------------------------------------------------------

  gen_with_channel1 : if(g_enable_ch1 /= 0) generate

    ch1_tx_disparity_o <= ch1_disp_pipe(1);


    gen_disp_ch1 : process(ch01_ref_clk_i)
    begin
      if rising_edge(ch01_ref_clk_i) then
        if(ch1_tx_chardispmode = '1' or ch01_gtp_reset = '1') then
          if(g_force_disparity = 0) then
            ch1_cur_disp <= RD_MINUS;
          else
            ch1_cur_disp <= RD_PLUS;
          end if;
          ch1_disp_pipe <= (others => '0');
        else
          ch1_cur_disp     <= f_next_8b10b_disparity8(ch1_cur_disp, ch1_tx_k_i, ch1_tx_data_i);
          ch1_disp_pipe(0) <= to_std_logic(ch1_cur_disp);
          ch1_disp_pipe(1) <= ch1_disp_pipe(0);
        end if;
      end if;
    end process;

    U_Rbclk_bufg_ch1 : BUFG
      port map (
        I => ch1_rx_rec_clk_pad,        -- replaces "ch1_rx_divclk",
        O => ch1_rx_rec_clk
        );

    -- U_Align_Detect_CH1: v5_gtp_align_detect
    --   port map (
    --     clk_rx_i  => ch1_rx_rec_clk,
    --     rst_i   => ch01_gtp_reset,
    --     data_i    => ch1_rx_data_int,
    --     k_i       => ch1_rx_k_int,
    --     aligned_o => ch1_rx_byte_is_aligned);

    ch1_rx_data_raw_int(0) <= ch1_rx_data_raw_int_pre(9);
    ch1_rx_data_raw_int(1) <= ch1_rx_data_raw_int_pre(8);
    ch1_rx_data_raw_int(2) <= ch1_rx_data_raw_int_pre(7);
    ch1_rx_data_raw_int(3) <= ch1_rx_data_raw_int_pre(6);
    ch1_rx_data_raw_int(4) <= ch1_rx_data_raw_int_pre(5);
    ch1_rx_data_raw_int(5) <= ch1_rx_data_raw_int_pre(4);
    ch1_rx_data_raw_int(6) <= ch1_rx_data_raw_int_pre(3);
    ch1_rx_data_raw_int(7) <= ch1_rx_data_raw_int_pre(2);
    ch1_rx_data_raw_int(8) <= ch1_rx_data_raw_int_pre(1);
    ch1_rx_data_raw_int(9) <= ch1_rx_data_raw_int_pre(0);

    
    gc_dec_8b10b_2: entity work.gc_dec_8b10b
      port map (
        clk_i       => ch1_rx_rec_clk,
        rst_n_i     => ch1_gtp_reset_rxclk_n,
        in_10b_i    => ch1_rx_data_raw_int_pre,
        ctrl_o      => ch1_rx_k_int,
        code_err_o  => ch1_rx_invcode,
        rdisp_err_o => open,
        out_8b_o    => ch1_rx_data_int);


    ch1_rx_disperr <= '0';

    v5_gtp_comma_detect_2: entity work.v5_gtp_comma_detect
      port map (
        clk_rx_i      => ch1_rx_rec_clk,
        rst_n_i         => ch1_gtp_reset_rxclk_n,
        rx_data_raw_i => ch1_rx_data_raw_int,
        rx_is_comma_o => ch1_rx_comma_det,
        aligned_o     => ch1_rx_byte_is_aligned);
    
    ch1_tx_enc_err_o <= '0';

      U_sync_4 : gc_sync_ffs
      generic map (
        g_sync_edge => "positive")
      port map (
        clk_i    => ch1_rx_rec_clk,
        rst_n_i  => '1',
        data_i   => ch01_gtp_locked,
        synced_o => ch1_gtp_locked_rxclk,
        npulse_o => open,
        ppulse_o => open);


    U_bitslide_ch1 : gtp_bitslide
      generic map (
        g_simulation => g_simulation)
      port map (
        gtp_rst_i                => ch1_gtp_reset_rxclk,
        gtp_rx_clk_i             => ch1_rx_rec_clk,
        gtp_rx_comma_det_i       => ch1_rx_comma_det,
        gtp_rx_byte_is_aligned_i => ch1_rx_byte_is_aligned,
        serdes_ready_i           => ch1_gtp_locked_rxclk,
        gtp_rx_slide_o           => ch1_rx_slide,
        gtp_rx_cdr_rst_o         => ch1_rx_cdr_rst,
        bitslide_o               => ch1_rx_bitslide_int,
        synced_o                 => ch1_rx_synced);

    ch1_rx_bitslide_o    <= ch1_rx_bitslide_int(3 downto 0);
    ch1_rx_enable_output <= ch1_rx_synced and ch01_align_done;

    U_sync_oen_ch1 : gc_sync_ffs
      generic map (
        g_sync_edge => "positive")
      port map (
        clk_i    => ch1_rx_rec_clk,
        rst_n_i  => '1',
        data_i   => ch1_rx_enable_output,
        synced_o => ch1_rx_enable_output_synced,
        npulse_o => open,
        ppulse_o => open);

    p_force_proper_disparity_ch1 : process(ch01_ref_clk_i, ch01_gtp_reset)
    begin
      if (ch01_gtp_reset = '1') then
        ch1_disparity_set   <= '0';
        ch1_tx_chardispval  <= '0';
        ch1_tx_chardispmode <= '0';
        
      elsif rising_edge(ch01_ref_clk_i) then
        if(ch1_disparity_set = '0' and ch1_tx_k_i = '1' and ch1_tx_data_i = x"bc" and ch01_align_done = '1') then
          ch1_disparity_set <= '1';
          if(g_force_disparity = 0) then
            ch1_tx_chardispval <= '0';
          else
            ch1_tx_chardispval <= '1';
          end if;
          ch1_tx_chardispmode <= '1';
        else
          ch1_tx_chardispmode <= '0';
          ch1_tx_chardispval  <= '0';
        end if;
      end if;
    end process;

    p_gen_output_ch1 : process(ch1_rx_rec_clk, ch1_gtp_reset_rxclk)
    begin
      if(ch1_gtp_reset_rxclk = '1') then
        ch1_rx_data_o    <= (others => '0');
        ch1_rx_k_o       <= '0';
        ch1_rx_enc_err_o <= '0';
        
      elsif rising_edge(ch1_rx_rec_clk) then
        if(ch1_rx_enable_output_synced = '0') then
-- make sure the output data is invalid when the link is down and that it will
-- trigger the sync loss detection
          ch1_rx_data_o    <= (others => '0');
          ch1_rx_k_o       <= '1';
          ch1_rx_enc_err_o <= '1';
        else
          ch1_rx_data_o    <= ch1_rx_data_int after 1ns;
          ch1_rx_k_o       <= ch1_rx_k_int after 1ns;
          ch1_rx_enc_err_o <= (ch1_rx_disperr or ch1_rx_invcode) after 1ns;
        end if;
      end if;
    end process;

    ch1_rx_rbclk_o <= ch1_rx_rec_clk;
  end generate gen_with_channel1;

  ch1_gtp_loopback <= "000";

  -------------------------------------------------------------------------------
  -- Common logic
  -------------------------------------------------------------------------------

  gen_with_common : if(g_enable_ch0 /= 0) or (g_enable_ch1 /= 0) generate
    
    ch01_ref_clk_in <= gtp_clk_i;

    ch01_gtp_locked <= ch01_gtp_pll_lockdet and (ch0_gtp_reset_done or To_Std_Logic(g_enable_ch0 = 0)) and (ch1_gtp_reset_done or To_Std_Logic(g_enable_ch1 = 0));

    U_align_ch1 : gtp_phase_align
      generic map (
        g_simulation => g_simulation) 
      port map (
        gtp_rst_i                   => ch01_gtp_reset,
        gtp_tx_clk_i                => ch01_ref_clk_i,
        gtp_tx_en_pma_phase_align_o => ch01_tx_en_pma_phase_align,
        gtp_tx_pma_set_phase_o      => ch01_tx_pma_set_phase,
        align_en_i                  => ch01_gtp_locked,
        align_done_o                => ch01_align_done);
  end generate gen_with_common;

  U_GTP_TILE_INST : WHITERABBITGTP_WRAPPER_TILE_VIRTEX5
    generic map
    (
      TILE_SIM_MODE             => "FAST",  -- Set to Fast Functional Simulation Model    
      TILE_SIM_GTPRESET_SPEEDUP => 0,   -- Set to 1 to speed up sim reset
      TILE_SIM_PLL_PERDIV2      => x"190",  -- Set to the VCO Unit Interval time 

      TILE_CHAN_BOND_MODE_0  => "OFF",  -- "MASTER", "SLAVE", or "OFF"
      TILE_CHAN_BOND_LEVEL_0 => 0,  -- 0 to 7. See UG for details                            
      TILE_CHAN_BOND_MODE_1  => "OFF",  -- "MASTER", "SLAVE", or "OFF"
      TILE_CHAN_BOND_LEVEL_1 => 0       -- 0 to 7. See UG for details
      )
    port map
    (
      ------------------------ Loopback and Powerdown Ports ----------------------
      LOOPBACK0_IN         => ch0_gtp_loopback,
      LOOPBACK1_IN         => ch1_gtp_loopback,
      ----------------------- Receive Ports - 8b10b Decoder ----------------------
      RXCHARISK0_OUT       => ch0_rx_data_raw_int_pre(8),
      RXCHARISK1_OUT       => ch1_rx_data_raw_int_pre(8),
      RXDISPERR0_OUT       => ch0_rx_data_raw_int_pre(9),
      RXDISPERR1_OUT       => ch1_rx_data_raw_int_pre(9),
      RXNOTINTABLE0_OUT    => open,
      RXNOTINTABLE1_OUT    => open,
      --------------- Receive Ports - Comma Detection and Alignment --------------
-- these don't seem to work on Virtex5 - we need to emulate them.
      RXBYTEISALIGNED0_OUT => open,
      RXBYTEISALIGNED1_OUT => open,
      RXCOMMADET0_OUT      => open,
      RXCOMMADET1_OUT      => open,
      RXSLIDE0_IN          => ch0_rx_slide,
      RXSLIDE1_IN          => ch1_rx_slide,
      ------------------- Receive Ports - RX Data Path interface -----------------
      RXDATA0_OUT          => ch0_rx_data_raw_int_pre(7 downto 0),
      RXDATA1_OUT          => ch1_rx_data_raw_int_pre(7 downto 0),
      RXRECCLK0_OUT        => ch0_rx_rec_clk_pad,
      RXRECCLK1_OUT        => ch1_rx_rec_clk_pad,
      RXUSRCLK0_IN         => ch0_rx_rec_clk,
      RXUSRCLK1_IN         => ch1_rx_rec_clk,
      RXUSRCLK20_IN        => ch0_rx_rec_clk,
      RXUSRCLK21_IN        => ch1_rx_rec_clk,
      ------- Receive Ports - RX Driver,OOB signalling,Coupling and Eq.,CDR ------
      RXCDRRESET0_IN       => ch0_rx_cdr_rst,
      RXCDRRESET1_IN       => ch1_rx_cdr_rst,
      RXN0_IN              => pad_rxn0_i,
      RXN1_IN              => pad_rxn1_i,
      RXP0_IN              => pad_rxp0_i,
      RXP1_IN              => pad_rxp1_i,
      --------------- Receive Ports - RX Loss-of-sync State Machine --------------
      RXLOSSOFSYNC0_OUT    => open,
      RXLOSSOFSYNC1_OUT    => open,
      --------------------- Shared Ports - Tile and PLL Ports --------------------
      CLKIN_IN             => ch01_ref_clk_in,             --- TO BE CONFIRMED
      GTPRESET_IN          => ch01_gtp_reset,              --- TO BE CONFIRMED
      PLLLKDET_OUT         => ch01_gtp_pll_lockdet,        --- TO BE CONFIRMED
      REFCLKOUT_OUT        => ch01_gtp_clkout_int,
      RESETDONE0_OUT       => ch0_gtp_reset_done,          --- TO BE CONFIRMED
      RESETDONE1_OUT       => ch1_gtp_reset_done,          --- TO BE CONFIRMED
      TXENPMAPHASEALIGN_IN => ch01_tx_en_pma_phase_align,  --- TO BE CONFIRMED
      TXPMASETPHASE_IN     => ch01_tx_pma_set_phase,       --- TO BE CONFIRMED
      ---------------- Transmit Ports - 8b10b Encoder Control Ports --------------
      TXCHARDISPVAL0_IN    => ch0_tx_chardispval,
      TXCHARDISPVAL1_IN    => ch1_tx_chardispval,
      TXCHARISK0_IN        => ch0_tx_k_i,
      TXCHARISK1_IN        => ch1_tx_k_i,
      ------------------ Transmit Ports - TX Data Path interface -----------------
      TXDATA0_IN           => ch0_tx_data_i,
      TXDATA1_IN           => ch1_tx_data_i,
      TXUSRCLK0_IN         => ch01_ref_clk_i,
      TXUSRCLK1_IN         => ch01_ref_clk_i,
      TXUSRCLK20_IN        => ch01_ref_clk_i,
      TXUSRCLK21_IN        => ch01_ref_clk_i,
      --------------- Transmit Ports - TX Driver and OOB signalling --------------
      TXN0_OUT             => pad_txn0_o,
      TXN1_OUT             => pad_txn1_o,
      TXP0_OUT             => pad_txp0_o,
      TXP1_OUT             => pad_txp1_o
      );

  -- Debug added by J.Simonin
  ch1_align_done_o <= ch01_align_done;
  ch1_rx_synced_o  <= ch1_rx_synced;
  ch0_rdy_o <= ch0_gtp_locked_rxclk and ch0_rx_enable_output_synced;
  ch1_rdy_o <= ch1_gtp_locked_rxclk and ch1_rx_enable_output_synced;

end rtl;
