/*
--------------------------------------------------------------------------------
-- CERN BE-CO-HT
-- uRV - a tiny and dumb RISC-V core
-- https://www.ohwr.org/projects/urv-core
--------------------------------------------------------------------------------
--
-- unit name:   urv_csr
--
-- description: uRV CSR
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

module urv_csr
  (
   input 	     clk_i,
   input 	     rst_i,

   input 	     x_stall_i,
   input 	     x_kill_i,
   
   input 	     d_is_csr_i,
   input [2:0] 	     d_fun_i,
   input [4:0] 	     d_csr_imm_i,
   input [11:0]      d_csr_sel_i,
   
   
   input [31:0]      d_rs1_i,
   
   output [31:0]     x_rd_o,
   
   input [39:0]      csr_time_i,
   input [39:0]      csr_cycles_i,

   // interrupt management

   output [31:0]     x_csr_write_value_o,

   input [31:0]      csr_mstatus_i,
   input [31:0]      csr_mip_i,
   input [31:0]      csr_mie_i,
   input [31:0]      csr_mepc_i,
   input [31:0]      csr_mcause_i,

   //  Debug mailboxes
   input [31:0]      dbg_mbx_data_i,
   input             dbg_mbx_write_i,
   output [31:0]     dbg_mbx_data_o
   );

   parameter g_with_hw_debug = 0;
   
   reg [31:0] 	csr_mscratch; 
   reg [31:0]   mbx_data;

   reg [31:0] 	csr_in1;
   reg [31:0] 	csr_in2;
   reg [31:0] 	csr_out;

  
   always@*
     case(d_csr_sel_i) // synthesis full_case parallel_case
       `CSR_ID_CYCLESL: csr_in1 <= csr_cycles_i[31:0];
       `CSR_ID_CYCLESH: csr_in1 <= { 24'h0, csr_cycles_i[39:32] };
       `CSR_ID_TIMEL: csr_in1 <= csr_time_i[31:0];
       `CSR_ID_TIMEH: csr_in1 <= { 24'h0, csr_time_i[39:32] };
       `CSR_ID_MSCRATCH: csr_in1 <= csr_mscratch;
       `CSR_ID_MEPC: csr_in1 <= csr_mepc_i;
       `CSR_ID_MSTATUS: csr_in1 <= csr_mstatus_i;
       `CSR_ID_MCAUSE: csr_in1 <= csr_mcause_i;
       `CSR_ID_MIP: csr_in1 <= csr_mip_i;
       `CSR_ID_MIE: csr_in1 <= csr_mie_i;
       `CSR_ID_DBGMBX: csr_in1 <= g_with_hw_debug ? mbx_data : 32'h0;
       `CSR_ID_MIMPID: csr_in1 <= 32'h20190131;
       default: csr_in1 <= 32'h0;
     endcase // case (d_csr_sel_i)

   assign x_rd_o = csr_in1;

   genvar 	i;

   
   always@*
     case (d_fun_i)
       `CSR_OP_CSRRWI,
       `CSR_OP_CSRRSI,
       `CSR_OP_CSRRCI:
	 csr_in2 <= {27'b0, d_csr_imm_i };
       default:
	 csr_in2 <= d_rs1_i;
     endcase // case (d_fun_i)

   generate
      for (i=0;i<32;i=i+1) 
	begin : gen_csr_bits

	   always@*
	     case(d_fun_i) // synthesis full_case parallel_case
	       `CSR_OP_CSRRWI, 
	       `CSR_OP_CSRRW:
		 csr_out[i] <= csr_in2[i];
	       `CSR_OP_CSRRCI,
	       `CSR_OP_CSRRC:
		 csr_out[i] <= csr_in2[i] ? 1'b0 : csr_in1[i];
	       `CSR_OP_CSRRSI,
	       `CSR_OP_CSRRS:
		 csr_out[i] <= csr_in2[i] ? 1'b1 : csr_in1[i];
	       default:
		 csr_out[i] <= 32'hx;
	     endcase // case (d_csr_op_i)
	end // for (i=0;i<32;i=i+1)
   endgenerate
   
   
    always@(posedge clk_i)
     if(rst_i)
       begin
          csr_mscratch <= 0;
          mbx_data <= 0;
       end
     else
       begin
          if (dbg_mbx_write_i && g_with_hw_debug)
            mbx_data <= dbg_mbx_data_i;

          if(!x_stall_i && !x_kill_i && d_is_csr_i)
            case (d_csr_sel_i)
	      `CSR_ID_MSCRATCH:
	        csr_mscratch <= csr_out;
              `CSR_ID_DBGMBX:
		if(g_with_hw_debug)
                  mbx_data <= csr_out;
            endcase // case (d_csr_sel_i)
       end // else: !if(rst_i)

   assign dbg_mbx_data_o = mbx_data;

   assign x_csr_write_value_o = csr_out;
endmodule
