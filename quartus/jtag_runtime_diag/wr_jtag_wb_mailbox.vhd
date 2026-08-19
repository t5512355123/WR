library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.wishbone_pkg.all;

entity wr_jtag_wb_mailbox is
  generic (
    g_instance_id : string := "WR_WB_MASTER"
  );
  port (
    i_clk          : in  std_logic;
    i_reset_n      : in  std_logic;
    i_wb_slave_o   : in  t_wishbone_slave_out;
    o_wb_slave_i   : out t_wishbone_slave_in
  );
end entity wr_jtag_wb_mailbox;

architecture rtl of wr_jtag_wb_mailbox is
  component altsource_probe is
    generic (
      enable_metastability    : string  := "NO";
      instance_id             : string  := "UNUSED";
      lpm_hint                : string  := "altsource_probe";
      lpm_type                : string  := "altsource_probe";
      probe_width             : natural := 1;
      sld_auto_instance_index : string  := "YES";
      sld_instance_index      : natural := 0;
      source_initial_value    : string  := "0";
      source_width            : natural := 1
    );
    port (
      probe      : in  std_logic_vector(probe_width-1 downto 0);
      source     : out std_logic_vector(source_width-1 downto 0);
      source_clk : in  std_logic := '0';
      source_ena : in  std_logic := '1'
    );
  end component;

  type t_state is (IDLE, ACTIVE);
  signal state_r : t_state := IDLE;

  signal source_jtag_w : std_logic_vector(95 downto 0);
  signal source_sync1_r : std_logic_vector(95 downto 0) := (others => '0');
  signal source_sync2_r : std_logic_vector(95 downto 0) := (others => '0');
  signal request_seen_r : std_logic := '0';
  signal done_toggle_r  : std_logic := '0';

  signal wb_addr_r  : std_logic_vector(31 downto 0) := (others => '0');
  signal wb_data_r  : std_logic_vector(31 downto 0) := (others => '0');
  signal wb_sel_r   : std_logic_vector(3 downto 0) := (others => '1');
  signal wb_we_r    : std_logic := '0';
  signal result_r   : std_logic_vector(31 downto 0) := (others => '0');
  signal result_ack_r : std_logic := '0';
  signal result_err_r : std_logic := '0';
  signal result_stall_r : std_logic := '0';

  signal wb_slave_i_w : t_wishbone_slave_in := cc_dummy_slave_in;
  signal probe_w      : std_logic_vector(63 downto 0) := (others => '0');
  signal active_w     : std_logic;

begin
  u_mailbox_probe : altsource_probe
    generic map (
      instance_id             => g_instance_id,
      probe_width             => 64,
      source_width            => 96,
      sld_auto_instance_index => "NO",
      sld_instance_index      => 1
    )
    port map (
      probe      => probe_w,
      source     => source_jtag_w,
      source_clk => i_clk,
      source_ena => '1'
    );

  -- A mailbox transaction is one classic Wishbone cycle.  The source toggle
  -- is the command commit point; all address/data fields are sampled from the
  -- same synchronized source word.
  p_mailbox : process(i_clk)
  begin
    if rising_edge(i_clk) then
      source_sync1_r <= source_jtag_w;
      source_sync2_r <= source_sync1_r;

      if i_reset_n = '0' then
        state_r         <= IDLE;
        request_seen_r  <= '0';
        done_toggle_r   <= '0';
        wb_addr_r       <= (others => '0');
        wb_data_r       <= (others => '0');
        wb_sel_r        <= (others => '1');
        wb_we_r         <= '0';
        result_r        <= (others => '0');
        result_ack_r    <= '0';
        result_err_r    <= '0';
        result_stall_r  <= '0';
      else
        case state_r is
          when IDLE =>
            result_ack_r   <= '0';
            result_err_r   <= '0';
            result_stall_r <= '0';
            if source_sync2_r(0) /= request_seen_r then
              request_seen_r <= source_sync2_r(0);
              wb_we_r        <= source_sync2_r(1);
              wb_sel_r       <= source_sync2_r(5 downto 2);
              wb_addr_r      <= source_sync2_r(37 downto 6);
              wb_data_r      <= source_sync2_r(69 downto 38);
              state_r        <= ACTIVE;
            end if;

          when ACTIVE =>
            if i_wb_slave_o.ack = '1' or i_wb_slave_o.err = '1' then
              result_r        <= i_wb_slave_o.dat;
              result_ack_r    <= i_wb_slave_o.ack;
              result_err_r    <= i_wb_slave_o.err;
              result_stall_r  <= i_wb_slave_o.stall;
              done_toggle_r   <= request_seen_r;
              state_r         <= IDLE;
            elsif i_wb_slave_o.stall = '1' then
              result_stall_r <= '1';
            end if;
        end case;
      end if;
    end if;
  end process;

  p_wishbone_drive : process(state_r, wb_addr_r, wb_data_r, wb_sel_r, wb_we_r)
  begin
    wb_slave_i_w <= cc_dummy_slave_in;
    if state_r = ACTIVE then
      wb_slave_i_w.cyc <= '1';
      wb_slave_i_w.stb <= '1';
      wb_slave_i_w.adr <= wb_addr_r;
      wb_slave_i_w.dat <= wb_data_r;
      wb_slave_i_w.sel <= wb_sel_r;
      wb_slave_i_w.we  <= wb_we_r;
    end if;
  end process;

  o_wb_slave_i <= wb_slave_i_w;

  active_w <= '1' when state_r = ACTIVE else '0';
  probe_w <= (63 downto 37 => '0') & active_w & done_toggle_r &
             result_ack_r & result_err_r & result_stall_r & result_r;
end architecture rtl;
