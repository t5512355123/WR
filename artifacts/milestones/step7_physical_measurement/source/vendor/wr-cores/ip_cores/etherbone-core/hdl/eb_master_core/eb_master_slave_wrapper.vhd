  library ieee;
  use ieee.std_logic_1164.all;

  library work;
  use work.genram_pkg.all;
  use work.wishbone_pkg.all;
  use work.wr_fabric_pkg.all;
  use work.etherbone_pkg.all;
  use work.eb_internals_pkg.all;
  
  entity eb_master_slave_wrapper is
  generic(
    g_with_master         : boolean := false;
    
    g_ebs_sdb_address     : std_logic_vector(63 downto 0);
    g_ebs_timeout_cycles  : natural;
    g_ebs_mtu             : natural;
    
    g_ebm_adr_bits_hi     : natural
    
    );
  port(
    clk_i           : in  std_logic;
    nRst_i          : in  std_logic;
    
    --to wr core, ext wrf if 
    snk_i           : in  t_wrf_sink_in;
    snk_o           : out t_wrf_sink_out;
    src_o           : out t_wrf_source_out;
    src_i           : in  t_wrf_source_in;
  
    --ebs
    ebs_cfg_slave_o : out t_wishbone_slave_out;
    ebs_cfg_slave_i : in  t_wishbone_slave_in;
    ebs_wb_master_o : out t_wishbone_master_out;
    ebs_wb_master_i : in  t_wishbone_master_in;
    
    --ebm (optional)
    ebm_wb_slave_i  : in  t_wishbone_slave_in;
    ebm_wb_slave_o  : out t_wishbone_slave_out 
     
  );
  end eb_master_slave_wrapper;
  
  architecture behavioral of eb_master_slave_wrapper is

    signal mux_src_out : t_wrf_source_out_array(1 downto 0);
    signal mux_src_in  : t_wrf_source_in_array(1 downto 0);
    signal mux_snk_out : t_wrf_sink_out_array(1 downto 0);
    signal mux_snk_in  : t_wrf_sink_in_array(1 downto 0);
    signal mux_class   : t_wrf_mux_class(1 downto 0);

    signal ebm_src_in  : t_wrf_source_in;
    signal ebm_src_out : t_wrf_source_out;
    
    signal ebs_snk_in  : t_wrf_sink_in;
    signal ebs_snk_out : t_wrf_sink_out;
    signal ebs_src_out : t_wrf_source_out;
    signal ebs_src_in  : t_wrf_source_in;
    
    
  begin
  
     U_ebs : eb_ethernet_slave
     generic map(
       g_sdb_address => g_ebs_sdb_address)
     port map(
       clk_i       => clk_i,
       nRst_i      => nRst_i,
       snk_i       => ebs_snk_in,
       snk_o       => ebs_snk_out,
       src_o       => ebs_src_out,
       src_i       => ebs_src_in,
       cfg_slave_o => ebs_cfg_slave_o,
       cfg_slave_i => ebs_cfg_slave_i,
       master_o    => ebs_wb_master_o,
       master_i    => ebs_wb_master_i);
       
  MS1:  if(g_with_master = true) generate

      -- instantiate eb master
      
		
		U_ebm : eb_master_top 
        GENERIC MAP(g_adr_bits_hi => g_ebm_adr_bits_hi,
                    g_mtu         => 1500)
        PORT MAP (
          clk_i           => clk_i,
          rst_n_i         => nRst_i,
          slave_i  		  => ebm_wb_slave_i,
          slave_o         => ebm_wb_slave_o,
          src_o           => ebm_src_out,
          src_i           => ebm_src_in);  

      -- instantiate fabric mux for eb slave and master
      U_WBP_Mux : xwrf_mux
        generic map(
          g_muxed_ports => 2)
        port map (
          clk_sys_i   => clk_i,
          rst_n_i     => nRst_i,
          ep_src_o    => src_o,
          ep_src_i    => src_i,
          ep_snk_o    => snk_o,
          ep_snk_i    => snk_i,
          mux_src_o   => mux_src_out,
          mux_src_i   => mux_src_in,
          mux_snk_o   => mux_snk_out,
          mux_snk_i   => mux_snk_in,
          mux_class_i => mux_class);

      -- wire eb slave and eb master to mux, connect mux to outer fabric sink/src
      mux_class(0)  <= x"00";
      mux_class(1)  <= x"f0";
      
      mux_snk_in(1)  <= ebs_src_out; -- EB slave
      ebs_src_in     <= mux_snk_out(1);
      mux_src_in(1)  <= ebs_snk_out;
      ebs_snk_in     <= mux_src_out(1);
      
      ebm_src_in     <= mux_snk_out(0);   -- EB Master
      mux_snk_in(0)  <= ebm_src_out;
		
		
      mux_src_in(0) <= c_dummy_src_in;
    end generate;
	 
    MS2:  if(g_with_master = false) generate

      -- wire eb slave fabric src and sink directly to outer interface      
      src_o         <= ebs_src_out;
      ebs_src_in	  <= src_i;

		
		ebs_snk_in    <= snk_i;
      snk_o         <= ebs_snk_out;
          
    end generate;
  end behavioral;   
