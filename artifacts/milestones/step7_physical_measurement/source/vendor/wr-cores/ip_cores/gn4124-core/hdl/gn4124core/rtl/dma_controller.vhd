--------------------------------------------------------------------------------
-- CERN BE-CO-HT
-- GN4124 core for PCIe FMC carrier
-- http://www.ohwr.org/projects/gn4124-core
--------------------------------------------------------------------------------
--
-- unit name:   dma_controller
--
-- description: Manages the DMA transfers.
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


entity dma_controller is
  port
    (
      ---------------------------------------------------------
      -- GN4124 core clock and reset
      clk_i   : in std_logic;
      rst_n_i : in std_logic;

      ---------------------------------------------------------
      -- Interrupt request
      dma_ctrl_irq_o : out std_logic_vector(1 downto 0);

      ---------------------------------------------------------
      -- To the L2P DMA master and P2L DMA master
      dma_ctrl_carrier_addr_o : out std_logic_vector(31 downto 0);
      dma_ctrl_host_addr_h_o  : out std_logic_vector(31 downto 0);
      dma_ctrl_host_addr_l_o  : out std_logic_vector(31 downto 0);
      dma_ctrl_len_o          : out std_logic_vector(31 downto 0);
      dma_ctrl_start_l2p_o    : out std_logic;  -- To the L2P DMA master
      dma_ctrl_start_p2l_o    : out std_logic;  -- To the P2L DMA master
      dma_ctrl_start_next_o   : out std_logic;  -- To the P2L DMA master
      dma_ctrl_byte_swap_o    : out std_logic_vector(1 downto 0);
      dma_ctrl_abort_o        : out std_logic;
      dma_ctrl_done_i         : in  std_logic;
      dma_ctrl_error_i        : in  std_logic;

      ---------------------------------------------------------
      -- From P2L DMA master
      next_item_carrier_addr_i : in std_logic_vector(31 downto 0);
      next_item_host_addr_h_i  : in std_logic_vector(31 downto 0);
      next_item_host_addr_l_i  : in std_logic_vector(31 downto 0);
      next_item_len_i          : in std_logic_vector(31 downto 0);
      next_item_next_l_i       : in std_logic_vector(31 downto 0);
      next_item_next_h_i       : in std_logic_vector(31 downto 0);
      next_item_attrib_i       : in std_logic_vector(31 downto 0);
      next_item_valid_i        : in std_logic;

      ---------------------------------------------------------
      -- Wishbone slave interface
      wb_rst_n_i : in  std_logic;
      wb_clk_i   : in  std_logic;                      -- Bus clock
      wb_adr_i   : in  std_logic_vector(3 downto 0);   -- Adress
      wb_dat_o   : out std_logic_vector(31 downto 0);  -- Data in
      wb_dat_i   : in  std_logic_vector(31 downto 0);  -- Data out
      wb_sel_i   : in  std_logic_vector(3 downto 0);   -- Byte select
      wb_cyc_i   : in  std_logic;                      -- Read or write cycle
      wb_stb_i   : in  std_logic;                      -- Read or write strobe
      wb_we_i    : in  std_logic;                      -- Write
      wb_ack_o   : out std_logic                       -- Acknowledge
      );
end dma_controller;


