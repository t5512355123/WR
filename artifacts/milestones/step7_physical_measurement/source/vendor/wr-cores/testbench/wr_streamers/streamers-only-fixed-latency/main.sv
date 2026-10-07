//
// White Rabbit Core Hands-On Course
//
// Lesson 04: Simulating the streamers
//
// Objectives:
// - demonstrate packet transfers in WR Core MAC interface
// - demonstrate the user interface of tx_streamer/rx_streamer modules.
// - demonstrate latency measurement feature of the streamers
//
// Brief description:
// A continuous sequence of 64-bit numbers (counting up from 0) is streamed
// via the TX streamer, sent as Ethernet packets over WR MAC interface and decoded
// in the RX streamer module.
//

`include "simdrv_defs.svh"
`include "if_wb_master.svh"
`include "if_wb_link.svh"



`timescale 1ns/1ps

import wishbone_pkg::*;
import streamers_pkg::*;
import wr_fabric_pkg::*;


class WBModule;

protected   CBusAccessor m_bus;
protected   uint64_t m_base;

   function new(CBusAccessor bus, uint64_t base);
      m_bus = bus;
      m_base = base;
   endfunction // new

   task automatic writel(uint32_t addr, uint32_t data);
      m_bus.write(m_base + addr, data);
   endtask // writel

   task automatic readl(uint32_t addr, ref uint32_t data);
      uint64_t rv;
      m_bus.read(m_base + addr, rv);
      data = rv;
   endtask // writel
  
endclass // unmatched endclass

class StreamersDriver extends WBModule;
   function new(CBusAccessor bus, uint64_t base);
      super.new(bus, base);
   endfunction // new

   task automatic configure();
      // set fixed latency
//      writel(`ADDR_WR_STREAMERS_RX_CFG5, 10); // in periods of 8ns.
      // enable fixed latency (overide register)
  //    writel(`ADDR_WR_STREAMERS_CFG, 1<<21);
   endtask // configure

endclass // WRStreamers


module main;

   // Parameters
   
   // Size of data record to be used by the streamers - in our case, a 64-bit
   // word.
   parameter g_record_size = 64;
   parameter g_wr_cycles_per_second = 625000;
   

   
   // 16-bit data, 2-bit address Wishbone bus that connects the WR MAC interfaces
   // of both streamers
   IWishboneLink #(16, 2) mac();

   // Clock & reset
   reg clk_ref = 0;
   reg clk_sys = 0;
   reg rst = 0;

   // TX Streamer signals
   reg tx_streamer_dvalid = 0;
   reg [g_record_size-1:0] tx_streamer_data = 0;
   reg 			   tx_streamer_flush = 0;
   reg 			   tx_streamer_last = 0;
   
   wire                    tx_streamer_dreq;
   wire 		   tx_streamer_sync;
   
   // RX Streamer signals
   reg                     rx_streamer_dreq = 0;
   wire [g_record_size-1:0] rx_streamer_data;
   wire                     rx_streamer_dvalid;
   wire                     rx_streamer_lost;
   wire [27:0]              rx_latency;
   wire                     rx_latency_valid;


   // Fake White Rabbit reference clock (125 MHz) and cycle counte (we don't use 
   // TAI counter as the latency never exceeds 1 second...)

   reg [27:0]               tm_cycles = 0;
   reg [39:0] 		    tm_tai = 0;

   // Currently transmitted counter value
   int                 tx_counter = 0;

   t_rx_streamer_cfg rx_streamer_cfg;
   t_tx_streamer_cfg tx_streamer_cfg;

   t_wrf_source_out src_out;
   t_wrf_source_in src_in;

   typedef struct {
      bit [g_record_size-1:0] data;
      time 		      ts;
   } t_queue_entry;
   

   int 			      tx_delay_count = 1;
   
   
   
   initial #100 rst = 1;
   always #8ns clk_ref <= ~clk_ref;
   always #7.9ns clk_sys <= ~clk_sys;


   
   
   // transfer queue. Used to pass sent data to the verification process.
   t_queue_entry queue[$];
   
   // WR clock cycle counter
   always@(posedge clk_ref)
     if( tm_cycles == g_wr_cycles_per_second - 1 )
       begin
	  tm_cycles <= 0;
	  tm_tai <= tm_tai + 1;
       end else
	 tm_cycles <= tm_cycles + 1;
   
   
   // TX data stream generation. 
   always@(posedge clk_ref) 
     if(!rst)
       begin
          tx_streamer_dvalid <= 0;
          tx_counter <= 0;
       end else  begin
          // TX streamer is fed with a subsequent data word at random intervals (you can
          // change the probability in the condition below). New value is sent only when
          // the streamer can accept it (i.e. its tx_dreq_o output is active)

	  if(tx_delay_count > 0 )
	    tx_delay_count --;

