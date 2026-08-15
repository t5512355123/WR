library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.wishbone_pkg.all;
use work.eb_hdr_pkg.all;
use work.eb_internals_pkg.all;
use work.wr_fabric_pkg.all;
use work.RandomPkg.all;
use work.etherbone_pkg.all;
use work.genram_pkg.all;

-- entity declaration for your testbench.Dont declare any ports here
ENTITY test_tb IS
END test_tb;

ARCHITECTURE behavior OF test_tb IS


---------------------------------------------------------------------------------
--*****************************************************************************
constant c_seed : natural  := 12800;
constant c_reps : natural  := 10_000_000;
constant c_max_msgs        : natural := 6;
constant c_msgs_len        : natural := 5;

constant c_max_flush_wait  : natural := 5;
constant c_max_wb_wait     : natural := 2;
constant c_max_msg_wait    : natural := 5;
constant c_max_packet_wait : natural := 5000;
--------------------------------------------------------------------------------- 


   constant c_dummy_slave_in : t_wishbone_slave_in :=
    ('0', '0', x"00000000", x"F", '0', x"00000000");
   constant c_dummy_slave_out : t_wishbone_slave_out :=
    ('0', '0', '0', '0', '0', x"00000000"); 
   constant c_dummy_master_out : t_wishbone_master_out := c_dummy_slave_in;

   --declare inputs and initialize them
signal clk                 : std_logic := '0';
signal rst_n               : std_logic := '0';
signal master_o, debug_out : t_wishbone_master_out;
signal master_i, debug_in  : t_wishbone_master_in;

signal ebs_o, fc_ebs_o     : t_wishbone_master_out;
signal ebs_i, fc_ebs_i     : t_wishbone_master_in;

signal fc_master_o         : t_wishbone_master_out;
signal fc_master_i         : t_wishbone_master_in;

signal src_i,ebs_src_in    : t_wrf_source_in;
signal src_o,ebs_src_out   : t_wrf_source_out;

signal slave_stall   : std_logic;
signal cfg_rec_hdr   : t_rec_hdr;
signal cfg_mtu       : natural;
signal count, r_ack_cnt, r_stb_cnt         : natural;
signal r_ack_clr  : std_logic := '1';

signal data          : std_logic_vector(c_wishbone_data_width-1 downto 0);
signal en            : std_logic;
signal eop           : std_logic;
signal clear, s_clear         : std_logic;
signal stop, stop_cnt : boolean := false;    
   
   constant c_CLEAR        : unsigned(31 downto 0) := (others => '0');                 --wo    00
   constant c_FLUSH        : unsigned(31 downto 0) := c_CLEAR        +4; --wo    04
   constant c_STATUS       : unsigned(31 downto 0) := c_FLUSH        +4; --rw    08
   constant c_SRC_MAC_HI   : unsigned(31 downto 0) := c_STATUS       +4; --rw    0C
   constant c_SRC_MAC_LO   : unsigned(31 downto 0) := c_SRC_MAC_HI   +4; --rw    10 
   constant c_SRC_IPV4     : unsigned(31 downto 0) := c_SRC_MAC_LO   +4; --rw    14 
   constant c_SRC_UDP_PORT : unsigned(31 downto 0) := c_SRC_IPV4     +4; --rw    18
   constant c_DST_MAC_HI   : unsigned(31 downto 0) := c_SRC_UDP_PORT +4; --rw    1C
   constant c_DST_MAC_LO   : unsigned(31 downto 0) := c_DST_MAC_HI   +4; --rw    20
   constant c_DST_IPV4     : unsigned(31 downto 0) := c_DST_MAC_LO   +4; --rw    24
   constant c_DST_UDP_PORT : unsigned(31 downto 0) := c_DST_IPV4     +4; --rw    28
   constant c_MTU          : unsigned(31 downto 0) := c_DST_UDP_PORT +4; --rw    2C
   constant c_ADR_HI       : unsigned(31 downto 0) := c_MTU          +4; --rw    30
   constant c_OPS_MAX      : unsigned(31 downto 0) := c_ADR_HI       +4; --rw    34
   constant c_EB_OPT       : unsigned(31 downto 0) := c_OPS_MAX      +4; --rw    38
   constant c_SEMA         : unsigned(31 downto 0) := c_EB_OPT       +4; --rw    3C
   constant c_UDP_RAW      : unsigned(31 downto 0) := c_SEMA         +4; --rw    40
   constant c_UDP_DATA     : unsigned(31 downto 0) := c_UDP_RAW      +4; --ro    44