architecture behaviour of dma_controller is

  ------------------------------------------------------------------------------
  -- Constants declaration
  ------------------------------------------------------------------------------
  constant c_IDLE  : std_logic_vector(2 downto 0) := "000";
  constant c_DONE  : std_logic_vector(2 downto 0) := "001";
  constant c_BUSY  : std_logic_vector(2 downto 0) := "010";
  constant c_ERROR : std_logic_vector(2 downto 0) := "011";
  constant c_ABORT : std_logic_vector(2 downto 0) := "100";

  ------------------------------------------------------------------------------
  -- Signals declaration
  ------------------------------------------------------------------------------

  signal dma_ctrl_carrier_addr : std_logic_vector(31 downto 0) := (others => '0');
  signal dma_ctrl_host_addr_h  : std_logic_vector(31 downto 0) := (others => '0');
  signal dma_ctrl_host_addr_l  : std_logic_vector(31 downto 0) := (others => '0');
  signal dma_ctrl_len          : std_logic_vector(31 downto 0) := (others => '0');

  -- DMA controller registers
  signal dma_ctrl    : std_logic_vector(31 downto 0);
  signal dma_stat    : std_logic_vector(31 downto 0);
  signal dma_cstart  : std_logic_vector(31 downto 0);
  signal dma_hstartl : std_logic_vector(31 downto 0);
  signal dma_hstarth : std_logic_vector(31 downto 0);
  signal dma_len     : std_logic_vector(31 downto 0);
  signal dma_nextl   : std_logic_vector(31 downto 0);
  signal dma_nexth   : std_logic_vector(31 downto 0);
  signal dma_attrib  : std_logic_vector(31 downto 0);

  signal dma_ctrl_load    : std_logic;
  signal dma_stat_load    : std_logic;
  signal dma_cstart_load  : std_logic;
  signal dma_hstartl_load : std_logic;
  signal dma_hstarth_load : std_logic;
  signal dma_len_load     : std_logic;
  signal dma_nextl_load   : std_logic;
  signal dma_nexth_load   : std_logic;
  signal dma_attrib_load  : std_logic;

  signal dma_ctrl_reg    : std_logic_vector(31 downto 0);
  signal dma_stat_reg    : std_logic_vector(31 downto 0);
  signal dma_cstart_reg  : std_logic_vector(31 downto 0);
  signal dma_hstartl_reg : std_logic_vector(31 downto 0);
  signal dma_hstarth_reg : std_logic_vector(31 downto 0);
  signal dma_len_reg     : std_logic_vector(31 downto 0);
  signal dma_nextl_reg   : std_logic_vector(31 downto 0);
  signal dma_nexth_reg   : std_logic_vector(31 downto 0);
  signal dma_attrib_reg  : std_logic_vector(31 downto 0);

  -- DMA controller FSM
  type dma_ctrl_state_type is (DMA_IDLE, DMA_START_TRANSFER, DMA_TRANSFER,
                               DMA_START_CHAIN, DMA_CHAIN,
                               DMA_ERROR, DMA_ABORT);
  signal dma_ctrl_current_state : dma_ctrl_state_type;

  -- status signals
  signal dma_status    : std_logic_vector(2 downto 0);
  signal dma_error_irq : std_logic;
  signal dma_done_irq  : std_logic;


