/* Crude wrapper for Gennum-provided GN4124x BFM. Supports only single CSR reads/writes so far. */

`ifndef __GN4124_BFM_SVH
 `define __GN4124_BFM_SVH 1

`include "simdrv_defs.svh"

interface IGN4124PCIMaster;

   int  cmd_str_int[256];
   reg  cmd_req = 0;
   wire cmd_ack;

   reg  internal_rstn = 0;

   wire lclk_p, lclk_n, l2p_clk_p, l2p_clk_n, p2l_clk_p, p2l_clk_n;
   wire [15:0] l2p_data, p2l_data;
   wire        l2p_dframe, l2p_valid, l2p_edb;
   wire        p2l_dframe, p2l_valid, p2l_rdy;


   wire [1:0] l_wr_rdy, p_rd_d_rdy;
   wire [1:0] p_wr_req, p_wr_rdy, vc_rdy;
   wire       l2p_rdy, tx_error, rx_error;
   wire [15:0] gpio;

 // Local bus to Gennum
   modport L2P
     (

      input  l2p_clk_n,
      input  l2p_clk_p,
      input  l2p_data,
      input  l2p_dframe,
      input  l2p_valid,
      input  l2p_edb,

      output l_wr_rdy,
      output p_rd_d_rdy,
      output l2p_rdy,
      output tx_error
      );

// Gennum to local bus
   modport P2L
     (
      output p2l_clk_p,
      output p2l_clk_n,
      output p2l_dframe,
      output p2l_data,
      output p2l_valid,
      input  p2l_rdy,
      output p_wr_req,
      input  p_wr_rdy,
      input  rx_error,
      output vc_rdy
      );

   wire      rst_n;

   modport SYS
     (
      output lclk_p,
      output lclk_n,
      output rst_n,
      inout  gpio);

   wire [31:0] cmd_rddata;
   wire        cmd_rddata_valid;

GN412X_BFM
  U_BFM (

	 .CMD_INT           (cmd_str_int),
	 .CMD_REQ           (cmd_req),
	 .CMD_ACK           (cmd_ack),
	 .CMD_CLOCK_EN      (1'b1),
	 .CMD_RD_DATA       (cmd_rddata),
	 .CMD_RD_DATA_VALID (cmd_rddata_valid),
	 .RSTINn            (internal_rstn),
	 .RSTOUT18n         (),
	 .RSTOUT33n         (rst_n),
	 .LCLK              (lclk_p),
	 .LCLKn             (lclk_n),
	 .L2P_CLKp          (l2p_clk_p),
	 .L2P_CLKn          (l2p_clk_n),
	 .L2P_DATA          (l2p_data),
	 .L2P_DFRAME        (l2p_dframe),
	 .L2P_VALID         (l2p_valid),
	 .L2P_EDB           (l2p_edb),
	 .L_WR_RDY          (l_wr_rdy),
	 .P_RD_D_RDY        (p_rd_d_rdy),
	 .L2P_RDY           (l2p_rdy),
	 .TX_ERROR          (tx_error),
	 .P2L_CLKp          (p2l_clk_p),
	 .P2L_CLKn          (p2l_clk_n),
	 .P2L_DATA          (p2l_data),
	 .P2L_DFRAME        (p2l_dframe),
	 .P2L_VALID         (p2l_valid),
	 .P2L_RDY           (p2l_rdy),
	 .P_WR_REQ          (p_wr_req),
	 .P_WR_RDY          (p_wr_rdy),
	 .RX_ERROR          (rx_error),
	 .VC_RDY            (vc_rdy),
	 .GPIO              (gpio)
	 );

   int       line_no = 1;

   task send_cmd(string cmd);
      int i;
      string cmd_2;

      $sformat(cmd_2, "%-1d %s", line_no++, cmd);

      //$display("SendCmd '%s'", cmd_2);

      for(i=0;i<cmd_2.len(); i++)
	cmd_str_int[i] = int'(cmd_2[i]);
      cmd_str_int[i] = 0;

      #10ns;
      cmd_req = 1;
      while(!cmd_ack) #1ns;
      cmd_req = 0;
      while(cmd_ack) #1ns;
      #10ns;


   endtask // send_cmd

   bit       ready = 0;


   task init();
      #100ns;
      internal_rstn <= 1;
      #100ns;

      send_cmd("init");
      send_cmd("reset %d16");
      send_cmd("bar 0 FF00000000000000 08000000 0 7 0");
      send_cmd("bfm_bar 0 0000000040000000 20000000");
      send_cmd("bfm_bar 1 0000000020000000 20000000");
      send_cmd("wait %d64");
      ready = 1;

    //  send_cmd("wr FF000000000A0004 F 007C0270");
//      send_cmd("rd FF000000000A0004 F");
   endtask // init

   initial init();

   task automatic readback(ref uint64_t value);
      @(posedge cmd_rddata_valid);
      value = cmd_rddata;
      @(negedge cmd_rddata_valid);
     endtask // readback



class CBusAccessor_Gennum extends CBusAccessor;

   function new();

   endfunction // new

   task writem(uint64_t addr[], uint64_t data[], input int size, ref int result);
      string cmd;
      int    i;


      if(size != 4)
	size = 4;

      //  $fatal("CBusAccessor_Gennum: only size=4 supported");

      for(i=0;i<addr.size();i++)
	begin
	   $sformat(cmd,"wr FF000000%08X F %08X", addr[i], data[i]);
	   send_cmd(cmd);
	end
   endtask // writem

   task readm(uint64_t addr[], ref uint64_t data[], input int size, ref int result);
      string cmd;
      int    i;
      uint64_t tmp;



      if(size != 4)
	size = 4;

      //  $fatal("CBusAccessor_Gennum: only size=4 supported");

      for(i=0;i<addr.size();i++)
	begin
	   $sformat(cmd,"rd FF000000%08X F", addr[i]);
	   fork
	   send_cmd(cmd);
	   readback(tmp);
	   join

	   data[i] = tmp;

	end
   endtask // readm


endclass // CBusAccessor_Gennum

   function CBusAccessor get_accessor();
      automatic CBusAccessor_Gennum g = new();
      return g;
   endfunction




endinterface

/* Helper macro for wiring Gennum-Xilinx ports in spec_top */

`define GENNUM_WIRE_SPEC_PINS(IF_NAME) \
  .L_RST_N    (IF_NAME.rst_n),\
  .L_CLKp     (IF_NAME.lclk_p),\
  .L_CLKn     (IF_NAME.lclk_n),\
  .p2l_clkp   (IF_NAME.p2l_clk_p),\
  .p2l_clkn   (IF_NAME.p2l_clk_n),\
  .p2l_data   (IF_NAME.p2l_data),\
  .p2l_dframe (IF_NAME.p2l_dframe),\
  .p2l_valid  (IF_NAME.p2l_valid),\
  .p2l_rdy    (IF_NAME.p2l_rdy),\
  .p_wr_req   (IF_NAME.p_wr_req),\
  .p_wr_rdy   (IF_NAME.p_wr_rdy),\
  .rx_error   (IF_NAME.rx_error),\
  .l2p_clkp   (IF_NAME.l2p_clk_p),\
  .l2p_clkn   (IF_NAME.l2p_clk_n),\
  .l2p_data   (IF_NAME.l2p_data),\
  .l2p_dframe (IF_NAME.l2p_dframe),\
  .l2p_valid  (IF_NAME.l2p_valid),\
  .l2p_edb    (IF_NAME.l2p_edb),\
  .l2p_rdy    (IF_NAME.l2p_rdy),\
  .l_wr_rdy   (IF_NAME.l_wr_rdy),\
  .p_rd_d_rdy (IF_NAME.p_rd_d_rdy),\
  .tx_error   (IF_NAME.tx_error),\
  .vc_rdy     (IF_NAME.vc_rdy)

