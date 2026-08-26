--------------------------------------------------------------------------------
-- CERN BE-CO-HT
-- Mock Turtle
-- https://gitlab.cern.ch/coht/mockturtle
--------------------------------------------------------------------------------
--
-- unit name:   mt_urv_wrapper
--
-- description: A small wrapper for the URV encompassing the internal RAM and
-- access to the RAM through CPU CSR register block.
--
--------------------------------------------------------------------------------
-- Copyright (c) 2014-2019 CERN (home.cern)
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

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.genram_pkg.all;
use work.wishbone_pkg.all;
use work.wrc_cpu_csr_wbgen2_pkg.all;
use work.urv_pkg.all;

entity wrc_urv_wrapper is
  generic(
    g_IRAM_SIZE : integer;
    g_IRAM_INIT : string;
    g_CPU_ID    : integer);
  port(
    clk_sys_i : in  std_logic;
    rst_n_i   : in  std_logic;
    irq_i     : in  std_logic;
    dwb_o     : out t_wishbone_master_out;
    dwb_i     : in  t_wishbone_master_in;
    host_slave_i : in t_wishbone_slave_in;
    host_slave_o : out t_wishbone_slave_out;
    cpu_pc_o     : out std_logic_vector(31 downto 0);
    cpu_reset_o  : out std_logic;
    cpu_fault_o  : out std_logic;
    cpu_im_valid_o : out std_logic;
    cpu_boot_stage_value_o : out std_logic_vector(31 downto 0);
    cpu_boot_stage_seen_o  : out std_logic;
    cpu_last_store_addr_o  : out std_logic_vector(31 downto 0);
    cpu_last_store_data_o  : out std_logic_vector(31 downto 0);
    cpu_last_store_seen_o  : out std_logic;
    cpu_internal_store_count_o : out std_logic_vector(31 downto 0);
    cpu_mepc_o : out std_logic_vector(31 downto 0);
    cpu_mcause_o : out std_logic_vector(31 downto 0);
    cpu_data_diag_addr_payload_o : out std_logic_vector(63 downto 0);
    cpu_data_diag_meta_payload_o : out std_logic_vector(63 downto 0);
    cpu_ram_diag_addr_payload_o : out std_logic_vector(63 downto 0);
    cpu_ram_diag_q_payload_o : out std_logic_vector(63 downto 0);
    cpu_ram_diag_meta_payload_o : out std_logic_vector(63 downto 0);
    cpu_ram_diag_q0_payload_o : out std_logic_vector(63 downto 0);
    cpu_ram_init_diag_payload0_o : out std_logic_vector(63 downto 0);
    cpu_ram_init_diag_payload1_o : out std_logic_vector(63 downto 0);
    cpu_ram_init_diag_payload2_o : out std_logic_vector(63 downto 0);
    cpu_ram_init_diag_payload3_o : out std_logic_vector(63 downto 0);
    cpu_ram_init_diag_meta_payload_o : out std_logic_vector(63 downto 0);
    cpu_ram_primitive_diag_payload0_o : out std_logic_vector(63 downto 0);
    cpu_ram_primitive_diag_payload1_o : out std_logic_vector(63 downto 0);
    cpu_ram_primitive_diag_meta_payload_o : out std_logic_vector(63 downto 0);
    cpu_ram_port_a_diag_payload0_o : out std_logic_vector(63 downto 0);
    cpu_ram_port_a_diag_payload1_o : out std_logic_vector(63 downto 0);
    cpu_ram_port_a_diag_meta_payload_o : out std_logic_vector(63 downto 0)
    );
end wrc_urv_wrapper;

