`timescale 10fs/10fs

`include "simdrv_defs.svh"
`include "8b10b_encoder.svh"

`timescale 10fs/10fs

module wr_1000basex_phy_tx_path_model
  (
   input 	clk_ref_i,
   input 	rst_n_i,

   input [15:0] tx_data_i,
   input [1:0] 	tx_k_i,
   input [19:0] tx_raw_i,
   input tx_is_raw_i,
   output 	tx_disparity_o,
   

   output reg 	tx_o,
   output reg 	rdy_o
   );

   time       t_prev, t_cur, t_delta, t_delta_prev;
   int 	      stab_cnt;

   reg 	      pll_en = 0;
   int 	      pll_stab_count = 0;
   
   const int  c_pll_lock_thr = 100;
   
   reg 	      clk_tx = 0;
   
   function bit[31:0] f_reverse(bit[31:0] x, int n);

      bit [31:0] rv;
      int 	 i;
      
      for(i=0;i<n;i++)
	rv[n-1-i]=x[i];
      return rv;
   endfunction // f_reverse
   
   always@(posedge clk_ref_i)
     if(pll_en)
       begin
	  automatic int i;
	  for(i=0;i<20; i++)
	  begin
	     clk_tx <= 1;
	     #(t_delta / 40);
	     clk_tx <= 0;
	     #(t_delta / 40);
	  end
       end
   
   
   always@(posedge clk_ref_i or negedge rst_n_i)
     if (!rst_n_i)
       begin
	  pll_stab_count <= 0;
	  pll_en <= 0;
	  end else     begin
	t_prev = t_cur;
	t_cur = $time;
	t_delta = t_cur - t_prev;
	t_delta_prev = t_delta;
	
	     if(t_delta_prev == t_delta && t_delta > 1ns)
	       begin
		  if( pll_stab_count < c_pll_lock_thr)
		    pll_stab_count <= pll_stab_count + 1;
		  else
		    pll_en <= 1;
		  
	       end else begin
		  pll_stab_count <= 0;
		  pll_en <= 0;
		  
	       end
	  end // else: !if(!rst_n_i)


   assign rdy_o = pll_en;
   
   reg [19:0] tx_d;
   reg [19:0] tx_sreg;
   int 	      tx_bit_count = 0;
   reg 	      clk_ref_d = 0;

   wire [19:0] tx_raw_rev ;
   
   assign tx_raw_rev[19:10] = f_reverse(tx_raw_i[19:10], 10);
   assign tx_raw_rev[9:0] = f_reverse(tx_raw_i[9:0], 10);

   wire [19:0] tx_d_mux = tx_is_raw_i ? tx_raw_rev : tx_d;
   
   
   always@(posedge clk_tx)
     begin
	clk_ref_d <= clk_ref_i;
	
	if(!clk_ref_d && clk_ref_i)
	  begin
	     $display("Tx %b", tx_d_mux);
	     tx_sreg <= tx_d_mux;
	     tx_bit_count <= 1;
	     tx_o <= tx_d_mux[0];
	  end else begin
	     tx_bit_count <= tx_bit_count + 1;
	     tx_o <= tx_sreg[tx_bit_count];
	  end
     end
   

   wire [19:0] encoded;
   reg 	       cur_disp = 0;
   reg 	       tmp_disp;
   
   
   always@(posedge clk_tx)
     begin
	f_8b10b_encode ( {tx_k_i[0], tx_data_i[7:0] }, cur_disp, tx_d[19:10], tmp_disp );
	f_8b10b_encode ( {tx_k_i[1], tx_data_i[15:8] }, tmp_disp, tx_d[9:0], cur_disp );
	
     end

   assign tx_disparity_o = cur_disp;

endmodule // phy_tx_path_model



module wr_1000basex_phy_rx_path_model
  (
   input 	     clk_ref_i,
   input 	     rst_n_i,

   output reg [15:0] rx_data_o,
   output reg [1:0]  rx_k_o,
   output reg 	     rx_error_o,
   output reg [4:0]  rx_bitslide_o,
   output rx_rbclk_o,

   
   input 	     rx_i,
   output 	     rdy_o
   );

   reg 	 clk_rx_ser = 0;
   
   
   parameter time g_bit_time = 800ps;
   parameter time g_bit_time_tollerance = 0.05ns;
   parameter time g_pll_resolution = 10ps;
      
   time       t_prev, t_cur, t_delta, t_delta_prev, t_bit_time;

   int 	      bit_time_valid_cnt = 0;
   reg 	      bit_time_ok = 0;
   
   
   always@(posedge rx_i or negedge rx_i)
     if (!rst_n_i)
       begin
	  bit_time_valid_cnt <= 0;
	  bit_time_ok <= 0;
	  
       end else     begin
	  t_prev = t_cur;
	  t_cur = $time;
	  t_delta = t_cur - t_prev;

	  if(t_delta > g_bit_time - g_bit_time_tollerance && t_delta < g_bit_time + g_bit_time_tollerance )
	    begin

	       t_bit_time = t_delta;
	       //$display("BitTime: %t %d", t_bit_time, bit_time_ok);
	       
	       if(bit_time_valid_cnt == 1000)
		 bit_time_ok <= 1;
	       else
		 bit_time_valid_cnt++;
	       
	    end
       end // else: !if(!rst_n_i)


   assign rdy_o = 1;
   
   
   reg rx_d = 0;
   
   always #(g_pll_resolution)
     rx_d <= rx_i;
   
   always begin
      if(bit_time_ok)
	begin
	   if(rx_d != rx_i)
	     begin
		clk_rx_ser <= 0;
		#1;
	     end

	   #(t_bit_time/2);
	   clk_rx_ser <= 1;
	   #(t_bit_time/2);
	   clk_rx_ser <= 0;
	end else // if (bit_time_ok)
	  #(g_pll_resolution);
   end // always


   reg [19:0] rx_sreg;

   reg 	      clk_rx_par = 0;
   int 	      clk_par_div_cnt = 0;
   
   
   always@(posedge clk_rx_ser)
     begin
	rx_sreg <= {rx_sreg[18:0], rx_i};

