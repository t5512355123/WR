`timescale 1ns/1ps
// L1: exercise the production DCO serializer with a pin-level I2C model.
// This test intentionally does not change the arbiter or completion logic.
module tb_dco_liveness;
  reg clk = 0;
  reg rst_n = 0;
  reg dpll_load = 0;
  reg hpll_load = 0;
  reg [15:0] dpll_data = 0;
  reg [15:0] hpll_data = 5;
  reg nack_inject = 0;
  reg nack_consumed = 0;
  always #5 clk = ~clk;

  wire scl;
  tri1 sda;
  reg ack_drive = 0;
  reg bus_active = 0;
  integer bit_count = 0;
  integer byte_count = 0;
  integer tx_write_index = 0;
  integer logical_slot = 0;
  reg [7:0] shift = 0;
  reg [7:0] word_addr = 0;
  reg [7:0] current_page = 0;
  reg [7:0] current_mask = 8'h0c;

  integer transactions = 0;
  integer n0_commands = 0;
  integer n1_commands = 0;
  integer wrong_page = 0;
  integer sequence_errors = 0;
  integer nack_count = 0;
  reg nack_seen_any = 0;
  integer first_hpll_time = -1;
  integer main_at_first_hpll = -1;
  integer fail_count = 0;

  wire [15:0] dco_steps;
  wire [63:0] i2c_debug;
  wire ack_error;

  assign sda = ack_drive ? 1'b0 : 1'bz;

  si5340a_controller_dco #(
    .ENABLE_NORMAL_HPLL_TRACKER(1),
    .ENABLE_STEP5_BOOTSTRAP(0),
    .HPLL_TRACKER_CODE_PER_PHYSICAL_STEP(64),
    .DPLL_TRACKER_CODE_PER_PHYSICAL_STEP(16),
    .STEP5_NORMAL_HPLL_COOLDOWN_LOADS(0)
  ) dut (
    .iCLK(clk), .iRST_n(rst_n), .iStart(1'b0),
    .iPLL_OUT0_FREQ_SEL(3'd0), .iPLL_OUT1_FREQ_SEL(3'd0),
    .iPLL_OUT2_FREQ_SEL(3'd0), .iPLL_OUT3_FREQ_SEL(3'd0),
    .iDPLL_LOAD(dpll_load), .iDPLL_DATA(dpll_data),
    .iHPLL_LOAD(hpll_load), .iHPLL_DATA(hpll_data),
    .iFORCE_HPLL_ONE_STEP(1'b0), .iFORCE_HPLL_REVERSE(1'b0),
    .iFORCE_HPLL_BURST_SIZE(16'd1),
    .I2C_CLK(scl), .I2C_DATA(sda),
    .oPLL_I2C_ID_READ_ERROR(), .oPLL_REG_CONFIG_DONE(),
    .oDCO_BUSY(), .oDCO_ERROR(), .oDCO_STEP_COUNT(dco_steps),
    .oDCO_DEBUG(), .oDEBUG_STATIC_STATE(),
    .oDEBUG_STATIC_CONFIG_DONE_PULSE(), .oDEBUG_STATIC_ACCESS_START(),
    .oDEBUG_RUNTIME_STATE(), .oDEBUG_BUS_STATE(), .oDEBUG_BUS_DONE(),
    .oDEBUG_RUNTIME_START(), .oDEBUG_RUNTIME_BUS_ENABLE(),
    .oDEBUG_SYSTEM_START(), .oDCO_STEP5_DEBUG(),
    .oDCO_STEP5_BURST_DEBUG(), .oDCO_STEP5_BURST_WIDE_DEBUG(),
    .oDCO_STEP5_TRACKER_DEBUG(), .oDCO_STEP5_BOOTSTRAP_DEBUG(),
    .oDCO_STEP5_POSITION_DEBUG(), .oDCO_STEP5_POSITION_ACCOUNTING_DEBUG(),
    .oDCO_STEP5_ACTUATOR_DEBUG(), .oDCO_STEP5_I2C_DEBUG(i2c_debug),
    .oDCO_STEP5_I2C_SEQUENCE_DEBUG(), .oDCO_STEP5_POLARITY_ACTIVE()
  );

  assign ack_error = dut.u_i2c_bus.oACK_ERROR;

  // Keep the static configuration path out of this L1 test. The runtime
  // serializer and the real low-level I2C engine remain in the DUT.
  initial begin
    force dut.initial_start = 1'b0;
    force dut.static_start_pulse = 1'b0;
    force dut.static_controller_ready = 1'b1;
    force dut.i2c_system_clk = clk;
  end

  // Decode the three-byte writes made by the real I2C engine. The model ACKs
  // every byte except the first data byte requested by the NACK case.
  always @(negedge sda) begin
    if (scl === 1'b1 && rst_n) begin
      bus_active = 1;
      bit_count = 0;
      byte_count = 0;
      tx_write_index = 0;
      shift = 0;
    end
  end

  always @(posedge sda) begin
    if (scl === 1'b1)
      bus_active = 0;
  end

  always @(negedge scl) begin
    if (bus_active && bit_count == 8) begin
      if (nack_inject && byte_count == 2 && !nack_seen_any) begin
        ack_drive = 0;
        nack_seen_any = 1;
        nack_count = nack_count + 1;
      end else begin
        ack_drive = 1;
      end
    end else begin
      ack_drive = 0;
    end
  end

  always @(posedge scl) begin
    if (bus_active) begin
      if (bit_count == 8) begin
        bit_count = 0;
        byte_count = byte_count + 1;
      end else begin
        shift = {shift[6:0], sda};
        bit_count = bit_count + 1;
        if (bit_count == 8) begin
          if (byte_count == 0 && shift != 8'hee)
            sequence_errors = sequence_errors + 1;
          if (byte_count == 1)
            word_addr = shift;
          if (byte_count == 2) begin
            if (logical_slot == 0 && (word_addr != 8'h01 || shift != 8'h03))
              sequence_errors = sequence_errors + 1;
            if (logical_slot == 1 && (word_addr != 8'h39 ||
                                      (shift != 8'h0e && shift != 8'h0d)))
              sequence_errors = sequence_errors + 1;
            if (logical_slot == 2 && (word_addr != 8'h01 || shift != 8'h00))
              sequence_errors = sequence_errors + 1;
            if (logical_slot == 3 && word_addr != 8'h1d)
              sequence_errors = sequence_errors + 1;
            if (word_addr == 8'h01)
              current_page = shift;
            else if (word_addr == 8'h39 && current_page == 3)
              current_mask = shift;
            else if (word_addr == 8'h39 && current_page == 0)
              wrong_page = wrong_page + 1;
            else if (word_addr == 8'h1d && current_page == 0) begin
              if (!current_mask[0]) begin
                n0_commands = n0_commands + 1;
              end
              if (!current_mask[1]) begin
                n1_commands = n1_commands + 1;
                if (first_hpll_time < 0) begin
                  first_hpll_time = $time;
                  main_at_first_hpll = n0_commands;
                end
              end
              if (logical_slot == 3)
                transactions = transactions + 1;
            end
            if (logical_slot == 3)
              logical_slot = 0;
            else
              logical_slot = logical_slot + 1;
          end
        end
      end
    end
  end

  task automatic reset_dut;
    begin
      rst_n = 0;
      dpll_load = 0;
      hpll_load = 0;
      logical_slot = 0;
      current_page = 0;
      current_mask = 8'h0c;
      repeat (8) @(posedge clk);
      rst_n = 1;
      repeat (8) @(posedge clk);
    end
  endtask

  task automatic load_main(input [15:0] value);
    begin
      @(negedge clk);
      dpll_data = value;
      dpll_load = 1;
      @(negedge clk);
      dpll_load = 0;
    end
  endtask

  task automatic load_helper(input [15:0] value);
    begin
      @(negedge clk);
      hpll_data = value;
      hpll_load = 1;
      @(negedge clk);
      hpll_load = 0;
    end
  endtask

  task automatic print_counters(input [8*24-1:0] label,
                                input integer base_n0,
                                input integer base_n1,
                                input integer base_tx);
    begin
      $display("L1_CASE=%0s MAIN_COMPLETED=%0d HELPER_COMPLETED=%0d TRANSACTIONS=%0d WRONG_PAGE=%0d SEQUENCE_ERRORS=%0d ACK_ERROR=%0d DCO_STEPS=%0d",
               label, n0_commands-base_n0, n1_commands-base_n1,
               transactions-base_tx, wrong_page, sequence_errors,
               ack_error, dco_steps);
    end
  endtask

  initial begin : test_body
    integer base_n0;
    integer base_n1;
    integer base_tx;
    integer before_hpll;
    integer elapsed_hpll;
    integer contention_start_time;

    #100;

    // Case 1: one Main target jump must be drained to the absolute target.
    reset_dut();
    base_n0 = n0_commands; base_n1 = n1_commands; base_tx = transactions;
    load_main(16'd32768);
    load_main(16'd32832); // four 16-code DPLL steps
    #500000;
    print_counters("MAIN_JUMP", base_n0, base_n1, base_tx);
    if ((n0_commands-base_n0) < 4) begin
      $display("L1_UNEXPECTED_MAIN_RESIDUAL_NOT_DRAINED=1");
      fail_count = fail_count + 1;
    end

    // Case 2: one Helper jump must also be drained to the absolute target.
    reset_dut();
    base_n0 = n0_commands; base_n1 = n1_commands; base_tx = transactions;
    first_hpll_time = -1;
    load_helper(16'd5);
    load_helper(16'd261); // four 64-code HPLL steps
    #500000;
    print_counters("HELPER_JUMP", base_n0, base_n1, base_tx);
    if ((n1_commands-base_n1) < 4) begin
      $display("L1_UNEXPECTED_HELPER_RESIDUAL_NOT_DRAINED=1");
      fail_count = fail_count + 1;
    end

    // Case 3: keep Main ready with residual work while Helper is ready.
    // The current fixed-priority arbiter is expected to expose a bounded or
    // unbounded wait here; the result is evidence, not a functional edit.
    reset_dut();
    base_n0 = n0_commands; base_n1 = n1_commands; base_tx = transactions;
    first_hpll_time = -1;
    main_at_first_hpll = -1;
    contention_start_time = $time;
    load_main(16'd32768);
    load_helper(16'd5);
    load_main(16'd35968); // 200 DPLL steps keeps Main residual pending
    load_helper(16'd261);
    fork : main_feeder
      begin
        repeat (160) begin
          load_main(16'd35968);
          repeat (3) @(posedge clk);
        end
      end
    join_none
    #1000000;
    disable main_feeder;
    before_hpll = n0_commands-base_n0;
    elapsed_hpll = (first_hpll_time < 0) ? -1 : first_hpll_time-contention_start_time;
    print_counters("MAIN_HELPER_CONTENTION", base_n0, base_n1, base_tx);
    $display("L1_CONTENTION MAIN_BEFORE_FIRST_HELPER=%0d FIRST_HELPER_TIME_NS=%0d",
             main_at_first_hpll, elapsed_hpll);
    if ((n1_commands-base_n1) == 0 && before_hpll > 0)
      $display("SOURCE_LIVENESS_RISK_REPRODUCED=YES");
    else
      $display("SOURCE_LIVENESS_RISK_REPRODUCED=NO_OR_NOT_REPRODUCED");

    // Case 4: inject one NACK into a final data byte. The current source is
    // known to expose sticky ACK error separately from applied/completion;
    // record whether that completion contract is safe without changing it.
    reset_dut();
    base_n1 = n1_commands;
    nack_seen_any = 0;
    nack_inject = 1;
    load_helper(16'd5);
    load_helper(16'd69); // one physical HPLL step
    #500000;
    nack_inject = 0;
    $display("L1_CASE=NACK_COMPLETION NACKS=%0d HELPER_COMPLETED=%0d ACK_ERROR=%0d DCO_ERROR=%0d",
             nack_count, n1_commands-base_n1, ack_error, dut.dco_error);
    if (nack_count == 0)
      $display("L1_NACK_INJECTION=NOT_OBSERVED");
    else if (ack_error && (n1_commands-base_n1) > 0)
      $display("TRANSACTION_COMPLETION_DEFECT_REPRODUCED=YES");
    else
      $display("TRANSACTION_COMPLETION_DEFECT_REPRODUCED=NO_OR_ABORTED");

    $display("L1_DCO_LIVENESS_SUMMARY MAIN_COMMANDS=%0d HELPER_COMMANDS=%0d TRANSACTIONS=%0d WRONG_PAGE=%0d SEQUENCE_ERRORS=%0d FAIL_COUNT=%0d",
             n0_commands, n1_commands, transactions, wrong_page,
             sequence_errors, fail_count);
    if (fail_count != 0 || wrong_page != 0 || sequence_errors != 0)
      $display("L1_TEST_RESULT=FAIL");
    else
      $display("L1_TEST_RESULT=PASS");
    $finish;
  end

  initial begin
    #5000000;
    $display("L1_TEST_RESULT=TIMEOUT rt_state=%0d bus_state=%0d", dut.rt_state, dut.u_i2c_bus.i2c_state);
    $fatal(1, "L1 simulation timeout");
  end
endmodule
