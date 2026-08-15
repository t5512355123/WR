/*
--------------------------------------------------------------------------------
-- CERN BE-CO-HT
-- uRV - a tiny and dumb RISC-V core
-- https://www.ohwr.org/projects/urv-core
--------------------------------------------------------------------------------
--
-- unit name:   urv_decode
--
-- description: uRV CPU: instruction decode stage
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

module urv_decode 
(
 input 		   clk_i,
 input 		   rst_i,

 // pipeline control
 input 		   d_stall_i,
 input 		   d_kill_i,
 output 	   d_stall_req_o,

 // from Fetch stage
 input [31:0] 	   f_ir_i,
 input [31:0] 	   f_pc_i,
 input 		   f_valid_i,

 // to Register File
 output [4:0] 	   rf_rs1_o,
 output [4:0] 	   rf_rs2_o,

 // to Execute 1 stage
 output 	   x_valid_o,
 output reg [31:0] x_pc_o,

 output [4:0] 	   x_rs1_o,
 output [4:0] 	   x_rs2_o,
 output [4:0] 	   x_rd_o,
 output reg [2:0]  x_fun_o,
 output [4:0] 	   x_opcode_o,
 output reg 	   x_shifter_sign_o,
 output reg 	   x_is_signed_alu_op_o,
 output reg 	   x_is_add_o,
 output reg 	   x_is_load_o,
 output reg 	   x_is_store_o,
 output reg 	   x_is_undef_o,
 output reg 	   x_is_write_ecc_o,
 output reg 	   x_is_fix_ecc_o,
 output reg [2:0]  x_rd_source_o,
 output 	   x_rd_write_o,
 output reg [11:0] x_csr_sel_o,
 output reg [4:0]  x_csr_imm_o,
 output reg 	   x_is_csr_o,
 output reg 	   x_is_mret_o,
 output reg 	   x_is_ebreak_o,
 output reg [31:0] x_imm_o,
 output reg [31:0] x_alu_op1_o,
 output reg [31:0] x_alu_op2_o,
 output reg 	   x_use_op1_o,
 output reg 	   x_use_op2_o,
 output reg 	   x_use_rs1_o,
 output reg 	   x_use_rs2_o,
 output reg 	   x_is_divide_o,
 output reg 	   x_is_multiply_o
);

   parameter g_with_hw_div = 0;
   parameter g_with_hw_mul = 0;
   parameter g_with_hw_debug = 0;

   wire [4:0] f_rs1 = f_ir_i[19:15];
   wire [4:0] f_rs2 = f_ir_i[24:20];
   wire [4:0] f_rd = f_ir_i[11:7];

   wire [4:0] d_opcode = f_ir_i[6:2];
   wire [2:0] d_fun = f_ir_i[14:12];
	      
   reg [4:0]  x_rs1;
   reg [4:0]  x_rs2;
   reg [4:0]  x_rd;
   reg [4:0]  x_opcode;
   reg 	      x_valid;
   reg 	      x_is_shift;
   reg 	      x_rd_write;
   
   
   assign x_rs1_o = x_rs1;
   assign x_rs2_o = x_rs2;
   assign x_rd_o = x_rd;
   assign x_opcode_o = x_opcode;

   assign rf_rs1_o = f_rs1;
   assign rf_rs2_o = f_rs2;


   reg 	      load_hazard;

   wire d_is_shift = !f_ir_i[25] && (d_fun == `FUNC_SL || d_fun == `FUNC_SR) &&
	(d_opcode == `OPC_OP || d_opcode == `OPC_OP_IMM );

   reg 	x_is_mul;
   wire d_is_mul = (f_ir_i[25] && (d_fun == `FUNC_MUL || d_fun == `FUNC_MULH || d_fun == `FUNC_MULHU || d_fun == `FUNC_MULHSU) );

   // hazzard detect combinatorial logic
   always@*
     if ( x_valid && f_valid_i && ( (f_rs1 == x_rd)  || (f_rs2 == x_rd) ) && (!d_kill_i) )
       begin
	  case (x_opcode)
	    `OPC_LOAD:
	      load_hazard <= 1;
	    `OPC_OP:
              // 2 cycles instructions
	      load_hazard <= x_is_shift | x_is_mul;
	    `OPC_OP_IMM:
              // 2 cycles instructions
	      load_hazard <= x_is_shift;
	    default:
	      load_hazard <= 0;
	  endcase // case (x_opcode)
       end
     else
	 load_hazard <= 0;
   
   reg 	inserting_nop;

   // bubble insertion following a hazard (only 1 bubble).
   always@(posedge clk_i)
     if(rst_i)
       inserting_nop <= 0;
     else if (!d_stall_i)
       inserting_nop <= load_hazard && !inserting_nop;

   assign d_stall_req_o = load_hazard && !inserting_nop;

   
   assign x_valid_o = x_valid;
   
   always@(posedge clk_i)
     if(rst_i || d_kill_i )
       begin
	  x_pc_o <= 0;
	  x_valid <= 0;
       end
     else if(!d_stall_i)
       begin
	  x_pc_o <= f_pc_i;

	  if (load_hazard && !inserting_nop)
	    x_valid <= 0;
	  else
	    x_valid <= f_valid_i;

	  x_rs1 <= f_rs1;
	  x_rs2 <= f_rs2;
	  x_rd <= f_rd;
	  x_opcode <= d_opcode;
       end
   
   // ALU function decoding
   // attempt to reuse ALU for jump address generation
   always@(posedge clk_i)
     if(!d_stall_i)
       case (d_opcode)
	 `OPC_JAL, `OPC_JALR, `OPC_LUI, `OPC_AUIPC:
	   x_fun_o <= `FUNC_ADD;
	 default:
	   x_fun_o <= d_fun;
       endcase // case (f_opcode)
   
   always@(posedge clk_i)
     if(!d_stall_i)
       x_shifter_sign_o <= f_ir_i[30];

   wire[31:0] d_imm_i = { {21{ f_ir_i[31] }}, f_ir_i[30:25], f_ir_i[24:21], f_ir_i[20] };
   wire [31:0] d_imm_s = { {21{ f_ir_i[31] }}, f_ir_i[30:25], f_ir_i[11:8], f_ir_i[7] };
   wire [31:0] d_imm_b = { {20{ f_ir_i[31] }}, f_ir_i[7], f_ir_i[30:25], f_ir_i[11:8], 1'b0 };
   wire [31:0] d_imm_u = { f_ir_i[31], f_ir_i[30:20], f_ir_i[19:12], 12'h000 };
   wire [31:0] d_imm_j = { {12{f_ir_i[31]}}, 
			   f_ir_i[19:12], 
			   f_ir_i[20], f_ir_i[30:25], f_ir_i[24:21], 1'b0};

   
   reg [31:0] d_imm;
   

   // Immediate decode, comb part
   always@*
     case(d_opcode)
       `OPC_LUI, `OPC_AUIPC: d_imm <= d_imm_u;
       `OPC_OP_IMM, `OPC_LOAD: d_imm <= d_imm_i;
       `OPC_STORE: d_imm <= d_imm_s;
       `OPC_JAL: d_imm <= d_imm_j;
       `OPC_JALR: d_imm <= d_imm_i;
       `OPC_BRANCH: d_imm <= d_imm_b;
       default: d_imm <= 32'hx;
     endcase // case (opcode)

   // Immediate decode, seq part
   always@(posedge clk_i)
     if(!d_stall_i)
       x_imm_o <= d_imm;
   

   // ALU operand decoding
   always@(posedge clk_i)
     if(!d_stall_i)
       begin
	  case (d_opcode)
	    `OPC_LUI, `OPC_AUIPC: 
	      begin
		 x_alu_op1_o <= d_imm; 
		 x_use_op1_o <= 1;
	      end
	    `OPC_JAL, `OPC_JALR:
	      begin
		 x_alu_op1_o <= 4; 
		 x_use_op1_o <= 1;
	      end
	    
	    default:
	      begin
		 x_alu_op1_o <= 32'hx; 
		 x_use_op1_o <= 0;
	      end
	  endcase // case (d_opcode)

	  case (d_opcode)
	    `OPC_LUI:
	      begin
		 x_alu_op2_o <= 0;
		 x_use_op2_o <= 1;
	      end
	    `OPC_AUIPC, `OPC_JAL, `OPC_JALR:
	      begin
		 x_alu_op2_o <= f_pc_i;
		 x_use_op2_o <= 1;
	      end
	    
	    `OPC_OP_IMM:
	      begin
		 x_alu_op2_o <= d_imm;
		 x_use_op2_o <= 1;
	      end

	    default:
	      begin
		 x_alu_op2_o <= 32'hx; 
		 x_use_op2_o <= 0;
	      end
	  endcase // case (d_opcode_i)
       end // if (!d_stall_i)
   

   always@(posedge clk_i)
     if(!d_stall_i)
       case (d_opcode)
	 `OPC_JALR, `OPC_LOAD, `OPC_OP_IMM:
	   begin
	      x_use_rs1_o <= 1'b1;
	      x_use_rs2_o <= 1'b0;
	   end
	 `OPC_STORE, `OPC_BRANCH, `OPC_OP, `OPC_CUST2:
	   begin
	      x_use_rs1_o <= 1'b1;
	      x_use_rs2_o <= 1'b1;
	   end
	 `OPC_SYSTEM:
	   begin
	      x_use_rs1_o <= d_fun[2] == 1'b0 && d_fun[1:0] != 2'b0;
	      x_use_rs2_o <= 1'b0;
	   end
	 default:
	   begin
	      x_use_rs1_o <= 1'b0;
	      x_use_rs2_o <= 1'b0;
	   end
       endcase
   
   wire d_rd_nonzero = (f_rd != 0);
   
   // misc decoding
   always@(posedge clk_i)
     if(!d_stall_i)
       begin
	  x_is_shift <= d_is_shift;

	  x_is_load_o <= d_opcode == `OPC_LOAD && !load_hazard;
	  x_is_store_o <= d_opcode == `OPC_STORE && !load_hazard;

	  x_is_mul <= d_is_mul && g_with_hw_mul;

	  x_is_write_ecc_o <= d_opcode == `OPC_CUST2 && d_fun == `FUNC_WRECC;
	  x_is_fix_ecc_o <= d_opcode == `OPC_CUST2 && d_fun == `FUNC_FIXECC;

	  case (d_opcode)
	    `OPC_BRANCH:
	      x_is_signed_alu_op_o <= (d_fun == `BRA_GE || d_fun == `BRA_LT);
	    default:
	      x_is_signed_alu_op_o <= (d_fun == `FUNC_SLT);
	  endcase // case (d_opcode)

	  case (d_opcode)
	    `OPC_OP:
	      x_is_add_o <= ~f_ir_i[30];
	    `OPC_OP_IMM:
	      x_is_add_o <= 1;
	    `OPC_BRANCH:
	      x_is_add_o <= 0;
	    default:
	      x_is_add_o <= 1;
	  endcase // case (d_opcode)

	  // all multiply/divide instructions except
	  if( d_opcode == `OPC_OP && f_ir_i[25] )
	    begin
	       case (d_fun)
		 `FUNC_MUL:
		   begin
		      x_is_multiply_o <= g_with_hw_mul != 0;
		      x_is_divide_o <= 0;
		      x_is_undef_o <= g_with_hw_mul == 0;
		   end
		 `FUNC_MULH, `FUNC_MULHU, `FUNC_MULHSU:
		   begin
		      x_is_multiply_o <= g_with_hw_mul > 1;
                      x_is_divide_o <= 0;
		      x_is_undef_o <= g_with_hw_mul <= 1;
		   end

		 `FUNC_DIV, `FUNC_DIVU, `FUNC_REM, `FUNC_REMU:
		   begin
		      x_is_multiply_o <= 0;
		      x_is_divide_o <= 1;
		      x_is_undef_o <= !g_with_hw_div;
		   end

		 default:
		   begin
		      x_is_multiply_o <= 0;
		      x_is_divide_o <= 0;
		      x_is_undef_o <= 0;
		   end
		 

	       endcase // case (d_fun)
	    end else begin // if ( d_opcode == `OPC_OP && f_ir_i[25] )
	       x_is_multiply_o <= 0;
	       x_is_divide_o <= 0;
	       x_is_undef_o <= 0;
	    end // else: !if( d_opcode == `OPC_OP && f_ir_i[25] )

	  
	  if(d_is_shift)
	    x_rd_source_o <= `RD_SOURCE_SHIFTER;
	  else if (d_opcode == `OPC_SYSTEM)
	    x_rd_source_o <= `RD_SOURCE_CSR;
	  else if (d_opcode == `OPC_OP && f_ir_i[25])
	    begin
	       // mul/div
	       if( !d_fun[2] )
		 begin
		    if( d_fun == `FUNC_MUL )
		      x_rd_source_o <= `RD_SOURCE_MULTIPLY;
		    else
		      x_rd_source_o <= `RD_SOURCE_MULH;
		 end
	       
	       else
		 x_rd_source_o <= `RD_SOURCE_DIVIDE;
	    end
	  else
	    x_rd_source_o <= `RD_SOURCE_ALU;
	  
	  // rdest write value
	  case (d_opcode)
	    `OPC_OP_IMM, `OPC_OP, `OPC_JAL, `OPC_JALR, `OPC_LUI, `OPC_AUIPC:
	      x_rd_write <= d_rd_nonzero;
	    `OPC_SYSTEM:
	      x_rd_write <= d_rd_nonzero && (d_fun != 0); // CSR instructions write to RD
	    `OPC_CUST2:
	      x_rd_write <= 1'b1;
	    default:
	      x_rd_write <= 0;
	  endcase // case (d_opcode)
       end // if (!d_stall_i)
   
	
   // CSR/supervisor instructions
   always@(posedge clk_i)
	if (!d_stall_i)
	  begin
	     x_csr_imm_o <= f_ir_i[19:15];
	     x_csr_sel_o <= f_ir_i[31:20];
	     x_is_csr_o <= (d_opcode == `OPC_SYSTEM) && (d_fun != 0);
	     x_is_mret_o <= (d_opcode == `OPC_SYSTEM) && (d_fun == 0) && (f_ir_i [31:20] == `SYS_IMM_MRET);

	     if(g_with_hw_debug)
               x_is_ebreak_o <= (d_opcode == `OPC_SYSTEM) && (d_fun == 0) && (f_ir_i [31:20] == `SYS_IMM_EBREAK);
	     else
	       x_is_ebreak_o <= 1'b0;
	  end
   
   assign x_rd_write_o = x_rd_write;

endmodule // rv_decode
