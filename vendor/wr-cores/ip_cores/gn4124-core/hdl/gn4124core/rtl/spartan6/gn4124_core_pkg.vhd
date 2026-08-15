--------------------------------------------------------------------------------
-- CERN BE-CO-HT
-- GN4124 core for PCIe FMC carrier
-- http://www.ohwr.org/projects/gn4124-core
--------------------------------------------------------------------------------
--
-- unit name:   gn4124_core_pkg
--
-- description: Package for components declaration and core wide constants.
-- Spartan6 FPGAs version.
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

--! Standard library
library IEEE;
--! Standard packages
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

--! Work library
library work;
--! Wishbone definitions from general-cores
use work.wishbone_pkg.all;

--==============================================================================
--! Package declaration
--==============================================================================
package gn4124_core_pkg is


--==============================================================================
--! Functions declaration
--==============================================================================
  function f_byte_swap (
    constant enable    : boolean;
    signal   din       : std_logic_vector(31 downto 0);
    signal   byte_swap : std_logic_vector(1 downto 0))
    return std_logic_vector;

--==============================================================================
--! Components declaration
--==============================================================================

  component xwb_gn4124_core is
    generic (
      g_WB_MASTER_MODE         : t_wishbone_interface_mode      := PIPELINED;
      g_WB_MASTER_GRANULARITY  : t_wishbone_address_granularity := BYTE;
      g_WB_DMA_CFG_MODE        : t_wishbone_interface_mode      := PIPELINED;
      g_WB_DMA_CFG_GRANULARITY : t_wishbone_address_granularity := BYTE;
      g_WB_DMA_DAT_MODE        : t_wishbone_interface_mode      := PIPELINED;
      g_WB_DMA_DAT_GRANULARITY : t_wishbone_address_granularity := BYTE;
      g_ACK_TIMEOUT            : positive                       := 100);
    port (
      rst_n_a_i          : in  std_logic;
      status_o           : out std_logic_vector(31 downto 0);
      p2l_clk_p_i        : in  std_logic;
      p2l_clk_n_i        : in  std_logic;
      p2l_data_i         : in  std_logic_vector(15 downto 0);
      p2l_dframe_i       : in  std_logic;
      p2l_valid_i        : in  std_logic;
      p2l_rdy_o          : out std_logic;
      p_wr_req_i         : in  std_logic_vector(1 downto 0);
      p_wr_rdy_o         : out std_logic_vector(1 downto 0);
      rx_error_o         : out std_logic;
      vc_rdy_i           : in  std_logic_vector(1 downto 0);
      l2p_clk_p_o        : out std_logic;
      l2p_clk_n_o        : out std_logic;
      l2p_data_o         : out std_logic_vector(15 downto 0);
      l2p_dframe_o       : out std_logic;
      l2p_valid_o        : out std_logic;
      l2p_edb_o          : out std_logic;
      l2p_rdy_i          : in  std_logic;
      l_wr_rdy_i         : in  std_logic_vector(1 downto 0);
      p_rd_d_rdy_i       : in  std_logic_vector(1 downto 0);
      tx_error_i         : in  std_logic;
      dma_irq_o          : out std_logic_vector(1 downto 0);
      irq_p_i            : in  std_logic;
      irq_p_o            : out std_logic;
      wb_master_clk_i    : in  std_logic;
      wb_master_rst_n_i  : in  std_logic;
      wb_master_i        : in  t_wishbone_master_in;
      wb_master_o        : out t_wishbone_master_out;
      wb_dma_cfg_clk_i   : in  std_logic            := '0';
      wb_dma_cfg_rst_n_i : in  std_logic            := '0';
      wb_dma_cfg_i       : in  t_wishbone_slave_in  := c_DUMMY_WB_SLAVE_IN;
      wb_dma_cfg_o       : out t_wishbone_slave_out;
      wb_dma_dat_clk_i   : in  std_logic            := '0';
      wb_dma_dat_rst_n_i : in  std_logic            := '0';
      wb_dma_dat_i       : in  t_wishbone_master_in := c_DUMMY_WB_MASTER_IN;
      wb_dma_dat_o       : out t_wishbone_master_out);
  end component xwb_gn4124_core;

