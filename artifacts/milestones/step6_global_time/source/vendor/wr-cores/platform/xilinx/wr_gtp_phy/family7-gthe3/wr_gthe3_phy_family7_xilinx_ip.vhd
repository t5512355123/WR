library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.gencores_pkg.all;
use work.disparity_gen_pkg.all;

entity wr_gthe3_phy_family7_xilinx_ip is

  generic (
    -- set to non-zero value to speed up the simulation by reducing some delays
    g_simulation : integer := 0
    );

  port (
    -- Dedicated reference 125 MHz clock for the GTX transceiver
    clk_gth_p_i : in std_logic;
    clk_gth_n_i : in std_logic;

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
end wr_gthe3_phy_family7_xilinx_ip;

architecture rtl of wr_gthe3_phy_family7_xilinx_ip is

  component wr_gth_wrapper_example_top is
    port (
      ch0_gthrxn_in                 : in  std_logic;
      
      ch0_gthrxp_in                 : in  std_logic;
      ch0_gthtxn_out                : out std_logic;
      ch0_gthtxp_out                : out std_logic;
      hb_gtwiz_reset_all_in         : in  std_logic;
      hb_gtwiz_reset_clk_freerun_in : in  std_logic;
      mgtrefclk0_x0y2_n             : in  std_logic;
      mgtrefclk0_x0y2_p             : in  std_logic;
      rx_byte_is_aligned_o          : out std_logic;
      rx_clk_o                      : out std_logic;
      rx_comma_det_o                : out std_logic;
      rx_data_o                     : out std_logic_vector(15 downto 0);
      rx_k_o                        : out std_logic_vector(1 downto 0);
      rx_slide_i                    : in  std_logic;
      tx_clk_o                      : out std_logic;
      tx_data_i                     : in  std_logic_vector(15 downto 0);
      tx_k_i                        : in  std_logic_vector(1 downto 0);
      ready_o : out std_logic);
  end component wr_gth_wrapper_example_top;

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
  signal serdes_ready, rx_comma_det, rx_byte_is_aligned, rx_slide : std_logic;
  signal rx_synced,rst_rxclk                                                : std_logic;

  signal rx_data_int                                              : std_logic_vector(15 downto 0);
  signal rx_k_int                                                 : std_logic_vector(1 downto 0);

  signal cur_disp : t_8b10b_disparity;

  signal tx_is_k_swapped : std_logic_vector(1 downto 0);
  signal tx_data_swapped : std_logic_vector(15 downto 0);

  attribute keep : string;
  attribute keep of rx_data_int : signal is "true";
  attribute keep of rx_k_int : signal is "true";

    
begin

 U_Sync_Reset :  gc_sync_ffs
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
      serdes_ready_i           => serdes_ready,
      gtp_rx_slide_o           => rx_slide,
      gtp_rx_cdr_rst_o         => open,
      bitslide_o               => rx_bitslide_o,
      synced_o                 => rx_synced);

 tx_is_k_swapped <=  tx_k_i(0) & tx_k_i(1);
  tx_data_swapped <= tx_data_i(7 downto 0) & tx_data_i(15 downto 8);

  U_Wrapped_GTH : wr_gth_wrapper_example_top
    port map (
      ch0_gthrxn_in  => pad_rxn_i,
      ch0_gthrxp_in  => pad_rxp_i,
      ch0_gthtxn_out => pad_txn_o,
      ch0_gthtxp_out => pad_txp_o,

      hb_gtwiz_reset_all_in         => rst_i,
      hb_gtwiz_reset_clk_freerun_in => clk_freerun_i,

      mgtrefclk0_x0y2_n    => clk_gth_n_i,
      mgtrefclk0_x0y2_p    => clk_gth_p_i,
      rx_byte_is_aligned_o => rx_byte_is_aligned,
      rx_clk_o             => rx_clk,
      rx_comma_det_o       => rx_comma_det,
      rx_data_o            => rx_data_int,
      rx_k_o               => rx_k_int,
      rx_slide_i           => rx_slide,
      tx_clk_o             => tx_clk,
      tx_data_i            => tx_data_swapped,
      tx_k_i               => tx_is_k_swapped,
      ready_o              => serdes_ready);


  p_gen_rx_outputs : process(rx_clk, rst_rxclk)
  begin
    if(rst_rxclk = '1') then
      rx_data_o    <= (others => '0');
      rx_k_o       <= (others => '0');
      rx_enc_err_o <= '0';
    elsif rising_edge(rx_clk) then
      if(serdes_ready = '1' and rx_synced = '1') then
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
      if serdes_ready = '0' then
        cur_disp <= RD_MINUS;
      else
        cur_disp <= f_next_8b10b_disparity16(cur_disp, tx_k_i, tx_data_i);
      end if;
    end if;
  end process;

  tx_disparity_o <= to_std_logic(cur_disp);

  tx_out_clk_o   <= tx_clk;
  rx_rbclk_o <= rx_clk;

 rdy_o <= serdes_ready and rx_synced;
 tx_locked_o <= '1';
 tx_enc_err_o <= '0';
 
  
end rtl;


