`include "if_wb_master.svh"
`include "if_wb_slave.svh"
`include "wb_packet_source.svh"
`include "wb_packet_sink.svh"

`include "endpoint_mdio.v"


import endpoint_pkg::*;
import ep_wbgen2_pkg::*;


module main;

  reg clk_sys = 1'b0;
  reg rst_n = 1'b0;
  
  always #5ns clk_sys <= ~clk_sys;
  initial begin
    repeat(3) @(posedge clk_sys);
    rst_n <= 1'b1;
  end
      
/*
 * LFSR PRBS generator
 */

   wire [15:0] tx_data;
   reg [15:0]  rx_data;
   wire [1:0]  tx_k;
   reg [1:0]   rx_k;

   always@(posedge clk_sys)
     begin
	if ($urandom()%1000 < 10)
	  begin
	     rx_data <= 'hdead;
//	     $error("InjectERror!");
	  end
	
	else
	  rx_data <= tx_data;

	rx_k <= tx_k;
     end
   
   

   IWishboneMaster 
     #(
       .g_data_width(32),
       .g_addr_width(7))
   MDIO
     (
      .clk_i(clk_sys),
      .rst_n_i(rst_n)
      );


   reg [15:0]  mdio_addr, mdio_din;
   reg 	       mdio_rw = 0;
   reg 	       mdio_stb = 0;
   wire        mdio_ready;
   wire [15:0] mdio_dout;

   task automatic mdio_write(int r, int v );
      mdio_addr <= r;
      mdio_din <= v;
      mdio_stb <= 1;
      mdio_rw <= 1;

      @(posedge clk_sys);
      @(posedge clk_sys);

      while(!mdio_ready)
	@(posedge clk_sys);

      mdio_stb = 0;

      repeat(5)
	@(posedge clk_sys);
      
   endtask // mdio_write

   task automatic mdio_read(int r, output int v );
      mdio_addr <= r;
      mdio_din <= v;
      mdio_stb <= 1;
      mdio_rw <= 0;

      @(posedge clk_sys);
      @(posedge clk_sys);

      while(!mdio_ready)
	@(posedge clk_sys);

      //$error("READ");
      
      
      mdio_stb = 0;
      v = mdio_dout;
      
      repeat(5)
	@(posedge clk_sys);
      
   endtask // mdio_write
   
   
   ep_1000basex_pcs
     #(
       .g_simulation(1'b0),
       .g_16bit(1'b1),
       .g_ep_idx(0)
       ) DUT (

	      .rst_sys_n_i   (rst_n),
	      .rst_txclk_n_i (rst_n),
	      .rst_rxclk_n_i (rst_n),
	      .clk_sys_i     (clk_sys),

	      .serdes_tx_clk_i (clk_sys),
	      .serdes_tx_data_o (tx_data),
	      .serdes_tx_k_o (tx_k),
	      .serdes_tx_disparity_i (1'b0),
	      .serdes_tx_enc_err_i (1'b0),
	      
	      .serdes_rx_clk_i      (clk_sys),
	      .serdes_rx_data_i     (rx_data),
	      .serdes_rx_k_i        (rx_k),
	      .serdes_rx_enc_err_i  (1'b0),
	      .serdes_rx_bitslide_i (5'b0),

	      
	      .mdio_addr_i  (mdio_addr),
	      .mdio_data_i  (mdio_din),
	      .mdio_data_o  (mdio_dout),
	      .mdio_stb_i   (mdio_stb),
	      .mdio_rw_i    (mdio_rw),
	      .mdio_ready_o (mdio_ready)
	      );

   initial begin
      #1us;

`define CTL_PRBS_TX_EN (1<<0)
`define CTL_PRBS_CHECK_EN (1<<1)
`define CTL_PRBS_WORD_SEL (1<<2)
`define CTL_PRBS_LATCH_COUNT (1<<3)

      
      mdio_write( `ADDR_MDIO_DBG_PRBS_CONTROL >> 2, `CTL_PRBS_TX_EN | `CTL_PRBS_CHECK_EN  );


      while(1)
	begin
	   automatic uint32_t err_lsb, err_msb;

	   mdio_write( `ADDR_MDIO_DBG_PRBS_CONTROL >> 2, `CTL_PRBS_TX_EN | `CTL_PRBS_CHECK_EN | `CTL_PRBS_LATCH_COUNT  );

	   mdio_read( `ADDR_MDIO_DBG_PRBS_STATUS >> 2, err_lsb );

	   mdio_write( `ADDR_MDIO_DBG_PRBS_CONTROL >> 2, `CTL_PRBS_TX_EN | `CTL_PRBS_CHECK_EN | `CTL_PRBS_WORD_SEL  );
	   mdio_read( `ADDR_MDIO_DBG_PRBS_STATUS >> 2, err_msb );

	   $display("PRBS Errors: ", (err_msb << 16) | err_lsb);

	   #10us;
	   
	end
      
      
      

      
      
//`define ADDR_MDIO_DBG_PRBS_CONTROL     7'h50
//`define ADDR_MDIO_DBG_PRBS_STATUS      7'h54

   end
   
   
   
endmodule // main