-----------------------------------------------------------------------------
  component gn4124_core
    generic (
      g_ACK_TIMEOUT : positive := 100                    -- Wishbone ACK timeout (in wishbone clock cycles)
      );
    port
      (
        ---------------------------------------------------------
        -- Control and status
        rst_n_a_i : in  std_logic;                      -- Asynchronous reset from GN4124
        status_o  : out std_logic_vector(31 downto 0);  -- Core status output

        ---------------------------------------------------------
        -- P2L Direction
        --
        -- Source Sync DDR related signals
        p2l_clk_p_i  : in  std_logic;                      -- Receiver Source Synchronous Clock+
        p2l_clk_n_i  : in  std_logic;                      -- Receiver Source Synchronous Clock-
        p2l_data_i   : in  std_logic_vector(15 downto 0);  -- Parallel receive data
        p2l_dframe_i : in  std_logic;                      -- Receive Frame
        p2l_valid_i  : in  std_logic;                      -- Receive Data Valid
        -- P2L Control
        p2l_rdy_o    : out std_logic;                      -- Rx Buffer Full Flag
        p_wr_req_i   : in  std_logic_vector(1 downto 0);   -- PCIe Write Request
        p_wr_rdy_o   : out std_logic_vector(1 downto 0);   -- PCIe Write Ready
        rx_error_o   : out std_logic;                      -- Receive Error
        vc_rdy_i     : in  std_logic_vector(1 downto 0);   -- Virtual channel ready

        ---------------------------------------------------------
        -- L2P Direction
        --
        -- Source Sync DDR related signals
        l2p_clk_p_o  : out std_logic;                      -- Transmitter Source Synchronous Clock+
        l2p_clk_n_o  : out std_logic;                      -- Transmitter Source Synchronous Clock-
        l2p_data_o   : out std_logic_vector(15 downto 0);  -- Parallel transmit data
        l2p_dframe_o : out std_logic;                      -- Transmit Data Frame
        l2p_valid_o  : out std_logic;                      -- Transmit Data Valid
        -- L2P Control
        l2p_edb_o    : out std_logic;                      -- Packet termination and discard
        l2p_rdy_i    : in  std_logic;                      -- Tx Buffer Full Flag
        l_wr_rdy_i   : in  std_logic_vector(1 downto 0);   -- Local-to-PCIe Write
        p_rd_d_rdy_i : in  std_logic_vector(1 downto 0);   -- PCIe-to-Local Read Response Data Ready
        tx_error_i   : in  std_logic;                      -- Transmit Error

        ---------------------------------------------------------
        -- Interrupt interface
        dma_irq_o : out std_logic_vector(1 downto 0);  -- Interrupts sources to IRQ manager
        irq_p_i   : in  std_logic;                     -- Interrupt request pulse from IRQ manager
        irq_p_o   : out std_logic;                     -- Interrupt request pulse to GN4124 GPIO

        ---------------------------------------------------------
        -- DMA registers wishbone interface (slave classic)
        dma_reg_rst_n_i : in  std_logic := '1';
        dma_reg_clk_i   : in  std_logic := '0';
        dma_reg_adr_i   : in  std_logic_vector(31 downto 0) := x"00000000";
        dma_reg_dat_i   : in  std_logic_vector(31 downto 0) := x"00000000";
        dma_reg_sel_i   : in  std_logic_vector(3 downto 0) := x"0";
        dma_reg_stb_i   : in  std_logic := '0';
        dma_reg_we_i    : in  std_logic := '0';
        dma_reg_cyc_i   : in  std_logic := '0';
        dma_reg_dat_o   : out std_logic_vector(31 downto 0);
        dma_reg_ack_o   : out std_logic;
        dma_reg_stall_o : out std_logic;

        ---------------------------------------------------------
        -- CSR wishbone interface (master pipelined)
        csr_rst_n_i : in  std_logic;
        csr_clk_i   : in  std_logic;
        csr_adr_o   : out std_logic_vector(31 downto 0);
        csr_dat_o   : out std_logic_vector(31 downto 0);
        csr_sel_o   : out std_logic_vector(3 downto 0);
        csr_stb_o   : out std_logic;
        csr_we_o    : out std_logic;
        csr_cyc_o   : out std_logic;
        csr_dat_i   : in  std_logic_vector(31 downto 0);
        csr_ack_i   : in  std_logic;
        csr_stall_i : in  std_logic;
        csr_err_i   : in  std_logic := '0';
        csr_rty_i   : in  std_logic := '0';

        ---------------------------------------------------------
        -- DMA wishbone interface (master pipelined)
        dma_rst_n_i : in  std_logic := '1';
        dma_clk_i   : in  std_logic := '0';
        dma_adr_o   : out std_logic_vector(31 downto 0);
        dma_dat_o   : out std_logic_vector(31 downto 0);
        dma_sel_o   : out std_logic_vector(3 downto 0);
        dma_stb_o   : out std_logic;
        dma_we_o    : out std_logic;
        dma_cyc_o   : out std_logic;
        dma_dat_i   : in  std_logic_vector(31 downto 0) := x"00000000";
        dma_ack_i   : in  std_logic := '0';
        dma_stall_i : in  std_logic := '0';
        dma_err_i   : in  std_logic := '0';
        dma_rty_i   : in  std_logic := '0'
        );
  end component gn4124_core;

end gn4124_core_pkg;

package body gn4124_core_pkg is

  -----------------------------------------------------------------------------
  -- Byte swap function
  --
  -- enable | byte_swap | din  | dout
  -- false  | XX        | ABCD | ABCD
  -- true   | 00        | ABCD | ABCD
  -- true   | 01        | ABCD | BADC
  -- true   | 10        | ABCD | CDAB
  -- true   | 11        | ABCD | DCBA
  -----------------------------------------------------------------------------
  function f_byte_swap (
    constant enable    : boolean;
    signal   din       : std_logic_vector(31 downto 0);
    signal   byte_swap : std_logic_vector(1 downto 0))
    return std_logic_vector is
    variable dout : std_logic_vector(31 downto 0) := din;
  begin
    if (enable = true) then
      case byte_swap is
        when "00" =>
          dout := din;
        when "01" =>
          dout := din(23 downto 16)
                  & din(31 downto 24)
                  & din(7 downto 0)
                  & din(15 downto 8);
        when "10" =>
          dout := din(15 downto 0)
                  & din(31 downto 16);
        when "11" =>
          dout := din(7 downto 0)
                  & din(15 downto 8)
                  & din(23 downto 16)
                  & din(31 downto 24);
        when others =>
          dout := din;
      end case;
    else
      dout := din;
    end if;
    return dout;
  end function f_byte_swap;

end gn4124_core_pkg;