//	$display("rxsreg %b", rx_sreg);
	
	if(rx_sreg[19:10] == 10'b0011111010 || rx_sreg[19:10] == ~10'b0011111010)
	  begin
//	     $display("Comma!");
	     clk_par_div_cnt <= 2;
	  end else if(clk_par_div_cnt == 19)
	    clk_par_div_cnt <= 0;
	  else
	    clk_par_div_cnt <= clk_par_div_cnt + 1;
     end // always@ (posedge clk_rx_ser)

   always@(posedge clk_rx_ser)
     clk_rx_par <= (clk_par_div_cnt < 10 ? 1'b1 : 1'b0);
   

   reg cur_disp = 0;


   function bit[9:0] f_reverse(bit[9:0] d);
      return {d[0], d[1], d[2], d[3], d[4], d[5], d[6], d[7], d[8], d[9]};
   endfunction // f_reverse
   
     
   
   always@(posedge clk_rx_par)
     if(!rst_n_i)
       begin
	  cur_disp <= 0;
       end else begin
	  automatic logic tmp_disp, code_err, disp_err;
	  automatic logic [8:0] rx_out1, rx_out2;
	  
	  f_8b10b_decode( f_reverse(rx_sreg[19:10]), cur_disp, rx_out1, tmp_disp, code_err, disp_err);
	  f_8b10b_decode( f_reverse(rx_sreg[9:0]), tmp_disp, rx_out2, cur_disp, code_err, disp_err);

	  rx_k_o <= {rx_out1[8], rx_out2[8]};
	  rx_data_o <= {rx_out1[7:0], rx_out2[7:0]};
	  rx_error_o <= 0;
	  rx_bitslide_o <= 0;
	 
       end // else: !if(!rst_n_i)

   assign rx_rbclk_o = clk_rx_par;
   
endmodule

module wr_1000basex_phy_model
(
    // Reference 62.5 MHz clock input for the TX/RX logic (not the GTX itself)
 input 	       clk_ref_i,
 input [15:0]  tx_data_i,
 input [1:0]   tx_k_i,
 output        tx_disparity_o,
 output        tx_enc_err_o,
 input [19:0]  tx_raw_i,
 input 	       tx_is_raw_i,

 
 output        rx_rbclk_o,
 output [15:0] rx_data_o,
 output [1:0]  rx_k_o,

 output        rx_enc_err_o,
 output [4:0]  rx_bitslide_o,

 input 	       rst_i,
 input 	       loopen_i,

 output        pad_txn_o,
 output        pad_txp_o,

 input 	       pad_rxn_i,
 input 	       pad_rxp_i,
    
 output rdy_o
    );


   wire ser_tx, ser_rx, ready_tx, ready_rx;

   assign rdy_o = ready_tx & ready_rx;

   wr_1000basex_phy_tx_path_model U_TX 
     (
      .clk_ref_i(clk_ref_i),
      .rst_n_i(~rst_i),
      .tx_raw_i(tx_raw_i),
      .tx_is_raw_i(tx_is_raw_i),
      .tx_data_i(tx_data_i),
      .tx_k_i(tx_k_i),
      .tx_disparity_o(tx_disparity_o),
      .tx_o(ser_tx),
      .rdy_o(ready_tx)
   );



   wr_1000basex_phy_rx_path_model U_RX
     (
      .clk_ref_i(clk_ref_i),
      .rst_n_i(~rst_i),

      .rx_data_o(rx_data_o),
      .rx_k_o(rx_k_o),
      .rx_error_o(rx_enc_err_o),
      .rx_bitslide_o(rx_bitslide_o),
      .rx_rbclk_o(rx_rbclk_o),

   
      .rx_i(ser_rx),
      .rdy_o(ready_rx)
   );


   assign ser_rx = loopen_i ? ser_tx : pad_rxp_i;

   assign pad_txp_o = loopen_i == 1'b1 ? 1'bz : ser_tx;
   assign pad_txn_o = loopen_i == 1'b1 ? 1'bz : ~ser_tx;
   
   
endmodule // wr_1000basex_phy_model

