`timescale 1ns/1ps
// Actual baseline/candidate controllers and bit engines, debug toggles only.
module tb_main_dco_capture;
  reg clk=0, rst=0, dl=0, hl=0, request=0;
  reg [15:0] dd=32768, hd=5;
  always #5 clk=~clk;
  wire scl, reference_scl;
  tri1 sda, reference_sda;
  wire [63:0] meta, position, counts;
  wire ack_phase = dut.u_i2c_bus.i2c_state==3 ||
                   dut.u_i2c_bus.i2c_state==5 ||
                   dut.u_i2c_bus.i2c_state==15;
  wire reference_ack_phase = baseline.u_i2c_bus.i2c_state==3 ||
                             baseline.u_i2c_bus.i2c_state==5 ||
                             baseline.u_i2c_bus.i2c_state==15;
  assign sda=ack_phase ? 1'b0 : 1'bz;
  assign reference_sda=reference_ack_phase ? 1'b0 : 1'bz;
  si5340a_controller_dco #(.HPLL_TRACKER_CODE_PER_PHYSICAL_STEP(64)) dut (
    .iCLK(clk),.iRST_n(rst),.iStart(1'b0),
    .iPLL_OUT0_FREQ_SEL(3'd0),.iPLL_OUT1_FREQ_SEL(3'd0),
    .iPLL_OUT2_FREQ_SEL(3'd0),.iPLL_OUT3_FREQ_SEL(3'd0),
    .iDPLL_LOAD(dl),.iDPLL_DATA(dd),.iHPLL_LOAD(hl),.iHPLL_DATA(hd),
    .iFORCE_HPLL_ONE_STEP(1'b0),.iFORCE_HPLL_REVERSE(1'b0),
    .iFORCE_HPLL_BURST_SIZE(16'd1),.I2C_CLK(scl),.I2C_DATA(sda),
    .iDIAG_MAIN_CAPTURE_TOGGLE(request),.oDIAG_MAIN_CAPTURE_META(meta),
    .oDIAG_MAIN_CAPTURE_POSITION(position),.oDIAG_MAIN_CAPTURE_COUNTS(counts));
  baseline_si5340a_controller_dco #(.HPLL_TRACKER_CODE_PER_PHYSICAL_STEP(64)) baseline (
    .iCLK(clk),.iRST_n(rst),.iStart(1'b0),
    .iPLL_OUT0_FREQ_SEL(3'd0),.iPLL_OUT1_FREQ_SEL(3'd0),
    .iPLL_OUT2_FREQ_SEL(3'd0),.iPLL_OUT3_FREQ_SEL(3'd0),
    .iDPLL_LOAD(dl),.iDPLL_DATA(dd),.iHPLL_LOAD(hl),.iHPLL_DATA(hd),
    .iFORCE_HPLL_ONE_STEP(1'b0),.iFORCE_HPLL_REVERSE(1'b0),
    .iFORCE_HPLL_BURST_SIZE(16'd1),.I2C_CLK(reference_scl),.I2C_DATA(reference_sda));
  integer cycles=0, captures=0;
  always @(negedge clk) if(rst) begin
    cycles=cycles+1;
    if ({dut.rt_state,dut.rt_dir,dut.rt_select_dpll,dut.runtime_start,
         dut.runtime_byte_addr,dut.runtime_byte_data,dut.dco_step_count,
         dut.dpll_target_position,dut.dpll_applied_position,dut.dpll_pending,
         dut.hpll_target_position,dut.hpll_applied_position,dut.hpll_pending,
         dut.liveness_dpll_service_count,dut.liveness_dpll_success_count,
         dut.liveness_hpll_service_count,dut.liveness_hpll_success_count,
         scl,sda} !==
        {baseline.rt_state,baseline.rt_dir,baseline.rt_select_dpll,baseline.runtime_start,
         baseline.runtime_byte_addr,baseline.runtime_byte_data,baseline.dco_step_count,
         baseline.dpll_target_position,baseline.dpll_applied_position,baseline.dpll_pending,
         baseline.hpll_target_position,baseline.hpll_applied_position,baseline.hpll_pending,
         baseline.liveness_dpll_service_count,baseline.liveness_dpll_success_count,
         baseline.liveness_hpll_service_count,baseline.liveness_hpll_success_count,
         reference_scl,reference_sda}) $fatal(1,"Diagnostic changed functional behaviour");
  end
  task capture;
    reg [15:0] old_seq;
    integer n;
    begin
      old_seq=meta[16:1]; request=~request;
      n=0;
      while(meta[0]!==request && n<20) begin @(negedge clk); n=n+1; end
      if(n==20 || meta[16:1]!==old_seq+16'd1 || meta[31:29]!==3'd1)
        $fatal(1,"Capture handshake/schema/sequence failure");
      if(meta[23:21]!==3'd0) $fatal(1,"Unexpected ACK/timeout/DCO error");
      captures=captures+1;
    end
  endtask
  reg [63:0] saved_meta,saved_position,saved_counts;
  initial begin
    force dut.initial_start=0; force baseline.initial_start=0;
    force dut.static_start_pulse=0; force baseline.static_start_pulse=0;
    force dut.static_controller_ready=1; force baseline.static_controller_ready=1;
    force dut.i2c_system_clk=clk; force baseline.i2c_system_clk=clk;
    #1; rst=0; #99; rst=1;
    @(negedge clk); dl=1; hl=1;
    @(negedge clk); dl=0; hl=0;
    capture();
    if(position!=={32'd32768,32'd32768} || !meta[17])
      $fatal(1,"Initialization or unsigned position packing failure");
    saved_meta=meta; saved_position=position; saved_counts=counts;
    @(negedge clk); dd=32832; hd=261; dl=1; hl=1;
    @(negedge clk); dl=0; hl=0;
    repeat(500) @(negedge clk);
    if({meta,position,counts}!=={saved_meta,saved_position,saved_counts})
      $fatal(1,"Snapshot not immutable without request");
    repeat(30) begin
      capture();
      repeat(2000) @(negedge clk);
    end
    capture();
    if(position[63:32]!==32'd32832 || counts[63:32]!==32'd4)
      $fatal(1,"Actual Main completion/model position not captured");
    // Unsigned targets above signed16 range must be retained without clipping.
    @(negedge clk); dd=65535; dl=1;
    @(negedge clk); dl=0;
    capture();
    if(position[31:0]!==32'd65535) $fatal(1,"Unsigned target narrowed");
    $display("MAIN_DCO_CAPTURE_EQ=PASS cycles=%0d captures=%0d completed=%0d immutable=1 no_control_feedback=1",cycles,captures,counts[63:32]);
    $finish;
  end
  initial begin #2000000; $fatal(1,"Capture/equivalence test timeout"); end
endmodule