architecture arch of wrc_urv_wrapper is

  impure function f_x_to_zero (x : std_logic_vector) return std_logic_vector
  is
    variable tmp : std_logic_vector(x'length-1 downto 0);
    variable found_undef : boolean := false;
  begin
-- synthesis translate_off
    for i in 0 to x'length-1 loop
      if( x(i) = 'U' or x(i) = 'Z' or x(i) = 'X' ) then
        found_undef := true;
      end if;

      if x(i) = '1' or x(i) = 'H' then
        tmp(i) := '1';
      else
        tmp(i) := '0';
      end if;
    end loop;
    return tmp;

    if found_undef then
      report "Undefined data value read from memory" severity warning;
    end if;

-- synthesis translate_on
    return x;
  end function f_x_to_zero;

  function f_swap_endian_32(x : std_logic_vector) return std_logic_vector
  is
  begin
    return x(7 downto 0) & x(15 downto 8) & x(23 downto 16) & x(31 downto 24);
  end f_swap_endian_32;

  signal cpu_rst        : std_logic;
  signal cpu_rst_d      : std_logic;

  signal im_addr  : std_logic_vector(31 downto 0);
  signal im_data  : std_logic_vector(31 downto 0);
  signal im_valid : std_logic;
  signal cpu_fault : std_logic;
  signal cpu_boot_stage_value : std_logic_vector(31 downto 0);
  signal cpu_boot_stage_seen  : std_logic;
  signal cpu_last_store_addr  : std_logic_vector(31 downto 0);
  signal cpu_last_store_data  : std_logic_vector(31 downto 0);
  signal cpu_last_store_seen  : std_logic;
  signal cpu_internal_store_count : unsigned(31 downto 0);
  signal cpu_mepc : std_logic_vector(31 downto 0);
  signal cpu_mcause : std_logic_vector(31 downto 0);
  signal cpu_data_diag_addr : std_logic_vector(31 downto 0);
  signal cpu_data_diag_return_data : std_logic_vector(31 downto 0);
  signal cpu_data_diag_sel : std_logic_vector(3 downto 0);
  signal cpu_data_diag_seen : std_logic;
  signal cpu_data_diag_return_seen : std_logic;
  signal cpu_data_diag_expected_match : std_logic;
  signal cpu_data_diag_pending : std_logic;
  signal cpu_data_diag_addr_payload : std_logic_vector(63 downto 0);
  signal cpu_data_diag_meta_payload : std_logic_vector(63 downto 0);
  signal dm_addr_b_registered_debug : std_logic_vector(31 downto 0);
  signal cpu_ram_diag_addr_request : std_logic_vector(31 downto 0);
  signal cpu_ram_diag_addr_prev : std_logic_vector(31 downto 0);
  signal cpu_ram_diag_addr_registered : std_logic_vector(31 downto 0);
  signal cpu_ram_diag_q_cycle0 : std_logic_vector(31 downto 0);
  signal cpu_ram_diag_q_cycle1 : std_logic_vector(31 downto 0);
  signal cpu_ram_diag_q_cycle2 : std_logic_vector(31 downto 0);
  signal cpu_ram_diag_sel : std_logic_vector(3 downto 0);
  signal cpu_ram_diag_seen : std_logic;
  signal cpu_ram_diag_q1_seen : std_logic;
  signal cpu_ram_diag_q2_seen : std_logic;
  signal cpu_ram_diag_expected_match : std_logic;
  signal cpu_ram_diag_state : std_logic_vector(1 downto 0);
  signal cpu_ram_init_q_while_reset : std_logic_vector(31 downto 0);
  signal cpu_ram_init_q_release0 : std_logic_vector(31 downto 0);
  signal cpu_ram_init_q_release1 : std_logic_vector(31 downto 0);
  signal cpu_ram_init_q_release2 : std_logic_vector(31 downto 0);
  signal cpu_ram_init_q_release3 : std_logic_vector(31 downto 0);
  signal cpu_ram_init_q_before_first_load : std_logic_vector(31 downto 0);
  signal cpu_ram_init_q_at_first_load : std_logic_vector(31 downto 0);
  signal cpu_ram_init_q_prev : std_logic_vector(31 downto 0);
  signal cpu_ram_init_release_state : std_logic_vector(2 downto 0);
  signal cpu_ram_init_q_reset_seen : std_logic;
  signal cpu_ram_init_release_seen : std_logic;
  signal cpu_ram_init_release_complete : std_logic;
  signal cpu_ram_init_first_load_seen : std_logic;
  signal dm_ram_q_b_raw : std_logic_vector(31 downto 0);
  signal cpu_ram_primitive_q_prev : std_logic_vector(31 downto 0);
  signal cpu_ram_primitive_q_before_load : std_logic_vector(31 downto 0);
  signal cpu_ram_primitive_q_at_load : std_logic_vector(31 downto 0);
  signal cpu_ram_primitive_q_after_load : std_logic_vector(31 downto 0);
  signal cpu_ram_primitive_dm_at_load : std_logic_vector(31 downto 0);
  signal cpu_ram_primitive_state : std_logic_vector(1 downto 0);
  signal cpu_ram_primitive_load_seen : std_logic;
  signal cpu_ram_primitive_after_seen : std_logic;
  signal cpu_ram_primitive_same_at_load : std_logic;
  signal cpu_ram_port_a_addr_at_load : std_logic_vector(31 downto 0);
  signal cpu_ram_port_a_write_data_at_load : std_logic_vector(31 downto 0);
  signal cpu_ram_port_a_bwe_at_load : std_logic_vector(3 downto 0);
  signal cpu_ram_port_a_write_enable_at_load : std_logic;
  signal cpu_ram_port_b_addr_at_load : std_logic_vector(31 downto 0);
  signal cpu_ram_port_b_q_at_load : std_logic_vector(31 downto 0);
  signal cpu_ram_port_a_diag_seen : std_logic;
  signal cpu_ram_port_a_same_addr : std_logic;

  signal ha_im_addr     : std_logic_vector(31 downto 0);
  signal ha_im_wdata    : std_logic_vector(31 downto 0);
  signal ha_im_bwea     : std_logic_vector(3 downto 0);
  signal ha_im_write    : std_logic;

  signal im_addr_muxed : std_logic_vector(31 downto 0);

  signal dm_addr, dm_data_s, dm_data_l                  : std_logic_vector(31 downto 0);
  signal dm_data_select                                 : std_logic_vector(3 downto 0);
  signal dm_load, dm_store, dm_load_done, dm_store_done : std_logic;

  signal dm_cycle_in_progress, dm_is_wishbone : std_logic;

  signal dm_mem_rdata, dm_wb_rdata : std_logic_vector(31 downto 0);
  signal dm_wb_write, dm_select_wb : std_logic;
  signal dm_data_write             : std_logic;

  constant c_INSN_NOP : std_logic_vector(31 downto 0) := x"0000_0013";
  signal dbg_insn     : std_logic_vector(31 downto 0);

  signal dwb_out         : t_wishbone_master_out;

  signal regs_in : t_wrc_cpu_csr_out_registers;
  signal regs_out : t_wrc_cpu_csr_in_registers;

  component urv_cpu is
    generic (
      g_timer_frequency       : integer := 1000;
      g_clock_frequency       : integer := 100000000;
      g_with_hw_div           : integer := 1;
      g_with_hw_mulh          : integer := 1;
      g_with_hw_mul           : integer := 1;
      g_with_hw_debug         : integer := 0;
      g_with_ecc              : integer := 0;
      g_with_compressed_insns : integer := 0);
    port (
      clk_i            : in  std_logic;
      rst_i            : in  std_logic;
      irq_i            : in  std_logic;
      fault_o          : out std_logic;
      im_addr_o        : out std_logic_vector(31 downto 0);
      im_rd_o          : out std_logic;
      im_data_i        : in  std_logic_vector(31 downto 0);
      im_valid_i       : in  std_logic;
      dm_addr_o        : out std_logic_vector(31 downto 0);
      dm_data_s_o      : out std_logic_vector(31 downto 0);
      dm_data_l_i      : in  std_logic_vector(31 downto 0);
      dm_data_select_o : out std_logic_vector(3 downto 0);
      dm_store_o       : out std_logic;
      dm_load_o        : out std_logic;
      dm_load_done_i   : in  std_logic;
      dm_store_done_i  : in  std_logic;
      dbg_force_i      : in  std_logic;
      dbg_enabled_o    : out std_logic;
      dbg_insn_i       : in  std_logic_vector(31 downto 0);
      dbg_insn_set_i   : in  std_logic;
      dbg_insn_ready_o : out std_logic;
      dbg_mbx_data_i   : in  std_logic_vector(31 downto 0);
      dbg_mbx_write_i  : in  std_logic;
      dbg_mbx_data_o   : out std_logic_vector(31 downto 0);
      csr_mepc_o       : out std_logic_vector(31 downto 0);
      csr_mcause_o     : out std_logic_vector(31 downto 0));
  end component;

begin

  ha_im_bwea <= "1111";

  wrc_cpu_csr_wb_slave_1: entity work.wrc_cpu_csr_wb_slave
    port map (
      rst_n_i   => rst_n_i,
      clk_sys_i => clk_sys_i,
      slave_i   => host_slave_i,
      slave_o   => host_slave_o,
      regs_i    => regs_out,
      regs_o    => regs_in);

  dwb_o <= dwb_out;

  U_cpu_core : urv_cpu
    generic map (
      g_timer_frequency => 1000,
      g_clock_frequency => 62500000,
      g_with_hw_debug => 1,
      g_with_hw_mulh => 1,
      g_with_hw_mul => 1,
      g_with_hw_div => 1
    )
    port map (
      clk_i            => clk_sys_i,
      rst_i            => cpu_rst,
      irq_i            => irq_i,
      fault_o          => cpu_fault,
      im_addr_o        => im_addr,
      im_rd_o          => open,
      im_data_i        => im_data,
      im_valid_i       => im_valid,
      dm_addr_o        => dm_addr,
      dm_data_s_o      => dm_data_s,
      dm_data_l_i      => dm_data_l,
      dm_data_select_o => dm_data_select,
      dm_store_o       => dm_store,
      dm_load_o        => dm_load,
      dm_load_done_i   => dm_load_done,
      dm_store_done_i  => dm_store_done,
      dbg_force_i      => regs_in.dbg_force_o(0),
      dbg_enabled_o    => regs_out.dbg_status_i(0),
      dbg_insn_i       => dbg_insn,
      dbg_insn_set_i   => regs_in.dbg_core0_insn_wr_o,
      dbg_insn_ready_o => regs_out.dbg_insn_ready_i(0),
      dbg_mbx_data_i   => regs_in.dbg_core0_mbx_o,
      dbg_mbx_write_i  => regs_in.dbg_core0_mbx_load_o,
      dbg_mbx_data_o   => regs_out.dbg_core0_mbx_i,
      csr_mepc_o       => cpu_mepc,
      csr_mcause_o     => cpu_mcause);

  -- 1st MByte of the mem is the IRAM
  dm_is_wishbone <= '1' when dm_addr(31 downto 20) /= x"000" else '0';

  U_iram : generic_dpram
    generic map (
      g_DATA_WIDTH               => 32,
      g_SIZE                     => g_IRAM_SIZE,
      g_WITH_BYTE_ENABLE         => TRUE,
      g_ADDR_CONFLICT_RESOLUTION => "dont_care",
      g_INIT_FILE                => g_IRAM_INIT,
      g_FAIL_IF_FILE_NOT_FOUND   => TRUE,
      g_DUAL_CLOCK               => FALSE)
    port map (
      rst_n_i => rst_n_i,
      clka_i  => clk_sys_i,
      bwea_i  => ha_im_bwea,
      wea_i   => ha_im_write,
      aa_i    => im_addr_muxed(f_log2_size(g_IRAM_SIZE)+1 downto 2),
      da_i    => ha_im_wdata,
      qa_o    => im_data,
      clkb_i  => clk_sys_i,
      bweb_i  => dm_data_select,
      web_i   => dm_data_write,
      ab_i    => dm_addr(f_log2_size(g_IRAM_SIZE)+1 downto 2),
      db_i    => dm_data_s,
      qb_o    => dm_mem_rdata,
      qb_raw_o => dm_ram_q_b_raw);

  --  Host access to the CPU memory (through instruction port)
  p_iram_host_access : process(clk_sys_i)
  begin
    if rising_edge(clk_sys_i) then
      if rst_n_i = '0' then
        ha_im_write <= '0';
      else
        if regs_in.udata_load_o = '1' then
          ha_im_wdata <= f_swap_endian_32(regs_in.udata_o);
          ha_im_write <= '1';
        else
          ha_im_write <= '0';
        end if;

        ha_im_addr(21 downto 0)  <= regs_in.uaddr_addr_o & "00";
        ha_im_addr(31 downto 22) <= (others => '0');
        regs_out.udata_i        <= f_swap_endian_32(im_data);
      end if;
    end if;
  end process p_iram_host_access;

  -- Wishbone bus arbitration / internal RAM access
  p_wishbone_master : process(clk_sys_i)
  begin
    if rising_edge(clk_sys_i) then
      if rst_n_i = '0' or cpu_rst = '1' then
        dwb_out.cyc          <= '0';
        dwb_out.stb          <= '0';
        dwb_out.adr          <= (others => '0');
        dwb_out.sel          <= x"0";
        dwb_out.we           <= '0';
        dwb_out.dat          <= (others => '0');
        dm_cycle_in_progress <= '0';
        dm_load_done         <= '0';
        dm_store_done        <= '0';
        dm_select_wb         <= '0';
      else
        if dm_cycle_in_progress = '0' then
          if dm_is_wishbone = '0' then
            -- access to internal memory
            dm_select_wb  <= '0';
            if dm_store = '1' then
              dm_load_done  <= '0';
              dm_store_done <= '1';
            elsif dm_load = '1' then
              dm_load_done  <= '1';
              dm_store_done <= '0';
            else
              dm_store_done <= '0';
              dm_load_done  <= '0';
            end if;
          else
            if dm_load = '1' or dm_store = '1' then
              dwb_out.cyc          <= '1';
              dwb_out.stb          <= '1';
              dwb_out.we           <= dm_store;
              dm_wb_write          <= dm_store;
              dwb_out.adr          <= dm_addr;
              dwb_out.dat          <= dm_data_s;
              dwb_out.sel          <= dm_data_select;
              dm_load_done         <= '0';
              dm_store_done        <= '0';
              dm_cycle_in_progress <= '1';
            else
              dm_store_done        <= '0';
              dm_load_done         <= '0';
              dm_cycle_in_progress <= '0';
            end if;
          end if;
        else
          if dwb_i.stall = '0' then
            dwb_out.stb <= '0';
          end if;

          if dwb_i.ack = '1' then
            if dm_wb_write = '0' then
              dm_wb_rdata  <= f_x_to_zero(dwb_i.dat);
              dm_select_wb <= '1';
              dm_load_done <= '1';
            else
              dm_store_done <= '1';
              dm_select_wb  <= '0';
            end if;

            dm_cycle_in_progress <= '0';
            dwb_out.cyc          <= '0';
          end if;
        end if;
      end if;
    end if;
  end process p_wishbone_master;

  dm_data_write <= not dm_is_wishbone and dm_store;
  dm_data_l     <= dm_wb_rdata when dm_select_wb = '1' else dm_mem_rdata;
  im_addr_muxed <= ha_im_addr  when cpu_rst = '1'      else im_addr;

  p_dbg_insn : process(clk_sys_i)
  begin
    if rising_edge(clk_sys_i) then
      if rst_n_i = '0' then
        dbg_insn <= c_INSN_NOP;
      else
        if regs_in.dbg_core0_insn_wr_o = '1' then
          dbg_insn <= regs_in.dbg_core0_insn_o;
        else
          dbg_insn <= c_INSN_NOP;
        end if;
      end if;
    end if;
  end process p_dbg_insn;

  p_im_valid : process(clk_sys_i)
  begin
    if rising_edge(clk_sys_i) then
      if cpu_rst = '1' then
        im_valid  <= '0';
        cpu_rst_d <= '1';
      else
        cpu_rst_d <= cpu_rst;
        im_valid  <= (not cpu_rst_d);
      end if;
    end if;
  end process p_im_valid;

  -- 診斷 latch：記住固定 linker section .debug_boot 的啟動標記。
  -- 這個位置位於 192 KiB RAM 的 stack 前保留區，避免韌體大小變化
  -- 讓符號位址漂移。Master/Slave 共用同一個固定地址。
  p_boot_stage_observe : process(clk_sys_i)
  begin
    if rising_edge(clk_sys_i) then
      if rst_n_i = '0' then
        cpu_boot_stage_value <= (others => '0');
        cpu_boot_stage_seen  <= '0';
        cpu_last_store_addr  <= (others => '0');
        cpu_last_store_data  <= (others => '0');
        cpu_last_store_seen  <= '0';
        cpu_internal_store_count <= (others => '0');
      elsif dm_store = '1' and dm_is_wishbone = '0' then
        cpu_last_store_addr <= dm_addr;
        cpu_last_store_data <= dm_data_s;
        cpu_last_store_seen <= '1';
        cpu_internal_store_count <= cpu_internal_store_count + 1;
        if dm_addr = x"0002E000" then
          cpu_boot_stage_value <= dm_data_s;
          cpu_boot_stage_seen  <= '1';
        end if;
      end if;
    end if;
  end process p_boot_stage_observe;

  -- Read-only sticky capture of the first CPU internal data read after reset.
  -- The address/byte-enable are sampled with the request.  The RAM has a
  -- registered address on port B, so the return word is sampled one clock
  -- later from dm_mem_rdata.  This observes the CPU data path without changing
  -- address decode, byte enables, or returned data.
  p_cpu_data_port_observe : process(clk_sys_i)
  begin
    if rising_edge(clk_sys_i) then
      if rst_n_i = '0' then
        cpu_data_diag_addr          <= (others => '0');
        cpu_data_diag_return_data   <= (others => '0');
        cpu_data_diag_sel           <= (others => '0');
        cpu_data_diag_seen          <= '0';
        cpu_data_diag_return_seen  <= '0';
        cpu_data_diag_expected_match <= '0';
        cpu_data_diag_pending       <= '0';
      elsif cpu_data_diag_pending = '1' then
        cpu_data_diag_return_data  <= dm_mem_rdata;
        cpu_data_diag_return_seen <= '1';
        cpu_data_diag_pending     <= '0';
      elsif cpu_data_diag_seen = '0' and dm_load = '1' and dm_is_wishbone = '0' then
        cpu_data_diag_addr        <= dm_addr;
        cpu_data_diag_sel         <= dm_data_select;
        cpu_data_diag_seen        <= '1';
        cpu_data_diag_pending     <= '1';
        if dm_addr = x"0001C304" then
          cpu_data_diag_expected_match <= '1';
        else
          cpu_data_diag_expected_match <= '0';
        end if;
      end if;
    end if;
  end process p_cpu_data_port_observe;

  -- Read-only sticky observation of the RAM port-B request/return pipeline.
  -- dm_addr_b_registered_debug mirrors the clocked address register at U_iram
  -- port B: ab_i is wired directly from dm_addr and the Altera RAM address
  -- register is clocked by clk_sys_i.  Q samples are taken before the next
  -- address-register update, giving the two successive port-B q values.
  p_cpu_ram_port_b_observe : process(clk_sys_i)
  begin
    if rising_edge(clk_sys_i) then
      if rst_n_i = '0' then
        dm_addr_b_registered_debug <= (others => '0');
        cpu_ram_diag_addr_request  <= (others => '0');
        cpu_ram_diag_addr_prev     <= (others => '0');
        cpu_ram_diag_addr_registered <= (others => '0');
        cpu_ram_diag_q_cycle0      <= (others => '0');
        cpu_ram_diag_q_cycle1      <= (others => '0');
        cpu_ram_diag_q_cycle2      <= (others => '0');
        cpu_ram_diag_sel           <= (others => '0');
        cpu_ram_diag_seen          <= '0';
        cpu_ram_diag_q1_seen       <= '0';
        cpu_ram_diag_q2_seen       <= '0';
        cpu_ram_diag_expected_match <= '0';
        cpu_ram_diag_state         <= "00";
      else
        dm_addr_b_registered_debug <= dm_addr;
        case cpu_ram_diag_state is
          when "00" =>
            if dm_load = '1' and dm_is_wishbone = '0' then
              cpu_ram_diag_addr_request <= dm_addr;
              cpu_ram_diag_addr_prev    <= dm_addr_b_registered_debug;
              cpu_ram_diag_q_cycle0     <= dm_mem_rdata;
              cpu_ram_diag_sel          <= dm_data_select;
              cpu_ram_diag_seen         <= '1';
              if dm_addr = x"0001C304" then
                cpu_ram_diag_expected_match <= '1';
              else
                cpu_ram_diag_expected_match <= '0';
              end if;
              cpu_ram_diag_state <= "01";
            end if;
          when "01" =>
            cpu_ram_diag_addr_registered <= dm_addr_b_registered_debug;
            cpu_ram_diag_q_cycle1        <= dm_mem_rdata;
            cpu_ram_diag_q1_seen         <= '1';
            cpu_ram_diag_state           <= "10";
          when "10" =>
            cpu_ram_diag_q_cycle2 <= dm_mem_rdata;
            cpu_ram_diag_q2_seen  <= '1';
            cpu_ram_diag_state    <= "11";
          when others =>
            null;
        end case;
      end if;
    end if;
  end process p_cpu_ram_port_b_observe;

  -- Read-only capture of the RAM port-B q sequence around reset release.
  -- q_while_reset is intentionally clock-enabled while rst_n_i is low,
  -- rather than reset by rst_n_i, so the last q value observed during the
  -- asserted-reset interval remains available after release.  The other
  -- fields capture the first four post-release q samples and the q value
  -- immediately before/at the first internal CPU load.
  p_cpu_ram_init_observe : process(clk_sys_i)
  begin
    if rising_edge(clk_sys_i) then
      if rst_n_i = '0' then
        cpu_ram_init_q_while_reset <= dm_mem_rdata;
        cpu_ram_init_q_reset_seen  <= '1';
        cpu_ram_init_q_release0 <= (others => '0');
        cpu_ram_init_q_release1 <= (others => '0');
        cpu_ram_init_q_release2 <= (others => '0');
        cpu_ram_init_q_release3 <= (others => '0');
        cpu_ram_init_q_before_first_load <= (others => '0');
        cpu_ram_init_q_at_first_load <= (others => '0');
        cpu_ram_init_q_prev <= (others => '0');
        cpu_ram_init_release_state <= "000";
        cpu_ram_init_release_seen <= '0';
        cpu_ram_init_release_complete <= '0';
        cpu_ram_init_first_load_seen <= '0';
      else
        cpu_ram_init_q_prev <= dm_mem_rdata;

        case cpu_ram_init_release_state is
          when "000" =>
            cpu_ram_init_q_release0 <= dm_mem_rdata;
            cpu_ram_init_release_seen <= '1';
            cpu_ram_init_release_state <= "001";
          when "001" =>
            cpu_ram_init_q_release1 <= dm_mem_rdata;
            cpu_ram_init_release_state <= "010";
          when "010" =>
            cpu_ram_init_q_release2 <= dm_mem_rdata;
            cpu_ram_init_release_state <= "011";
          when "011" =>
            cpu_ram_init_q_release3 <= dm_mem_rdata;
            cpu_ram_init_release_complete <= '1';
            cpu_ram_init_release_state <= "100";
          when others =>
            null;
        end case;

        if cpu_ram_init_first_load_seen = '0' and
           dm_load = '1' and dm_is_wishbone = '0' then
          cpu_ram_init_q_before_first_load <= cpu_ram_init_q_prev;
          cpu_ram_init_q_at_first_load <= dm_mem_rdata;
          cpu_ram_init_first_load_seen <= '1';
        end if;
      end if;
    end if;
  end process p_cpu_ram_init_observe;

  -- Read-only capture at the generic_dpram/Altera primitive boundary.
  -- q_before_load is the previous system-clock sample of the primitive q_b;
  -- q_at_load and dm_at_load are sampled on the first internal dm_load edge;
  -- q_after_load is sampled on the following edge.  The additional raw-q
  -- fanout does not alter RAM parameters, mode, latency, or arbitration.
  p_cpu_ram_primitive_observe : process(clk_sys_i)
  begin
    if rising_edge(clk_sys_i) then
      if rst_n_i = '0' then
        cpu_ram_primitive_q_prev <= (others => '0');
        cpu_ram_primitive_q_before_load <= (others => '0');
        cpu_ram_primitive_q_at_load <= (others => '0');
        cpu_ram_primitive_q_after_load <= (others => '0');
        cpu_ram_primitive_dm_at_load <= (others => '0');
        cpu_ram_primitive_state <= "00";
        cpu_ram_primitive_load_seen <= '0';
        cpu_ram_primitive_after_seen <= '0';
        cpu_ram_primitive_same_at_load <= '0';
      else
        case cpu_ram_primitive_state is
          when "00" =>
            if dm_load = '1' and dm_is_wishbone = '0' then
              cpu_ram_primitive_q_before_load <= cpu_ram_primitive_q_prev;
              cpu_ram_primitive_q_at_load <= dm_ram_q_b_raw;
              cpu_ram_primitive_dm_at_load <= dm_mem_rdata;
              cpu_ram_primitive_load_seen <= '1';
              if dm_ram_q_b_raw = dm_mem_rdata then
                cpu_ram_primitive_same_at_load <= '1';
              else
                cpu_ram_primitive_same_at_load <= '0';
              end if;
              cpu_ram_primitive_state <= "01";
            end if;
          when "01" =>
            cpu_ram_primitive_q_after_load <= dm_ram_q_b_raw;
            cpu_ram_primitive_after_seen <= '1';
            cpu_ram_primitive_state <= "10";
          when others =>
            null;
        end case;
        cpu_ram_primitive_q_prev <= dm_ram_q_b_raw;
      end if;
    end if;
  end process p_cpu_ram_primitive_observe;

  -- Read-only capture of port-A activity on the same edge as the first
  -- internal port-B load.  Port A is the instruction/host side of U_iram;
  -- there is no separate port-A read-enable in generic_dpram or altsyncram,
  -- so wea_i/bwea_i are the complete write-side activity indicators.
  p_cpu_ram_port_a_observe : process(clk_sys_i)
  begin
    if rising_edge(clk_sys_i) then
      if rst_n_i = '0' then
        cpu_ram_port_a_addr_at_load        <= (others => '0');
        cpu_ram_port_a_write_data_at_load <= (others => '0');
        cpu_ram_port_a_bwe_at_load         <= (others => '0');
        cpu_ram_port_a_write_enable_at_load <= '0';
        cpu_ram_port_b_addr_at_load        <= (others => '0');
        cpu_ram_port_b_q_at_load           <= (others => '0');
        cpu_ram_port_a_diag_seen           <= '0';
        cpu_ram_port_a_same_addr           <= '0';
      elsif cpu_ram_port_a_diag_seen = '0' and
            dm_load = '1' and dm_is_wishbone = '0' then
        -- Capture the byte-address sources that feed the actual primitive
        -- word-address slices in U_iram, together with the exact q_b sample.
        cpu_ram_port_a_addr_at_load          <= im_addr_muxed;
        cpu_ram_port_a_write_data_at_load   <= ha_im_wdata;
        cpu_ram_port_a_bwe_at_load          <= ha_im_bwea;
        cpu_ram_port_a_write_enable_at_load <= ha_im_write;
        cpu_ram_port_b_addr_at_load         <= dm_addr;
        cpu_ram_port_b_q_at_load            <= dm_ram_q_b_raw;
        cpu_ram_port_a_diag_seen            <= '1';
        if im_addr_muxed(f_log2_size(g_IRAM_SIZE)+1 downto 2) =
           dm_addr(f_log2_size(g_IRAM_SIZE)+1 downto 2) then
          cpu_ram_port_a_same_addr <= '1';
        else
          cpu_ram_port_a_same_addr <= '0';
        end if;
      end if;
    end if;
  end process p_cpu_ram_port_a_observe;

  cpu_rst        <= not rst_n_i or regs_in.reset_o(0);

  cpu_pc_o       <= im_addr;
  cpu_reset_o    <= cpu_rst;
  cpu_fault_o    <= cpu_fault;
  cpu_im_valid_o <= im_valid;
  cpu_boot_stage_value_o <= cpu_boot_stage_value;
  cpu_boot_stage_seen_o  <= cpu_boot_stage_seen;
  cpu_last_store_addr_o  <= cpu_last_store_addr;
  cpu_last_store_data_o  <= cpu_last_store_data;
  cpu_last_store_seen_o  <= cpu_last_store_seen;
  cpu_internal_store_count_o <= std_logic_vector(cpu_internal_store_count);
  cpu_mepc_o <= cpu_mepc;
  cpu_mcause_o <= cpu_mcause;
  cpu_data_diag_addr_payload <= cpu_data_diag_return_data & cpu_data_diag_addr;
  cpu_data_diag_meta_payload <= (63 downto 7 => '0') &
                                cpu_data_diag_expected_match &
                                cpu_data_diag_return_seen &
                                cpu_data_diag_seen &
                                cpu_data_diag_sel;
  cpu_data_diag_addr_payload_o <= cpu_data_diag_addr_payload;
  cpu_data_diag_meta_payload_o <= cpu_data_diag_meta_payload;
  cpu_ram_diag_addr_payload_o <= cpu_ram_diag_addr_registered & cpu_ram_diag_addr_request;
  cpu_ram_diag_q_payload_o <= cpu_ram_diag_q_cycle2 & cpu_ram_diag_q_cycle1;
  cpu_ram_diag_q0_payload_o <= cpu_ram_diag_addr_prev & cpu_ram_diag_q_cycle0;
  cpu_ram_diag_meta_payload_o <= (63 downto 8 => '0') &
                                 cpu_ram_diag_expected_match &
                                 cpu_ram_diag_q2_seen &
                                 cpu_ram_diag_q1_seen &
                                 cpu_ram_diag_seen &
                                 cpu_ram_diag_sel;
  cpu_ram_init_diag_payload0_o <= cpu_ram_init_q_while_reset & cpu_ram_init_q_release0;
  cpu_ram_init_diag_payload1_o <= cpu_ram_init_q_release1 & cpu_ram_init_q_release2;
  cpu_ram_init_diag_payload2_o <= cpu_ram_init_q_release3 & cpu_ram_init_q_before_first_load;
  cpu_ram_init_diag_payload3_o <= (31 downto 0 => '0') & cpu_ram_init_q_at_first_load;
  cpu_ram_init_diag_meta_payload_o <= (63 downto 10 => '0') &
                                      cpu_rst &
                                      (not rst_n_i) &
                                      '0' &
                                      cpu_ram_init_release_state &
                                      cpu_ram_init_first_load_seen &
                                      cpu_ram_init_release_complete &
                                      cpu_ram_init_release_seen &
                                      cpu_ram_init_q_reset_seen;
  cpu_ram_primitive_diag_payload0_o <= cpu_ram_primitive_q_before_load &
                                      cpu_ram_primitive_q_at_load;
  cpu_ram_primitive_diag_payload1_o <= cpu_ram_primitive_q_after_load &
                                      cpu_ram_primitive_dm_at_load;
  cpu_ram_primitive_diag_meta_payload_o <= (63 downto 10 => '0') &
                                          cpu_rst &
                                          (not rst_n_i) &
                                          (7 downto 5 => '0') &
                                          cpu_ram_primitive_state &
                                          cpu_ram_primitive_same_at_load &
                                          cpu_ram_primitive_after_seen &
                                          cpu_ram_primitive_load_seen;
  cpu_ram_port_a_diag_payload0_o <= cpu_ram_port_a_addr_at_load &
                                    cpu_ram_port_a_write_data_at_load;
  cpu_ram_port_a_diag_payload1_o <= cpu_ram_port_b_addr_at_load &
                                    cpu_ram_port_b_q_at_load;
  cpu_ram_port_a_diag_meta_payload_o <= (63 downto 10 => '0') &
                                        cpu_rst &
                                        (not rst_n_i) &
                                        cpu_ram_port_a_diag_seen &
                                        cpu_ram_port_a_same_addr &
                                        cpu_ram_port_a_bwe_at_load &
                                        cpu_ram_port_a_write_enable_at_load &
                                        cpu_ram_port_a_diag_seen;

end architecture arch;
