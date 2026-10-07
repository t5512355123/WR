/*
--------------------------------------------------------------------------------
-- CERN BE-CO-HT
-- uRV - a tiny and dumb RISC-V core
-- https://www.ohwr.org/projects/urv-core
--------------------------------------------------------------------------------
--
-- unit name:   urv_multiply
--
-- description: uRV multiplication unit
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

`ifdef URV_PLATFORM_SPARTAN6

module urv_mult18x18
  (
   input 	 clk_i,
   input 	 rst_i,

   input 	 stall_i,

   input [17:0]  x_i,
   input [17:0]  y_i,

   output [35:0] q_o
   );

   DSP48A1 #(
	     .A0REG(0),
	     .A1REG(0),
	     .B0REG(0),
	     .B1REG(0),
	     .CARRYINREG(0),
	     .CARRYINSEL("OPMODE5"),
	     .CARRYOUTREG(0),
	     .CREG(0),
	     .DREG(0),
	     .MREG(1),
	     .OPMODEREG(0),
	     .PREG(0),
	     .RSTTYPE("SYNC")
	     ) D1 (
		   .BCOUT(),
		   .PCOUT(),
		   .CARRYOUT(),
		   .CARRYOUTF(),
		   .M(q_o),
		   .P(),
		   .PCIN(),
		   .CLK(clk_i),
		   .OPMODE(8'd1),
		   .A(x_i),
		   .B(y_i),
		   .C(48'h0),
		   .CARRYIN(),
		   .D(18'b0),
		   .CEA(1'b1),
		   .CEB(1'b1),
		   .CEC(1'b1),
		   .CECARRYIN(1'b0),
		   .CED(1'b0),
		   .CEM(~stall_i),
		   .CEOPMODE(1'b0),
		   .CEP(1'b1),
		   .RSTA(rst_i),
		   .RSTB(rst_i),
		   .RSTC(1'b0),
		   .RSTCARRYIN(1'b0),
		   .RSTD(1'b0),
		   .RSTM(rst_i),
		   .RSTOPMODE(1'b0),
		   .RSTP(1'b0)
		   );

   /// Silence Xilinx unisim DSP48A1 warnings about invalid OPMODE
   // synthesis translate_off
   initial force D1.OPMODE_dly = 8'd1;
   // synthesis translate_on


endmodule // urv_mult18x18
`endif //  `ifdef PLATFORM_SPARTAN6


`ifdef URV_PLATFORM_GENERIC
module urv_mult18x18
  (
   input 	 clk_i,
   input 	 rst_i,

   input 	 stall_i,

   input signed [17:0]  x_i,
   input signed [17:0]  y_i,

   output reg signed [35:0] q_o
   );


   always@(posedge clk_i)
     if(!stall_i)
       q_o <= x_i * y_i;

endmodule // urv_mult18x18
`endif //  `ifdef URV_PLATFORM_GENERIC

`ifdef URV_PLATFORM_ALTERA

module urv_mult18x18
  (
   input 	 clk_i,
   input 	 rst_i,

   input 	 stall_i,

   input [17:0]  x_i,
   input [17:0]  y_i,

   output [35:0] q_o
   );


   lpm_mult multiplier (
			.clock (clk_i),
			.dataa (x_i),
			.datab (y_i),
			.result (q_o),
			.aclr (1'b0),
			.clken (!stall_i),
			.sum (1'b0));
   defparam
     multiplier.lpm_hint = "DEDICATED_MULTIPLIER_CIRCUITRY=YES,MAXIMIZE_SPEED=5",
     multiplier.lpm_pipeline = 1,
     multiplier.lpm_representation = "SIGNED",
     multiplier.lpm_type = "LPM_MULT",
     multiplier.lpm_widtha = 18,
     multiplier.lpm_widthb = 18,
     multiplier.lpm_widthp = 36;

endmodule // urv_mult18x18


`endif


module urv_multiply
  (
   input 	     clk_i,
   input 	     rst_i,
   input 	     x_stall_i,
   input 	     x_kill_i,
   output 	     x_stall_req_o,
   
   input [31:0]      d_rs1_i,
   input [31:0]      d_rs2_i,
   input [2:0] 	     d_fun_i,
   input 	     d_is_multiply_i,

// multiply result for MUL instructions, bypassed to W-stage to achieve 1-cycle performance
// without much penalty on clock speed
   output [31:0]     w_rd_o,

// multiply result for MULH(S)(U) instructions. Goes to the X stage
// destination value mux.
   output reg [31:0] x_rd_o
   );

   parameter g_with_hw_mulh = 0;

   wire[17:0] xl_u = {1'b0, d_rs1_i[16:0] }; // 17 bits
   wire[17:0] yl_u = {1'b0, d_rs2_i[16:0] };


   wire       sign_extend_xh = (d_fun_i == `FUNC_MULH || d_fun_i == `FUNC_MULHSU) ? d_rs1_i[31] : 1'b0 ;
   wire       sign_extend_yh = (d_fun_i == `FUNC_MULH)  ? d_rs2_i[31] : 1'b0 ;
   
   wire signed [17:0] xh = { {3{sign_extend_xh}}, d_rs1_i[31:17] }; // 15 bits
   wire signed [17:0] yh = { {3{sign_extend_yh}}, d_rs2_i[31:17] };

   wire signed [35:0] 	      xh_yh;
   wire signed [35:0] yl_xl, yl_xh, yh_xl;

   wire              mul_stall_req;
   reg 		     mul_stall_req_d0;
   reg 		     mul_stall_req_d1;


   urv_mult18x18 mul0
     (
      .clk_i(clk_i),
      .rst_i(rst_i),
      .stall_i(1'b0),

      .x_i(xl_u),
      .y_i(yl_u),
      .q_o(yl_xl)
      );

     urv_mult18x18 mul1
     (
      .clk_i(clk_i),
      .rst_i(rst_i),
      .stall_i(1'b0),

      .x_i(xl_u),
      .y_i(yh),
      .q_o(yh_xl)
      );

      urv_mult18x18 mul2
     (
      .clk_i(clk_i),
      .rst_i(rst_i),
      .stall_i(1'b0),

      .x_i(yl_u),
      .y_i(xh),
      .q_o(yl_xh)
      );

   generate
      if (g_with_hw_mulh)
	begin

	   urv_mult18x18 mul3
	     (
	      .clk_i(clk_i),
	      .rst_i(rst_i),
	      .stall_i(1'b0),

	      .x_i(yh),
	      .y_i(xh),
	      .q_o(xh_yh)
	      );
	end
   endgenerate

   wire [63:0] 	     mul_result;

   wire [63:0] 	     yl_xl_ext = yl_xl;
   wire [63:0] 	     yh_xl_ext = { {15{yh_xl[35] } }, yh_xl, 17'h0 };
   wire [63:0] 	     yl_xh_ext = { {15{yl_xh[35] } }, yl_xh, 17'h0 };
   wire [63:0] 	     yh_xh_ext = { xh_yh, 34'h0 };
   
   generate
      if (g_with_hw_mulh)
	begin
	   assign mul_result = yl_xl_ext + yh_xl_ext + yl_xh_ext + yh_xh_ext;
	   
	   assign mul_stall_req = !x_kill_i && !mul_stall_req_d1 && d_is_multiply_i && d_fun_i != `FUNC_MUL;

	   always@(posedge clk_i)
	     x_rd_o <= mul_result[63:32]; 
	   
	   always@(posedge clk_i)
	     if (rst_i)
	       begin
		  mul_stall_req_d0 <= 0;
		  mul_stall_req_d1 <= 0;
	       end else begin
		  mul_stall_req_d0 <= mul_stall_req;
		  mul_stall_req_d1 <= mul_stall_req_d0;
	       end
	end

      else // no hardware multiply high
	begin
	   assign mul_result = yl_xl + {yl_xh[14:0], 17'h0} + {yh_xl[14:0], 17'h0};

	   assign mul_stall_req = 1'b0;
	end // else: !if(g_with_hw_mulh)
      
   endgenerate

   assign x_stall_req_o = mul_stall_req;
   
   assign w_rd_o = mul_result[31:0];

endmodule // urv_multiply