begin

  ------------------------------------------------------------------------------
  -- Wishbone slave instantiation
  ------------------------------------------------------------------------------
  dma_controller_wb_slave_0 : entity work.dma_controller_wb_slave port map (
    rst_n_i            => wb_rst_n_i,
    wb_clk_i           => wb_clk_i,
    wb_addr_i          => wb_adr_i,
    wb_data_i          => wb_dat_i,
    wb_data_o          => wb_dat_o,
    wb_cyc_i           => wb_cyc_i,
    wb_sel_i           => wb_sel_i,
    wb_stb_i           => wb_stb_i,
    wb_we_i            => wb_we_i,
    wb_ack_o           => wb_ack_o,
    clk_i              => clk_i,
    dma_ctrl_o         => dma_ctrl,
    dma_ctrl_i         => dma_ctrl_reg,
    dma_ctrl_load_o    => dma_ctrl_load,
    dma_stat_o         => open,
    dma_stat_i         => dma_stat_reg,
    dma_stat_load_o    => open,
    dma_cstart_o       => dma_cstart,
    dma_cstart_i       => dma_cstart_reg,
    dma_cstart_load_o  => dma_cstart_load,
    dma_hstartl_o      => dma_hstartl,
    dma_hstartl_i      => dma_hstartl_reg,
    dma_hstartl_load_o => dma_hstartl_load,
    dma_hstarth_o      => dma_hstarth,
    dma_hstarth_i      => dma_hstarth_reg,
    dma_hstarth_load_o => dma_hstarth_load,
    dma_len_o          => dma_len,
    dma_len_i          => dma_len_reg,
    dma_len_load_o     => dma_len_load,
    dma_nextl_o        => dma_nextl,
    dma_nextl_i        => dma_nextl_reg,
    dma_nextl_load_o   => dma_nextl_load,
    dma_nexth_o        => dma_nexth,
    dma_nexth_i        => dma_nexth_reg,
    dma_nexth_load_o   => dma_nexth_load,
    dma_attrib_o       => dma_attrib,
    dma_attrib_i       => dma_attrib_reg,
    dma_attrib_load_o  => dma_attrib_load
    );


  ------------------------------------------------------------------------------
  -- DMA controller registers
  ------------------------------------------------------------------------------
  p_regs : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if (rst_n_i = '0') then
        dma_ctrl_reg    <= (others => '0');
        dma_stat_reg    <= (others => '0');
        dma_cstart_reg  <= (others => '0');
        dma_hstartl_reg <= (others => '0');
        dma_hstarth_reg <= (others => '0');
        dma_len_reg     <= (others => '0');
        dma_nextl_reg   <= (others => '0');
        dma_nexth_reg   <= (others => '0');
        dma_attrib_reg  <= (others => '0');
      else
        -- Control register
        if (dma_ctrl_load = '1') then
          dma_ctrl_reg <= dma_ctrl;
        end if;
        -- Status register
        dma_stat_reg(2 downto 0)  <= dma_status;
        dma_stat_reg(31 downto 3) <= (others => '0');
        -- Target start address
        if (dma_cstart_load = '1') then
          dma_cstart_reg <= dma_cstart;
        end if;
        -- Host start address lowest 32-bit
        if (dma_hstartl_load = '1') then
          dma_hstartl_reg <= dma_hstartl;
        end if;
        -- Host start address highest 32-bit
        if (dma_hstarth_load = '1') then
          dma_hstarth_reg <= dma_hstarth;
        end if;
        -- DMA transfer length in byte
        if (dma_len_load = '1') then
          dma_len_reg <= dma_len;
        end if;
        -- next item address lowest 32-bit
        if (dma_nextl_load = '1') then
          dma_nextl_reg <= dma_nextl;
        end if;
        -- next item address highest 32-bit
        if (dma_nexth_load = '1') then
          dma_nexth_reg <= dma_nexth;
        end if;
        -- Chained DMA control
        if (dma_attrib_load = '1') then
          dma_attrib_reg <= dma_attrib;
        end if;
        -- next item received => start a new transfer
        if (next_item_valid_i = '1') then
          dma_ctrl_reg(0) <= '1';
          dma_cstart_reg  <= next_item_carrier_addr_i;
          dma_hstartl_reg <= next_item_host_addr_l_i;
          dma_hstarth_reg <= next_item_host_addr_h_i;
          dma_len_reg     <= next_item_len_i;
          dma_nextl_reg   <= next_item_next_l_i;
          dma_nexth_reg   <= next_item_next_h_i;
          dma_attrib_reg  <= next_item_attrib_i;
        end if;
        -- Start DMA, 1 tick pulse
        if (dma_ctrl_reg(0) = '1') then
          dma_ctrl_reg(0) <= '0';
        end if;
      end if;
    end if;
  end process p_regs;

  dma_ctrl_byte_swap_o <= dma_ctrl_reg(3 downto 2);

  ------------------------------------------------------------------------------
  -- IRQ output assignement
  ------------------------------------------------------------------------------
  dma_ctrl_irq_o <= dma_error_irq & dma_done_irq;

