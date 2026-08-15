/*
--------------------------------------------------------------------------------
-- CERN BE-CO-HT
-- uRV - a tiny and dumb RISC-V core
-- https://www.ohwr.org/projects/urv-core
--------------------------------------------------------------------------------
--
-- unit name:   urv_fetch
--
-- description: uRV CPU: instruction fetch stage
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

`timescale 1ns/1ps

module urv_fetch
(
 input             clk_i,
 input             rst_i,

 input             f_stall_i,

 //  Instruction memory
 //  im_rd_o is maintained as long as the instruction is needed.
 output [31:0]     im_addr_o,
 output            im_rd_o, 
 input [31:0]      im_data_i,
 input             im_valid_i,

 //  Fetched instruction - set on the next cycle.
 output reg        f_valid_o,
 output reg [31:0] f_ir_o,
 output reg [31:0] f_pc_o,

 //  Branch control
 input [31:0]      x_pc_bra_i,
 input             x_bra_i,

 //  Debug mode
 input             dbg_force_i,
 output            dbg_enabled_o,
 input [31:0]      dbg_insn_i,
 input             dbg_insn_set_i,
 output            dbg_insn_ready_o,
 input             x_dbg_toggle_i
);

   parameter g_with_compressed_insns = 0;
   parameter g_with_hw_debug = 0;

   reg [31:0] pc;
   reg 	      rst_d;

   reg [31:0]  pc_next;
   reg         dbg_mode;
   reg [2:0]   pipeline_cnt;
   wire        frozen;

   // Set by x_bra_i until the next instruction has been fetched.
   // The instruction being fetched before the branch has to be discarded.
   reg         f_kill;

   // Set as long as no instruction has to be fetched.
   assign frozen = (f_stall_i
                    || dbg_mode || dbg_force_i || pipeline_cnt != 0);
   
   always@*
     if (x_bra_i)
       pc_next <= x_pc_bra_i;
     else if (rst_d || frozen || f_kill || !im_valid_i)
       pc_next <= pc;
     else
       pc_next <= pc + 4;

   // Start fetching the next instruction
   assign im_addr_o = pc_next;
   assign im_rd_o = x_bra_i || !(frozen || rst_i);

   assign dbg_enabled_o = dbg_mode;
   assign dbg_insn_ready_o = pipeline_cnt == 4;

   always@(posedge clk_i)
     if (rst_i)
       begin
          //  PC = 0 at reset.
	  pc <= 0;

          f_pc_o <= 0;
	  f_ir_o <= 0;
	  f_valid_o <= 0;
          f_kill <= 0;

          //  Allow to start in debug mode.
          dbg_mode <= dbg_force_i;

          pipeline_cnt <= 0;

          //  The instruction won't be valid on the next cycle, as the
          //  instruction memory is registered.
	  rst_d <= 1;
       end
     else
       begin
	  rst_d <= 0;

	  if (!f_stall_i)
            begin
	       f_pc_o <= pc;
               pc <= pc_next;

               if(g_with_hw_debug
                  && !dbg_mode
                  && (dbg_force_i || x_dbg_toggle_i || pipeline_cnt != 0))
                 begin
                    //  Enter or entering in debug mode

                    //  Stall until the debug mode is set (pipeline flushed).
                    f_valid_o <= 0;
                    //  Ebreak enters directly in the debug mode.  As it is
                    //  considered as a branch, stages are killed.
                    if (pipeline_cnt == 4 || x_dbg_toggle_i)
                      begin
                         dbg_mode <= 1;
                         pipeline_cnt <= 0;
                      end
                    else
                      pipeline_cnt <= pipeline_cnt + 1'b1;
                 end
               else if(g_with_hw_debug && dbg_mode)
                 begin
                    //  In debug mode
                    if (x_dbg_toggle_i)
                      begin
                         //  Leave debug mode immediately.
                         dbg_mode <= 0;
                         f_valid_o <= 0;
                      end
                    else
                      begin
                         //  Use instruction from the debug port.
                         f_ir_o <= dbg_insn_i;
                         f_valid_o <= 1;
                      end

                    if (x_dbg_toggle_i || dbg_insn_set_i)
                      pipeline_cnt <= 0;
                    else if (pipeline_cnt != 4)
                      pipeline_cnt <= pipeline_cnt + 1'b1;
                 end
               else if(im_valid_i)
                 begin
	            f_ir_o <= im_data_i;
                    // A branch invalidate the current instruction.
                    // Not valid on the first cycle
	            f_valid_o <= (!rst_d && !x_bra_i && !f_kill);
                    //  The instruction has been killed.
                    f_kill <= 0;
	         end
               else
                 begin
                    //  If a branch has been executed, the instruction being
                    //  fetch must not be executed.  Kill it.
                    f_kill <= f_kill | x_bra_i;
	            f_valid_o <= 0;
	         end
	    end
       end

endmodule // urv_fetch
