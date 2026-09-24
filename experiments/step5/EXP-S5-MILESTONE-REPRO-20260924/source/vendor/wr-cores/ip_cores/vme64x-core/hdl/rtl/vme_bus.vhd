--------------------------------------------------------------------------------
-- CERN (BE-CO-HT)
-- VME64x Core
-- http://www.ohwr.org/projects/vme64x-core
--------------------------------------------------------------------------------
--
-- unit name:     VME_bus
--
-- description:
--
--   This block acts as interface between the VMEbus and the CR/CSR space or
--   WB bus.
--
--------------------------------------------------------------------------------
-- GNU LESSER GENERAL PUBLIC LICENSE
--------------------------------------------------------------------------------
-- This source file is free software; you can redistribute it and/or modify it
-- under the terms of the GNU Lesser General Public License as published by the
-- Free Software Foundation; either version 2.1 of the License, or (at your
-- option) any later version. This source is distributed in the hope that it
-- will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty
-- of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU Lesser General Public License for more details. You should have
-- received a copy of the GNU Lesser General Public License along with this
-- source; if not, download it from http://www.gnu.org/licenses/lgpl-2.1.html
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.vme64x_pkg.all;
use work.wishbone_pkg.all;
use work.gencores_pkg.all;

entity vme_bus is
  generic (
    g_CLOCK_PERIOD    : integer;
    g_VME32           : boolean;
    g_VME_2E          : boolean;
    g_WB_GRANULARITY  : t_wishbone_address_granularity;
    g_WB_MODE         : t_wishbone_interface_mode
  );
  port (
    clk_i           : in  std_logic;
    rst_n_i         : in  std_logic;

    -- VME signals
    vme_as_n_i      : in  std_logic;
    vme_lword_n_o   : out std_logic := '0';
    vme_lword_n_i   : in  std_logic;
    vme_retry_n_o   : out std_logic;
    vme_retry_oe_o  : out std_logic;
    vme_write_n_i   : in  std_logic;
    vme_ds_n_i      : in  std_logic_vector(1 downto 0);
    vme_nsync_ds_n_i : in  std_logic_vector(1 downto 0);  --  Not synch.
    vme_dtack_n_o   : out std_logic;
    vme_dtack_oe_o  : out std_logic;
    vme_berr_n_o    : out std_logic;
    vme_addr_i      : in  std_logic_vector(31 downto 1);
    vme_addr_o      : out std_logic_vector(31 downto 1) := (others => '0');
    vme_addr_dir_o  : out std_logic;
    vme_addr_oe_n_o : out std_logic;
    vme_data_i      : in  std_logic_vector(31 downto 0);
    vme_data_o      : out std_logic_vector(31 downto 0) := (others => '0');
    vme_data_dir_o  : out std_logic;
    vme_data_oe_n_o : out std_logic;
    vme_am_i        : in  std_logic_vector(5 downto 0);
    vme_iackin_n_i  : in  std_logic;
    vme_iack_n_i    : in  std_logic;
    vme_iackout_n_o : out std_logic;

    --  Setup and hold times for dtack (in number of cycles).
    --  [3:0] is the hold time for 160MB/s
    --  [7:4]        setup
    --  [11:8]       hold          266MB/s
    --  [15:12]      setup
    --  [19:16]      hold          320MB/s
    --  [23:20]      setup
    data_timing     : in  std_logic_vector(23 downto 0) := x"21_12_22";

    -- WB signals
    wb_stb_o        : out std_logic;
    wb_ack_i        : in  std_logic;
    wb_dat_o        : out std_logic_vector(31 downto 0);
    wb_dat_i        : in  std_logic_vector(31 downto 0);
    wb_adr_o        : out std_logic_vector(31 downto 0);
    wb_sel_o        : out std_logic_vector(3 downto 0);
    wb_we_o         : out std_logic;
    wb_cyc_o        : out std_logic;
    wb_err_i        : in  std_logic;
    wb_stall_i      : in  std_logic;

    -- Function decoder
    addr_decoder_i  : in  std_logic_vector(31 downto 1);
    addr_decoder_o  : out std_logic_vector(31 downto 1);
    decode_start_o  : out std_logic;
    decode_done_i   : in std_logic;
    am_o            : out std_logic_vector( 5 downto 0);
    decode_sel_i    : in  std_logic;

    -- CR/CSR space signals:
    cr_csr_addr_o   : out std_logic_vector(18 downto 2);
    cr_csr_data_i   : in  std_logic_vector( 7 downto 0);
    cr_csr_data_o   : out std_logic_vector( 7 downto 0);
    cr_csr_we_o     : out std_logic;
    module_enable_i : in  std_logic;
    bar_i           : in  std_logic_vector( 4 downto 0);

    -- Interrupts
    int_level_i     : in  std_logic_vector( 2 downto 0);
    int_vector_i    : in  std_logic_vector( 7 downto 0);
    irq_pending_i   : in  std_logic;
    irq_ack_o       : out std_logic;
    
    --Card selection
    card_sel_o      : out std_logic
  );
end vme_bus;