constant g_MTU          : natural := 1500;
constant c_adr_hi_bits  : natural := 10;

signal A_fifo_d,
       A_fifo_q,
       B_fifo_d,
       B_fifo_q : std_logic_vector(1+1+1+4+32+32 -1 downto 0);

signal A_fifo_push, 
       A_fifo_empty,
       A_fifo_full,
       B_fifo_push,
       AB_fifo_pop,
       B_fifo_empty,
       B_fifo_full,
       s_full,
       s_empty,
       s_diff : std_logic;
       
signal s_pack_len    : natural;
signal r_src_o       : t_wrf_source_out;
signal r_src_i       : t_wrf_source_in;

signal r_src_cnt,
       r_src_cmp,
       r_src_cmp_max : natural; 
 
   -- Clock period definitions
   constant clk_period : time := 8 ns;


component wb_fc_test is
   generic(
      g_seed          : natural := 14897;
      
      g_max_stall     : natural := 20;
      g_prob_stall    : natural := 35;
      
      g_ack_gen       : boolean := false;
      g_max_lag       : natural := 3;
      g_prob_lag      : natural := 35;
      g_prob_err      : natural := 0);
   port(
      -- Slave in
      clk_i    : in  std_logic;
      rst_n_i  : in  std_logic;
      slave_i        : in  t_wishbone_slave_in;
      slave_o        : out t_wishbone_slave_out;
      -- Master out
      master_i       : in  t_wishbone_master_in := ('0', '0', '0', '0', '0', x"00000000");
      master_o       : out t_wishbone_master_out);
end component;

component  wb_op_diff is
   generic(
      g_fifo_depth   : natural := 500;
      g_max_lag      : natural := 50);
   port(
      -- Slave in
      clk_i          : in  std_logic;
      rst_n_i        : in  std_logic;
      
      full_o         : out std_logic;
      empty_o        : out std_logic;
      diff_o         : out std_logic;
      
      slave_A_i      : in t_wishbone_slave_in;
      slave_A_o      : in t_wishbone_slave_out;  -- pure listening device without own signalling
      
      slave_B_i      : in t_wishbone_slave_in;
      slave_B_o      : in t_wishbone_slave_out); --  pure listening device without own signalling
end component;

BEGIN


   


fcI : wb_fc_test
   generic map(
      g_max_stall  => 20,
      g_prob_stall => 35,
      g_seed       => 14898)
   port map(
      -- Slave in
      clk_i    => clk,
      rst_n_i  => rst_n,
      slave_i  => master_o,
      slave_o  => master_i,
      -- Master out
      master_i => fc_master_i,
      master_o => fc_master_o);

fcO : wb_fc_test
   generic map(
      g_max_stall    => 10,
      g_prob_stall   => 20,
      g_seed         => 14899,
      
      g_ack_gen      => true,
      g_max_lag      => 3,
      g_prob_lag     => 50,
      g_prob_err     => 0)
   port map(
      -- Slave in
      clk_i          => clk,
      rst_n_i        => rst_n,
      slave_i        => ebs_o,
      slave_o        => ebs_i,
      -- Master out
      master_i       => fc_ebs_i,
      master_o       => fc_ebs_o);


  
