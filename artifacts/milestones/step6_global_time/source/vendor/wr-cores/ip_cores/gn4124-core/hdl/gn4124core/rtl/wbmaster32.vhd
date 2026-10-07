--------------------------------------------------------------------------------
-- CERN BE-CO-HT
-- GN4124 core for PCIe FMC carrier
-- http://www.ohwr.org/projects/gn4124-core
--------------------------------------------------------------------------------
--
-- unit name:   wbmaster32
--
-- description: 32-bit Wishbone master. Provides a Wishbone interface for
-- single read and write control and status registers.
--
--------------------------------------------------------------------------------
-- Copyright CERN 2010-2018
--------------------------------------------------------------------------------
-- Copyright and related rights are licensed under the Solderpad Hardware
-- License, Version 2.0 (the "License"); you may not use this file except
-- in compliance with the License. You may obtain a copy of the License at
-- http://solderpad.org/licenses/SHL-2.0.
-- Unless required by applicable law or agreed to in writing, software,
-- hardware and materials distributed under this License is distributed on an
-- "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express
-- or implied. See the License for the specific language governing permissions
-- and limitations under the License.
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use work.gn4124_core_pkg.all;
use work.gencores_pkg.all;
use work.genram_pkg.all;


entity wbmaster32 is
  generic (
    g_ACK_TIMEOUT : positive := 100     -- Wishbone ACK timeout (in wb_clk cycles)
    );
  port
    (
      ---------------------------------------------------------
      -- GN4124 core clock and reset
      clk_i   : in std_logic;
      rst_n_i : in std_logic;

      ---------------------------------------------------------
      -- From P2L packet decoder
      --
      -- Header
      pd_wbm_hdr_start_i  : in std_logic;                      -- Header strobe
      pd_wbm_hdr_length_i : in std_logic_vector(9 downto 0);   -- Packet length in 32-bit words multiples
      pd_wbm_hdr_cid_i    : in std_logic_vector(1 downto 0);   -- Completion ID
      pd_wbm_target_mrd_i : in std_logic;                      -- Target memory read
      pd_wbm_target_mwr_i : in std_logic;                      -- Target memory write
      --
      -- Address
      pd_wbm_addr_start_i : in std_logic;                      -- Address strobe
      pd_wbm_addr_i       : in std_logic_vector(31 downto 0);  -- Target address (in byte) that will increment with data
                                                               -- increment = 4 bytes
      --
      -- Data
      pd_wbm_data_valid_i : in std_logic;                      -- Indicates Data is valid
      pd_wbm_data_last_i  : in std_logic;                      -- Indicates end of the packet
      pd_wbm_data_i       : in std_logic_vector(31 downto 0);  -- Data
      pd_wbm_be_i         : in std_logic_vector(3 downto 0);   -- Byte Enable for data

      ---------------------------------------------------------
      -- P2L channel control
      p_wr_rdy_o   : out std_logic_vector(1 downto 0);  -- Ready to accept target write
      p2l_rdy_o    : out std_logic;                     -- De-asserted to pause transfer already in progress
      p_rd_d_rdy_i : in  std_logic;                     -- Asserted when GN4124 ready to accept read completion with data

      ---------------------------------------------------------
      -- To the arbiter (L2P data)
      wbm_arb_valid_o  : out std_logic;  -- Read completion signals
      wbm_arb_dframe_o : out std_logic;  -- Toward the arbiter
      wbm_arb_data_o   : out std_logic_vector(31 downto 0);
      wbm_arb_req_o    : out std_logic;
      arb_wbm_gnt_i    : in  std_logic;

      ---------------------------------------------------------
      -- CSR wishbone interface
      wb_rst_n_i : in  std_logic;                      -- Active low reset in sync with wb_clk_i
      wb_clk_i   : in  std_logic;                      -- Wishbone bus clock
      wb_adr_o   : out std_logic_vector(30 downto 0);  -- Address
      wb_dat_o   : out std_logic_vector(31 downto 0);  -- Data out
      wb_sel_o   : out std_logic_vector(3 downto 0);   -- Byte select
      wb_stb_o   : out std_logic;                      -- Strobe
      wb_we_o    : out std_logic;                      -- Write
      wb_cyc_o   : out std_logic;                      -- Cycle
      wb_dat_i   : in  std_logic_vector(31 downto 0);  -- Data in
      wb_ack_i   : in  std_logic;                      -- Acknowledge
      wb_stall_i : in  std_logic;                      -- Stall
      wb_err_i   : in  std_logic;                      -- Error
      wb_rty_i   : in  std_logic                       -- Retry
      );