------------------------------------------------------------------------------
  -- DMA controller FSM
  ------------------------------------------------------------------------------
  p_fsm : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if(rst_n_i = '0') then
        dma_ctrl_current_state  <= DMA_IDLE;
        dma_ctrl_start_l2p_o    <= '0';
        dma_ctrl_start_p2l_o    <= '0';
        dma_ctrl_start_next_o   <= '0';
        dma_status              <= c_IDLE;
        dma_error_irq           <= '0';
        dma_done_irq            <= '0';
        dma_ctrl_abort_o        <= '0';
      else
        case dma_ctrl_current_state is

          when DMA_IDLE =>
            -- Clear done irq to make it 1 tick pulse
            dma_done_irq <= '0';

            if(dma_ctrl_reg(0) = '1') then
              -- Starts a new transfer
              dma_ctrl_current_state <= DMA_START_TRANSFER;
            end if;

          when DMA_START_TRANSFER =>
            -- Clear abort signal
            dma_ctrl_abort_o <= '0';

            if (unsigned(dma_len_reg(31 downto 2)) = 0) then
              -- Requesting a DMA of 0 word length gives a error
              dma_error_irq          <= '1';
              dma_ctrl_current_state <= DMA_ERROR;
            else
              -- Start the DMA if the length is not 0
              if (dma_attrib_reg(1) = '0') then
                -- L2P transfer (from target to PCIe)
                dma_ctrl_start_l2p_o <= '1';
              elsif (dma_attrib_reg(1) = '1') then
                -- P2L transfer (from PCIe to target)
                dma_ctrl_start_p2l_o <= '1';
              end if;
              dma_ctrl_current_state <= DMA_TRANSFER;
              dma_ctrl_carrier_addr  <= dma_cstart_reg;
              dma_ctrl_host_addr_h   <= dma_hstarth_reg;
              dma_ctrl_host_addr_l   <= dma_hstartl_reg;
              dma_ctrl_len           <= dma_len_reg;
              dma_status             <= c_BUSY;
            end if;

          when DMA_TRANSFER =>
            -- Clear start signals, to make them 1 tick pulses
            dma_ctrl_start_l2p_o <= '0';
            dma_ctrl_start_p2l_o <= '0';

            if (dma_ctrl_reg(1) = '1') then
              -- Transfer aborted
              dma_ctrl_current_state <= DMA_ABORT;
            elsif(dma_ctrl_error_i = '1') then
              -- An error occurs !
              dma_error_irq          <= '1';
              dma_ctrl_current_state <= DMA_ERROR;
            elsif(dma_ctrl_done_i = '1') then
              -- End of DMA transfer
              if(dma_attrib_reg(0) = '1') then
                -- More transfer in chained DMA
                dma_ctrl_current_state <= DMA_START_CHAIN;
              else
                -- Was the last transfer
                dma_status             <= c_DONE;
                dma_done_irq           <= '1';
                dma_ctrl_current_state <= DMA_IDLE;
              end if;
            end if;

          when DMA_START_CHAIN =>
            -- Catch the next item in host memory
            dma_ctrl_current_state <= DMA_CHAIN;
            dma_ctrl_host_addr_h   <= dma_nexth_reg;
            dma_ctrl_host_addr_l   <= dma_nextl_reg;
            dma_ctrl_len           <= X"0000001C";
            dma_ctrl_start_next_o  <= '1';

          when DMA_CHAIN =>
            -- Clear start next signal, to make it 1 tick pulse
            dma_ctrl_start_next_o <= '0';

            if (dma_ctrl_reg(1) = '1') then
              -- Transfer aborted
              dma_ctrl_current_state <= DMA_ABORT;
            elsif(dma_ctrl_error_i = '1') then
              -- An error occurs !
              dma_error_irq          <= '1';
              dma_ctrl_current_state <= DMA_ERROR;
            elsif (next_item_valid_i = '1') then
              -- next item received
              dma_ctrl_current_state <= DMA_START_TRANSFER;
            end if;

          when DMA_ERROR =>
            dma_status    <= c_ERROR;
            -- Clear error irq to make it 1 tick pulse
            dma_error_irq <= '0';

            if(dma_ctrl_reg(0) = '1') then
              -- Starts a new transfer
              dma_ctrl_current_state <= DMA_START_TRANSFER;
            end if;

          when DMA_ABORT =>
            dma_status       <= c_ABORT;
            dma_ctrl_abort_o <= '1';

            if(dma_ctrl_reg(0) = '1') then
              -- Starts a new transfer
              dma_ctrl_current_state <= DMA_START_TRANSFER;
            end if;

          when others =>
            dma_ctrl_current_state <= DMA_IDLE;
            dma_ctrl_carrier_addr  <= (others => '0');
            dma_ctrl_host_addr_h   <= (others => '0');
            dma_ctrl_host_addr_l   <= (others => '0');
            dma_ctrl_len           <= (others => '0');
            dma_ctrl_start_l2p_o   <= '0';
            dma_ctrl_start_p2l_o   <= '0';
            dma_ctrl_start_next_o  <= '0';
            dma_status             <= (others => '0');
            dma_error_irq          <= '0';
            dma_done_irq           <= '0';
            dma_ctrl_abort_o       <= '0';

        end case;
      end if;
    end if;
  end process p_fsm;

  dma_ctrl_carrier_addr_o  <= dma_ctrl_carrier_addr;
  dma_ctrl_host_addr_h_o   <= dma_ctrl_host_addr_h;
  dma_ctrl_host_addr_l_o   <= dma_ctrl_host_addr_l;
  dma_ctrl_len_o           <= dma_ctrl_len;

end behaviour;