uut: eb_master_top 
   GENERIC MAP(g_adr_bits_hi => c_adr_hi_bits,
               g_mtu => g_mtu)
   PORT MAP (
      clk_i           => clk,
      rst_n_i         => rst_n,

      slave_i         => fc_master_o,
      slave_o         => fc_master_i,
     
      framer_in       => debug_out,
      framer_out      => debug_in,
  
     
      src_o           => src_o,
      src_i           => src_i);    


     U_ebs : eb_ethernet_slave
     generic map(
       g_sdb_address => (others => '0'),
       g_mtu => 1550)
     port map(
       clk_i       => clk,
       nRst_i      => rst_n,
       snk_i       => src_o,
       snk_o       => src_i,
       src_o       => ebs_src_out,
       src_i       => ebs_src_in,
       cfg_slave_o => open,
       cfg_slave_i => c_dummy_slave_in,
       master_o    => ebs_o,
       master_i    => ebs_i);

   -- Clock process definitions( clock with 50% duty cycle is generated here.
   clk_process :process
   begin
      if(not stop and not stop_cnt) then
        
        clk <= '0';
        wait for clk_period/2;  --for 0.5 ns signal is '0'.
        clk <= '1';
        wait for clk_period/2;  --for next 0.5 ns signal is '1'.
      end if;
   end process;
   
   
   ack_process :process(clk)
   variable add_ack : std_logic_vector( 0 downto 0);
   begin
      if(rising_edge(clk)) then
         add_ack(0) := master_i.ack or master_i.err;
         if (r_ack_clr = '1') then
          r_ack_cnt <= 0;
         else 
          r_ack_cnt <= r_ack_cnt + to_integer(unsigned(add_ack));      
         end if;
      end if;
   end process;
   
   

   
   
   
   
   -- Stimulus process
  stim_proc: process
  variable RV : RandomPType;
  variable wait_cnt : natural;
  variable I, J : natural;
  variable v_pack_len : natural;
  variable ovf : boolean := false;
  
   procedure wb_wr( adr : in unsigned(31 downto 0);
                    dat : in std_logic_vector(31 downto 0);
                    hold : in std_logic 
                  ) is
  begin
    
    if(master_o.cyc = '0') then
       r_ack_clr <= '1';
       r_stb_cnt <= 1;
    else
      r_ack_clr <= '0';
      r_stb_cnt <= r_stb_cnt +1;
    end if;
    
    master_o.cyc <= '1';
    master_o.stb  <= '1';
    master_o.we   <= '1';
    master_o.adr  <= std_logic_vector(adr);
    master_o.dat  <= dat;
    wait for clk_period; 
    r_ack_clr <= '0';
    while master_i.stall= '1'loop
      wait for clk_period; 
    end loop;
    master_o.stb  <= '0';
    
    
    if(hold = '0') then
       while r_ack_cnt < r_stb_cnt loop
          wait for clk_period;
       end loop;
       master_o.cyc <= '0'; 
       wait for clk_period;      
    end if;
  end procedure wb_wr;
  
  begin        
        RV.InitSeed(c_seed);
        clear <= '1';
        rst_n <= '0';
        eop <= '0';
        
        master_o         <= c_dummy_master_out;
         master_o.sel <= x"f";
         
         cfg_rec_hdr     <= c_rec_init;
         
        wait for clk_period*2;
        rst_n <= '1';
        wait until rising_edge(clk);  
        --wait for clk_period/4;
        
        wait for clk_period*20;
  
        wb_wr(c_SRC_MAC_HI,   x"D15EA5ED", '1');
        wb_wr(c_SRC_MAC_LO,   x"BEEF0000", '1');
        wb_wr(c_SRC_IPV4,     x"CAFEBABE", '1');
        wb_wr(c_SRC_UDP_PORT, x"0000EBD0", '1');
        wb_wr(c_DST_MAC_HI,   x"11223344", '1');
        wb_wr(c_DST_MAC_LO,   x"55660000", '1');
        wb_wr(c_DST_IPV4,     x"C0A80064", '1');
        wb_wr(c_DST_UDP_PORT, x"0000EBD1", '1');
        wb_wr(c_OPS_MAX,      x"00000030", '1');
        wb_wr(c_ADR_HI,       x"00000000", '1');
        wb_wr(c_EB_OPT,       x"00000000", '0');
      
        wb_wr(c_UDP_RAW,      x"00000001", '0'); 
        wb_wr(c_UDP_DATA,     x"DEADBEE1", '0');
        wb_wr(c_UDP_DATA,     x"DEADBEE2", '0');
        wb_wr(c_UDP_DATA,     x"DEADBEE3", '0'); 
        wb_wr(c_FLUSH,        x"00000001", '0');
        
      for I in 0 to c_reps-1 loop
        
  
        
        
        v_pack_len := 1*4;
        
        for J in 0 to RV.RandInt(4, c_max_msgs)-1 loop 
          ovf := false;
          
          wait for clk_period*RV.RandInt(0, c_max_wb_wait);
          wb_wr(c_ADR_HI,       x"7FFFFFF0", '0');
          v_pack_len := v_pack_len + 2*4;
          for k in 0 to RV.RandInt(2, c_msgs_len)-1 loop 
            
            
            wb_wr(x"01BFFFF0" + to_unsigned((RV.RandInt(1, 1) * 16#00400000#), 32),    std_logic_vector(to_unsigned(v_pack_len,32)), '1');
            v_pack_len := v_pack_len + 4;
          end loop;
          wb_wr(x"01FFFFF0",    x"80000000", '0');
          v_pack_len := v_pack_len + 4;
          wait for clk_period*RV.RandInt(0, c_max_msg_wait);
        end loop;
        wait for clk_period*RV.RandInt(0, c_max_flush_wait);
        s_pack_len <= v_pack_len;
        
        --wait for clk_period*1000; 
        master_o.cyc <= '1';
        master_o.stb  <= '1';
        master_o.we   <= '0';
        master_o.adr  <= std_logic_vector(c_STATUS);
        wait for clk_period; 
        while master_i.stall= '1'loop
          wait for clk_period; 
        end loop;
         master_o.stb  <= '0';
        wait until master_i.ack = '1';
--        
--        if(master_i.dat(0) = '1') then
--          ovf := true;
--          report "OVF!!!!!!!!!!!!!!!!!" severity warning;
--         end if;   
        
        report "FLUSH " & integer'image(v_pack_len) & " " & integer'image(to_integer(unsigned(master_i.dat(31 downto 16)))) severity note;
        wb_wr(c_FLUSH,       x"00000001",  '0');
        wait for clk_period;
        -- 
--        wait_cnt := 0;
--        while src_o.cyc = '0' loop
--          if(ovf) then
--            ovf := false;
--            clear <= '0';
--            wait for clk_period*50;
--            clear <= '1';
--            exit;
--          end if; 
--          wait_cnt := wait_cnt +1;
--          if (wait_cnt > c_max_packet_wait) then
--            report "FREEZE!!" severity failure;
--            stop <= true;
--          end if;  
--          wait for clk_period;
--          
--        end loop;   
--        --report "waiting cyc" severity note;
--        while src_o.cyc = '1' loop
--           wait for clk_period;
--        end loop;  
--        --report "done waiting cyc" severity note;
--         assert not ((I mod 100) = 0) report "***  " & integer'image(I) & " packets sent!" severity note;
--        
       
      end loop;
      report "DONE!" severity warning;
      stop <= true;
      wait for clk_period; 
      wait until rst_n = '0';
      
  end process;

  diff : wb_op_diff
   generic map(
      g_fifo_depth   => 5000,
      g_max_lag      => 50)
   port map(
      -- Slave in
      clk_i          => clk,
      rst_n_i        => s_clear,
      
      full_o         => s_full,
      empty_o        => s_empty,
      diff_o         => s_diff,
      
      slave_A_i      => debug_out,
      slave_A_o      => debug_in, -- pure listening device without own signalling
      
      slave_B_i      => ebs_o,
      slave_B_o      => ebs_i
      ); --  pure listening device without own signalling


  s_clear <= rst_n and clear; 


END;
