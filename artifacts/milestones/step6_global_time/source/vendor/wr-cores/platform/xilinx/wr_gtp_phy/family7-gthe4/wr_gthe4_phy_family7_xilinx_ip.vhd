library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.gencores_pkg.all;
use work.disparity_gen_pkg.all;

entity wr_gthe4_phy_family7_xilinx_ip is

  generic (
    -- set to non-zero value to speed up the simulation by reducing some delays
    g_simulation         : integer := 0;
    g_use_gclk_as_refclk : boolean);

  port (
    -- Dedicated reference 125 MHz clock for the GTX transceiver
    clk_gth_i     : in std_logic;
    clk_freerun_i : in std_logic;

    -- TX path, synchronous to tx_out_clk_o (62.5 MHz):
    tx_out_clk_o : out std_logic;
    tx_locked_o  : out std_logic;

    -- data input (8 bits, not 8b10b-encoded)
    tx_data_i : in std_logic_vector(15 downto 0);

    -- 1 when tx_data_i contains a control code, 0 when it's a data byte
    tx_k_i : in std_logic_vector(1 downto 0);

    -- disparity of the currently transmitted 8b10b code (1 = plus, 0 = minus).
    -- Necessary for the PCS to generate proper frame termination sequences.
    -- Generated for the 2nd byte (LSB) of tx_data_i.
    tx_disparity_o : out std_logic;

    -- Encoding error indication (1 = error, 0 = no error)
    tx_enc_err_o : out std_logic;

    -- RX path, synchronous to ch0_rx_rbclk_o.

    -- RX recovered clock
    rx_rbclk_o : out std_logic;

    -- 8b10b-decoded data output. The data output must be kept invalid before
    -- the transceiver is locked on the incoming signal to prevent the EP from
    -- detecting a false carrier.
    rx_data_o : out std_logic_vector(15 downto 0);

    -- 1 when the byte on rx_data_o is a control code
    rx_k_o : out std_logic_vector(1 downto 0);

    -- encoding error indication
    rx_enc_err_o : out std_logic;

    -- RX bitslide indication, indicating the delay of the RX path of the
    -- transceiver (in UIs). Must be valid when ch0_rx_data_o is valid.
    rx_bitslide_o : out std_logic_vector(4 downto 0);


    -- reset input, active hi
    rst_i    : in std_logic;
    loopen_i : in std_logic_vector(2 downto 0);

    debug_i : in  std_logic_vector(15 downto 0);
    debug_o : out std_logic_vector(15 downto 0);

    pad_txn_o : out std_logic;
    pad_txp_o : out std_logic;

    pad_rxn_i : in std_logic := '0';
    pad_rxp_i : in std_logic := '0';

    rdy_o : out std_logic);
end wr_gthe4_phy_family7_xilinx_ip;

