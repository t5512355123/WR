/*
--------------------------------------------------------------------------------
-- CERN BE-CO-HT
-- uRV - a tiny and dumb RISC-V core
-- https://www.ohwr.org/projects/urv-core
--------------------------------------------------------------------------------
--
-- unit name:   urv_cpu
--
-- description: uRV CPU: top-level
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

module urv_cpu
  #(
    parameter g_timer_frequency = 1000,
    parameter g_clock_frequency = 100000000,
    parameter g_with_hw_div = 1,
    parameter g_with_hw_mulh = 1, //  Force mulh if mul is > 0 (for compatibility).
    parameter g_with_hw_mul = 1,  // 0: no multiply, 1: 32x32 mul. 2: mulh
    parameter g_with_hw_debug = 0,
    parameter g_with_ecc = 0,
    parameter g_with_compressed_insns = 0
   )
   (
   input 	 clk_i,
   input 	 rst_i,

   input 	 irq_i,

   // For ECC double error
   output 	 fault_o,

   // instruction mem I/F
   output [31:0] im_addr_o,
   output 	 im_rd_o,
   input [31:0]  im_data_i,
   input 	 im_valid_i,

   // data mem I/F
   // The interface is pipelined: store/load are asserted for one cycle
   // and then store_done/load_done is awaited.
   output [31:0] dm_addr_o,
   output [31:0] dm_data_s_o,
   input [31:0]  dm_data_l_i,
   output [3:0]  dm_data_select_o,

   output 	 dm_store_o,
   output 	 dm_load_o,
   input 	 dm_load_done_i,
   input 	 dm_store_done_i,

   // Debug I/F
   // Debug mode is entered either when dbg_force_i is set, or when the ebreak
   // instructions is executed.  Debug mode is left when the ebreak instruction
   // is executed (from the dbg_insn_i port).
   // When debug mode is entered, dbg_enabled_o is set.  This may not be
   // immediate.  Interrupts are disabled in debug mode.
   // In debug mode, instructions are executed from dbg_insn_i.
   // As instructions are always fetched, they must be always valid.  Use
   // a nop (0x13) if nothing should be executed.
   input 	 dbg_force_i,
   output 	 dbg_enabled_o,
   input [31:0]  dbg_insn_i,
   input 	 dbg_insn_set_i,
   output 	 dbg_insn_ready_o,

   input [31:0]  dbg_mbx_data_i,
   input 	 dbg_mbx_write_i,
   output [31:0] dbg_mbx_data_o
   );


   // pipeline control
   wire 	 f_stall;
   wire 	 x_stall;
   wire 	 x_kill;
   wire 	 d_stall;
   wire 	 d_kill;
   wire 	 d_stall_req;
   wire 	 w_stall_req;
   wire 	 x_stall_req;

   wire 	 x_fault;

   // X1->F stage interface
   wire [31:0] 	 x2f_pc_bra;
   wire 	 x2f_bra;
   wire          x2f_dbg_toggle;

   // F->D stage interface
   wire [31:0] 	 f2d_pc, f2d_ir;
   wire 	 f2d_valid;

   // D->RF interface
   wire [4:0] 	 rf_rs1, rf_rs2;

   // X2/W->RF interface
   wire [4:0] 	 rf_rd;
   wire [31:0] 	 rf_rd_value;
   wire [6:0] 	 rf_rd_ecc;
   wire [1:0] 	 rf_rd_ecc_flip;
   wire 	 rf_rd_write;

   // D->X1 stage interface
   wire 	 d2x_valid;
   wire [31:0] 	 d2x_pc;
   wire [4:0] 	 d2x_rs1;
   wire [4:0] 	 d2x_rs2;
   wire [4:0] 	 d2x_rd;
   wire [2:0] 	 d2x_fun;
   wire [4:0] 	 d2x_opcode;
   wire 	 d2x_shifter_sign;
   wire 	 d2x_is_load, d2x_is_store, d2x_is_undef;
   wire 	 d2x_is_write_ecc;
   wire 	 d2x_is_fix_ecc;
   wire [31:0] 	 d2x_imm;
   wire 	 d2x_is_signed_alu_op;
   wire 	 d2x_is_add_o;
   wire [2:0] 	 d2x_rd_source;
   wire 	 d2x_rd_write;
   wire [11:0] 	 d2x_csr_sel;
   wire [4:0] 	 d2x_csr_imm;
   wire 	 d2x_is_csr, d2x_is_mret, d2x_is_ebreak, d2x_csr_load_en;
   wire [31:0] 	 d2x_alu_op1, d2x_alu_op2;
   wire  	 d2x_use_op1, d2x_use_op2;
   wire 	 d2x_use_rs1, d2x_use_rs2;
   wire 	 d2x_is_multiply, d2x_is_divide;

   // X1/M->X2/W interface
   wire [4:0] 	 x2w_rd;
   wire [31:0] 	 x2w_rd_value;
   wire [31:0] 	 x2w_rd_shifter;
   wire [31:0] 	 x2w_rd_multiply;
   wire [31:0] 	 x2w_dm_addr;
   wire 	 x2w_rd_write;
   wire [2:0] 	 x2w_fun;
   wire 	 x2w_store;
   wire 	 x2w_load;
   wire [1:0] 	 x2w_rd_source;
   wire 	 x2w_valid;
   wire [1:0]	 x2w_ecc_flip;

   // Register file signals
   wire [31:0] 	 x_rs2_value, x_rs1_value;
   wire 	 x_rs1_ecc_err, x_rs2_ecc_err;
   wire [31:0] 	 rf_bypass_rd_value = x2w_rd_value;
   wire  	 rf_bypass_rd_write = rf_rd_write && !x2w_load; // multiply/shift too?

   // misc stuff
   wire [39:0] 	 csr_time, csr_cycles;

   //  0: no multiply, 1: 32 bit multiply, 2: mulh.
   localparam p_with_hw_mul = g_with_hw_mul ? (g_with_hw_mul | (g_with_hw_mulh ? 2 : 0)) : 0;

   urv_fetch
    #(
      .g_with_hw_debug(g_with_hw_debug),
      .g_with_compressed_insns(g_with_compressed_insns)
      )
   fetch
     (
      .clk_i(clk_i),
      .rst_i(rst_i),

      // instruction memory
      .im_addr_o(im_addr_o),
      .im_rd_o(im_rd_o),
      .im_data_i(im_data_i),
      .im_valid_i(im_valid_i),

      // pipe control
      .f_stall_i(f_stall),

      // to D stage
      .f_valid_o(f2d_valid),
      .f_ir_o(f2d_ir),
      .f_pc_o(f2d_pc),

      // from X1 stage (jumps)
      .x_pc_bra_i(x2f_pc_bra),
      .x_bra_i(x2f_bra),

      .dbg_force_i(dbg_force_i),
      .dbg_enabled_o(dbg_enabled_o),
      .dbg_insn_i(dbg_insn_i),
      .dbg_insn_set_i(dbg_insn_set_i),
      .dbg_insn_ready_o(dbg_insn_ready_o),
      .x_dbg_toggle_i(x2f_dbg_toggle)
      );


   urv_decode
     #(
       .g_with_hw_div(g_with_hw_div),
       .g_with_hw_mul(p_with_hw_mul),
       .g_with_hw_debug(g_with_hw_debug)
       )
   decode
     (
      .clk_i(clk_i),
      .rst_i(rst_i),

      // pipe control
      .d_stall_i(d_stall),
      .d_kill_i(d_kill),
      .d_stall_req_o(d_stall_req),

      // from F stage
      .f_ir_i(f2d_ir),
      .f_pc_i(f2d_pc),
      .f_valid_i(f2d_valid),

      // to RF (regfile)
      .rf_rs1_o(rf_rs1),
      .rf_rs2_o(rf_rs2),

      // to X1 stage
      .x_valid_o(d2x_valid),
      .x_pc_o(d2x_pc),
      .x_rs1_o(d2x_rs1),
      .x_rs2_o(d2x_rs2),
      .x_use_rs1_o(d2x_use_rs1),
      .x_use_rs2_o(d2x_use_rs2),
      .x_imm_o(d2x_imm),
      .x_rd_o(d2x_rd),
      .x_fun_o(d2x_fun),
      .x_opcode_o(d2x_opcode),
      .x_shifter_sign_o(d2x_shifter_sign),
      .x_is_signed_alu_op_o(d2x_is_signed_alu_op),
      .x_is_add_o(d2x_is_add),
      .x_is_load_o(d2x_is_load),
      .x_is_store_o(d2x_is_store),
      .x_is_undef_o(d2x_is_undef),
      .x_is_write_ecc_o(d2x_is_write_ecc),
      .x_is_fix_ecc_o(d2x_is_fix_ecc),
      .x_is_multiply_o(d2x_is_multiply),
      .x_is_divide_o(d2x_is_divide),
      .x_rd_source_o(d2x_rd_source),
      .x_rd_write_o(d2x_rd_write),
      .x_csr_sel_o(d2x_csr_sel),
      .x_csr_imm_o(d2x_csr_imm),
      .x_is_csr_o(d2x_is_csr),
      .x_is_mret_o(d2x_is_mret),
      .x_is_ebreak_o(d2x_is_ebreak),
      .x_alu_op1_o(d2x_alu_op1),
      .x_alu_op2_o(d2x_alu_op2),
      .x_use_op1_o(d2x_use_op1),
      .x_use_op2_o(d2x_use_op2)
      );

   // Register File (RF)
   urv_regfile
     #(
       .g_with_ecc(g_with_ecc)
       )
   regfile
     (
      .clk_i(clk_i),
      .rst_i(rst_i),

      .d_stall_i(d_stall),

      .rf_rs1_i(rf_rs1),
      .rf_rs2_i(rf_rs2),

      .d_rs1_i(d2x_rs1),
      .d_rs2_i(d2x_rs2),

      .x_rs1_value_o(x_rs1_value),
      .x_rs2_value_o(x_rs2_value),
      .x_rs1_ecc_err_o(x_rs1_ecc_err),
      .x_rs2_ecc_err_o(x_rs2_ecc_err),

      .w_rd_i(rf_rd),
      .w_rd_value_i(rf_rd_value),
      .w_rd_ecc_i(rf_rd_ecc),
      .w_rd_ecc_flip_i(rf_rd_ecc_flip),
      .w_rd_store_i(rf_rd_write),

      .w_bypass_rd_write_i(rf_bypass_rd_write),
      .w_bypass_rd_value_i(rf_bypass_rd_value)
      );

   // Execute 1/Memory stage (X1/M)
   urv_exec
     #(
       .g_with_hw_div(g_with_hw_div),
       .g_with_hw_mul(p_with_hw_mul),
       .g_with_hw_debug(g_with_hw_debug)
       )
   execute
     (
      .clk_i(clk_i),
      .rst_i(rst_i),

      .irq_i(irq_i),

      // pipe control
      .x_stall_i(x_stall),
      .x_kill_i(x_kill),
      .x_stall_req_o(x_stall_req),

      .x_fault_o(x_fault),

      // from register file
      .rf_rs1_value_i(x_rs1_value),
      .rf_rs2_value_i(x_rs2_value),
      .rf_rs1_ecc_err_i(x_rs1_ecc_err),
      .rf_rs2_ecc_err_i(x_rs2_ecc_err),

      // from D stage
      .d_valid_i(d2x_valid),
      .d_is_csr_i(d2x_is_csr),
      .d_is_mret_i(d2x_is_mret),
      .d_is_ebreak_i(d2x_is_ebreak),
      .d_dbg_mode_i(dbg_enabled_o),
      .d_csr_imm_i(d2x_csr_imm),
      .d_csr_sel_i(d2x_csr_sel),
      .d_pc_i(d2x_pc),
      .d_rd_i(d2x_rd),
      .d_fun_i(d2x_fun),
      .d_imm_i(d2x_imm),
      .d_is_signed_alu_op_i(d2x_is_signed_alu_op),
      .d_is_add_i(d2x_is_add),
      .d_is_load_i(d2x_is_load),
      .d_is_store_i(d2x_is_store),
      .d_is_undef_i(d2x_is_undef),
      .d_is_write_ecc_i(d2x_is_write_ecc),
      .d_is_fix_ecc_i(d2x_is_fix_ecc),
      .d_is_multiply_i(d2x_is_multiply),
      .d_is_divide_i(d2x_is_divide),
      .d_alu_op1_i(d2x_alu_op1),
      .d_alu_op2_i(d2x_alu_op2),
      .d_use_op1_i(d2x_use_op1),
      .d_use_op2_i(d2x_use_op2),
      .d_use_rs1_i(d2x_use_rs1),
      .d_use_rs2_i(d2x_use_rs2),
      .d_rd_source_i(d2x_rd_source),
      .d_rd_write_i(d2x_rd_write),
      .d_opcode_i(d2x_opcode),
      .d_shifter_sign_i(d2x_shifter_sign),

      // to F stage (branches)
      .f_branch_target_o(x2f_pc_bra), // fixme: consistent naming
      .f_branch_take_o(x2f_bra),
      .f_dbg_toggle_o(x2f_dbg_toggle),

      // to X2/W stage
      .w_fun_o(x2w_fun),
      .w_load_o(x2w_load),
      .w_store_o(x2w_store),
      .w_valid_o(x2w_valid),
      .w_dm_addr_o(x2w_dm_addr),
      .w_rd_o(x2w_rd),
      .w_rd_value_o(x2w_rd_value),
      .w_rd_write_o(x2w_rd_write),
      .w_rd_source_o(x2w_rd_source),
      .w_rd_shifter_o(x2w_rd_shifter),
      .w_rd_multiply_o(x2w_rd_multiply),
      .w_ecc_flip_o(x2w_ecc_flip),

      // Data memory I/F
      .dm_addr_o(dm_addr_o),
      .dm_data_s_o(dm_data_s_o),
      .dm_data_select_o(dm_data_select_o),
      .dm_store_o(dm_store_o),
      .dm_load_o(dm_load_o),

      // CSR registers/timer stuff
      .csr_time_i(csr_time),
      .csr_cycles_i(csr_cycles),
      .timer_tick_i(sys_tick),

      // Debug mailboxes
      .dbg_mbx_data_i(dbg_mbx_data_i),
      .dbg_mbx_write_i(dbg_mbx_write_i),
      .dbg_mbx_data_o(dbg_mbx_data_o)
   );

   // Execute 2/Writeback stage
   urv_writeback
     #(.g_with_ecc(g_with_ecc))
   writeback
     (
      .clk_i(clk_i),
      .rst_i(rst_i),

      // pipe control
      .w_stall_req_o(w_stall_req),

      // from X1 stage
      .x_fun_i(x2w_fun),
      .x_load_i(x2w_load),
      .x_store_i(x2w_store),
      .x_valid_i(x2w_valid),
      .x_rd_i(x2w_rd),
      .x_rd_source_i(x2w_rd_source),
      .x_rd_value_i(x2w_rd_value),
      .x_rd_write_i(x2w_rd_write),
      .x_shifter_rd_value_i(x2w_rd_shifter),
      .x_multiply_rd_value_i(x2w_rd_multiply),
      .x_dm_addr_i(x2w_dm_addr),
      .x_ecc_flip_i(x2w_ecc_flip),

      // Data memory I/F
      .dm_data_l_i(dm_data_l_i),
      .dm_load_done_i(dm_load_done_i),
      .dm_store_done_i(dm_store_done_i),

      // to register file
      .rf_rd_value_o(rf_rd_value),
      .rf_rd_ecc_o(rf_rd_ecc),
      .rf_rd_ecc_flip_o(rf_rd_ecc_flip),
      .rf_rd_o(rf_rd),
      .rf_rd_write_o(rf_rd_write)
   );

   assign fault_o = x_fault & g_with_ecc;

   // Built-in timer
   generate
      if (g_timer_frequency > 0)
         urv_timer
           #(
             .g_timer_frequency(g_timer_frequency),
             .g_clock_frequency(g_clock_frequency)
             )
         ctimer
           (
            .clk_i(clk_i),
            .rst_i(rst_i),

            .csr_time_o(csr_time),
            .csr_cycles_o(csr_cycles),

            .sys_tick_o(sys_tick)
            );
      else
        assign sys_tick = 0;
   endgenerate

   // pipeline invalidation logic after a branch
   reg 		 x2f_bra_d0, x2f_bra_d1;

   always@(posedge clk_i)
     if(rst_i) begin
	x2f_bra_d0 <= 0;
	x2f_bra_d1 <= 0;
     end else if (!x_stall) begin
	x2f_bra_d0 <= x2f_bra;
	x2f_bra_d1 <= x2f_bra_d0;
     end

   // pipeline control
   assign f_stall = x_stall_req || w_stall_req || d_stall_req;
   assign d_stall = x_stall_req || w_stall_req;
   assign x_stall = x_stall_req || w_stall_req;

   assign x_kill = x2f_bra || x2f_bra_d0 || x2f_bra_d1;
   assign d_kill = x2f_bra || x2f_bra_d0;

endmodule // urv_cpu
