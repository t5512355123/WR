//------------------------------------------------------------------------------
// CERN BE-CO-HT
// GN4124 core for PCIe FMC carrier
// http://www.ohwr.org/projects/gn4124-core
//------------------------------------------------------------------------------
//
// unit name:   main
//
// description: This is a simple example testbench, to demonstrate how to use
// the SystemVerilog BFM of the GN4124 to perform simple accesses over wishbone.
//
// The testbench simply connects the wishbone master of the GN4124 to its own
// DMA configuration wishbone slave and attaches a pre-initialised dummy RAM
// with a wishbone interface to the pipelined DMA interface in order to perform
// a DMA read.
//
//------------------------------------------------------------------------------
// Copyright CERN 2019
//------------------------------------------------------------------------------
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 2.0 (the "License"); you may not use this file except
// in compliance with the License. You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-2.0.
// Unless required by applicable law or agreed to in writing, software,
// hardware and materials distributed under this License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express
// or implied. See the License for the specific language governing permissions
// and limitations under the License.
//------------------------------------------------------------------------------

`timescale 1ns/1ps

`include "gn4124_bfm.svh"

import wishbone_pkg::*;

module main;
   reg clk_125m = 0;

   logic gn4124_irq;

   t_wishbone_master_in  wb_in, wb_dma_in, wb_mem_in;
   t_wishbone_master_out wb_out, wb_dma_out, wb_mem_out;

   always #4ns clk_125m <= ~clk_125m;

   logic rst_125m_n;

   initial begin
      rst_125m_n = 0;
      #80ns rst_125m_n = 1;
   end

   IGN4124PCIMaster i_gn4124 ();

   xwb_gn4124_core
     DUT (
	  .rst_n_a_i          (i_gn4124.rst_n),
	  .p2l_clk_p_i        (i_gn4124.p2l_clk_p),
	  .p2l_clk_n_i        (i_gn4124.p2l_clk_n),
	  .p2l_data_i         (i_gn4124.p2l_data),
	  .p2l_dframe_i       (i_gn4124.p2l_dframe),
	  .p2l_valid_i        (i_gn4124.p2l_valid),
	  .p2l_rdy_o          (i_gn4124.p2l_rdy),
	  .p_wr_req_i         (i_gn4124.p_wr_req),
	  .p_wr_rdy_o         (i_gn4124.p_wr_rdy),
	  .rx_error_o         (i_gn4124.rx_error),
	  .vc_rdy_i           (i_gn4124.vc_rdy),
	  .l2p_clk_p_o        (i_gn4124.l2p_clk_p),
	  .l2p_clk_n_o        (i_gn4124.l2p_clk_n),
	  .l2p_data_o         (i_gn4124.l2p_data),
	  .l2p_dframe_o       (i_gn4124.l2p_dframe),
	  .l2p_valid_o        (i_gn4124.l2p_valid),
	  .l2p_edb_o          (i_gn4124.l2p_edb),
	  .l2p_rdy_i          (i_gn4124.l2p_rdy),
	  .l_wr_rdy_i         (i_gn4124.l_wr_rdy),
	  .p_rd_d_rdy_i       (i_gn4124.p_rd_d_rdy),
	  .tx_error_i         (i_gn4124.tx_error),
	  .dma_irq_o          (),
	  .irq_p_i            (1'b0),
	  .irq_p_o            (gn4124_irq),
	  .status_o           (),
	  .wb_master_clk_i    (clk_125m),
	  .wb_master_rst_n_i  (rst_125m_n),
	  .wb_master_i        (wb_in),
	  .wb_master_o        (wb_out),
	  .wb_dma_cfg_clk_i   (clk_125m),
	  .wb_dma_cfg_rst_n_i (rst_125m_n),
	  .wb_dma_cfg_i       (wb_out),
	  .wb_dma_cfg_o       (wb_in),
	  .wb_dma_dat_clk_i   (clk_125m),
	  .wb_dma_dat_rst_n_i (rst_125m_n),
	  .wb_dma_dat_i       (wb_dma_in),
	  .wb_dma_dat_o       (wb_dma_out)
	  );

   xwb_dpram #
     (
      .g_size                  (32),
      .g_init_file             ("mem_init.bram"),
      .g_slave1_interface_mode (1), // 1 = PIPELINED
      .g_slave2_interface_mode (1),
      .g_slave1_granularity    (1), // 1 = WORD
      .g_slave2_granularity    (1)
      )
   MEM (
	.rst_n_i   (1'b1),
	.clk_sys_i (clk_125m),
	.slave1_i  (wb_dma_out),
	.slave1_o  (wb_dma_in),
	.slave2_i  (wb_mem_out),
	.slave2_o  (wb_mem_in)
	);

   CBusAccessor acc;

   task val_check(string name, uint64_t addr, val, expected);
      if (val != expected)
	begin
	   $display();
	   $display("Simulation FAILED");
	   $fatal(1, "%s error at address 0x%.2x. Expected 0x%.8x, got 0x%.8x",
		  name, addr, expected, val);
	end
      $display("%s at address 0x%.2x: 0x%.8x [OK]",
	       name, addr, val);
   endtask // val_check

   task reg_check(uint64_t addr, expected);
      uint64_t val;
      acc.read(addr, val);
      val_check("Register read-back", addr, val, expected);
   endtask // reg_check

   initial begin

      uint64_t addr, val, expected;

      @(posedge i_gn4124.ready);

      acc = i_gn4124.get_accessor();

      acc.set_default_xfer_size(4);

      @(posedge clk_125m);

      // Verify simple read/writes over wishbone
      reg_check('h0, 'h0);

      acc.write('h10, 'hffacce55);
      acc.write('h20, 'h1badcafe);

      reg_check('h10, 'hffacce55);
      reg_check('h20, 'h1badcafe);

      // Reset all DMA config registers
      for (addr = 'h00; addr <= 'h20; addr += 4)
	begin
	   acc.write(addr, 'h0);
	end

      // Perform 32 reads over DMA
      acc.write('h14, 'h80);
      acc.write('h00, 'h01);

      // Check values read from memory
      @(posedge i_gn4124.l2p_valid); // skip header
      @(posedge i_gn4124.l2p_valid);

      for (addr = 'h20; addr > 'h00; addr -= 1)
	begin
	   expected = 64'h80000000 + addr - 1;
	   val = i_gn4124.l2p_data;
	   @(posedge i_gn4124.l2p_clk_n);
	   val |= i_gn4124.l2p_data << 16;
	   val_check("DMA read-back", 'h20-addr, val, expected);
	   @(posedge i_gn4124.l2p_clk_p);
	end

      #1us;

      $display();
      $display("Simulation PASSED");

      $finish;

   end


endmodule // main
