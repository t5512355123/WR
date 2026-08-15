/*
--------------------------------------------------------------------------------
-- CERN BE-CO-HT
-- uRV - a tiny and dumb RISC-V core
-- https://www.ohwr.org/projects/urv-core
--------------------------------------------------------------------------------
--
-- unit name:   urv_exec
--
-- description: uRV CPU: instruction execute stage
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

module urv_exec
  (
   input 	     clk_i,
   input 	     rst_i,

   input 	     x_stall_i,
   input 	     x_kill_i,
   output reg 	     x_stall_req_o,

   //  Unfixable ecc error
   output reg        x_fault_o,

   input [31:0]      d_pc_i,
   input [4:0] 	     d_rd_i,
   input [2:0] 	     d_fun_i,


   input [31:0]      rf_rs1_value_i,
   input [31:0]      rf_rs2_value_i,
   input 	     rf_rs1_ecc_err_i,
   input 	     rf_rs2_ecc_err_i,

   input 	     d_valid_i,

   input [4:0] 	     d_opcode_i,
   input 	     d_shifter_sign_i,

   input 	     d_is_csr_i,
   input 	     d_is_mret_i,
   input 	     d_is_ebreak_i,
   input 	     d_dbg_mode_i,
   input [4:0] 	     d_csr_imm_i,
   input [11:0]      d_csr_sel_i,

   input [31:0]      d_imm_i,
   input 	     d_is_signed_alu_op_i,
   input 	     d_is_add_i,
   input 	     d_is_load_i,
   input 	     d_is_store_i,
   input 	     d_is_divide_i,
   input 	     d_is_multiply_i,
   input 	     d_is_undef_i,
   input 	     d_is_write_ecc_i,
   input 	     d_is_fix_ecc_i,

   input [31:0]      d_alu_op1_i,
   input [31:0]      d_alu_op2_i,

   input 	     d_use_op1_i,
   input 	     d_use_op2_i,

   input 	     d_use_rs1_i,
   input 	     d_use_rs2_i,

   input [2:0] 	     d_rd_source_i,
   input 	     d_rd_write_i,

   output reg [31:0] f_branch_target_o,
   output 	     f_branch_take_o,
   output reg 	     f_dbg_toggle_o,

   input 	     irq_i,

   // Writeback stage I/F
   output reg [2:0 ] w_fun_o,
   output reg 	     w_load_o,
   output reg 	     w_store_o,

   output reg 	     w_valid_o,
   output reg [4:0]  w_rd_o,
   output reg [31:0] w_rd_value_o,
   output reg 	     w_rd_write_o,
   output reg [31:0] w_dm_addr_o,
   output reg [1:0]  w_rd_source_o,
   output [31:0]     w_rd_shifter_o,
   output [31:0]     w_rd_multiply_o,
   output reg [1:0]  w_ecc_flip_o,


   // Data memory I/F (address/store)
   output [31:0]     dm_addr_o,
   output [31:0]     dm_data_s_o,
   output [3:0]      dm_data_select_o,
   output 	     dm_store_o,
   output 	     dm_load_o,

   input [39:0]      csr_time_i,
   input [39:0]      csr_cycles_i,
   input 	     timer_tick_i,

   //  Debug mailboxes.
   input [31:0]      dbg_mbx_data_i,
   input 	     dbg_mbx_write_i,
   output [31:0]     dbg_mbx_data_o
   );

   parameter g_with_hw_mul = 0;
   parameter g_with_hw_div = 0;
   parameter g_with_hw_debug = 0;

   //  Use rs1 and rs2, it's shorter; but keep long name for the ports.
   wire [31:0] 	 rs1, rs2;
   assign rs1 = rf_rs1_value_i;
   assign rs2 = rf_rs2_value_i;

   wire [31:0]   alu_op1, alu_op2;
   reg [31:0] 	 alu_result, rd_value;

   reg           x_exception;
   reg [3:0]     x_exception_cause;
   reg           x_interrupt;
   reg 		 branch_take;
   reg 		 branch_condition_met;

   reg [31:0] 	 branch_target;

   wire [31:0]   dm_addr;
   reg [31:0]    dm_data_s;
   reg [3:0]     dm_select_s;

   // Comparator
   wire [32:0] 	 cmp_op1 = { d_is_signed_alu_op_i ? rs1[31] : 1'b0, rs1 };
   wire [32:0] 	 cmp_op2 = { d_is_signed_alu_op_i ? rs2[31] : 1'b0, rs2 };
   wire [32:0] 	 cmp_rs = cmp_op1 - cmp_op2;
   wire 	 cmp_equal = (cmp_op1 == cmp_op2);
   wire 	 cmp_lt = cmp_rs[32];

   reg 		 f_branch_take;

   wire [31:0] 	 rd_csr;
   wire [31:0] 	 rd_mulh;

   wire [31:0] 	 csr_mie, csr_mip, csr_mepc, csr_mstatus,csr_mcause;
   wire [31:0] 	 csr_write_value;
   wire [31:0]   exception_address;
   wire [31:0]   exception_pc;
   wire          irq_pending;
   wire          timer_pending;

   urv_csr
     #(
       .g_with_hw_debug(g_with_hw_debug)
      )
     csr_regs
     (

      .clk_i(clk_i),
      .rst_i(rst_i),

      .x_stall_i(x_stall_i),
      .x_kill_i(x_kill_i),

      .d_is_csr_i(d_is_csr_i),
      .d_fun_i(d_fun_i),
      .d_csr_imm_i(d_csr_imm_i),
      .d_csr_sel_i (d_csr_sel_i),

      .d_rs1_i(rs1),

      .x_rd_o(rd_csr),
      .x_csr_write_value_o(csr_write_value),

      .csr_time_i(csr_time_i),
      .csr_cycles_i(csr_cycles_i),

      .csr_mstatus_i(csr_mstatus),
      .csr_mip_i(csr_mip),
      .csr_mie_i(csr_mie),
      .csr_mepc_i(csr_mepc),
      .csr_mcause_i(csr_mcause),

      .dbg_mbx_data_i(dbg_mbx_data_i),
      .dbg_mbx_write_i(dbg_mbx_write_i),
      .dbg_mbx_data_o(dbg_mbx_data_o)
      );

   urv_exceptions exception_unit
     (
      .clk_i(clk_i),
      .rst_i(rst_i),

      .x_stall_i (x_stall_i),
      .x_kill_i (x_kill_i),

      .d_is_csr_i(d_is_csr_i),
      .d_is_mret_i (d_is_mret_i),
      .d_csr_imm_i(d_csr_imm_i),
      .d_csr_sel_i(d_csr_sel_i),
      .x_csr_write_value_i(csr_write_value),

      .exp_irq_i(irq_i),
      .exp_tick_i(timer_tick_i),
      .exp_ei_pending_o(irq_pending),
      .exp_ti_pending_o(timer_pending),

      .x_exception_i(x_exception),
      .x_exception_cause_i(x_exception_cause),
      .x_interrupt_i(x_interrupt),
      .x_exception_pc_i(exception_pc),
      .x_exception_pc_o(exception_address),

      .csr_mstatus_o(csr_mstatus),
      .csr_mip_o(csr_mip),
      .csr_mie_o(csr_mie),
      .csr_mepc_o(csr_mepc),
      .csr_mcause_o(csr_mcause)
      );


   // branch condition decoding
   always@*
     case (d_fun_i) // synthesis parallel_case full_case
       `BRA_EQ:  branch_condition_met <= cmp_equal;
       `BRA_NEQ: branch_condition_met <= ~cmp_equal;
       `BRA_GE:  branch_condition_met <= ~cmp_lt | cmp_equal;
       `BRA_LT:  branch_condition_met <= cmp_lt;
       `BRA_GEU: branch_condition_met <= ~cmp_lt | cmp_equal;
       `BRA_LTU: branch_condition_met <= cmp_lt;
       default:  branch_condition_met <= 0;
     endcase // case (d_fun_i)

   // calculate branch target address
   always@*
     if (d_is_mret_i)
       branch_target <= exception_address;
     else if (x_exception)
       branch_target <= `URV_TRAP_VECTOR;
     else if (d_is_ebreak_i && g_with_hw_debug)
       branch_target <= d_pc_i;
     else
       branch_target <= d_imm_i + (d_opcode_i == `OPC_JALR ? rs1 : d_pc_i);

   // decode ALU operands
   assign alu_op1 = d_use_op1_i ? d_alu_op1_i : rs1;
   assign alu_op2 = d_use_op2_i ? d_alu_op2_i : rs2;

   //  Sign extension
   wire [32:0] alu_addsub_op1 = {d_is_signed_alu_op_i ? alu_op1[31] : 1'b0, alu_op1 };
   wire [32:0] alu_addsub_op2 = {d_is_signed_alu_op_i ? alu_op2[31] : 1'b0, alu_op2 };

   // ALU adder/subtractor
   wire [32:0]  alu_add = alu_addsub_op1 + alu_addsub_op2;
   wire [32:0] 	alu_sub = alu_addsub_op1 - alu_addsub_op2;

   // the rest of the ALU
   // FIXECC and WRECC uses 'fun' bits used by shift
   always@*
     case (d_fun_i)
       `FUNC_ADD:    alu_result <= d_is_add_i ? alu_add[31:0] : alu_sub[31:0];
       `FUNC_XOR:    alu_result <= alu_op1 ^ alu_op2;
       `FUNC_OR:     alu_result <= alu_op1 | alu_op2;
       `FUNC_AND:    alu_result <= alu_op1 & alu_op2;
       `FUNC_FIXECC: alu_result <= rf_rs1_ecc_err_i ? alu_op2 : alu_op1;
       `FUNC_WRECC:  alu_result <= alu_op1;
       `FUNC_SLT,
	 `FUNC_SLTU: alu_result <= {31'b0, alu_sub[32]};
       default:      alu_result <= 32'hx;
     endcase // case (d_fun_i)

   // barel shifter
   urv_shifter shifter
     (
      .clk_i(clk_i),
      .rst_i(rst_i),

      .x_stall_i(x_stall_i),
      .d_valid_i(d_valid_i),
      .d_rs1_i(rs1),
      .d_shamt_i(alu_op2[4:0]),
      .d_fun_i(d_fun_i),
      .d_shifter_sign_i(d_shifter_sign_i),

      .w_rd_o(w_rd_shifter_o)
      );

   wire divider_stall_req;
   wire multiply_stall_req;

   generate
      if (g_with_hw_mul)
         urv_multiply
           #(
             .g_with_hw_mulh( g_with_hw_mul > 1)
            )
           multiplier
           (
            .clk_i(clk_i),
            .rst_i(rst_i),
            .x_stall_i(x_stall_i),
            .x_kill_i(x_kill_i),
            .x_stall_req_o(multiply_stall_req),

            .d_rs1_i(rs1),
            .d_rs2_i(rs2),
            .d_fun_i(d_fun_i),
            .d_is_multiply_i(d_is_multiply_i),
            .w_rd_o (w_rd_multiply_o),
            .x_rd_o (rd_mulh)
            );
      else begin
         assign multiply_stall_req = 0;
         assign w_rd_multiply_o = 0;
      end
   endgenerate

   wire [31:0] rd_divide;

   generate
      if(g_with_hw_div)
	urv_divide divider
	  (
	   .clk_i(clk_i),
	   .rst_i(rst_i),
	   .x_stall_i(x_stall_i),
	   .x_kill_i(x_kill_i),
	   .x_stall_req_o(divider_stall_req),

	   .d_valid_i(d_valid_i),
	   .d_is_divide_i(d_is_divide_i),

	   .d_rs1_i(rs1),
	   .d_rs2_i(rs2),

	   .d_fun_i(d_fun_i),

	   .x_rd_o(rd_divide)
	   );
      else
	assign divider_stall_req = 1'b0;
   endgenerate

  always@*
     case (d_rd_source_i)
       `RD_SOURCE_ALU:    rd_value <= alu_result;
       `RD_SOURCE_CSR:    rd_value <= rd_csr;
       `RD_SOURCE_DIVIDE: rd_value <= g_with_hw_div ? rd_divide : 32'hx;
       `RD_SOURCE_MULH:   rd_value <= g_with_hw_mul > 1 ? rd_mulh : 32'hx;
       default:           rd_value <= 32'hx;
     endcase

   // generate load/store address
   assign dm_addr = d_imm_i + rs1;

   reg unaligned_addr;

   always@*
     case (d_fun_i)
       `LDST_B,
       `LDST_BU:
	 unaligned_addr <= 0;

       `LDST_H,
       `LDST_HU:
	 unaligned_addr <= (dm_addr[0]);

       `LDST_L:
	 unaligned_addr <= (dm_addr[1:0] != 2'b00);
       default:
	 unaligned_addr <= 0;
     endcase // case (d_fun_i)

   // x_exception: exception due to execution
   always@*
     begin
        x_exception <= 0;
        x_interrupt <= 0;
        x_exception_cause <= 4'hx;

        if (x_stall_i || x_kill_i || !d_valid_i)
          begin
             //  If the current instruction is not valid, there is no exception.
          end
        else if (d_is_undef_i)
          begin
             x_exception <= 1;
             x_interrupt <= 0;
             x_exception_cause <= `CAUSE_ILLEGAL_INSN;
          end
	else if (!d_is_fix_ecc_i
		 && ((d_use_rs1_i && rf_rs1_ecc_err_i)
		     || (d_use_rs2_i && rf_rs2_ecc_err_i)))
	  begin
	     // Ecc error
	     x_exception <= 1;
             x_interrupt <= 0;
             x_exception_cause <= `CAUSE_ECC_ERROR;
	  end
        else if (unaligned_addr
                 && (d_opcode_i == `OPC_LOAD || d_opcode_i == `OPC_STORE))
          begin
             x_exception <= 1;
             x_interrupt <= 0;
             case (d_opcode_i)
               `OPC_LOAD:
                 x_exception_cause <= `CAUSE_UNALIGNED_LOAD;
               `OPC_STORE:
                 x_exception_cause <= `CAUSE_UNALIGNED_STORE;
               default:
                 x_exception_cause <= 4'hx;
             endcase // case (d_opcode_i)
          end
        else if (timer_pending && !d_dbg_mode_i)
          begin
             x_exception <= 1;
             x_interrupt <= 1;
             x_exception_cause <= `CAUSE_MACHINE_TIMER;
          end
        else if (irq_pending && !d_dbg_mode_i)
          begin
             x_exception <= 1;
             x_interrupt <= 1;
             x_exception_cause <= `CAUSE_MACHINE_IRQ;
          end
     end

   // generate store value/select
   always@*
     begin
	case (d_fun_i)
	  `LDST_B:
	    begin
	       dm_data_s <= { rs2[7:0], rs2[7:0], rs2[7:0], rs2[7:0] };
	       dm_select_s[0] <= (dm_addr [1:0] == 2'b00);
	       dm_select_s[1] <= (dm_addr [1:0] == 2'b01);
	       dm_select_s[2] <= (dm_addr [1:0] == 2'b10);
	       dm_select_s[3] <= (dm_addr [1:0] == 2'b11);
	    end

	  `LDST_H:
	    begin
	       dm_data_s <= { rs2[15:0], rs2[15:0] };
	       dm_select_s[0] <= (dm_addr [1] == 1'b0);
	       dm_select_s[1] <= (dm_addr [1] == 1'b0);
	       dm_select_s[2] <= (dm_addr [1] == 1'b1);
	       dm_select_s[3] <= (dm_addr [1] == 1'b1);
	    end

	  `LDST_L:
	    begin
	       dm_data_s <= rs2;
	       dm_select_s <= 4'b1111;
	    end

	  default:
	    begin
	       dm_data_s <= 32'hx;
	       dm_select_s <= 4'hx;
	    end
	endcase // case (d_fun_i)
     end

   //branch decision
   always@*
     if (x_exception)
       branch_take <= 1;
     else
       case (d_opcode_i)
	 `OPC_JAL, `OPC_JALR:
	   branch_take <= 1;
	 `OPC_BRANCH:
	   branch_take <= branch_condition_met;
         `OPC_SYSTEM:
           branch_take <= d_is_mret_i || (g_with_hw_debug && d_is_ebreak_i && !d_dbg_mode_i);
	 default:
	   branch_take <= 0;
       endcase // case (d_opcode_i)


   // generate load/store requests

   assign dm_addr_o = dm_addr;
   assign dm_data_s_o = dm_data_s;
   assign dm_data_select_o = dm_select_s;

   assign dm_load_o =  d_is_load_i & d_valid_i & !x_kill_i & !x_stall_i & !x_exception;
   assign dm_store_o = d_is_store_i & d_valid_i & !x_kill_i & !x_stall_i & !x_exception;


   // X/W pipeline registers
   always@(posedge clk_i)
     if (rst_i)
       begin
	  f_branch_take   <= 0;
          f_dbg_toggle_o <= 0;
	  w_load_o <= 0;
	  w_store_o <= 0;
	  w_ecc_flip_o <= 2'b0;
	  x_fault_o <= 0;
          //  Values so that 0 could be written to register 0.
          w_rd_value_o <= 0;
          w_rd_o <= 0;
          w_rd_source_o <= `RD_SOURCE_ALU;
          w_rd_write_o <= 1;
          w_valid_o <= 1;
       end
     else
       begin
	  if (!x_stall_i)
            begin
               // Stay valid for memory operations
               w_valid_o <= !x_exception;

	       f_branch_target_o <= branch_target;
               w_rd_o <= d_rd_i;
	       w_rd_value_o <= rd_value;
	       w_ecc_flip_o <= {2{d_is_write_ecc_i}} & rs2[1:0];
	       x_fault_o <= d_is_fix_ecc_i & rf_rs1_ecc_err_i & rf_rs2_ecc_err_i;

	       f_branch_take <= branch_take && !x_kill_i && d_valid_i;
               f_dbg_toggle_o <= g_with_hw_debug && d_is_ebreak_i && !x_kill_i && d_valid_i;
               w_rd_write_o <= d_rd_write_i && !x_kill_i && d_valid_i && !x_exception;
	       w_load_o <= d_is_load_i && !x_kill_i && d_valid_i && !x_exception;
	       w_store_o <= d_is_store_i && !x_kill_i && d_valid_i && !x_exception;

	       w_rd_source_o <= d_rd_source_i;
	       w_fun_o <= d_fun_i;
	       w_dm_addr_o <= dm_addr;
            end
        else if (divider_stall_req || multiply_stall_req)
          begin
             // Do not be valid while the mul/div is working
             w_valid_o <= 0;
          end
       end

   assign exception_pc = d_pc_i;

   assign f_branch_take_o = f_branch_take;

   // pipeline control: generate stall request signal
   always@*
   // never stall on taken branch
     if(f_branch_take)
       x_stall_req_o <= 0;
     else if(divider_stall_req || multiply_stall_req)
       x_stall_req_o <= 1;
     else
       x_stall_req_o <= 0;

endmodule // urv_exec