//the same as above but with names of the top SPEC entity that stick to naming conventions
`define GENNUM_WIRE_SPEC_PINS_WITH_PROPER_NAMING(IF_NAME) \
  .l_rst_n_i    (IF_NAME.rst_n),\
  .l_clk_p_i    (IF_NAME.lclk_p),\
  .l_clk_n_i    (IF_NAME.lclk_n),\
  .p2l_clk_p_i  (IF_NAME.p2l_clk_p),\
  .p2l_clk_n_i  (IF_NAME.p2l_clk_n),\
  .p2l_data_i   (IF_NAME.p2l_data),\
  .p2l_dframe_i (IF_NAME.p2l_dframe),\
  .p2l_valid_i  (IF_NAME.p2l_valid),\
  .p2l_rdy_o    (IF_NAME.p2l_rdy),\
  .p_wr_req_i   (IF_NAME.p_wr_req),\
  .p_wr_rdy_o   (IF_NAME.p_wr_rdy),\
  .l_rx_error_o (IF_NAME.rx_error),\
  .l2p_clk_p_o  (IF_NAME.l2p_clk_p),\
  .l2p_clk_n_o  (IF_NAME.l2p_clk_n),\
  .l2p_data_o   (IF_NAME.l2p_data),\
  .l2p_dframe_o (IF_NAME.l2p_dframe),\
  .l2p_valid_o  (IF_NAME.l2p_valid),\
  .l2p_edb_o    (IF_NAME.l2p_edb),\
  .l2p_rdy_i    (IF_NAME.l2p_rdy),\
  .l_wr_rdy_i   (IF_NAME.l_wr_rdy),\
  .p_rd_d_rdy_i (IF_NAME.p_rd_d_rdy),\
  .tx_error_i   (IF_NAME.tx_error),\
  .vc_rdy_i     (IF_NAME.vc_rdy)

//the same as above but with names matching those of the BTrain SPEC reference design
`define GENNUM_WIRE_SPEC_BTRAIN_REF(IF_NAME) \
  .gn_rst_n_i      (IF_NAME.rst_n),\
  .gn_p2l_clk_p_i  (IF_NAME.p2l_clk_p),\
  .gn_p2l_clk_n_i  (IF_NAME.p2l_clk_n),\
  .gn_p2l_rdy_o    (IF_NAME.p2l_rdy),\
  .gn_p2l_dframe_i (IF_NAME.p2l_dframe),\
  .gn_p2l_valid_i  (IF_NAME.p2l_valid),\
  .gn_p2l_data_i   (IF_NAME.p2l_data),\
  .gn_p_wr_req_i   (IF_NAME.p_wr_req),\
  .gn_p_wr_rdy_o   (IF_NAME.p_wr_rdy),\
  .gn_rx_error_o   (IF_NAME.rx_error),\
  .gn_l2p_clkn_o   (IF_NAME.l2p_clk_n),\
  .gn_l2p_clkp_o   (IF_NAME.l2p_clk_p),\
  .gn_l2p_dframe_o (IF_NAME.l2p_dframe),\
  .gn_l2p_valid_o  (IF_NAME.l2p_valid),\
  .gn_l2p_edb_o    (IF_NAME.l2p_edb),\
  .gn_l2p_data_o   (IF_NAME.l2p_data),\
  .gn_l2p_rdy_i    (IF_NAME.l2p_rdy),\
  .gn_l_wr_rdy_i   (IF_NAME.l_wr_rdy),\
  .gn_p_rd_d_rdy_i (IF_NAME.p_rd_d_rdy),\
  .gn_tx_error_i   (IF_NAME.tx_error),\
  .gn_vc_rdy_i     (IF_NAME.vc_rdy),\
  .gn_gpio_b       ()
  
`endif //  `ifndef __GN4124_BFM_SVH