end wbmaster32;


architecture behaviour of wbmaster32 is


  -----------------------------------------------------------------------------
  -- Constants declaration
  -----------------------------------------------------------------------------
  constant c_TO_WB_FIFO_SIZE         : integer := 128;
  constant c_TO_WB_FIFO_FULL_THRES   : integer := 110;
  constant c_FROM_WB_FIFO_SIZE       : integer := 128;
  constant c_FROM_WB_FIFO_FULL_THRES : integer := 110;

  -----------------------------------------------------------------------------
  -- Signals declaration
  -----------------------------------------------------------------------------

  -- Sync fifos
  signal fifo_rst_n    : std_logic;
  signal wb_fifo_rst_n : std_logic;

  signal to_wb_fifo_empty : std_logic;
  signal to_wb_fifo_full  : std_logic;
  signal to_wb_fifo_rd    : std_logic;
  signal to_wb_fifo_wr    : std_logic;
  signal to_wb_fifo_din   : std_logic_vector(65 downto 0) := (others => '0');
  signal to_wb_fifo_dout  : std_logic_vector(65 downto 0);
  signal to_wb_fifo_rw    : std_logic;
  signal to_wb_fifo_data  : std_logic_vector(31 downto 0);
  signal to_wb_fifo_addr  : std_logic_vector(30 downto 0);
  signal to_wb_fifo_cid   : std_logic_vector(1 downto 0);

  signal from_wb_fifo_empty : std_logic;
  signal from_wb_fifo_full  : std_logic;
  signal from_wb_fifo_rd    : std_logic;
  signal from_wb_fifo_wr    : std_logic;
  signal from_wb_fifo_din   : std_logic_vector(33 downto 0) := (others => '0');
  signal from_wb_fifo_dout  : std_logic_vector(33 downto 0);

  signal wbm_arb_data : std_logic_vector(31 downto 0) := (others => '0');

  -- Wishbone
  type   wishbone_state_type is (WB_IDLE, WB_READ_FIFO, WB_CYCLE, WB_WAIT_ACK);
  signal wishbone_current_state : wishbone_state_type;

  signal wb_ack_t   : std_logic;
  signal wb_err_t   : std_logic;
  signal wb_dat_i_t : std_logic_vector(31 downto 0);
  signal wb_cyc_t   : std_logic;
  signal wb_dat_o_t : std_logic_vector(31 downto 0) := (others => '0');
  signal wb_stb_t   : std_logic;
  signal wb_adr_t   : std_logic_vector(30 downto 0) := (others => '0');
  signal wb_we_t    : std_logic;
  signal wb_sel_t   : std_logic_vector(3 downto 0) := (others => '0');
  signal wb_stall_t : std_logic;
  signal wb_cid_t : std_logic_vector(1 downto 0);

  signal wb_ack_timeout_cnt : unsigned(log2_ceil(g_ACK_TIMEOUT)-1 downto 0);
  signal wb_ack_timeout     : std_logic;

  -- L2P packet generator
  type   l2p_read_cpl_state_type is (L2P_IDLE, L2P_HEADER, L2P_DATA);
  signal l2p_read_cpl_current_state : l2p_read_cpl_state_type;

  signal p2l_cid      : std_logic_vector(1 downto 0);
  signal s_l2p_header : std_logic_vector(31 downto 0);


