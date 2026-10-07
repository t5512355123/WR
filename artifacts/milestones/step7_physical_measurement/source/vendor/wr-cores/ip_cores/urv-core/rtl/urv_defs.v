/*
--------------------------------------------------------------------------------
-- CERN BE-CO-HT
-- uRV - a tiny and dumb RISC-V core
-- https://www.ohwr.org/projects/urv-core
--------------------------------------------------------------------------------
--
-- unit name:   na
--
-- description: uRV definitions
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

`include "urv_config.v"

//  opcodes (bits[6:2], bits[1:0] == 2'b11)
`define OPC_LOAD   5'b00000
`define OPC_OP_IMM 5'b00100
`define OPC_AUIPC  5'b00101
`define OPC_STORE  5'b01000
`define OPC_OP     5'b01100
`define OPC_LUI    5'b01101
`define OPC_CUST2  5'b10110
`define OPC_BRANCH 5'b11000
`define OPC_JALR   5'b11001
`define OPC_JAL    5'b11011
`define OPC_SYSTEM 5'b11100

// funct3 for OPC_BRANCH
`define BRA_EQ 3'b000
`define BRA_NEQ  3'b001
`define BRA_LT 3'b100
`define BRA_GE 3'b101
`define BRA_LTU 3'b110
`define BRA_GEU 3'b111

// funct3 for OPC_LOAD and OPC_STORE
`define LDST_B 3'b000
`define LDST_H 3'b001
`define LDST_L 3'b010
`define	LDST_BU 3'b100
`define LDST_HU 3'b101

// funct3 for OPC_OP and OPC_OP_IMM
`define FUNC_ADD 3'b000
`define FUNC_SLT 3'b010
`define FUNC_SLTU 3'b011
`define FUNC_XOR 3'b100
`define FUNC_OR 3'b110
`define FUNC_AND 3'b111
`define FUNC_SL 3'b001
`define FUNC_SR 3'b101

// funct3 for OPC_OP, funct7=1
`define FUNC_MUL 3'b000
`define FUNC_MULH 3'b001
`define FUNC_MULHSU 3'b010
`define FUNC_MULHU 3'b011
`define FUNC_DIV 3'b100
`define FUNC_DIVU 3'b101
`define FUNC_REM 3'b110
`define FUNC_REMU 3'b111

// funct3 for OPC_SYSTEM
`define CSR_OP_PRIV  3'b000
`define CSR_OP_CSRRW 3'b001
`define CSR_OP_CSRRS 3'b010
`define CSR_OP_CSRRC 3'b011
`define CSR_OP_CSRRWI 3'b101
`define CSR_OP_CSRRSI 3'b110
`define CSR_OP_CSRRCI 3'b111

// funct3 for OPC_CUST2
// (they use shifter functions)
`define FUNC_WRECC `FUNC_SL
`define FUNC_FIXECC `FUNC_SR

// Imm for OPC_SYSTEM, fun3 = 0
`define SYS_IMM_MRET   12'b0011000_00010
`define SYS_IMM_EBREAK 12'b0000000_00001

`define RD_SOURCE_ALU 3'b000
`define RD_SOURCE_SHIFTER 3'b010
`define RD_SOURCE_MULTIPLY 3'b001
`define RD_SOURCE_DIVIDE 3'b100
`define RD_SOURCE_CSR 3'b011
`define RD_SOURCE_MULH 3'b111

`define CSR_ID_CYCLESH 12'hc80
`define CSR_ID_CYCLESL 12'hc00
`define CSR_ID_TIMEH 12'hc81
`define CSR_ID_TIMEL 12'hc01
`define CSR_ID_MSCRATCH 12'h340
`define CSR_ID_MEPC 12'h341
`define CSR_ID_MSTATUS 12'h300
`define CSR_ID_MCAUSE 12'h342
`define CSR_ID_MIP 12'h344
`define CSR_ID_MIE 12'h304
`define CSR_ID_DBGMBX 12'h7d0
`define CSR_ID_MIMPID 12'hf13

/* History for MIMPID:
   0000_0000: mimpid not implemented
   2019_0125: mimpid added.
   2019_0131: data memory wait state.
*/

`define URV_RESET_VECTOR 32'h00000000
`define URV_TRAP_VECTOR  32'h00000008

//  Bits in mie/mip for machine mode
`define EXCEPT_TIMER 7
`define EXCEPT_IRQ 11

//  Cause
`define CAUSE_ILLEGAL_INSN    2
`define CAUSE_BREAKPOINT      3
`define CAUSE_UNALIGNED_LOAD  4
`define CAUSE_UNALIGNED_STORE 6
`define CAUSE_MACHINE_TIMER   7
`define CAUSE_MACHINE_IRQ     11
`define CAUSE_ECC_ERROR       15

`define OP_SEL_BYPASS_X 0
`define OP_SEL_BYPASS_W 1
`define OP_SEL_DIRECT 2
`define OP_SEL_IMM 3
