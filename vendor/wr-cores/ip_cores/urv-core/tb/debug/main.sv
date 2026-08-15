/*

 uRV - a tiny and dumb RISC-V core
 Copyright (c) 2015 twl <twlostow@printf.cc>.

 This library is free software; you can redistribute it and/or
 modify it under the terms of the GNU Lesser General Public
 License as published by the Free Software Foundation; either
 version 3.0 of the License, or (at your option) any later version.

 This library is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 Lesser General Public License for more details.

 You should have received a copy of the GNU Lesser General Public
 License along with this library.

*/

`include "urv_defs.v"

`timescale 1ns/1ps

module main;

   const int dump_insns = 1;
   const int dump_mem_accesses = 1;


   reg clk = 0;
   reg rst = 1;

   wire [31:0] im_addr;
   reg [31:0] im_data;
   reg        im_valid;


   wire [31:0] dm_addr;
   wire [31:0] dm_data_s;
   reg [31:0]  dm_data_l;
   wire [3:0]  dm_data_select;
   wire        dm_write;
   reg 	       dm_valid_l = 1;

   reg        dbg_force = 1;
   wire       dbg_enabled;
   reg [31:0] dbg_insn;
   reg        dbg_insn_set;
   wire       dbg_insn_ready;

   reg [31:0] mbxi_data;
   reg        mbxi_write;
   wire [31:0] mbxo_data;


   const var [31:0] insn_nop = 32'h13;
   const var [31:0] insn_csrr_t0_mbxi = 32'h7d0022f3;
   const var [31:0] insn_csrr_t1_mbxi = 32'h7d002373;
   const var [31:0] insn_sw_t1_t0     = 32'h0062a023;
   const var [31:0] insn_jr_t0        = 32'h00028067;
   const var [31:0] insn_ebreak       = 32'h00100073;

   const var [31:0] insn_csrw_mbxo_ra = 32'h7d409073;
   const var [31:0] insn_mov_ra_pc4   = 32'h000000ef;
   const var [31:0] insn_csrr_ra_mbxi = 32'h7d0020f3;
   const var [31:0] insn_ret          = 32'h00008067; // Use a different reg?
   const var [31:0] insn_jmp_4        = 32'h0040006f;


   const var [31:0] loader [14] = '{ 32'h00000513,  //  li	a0,0
                                     32'h7c0022f3,  //  csrr	t0,0x7c0
                                     32'h0012f293,  //  andi	t0,t0,1
                                     32'hfe028ce3,  //  beqz	t0,-8
                                     32'h7d0025f3,  //  csrr	a1,0x7d0
                                     32'h7c0022f3,  //  csrr	t0,0x7c0
                                     32'h0012f293,  //  andi	t0,t0,1
                                     32'hfe028ce3,  //  beqz	t0,-8
                                     32'h7d002373,  //  csrr	t1,0x7d0
                                     32'h00652023,  //  sw	t1,0(a0)
                                     32'h00450513,  //  addi	a0,a0,4
                                     32'hfeb544e3,  //  blt	a0,a1,-24
                                     32'h00000513,  //  li	a0,0
                                     32'h00050067}; //  jr	a0

   localparam int mem_size = 16384;

   reg [31:0]  mem[0:mem_size - 1];

   task automatic load_ram(string filename);
      int f = $fopen(filename,"r");
      int     n, i;

      while(!$feof(f))
        begin
           int addr, data;
           string cmd;

           void'($fscanf(f,"%s %08x %08x", cmd,addr,data));
           if(cmd == "write")
             begin
                mem[addr % mem_size] = data;
             end
        end

   endtask // load_ram

   int seed;



   always@(posedge clk)
     begin
	if ($dist_uniform(seed, 0, 100 ) <= 100) begin
	   im_data <= mem[(im_addr / 4) % mem_size];
	   im_valid <= 1;
	end else
	   im_valid <= 0;

	if(dm_write && dm_data_select[0])
	  mem [(dm_addr / 4) % mem_size][7:0] <= dm_data_s[7:0];
	if(dm_write && dm_data_select[1])
	  mem [(dm_addr / 4) % mem_size][15:8] <= dm_data_s[15:8];
	if(dm_write && dm_data_select[2])
	  mem [(dm_addr / 4) % mem_size][23:16] <= dm_data_s[23:16];
	if(dm_write && dm_data_select[3])
	  mem [(dm_addr / 4) % mem_size][31:24] <= dm_data_s[31:24];
     end



   always@(posedge clk)
     begin
	dm_data_l <= mem[(dm_addr/4) % mem_size];
     end


   reg irq = 0;

   urv_cpu #(.g_with_hw_debug(1)) DUT
     (
      .clk_i(clk),
      .rst_i(rst),

      .irq_i(irq),

      // instruction mem I/F
      .im_addr_o(im_addr),
      .im_data_i(im_data),
      .im_valid_i(im_valid),

      // data mem I/F
      .dm_addr_o(dm_addr),
      .dm_data_s_o(dm_data_s),
      .dm_data_l_i(dm_data_l),
      .dm_data_select_o(dm_data_select),
      .dm_store_o(dm_write),
      .dm_load_o(),
      .dm_store_done_i(1'b1),
      .dm_load_done_i(1'b1),

      // Debug
      .dbg_force_i(dbg_force),
      .dbg_enabled_o(dbg_enabled),
      .dbg_insn_i(dbg_insn),
      .dbg_insn_set_i(dbg_insn_set),
      .dbg_insn_ready_o(dbg_insn_ready),

      // Debug mailboxes
      .dbg_mbx_data_i(mbxi_data),
      .dbg_mbx_write_i(mbxi_write),
      .dbg_mbx_data_o(mbxo_data)
      );

   always #5ns clk <= ~clk;


   task send_insn (input [31:0] insn);
      dbg_insn <= insn;
      dbg_insn_set <= 1'b1;
      @(posedge clk);
      dbg_insn_set <= 1'b0;
      dbg_insn <= insn_nop;
      @(posedge clk);
      while (!dbg_insn_ready)
        @(posedge clk);
   endtask // send_insn

   task send_mbxi(input [31:0] data);
      mbxi_data <= data;
      mbxi_write <= 1;
      @(posedge clk);
      mbxi_write <= 0;
      @(posedge clk);
      @(posedge clk);
   endtask

   task read_pc;
      reg [31:0] pc, ra;

      // write x1 to mbxo, jal x1, 0, write x1 to mbxo, read x1 from mbxi
      send_insn(insn_csrw_mbxo_ra);
      send_insn(insn_mov_ra_pc4);
      send_insn(insn_nop);
      send_insn(insn_nop);
      //  Read ra only once the csrw has been executed.
      ra <= mbxo_data;
      send_insn(insn_csrw_mbxo_ra);
      mbxi_data <= ra;
      mbxi_write <= 1;
      send_insn(insn_csrr_ra_mbxi);
      mbxi_write <= 0;
      send_insn(insn_nop);
      send_insn(insn_nop);
      pc <= mbxo_data - 4; // Jal save pc + 4
      send_insn(insn_nop);

      $display("Break: pc=%x, ra=%x\n", pc, ra);
   endtask

   initial begin
//      load_ram("../../sw/test3/test3.ram");
//      load_ram("../../sw/testsuite/benchmarks/dhrystone/dhrystone.ram");

//      load_ram("../../sw/testsuite/isa/rv32ui-p-mulh.ram");

      const var [31:0] loader_addr = 16'h3f80;

      dbg_insn = insn_nop;
      dbg_insn_set = 1'b0;
      mbxi_data <= 0;
      mbxi_write <= 0;

      repeat(3) @(posedge clk);
      rst = 0;
      dbg_force = 0;

      while (!dbg_insn_ready)
        @(posedge clk);

      $display("Load application");

      begin
         int fd;
         int filelen;

         fd = $fopen("app1.bin", "rb");
         void'($fseek(fd, 0, 2));
         filelen = $ftell(fd);
         void'($rewind(fd));

         filelen = (filelen + 3) / 4;
         for(int i = 0; i < filelen; i++)
           begin
              var [7:0] b0, b1, b2, b3;
              int l;
              l = $fread(b0, fd);
              l += $fread(b1, fd);
              l += $fread(b2, fd);
              l += $fread(b3, fd);

              // Address
              mbxi_data <= i * 4;
              mbxi_write <= 1;
              send_insn (insn_csrr_t0_mbxi);

              // Data
              mbxi_data <= {b3, b2, b1, b0};
              mbxi_write <= 1;
              send_insn (insn_csrr_t1_mbxi);

              //  Store
              send_insn (insn_sw_t1_t0);
           end
         $fclose(fd);
      end

      //  Set PC address
      mbxi_data <= 0;
      mbxi_write <= 1;
      send_insn (insn_csrr_t0_mbxi);

      //  Branch and be sure it is executed.
      mbxi_write <= 0;
      send_insn (insn_jr_t0);

      send_insn (insn_ebreak);

      // Wait until debug mode is enabled again.
      while (!dbg_enabled)
        @(posedge clk) ;

      // Read pc
      read_pc;

      // Continue
      send_insn (insn_jmp_4);
      send_insn (insn_ebreak);

      while (1)
        begin
           repeat(100) @(posedge clk);

           // Stop
           dbg_force = 1;
           while (!dbg_enabled)
             @(posedge clk) ;
           dbg_force = 0;

           // Read pc
           read_pc;

           // Continue
           send_insn (insn_ebreak);
           send_insn (insn_nop);
           send_insn (insn_nop);
        end
   end

   function string decode_op(bit[2:0] fun);
     case(fun)
       `FUNC_ADD: return "add";
       `FUNC_XOR: return "xor";
       `FUNC_OR:  return "or";
       `FUNC_AND: return "and";
       `FUNC_SLT: return "slt";
       `FUNC_SLTU:return "sltu";
       `FUNC_SL:  return "sl";
       `FUNC_SR:  return "sr";
     endcase // case (fun)
   endfunction // decode_op

   function string decode_cond(bit[2:0] fun);
     case(fun)
       `BRA_EQ:  return "eq";
       `BRA_NEQ: return "neq";
       `BRA_LT:  return "lt";
       `BRA_GE:  return "ge";
       `BRA_LTU: return "ltu";
       `BRA_GEU: return "geu";
     endcase // case (fun)
   endfunction

   function string decode_size(bit[2:0] fun);
     case(fun)
       `LDST_B:  return "s8";
       `LDST_BU: return "u8";
       `LDST_H:  return "s16";
       `LDST_HU: return "u16";
       `LDST_L:  return "32";
     endcase // case (fun)
   endfunction

   function string decode_regname(bit[4:0] r);
      case(r)
	0: return "zero";
	1: return "ra";
	2: return "sp";
	3: return "gp";
	4: return "tp";
	5: return "t0";
	6: return "t1";
	7: return "t2";
	8: return "s0";
	9: return "s1";
	10: return "a0";
	11: return "a1";
	12: return "a2";
	13: return "a3";
	14: return "a4";
	15: return "a5";
	16: return "a6";
	17: return "a7";
	18: return "s2";
	19: return "s3";
	20: return "s4";
	21: return "s5";
	22: return "s6";
	23: return "s7";
	24: return "s8";
	25: return "s9";
	26: return "s10";
	27: return "s11";
	28: return "t3";
	29: return "t4";
	30: return "t5";
	31: return "t6";
      endcase // case (fun)
   endfunction // decode_regname

   function string decode_csr(bit[11:0] csr);
      case(csr)
	`CSR_ID_CYCLESH:  return "cyclesh";
	`CSR_ID_CYCLESL:  return "cyclesl";
	`CSR_ID_TIMEH:    return "timeh";
	`CSR_ID_TIMEL:    return "timel";
	`CSR_ID_MSCRATCH: return "mscratch";
	`CSR_ID_MEPC:     return "mepc";
	`CSR_ID_MSTATUS:  return "mstatus";
	`CSR_ID_MCAUSE:   return "mcause";
	default: return "???";
      endcase // case (csr)
   endfunction // decode_csr

   task automatic verify_branch(input [31:0] rs1, input[31:0] rs2, input take, input [2:0] fun);
      int do_take;

      case(fun)
	`BRA_EQ: do_take = (rs1 == rs2);
	`BRA_NEQ: do_take = (rs1 != rs2);
	`BRA_GE: do_take = $signed(rs1) >= $signed(rs2);
	`BRA_LT: do_take = $signed(rs1) < $signed(rs2);
	`BRA_GEU: do_take = rs1 >= rs2;
	`BRA_LTU: do_take = rs1 < rs2;
	default:
	  begin
	     $error("illegal branch func");
	     $stop;
	  end
      endcase // case (func)

      if(do_take != take)
	begin
	   $error("fucked up jump");
	   $stop;
	end
   endtask // verify_branch

   function automatic string s_hex(int x);
      return $sformatf("%s0x%-08x", x<0?"-":" ", (x<0)?(-x):x);
   endfunction // s_hex

   reg[31:0] dm_addr_d0;
   integer   f_console, f_exec_log;

   initial begin
      f_console = $fopen("console.txt","wb");
      f_exec_log = $fopen("exec_log.txt","wb");

      #500us;
//      $fclose(f_console);
   end

   always@(posedge clk)
     begin
	if(dump_mem_accesses)
	  begin
	dm_addr_d0 <= dm_addr;

	if(dm_write)begin
	  $display("DM Write addr %x data %x", dm_addr, dm_data_s);
//	  $fwrite(f_exec_log,"DM Write addr %x data %x\n", dm_addr, dm_data_s);
	end

	if (DUT.writeback.x_load_i && DUT.writeback.rf_rd_write_o)
	  begin
/* -----\/----- EXCLUDED -----\/-----
	     if ($isunknown(dm_data_l))
	       begin
		  $error("Attempt to load uninitialized entry from memory");
		  $stop;
	       end
 -----/\----- EXCLUDED -----/\----- */


     $display("DM Load addr %x data %x -> %s", dm_addr_d0, DUT.writeback.rf_rd_value_o, decode_regname(DUT.writeback.x_rd_i));
/* -----\/----- EXCLUDED -----\/-----
	    $fwrite(f_exec_log, "DM Load addr %x data %x -> %s\n", dm_addr_d0, DUT.writeback.rf_rd_value_o, decode_regname(DUT.writeback.x_rd_i));
 -----/\----- EXCLUDED -----/\----- */
	  end
	end
     end




   always@(posedge clk)
     if(dm_write && dm_addr == 'h100000)
       begin
	  $display("\n ****** TX '%c' \n", dm_data_s[7:0]) ;
//	  $fwrite(f_exec_log,"\n ****** TX '%c' \n", dm_data_s[7:0]) ;
	  $fwrite(f_console,"%c", dm_data_s[7:0]);
	  $fflush(f_console);
       end

   int cycles = 0;


   always@(posedge clk)
     if(dump_insns && DUT.execute.d_valid_i && !DUT.execute.x_stall_i && !DUT.execute.x_kill_i)
       begin
	  automatic string opc="<unk>", fun="", args="";

	  automatic string rs1 = decode_regname(DUT.d2x_rs1);
	  automatic string rs2 = decode_regname(DUT.d2x_rs2);
	  automatic string rd = decode_regname(DUT.d2x_rd);

	  reg [31:0] imm;

//	  	  $display("Opcode %x", DUT.d2x_opcode);

	  case (DUT.d2x_opcode)
	    `OPC_AUIPC:
	      begin
		 opc = "auipc";
		 fun = "";
		 args = $sformatf("%-3s %-3s %s", rd, " ", s_hex(DUT.d2x_imm));
	      end

	    `OPC_LUI:
	      begin
		 opc = "lui";
		 fun = "";
		 args = $sformatf("%-3s %-3s %s", rd, " ", s_hex(DUT.d2x_imm));
	      end

	    `OPC_OP_IMM:
	      begin
		 opc = "op-imm";
		 fun = decode_op(DUT.d2x_fun);
		 args = $sformatf("%-3s %-3s %s", rd, rs1, s_hex(DUT.d2x_imm));
	      end

	    `OPC_OP:
	      begin
		 opc = "op";
		 fun = decode_op(DUT.d2x_fun);
		 args = $sformatf("%-3s %-3s %-3s", rd, rs1, rs2);
	      end

	    `OPC_JAL:
	      begin
		 opc = "jal";
		 fun = "";
//decode_op(DUT.d2x_fun);
		 args = $sformatf("%-3s      0x%-08x", rd, DUT.execute.branch_target);
	      end
	    `OPC_JALR:
	      begin
		 opc = "jalr";
		 fun = "";
//decode_op(DUT.d2x_fun);
		 args = $sformatf("%-3s %-3s 0x%-08x", rd, rs1,
                                  DUT.execute.branch_target);
	      end
	    `OPC_BRANCH:
	      begin
		 opc = "branch";
		 fun = decode_cond(DUT.d2x_fun);
//decode_op(DUT.d2x_fun);
		 args = $sformatf("%-3s %-3s 0x%-08x rs1 %s", rs1, rs2,
                                  DUT.execute.branch_target,
                                  DUT.execute.branch_take?"TAKE":"IGNORE");

		 verify_branch(DUT.execute.rs1, DUT.execute.rs2, DUT.execute.branch_take,DUT.d2x_fun);
	      end
	    `OPC_LOAD:
	      begin
		 opc = "ld";
		 fun = decode_size(DUT.d2x_fun);
//decode_op(DUT.d2x_fun);
		 args = $sformatf("%-3s %-3s [0x%-08x + %s]", rd, rs1,
                                  DUT.execute.rs1,
                                  s_hex($signed(DUT.execute.d_imm_i)));
	      end
	    `OPC_STORE:
	      begin
		 opc = "st";
		 fun = decode_size(DUT.d2x_fun);
//decode_op(DUT.d2x_fun);
		 args = $sformatf("%-3s %-3s [0x%-08x + %s]", rs2, rs1,
                                  DUT.execute.rs1,
                                  s_hex($signed(DUT.execute.d_imm_i)));
	      end
	    `OPC_SYSTEM:
	      case (DUT.d2x_fun)
		`CSR_OP_CSRRWI:  begin
		   opc = "csrrwi";
		   args = $sformatf("%-3s %-3s 0x%08x",
                                    rd, decode_csr(DUT.d2x_csr_sel),
                                    DUT.d2x_csr_imm);
		end
		`CSR_OP_CSRRSI:  begin
		   opc = "csrrsi";
		   args = $sformatf("%-3s %-3s 0x%08x",
                                    rd, decode_csr(DUT.d2x_csr_sel),
                                    DUT.d2x_csr_imm);
		end
		`CSR_OP_CSRRCI:  begin
		   opc = "csrrci";
		   args = $sformatf("%-3s %-3s 0x%08x",
                                    rd, decode_csr(DUT.d2x_csr_sel),
                                    DUT.d2x_csr_imm);
		end
		`CSR_OP_CSRRW: begin
		   opc = "csrrw";
		   args = $sformatf("%-3s %-3s %-3s [0x%08x]",
                                    rd, decode_csr(DUT.d2x_csr_sel),
                                    rs1, DUT.execute.rs1);
		end
		`CSR_OP_CSRRS: begin
		   opc = "csrrs";
		   args = $sformatf("%-3s %-3s %-3s [0x%08x]",
                                    rd, decode_csr(DUT.d2x_csr_sel),
                                    rs1, DUT.execute.rs1);
		end
		`CSR_OP_CSRRC: begin
		   opc = "csrrc";
		   args = $sformatf("%-3s %-3s %-3s [0x%08x]",
                                    rd, decode_csr(DUT.d2x_csr_sel),
                                    rs1, DUT.execute.rs1);
		end
                default: begin
                   opc = "system";
                end
	      endcase // case (d_fun_i)

           default:
             begin
		fun = "";
                args = $sformatf("opc: 0x%02x", DUT.d2x_opcode);
             end
	  endcase // case (d2x_opcode)

	  $display("%08x [%d]: %-8s %-3s %s",
                   DUT.execute.d_pc_i, cycles, opc, fun, args);
//  	  $fwrite(f_exec_log,"%08x: %-8s %-3s %s\n",
//                DUT.execute.d_pc_i, opc, fun, args);
	  $fwrite(f_exec_log,
                  ": PC %08x OP %08x CYCLES %-0d RS1 %08x RS2 %08x\n",
                  DUT.execute.d_pc_i, DUT.decode.f_ir_i, cycles++,
                  DUT.execute.rs1, DUT.execute.rs2);
       end
endmodule // main