begin


  ------------------------------------------------------------------------------
  -- Active low resets for fifos
  ------------------------------------------------------------------------------
  fifo_rst_n <= rst_n_i;

  -- Local resynced copy of fifo_rst_n to make sure that both sides of the fifo
  -- are reset if rst_n_i = '0'
  cmp_wb_fifo_rst_sync: gc_sync_ffs
    port map (
      clk_i    => wb_clk_i,
      rst_n_i  => wb_rst_n_i,
      data_i   => fifo_rst_n,
      synced_o => wb_fifo_rst_n);

  ------------------------------------------------------------------------------
  -- Write frame from P2L decoder to fifo
  ------------------------------------------------------------------------------

  -- ready to receive new target write if fifo not full
  p_wr_rdy_o <= "00" when to_wb_fifo_full = '1' else "11";

  -- pause transfer from GN4124 when fifo is full
  p2l_rdy_o <= not(to_wb_fifo_full);

  p_from_decoder : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if (rst_n_i = '0') then
        to_wb_fifo_wr  <= '0';
      else
        if (pd_wbm_target_mwr_i = '1' and pd_wbm_data_valid_i = '1') then
          -- Target write
          -- wishbone address is in 32-bit words and address from PCIe in byte
          -- pd_wbm_addr_i(0) represent the BAR (0 = BAR0, 1 = BAR 2)
          to_wb_fifo_din(62 downto 32) <= pd_wbm_addr_i(0) & pd_wbm_addr_i(31 downto 2);
          to_wb_fifo_din(31 downto 0)  <= pd_wbm_data_i;
          to_wb_fifo_din(63)           <= '1';
          to_wb_fifo_din(65 downto 64) <= pd_wbm_hdr_cid_i;
          to_wb_fifo_wr                <= '1';
        elsif (pd_wbm_target_mrd_i = '1' and pd_wbm_addr_start_i = '1') then
          -- Target read request
          -- wishbone address is in 32-bit words and address from PCIe in byte
          -- pd_wbm_addr_i(0) represent the BAR (0 = BAR0, 1 = BAR 2)
          to_wb_fifo_din(62 downto 32) <= pd_wbm_addr_i(0) & pd_wbm_addr_i(31 downto 2);
          to_wb_fifo_din(65 downto 64) <= pd_wbm_hdr_cid_i;
          to_wb_fifo_din(63)           <= '0';
          to_wb_fifo_wr                <= '1';
        else
          to_wb_fifo_wr <= '0';
        end if;
      end if;
    end if;
  end process p_from_decoder;

  ------------------------------------------------------------------------------
  -- Packet generator
  ------------------------------------------------------------------------------
  -- Generates read completion with requested data
  -- Single 32-bit word read only


  --read completion header
  s_l2p_header <= "000"                 -->  Traffic Class
                  & '0'                 -->  Reserved
                  & "0101"              -->  Read completion (Master read competition with data)
                  & "000000"            -->  Reserved
                  & "00"                -->  Completion Status
                  & '1'                 -->  Last completion packet
                  & "00"                -->  Reserved
                  & '0'                 -->  VC (Vitrual Channel)
                  & p2l_cid             -->  CID (Completion Identifer)
                  & "0000000001";       -->  Length (Single 32-bit word read only)


  p2l_cid <= from_wb_fifo_dout(33 downto 32);

  ------------------------------------------------------------------------------
  -- L2P packet write FSM
  ------------------------------------------------------------------------------
  process( from_wb_fifo_empty, p_rd_d_rdy_i, l2p_read_cpl_current_state )
  begin
    if(l2p_read_cpl_current_state = L2P_IDLE and from_wb_fifo_empty = '0' and p_rd_d_rdy_i = '1') then
      from_wb_fifo_rd <= '1';
    else
      from_wb_fifo_rd <= '0';
    end if;
  end process;

  process (clk_i)
  begin
    if rising_edge(clk_i) then
      if(rst_n_i = '0') then
        l2p_read_cpl_current_state <= L2P_IDLE;
        wbm_arb_req_o              <= '0';
        wbm_arb_valid_o            <= '0';
        wbm_arb_dframe_o           <= '0';
      else
        case l2p_read_cpl_current_state is

          when L2P_IDLE =>
            wbm_arb_req_o    <= '0';
            wbm_arb_data     <= (others => '0');
            wbm_arb_valid_o  <= '0';
            wbm_arb_dframe_o <= '0';
            if(from_wb_fifo_empty = '0' and p_rd_d_rdy_i = '1') then
              -- generate a packet when read data in fifo
              -- and GN4124 ready to receive the packet
              wbm_arb_req_o <= '1';

              l2p_read_cpl_current_state <= L2P_HEADER;
            end if;

          when L2P_HEADER =>

            if(arb_wbm_gnt_i = '1') then
              wbm_arb_req_o              <= '0';
              wbm_arb_data               <= s_l2p_header;
              wbm_arb_valid_o            <= '1';
              wbm_arb_dframe_o           <= '1';
              l2p_read_cpl_current_state <= L2P_DATA;
            end if;

          when L2P_DATA =>
            l2p_read_cpl_current_state <= L2P_IDLE;
            wbm_arb_data               <= from_wb_fifo_dout(31 downto 0);
            wbm_arb_dframe_o           <= '0';

          when others =>
            l2p_read_cpl_current_state <= L2P_IDLE;
            wbm_arb_req_o              <= '0';
            wbm_arb_data               <= (others => '0');
            wbm_arb_valid_o            <= '0';
            wbm_arb_dframe_o           <= '0';

        end case;
      end if;
    end if;
  end process;

  wbm_arb_data_o <= wbm_arb_data;

  -----------------------------------------------------------------------------
  -- FIFOs for transition between GN4124 core and wishbone clock domain
  -----------------------------------------------------------------------------

  -- fifo for PCIe to WB transfer
  cmp_fifo_to_wb : generic_async_fifo_dual_rst
    generic map (
      g_data_width             => 66,
      g_size                   => c_TO_WB_FIFO_SIZE,
      g_show_ahead             => false,
      g_with_rd_empty          => true,
      g_with_rd_full           => false,
      g_with_rd_almost_empty   => false,
      g_with_rd_almost_full    => false,
      g_with_rd_count          => false,
      g_with_wr_empty          => false,
      g_with_wr_full           => false,
      g_with_wr_almost_empty   => false,
      g_with_wr_almost_full    => true,
      g_with_wr_count          => false,
      g_almost_empty_threshold => 0,
      g_almost_full_threshold  => c_TO_WB_FIFO_FULL_THRES)
    port map (
      rst_wr_n_i        => fifo_rst_n,
      clk_wr_i          => clk_i,
      d_i               => to_wb_fifo_din,
      we_i              => to_wb_fifo_wr,
      wr_empty_o        => open,
      wr_full_o         => open,
      wr_almost_empty_o => open,
      wr_almost_full_o  => to_wb_fifo_full,
      wr_count_o        => open,
      rst_rd_n_i        => wb_fifo_rst_n,
      clk_rd_i          => wb_clk_i,
      q_o               => to_wb_fifo_dout,
      rd_i              => to_wb_fifo_rd,
      rd_empty_o        => to_wb_fifo_empty,
      rd_full_o         => open,
      rd_almost_empty_o => open,
      rd_almost_full_o  => open,
      rd_count_o        => open);

  to_wb_fifo_rw   <= to_wb_fifo_dout(63);
  to_wb_fifo_addr <= to_wb_fifo_dout(62 downto 32);  -- 31-bit
  to_wb_fifo_data <= to_wb_fifo_dout(31 downto 0);   -- 32-bit
  to_wb_fifo_cid  <= to_wb_fifo_dout(65 downto 64);

  -- fifo for WB to PCIe transfer
  cmp_from_wb_fifo : generic_async_fifo_dual_rst
    generic map (
      g_data_width             => 34,
      g_size                   => c_FROM_WB_FIFO_SIZE,
      g_show_ahead             => false,
      g_with_rd_empty          => true,
      g_with_rd_full           => false,
      g_with_rd_almost_empty   => false,
      g_with_rd_almost_full    => false,
      g_with_rd_count          => false,
      g_with_wr_empty          => false,
      g_with_wr_full           => false,
      g_with_wr_almost_empty   => false,
      g_with_wr_almost_full    => true,
      g_with_wr_count          => false,
      g_almost_empty_threshold => 0,
      g_almost_full_threshold  => c_FROM_WB_FIFO_FULL_THRES)
    port map (
      rst_wr_n_i        => wb_fifo_rst_n,
      clk_wr_i          => wb_clk_i,
      d_i               => from_wb_fifo_din,
      we_i              => from_wb_fifo_wr,
      wr_empty_o        => open,
      wr_full_o         => open,
      wr_almost_empty_o => open,
      wr_almost_full_o  => from_wb_fifo_full, -- not used!
      wr_count_o        => open,
      rst_rd_n_i        => fifo_rst_n,
      clk_rd_i          => clk_i,
      q_o               => from_wb_fifo_dout,
      rd_i              => from_wb_fifo_rd,
      rd_empty_o        => from_wb_fifo_empty,
      rd_full_o         => open,
      rd_almost_empty_o => open,
      rd_almost_full_o  => open,
      rd_count_o        => open);

  -----------------------------------------------------------------------------
  -- Wishbone master FSM
  -----------------------------------------------------------------------------
  p_wb_fsm : process (wb_clk_i)
  begin
    if rising_edge(wb_clk_i) then
      if wb_fifo_rst_n = '0' then
        wishbone_current_state <= WB_IDLE;
        to_wb_fifo_rd          <= '0';
        wb_cyc_t               <= '0';
        wb_stb_t               <= '0';
        wb_we_t                <= '0';
        from_wb_fifo_wr        <= '0';
      else
        case wishbone_current_state is

          when WB_IDLE =>
            -- stop writing to fifo
            from_wb_fifo_wr <= '0';
            -- clear bus
            wb_cyc_t        <= '0';
            wb_stb_t        <= '0';
            wb_sel_t        <= "0000";
            -- wait for a Wishbone cycle
            if (to_wb_fifo_empty = '0') then
              -- read request in fifo (address, data and transfer type)
              to_wb_fifo_rd          <= '1';
              wishbone_current_state <= WB_READ_FIFO;
            end if;

          when WB_READ_FIFO =>
            -- read only one request in fifo (no block transfer)
            to_wb_fifo_rd          <= '0';
            wishbone_current_state <= WB_CYCLE;

          when WB_CYCLE =>
            -- initate a bus cycle
            wb_cyc_t               <= '1';
            wb_stb_t               <= '1';
            wb_we_t                <= to_wb_fifo_rw;
            wb_sel_t               <= "1111";
            wb_adr_t               <= to_wb_fifo_addr;
            wb_cid_t               <= to_wb_fifo_cid;
            wb_dat_o_t             <= to_wb_fifo_data;
            -- wait for slave to ack
            wishbone_current_state <= WB_WAIT_ACK;

          when WB_WAIT_ACK =>
            if wb_stall_t = '0' then
              wb_stb_t <= '0';
            end if;
            if (wb_ack_t = '1') then
              -- for read cycles write read data to fifo
              if (wb_we_t = '0') then
                from_wb_fifo_din(31 downto 0)  <= wb_dat_i_t;
                from_wb_fifo_din(33 downto 32) <= wb_cid_t;
                from_wb_fifo_wr                <= '1';
              end if;
              -- end of the bus cycle
              wb_cyc_t               <= '0';
              wishbone_current_state <= WB_IDLE;
            elsif (wb_err_t = '1') or (wb_ack_timeout = '1') then
              -- e.g. When trying to access unmapped wishbone addresses,
              -- the wb crossbar asserts ERR. If ERR is not asserted when
              -- accessing un-mapped addresses, a timeout makes sure the
              -- transaction terminates.
              if (wb_we_t = '0') then
                -- dummy data as the transaction failed
                from_wb_fifo_din(31 downto 0)  <= (others => '1');
                from_wb_fifo_din(33 downto 32) <= wb_cid_t;
                from_wb_fifo_wr                <= '1';
              end if;
              -- end of the bus cycle
              wb_cyc_t               <= '0';
              wishbone_current_state <= WB_IDLE;
            end if;

          when others =>
            -- should not get here!
            wishbone_current_state <= WB_IDLE;
            wb_cyc_t               <= '0';
            wb_stb_t               <= '0';
            wb_we_t                <= '0';
            wb_sel_t               <= "0000";
            wb_dat_o_t             <= (others => '0');
            wb_adr_t               <= (others => '0');
            to_wb_fifo_rd          <= '0';
            from_wb_fifo_din       <= (others => '0');
            from_wb_fifo_wr        <= '0';

        end case;
      end if;
    end if;
  end process p_wb_fsm;

  wb_adr_o   <= wb_adr_t;
  wb_cyc_o   <= wb_cyc_t;
  wb_stb_o   <= wb_stb_t;
  wb_we_o    <= wb_we_t;
  wb_sel_o   <= wb_sel_t;
  wb_dat_i_t <= wb_dat_i;
  wb_dat_o   <= wb_dat_o_t;
  wb_ack_t   <= wb_ack_i;
  wb_stall_t <= wb_stall_i;
  wb_err_t   <= wb_err_i;

  -- ACK timeout
  p_wb_ack_timeout_cnt : process (wb_clk_i)
  begin
    if rising_edge(wb_clk_i) then
      if wb_fifo_rst_n = '0' then
        wb_ack_timeout_cnt <= (others => '1');
      else
        if wishbone_current_state = WB_WAIT_ACK then
          if wb_ack_timeout_cnt /= 0 then
            wb_ack_timeout_cnt <= wb_ack_timeout_cnt - 1;
          end if;
        else
          wb_ack_timeout_cnt <= (others => '1');
        end if;
      end if;
    end if;
  end process p_wb_ack_timeout_cnt;

  p_ack_timeout : process (wb_clk_i)
  begin
    if rising_edge(wb_clk_i) then
      if wb_fifo_rst_n = '0' then
        wb_ack_timeout <= '0';
      else
        if wb_ack_timeout_cnt = 0 then
          wb_ack_timeout <= '1';
        else
          wb_ack_timeout <= '0';
        end if;
      end if;
    end if;
  end process p_ack_timeout;

end behaviour;