architecture rtl of wr_gthe4_phy_family7_xilinx_ip is


  component gtwizard_ultrascale_2 is
    port (
      gthrxn_in                            : in  std_logic;
      gthrxp_in                            : in  std_logic;
      gthtxn_out                           : out std_logic;
      gthtxp_out                           : out std_logic;
      gtwiz_userclk_tx_reset_in            : in  std_logic_vector(0 downto 0);
      gtwiz_userclk_tx_usrclk_out          : out std_logic_vector(0 downto 0);
      gtwiz_userclk_tx_usrclk2_out         : out std_logic_vector(0 downto 0);
      gtwiz_userclk_tx_active_out          : out std_logic_vector(0 downto 0);
      gtwiz_userclk_rx_reset_in            : in  std_logic_vector(0 downto 0);
      gtwiz_userclk_rx_usrclk_out          : out std_logic_vector(0 downto 0);
      gtwiz_userclk_rx_usrclk2_out         : out std_logic_vector(0 downto 0);
      gtwiz_userclk_rx_active_out          : out std_logic_vector(0 downto 0);
      gtwiz_buffbypass_tx_reset_in         : in  std_logic_vector(0 downto 0);
      gtwiz_buffbypass_tx_start_user_in    : in  std_logic_vector(0 downto 0); 
      gtwiz_buffbypass_tx_done_out         : out std_logic_vector(0 downto 0);
      gtwiz_buffbypass_tx_error_out        : out std_logic_vector(0 downto 0);
      gtwiz_buffbypass_rx_reset_in         : in  std_logic_vector(0 downto 0); 
      gtwiz_buffbypass_rx_start_user_in    : in  std_logic_vector(0 downto 0);
      gtwiz_buffbypass_rx_done_out         : out std_logic_vector(0 downto 0);
      gtwiz_buffbypass_rx_error_out        : out std_logic_vector(0 downto 0);
      drpaddr_in                           : in  std_logic_vector(9 downto 0);
      drpclk_in                            : in  std_logic;
      drpdi_in                             : in  std_logic_vector(15 downto 0);
      drpen_in                             : in  std_logic;
      drpwe_in                             : in  std_logic;
      eyescanreset_in                      : in  std_logic;

      gtrefclk0_in : in std_logic;

      gtwiz_reset_clk_freerun_in           : in  std_logic_vector(0 downto 0);
      gtwiz_reset_all_in                   : in  std_logic_vector(0 downto 0);
      gtwiz_reset_tx_pll_and_datapath_in   : in  std_logic_vector(0 downto 0);
      gtwiz_reset_tx_datapath_in           : in  std_logic_vector(0 downto 0);
      gtwiz_reset_rx_pll_and_datapath_in   : in  std_logic_vector(0 downto 0);
      gtwiz_reset_rx_datapath_in           : in  std_logic_vector(0 downto 0);
      gtwiz_reset_rx_cdr_stable_out        : out std_logic_vector(0 downto 0);
      gtwiz_reset_tx_done_out              : out std_logic_vector(0 downto 0);
      gtwiz_reset_rx_done_out              : out std_logic_vector(0 downto 0);
      gtwiz_userdata_tx_in                 : in  std_logic_vector(15 downto 0);
      gtwiz_userdata_rx_out                : out std_logic_vector(15 downto 0);
      rx8b10ben_in                         : in  std_logic_vector(0 downto 0);
      rxcommadeten_in                      : in  std_logic_vector(0 downto 0);
      rxmcommaalignen_in                   : in  std_logic_vector(0 downto 0);
      rxpcommaalignen_in                   : in  std_logic_vector(0 downto 0);
      rxslide_in                           : in  std_logic_vector(0 downto 0);
      tx8b10ben_in                         : in  std_logic_vector(0 downto 0);
      txctrl0_in                           : in  std_logic_vector(15 downto 0);
      txctrl1_in                           : in  std_logic_vector(15 downto 0);
      txctrl2_in                           : in  std_logic_vector(7 downto 0);
      rxbyteisaligned_out                  : out std_logic_vector(0 downto 0);
      rxbyterealign_out                    : out std_logic;
      rxcommadet_out                       : out std_logic_vector(0 downto 0);
      rxctrl0_out                          : out std_logic_vector(15 downto 0);
      rxctrl1_out                          : out std_logic_vector(15 downto 0);
      rxctrl2_out                          : out std_logic_vector(7 downto 0);
      rxctrl3_out                          : out std_logic_vector(7 downto 0);
      rxpmaresetdone_out                   : out std_logic_vector(0 downto 0);
      txpmaresetdone_out                   : out std_logic_vector(0 downto 0);

      rxlpmen_in      : in std_logic_vector(0 downto 0);
      rxrate_in       : in std_logic_vector(2 downto 0);
      txdiffctrl_in   : in std_logic_vector(4 downto 0);
      txpostcursor_in : in std_logic_vector(4 downto 0);
      txprecursor_in  : in std_logic_vector(4 downto 0)
      );
  end component gtwizard_ultrascale_2;


  signal gtwiz_userclk_tx_reset_in     : std_logic;
--  signal gtwiz_userclk_tx_srcclk_out        : std_logic;
--  signal gtwiz_userclk_tx_usrclk_out        : std_logic;
--  signal gtwiz_userclk_tx_usrclk2_out       : std_logic;
  signal gtwiz_userclk_tx_active_out   : std_logic;
  signal gtwiz_userclk_rx_reset_in     : std_logic;
--  signal gtwiz_userclk_rx_srcclk_out        : std_logic;
--  signal gtwiz_userclk_rx_usrclk_out        : std_logic;
--  signal gtwiz_userclk_rx_usrclk2_out       : std_logic;
  signal gtwiz_userclk_rx_active_out   : std_logic;
  signal gtwiz_buffbypass_tx_reset_in  : std_logic;
