/*
--------------------------------------------------------------------------------
-- CERN BE-CO-HT
-- uRV - a tiny and dumb RISC-V core
-- https://www.ohwr.org/projects/urv-core
--------------------------------------------------------------------------------
--
-- unit name:   urv_ecc
--
-- description: uRV CPU: compute ecc
--
--------------------------------------------------------------------------------
-- Copyright CERN 2022
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

module urv_ecc
  (
   input [31:0]	     dat_i,
   output [6:0]      ecc_o
   );

   assign ecc_o[0] = ^(dat_i & 32'b11000001010010000100000011111111);
   assign ecc_o[1] = ^(dat_i & 32'b00100001001001001111111110010000);
   assign ecc_o[2] = ^(dat_i & 32'b01101100111111110000100000001000);
   assign ecc_o[3] = ^(dat_i & 32'b11111111000000011010010001000100);
   assign ecc_o[4] = ^(dat_i & 32'b00010110111100001001001010100110);
   assign ecc_o[5] = ^(dat_i & 32'b00010000000111110111000101100001);
   assign ecc_o[6] = ^(dat_i & 32'b10001010100000100000111100011011);
endmodule // urv_ecc

