/*
--------------------------------------------------------------------------------
-- CERN BE-CO-HT
-- uRV - a tiny and dumb RISC-V core
-- https://www.ohwr.org/projects/urv-core
--------------------------------------------------------------------------------
--
-- unit name:   urv_writeback
--
-- description: uRV CPU: instruction write-back stage
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

module urv_writeback
  #(
    parameter g_with_ecc = 0
   )
  (
   input 	 clk_i,
   input 	 rst_i,

   output 	 w_stall_req_o,

   input [2:0] 	 x_fun_i,
   input 	 x_load_i,
   input 	 x_store_i,

   input [31:0]  x_dm_addr_i,
   input [4:0] 	 x_rd_i,
   input [31:0]  x_rd_value_i,
   input 	 x_rd_write_i,
   input 	 x_valid_i,


   input [31:0]  x_shifter_rd_value_i,
   input [31:0]  x_multiply_rd_value_i,
   input [1:0] 	 x_rd_source_i,
   input [1:0] 	 x_ecc_flip_i,

   input [31:0]  dm_data_l_i,
   input 	 dm_load_done_i,
   input 	 dm_store_done_i,

   output [31:0] rf_rd_value_o,
   output [4:0]  rf_rd_o,
   output [6:0]  rf_rd_ecc_o,
   output [1:0]  rf_rd_ecc_flip_o,
   output 	 rf_rd_write_o
   );

   reg [31:0] 	 load_value;

   // generate load value
   always@*
     case (x_fun_i)
       `LDST_B:
	 case ( x_dm_addr_i [1:0] )
	   2'b00:  load_value <= {{24{dm_data_l_i[7]}}, dm_data_l_i[7:0] };
	   2'b01:  load_value <= {{24{dm_data_l_i[15]}}, dm_data_l_i[15:8] };
	   2'b10:  load_value <= {{24{dm_data_l_i[23]}}, dm_data_l_i[23:16] };
	   2'b11:  load_value <= {{24{dm_data_l_i[31]}}, dm_data_l_i[31:24] };
	   default: load_value <= 32'hx;
	 endcase // case ( x_dm_addr_i [1:0] )

       `LDST_BU:
	 case ( x_dm_addr_i [1:0] )
	   2'b00:  load_value <= {24'h0, dm_data_l_i[7:0] };
	   2'b01:  load_value <= {24'h0, dm_data_l_i[15:8] };
	   2'b10:  load_value <= {24'h0, dm_data_l_i[23:16] };
	   2'b11:  load_value <= {24'h0, dm_data_l_i[31:24] };
	   default: load_value <= 32'hx;
	 endcase // case ( x_dm_addr_i [1:0] )

       `LDST_H:
	 case ( x_dm_addr_i [1] )
	   1'b0:    load_value <= {{16{dm_data_l_i[15]}}, dm_data_l_i[15:0] };
	   1'b1:    load_value <= {{16{dm_data_l_i[31]}}, dm_data_l_i[31:16] };
	   default: load_value <= 32'hx;
	 endcase // case ( x_dm_addr_i [1:0] )

       `LDST_HU:
	 case ( x_dm_addr_i [1] )
	   1'b0:    load_value <= {16'h0, dm_data_l_i[15:0] };
	   1'b1:    load_value <= {16'h0, dm_data_l_i[31:16] };
	   default: load_value <= 32'hx;
	 endcase // case ( x_dm_addr_i [1:0] )

       `LDST_L: load_value <= dm_data_l_i;

       default: load_value <= 32'hx;
     endcase // case (d_fun_i)

   reg rf_rd_write;
   reg [31:0] rf_rd_value;

   always@*
     if( x_load_i )
       rf_rd_value <= load_value;
     else if ( x_rd_source_i == `RD_SOURCE_SHIFTER )
       rf_rd_value <= x_shifter_rd_value_i;
     else if ( x_rd_source_i == `RD_SOURCE_MULTIPLY )
       rf_rd_value <= x_multiply_rd_value_i;
     else
       rf_rd_value <= x_rd_value_i;

   always@*
     if (x_load_i && dm_load_done_i)
       rf_rd_write <= x_valid_i;
     else
       rf_rd_write <= x_rd_write_i & x_valid_i;

   // synthesis translate_off
   always@(posedge clk_i)
     if(!rst_i)
       if(rf_rd_write  && (^rf_rd_value === 1'hx) )
	  $error("Attempt to write unknown value to reg %x", x_rd_i);
   // synthesis translate_on

   generate
      if (g_with_ecc) begin
	 wire [6:0] rf_rd_ecc;
      
	 urv_ecc gen_ecc
	   (.dat_i(rf_rd_value),
	    .ecc_o(rf_rd_ecc));
	 assign rf_rd_ecc_o = rf_rd_ecc;
	 assign rf_rd_ecc_flip_o = x_ecc_flip_i;
      end
      else
	assign rf_rd_ecc_o = 6'bx;
   endgenerate

   assign rf_rd_write_o = rf_rd_write;
   assign rf_rd_value_o = rf_rd_value;
   assign rf_rd_o = x_rd_i;
   assign w_stall_req_o = x_valid_i && ((x_load_i && !dm_load_done_i) || (x_store_i && !dm_store_done_i));

endmodule // urv_writeback