--  signal gtwiz_buffbypass_tx_start_user_in  : std_logic;
  signal gtwiz_buffbypass_tx_done_out  : std_logic;
  signal gtwiz_buffbypass_tx_error_out : std_logic;
  signal gtwiz_buffbypass_rx_reset_in  : std_logic;
--  signal gtwiz_buffbypass_rx_start_user_in  : std_logic;
  signal gtwiz_buffbypass_rx_done_out  : std_logic;
  signal gtwiz_buffbypass_rx_error_out : std_logic;
--  signal gtwiz_reset_clk_freerun_in         : std_logic;
  signal gtwiz_reset_all_in            : std_logic;
--  signal gtwiz_reset_tx_pll_and_datapath_in : std_logic;
--  signal gtwiz_reset_tx_datapath_in         : std_logic;
--  signal gtwiz_reset_rx_pll_and_datapath_in : std_logic;
--  signal gtwiz_reset_rx_datapath_in         : std_logic;
  signal gtwiz_reset_rx_cdr_stable_out : std_logic;
  signal gtwiz_reset_tx_done_out       : std_logic;
  signal gtwiz_reset_rx_done_out       : std_logic;
--  signal gtwiz_userdata_tx_in               : std_logic_vector(15 downto 0);
--  signal gtwiz_userdata_rx_out              : std_logic_vector(15 downto 0);

  signal txctrl0_int        : std_logic_vector(15 downto 0);
  signal txctrl1_int        : std_logic_vector(15 downto 0);
  signal txctrl2_int        : std_logic_vector(7 downto 0);
--  signal rxbyteisaligned_out                : std_logic;
--  signal rxbyterealign_out                  : std_logic;
--  signal rxcommadet_out                     : std_logic;
  signal rxctrl0_int        : std_logic_vector(15 downto 0);
  signal rxctrl1_int        : std_logic_vector(15 downto 0);
  signal rxctrl2_int        : std_logic_vector(7 downto 0);
  signal rxctrl3_int        : std_logic_vector(7 downto 0);
  signal rxpmaresetdone_int : std_logic;
  signal txpmaresetdone_int : std_logic;

  signal rx8b10ben_int    : std_logic;
  signal drpaddr_int      : std_logic_vector(9 downto 0);
  signal drpclk_int       : std_logic;
  signal drpdi_int        : std_logic_vector(15 downto 0);
  signal drpen_int        : std_logic;
  signal drpwe_int        : std_logic;
  signal eyescanreset_int : std_logic;

  signal rxrate_int     : std_logic_vector(2 downto 0);
  signal rxlpmen_int    : std_logic;
  signal txdiffctrl_int : std_logic_vector(4 downto 0);

  signal txprecursor_int, txpostcursor_int : std_logic_vector(4 downto 0);

  component gtp_bitslide is
    generic (
      g_simulation : integer;
      g_target     : string);
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
  end component gtp_bitslide;

  signal rx_clk, tx_clk                                           : std_logic;
  signal serdes_ready_a, serdes_ready_txclk, serdes_ready_rxclk, rx_comma_det, rx_byte_is_aligned, rx_slide : std_logic;
  signal rx_synced, rst_rxclk                                     : std_logic;

  -- attribute mark_debug : string;
  -- attribute mark_debug of serdes_ready : signal is "true";
  -- attribute mark_debug of rx_comma_det : signal is "true";
  -- attribute mark_debug of rx_byte_is_aligned : signal is "true";
  -- attribute mark_debug of rx_slide : signal is "true";
  -- attribute mark_debug of rx_synced : signal is "true";
  

  -- attribute mark_debug of gtwiz_reset_all_in : signal is "true";
  -- attribute mark_debug of gtwiz_reset_rx_done_out : signal is "true";
  -- attribute mark_debug of gtwiz_buffbypass_rx_done_out : signal is "true";
  -- attribute mark_debug of gtwiz_buffbypass_tx_done_out : signal is "true";

  
  signal rx_data_int : std_logic_vector(15 downto 0);
  signal rx_k_int    : std_logic_vector(1 downto 0);

  signal cur_disp : t_8b10b_disparity;

  signal tx_is_k_swapped : std_logic_vector(1 downto 0);
  signal tx_data_swapped : std_logic_vector(15 downto 0);

  attribute keep                : string;
  attribute keep of rx_data_int : signal is "true";
  attribute keep of rx_k_int    : signal is "true";

  signal rst_extended : std_logic;


  signal rst_n : std_logic;
  signal gtwiz_buffbypass_tx_reset_pre, gtwiz_buffbypass_rx_reset_pre : std_logic;

  signal s_zero : std_logic := '0';
  signal s_one : std_logic := '1';
  
  
