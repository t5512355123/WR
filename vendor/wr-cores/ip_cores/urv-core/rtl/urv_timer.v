/*
--------------------------------------------------------------------------------
-- CERN BE-CO-HT
-- uRV - a tiny and dumb RISC-V core
-- https://www.ohwr.org/projects/urv-core
--------------------------------------------------------------------------------
--
-- unit name:   urv_timer
--
-- description: uRV timer unit
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

module urv_timer
  (
   input 	 clk_i,
   input 	 rst_i,

   output [39:0] csr_time_o,
   output [39:0] csr_cycles_o,

   output 	 sys_tick_o
   );

   parameter g_timer_frequency = 1000;
   parameter g_clock_frequency = 62500000;

   localparam g_prescaler = (g_clock_frequency / g_timer_frequency ) - 1;

   reg [23:0] 	 presc;
   reg 		 presc_tick;

   reg [39:0] 	 cycles;
   reg [39:0] 	 ticks;

   always@(posedge clk_i)
     if(rst_i)
       begin
	  presc <= 0;
	  presc_tick <= 0;
       end else begin
	  if(presc == g_prescaler) begin
	     presc <= 0;
	     presc_tick <= 1;
	  end else begin
	     presc_tick <= 0;
	     presc <= presc + 1;
	  end // else: !if(rst_i)
       end // else: !if(rst_i)

   always @(posedge clk_i)
     if (rst_i)
       ticks <= 0;
     else if (presc_tick)
       ticks <= ticks + 1;

   always @(posedge clk_i)
     if (rst_i)
       cycles <= 0;
     else
       cycles <= cycles + 1;


   assign csr_time_o = ticks;
   assign csr_cycles_o = cycles;
   assign sys_tick_o = presc_tick;

endmodule // urv_timer
