--------------------------------------------------------------------------------
-- CERN (BE-CO-HT)
-- VME64x Core
-- http://www.ohwr.org/projects/vme64x-core
--------------------------------------------------------------------------------
--
-- unit name:     xvme64x_core (xvme64x_core.vhd)
--
-- description:
--
--   This core implements an interface to transfer data between the VMEbus and
--   the WBbus. This core is a Slave in the VME side and Master in the WB side.
--
--   All the output signals on the WB bus are registered.
--   The Input signals from the WB bus aren't registered indeed the WB is a
--   synchronous protocol and some registers in the WB side will introduce a
--   delay that make impossible reproduce the WB PIPELINED protocol.
--   The main component of this core is the VME_bus on the left in the block
--   diagram. Inside this component you can find the main finite state machine
--   that coordinates all the synchronisms.
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
use work.gencores_pkg.all;
use work.wishbone_pkg.all;
use work.vme64x_pkg.all;

entity xvme64x_core is
  generic (
    -- Clock period (ns). Used for DS synchronization. A value is required.
    g_CLOCK_PERIOD    : natural;

    -- Consider AM field of ADER to decode addresses. This is what the VME64x
    -- standard says. However, for compatibility with previous implementations
    -- (or to reduce resources), it is possible for a decoder to allow all AM
    -- declared in the AMCAP.
    g_DECODE_AM       : boolean := true;

    -- Enable CR/CSR space.
    -- If False, it also disable DECODE_AM.
    g_ENABLE_CR_CSR   : boolean := true;

    -- Use external user CSR
    g_USER_CSR_EXT    : boolean := false;

    --  If False, handle 16bit backplane, ie not support for P1.
    --  Capbilities are reduced: no A32, no D32, no MBLT.
    --  As a consequence, it uses a 16bit data wishbone bus.
    g_VME32           : boolean := True;

    --  If True, supports 2eSST.
    --  Do not forget to assign g_DECODER if set to True.
    g_VME_2e          : boolean := False;

    -- Address granularity on the WB bus. Value can be:
    -- WORD: VME address bits 31:2 are translated to WB address bits 29:0,
    --       the WB data represents bytes for VME address bits 1:0.
    -- BYTE: VME address bits 31:2 are translated to WB address bits 31:2,
    --       WB address bits 1:0 are always 0.
    g_WB_GRANULARITY  : t_wishbone_address_granularity;

    -- Wishbone mode: classic or pipeline.
    g_WB_MODE         : t_wishbone_interface_mode := CLASSIC;

    -- Manufacturer ID: IEEE OUID
    --                  e.g. CERN is 0x080030
    g_MANUFACTURER_ID : std_logic_vector(23 downto 0);

    -- Board ID: Per manufacturer, each board shall have an unique ID
    --           e.g. SVEC = 408 (CERN IDs: http://cern.ch/boardid)
    g_BOARD_ID        : std_logic_vector(31 downto 0);

    -- Revision ID: user defined revision code
    g_REVISION_ID     : std_logic_vector(31 downto 0);

    -- Program ID: Defined per VME64:
    --               0x00      = Not used
    --               0x01      = No program, ID ROM only
    --               0x02-0x4F = Manufacturer defined
    --               0x50-0x7F = User defined
    --               0x80-0xEF = Reserved for future use
    --               0xF0-0xFE = Reserved for Boot Firmware (P1275)
    --               0xFF      = Not to be used
    g_PROGRAM_ID      : std_logic_vector( 7 downto 0);

    -- Pointer to a user defined ASCII string.
    g_ASCII_PTR       : std_logic_vector(23 downto 0)  := x"000000";

    -- User CR/CSR, CRAM & serial number pointers
    g_BEG_USER_CR     : std_logic_vector(23 downto 0)  := x"000000";
    g_END_USER_CR     : std_logic_vector(23 downto 0)  := x"000000";
    g_BEG_CRAM        : std_logic_vector(23 downto 0)  := x"000000";
    g_END_CRAM        : std_logic_vector(23 downto 0)  := x"000000";
    g_BEG_USER_CSR    : std_logic_vector(23 downto 0)  := x"07ff33";
    g_END_USER_CSR    : std_logic_vector(23 downto 0)  := x"07ff5f";
    g_BEG_SN          : std_logic_vector(23 downto 0)  := x"000000";
    g_END_SN          : std_logic_vector(23 downto 0)  := x"000000";

    -- Function decoder parameters.
    g_DECODER         : t_vme64x_decoder_arr := c_vme64x_decoders_default);
  port (
    -- Main clock and reset.
    clk_i           : in  std_logic;
    rst_n_i         : in  std_logic;

    -- Reset for wishbone core.
    rst_n_o         : out std_logic;

    -- VME slave interface.
    vme_i           : in  t_vme64x_in;
    vme_o           : out t_vme64x_out;

    -- Wishbone interface.
    wb_i            : in  t_wishbone_master_in;
    wb_o            : out t_wishbone_master_out;

    -- Interrupt input from the master side.
    -- Previously it was part of the wishbone interface, but is now separate
    -- as interrupt is not defined by wishbone.
    int_i           : in std_logic := '0';

    -- When the IRQ controller acknowledges the Interrupt cycle it sends a
    -- pulse to the IRQ Generator.
    irq_ack_o       : out std_logic;

    -- User CSR
    -- The following signals are used when g_USER_CSR_EXT = true
    -- otherwise they are connected to the internal user CSR.
    irq_level_i     : in  std_logic_vector( 2 downto 0) := (others => '0');
    irq_vector_i    : in  std_logic_vector( 7 downto 0) := (others => '0');
    user_csr_addr_o : out std_logic_vector(18 downto 2);
    user_csr_data_i : in  std_logic_vector( 7 downto 0) := (others => '0');
    user_csr_data_o : out std_logic_vector( 7 downto 0);
    user_csr_we_o   : out std_logic;

    -- User CR
    user_cr_addr_o  : out std_logic_vector(18 downto 2);
    user_cr_data_i  : in  std_logic_vector( 7 downto 0) := (others => '0'));
end xvme64x_core;

architecture rtl of xvme64x_core is

  -- Compute the index of the last function decoder used.  Assume sequential
  -- use of decoders (ie decoders 0 to N - 1 are used, and decoders N to 7
  -- are not used; holes are supported but not efficiently).
  function compute_last_ader (decoder : t_vme64x_decoder_arr)
    return t_vme_func_index is
  begin
    for i in decoder'reverse_range loop
      if decoder(i).adem /= x"0000_0000" then
        return i;
      end if;
    end loop;
    assert false report "no ADEM defined" severity failure;
    return 0;
  end compute_last_ader;

  constant c_last_ader          : natural := compute_last_ader (g_DECODER);

  -- Calculate the least set bit in a vector
  function least_set_bit (v : std_logic_vector) return natural is
  begin
    for i in 0 to v'length-1 loop
        if v(i) = '1' then
            return i;
        end if;
    end loop;
  end least_set_bit;

  -- Compute the ADER for each function if CR/CSR is not used. For example:
  --   ADEM=FF000000, GA=05 => ADER=05000000
  --   ADEM=FFE00000, GA=05 => ADER=00A00000
  function compute_static_ader (ga : std_logic_vector(4 downto 0)) return t_ader_array is
    variable a : t_ader_array(0 to c_last_ader) := (others => x"0000_0000");
  begin
    for i in a'range loop
      if g_DECODER(i).adem /= x"0000_0000" then
        a(i) := std_logic_vector(resize(unsigned(ga), 32) sll least_set_bit(g_DECODER(i).adem));
      end if;
    end loop;
    return a;
  end compute_static_ader;

  signal s_reset_n              : std_logic;

  signal s_irq_ack              : std_logic;
  signal s_irq_pending          : std_logic;
  signal s_ga                   : std_logic_vector( 4 downto 0);
  signal s_ga_parity            : std_logic;

  -- CR/CSR
  signal s_cr_csr_addr          : std_logic_vector(18 downto 2);
  signal s_cr_csr_data_o        : std_logic_vector( 7 downto 0);
  signal s_cr_csr_data_i        : std_logic_vector( 7 downto 0);
  signal s_cr_csr_we            : std_logic;
  signal s_ader                 : t_ader_array(0 to c_last_ader);
  signal s_module_reset         : std_logic;
  signal s_module_enable        : std_logic;
  signal s_bar                  : std_logic_vector( 4 downto 0);
  signal s_vme_berr_n           : std_logic;

  signal s_irq_vector           : std_logic_vector( 7 downto 0);
  signal s_irq_level            : std_logic_vector( 2 downto 0);
  signal s_user_csr_addr        : std_logic_vector(18 downto 2);
  signal s_user_csr_data_i      : std_logic_vector( 7 downto 0);
  signal s_user_csr_data_o      : std_logic_vector( 7 downto 0);
  signal s_user_csr_we          : std_logic;

  -- Function decoders
  signal s_addr_decoder_i       : std_logic_vector(31 downto 1);
  signal s_addr_decoder_o       : std_logic_vector(31 downto 1);
  signal s_decode_start         : std_logic;
  signal s_decode_done          : std_logic;
  signal s_decode_sel           : std_logic;
  signal s_am                   : std_logic_vector( 5 downto 0);

  -- Oversampled input signals
  signal s_vme_rst_n            : std_logic;
  signal s_vme_as_n             : std_logic;
  signal s_vme_write_n          : std_logic;
  signal s_vme_ds_n             : std_logic_vector(1 downto 0);
  signal s_vme_iack_n           : std_logic;
  signal s_vme_iackin_n         : std_logic;

  -- List of supported AM.
  constant c_AMCAP_ALLOWED : std_logic_vector(63 downto 0) :=
    (16#38# to 16#3f# => '1', --  A24
     16#2d# | 16#29#  => '1', --  A16
     16#20# => f_to_std_logic(g_VME32 and g_VME_2e),
     16#08# to 16#0f# => f_to_std_logic(g_VME32), --  A32
     others => '0');
begin
  assert g_CLOCK_PERIOD > 0 report "g_CLOCK_PERIOD generic must be set"
    severity failure;

  --  Check for invalid bits in ADEM/AMCAP
  gen_gchecks: for i in 7 downto 0 generate
    constant adem  : std_logic_vector(31 downto 0) := g_DECODER(i).adem;
    constant amcap : std_logic_vector(63 downto 0) := g_DECODER(i).amcap;
  begin
    assert adem(c_ADEM_FAF) = '0' report "FAF bit set in ADEM"
      severity failure;
    assert adem(c_ADEM_DFS) = '0' report "DFS bit set in ADEM"
      severity failure;
    assert adem(c_ADEM_EFM) = '0' report "EFM bit set in ADEM"
      severity failure;
    assert (amcap and c_AMCAP_ALLOWED) = amcap
      report "bit set in AMCAP for not supported AM"
      severity failure;
  end generate;

  ------------------------------------------------------------------------------
  -- Metastability
  ------------------------------------------------------------------------------
  -- Input oversampling: oversampling the input data is
  -- necessary to avoid metastability problems, but of course the transfer rate
  -- will be slow down a little.
  -- NOTE: the reset value is '0', which means that all signals are active
  -- at reset. But not for a long time and so is s_vme_rst_n.
  inst_vme_rst_resync: entity work.gc_sync_register
    generic map (g_width => 1)
    port map (clk_i => clk_i,
              rst_n_a_i => rst_n_i,
              d_i(0) => vme_i.rst_n,
              q_o(0) => s_vme_rst_n);
  inst_vme_as_resync: entity work.gc_sync_register
    generic map (g_width => 1)
    port map (clk_i => clk_i,
              rst_n_a_i => rst_n_i,
              d_i(0) => vme_i.as_n,
              q_o(0) => s_vme_as_n);
  inst_vme_write_resync: entity work.gc_sync_register
    generic map (g_width => 1)
    port map (clk_i => clk_i,
              rst_n_a_i => rst_n_i,
              d_i(0) => vme_i.write_n,
              q_o(0) => s_vme_write_n);
  -- The two bits of DS are synchronized by the vme_bus FSM. Instantiate two
  -- synchronizers to make clear that they should be considered as independant
  -- signals until they are handled by the FSM.
  inst_vme_ds0_resync: entity work.gc_sync_register
    generic map (g_width => 1)
    port map (clk_i => clk_i,
              rst_n_a_i => rst_n_i,
              d_i(0) => vme_i.ds_n(0),
              q_o(0) => s_vme_ds_n(0));
  inst_vme_ds1_resync: entity work.gc_sync_register
    generic map (g_width => 1)
    port map (clk_i => clk_i,
              rst_n_a_i => rst_n_i,
              d_i(0) => vme_i.ds_n(1),
              q_o(0) => s_vme_ds_n(1));
  inst_vme_iack_resync: entity work.gc_sync_register
    generic map (g_width => 1)
    port map (clk_i => clk_i,
              rst_n_a_i => rst_n_i,
              d_i(0) => vme_i.iack_n,
              q_o(0) => s_vme_iack_n);
  inst_vme_iackin_resync: entity work.gc_sync_register
    generic map (g_width => 1)
    port map (clk_i => clk_i,
              rst_n_a_i => rst_n_i,
              d_i(0) => vme_i.iackin_n,
              q_o(0) => s_vme_iackin_n);

  ------------------------------------------------------------------------------
  -- VME Bus
  ------------------------------------------------------------------------------
  inst_vme_bus : entity work.vme_bus
    generic map (
      g_CLOCK_PERIOD   => g_CLOCK_PERIOD,
      g_VME32          => g_VME32,
      g_VME_2E         => g_VME_2E,
      g_WB_GRANULARITY => g_WB_GRANULARITY,
      g_WB_MODE        => g_WB_MODE)
    port map (
      clk_i           => clk_i,
      rst_n_i         => s_reset_n,

      -- VME
      vme_as_n_i      => s_vme_as_n,
      vme_lword_n_o   => vme_o.lword_n,
      vme_lword_n_i   => vme_i.lword_n,
      vme_retry_n_o   => vme_o.retry_n,
      vme_retry_oe_o  => vme_o.retry_oe,
      vme_write_n_i   => s_vme_write_n,
      vme_ds_n_i      => s_vme_ds_n,
      vme_nsync_ds_n_i => vme_i.ds_n,  --  Not synchronized.
      vme_dtack_n_o   => vme_o.dtack_n,
      vme_dtack_oe_o  => vme_o.dtack_oe,
      vme_berr_n_o    => s_vme_berr_n,
      vme_addr_i      => vme_i.addr,
      vme_addr_o      => vme_o.addr,
      vme_addr_dir_o  => vme_o.addr_dir,
      vme_addr_oe_n_o => vme_o.addr_oe_n,
      vme_data_i      => vme_i.data,
      vme_data_o      => vme_o.data,
      vme_data_dir_o  => vme_o.data_dir,
      vme_data_oe_n_o => vme_o.data_oe_n,
      vme_am_i        => vme_i.am,
      vme_iackin_n_i  => s_vme_iackin_n,
      vme_iack_n_i    => s_vme_iack_n,
      vme_iackout_n_o => vme_o.iackout_n,

      -- WB signals
      wb_stb_o        => wb_o.stb,
      wb_ack_i        => wb_i.ack,
      wb_dat_o        => wb_o.dat,
      wb_dat_i        => wb_i.dat,
      wb_adr_o        => wb_o.adr,
      wb_sel_o        => wb_o.sel,
      wb_we_o         => wb_o.we,
      wb_cyc_o        => wb_o.cyc,
      wb_err_i        => wb_i.err,
      wb_stall_i      => wb_i.stall,

      -- Function decoder
      addr_decoder_i  => s_addr_decoder_o,
      addr_decoder_o  => s_addr_decoder_i,
      decode_start_o  => s_decode_start,
      decode_done_i   => s_decode_done,
      am_o            => s_am,
      decode_sel_i    => s_decode_sel,

      -- CR/CSR signals
      cr_csr_addr_o   => s_cr_csr_addr,
      cr_csr_data_i   => s_cr_csr_data_o,
      cr_csr_data_o   => s_cr_csr_data_i,
      cr_csr_we_o     => s_cr_csr_we,
      module_enable_i => s_module_enable,
      bar_i           => s_bar,

      int_level_i     => s_irq_level,
      int_vector_i    => s_irq_vector,
      irq_pending_i   => s_irq_pending,
      irq_ack_o       => s_irq_ack,
      card_sel_o      => open);

  s_reset_n  <= rst_n_i and s_vme_rst_n;
  rst_n_o    <= s_reset_n and (not s_module_reset);

  vme_o.berr_n <= s_vme_berr_n;

  inst_vme_funct_match : entity work.vme_funct_match
    generic map (
      g_DECODER   => g_DECODER,
      g_DECODE_AM => g_DECODE_AM and g_ENABLE_CR_CSR
    )
    port map (
      clk_i          => clk_i,
      rst_n_i        => s_reset_n,

      addr_i         => s_addr_decoder_i,
      addr_o         => s_addr_decoder_o,
      decode_start_i => s_decode_start,
      am_i           => s_am,
      ader_i         => s_ader,
      decode_sel_o   => s_decode_sel,
      decode_done_o  => s_decode_done
    );

  ------------------------------------------------------------------------------
  -- Output
  ------------------------------------------------------------------------------
  irq_ack_o  <= s_irq_ack;

  ------------------------------------------------------------------------------
  --  Interrupter
  ------------------------------------------------------------------------------
  inst_vme_irq_controller : entity work.vme_irq_controller
    generic map (
      g_RETRY_TIMEOUT => 1000000 / g_CLOCK_PERIOD   -- 1ms timeout
    )
    port map (
      clk_i           => clk_i,
      rst_n_i         => s_reset_n,
      int_level_i     => s_irq_level,
      int_req_i       => int_i,
      irq_pending_o   => s_irq_pending,
      irq_ack_i       => s_irq_ack,
      vme_irq_n_o     => vme_o.irq_n
    );

  ------------------------------------------------------------------------------
  -- Geographical address
  ------------------------------------------------------------------------------
  s_ga_parity <= vme_i.ga(5) xor vme_i.ga(4) xor vme_i.ga(3) xor
                 vme_i.ga(2) xor vme_i.ga(1) xor vme_i.ga(0);

  -- ANSI/VITA 1.1-1997 Recommendation 3.8: set the "amnesia address"
  -- of 0x1E if bad parity.
  s_ga <= not vme_i.ga(4 downto 0) when s_ga_parity = '1' else '1' & x"e";

  ------------------------------------------------------------------------------
  -- CR/CSR space
  ------------------------------------------------------------------------------
  gen_enable_cr_csr : if g_ENABLE_CR_CSR = true generate
    assert g_VME32 report "CS/CSR requires VME32 (uses a 32bit bus)" severity failure;

    inst_vme_cr_csr_space : entity work.vme_cr_csr_space
      generic map (
        g_MANUFACTURER_ID  => g_MANUFACTURER_ID,
        g_BOARD_ID         => g_BOARD_ID,
        g_REVISION_ID      => g_REVISION_ID,
        g_PROGRAM_ID       => g_PROGRAM_ID,
        g_ASCII_PTR        => g_ASCII_PTR,
        g_BEG_USER_CR      => g_BEG_USER_CR,
        g_END_USER_CR      => g_END_USER_CR,
        g_BEG_CRAM         => g_BEG_CRAM,
        g_END_CRAM         => g_END_CRAM,
        g_BEG_USER_CSR     => g_BEG_USER_CSR,
        g_END_USER_CSR     => g_END_USER_CSR,
        g_BEG_SN           => g_BEG_SN,
        g_END_SN           => g_END_SN,
        g_DECODER          => g_DECODER
      )
      port map (
        clk_i               => clk_i,
        rst_n_i             => s_reset_n,

        vme_ga_i            => s_ga,
        vme_berr_n_i        => s_vme_berr_n,
        bar_o               => s_bar,
        module_enable_o     => s_module_enable,
        module_reset_o      => s_module_reset,

        addr_i              => s_cr_csr_addr,
        data_i              => s_cr_csr_data_i,
        data_o              => s_cr_csr_data_o,
        we_i                => s_cr_csr_we,

        user_csr_addr_o     => s_user_csr_addr,
        user_csr_data_i     => s_user_csr_data_i,
        user_csr_data_o     => s_user_csr_data_o,
        user_csr_we_o       => s_user_csr_we,

        user_cr_addr_o      => user_cr_addr_o,
        user_cr_data_i      => user_cr_data_i,

        ader_o              => s_ader
      );

    -- User CSR space
    gen_int_user_csr : if g_USER_CSR_EXT = false generate
      inst_vme_user_csr : entity work.vme_user_csr
        port map (
          clk_i        => clk_i,
          rst_n_i      => s_reset_n,
          addr_i       => s_user_csr_addr,
          data_i       => s_user_csr_data_o,
          data_o       => s_user_csr_data_i,
          we_i         => s_user_csr_we,
          irq_vector_o => s_irq_vector,
          irq_level_o  => s_irq_level
        );
    end generate;
    gen_ext_user_csr : if g_USER_CSR_EXT = true generate
      s_user_csr_data_i <= user_csr_data_i;
      s_irq_vector      <= irq_vector_i;
      s_irq_level       <= irq_level_i(2 downto 0);
    end generate;
  end generate;
  gen_disable_cr_csr : if g_ENABLE_CR_CSR = false generate
    s_user_csr_data_i <= user_csr_data_i;
    s_cr_csr_data_o   <= s_user_csr_data_i;
    s_irq_vector      <= irq_vector_i;
    s_irq_level       <= irq_level_i(2 downto 0);
    s_user_csr_addr   <= s_cr_csr_addr;
    s_user_csr_data_o <= s_cr_csr_data_i;
    s_user_csr_we     <= s_cr_csr_we;
    user_cr_addr_o    <= (others => '0');
    s_module_enable   <= '1';
    s_module_reset    <= '0';
    s_bar             <= s_ga;
    s_ader            <= compute_static_ader(s_ga);
  end generate;

  user_csr_addr_o <= s_user_csr_addr;
  user_csr_data_o <= s_user_csr_data_o;
  user_csr_we_o   <= s_user_csr_we;

  assert wb_i.rty /= '1' report "rty not supported";
end rtl;