begin

  rst_n <= not rst_i;

  gtwiz_buffbypass_tx_reset_pre <= not gtwiz_userclk_tx_active_out;
  
  U_Sync1 : gc_sync_ffs
    port map (
      clk_i    => tx_clk,
      rst_n_i  => rst_n,
      data_i   => gtwiz_buffbypass_tx_reset_pre,
      synced_o => gtwiz_buffbypass_tx_reset_in);

  gtwiz_buffbypass_rx_reset_pre <= not gtwiz_userclk_rx_active_out or not gtwiz_buffbypass_tx_done_out;
  
  U_Sync2 : gc_sync_ffs
    port map (
      clk_i    => rx_clk,
      rst_n_i  => rst_n,
      data_i   => gtwiz_buffbypass_rx_reset_pre,
      synced_o => gtwiz_buffbypass_rx_reset_in);

  gtwiz_userclk_tx_reset_in <= not txpmaresetdone_int;
  gtwiz_userclk_rx_reset_in <= not rxpmaresetdone_int;

  U_Sync_Reset : gc_sync_ffs
    port map (
      clk_i    => rx_clk,
      rst_n_i  => '1',
      data_i   => rst_i,
      synced_o => rst_rxclk);

  U_Bitslide : gtp_bitslide
    generic map (
      g_simulation => g_simulation,
      g_target     => "ultrascale")
    port map (
      gtp_rst_i                => rst_i,
      gtp_rx_clk_i             => rx_clk,
      gtp_rx_comma_det_i       => rx_comma_det,
      gtp_rx_byte_is_aligned_i => rx_byte_is_aligned,
      serdes_ready_i           => serdes_ready_rxclk,
      gtp_rx_slide_o           => rx_slide,
      gtp_rx_cdr_rst_o         => open,
      bitslide_o               => rx_bitslide_o,
      synced_o                 => rx_synced);

  tx_is_k_swapped <= tx_k_i(0) & tx_k_i(1);
  tx_data_swapped <= tx_data_i(7 downto 0) & tx_data_i(15 downto 8);

  gtwiz_reset_all_in <= rst_i;

  -- U_gtwizard_gthe4 : entity work.gtwizard_ultrascale_2
  U_gtwizard_gthe4 : gtwizard_ultrascale_2
    port map (
      gthrxn_in                            => pad_rxn_i,
      gthrxp_in                            => pad_rxp_i,
      gthtxn_out                           => pad_txn_o,
      gthtxp_out                           => pad_txp_o,
      gtwiz_userclk_tx_reset_in(0)         => gtwiz_userclk_tx_reset_in,
--     gtwiz_userclk_tx_usrclk_out(0)       => open,
      gtwiz_userclk_tx_usrclk2_out(0)      => tx_clk,
      gtwiz_userclk_tx_active_out(0)       => gtwiz_userclk_tx_active_out,
      gtwiz_userclk_rx_reset_in(0)         => gtwiz_userclk_rx_reset_in,
--      gtwiz_userclk_rx_usrclk_out(0)        => open,
      gtwiz_userclk_rx_usrclk2_out(0)      => rx_clk,
      gtwiz_userclk_rx_active_out(0)       => gtwiz_userclk_rx_active_out,
      gtwiz_buffbypass_tx_reset_in(0)      => gtwiz_buffbypass_tx_reset_in,
      gtwiz_buffbypass_tx_start_user_in(0) => s_zero,
      gtwiz_buffbypass_tx_done_out(0)      => gtwiz_buffbypass_tx_done_out,
      gtwiz_buffbypass_tx_error_out(0)     => gtwiz_buffbypass_tx_error_out,
      gtwiz_buffbypass_rx_reset_in(0)      => gtwiz_buffbypass_rx_reset_in,
      gtwiz_buffbypass_rx_start_user_in(0) => s_zero,
      gtwiz_buffbypass_rx_done_out(0)      => gtwiz_buffbypass_rx_done_out,
      gtwiz_buffbypass_rx_error_out(0)     => gtwiz_buffbypass_rx_error_out,
      drpaddr_in                           => drpaddr_int,
      drpclk_in                            => drpclk_int,
      drpdi_in                             => drpdi_int,
      drpen_in                             => drpen_int,
      drpwe_in                             => drpwe_int,
      eyescanreset_in                      => eyescanreset_int,

      gtrefclk0_in => clk_gth_i,

      gtwiz_reset_clk_freerun_in(0)         => clk_freerun_i,
      gtwiz_reset_all_in(0)                 => gtwiz_reset_all_in,
      gtwiz_reset_tx_pll_and_datapath_in(0) => s_zero,  --gtwiz_reset_tx_pll_and_datapath_in,
      gtwiz_reset_tx_datapath_in(0)         => s_zero,  --gtwiz_reset_tx_datapath_in,
      gtwiz_reset_rx_pll_and_datapath_in(0) => s_zero,  -- gtwiz_reset_rx_pll_and_datapath_in,
      gtwiz_reset_rx_datapath_in(0)         => s_zero,  --gtwiz_reset_rx_datapath_in,
      gtwiz_reset_rx_cdr_stable_out(0)      => gtwiz_reset_rx_cdr_stable_out,
      gtwiz_reset_tx_done_out(0)            => gtwiz_reset_tx_done_out,
      gtwiz_reset_rx_done_out(0)            => gtwiz_reset_rx_done_out,
      gtwiz_userdata_tx_in                  => tx_data_swapped,
      gtwiz_userdata_rx_out                 => rx_data_int,
      rx8b10ben_in(0)                       => rx8b10ben_int,
      rxcommadeten_in(0)                    => s_one,
      rxmcommaalignen_in(0)                 => s_zero,
      rxpcommaalignen_in(0)                 => s_zero,
      rxslide_in(0)                         => rx_slide,
      tx8b10ben_in(0)                       => s_one,
      txctrl0_in                            => txctrl0_int,
      txctrl1_in                            => txctrl1_int,
      txctrl2_in                            => txctrl2_int,
      rxbyteisaligned_out(0)                => rx_byte_is_aligned,
      rxbyterealign_out                     => open,
      rxcommadet_out(0)                     => rx_comma_det,
      rxctrl0_out                           => rxctrl0_int,
      rxctrl1_out                           => rxctrl1_int,
      rxctrl2_out                           => rxctrl2_int,
      rxctrl3_out                           => rxctrl3_int,
      rxpmaresetdone_out(0)                 => rxpmaresetdone_int,
      txpmaresetdone_out(0)                 => txpmaresetdone_int,

      rxlpmen_in(0)   => rxlpmen_int,
      rxrate_in       => rxrate_int,
      txdiffctrl_in   => txdiffctrl_int,
      txpostcursor_in => txpostcursor_int,
      txprecursor_in  => txprecursor_int
      );

  drpclk_int  <= clk_freerun_i;
  drpen_int   <= '0';
  drpdi_int   <= (others => '0');
  drpen_int   <= '0';
  drpwe_int   <= '0';
  drpaddr_int <= (others => '0');

  rxrate_int       <= "000";
  txdiffctrl_int   <= "11000";
  txprecursor_int  <= "00000";
  txpostcursor_int <= "00000";
  eyescanreset_int <= '0';
  rxlpmen_int      <= '1';
  rx8b10ben_int    <= '1';


  -- IBERT: gtwizard_ultrascale_2_in_system_ibert_0
  --   port map (
  --   drpclk_o       => drpclk_int,
  --   gt0_drpen_o    => drpen_int,
  --   gt0_drpwe_o    => drpwe_int,
  --   gt0_drpaddr_o  => drpaddr_int,
  --   gt0_drpdi_o    => drpdi_int,
  --   gt0_drprdy_i   => drprdy_int,
  --   gt0_drpdo_i    => drpdo_int,
  --   eyescanreset_o => eyescanreset_int,
  --   rxrate_o       =>rxrate_int,
  --   txdiffctrl_o   =>txdiffctrl_int,
  --   txprecursor_o  =>txprecursor_int,
  --   txpostcursor_o =>txpostcursor_int,
  --   rxlpmen_o      =>rxlpmen_int,
  --   rxrate_i       => "000",
  --   txdiffctrl_i   => "11000",
  --   txprecursor_i  => "00000",
  --   txpostcursor_i => "00000",
  --   rxlpmen_i      => '1',
  --   rxoutclk_i     => rx_clk,
  --   drpclk_i       => clk_freerun_i,
  --   clk            => clk_freerun_i
  --   );

  -- U_Wrapped_GTH : entity work.gtwizard_gthe4_1_example_top
  --   port map (
  --     ch0_gthrxn_in  => pad_rxn_i,
  --     ch0_gthrxp_in  => pad_rxp_i,
  --     ch0_gthtxn_out => pad_txn_o,
  --     ch0_gthtxp_out => pad_txp_o,

  --     hb_gtwiz_reset_all_in         => rst_i,
  --     hb_gtwiz_reset_clk_freerun_in => clk_freerun_i,

  --     mgtrefclk1_x0y2   => clk_gth_i,
  --     rx_byte_is_aligned_o => rx_byte_is_aligned,
  --     rx_clk_o             => rx_clk,
  --     rx_comma_det_o       => rx_comma_det,
  --     rx_data_o            => rx_data_int,
  --     rx_k_o               => rx_k_int,
  --     rx_slide_i           => rx_slide,
  --     tx_clk_o             => tx_clk,
  --     tx_data_i            => tx_data_swapped,
  --     tx_k_i               => tx_is_k_swapped,
  --     ready_o              => serdes_ready);

  serdes_ready_a <=
    not (
      gtwiz_reset_all_in or not gtwiz_reset_rx_done_out or not gtwiz_buffbypass_rx_done_out or not gtwiz_buffbypass_tx_done_out);

  U_Sync_Serdes_RDY1 : gc_sync_ffs
    port map (
      clk_i    => rx_clk,
      rst_n_i  => '1',
      data_i   => serdes_ready_a,
      synced_o => serdes_ready_rxclk);

  U_Sync_Serdes_RDY2 : gc_sync_ffs
    port map (
      clk_i    => tx_clk,
      rst_n_i  => '1',
      data_i   => serdes_ready_a,
      synced_o => serdes_ready_txclk);
  
  txctrl0_int <= x"0000";
  txctrl1_int <= x"0000";
  txctrl2_int <= "000000" & tx_is_k_swapped;
  rx_k_int    <= rxctrl0_int(1 downto 0);


  p_gen_rx_outputs : process(rx_clk, rst_rxclk)
  begin
    if(rst_rxclk = '1') then
      rx_data_o    <= (others => '0');
      rx_k_o       <= (others => '0');
      rx_enc_err_o <= '0';
    elsif rising_edge(rx_clk) then
      if(serdes_ready_rxclk = '1' and rx_synced = '1') then
        rx_data_o    <= rx_data_int(7 downto 0) & rx_data_int(15 downto 8);
        rx_k_o       <= rx_k_int(0) & rx_k_int(1);
        rx_enc_err_o <= '0';  --rx_disp_err(0) or rx_disp_err(1) or rx_code_err(0) or rx_code_err(1);
      else
        rx_data_o    <= (others => '1');
        rx_k_o       <= (others => '1');
        rx_enc_err_o <= '1';
      end if;
    end if;
  end process;

  p_gen_tx_disparity : process(tx_clk)
  begin
    if rising_edge(tx_clk) then
      if serdes_ready_txclk = '0' then
        cur_disp <= RD_MINUS;
      else
        cur_disp <= f_next_8b10b_disparity16(cur_disp, tx_k_i, tx_data_i);
      end if;
    end if;
  end process;

  tx_disparity_o <= to_std_logic(cur_disp);

  tx_out_clk_o <= tx_clk;
  rx_rbclk_o   <= rx_clk;

  rdy_o        <= serdes_ready_rxclk and rx_synced;
  tx_locked_o  <= '1';
  tx_enc_err_o <= '0';


end rtl;