architecture rtl of vme_bus is
  -- VME latched signals - corresponds to the input dff in the pad.
  --  latched at the rising edge of /AS:
  signal vme_idff_addr              : std_logic_vector(31 downto 1);
  signal vme_idff_data              : std_logic_vector(31 downto 0);
  signal vme_idff_lword_n           : std_logic;
  signal vme_idff_am                : std_logic_vector(5 downto 0);

  --  As these signals are synchronized, they correspond to latched values.
  signal vme_idff_ds_n              : std_logic_vector(1 downto 0);
  signal vme_idff_write_n           : std_logic;

  -- Address and data from the VME bus.  There are two registers so that the
  -- first one can be placed in the IOBs.
  signal vme_odff_addr             : std_logic_vector(31 downto 1);
  signal vme_odff_data             : std_logic_vector(31 downto 0);
  signal vme_odff_lword_n          : std_logic;
  signal vme_odff_addr_dir         : std_logic;
  signal vme_odff_data_dir         : std_logic;

  signal vme_odff_dtack_n          : std_logic;
  signal vme_odff_dtack_oe         : std_logic;

  signal vme_odff_retry_n          : std_logic;
  signal vme_odff_retry_oe         : std_logic;

  signal vme_cycles                : unsigned (7 downto 0);

  --  If set, dtack is controled directly from ds.
  --  Otherwise, it is controled by vme_odff_dtack_n.
  signal vme_dtack_async_ctrl      : std_logic;

  --  Register containing the address.  Initialized from VME, adjusted
  --  by address decoder, and incremented during DMA.
  signal addr_reg                  : std_logic_vector(31 downto 0);

  --  Load addr_reg from vme idff (for address phase1 and 2).
  signal load_addr_reg_phase1        : std_logic;
  signal load_addr_reg_phase2        : std_logic;

  --  Data register, owned by the WB fsm.
  signal data_reg                 : std_logic_vector(63 downto 0);

  type t_transferType is (
    SINGLE,
    BLT,
    MBLT,
    VME2e,
    TFR_ERROR
  );

  -- Addressing type (depending on vme_am_i)
  signal s_transferType             : t_transferType;

  type t_mainFSMstates is (
    -- Wait until AS is asserted.
    IDLE,

    -- Reformat address according to AM.
    REFORMAT_ADDRESS,

    -- Decoding ADDR and AM (selecting card or conf).
    DECODE_ACCESS,

    -- Wait until DS is asserted.
    WAIT_FOR_DS,

    -- Wait until DS is stable (and asserted).
    LATCH_DS,

    -- Decode DS, generate WB request
    CHECK_TRANSFER_TYPE,

    -- For read cycle, put data on the bus
    DATA_TO_BUS,

    -- Assert DTACK
    DTACK_LOW,

    --  2eVME address phase 2 and 3
    APHASE_2,
    APHASE_3,

    VME_2E_TURN,

    --  2eVME/2eSST DATA
    VME_2E_DATA,
    VME_2E_SETUP,
    VME_2E_DTACK,
    VME_2E_DONE,

    -- Check if IACK is for this slave
    IRQ_CHECK,

    -- Pass IACKIN to IACKOUT
    IRQ_PASS,

    --  Wait until AS is deasserted
    WAIT_END
  );

  -- Main FSM signals
  signal s_mainFSMstate             : t_mainFSMstates;
  signal s_conf_req                 : std_logic;   -- Global memory request
  signal s_MBLT_Data                : std_logic;   -- for MBLT: '1' in Addr

  signal s_2e_dtack                 : std_logic;

  -- Access decode signals
  signal s_conf_sel                 : std_logic;   -- CR or CSR is addressed
  signal s_card_sel                 : std_logic;   -- WB memory is addressed
  signal s_irq_sel                  : std_logic;   -- IACK transaction

  signal s_err                      : std_logic;

  -- Stall status.  Set to one until wb_stall_i is cleared.
  signal s_stall                    : std_logic;

  -- Calculate the number of LATCH DS states necessary to match the timing
  -- rule 2.39 page 113 VMEbus specification ANSI/IEEE STD1014-1987.
  -- (max skew for the slave is 20 ns)
  constant c_num_latchDS            : natural range 1 to 8 :=
    (20 + g_CLOCK_PERIOD - 1) / g_CLOCK_PERIOD;

  signal s_DS_latch_count           : unsigned (2 downto 0);

  signal s_setup : unsigned(3 downto 0);
  signal s_sst_timing : std_logic_vector(7 downto 0);

  -- WB FSM states
  type t_WBFSMstates is (
	  -- Wait until the Main FSM issues a WB cycle.
    IDLE,

    -- Wait for WB reply
    MEMORY_REQ,

    -- Negate STB between half MBLT transactions
    MEMORY_PAUSE
  );

  -- WB FSM signals
  signal s_WBFSMstate		: t_WBFSMstates;

  -- Synch signals for MAIN FSM and WB FSM
  signal s_wb_done              : std_logic;
  signal s_wb_start             : std_logic;

  --  Set if the next WB access will cross boundary for BLT/MBLT
  --  transfer.  It will prevent from doing the next transfer.
  signal s_cross_boundary : std_logic;

  signal s_wb_dataphase 	: std_logic;
