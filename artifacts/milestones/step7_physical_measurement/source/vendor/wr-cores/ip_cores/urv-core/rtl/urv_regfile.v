/*
--------------------------------------------------------------------------------
-- CERN BE-CO-HT
-- uRV - a tiny and dumb RISC-V core
-- https://www.ohwr.org/projects/urv-core
--------------------------------------------------------------------------------
--
-- unit name:   urv_regfile
--
-- description: uRV CPU: register file
--
--------------------------------------------------------------------------------
-- Copyright CERN 2015-2018
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
*/

`include "urv_defs.v"

`timescale 1ns/1ps

module urv_regmem
  #(
    parameter g_width = 32
   )
  (
   input 		    clk_i,

   input 		    en1_i,
   input [4:0] 		    a1_i,
   output reg [g_width-1:0] q1_o,

   input [4:0] 		    a2_i,
   input [g_width-1:0] 	    d2_i,
   input 		    we2_i
   );

   reg [g_width-1:0] 	    ram [0:31];

   always@(posedge clk_i)
     if(en1_i)
       q1_o <= ram[a1_i];

   always@(posedge clk_i)
     if(we2_i)
       ram[a2_i] <= d2_i;

   // synthesis translate_off
   initial begin : ram_init
      integer i;

      for(i=0;i<32; i=i+1) begin
	 ram[i] = 32'h0;
      end
   end
   // synthesis translate_on

endmodule

module urv_regfile
  #(
    parameter g_with_ecc = 0
    )
  (
   input 	     clk_i,
   input 	     rst_i,
   
   input 	     d_stall_i,

   input [4:0] 	     rf_rs1_i,
   input [4:0] 	     rf_rs2_i,

   input [4:0] 	     d_rs1_i,
   input [4:0] 	     d_rs2_i,

   output reg [31:0] x_rs1_value_o,
   output reg [31:0] x_rs2_value_o,
   output reg 	     x_rs1_ecc_err_o,
   output reg 	     x_rs2_ecc_err_o,

   input [4:0] 	     w_rd_i,
   input [31:0]      w_rd_value_i,
   input [6:0] 	     w_rd_ecc_i,
   input [1:0] 	     w_rd_ecc_flip_i,
   input 	     w_rd_store_i,

   input 	     w_bypass_rd_write_i,
   input [31:0]      w_bypass_rd_value_i
 );

   localparam g_width = 32 + (g_with_ecc ? 7 : 0);

   wire [g_width-1:0] w_rd_value_1;
   wire [g_width-1:0] w_rd_value_2;
   wire [g_width-1:0] rs1_regfile;
   wire [g_width-1:0] rs2_regfile;
   wire        write  = w_rd_store_i;

   wire        rs1_ecc_err;
   wire        rs2_ecc_err;

   //  Value to be written in the register file
   wire [g_width-1:0] w_rd_value;

   generate
      if (g_with_ecc) begin
	 assign w_rd_value_1 = {w_rd_ecc_i ^ w_rd_ecc_flip_i[0], w_rd_value_i};
	 assign w_rd_value_2 = {w_rd_ecc_i ^ w_rd_ecc_flip_i[1], w_rd_value_i};
      end
      else begin
	 assign w_rd_value_1 = w_rd_value_i;
	 assign w_rd_value_2 = w_rd_value_i;
      end
   endgenerate

   urv_regmem
     #(.g_width(g_width))
   bank1
     (
      .clk_i(clk_i),
      .en1_i(!d_stall_i),
      .a1_i(rf_rs1_i),
      .q1_o(rs1_regfile),

      .a2_i(w_rd_i),
      .d2_i(w_rd_value_1),
      .we2_i (write));

   urv_regmem
     #(.g_width(g_width))
   bank2
     (
      .clk_i(clk_i),
      .en1_i(!d_stall_i),
      .a1_i(rf_rs2_i),
      .q1_o(rs2_regfile),

      .a2_i (w_rd_i),
      .d2_i (w_rd_value_2),
      .we2_i (write)
      );

   generate
      if (g_with_ecc) begin
	 wire [6:0] 	      rs1_ecc;
	 wire [6:0] 	      rs2_ecc;
	 urv_ecc ecc_rs1
	   (.dat_i(rs1_regfile[31:0]),
	    .ecc_o(rs1_ecc));
	 urv_ecc ecc_rs2
	   (.dat_i(rs2_regfile[31:0]),
	    .ecc_o(rs2_ecc));

	 assign rs1_ecc_err = |(rs1_ecc ^ rs1_regfile[38:32]);
	 assign rs2_ecc_err = |(rs2_ecc ^ rs2_regfile[38:32]);
      end
      else begin
	 assign rs1_ecc_err = 1'b0;
	 assign rs2_ecc_err = 1'b0;
      end
   endgenerate

   wire  rs1_bypass_x = w_bypass_rd_write_i && (w_rd_i == d_rs1_i) && (w_rd_i != 0);
   wire  rs2_bypass_x = w_bypass_rd_write_i && (w_rd_i == d_rs2_i) && (w_rd_i != 0);

   reg   rs1_bypass_w, rs2_bypass_w;

   always@(posedge clk_i)
     if(rst_i)
       begin
          rs1_bypass_w <= 0;
	  rs2_bypass_w <= 0;
       end else if(!d_stall_i) begin
	  rs1_bypass_w <= write && (rf_rs1_i == w_rd_i);
	  rs2_bypass_w <= write && (rf_rs2_i == w_rd_i);
       end

   reg [31:0] 	  bypass_w;

   always@(posedge clk_i)
     if(write)
       bypass_w <= w_rd_value_i;

   always@*
     begin
	case ( {rs1_bypass_x, rs1_bypass_w } ) // synthesis parallel_case full_case
	  2'b10, 2'b11:
	    begin
	       x_rs1_value_o <= w_bypass_rd_value_i;
	       x_rs1_ecc_err_o <= 1'b0;
	    end
	  2'b01:
	    begin
	       x_rs1_value_o <= bypass_w;
	       x_rs1_ecc_err_o <= 1'b0;
	    end
	  default:
	    begin
	       x_rs1_value_o <= rs1_regfile[31:0];
	       x_rs1_ecc_err_o <= rs1_ecc_err;
	    end
	endcase // case ( {rs1_bypass_x, rs1_bypass_w } )

	case ( {rs2_bypass_x, rs2_bypass_w } ) // synthesis parallel_case full_case
	  2'b10, 2'b11:
	    begin
	       x_rs2_value_o <= w_bypass_rd_value_i;
	       x_rs2_ecc_err_o <= 1'b0;
	    end
	  2'b01:
	    begin
	       x_rs2_value_o <= bypass_w;
	       x_rs2_ecc_err_o <= 1'b0;
	    end
	  default:
	    begin
	       x_rs2_value_o <= rs2_regfile[31:0];
	       x_rs2_ecc_err_o <= rs2_ecc_err;
	    end
	endcase // case ( {rs2_bypass_x, rs2_bypass_w } )
     end // always@ *

endmodule // urv_regfile
