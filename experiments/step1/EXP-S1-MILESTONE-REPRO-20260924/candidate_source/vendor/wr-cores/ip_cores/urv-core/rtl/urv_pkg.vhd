library ieee;
use ieee.std_logic_1164.all;

package urv_pkg is
    component urv_cpu is
        generic (
           g_timer_frequency : natural := 1000;
           g_clock_frequency : natural := 100000000;
           g_with_hw_div : natural := 1;
           g_with_hw_mulh : natural := 1;
           g_with_hw_mul : natural := 1;
           g_with_hw_debug : natural := 0;
           g_with_ecc : natural := 0;
           g_with_compressed_insns : natural := 0);
        port (
            clk_i   : in  std_logic;
            rst_i   : in  std_logic;
            irq_i   : in  std_logic;
            fault_o : out std_logic;

            -- instruction mem I/F
            im_addr_o  : out std_logic_vector (31 downto 0);
            im_rd_o    : out std_logic;
            im_data_i  : in  std_logic_vector (31 downto 0);
            im_valid_i : in  std_logic;

            -- data mem I/F
            -- The interface is pipelined: store/load are asserted for one cycle
            -- and then store_done/load_done is awaited.
            dm_addr_o        : out std_logic_vector (31 downto 0);
            dm_data_s_o      : out std_logic_vector (31 downto 0);
            dm_data_l_i      : in  std_logic_vector (31 downto 0);
            dm_data_select_o : out std_logic_vector (3 downto 0);

            dm_store_o : out std_logic;
            dm_load_o : out std_logic;
            dm_load_done_i : in  std_logic;
            dm_store_done_i : in  std_logic;

            -- Debug I/F
            -- Debug mode is entered either when dbg_force_i is set, or when the ebreak
            -- instructions is executed.  Debug mode is left when the ebreak instruction
            -- is executed (from the dbg_insn_i port).
            -- When debug mode is entered, dbg_enabled_o is set.  This may not be
            -- immediate.  Interrupts are disabled in debug mode.
            -- In debug mode, instructions are executed from dbg_insn_i.
            -- As instructions are always fetched, they must be always valid.  Use
            -- a nop (0x13) if nothing should be executed.
            dbg_force_i : in  std_logic;
            dbg_enabled_o : out std_logic;
            dbg_insn_i : in  std_logic_vector (31 downto 0);
            dbg_insn_set_i : in  std_logic;
            dbg_insn_ready_o : out std_logic;

            dbg_mbx_data_i : in std_logic_vector (31 downto 0);
            dbg_mbx_write_i : in  std_logic;
            dbg_mbx_data_o : out std_logic_vector (31 downto 0));
    end component;
end urv_pkg;
