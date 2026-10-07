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
`include "logger.svh"

`timescale 1ns/1ps

localparam struct {
   bit mul;
   bit div;
   bit dbg;
   bit ws;
   bit ecc;
   } configs[6] = '{ '{ mul: 0, div: 0, dbg: 0, ws: 0, ecc: 0 },
                     '{ mul: 0, div: 0, dbg: 0, ws: 1, ecc: 1 },
                     '{ mul: 1, div: 0, dbg: 0, ws: 0, ecc: 1 },
                     '{ mul: 1, div: 1, dbg: 0, ws: 0, ecc: 1 },
                     '{ mul: 1, div: 1, dbg: 1, ws: 0, ecc: 1 },
                     '{ mul: 1, div: 1, dbg: 1, ws: 1, ecc: 1 }};
localparam int n_configs = $size(configs);

module ICpuTestWrapper
  (
   input clk_i
   );

   reg rst = 1;


   reg r_with_hw_mulh = 0;
   reg r_with_hw_divide = 0;
   reg r_with_hw_debug = 0;

   reg irq = 0;

   parameter int mem_size = 16384;

   wire        cpu_fault[n_configs];

   wire [31:0] im_addr_m[n_configs];
   wire [31:0] dm_addr_m[n_configs];
   wire [31:0] dm_data_s_m[n_configs];
   wire [3:0]  dm_data_select_m[n_configs];
   wire        dm_store_m[n_configs];
   wire        dm_load_m[n_configs];
   reg  [1:0]  dm_store_done_d;  // Delay line
   reg  [1:0]  dm_load_done_d;   // Delay line
   wire        irq_m[n_configs];

   int 	       r_active_cpu = 0;


   wire        fault = cpu_fault[r_active_cpu];

   wire [31:0] im_addr = im_addr_m[r_active_cpu];
   reg [31:0] im_data;
   reg        im_valid;


   wire [31:0] dm_addr = dm_addr_m[r_active_cpu];
   wire [31:0] dm_data_s = dm_data_s_m[r_active_cpu];
   reg [31:0]  dm_data_l_d[1:0];
   wire [3:0]  dm_data_select = dm_data_select_m[r_active_cpu];
   wire        dm_store = dm_store_m[r_active_cpu];
   wire        dm_load = dm_load_m[r_active_cpu];
   reg 	       dm_valid_l = 1;

   wire        dm_delay = configs[r_active_cpu].ws;
   wire        dm_store_done = dm_store_done_d[dm_delay];
   wire        dm_load_done = dm_load_done_d[dm_delay];
   wire [31:0] dm_data_l = dm_data_l_d[dm_delay];

   reg [31:0]  mem[0:mem_size - 1];

   string current_msg;
   int 	  test_complete = 0;
   int 	  fault_expected = 0;

   task automatic selectConfiguration( int cpu );
      r_active_cpu = cpu;
   endtask // selectConfiguration


   function automatic string getConfigurationString();
      automatic string rv;

      if(configs[r_active_cpu].mul)
	rv = {rv, " hw_mulh"};
      if(configs[r_active_cpu].div)
	rv = {rv, " hw_div"};
      if(configs[r_active_cpu].dbg)
	rv = {rv, " hw_debug"};
      if(configs[r_active_cpu].ws)
	rv = {rv, " wait_state"};
      if(configs[r_active_cpu].ecc)
	rv = {rv, " ecc"};

      return rv;

   endfunction // getConfigurationString


   task automatic runTest(string filename);
      int f = $fopen(filename,"r");
      int n, i;

      // $display("load %s %x", filename, f);

      current_msg = "";
      test_complete = 0;
      fault_expected = 0;

      rst <= 1;
      @(posedge clk_i);
      @(posedge clk_i);

      if( f == 0)
	begin
	   $error("can't open: %s", filename);
	   $stop;
	end

      while(!$feof(f))
        begin
           int addr, data, r;
           string cmd;

           r = $fscanf(f,"%s %08x %08x", cmd,addr,data);

	   if ( r < 0 )
	     break;

           if(cmd == "write")
             begin
                mem[addr % mem_size] = data;
             end

        end
      $fclose(f);

      @(posedge clk_i);
      rst <= 0;
      @(posedge clk_i);

   endtask // runProgram

   function automatic string getTestResult();
      return current_msg;
   endfunction // getTestResult

   function automatic int isTestComplete();
      return test_complete;
   endfunction // isTestComplete


   int seed = 0;

   always@(posedge clk_i)
     begin
        //  Read memory for insn
	if(   $dist_uniform(seed, 0, 100 ) <= 100) begin
           logic [31:0] dat;
           dat = mem[(im_addr / 4) % mem_size];
           // $display("imem @%h: %08x", im_addr, dat);
	   im_data <= dat;
	   im_valid <= 1;
	end else
	   im_valid <= 0;

        //  Write data memory
        if (dm_store)
          begin
	     if(dm_data_select[0])
	       mem [(dm_addr / 4) % mem_size][7:0] <= dm_data_s[7:0];
	     if(dm_data_select[1])
	       mem [(dm_addr / 4) % mem_size][15:8] <= dm_data_s[15:8];
	     if(dm_data_select[2])
	       mem [(dm_addr / 4) % mem_size][23:16] <= dm_data_s[23:16];
	     if(dm_data_select[3])
	       mem [(dm_addr / 4) % mem_size][31:24] <= dm_data_s[31:24];
             // $display("dmem @%h: <- %08x", dm_addr, dm_data_s);
          end
        dm_store_done_d <= {dm_store_done_d[0], dm_store};

        //  Read data memory
        dm_data_l_d[1] <= dm_data_l_d[0];
	dm_data_l_d[0] <= dm_load ? mem[(dm_addr/4) % mem_size] : 'x;
        dm_load_done_d <= {dm_load_done_d[0], dm_load};
     end // always@ (posedge clk)


   for(genvar i = 0; i < n_configs; i++)
     begin
	urv_cpu
	  #(
	    .g_with_hw_mulh(configs[i].mul),
	    .g_with_hw_div(configs[i].div),
	    .g_with_hw_debug(configs[i].dbg),
	    .g_with_ecc(configs[i].ecc)
	    )
	DUTx
	   (
	    .clk_i(i == r_active_cpu ? clk_i : 1'b0 ),
	    .rst_i(i == r_active_cpu ? rst : 1'b1 ),

	    .irq_i ( irq ),

	    .fault_o (cpu_fault[i]),

	    // instruction mem I/F
	    .im_addr_o(im_addr_m[i]),
            .im_rd_o(),
	    .im_data_i(im_data),
	    .im_valid_i(im_valid),

	    // data mem I/F
	    .dm_addr_o(dm_addr_m[i]),
	    .dm_data_s_o(dm_data_s_m[i]),
	    .dm_data_l_i(dm_data_l),
	    .dm_data_select_o(dm_data_select_m[i]),
	    .dm_store_o(dm_store_m[i]),
	    .dm_load_o(dm_load_m[i]),
	    .dm_store_done_i(dm_store_done),
	    .dm_load_done_i(dm_load_done),

	    // Debug
	    .dbg_force_i(1'b0),
	    .dbg_enabled_o(),
	    .dbg_insn_i(32'h0),
	    .dbg_insn_set_i(1'b0),
	    .dbg_insn_ready_o(),

	    // Debug mailbox
	    .dbg_mbx_data_i(0),
	    .dbg_mbx_write_i(1'b0),
	    .dbg_mbx_data_o()
	    );
     end


   always@(posedge clk_i) begin
     if(dm_store)
       begin
	  automatic bit [7:0] chr = dm_data_s[7:0];

	  if(dm_addr == 'h100000)
	    current_msg = {current_msg, chr};
	  else if(dm_addr == 'h100004)
	    test_complete = 1;
	  else if(dm_addr == 'h100008)
	    fault_expected = 1;
       end
      if (fault) begin
	 current_msg = {current_msg, fault_expected ? "Test passed\n" : "Fault" };

	 test_complete = 1;
      end
   end

endmodule // ICpuTestWrapper




module main;


   reg clk = 0;

   always #5ns clk <= ~clk;

   ICpuTestWrapper DUT ( clk );

class ISATestRunner extends LoggerClient;

   typedef enum
		{
		 R_OK = 0,
		 R_FAIL = 1,
		 R_TIMEOUT = 2
		 } TestStatus;


   task automatic runTest(string filename, ref TestStatus  status, ref int failedTest );
      automatic integer cnt = 0;

      // $display("runTest task");

      DUT.runTest(filename);

      failedTest = 0;

      while(!DUT.isTestComplete() )
	begin
	   #1us;
	   if ( cnt > 10000)
	     begin
		status = R_TIMEOUT;
                $display("timeout,    time=%t, msg=%s",
                         $time, DUT.getTestResult());
		return;
	     end
           cnt++;
	end

      if (DUT.getTestResult() == "Test passed\n")
	status = R_OK;
      else
	status = R_FAIL;
   endtask // runTest

   task automatic runAllTests( string test_dir, string list_file, inout int failCount);
      automatic string tests[$];
      automatic int n, i, f;
      automatic string  failedTests = "";

      f = $fopen( $sformatf("%s/%s", test_dir, list_file ) ,"r");
      if (f == 0)
	$fatal;

      while(!$feof(f))
        begin
           automatic string fname;

           void'($fscanf(f,"%s", fname));

	   if (fname[0] == "#" || fname == "")
             continue;

	   tests.push_back(fname);
        end

      for (i=0;i<tests.size();i++)
	begin
	   automatic int failedTest;
	   automatic TestStatus status;
	   automatic string s;

           // $display("Run %s", tests[i]);

	   runTest({test_dir,"/",tests[i]}, status, failedTest );

	   if ( status == R_OK )
	     s = "PASS";
	   else if ( status == R_TIMEOUT )
	     begin
		s = "Timeout (likely fail due to CPU freeze)";
		failCount++;
                break;
	     end else begin
		s = $sformatf ("FAIL (subtest %d)", failedTest );
		failCount++;
	     end

	   msg(0, $sformatf("%s: %s", tests[i], s ) );

	end

   endtask // runAllTests

   task automatic testsResult(int failCount);
      if(failCount)
	fail ( $sformatf( "%d tests FAILED", failCount ) );
      else
	pass();
   endtask

endclass // ISATestRunner

   initial begin
      automatic int i;
      automatic ISATestRunner testRunner = new;
      automatic Logger l = Logger::get();
      automatic int failCount;

      for(i=0;i<n_configs;i++)
	begin
	   DUT.selectConfiguration(i);

	   l.startTest($sformatf( "Full ISA Test for feature set:%s", DUT.getConfigurationString() ) );

	   failCount = 0;
	   testRunner.runAllTests("../../sw/testsuite/isa", "tests.lst", failCount );
	   if (configs[i].ecc)
	     testRunner.runAllTests("../../sw/testsuite/isa", "tests-urv.lst", failCount );
	   testRunner.testsResult(failCount);
	end

      l.writeTestReport("report.txt");
      $stop;
   end


endmodule // main