begin
  -- These output signals are connected to the buffers on the board
  -- SN74VMEH22501A Function table:  (A is fpga, B is VME connector)
  --   OEn | DIR | OUTPUT                 OEAB   |   OEBYn   |   OUTPUT
  --    H  |  X  |   Z                      L    |     H     |     Z
  --    L  |  H  | A to B                   H    |     H     |   A to B
  --    L  |  L  | B to A                   L    |     L     |   B to Y
  --                                        H    |     L     |A to B, B to Y |

  vme_data_oe_n_o <= '0'; -- Driven IFF DIR = 1
  vme_addr_oe_n_o <= '0'; -- Driven IFF DIR = 1

  ------------------------------------------------------------------------------
  -- Access Mode Decoders
  ------------------------------------------------------------------------------
  -- Type of data transfer decoder
  -- VME64 ANSI/VITA 1-1994...Table 2-2 "Signal levels during data transfers"

  -- Bytes position on VMEbus:
  --
  -- A24-31 | A16-23 | A08-15 | A00-07 | D24-31 | D16-23 | D08-15 | D00-07
  --        |        |        |        |        |        | BYTE 0 |
  --        |        |        |        |        |        |        | BYTE 1
  --        |        |        |        |        |        | BYTE 2 |
  --        |        |        |        |        |        |        | BYTE 3
  --        |        |        |        |        |        | BYTE 0 | BYTE 1
  --        |        |        |        |        |        | BYTE 2 | BYTE 3
  --        |        |        |        | BYTE 0 | BYTE 1 | BYTE 2 | BYTE 3
  -- BYTE 0 | BYTE 1 | BYTE 2 | BYTE 3 | BYTE 4 | BYTE 5 | BYTE 6 | BYTE 7

    ------------------------------------------------------------------------------
  -- MAIN FSM
  ------------------------------------------------------------------------------
  p_VMEmainFSM : process (clk_i) is
  begin
    if rising_edge(clk_i) then
      if rst_n_i = '0' or vme_as_n_i = '1' then
        -- FSM reset after power up,
        -- software reset, manually reset,
        -- on rising edge of AS.
        s_conf_req       <= '0';
        decode_start_o   <= '0';

        -- VME
        vme_odff_dtack_oe <= '0';
        vme_odff_dtack_n  <= '1';
        vme_dtack_async_ctrl <= '0';
        vme_odff_retry_oe <= '0';
        vme_odff_retry_n <= '1';
        vme_odff_data_dir <= '0';
        vme_odff_addr_dir <= '0';
        vme_odff_lword_n  <= '0';
        vme_berr_n_o      <= '1';
        vme_iackout_n_o   <= '1';
        s_MBLT_Data       <= '0';
        s_mainFSMstate    <= IDLE;

        -- WB
        s_wb_start	 <= '0';

        vme_idff_addr    <= (others => '0');
        vme_idff_am      <= (others => '0');

        vme_odff_addr   <= (others => '0');

        load_addr_reg_phase1 <= '0';
        load_addr_reg_phase2 <= '0';

        s_transferType <= TFR_ERROR;

        s_card_sel <= '0';
        s_conf_sel <= '0';
        s_irq_sel  <= '0';
        irq_ack_o  <= '0';
      else
        s_conf_req       <= '0';
        decode_start_o   <= '0';
        vme_odff_dtack_oe <= '0';
        vme_odff_dtack_n <= '1';
        vme_odff_retry_oe <= '0';
        vme_odff_retry_n <= '1';
        vme_dtack_async_ctrl <= '0';
        vme_berr_n_o     <= '1';
        vme_iackout_n_o  <= '1';
        irq_ack_o        <= '0';

        load_addr_reg_phase1 <= '0';
        load_addr_reg_phase2 <= '0';
        s_wb_start	 <= '0';

        case s_mainFSMstate is

          when IDLE =>
            -- Can only be here if vme_as_n_i has fallen to 0, which starts a
            -- cycle.
            assert vme_as_n_i = '0';

            --  Data and address are inputs
            vme_odff_data_dir <= '0';
            vme_odff_addr_dir <= '0';

            -- Store ADDR, AM and LWORD
            vme_idff_addr    <= vme_addr_i;
            vme_idff_lword_n <= vme_lword_n_i;
            vme_idff_am      <= vme_am_i;

            s_transferType <= TFR_ERROR;


            if vme_iack_n_i = '0' then
              -- IACK cycle.
              s_mainFSMstate <= IRQ_CHECK;
            elsif s_WBFSMstate /= IDLE then
              -- Not yet read.
              null;
            else
              --  Address will be put to addr_reg.
              load_addr_reg_phase1 <= '1';
              -- ANSI/VITA 1-1994 Rule 2.11
              -- Slaves MUST NOT respond to DTB cycles when IACK* is low.
              s_mainFSMstate <= REFORMAT_ADDRESS;
            end if;

          when REFORMAT_ADDRESS =>
            -- Address is not yet decoded.
            s_card_sel <= '0';
            s_conf_sel <= '0';
            s_irq_sel <= '0';

            -- Address modifier decoder
            case vme_idff_am is
              when c_AM_A24_BLT | c_AM_A24_BLT_SUP =>
                s_transferType <= BLT;
              when c_AM_A24_MBLT | c_AM_A24_MBLT_SUP =>
                s_transferType <= MBLT;
              when c_AM_CR_CSR =>
                s_transferType <= SINGLE;
              when c_AM_A16 | c_AM_A16_SUP
                  | c_AM_A24_SUP | c_AM_A24
                  | c_AM_A32 | c_AM_A32_SUP =>
                s_transferType <= SINGLE;
              when c_AM_A32_BLT | c_AM_A32_BLT_SUP =>
                s_transferType <= BLT;
              when c_AM_A32_MBLT | c_AM_A32_MBLT_SUP =>
                s_transferType <= MBLT;
              when c_AM_2EVME_6U =>
                s_transferType <= VME2E;
              when others =>
                s_transferType <= TFR_ERROR;
            end case;

            --  DS latch counter
            s_DS_latch_count <= to_unsigned (c_num_latchDS, 3);

            --  ANSI/VITA 1-1994 Rule 2.6
            --  A Slave MUST NOT respond with a falling edge on DTACK* during
            --  an unaligned transfer cycle, if it does not have UAT
            --  capability.
            if vme_idff_lword_n = '0' and vme_idff_addr(1) = '1' then
              -- unaligned.
              s_mainFSMstate <= WAIT_END;
            elsif g_VME32 = False and vme_idff_lword_n = '0' then
              -- No 32bit access on VME16.
              s_mainFSMstate <= WAIT_END;
            else
              if vme_idff_addr(23 downto 19) = bar_i
                and vme_idff_am = c_AM_CR_CSR
              then
                -- conf_sel = '1' it means CR/CSR space addressed
                s_conf_sel <= '1';
                s_mainFSMstate <= WAIT_FOR_DS;
              else
                s_mainFSMstate <= DECODE_ACCESS;
                decode_start_o  <= '1';
              end if;
            end if;

          when DECODE_ACCESS =>
            -- Check if this slave board is addressed.

            -- Wait for DS in parallel.
            if vme_ds_n_i /= "11" then
              vme_idff_write_n <= vme_write_n_i;
              if s_DS_latch_count /= 0 then
                s_DS_latch_count <= s_DS_latch_count - 1;
              end if;
            end if;

            if decode_done_i = '1' then
              if decode_sel_i = '1' and module_enable_i = '1' then
                -- card_sel = '1' it means WB application addressed
                s_card_sel <= '1';

                if vme_ds_n_i = "11" then
                  --  Still have to wait for DS...
                  s_mainFSMstate <= WAIT_FOR_DS;
                else
                  s_mainFSMstate <= LATCH_DS;
                end if;
              else
                -- Another board will answer; wait here for the rising edge of
                -- vme_as_i (done by top if).
                s_mainFSMstate <= WAIT_END;
              end if;
            else
              -- Not yet decoded.
              s_mainFSMstate <= DECODE_ACCESS;
            end if;

          when WAIT_FOR_DS =>
            -- wait until DS /= "11"
            -- Note: before entering this state, s_DS_latch_count must be set.
            vme_odff_dtack_oe <= '1';
            vme_odff_dtack_n  <= '1';

            if s_transferType = MBLT
              and s_MBLT_Data = '1'
              and vme_idff_write_n = '1'
              and s_wb_done = '1'
            then
              --  Next data read transfer.
              --  Improve speed by putting data on the VME bus.
              vme_odff_addr_dir  <= '1';
              vme_odff_data_dir  <= '1';

              if s_setup = 0 then
                -- Do not assert dtack before setup cycles.
                vme_dtack_async_ctrl <= '1';
              else
                s_setup <= s_setup - 1;
              end if;

              vme_odff_addr    <= data_reg(63 downto 33);
              vme_odff_lword_n <= data_reg(32);
              vme_odff_data    <= data_reg(31 downto 0);
            end if;

            if vme_ds_n_i /= "11" then
              -- ANSI/VITA 1-1994 Table 4-1
              -- For interrupts ack, the handler MUST NOT drive WRITE* low

              --  Sample write.  It must be stable before DS.
              vme_idff_write_n <= vme_write_n_i;

              if s_DS_latch_count /= 0 then
                s_DS_latch_count <= s_DS_latch_count - 1;
              end if;

              if s_transferType = MBLT
                and s_MBLT_Data = '1'
                and vme_idff_write_n = '1'
              then
                --  Next data read transfer.
                --  Improve speed.
                vme_odff_addr_dir  <= '1';
                vme_odff_data_dir  <= '1';

                if s_wb_done = '1' and s_setup = 0 then
                  --  Prefetch.
                  s_wb_start <= '1';

                  --  Already assert dtack (assume that data have been on the
                  --  vme bus for at least one cycle).
                  vme_odff_dtack_oe <= '1';
                  vme_odff_dtack_n  <= s_err;
                  vme_dtack_async_ctrl <= '0';

                  s_mainFSMstate <= DTACK_LOW;
                else
                  s_mainFSMstate <= DATA_TO_BUS;
                end if;
              else
                s_mainFSMstate <= LATCH_DS;
              end if;
            else
              s_mainFSMstate <= WAIT_FOR_DS;
            end if;

          when LATCH_DS =>
            -- At least one DS line is asserted.  Wait a little bit to check
            -- if both are asserted or not.
            -- This state is necessary indeed the VME master can assert the
            -- DS lines not at the same time.
            vme_odff_dtack_oe <= '1';
            vme_odff_dtack_n  <= '1';

            -- ANSI/VITA 1-1994 Rule 2.53a
            -- During all read cycles [...], the responding slave MUST NOT
            -- drive the D[] lines until DSA* goes low.
            vme_odff_data_dir  <= vme_idff_write_n;

            if s_DS_latch_count = 0 or s_transferType = MBLT then
              -- Read DS (which is delayed to avoid metastability).
              vme_idff_ds_n  <= vme_ds_n_i;

              -- Read DATA (which are stable)
              vme_idff_addr    <= vme_addr_i;
              vme_idff_lword_n <= vme_lword_n_i;
              vme_idff_data    <= vme_data_i;

              if s_irq_sel = '1' then
                s_mainFSMstate <= DATA_TO_BUS;
              elsif s_transferType = MBLT and s_MBLT_Data = '0' then
                -- MBLT: ack address.
                -- (Data are also read but discarded).
                s_mainFSMstate <= DTACK_LOW;

                if vme_idff_write_n = '1' then
                  --  Can fetch the first data. Cannot be done before
                  --  because we need to know that this is a read access.
                  s_wb_start <= '1';
                end if;
              elsif g_VME_2E and s_transferType = VME2e then
                if vme_idff_write_n = '0' then
                  --  Only read transfers are supported.
                  s_mainFSMstate <= WAIT_END;
                else
                  --  Assert /dtack
                  vme_odff_dtack_n <= '0';

                  s_mainFSMstate <= APHASE_2;
                end if;
              else
                s_mainFSMstate <= CHECK_TRANSFER_TYPE;
                -- For every single access or every access at MBLT WRITE
                if not (s_transferType = MBLT and vme_idff_write_n = '1') then
                  s_wb_start <= '1';
                end if;
              end if;
            else
              s_mainFSMstate   <= LATCH_DS;
              s_DS_latch_count <= s_DS_latch_count - 1;
            end if;

          when CHECK_TRANSFER_TYPE =>
            vme_odff_dtack_oe <= '1';
            vme_odff_dtack_n  <= '1';
            vme_odff_data_dir <= vme_idff_write_n;

            --  vme_addr is an output during MBLT *read* data transfer.
            if s_transferType = MBLT and vme_idff_write_n = '1' and g_VME32 then
              vme_odff_addr_dir  <= '1';
            else
              vme_odff_addr_dir  <= '0';
            end if;

            --  ANSI/VITA 1-1994 Rule 2.6
            --  A Slave MUST NOT respond with a falling edge on DTACK* during
            --  an unaligned transfer cycle, if it does not have UAT
            --  capability.
            if vme_idff_lword_n = '0' and vme_idff_ds_n /= "00" then
              -- unaligned.
              s_mainFSMstate <= WAIT_END;
            else
              s_mainFSMstate <= DATA_TO_BUS;
              s_conf_req <= s_conf_sel;
            end if;

          when DATA_TO_BUS =>
            -- Update what WB FSM prepared
            vme_odff_dtack_oe <= '1';
            vme_odff_dtack_n  <= '1';

            if s_conf_sel = '1' or s_wb_done = '1' or s_irq_sel = '1' then
              vme_odff_data_dir   <= vme_idff_write_n;

              --  Put data (only enabled on read.)
              if g_VME32 then
                --  only for MBLT
                vme_odff_addr <= data_reg(63 downto 33);
                vme_odff_lword_n <= data_reg(32);
              end if;
              vme_odff_data    <= data_reg(31 downto 0);

              if s_transferType = MBLT and vme_idff_write_n = '1' then
                --  Prefetch.
                s_wb_start <= '1';
              end if;

              -- ANSI/VITA 1-1994 Rule 2.54a
              -- During all read cycles, the responding Slave MUST NOT drive
              -- DTACK* low before it drives D[].
              s_mainFSMstate   <= DTACK_LOW;
            end if;

          when DTACK_LOW =>
            --  Set /DTACK, wait until /DS[1:0] are released.
            vme_odff_dtack_oe  <= '1';
            vme_odff_dtack_n   <= '1';
            vme_odff_data_dir  <= vme_idff_write_n;

            -- Set DTACK (or retry or berr)
            if s_card_sel = '1' and s_err = '1' then
              vme_berr_n_o  <= '0';
            else
              vme_odff_dtack_n <= '0';

              if vme_idff_write_n = '1'
                and g_VME32 and s_transferType = MBLT
              then
                --  Early release for MBLT.
                vme_dtack_async_ctrl <= '1';
              end if;
            end if;

            -- ANSI/VITA 1-1994 Rule 2.57
            -- Once the responding Slave has driven DTACK* or BERR* low, it
            -- MUST NOT release them or drive DTACK* high until it detects
            -- both DS0* and DS1* high.
            if vme_ds_n_i = "11" then
              vme_berr_n_o    <= '1';

              -- Rescind DTACK.
              vme_odff_dtack_n <= '1';

              --  DS latch counter
              s_DS_latch_count <= to_unsigned (c_num_latchDS, 3);

              if s_irq_sel = '1' then
                s_mainFSMstate <= WAIT_END;
              elsif s_transferType = SINGLE then
                --  Cycle should be finished, but allow another access at
                --  the same address (RMW).
                s_mainFSMstate <= WAIT_FOR_DS;

                --  Data and address as input.
                vme_odff_data_dir <= '0';
                vme_odff_addr_dir <= '0';
              else
                --  Any block transfer.
                if g_VME32 and s_transferType = MBLT then
                  -- MBLT: end of address phase.
                  s_MBLT_Data <= '1';
                end if;

                --  Load the setup counter.
                s_setup <= unsigned (data_timing(7 downto 4));

                --  Keep same direction for data and address.
                s_mainFSMstate <= WAIT_FOR_DS;
              end if;
            else
              s_mainFSMstate <= DTACK_LOW;
            end if;

          when APHASE_2 =>
            --  Address phase 2; wait until DS0 is 1.
            vme_odff_dtack_oe  <= '1';
            vme_odff_dtack_n   <= '0';
            vme_odff_data_dir  <= '0';
            vme_odff_addr_dir  <= '0';

            if vme_ds_n_i = "11" then
              vme_idff_addr    <= vme_addr_i;
              vme_idff_lword_n <= vme_lword_n_i;
              vme_idff_data    <= vme_data_i;

              load_addr_reg_phase2 <= '1';
              s_wb_start <= '1';

              vme_odff_dtack_n   <= '1';
              s_mainFSMstate <= APHASE_3;
            end if;

          when APHASE_3 =>
            vme_odff_dtack_oe  <= '1';
            vme_odff_dtack_n   <= '1';
            vme_odff_data_dir  <= '0';
            vme_odff_addr_dir  <= '0';

            vme_cycles <= unsigned (vme_idff_addr (15 downto 8));
            case vme_idff_data(1 downto 0) is
              when "10" =>
                --  2eSST-320
                s_sst_timing <= data_timing(23 downto 16);
              when "01" =>
                --  2eSST-267
                s_sst_timing <= data_timing(15 downto 8);
              when others =>
                s_sst_timing <= data_timing(7 downto 0);
            end case;

            if vme_ds_n_i = "10" and s_wb_done = '1' then
              s_mainFSMstate <= VME_2E_TURN;
            end if;

          when VME_2E_TURN =>
            --  Wait until DS1 = 0
            vme_odff_dtack_oe  <= '1';
            vme_odff_dtack_n   <= '0';
            vme_odff_data_dir  <= '0';
            vme_odff_addr_dir  <= '0';
            if vme_ds_n_i = "00" and s_wb_done = '1' then
              vme_odff_dtack_n   <= '0';
              s_2e_dtack <= '0';

              --  Load the setup counter.
              s_setup <= unsigned (s_sst_timing(7 downto 4));

              --  Prefetch
              s_wb_start <= '1';

              s_mainFSMstate <= VME_2E_DATA;
            end if;

          when VME_2E_DATA | VME_2E_SETUP =>
            --  Setup: drive data and wait.
            vme_odff_dtack_oe  <= '1';
            vme_odff_dtack_n   <= s_2e_dtack;
            vme_odff_data_dir  <= '1';
            vme_odff_addr_dir  <= '1';

            if s_mainFSMstate = VME_2E_DATA then
              vme_odff_addr    <= data_reg(63 downto 33);
              vme_odff_lword_n <= data_reg(32);
              vme_odff_data    <= data_reg(31 downto 0);
            end if;

            if s_setup = 0 then
              --  End of setup: will flip dtack.
              s_mainFSMstate <= VME_2E_DTACK;
              --  Load the hold counter.
              s_setup <= unsigned (s_sst_timing(3 downto 0));
              s_2e_dtack <= not s_2e_dtack;
            else
              s_setup <= s_setup - 1;
              s_mainFSMstate <= VME_2E_SETUP;
            end if;

          when VME_2E_DTACK =>
            --  Drives new dtack.
            vme_odff_dtack_oe  <= '1';
            vme_odff_dtack_n   <= s_2e_dtack;
            vme_odff_data_dir  <= '1';
            vme_odff_addr_dir  <= '1';

            if s_setup = 0 then
              if s_2e_dtack = '0' and vme_cycles = 1 then
                --  That was the last transfer.
                vme_berr_n_o <= '0';
                vme_odff_retry_n <= '0';
                vme_odff_retry_oe <= '1';
                s_mainFSMstate <= VME_2E_DONE;
              elsif s_wb_done = '1' then
                s_mainFSMstate <= VME_2E_DATA;

                --  Prefetch
                s_wb_start <= '1';

                --  Load the setup counter.
                s_setup <= unsigned (s_sst_timing(7 downto 4));
                if s_2e_dtack = '0' then
                  vme_cycles <= vme_cycles - 1;
                end if;
              end if;
            else
              s_setup <= s_setup - 1;
              s_mainFSMstate <= VME_2E_DTACK;
            end if;

          when VME_2E_DONE =>
            --  Release DATA and ADDR.
            vme_odff_data_dir <= '0';
            vme_odff_addr_dir <= '0';

            --  Drive dtack
            vme_odff_dtack_oe  <= '1';
            vme_odff_dtack_n   <= s_2e_dtack;

            --  Assert BERR and RESP...
            vme_berr_n_o <= '0';
            vme_odff_retry_n <= '0';
            vme_odff_retry_oe <= '1';

            --  Until DS is released.
            if vme_ds_n_i /= "00" then
              vme_berr_n_o <= '1';
              vme_odff_retry_n <= '1';
              vme_odff_retry_oe <= '0';

              s_mainFSMstate <= WAIT_END;
            end if;

          when IRQ_CHECK =>
            if vme_iackin_n_i = '0' then
              if vme_idff_addr(3 downto 1) = int_level_i
                and irq_pending_i = '1'
              then
                -- That's for us
                s_wb_start <= '1';
                s_irq_sel <= '1';
                irq_ack_o <= '1';

                s_mainFSMstate <= WAIT_FOR_DS;
              else
                -- Pass
                vme_iackout_n_o <= '0';
                s_mainFSMstate <= IRQ_PASS;
              end if;
            else
              s_mainFSMstate <= IRQ_CHECK;
            end if;

          when IRQ_PASS =>
            -- Will stay here until AS is released.
            vme_iackout_n_o <= '0';
            s_mainFSMstate <= IRQ_PASS;

          when WAIT_END =>
            -- Will stay here until AS is released.

            vme_odff_data_dir <= '0';
            vme_odff_addr_dir <= '0';

            s_mainFSMstate <= WAIT_END;

          when others =>
            -- No-op, wait until AS is released.
            s_mainFSMstate <= WAIT_END;
        end case;
      end if;
    end if;
  end process;

  ------------------------------------------------------------------------------
  -- WB FSM
  ------------------------------------------------------------------------------
  p_WB_FSM : process (clk_i) is
  begin
    if rising_edge(clk_i) then
      if rst_n_i = '0' then
        -- FSM reset after power up,
        -- software reset, manually reset,
        -- on rising edge of AS.

        s_WBFSMstate  <= IDLE;
        -- WB
        wb_cyc_o         <= '0';
        wb_stb_o         <= '0';
        wb_sel_o         <= "0000";
        wb_we_o          <= '0';
        addr_reg         <= (others => '0');

        s_err            <= '0';
        s_wb_done		     <= '0';
        s_cross_boundary <= '0';
      else
        case s_WBFSMstate is
          when IDLE =>

            wb_cyc_o <= '0';
            wb_stb_o <= '0';

            if load_addr_reg_phase1 = '1' then
              --  VME address phase 1.
              addr_reg (31 downto 1) <= vme_idff_addr;
              addr_reg (0) <= vme_idff_lword_n;

              s_cross_boundary <= '0';

              -- Reformat address according to the mode (A16, A24, A32)
              -- FIXME: not needed if ADEM are correctly reduced to not compare
              -- MSBs of A16 or A24 addresses.
              case vme_idff_am is
                when c_AM_A16 | c_AM_A16_SUP =>
                  addr_reg (31 downto 16) <= (others => '0');  -- A16
                when c_AM_A24_SUP | c_AM_A24
                    | c_AM_A24_BLT | c_AM_A24_BLT_SUP
                    | c_AM_A24_MBLT | c_AM_A24_MBLT_SUP =>
                  addr_reg (31 downto 24) <= (others => '0');  -- A24
                when c_AM_CR_CSR
                    | c_AM_A32 | c_AM_A32_SUP
                    | c_AM_A32_BLT | c_AM_A32_BLT_SUP
                    | c_AM_A32_MBLT | c_AM_A32_MBLT_SUP
                    | c_AM_2EVME_6U =>
                  null;
                when others =>
                  null;
              end case;
            end if;

            if load_addr_reg_phase2 = '1' then
              --  VME address phase 2 (for 2eVME oand 2eSST)
              addr_reg(7 downto 0) <= vme_idff_addr (7 downto 1) & vme_idff_lword_n;
            end if;

            if decode_done_i = '1' then
              -- Keep only the local part of the address.
              addr_reg (31 downto 1) <= addr_decoder_i;
            end if;

            if s_wb_start = '1' then
              --  Even if no WB cycle is started, clear s_wb_done.
              s_wb_done <= '0';
            end if;

            if s_wb_start = '1' and s_cross_boundary = '0' then
              -- Start WB cycle.
              wb_cyc_o <= s_card_sel;
              wb_stb_o <= s_card_sel;
              wb_we_o <= not vme_idff_write_n;

              if vme_idff_write_n = '0' then
                --  Get the data to write (in case of write!).
                if g_VME32 and s_transferType = MBLT then
                  data_reg (0) <= vme_idff_lword_n;
                  data_reg (31 downto 1) <= vme_idff_addr;
                  data_reg (63 downto 32) <= vme_idff_data;
                else
                  if addr_reg(0) = '0' then
                    --  32bit access (lword is set)
                    data_reg (31 downto 0) <= vme_idff_data;
                  else
                    --  16bit access (lword is not set)
                    data_reg (15 downto  0) <= vme_idff_data (15 downto 0);
                    data_reg (31 downto 16) <= vme_idff_data (15 downto 0);
                  end if;
                end if;
              end if;

              --  Translate DS+LWORD+ADDR to WB byte selects
              if not g_VME32 then
                --  16bit access on a 16bit bus.
                wb_sel_o (3 downto 2) <= "00";
                wb_sel_o (1 downto 0) <= not vme_idff_ds_n;
              elsif addr_reg(0) = '0' or s_transferType = VME2E then
                --  32bit access
                wb_sel_o <= "1111";
              else
                --  16bit access on a 32bit bus.
                wb_sel_o <= "0000";
                case addr_reg(1) is
                  when '0' =>
                    wb_sel_o (3 downto 2) <= not vme_idff_ds_n;
                  when '1' =>
                    wb_sel_o (1 downto 0) <= not vme_idff_ds_n;
                  when others =>
                    null;
                end case;
              end if;

              s_wb_dataphase <= f_to_std_logic (s_transferType = MBLT or s_transferType = VME2E);

              s_stall  <= '1';  -- Can stall
              s_err <= '0';
              if s_card_sel = '1' then
                s_WBFSMstate <= MEMORY_REQ;
              elsif s_conf_sel = '1' then
                if vme_idff_write_n = '1' then
                  --  Read the data
                  data_reg(7 downto 0) <= cr_csr_data_i;
                end if;

                s_wb_done <= '1';
                s_WBFSMstate <= IDLE;
              elsif s_irq_sel = '1' then
                data_reg (7 downto 0) <= int_vector_i;

                s_wb_done <= '1';
                s_WBFSMstate <= IDLE;
              end if;
            else
              -- Wait in IDLE until s_wb_start = '1'
              s_WBFSMstate <= IDLE;
            end if;

          when MEMORY_REQ =>
            -- Assert STB if stall was asserted.

            case g_WB_MODE is
              when CLASSIC =>
                -- Maintain STB.
                wb_stb_o <= '1';
              when PIPELINED =>
                -- Maintain STB if stall was set in the previous cycle.
                wb_stb_o <= s_stall and wb_stall_i;
            end case;

            s_stall  <= s_stall and wb_stall_i;

            if wb_ack_i = '1' or wb_err_i = '1' then
              -- WB ack
              -- For classic mode, be sure strobe is negated.
              wb_stb_o <= '0';

              if s_transferType /= SINGLE then
                --  Next word for any block transfer.
                --  VITA 1-1994 RULE 2.12a:
                --    BLT must not cross any 256 byte boundary.
                --  VITA 1-1994 RULE 2.78
                --    MBLT cycles MUST not cross any 2048 byte boundary.
                addr_reg (10 downto 2) <=
                  std_logic_vector (unsigned(addr_reg (10 downto 2)) + 1);
                if addr_reg(7 downto 2) = b"1111_11" then
                  if s_transferType = MBLT and  addr_reg (10 downto 8) = "111" then
                    s_cross_boundary <= '1';
                  elsif s_transferType = BLT then
                    s_cross_boundary <= '1';
                  end if;
                end if;
              end if;

              if wb_err_i = '1' then
                -- Error
                s_err <= '1';
                s_WBFSMstate <= IDLE;

              elsif vme_idff_write_n = '0' then
                -- Write cycle.

                if s_wb_dataPhase = '1' then
                  -- MBLT
                  s_wb_dataPhase <= '0';

                  data_reg(31 downto 0) <= data_reg(63 downto 32);

                  -- STB is 0, wait one cycle before the 2nd xfer.
                  s_WBFSMstate <= MEMORY_PAUSE;
                else
                  s_wb_done <= '1';
                  s_WBFSMstate <= IDLE;
                end if;
              else
                -- Read cycle

                -- Mux (CS-CSR or WB)
                data_reg(63 downto 32) <= data_reg(31 downto 0);
                data_reg(31 downto 0) <= (others => '0');
                if g_VME32 and addr_reg(0) = '1' and addr_reg(1) = '0'
                then
                  -- Word/byte access with A1 = 0 on a 32bit bus.
                  data_reg(15 downto 0) <= wb_dat_i(31 downto 16);
                else
                  data_reg(31 downto 0) <= wb_dat_i;
                end if;

                if s_wb_dataPhase = '1' and g_VME32 then
                  -- MBLT
                  s_wb_dataPhase <= '0';

                  case g_WB_MODE is
                    when CLASSIC =>
                      -- STB is 0, wait one cycle before the 2nd xfer.
                      s_WBFSMstate <= MEMORY_PAUSE;
                    when PIPELINED =>
                      -- No need to pause, can directly start a new xfer.
                      wb_stb_o <= '1';
                      s_stall  <= '1';
                      s_WBFSMstate <= MEMORY_REQ;
                  end case;
                else
                  s_wb_done <= '1';
                  s_WBFSMstate <= IDLE;
                end if;
              end if;
            else
              s_WBFSMstate <= MEMORY_REQ;
            end if;


          when MEMORY_PAUSE =>
            -- Wait until ACK is 0. Strictly speaking, this is not needed
            -- according to WB specs.
            wb_stb_o <= '0';

            if wb_ack_i = '0' then
              wb_stb_o <= '1';
              s_stall  <= '1';
              s_WBFSMstate <= MEMORY_REQ;
            else
              s_WBFSMstate <= MEMORY_PAUSE;
            end if;
        end case;
      end if;
    end if;
  end process;

  -- WB Master

  g_wb_addr32: if g_VME32 generate
    with g_WB_GRANULARITY select
      wb_adr_o <= "00" & addr_reg(31 downto 2) when WORD,
                  addr_reg(31 downto 2) & "00" when BYTE;
  end generate;
  g_wb_addr16: if not g_VME32 generate
     with g_WB_GRANULARITY select
        wb_adr_o <= "0" & addr_reg(31 downto 1) when WORD,
                    addr_reg(31 downto 1) & "0" when BYTE;
  end generate;

  wb_dat_o <= data_reg(31 downto 0);

  -- Function Decoder
  addr_decoder_o <= addr_reg (31 downto 1);
  am_o           <= vme_idff_am;

  -- CR/CSR In/Out
  cr_csr_data_o  <= data_reg(7 downto 0);
  cr_csr_addr_o  <= addr_reg(18 downto 2);
  cr_csr_we_o    <= '1' when s_conf_req = '1' and vme_idff_write_n = '0'
                    else '0';

  vme_addr_dir_o   <= vme_odff_addr_dir;
  vme_data_dir_o   <= vme_odff_data_dir;
  vme_addr_o       <= vme_odff_addr;
  vme_data_o       <= vme_odff_data;
  vme_lword_n_o    <= vme_odff_lword_n;

  vme_retry_n_o  <= vme_odff_retry_n;
  vme_retry_oe_o <= vme_odff_retry_oe;

  vme_dtack_oe_o <= vme_odff_dtack_oe;
  
  card_sel_o     <= s_card_sel;

  process (vme_odff_dtack_n, vme_nsync_ds_n_i, vme_dtack_async_ctrl)
  begin
    if vme_dtack_async_ctrl = '0' then
      vme_dtack_n_o <= vme_odff_dtack_n;
    else
      --  Asserted (to 0) as soon as one ds signal is asserted (to 0).
      --  Negated (to 1) as soon as both ds signal is negated (to 1).
      vme_dtack_n_o <= vme_nsync_ds_n_i(0) and vme_nsync_ds_n_i(1);
    end if;
  end process;
end rtl;
