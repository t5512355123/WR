/*
--------------------------------------------------------------------------------
-- CERN BE-CO-HT
-- uRV - a tiny and dumb RISC-V core
-- https://www.ohwr.org/projects/urv-core
--------------------------------------------------------------------------------
--
-- unit name:   urv_divide
--
-- description: uRV division unit
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

module urv_divide
  (
   input 	     clk_i,
   input 	     rst_i,

   input 	     x_stall_i,
   input 	     x_kill_i,
   output 	     x_stall_req_o,

   input 	     d_valid_i,
   input 	     d_is_divide_i,

   input [31:0]      d_rs1_i,
   input [31:0]      d_rs2_i,

   input [2:0] 	     d_fun_i,

   output reg [31:0] x_rd_o
   );

   reg [31:0] 	     q,r,n,d;
   reg 		     n_sign, d_sign;
   reg [5:0] 	     state;

   wire [32:0] 	     alu_result;


   reg [31:0] 	     alu_op1;
   reg [31:0] 	     alu_op2;

   reg 		     is_rem;

   wire [31:0] r_next = { r[30:0], n[31 - (state - 3)] };


   always@*
     case(state) // synthesis full_case parallel_case
       0: begin alu_op1 <= 'hx; alu_op2 <= 'hx; end
       1: begin alu_op1 <= 0; alu_op2 <= n; end
       2: begin alu_op1 <= 0; alu_op2 <= d; end
       35: begin alu_op1 <= 0; alu_op2 <= q; end
       36: begin alu_op1 <= 0; alu_op2 <= r; end
       default: begin alu_op1 <= r_next; alu_op2 <= d; end
     endcase // case (state)

   reg alu_sub;

   assign alu_result = alu_sub ? {1'b0, alu_op1} - {1'b0, alu_op2} : {1'b0, alu_op1} + {1'b0, alu_op2};

   wire alu_ge = ~alu_result [32];
   wire alu_eq = alu_result == 0;
   
   wire done = (is_rem ? state == 37 : state == 36 );
   wire busy = ( state != 0 && !done );
   wire start_divide = !x_kill_i && d_valid_i && d_is_divide_i && !busy;

   assign x_stall_req_o = (d_valid_i && d_is_divide_i && !done);

   always@*
     case (state) 
       1:
	 alu_sub <= n_sign;
       2:
	 alu_sub <= d_sign;
       35:
	 alu_sub <= n_sign ^ d_sign;
       36:
	 alu_sub <= n_sign;
       default:
	 alu_sub <= 1;
     endcase // case (state)

   always@(posedge clk_i)
     if(rst_i || done)
       state <= 0;
     else if (state != 0 || start_divide)
       state <= state + 1;

   reg 	is_div_by_zero;
   
   always@(posedge clk_i)
	  case ( state )
	    0:
	      if(start_divide)
		begin
		   is_div_by_zero <= 0;
		 q <= 0;
		 r <= 0;

		 is_rem <= (d_fun_i == `FUNC_REM || d_fun_i ==`FUNC_REMU);

		 n <= d_rs1_i;
		 d <= d_rs2_i;
		 
		 if( d_fun_i == `FUNC_DIVU || d_fun_i == `FUNC_REMU )
		   begin
		      n_sign <= 0;
		      d_sign <= 0;
		   end else begin
		      n_sign <= d_rs1_i[31];
		      d_sign <= d_rs2_i[31];
		   end
		 
	      end

	    1: 
		n <= alu_result[31:0];

	    2:
	      begin
		 d <= alu_result[31:0];
		 is_div_by_zero <= alu_eq && (d_fun_i == `FUNC_DIV);
	      end
	    

	    35:
	      x_rd_o <= is_div_by_zero ? -1 : alu_result; // quotient

	    36:
	      x_rd_o <= alu_result; // remainder

	    default: // 3..345 32 divider iterations
	      begin

		 q <= { q[30:0], alu_ge };
		 r <= alu_ge ? alu_result : r_next;


	      end
	  endcase // case ( state )


endmodule // rv_divide