//	  $display("txdc %d", tx_delay_count);
	  
	  
          if(tx_streamer_dreq && (tx_delay_count == 0) ) begin
	     automatic t_queue_entry qe;


	     
	     qe.data = tx_counter;
	     qe.ts = $time;

	     tx_delay_count = 300 + {$random} % 100;
	     
	     
             queue.push_back(qe);
             
             tx_streamer_data <= tx_counter;
             tx_streamer_dvalid <= 1;
	     tx_streamer_last <= 1;
	     tx_streamer_flush <= 1;
	     
             
             tx_counter++;

          end else
            tx_streamer_dvalid <= 0;
       end // if (rst)

   // Instantiation of the streamers. The TX streamer will assemble packets
   // containing max. 8 records, or flush the buffer after 512 clk cycles if
   // it contains less than 8 records to prevent latency buildup.
   xtx_streamer
     #( 
        .g_data_width   (g_record_size),
        .g_tx_threshold  (8),
        .g_tx_buffer_size(16),
        .g_tx_max_words_per_frame(16),
        .g_tx_timeout    (512),
        .g_simulation(1),
	.g_clk_ref_rate(62500000),
	.g_use_ref_clock_for_data(1),
	.g_sim_startup_cnt(100)

     ) 
   U_TX_Streamer
     (
      .clk_sys_i(clk_sys),
      .rst_n_i  (rst),
 
      .src_o  (src_out),
      .src_i (src_in),
      
      .clk_ref_i(clk_ref), // fake WR time
      .tm_time_valid_i(1'b1),
      .tm_cycles_i(tm_cycles),
      .tm_tai_i(tm_tai),

      .tx_data_i      (tx_streamer_data),
      .tx_valid_i     (tx_streamer_dvalid),
      .tx_dreq_o      (tx_streamer_dreq),

      .tx_last_p1_i( tx_streamer_last),
      .tx_flush_p1_i( tx_streamer_flush),
      .tx_sync_o(tx_streamer_sync),
      
      .tx_streamer_cfg_i(tx_streamer_cfg)
      );


  // tx config
   assign tx_streamer_cfg.ethertype = 16'hdbff;
   assign tx_streamer_cfg.mac_local = 48'hdeadbeefcafe;
   assign tx_streamer_cfg.mac_target = 48'hffffffffffff;
   assign tx_streamer_cfg.qtag_ena = 1'b0;

   assign rx_streamer_cfg.ethertype = 16'hdbff;
   assign rx_streamer_cfg.mac_local = 48'h000000000000;
   assign rx_streamer_cfg.mac_remote = 48'h000000000000;
   assign rx_streamer_cfg.accept_broadcasts = 1'b1;
   assign rx_streamer_cfg.filter_remote = 1'b0;
   assign rx_streamer_cfg.fixed_latency = 200;

   
   
   xrx_streamer
     #(
       .g_data_width        (g_record_size),
       .g_simulation(1),
	.g_clk_ref_rate(62500000),
	.g_use_ref_clock_for_data(1),
       .g_sim_cycle_counter_range(g_wr_cycles_per_second)
       )

   U_RX_Streamer 
     (
      .clk_sys_i (clk_sys),
      .rst_n_i   (rst),

      .snk_i (src_out),
      .snk_o (src_in),

      .clk_ref_i(clk_ref), // fake WR time
      .tm_time_valid_i(1'b1),
      .tm_cycles_i(tm_cycles),
      .tm_tai_i(tm_tai),
      
      .rx_data_o  (rx_streamer_data),
      .rx_valid_o (rx_streamer_dvalid),
      .rx_dreq_i  (rx_streamer_dreq),
      .rx_latency_o (rx_latency),
      .rx_latency_valid_o(rx_latency_valid),

      .rx_streamer_cfg_i(rx_streamer_cfg)
      );


   initial rx_streamer_dreq = 1'b1;
   

   
   // Client-side reception logic. Compares the received records with their copies
   // stored in the queue.
   
   always@(posedge clk_ref)
     if(!rst)
       begin
          rx_streamer_dreq <= 1;
       end else begin

          if(rx_streamer_dvalid)
            begin
               // Got a record? Compare it against the copy stored in queue.
               automatic t_queue_entry qe = queue.pop_front();
	       automatic time ts_rx = $time, delta;
	       const time c_pipeline_delay = 16ns;
	       

	       if( rx_streamer_data != qe.data )
		 begin
		    $error("Failure: got rec %x, should be %x", rx_streamer_data, qe.data);
		 end


//	       $display("Tx ts %t rx ts %t", qe.ts, ts_rx);
	       
	       delta = ts_rx - qe.ts - rx_streamer_cfg.fixed_latency * 16ns - c_pipeline_delay;
	       
	       
               $display("delta: %.3f us %t", real'(delta) / real'(1us), delta );
               
            end // if (rx_streamer_dvalid)
       end // else: !if(!rst)

   // Show the latency value when a new frame arrives
//   always@(posedge clk)
  //   if(rst && rx_latency_valid)
    //      $display("This frame's latency: %.3f microseconds\n", real'(rx_latency) * 0.008);

   
endmodule // main

