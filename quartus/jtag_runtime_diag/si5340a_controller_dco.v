// SI5340 static configuration plus WR SoftPLL DCO step control.
// This diagnostic wrapper keeps the original startup table and adds a
// serialized FINC/FDEC write path after static configuration is complete.

module si5340a_controller_dco #(
parameter integer ENABLE_SAME_CODE_TEST = 0,
parameter integer ENABLE_JTAG_HPLL_BURST = 0,
parameter integer ENABLE_NORMAL_HPLL_TRACKER = 1,
parameter integer ENABLE_STEP5_BOOTSTRAP = 0,
parameter integer STEP5_BOOTSTRAP_STEPS = 6336,
parameter integer HPLL_TRACKER_CODE_PER_PHYSICAL_STEP = 34,
parameter integer JTAG_HPLL_BURST_SIZE = 32
)(
input                   iCLK,
input                   iRST_n,
input                   iStart,
input     [2:0]         iPLL_OUT0_FREQ_SEL,
input     [2:0]         iPLL_OUT1_FREQ_SEL,
input     [2:0]         iPLL_OUT2_FREQ_SEL,
input     [2:0]         iPLL_OUT3_FREQ_SEL,
input                   iDPLL_LOAD,
input     [15:0]        iDPLL_DATA,
input                   iHPLL_LOAD,
input     [15:0]        iHPLL_DATA,
input                   iFORCE_HPLL_ONE_STEP,
input                   iFORCE_HPLL_REVERSE,
input     [15:0]        iFORCE_HPLL_BURST_SIZE,
output                  I2C_CLK,
inout                   I2C_DATA,
output                  oPLL_I2C_ID_READ_ERROR,
output                  oPLL_REG_CONFIG_DONE,
output                  oDCO_BUSY,
output                  oDCO_ERROR,
output    [15:0]        oDCO_STEP_COUNT,
output    [63:0]        oDCO_DEBUG,
output    [7:0]         oDEBUG_STATIC_STATE,
output                  oDEBUG_STATIC_CONFIG_DONE_PULSE,
output                  oDEBUG_STATIC_ACCESS_START,
output    [2:0]         oDEBUG_RUNTIME_STATE,
output                  oDEBUG_BUS_STATE,
output                  oDEBUG_BUS_DONE,
output                  oDEBUG_RUNTIME_START,
output                  oDEBUG_RUNTIME_BUS_ENABLE,
output                  oDEBUG_SYSTEM_START,
output    [63:0]        oDCO_STEP5_DEBUG,
output    [63:0]        oDCO_STEP5_BURST_DEBUG,
output    [63:0]        oDCO_STEP5_BURST_WIDE_DEBUG,
output    [63:0]        oDCO_STEP5_TRACKER_DEBUG,
output    [63:0]        oDCO_STEP5_BOOTSTRAP_DEBUG,
output    [63:0]        oDCO_STEP5_POSITION_DEBUG,
output                  oDCO_STEP5_POLARITY_ACTIVE
);

wire [6:0] static_slave_addr;
wire [7:0] static_byte_addr;
wire [7:0] static_byte_data;
wire       static_wr_cmd;
wire [7:0] static_read_data;
wire       static_read_data_rdy;
wire       bus_state;
wire       bus_done;
wire       static_controller_ready;
wire       static_start_pulse;
wire [7:0] static_i2c_reg_state;
wire       static_config_done_pulse;
wire       static_access_start;
wire       initial_start;
wire       user_start_rise;
wire       i2c_system_clk;
wire       system_start;

reg [2:0]  rt_state;
reg        rt_dir;
reg        rt_select_dpll;
reg        rt_seen_busy;
reg        dpll_pending;
reg        hpll_pending;
reg        dpll_dir;
reg        hpll_dir;
reg        dpll_prev_valid;
reg        hpll_prev_valid;
reg [15:0] dpll_prev_data;
reg [15:0] hpll_prev_data;
reg [15:0] hpll_target_code;
reg [15:0] hpll_applied_code;
reg        hpll_tracker_initialized;
reg [15:0] normal_hpll_request_count;
reg [15:0] normal_hpll_completed_count;
reg [15:0] normal_finc_completed_count;
reg [15:0] normal_fdec_completed_count;
reg [15:0] dco_step_count;
reg        dco_error;
reg        same_code_test_fired;
reg        force_hpll_meta;
reg        force_hpll_sync;
reg        force_hpll_sync_prev;
reg        force_hpll_seen;
reg        force_hpll_reverse_meta;
reg        force_hpll_reverse_sync;
reg [7:0]  force_trigger_count;
reg [7:0]  forced_pending_count;
reg [15:0] force_burst_remaining;
reg        hpll_pending_forced;
reg        hpll_pending_forced_reverse;
reg        hpll_pending_bootstrap;
reg        current_request_forced;
reg        current_request_bootstrap;
reg        force_burst_reverse;
reg [7:0]  burst_trigger_count;
reg [15:0] forced_hpll_pending_count;
reg [15:0] forced_hpll_completed_count;
reg [7:0]  rt_state_enter_count;
reg [7:0]  runtime_start_count;
reg [7:0]  bus_done_count;
reg        runtime_start_prev;
reg        bus_done_prev;
reg [63:0] dco_debug;
reg [63:0] dco_step5_debug;
reg [63:0] dco_step5_burst_debug;
reg [63:0] dco_step5_burst_wide_debug;
reg [63:0] dco_step5_tracker_debug;
reg [63:0] dco_step5_bootstrap_debug;
reg [63:0] dco_step5_position_debug;
reg [15:0] bootstrap_remaining;
reg [15:0] bootstrap_completed_count;
reg        bootstrap_started;
reg        bootstrap_done;

wire [6:0] runtime_slave_addr = 7'b1110111;
wire       runtime_bus_enable = (rt_state != 3'd0);
wire       force_hpll_rise = force_hpll_sync & ~force_hpll_sync_prev;
wire [15:0] force_hpll_burst_size =
  (iFORCE_HPLL_BURST_SIZE != 16'd0) ?
    iFORCE_HPLL_BURST_SIZE : JTAG_HPLL_BURST_SIZE[15:0];
// Keep the corrected-SOF three-write runtime sequence as the A/B baseline.
// This experiment changes only the request handshake below.
wire [7:0] runtime_byte_addr =
  (rt_state == 3'd1 || rt_state == 3'd2) ? 8'h01 :
  (rt_state == 3'd3 || rt_state == 3'd4) ? 8'h39 : 8'h1D;
// Register 0x0339 uses zero to enable a divider and one to mask it.
// DPLL drives N0; HPLL/DMTD drives N1.  Keep the other N dividers masked.
wire [7:0] runtime_byte_data =
  (rt_state == 3'd1 || rt_state == 3'd2) ? 8'h00 :
  (rt_state == 3'd3 || rt_state == 3'd4) ?
    (rt_select_dpll ? 8'h0E : 8'h0D) :
  // SI5340 FINC is bit 0 and FDEC is bit 1.  A larger WR DAC code is
  // treated as a request for FINC; this direction is verified on hardware.
  (rt_dir ? 8'h01 : 8'h02);
wire       runtime_start = ((rt_state == 3'd1 || rt_state == 3'd3 ||
                              rt_state == 3'd5) &&
                            !bus_state && static_controller_ready);

wire       static_bus_enable = system_start || !static_controller_ready || bus_state;
wire       bus_enable = static_bus_enable || runtime_bus_enable;
// Keep the known-good single-cycle runtime request handshake.
wire       bus_start = static_start_pulse || runtime_start;
wire [6:0] bus_slave_addr = runtime_bus_enable ? runtime_slave_addr : static_slave_addr;
wire [7:0] bus_byte_addr = runtime_bus_enable ? runtime_byte_addr : static_byte_addr;
wire [7:0] bus_byte_data = runtime_bus_enable ? runtime_byte_data : static_byte_data;
wire       bus_wr_cmd = runtime_bus_enable ? 1'b1 : static_wr_cmd;

assign oPLL_REG_CONFIG_DONE = static_controller_ready;
assign oDCO_BUSY = (rt_state != 3'd0);
assign oDCO_ERROR = dco_error;
assign oDCO_STEP_COUNT = dco_step_count;
assign oPLL_I2C_ID_READ_ERROR = 1'b0;
assign oDEBUG_STATIC_STATE = static_i2c_reg_state;
assign oDEBUG_STATIC_CONFIG_DONE_PULSE = static_config_done_pulse;
assign oDEBUG_STATIC_ACCESS_START = static_access_start;
assign oDEBUG_RUNTIME_STATE = rt_state;
assign oDEBUG_BUS_STATE = bus_state;
assign oDEBUG_BUS_DONE = bus_done;
assign oDEBUG_RUNTIME_START = runtime_start;
assign oDEBUG_RUNTIME_BUS_ENABLE = runtime_bus_enable;
assign oDEBUG_SYSTEM_START = system_start;
assign oDCO_STEP5_DEBUG = dco_step5_debug;
assign oDCO_STEP5_BURST_DEBUG = dco_step5_burst_debug;
assign oDCO_STEP5_BURST_WIDE_DEBUG = dco_step5_burst_wide_debug;
assign oDCO_STEP5_TRACKER_DEBUG = dco_step5_tracker_debug;
assign oDCO_STEP5_BOOTSTRAP_DEBUG = dco_step5_bootstrap_debug;
assign oDCO_STEP5_POSITION_DEBUG = dco_step5_position_debug;
assign oDCO_STEP5_POLARITY_ACTIVE = force_burst_reverse;

// Read-only clean-9f DCO observability.  This exposes the existing
// controller state without changing the request or I2C state machine.
always @* begin
  dco_debug = 64'd0;
  dco_debug[2:0]   = rt_state;
  dco_debug[3]     = bus_state;
  dco_debug[4]     = bus_done;
  dco_debug[5]     = static_controller_ready;
  dco_debug[6]     = dpll_pending;
  dco_debug[7]     = hpll_pending;
  dco_debug[8]     = dpll_prev_valid;
  dco_debug[9]     = hpll_prev_valid;
  dco_debug[10]    = rt_select_dpll;
  dco_debug[11]    = rt_dir;
  dco_debug[12]    = dpll_dir;
  dco_debug[13]    = hpll_dir;
  dco_debug[14]    = runtime_start;
  dco_debug[15]    = bus_enable;
  dco_debug[16]    = iDPLL_LOAD;
  dco_debug[17]    = iHPLL_LOAD;
  dco_debug[18]    = dco_error;
  dco_debug[19]    = oDCO_BUSY;
  dco_debug[35:20] = dco_step_count;
  dco_debug[51:36] = dpll_prev_data;
  // Bit 52 records the one-shot Step5 same-code A/B on the Slave image.
  dco_debug[52]    = same_code_test_fired;
  dco_debug[63:53] = hpll_prev_data[10:0];
end

// JTAG-triggered bounded-burst evidence.  A single accepted source rising
// edge arms a bounded number of serialized HPLL requests; these counters distinguish the
// trigger, request admission, and completed runtime transactions.
always @* begin
  dco_step5_burst_debug = 64'd0;
  dco_step5_burst_debug[7:0]   = burst_trigger_count;
  dco_step5_burst_debug[15:8]  = forced_hpll_pending_count;
  dco_step5_burst_debug[23:16] = forced_hpll_completed_count;
  dco_step5_burst_debug[31:24] = rt_state_enter_count;
  dco_step5_burst_debug[39:32] = runtime_start_count;
  dco_step5_burst_debug[47:40] = bus_done_count;
  dco_step5_burst_debug[63:48] = dco_step_count;
end

// Wide calibration-only evidence.  Probe 41 preserves the legacy probe 37
// layout while exposing non-wrapping counters for the zero-crossing sweep:
// [15:0] burst triggers, [31:16] forced requests admitted, [47:32] forced
// transactions completed, and [63:48] total DCO transactions completed.
always @* begin
  dco_step5_burst_wide_debug = 64'd0;
  dco_step5_burst_wide_debug[15:0]  = {8'd0, burst_trigger_count};
  dco_step5_burst_wide_debug[31:16] = forced_hpll_pending_count;
  dco_step5_burst_wide_debug[47:32] = forced_hpll_completed_count;
  dco_step5_burst_wide_debug[63:48] = dco_step_count;
end

assign oDCO_DEBUG = dco_debug;

// JTAG-triggered Step5 evidence.  The first five fields are 8-bit event
// counters; the step count is copied as a 16-bit field.  The counters are
// sticky until reset so a short JTAG probe read cannot miss a pulse.
always @* begin
  dco_step5_debug = 64'd0;
  dco_step5_debug[7:0]   = force_trigger_count;
  dco_step5_debug[15:8]  = forced_pending_count;
  dco_step5_debug[23:16] = rt_state_enter_count;
  dco_step5_debug[31:24] = runtime_start_count;
  dco_step5_debug[39:32] = bus_done_count;
  dco_step5_debug[55:40] = dco_step_count;
  dco_step5_debug[56]    = force_hpll_seen;
  dco_step5_debug[57]    = force_hpll_sync;
  dco_step5_debug[58]    = force_hpll_rise;
  dco_step5_debug[59]    = hpll_pending;
  dco_step5_debug[60]    = hpll_prev_valid;
  dco_step5_debug[61]    = static_controller_ready;
  dco_step5_debug[63:62] = rt_state[1:0];
end

// Normal HPLL absolute-target tracker evidence.  The target and virtual
// applied code are both in the WR helper DAC-code domain.  Request and
// completion counters are intentionally separate from the forced-burst
// counters so the closed-loop experiment can prove that every completed
// normal transaction advances the virtual code by exactly one.
always @* begin
  dco_step5_tracker_debug = 64'd0;
  dco_step5_tracker_debug[15:0]  = hpll_target_code;
  dco_step5_tracker_debug[31:16] = hpll_applied_code;
  dco_step5_tracker_debug[47:32] = normal_hpll_request_count;
  dco_step5_tracker_debug[63:48] = normal_hpll_completed_count;
end

// Step5 bootstrap evidence.  The bootstrap is intentionally separate from
// the normal tracker: after fresh-program, it applies the measured physical
// zero-point offset before any normal quantized tracker transaction is
// admitted.
// [15:0] remaining bootstrap steps, [31:16] completed bootstrap steps,
// bit 32 started, bit 33 done, bit 34 pending, bit 35 current transaction.
always @* begin
  dco_step5_bootstrap_debug = 64'd0;
  dco_step5_bootstrap_debug[15:0]  = bootstrap_remaining;
  dco_step5_bootstrap_debug[31:16] = bootstrap_completed_count;
  dco_step5_bootstrap_debug[32] = bootstrap_started;
  dco_step5_bootstrap_debug[33] = bootstrap_done;
  dco_step5_bootstrap_debug[34] = hpll_pending_bootstrap;
  dco_step5_bootstrap_debug[35] = current_request_bootstrap;
end

// Step5 signed physical-position audit evidence.  These counters record
// only completed normal HPLL FINC/FDEC transactions; bootstrap and forced
// calibration requests are intentionally excluded.  The host-side audit
// reconstructs the signed normal net as FINC-FDEC and checks it against the
// virtual applied code: applied = 5 + 64 * (FINC-FDEC).
// [15:0] target, [31:16] virtual applied, [47:32] normal FINC completed,
// [63:48] normal FDEC completed.
always @* begin
  dco_step5_position_debug = 64'd0;
  dco_step5_position_debug[15:0]  = hpll_target_code;
  dco_step5_position_debug[31:16] = hpll_applied_code;
  dco_step5_position_debug[47:32] = normal_finc_completed_count;
  dco_step5_position_debug[63:48] = normal_fdec_completed_count;
end

si5340a_i2c_reg_controller_dco u_static_reg_controller(
  .iCLK(iCLK),
  .iRST_n(iRST_n),
  .iENABLE(system_start),
  .iPLL_OUT0_FREQ_SEL(iPLL_OUT0_FREQ_SEL),
  .iPLL_OUT1_FREQ_SEL(iPLL_OUT1_FREQ_SEL),
  .iPLL_OUT2_FREQ_SEL(iPLL_OUT2_FREQ_SEL),
  .iPLL_OUT3_FREQ_SEL(iPLL_OUT3_FREQ_SEL),
  .iI2C_CONTROLLER_STATE(bus_state),
  .iI2C_CONTROLLER_CONFIG_DONE(bus_done),
  .oSLAVE_ADDR(static_slave_addr),
  .oBYTE_ADDR(static_byte_addr),
  .oBYTE_DATA(static_byte_data),
  .oWR_CMD(static_wr_cmd),
  .oStart(static_start_pulse),
  .iI2C_READ_DATA_RDY(static_read_data_rdy),
  .iI2C_READ_DATA(static_read_data),
  .oONE_CLK_CONFIG_DONE(),
  .oController_Ready(static_controller_ready),
  .oDEBUG_STATIC_STATE(static_i2c_reg_state),
  .oDEBUG_STATIC_CONFIG_DONE_PULSE(static_config_done_pulse),
  .oDEBUG_STATIC_ACCESS_START(static_access_start)
);

initial_config u_initial_config(
  .iCLK(iCLK),
  .iRST_n(iRST_n),
  .oINITIAL_START(initial_start),
  .iINITIAL_ENABLE(1'b1)
);

edge_detector u_start_edge(
  .iCLK(iCLK),
  .iRST_n(iRST_n),
  .iIn(iStart),
  .oFallING_EDGE(),
  .oRISING_EDGE(user_start_rise)
);

assign system_start = user_start_rise | initial_start;

clock_divider u_clock_divider(
  .iCLK(iCLK),
  .iRST_n(iRST_n),
  .oCLK_OUT(i2c_system_clk)
);

i2c_bus_controller_dco u_i2c_bus(
  .iCLK(i2c_system_clk),
  .iRST_n(iRST_n),
  .iENABLE(bus_enable),
  .iStart(bus_start),
  .iSlave_addr(bus_slave_addr),
  .iWord_addr(bus_byte_addr),
  .iSequential_read(1'b0),
  .iRead_length(8'd1),
  .i2c_clk(I2C_CLK),
  .i2c_data(I2C_DATA),
  .i2c_read_data(static_read_data),
  .i2c_read_data_rdy(static_read_data_rdy),
  .wr_data(bus_byte_data),
  .wr_cmd(bus_wr_cmd),
  .oSYSTEM_STATE(bus_state),
  .oCONFIG_DONE(bus_done)
);

// Serialize each WR DAC update as three I2C writes:
// select page 0, select the N0/N1 divider mask, then issue FINC/FDEC.
always @(posedge iCLK or negedge iRST_n) begin
  if (!iRST_n) begin
    rt_state         <= 3'd0;
    rt_dir           <= 1'b0;
    rt_select_dpll   <= 1'b0;
    rt_seen_busy     <= 1'b0;
    dpll_pending     <= 1'b0;
    hpll_pending     <= 1'b0;
    dpll_dir         <= 1'b0;
    hpll_dir         <= 1'b0;
    dpll_prev_valid  <= 1'b0;
    hpll_prev_valid  <= 1'b0;
    dpll_prev_data   <= 16'd0;
    hpll_prev_data   <= 16'd0;
    hpll_target_code <= 16'd0;
    hpll_applied_code <= 16'd0;
    hpll_tracker_initialized <= 1'b0;
    normal_hpll_request_count <= 16'd0;
    normal_hpll_completed_count <= 16'd0;
    normal_finc_completed_count <= 16'd0;
    normal_fdec_completed_count <= 16'd0;
    dco_step_count   <= 16'd0;
    dco_error        <= 1'b0;
    same_code_test_fired <= 1'b0;
    force_hpll_meta  <= 1'b0;
    force_hpll_sync  <= 1'b0;
    force_hpll_sync_prev <= 1'b0;
    force_hpll_seen  <= 1'b0;
    force_hpll_reverse_meta <= 1'b0;
    force_hpll_reverse_sync <= 1'b0;
    force_trigger_count <= 8'd0;
    forced_pending_count <= 8'd0;
    force_burst_remaining <= 16'd0;
    hpll_pending_forced <= 1'b0;
    hpll_pending_forced_reverse <= 1'b0;
    hpll_pending_bootstrap <= 1'b0;
    current_request_forced <= 1'b0;
    current_request_bootstrap <= 1'b0;
    force_burst_reverse <= 1'b0;
    burst_trigger_count <= 8'd0;
    forced_hpll_pending_count <= 16'd0;
    forced_hpll_completed_count <= 16'd0;
    bootstrap_remaining <= 16'd0;
    bootstrap_completed_count <= 16'd0;
    bootstrap_started <= 1'b0;
    bootstrap_done <= 1'b0;
    rt_state_enter_count <= 8'd0;
    runtime_start_count <= 8'd0;
    bus_done_count <= 8'd0;
    runtime_start_prev <= 1'b0;
    bus_done_prev <= 1'b0;
  end else begin
    force_hpll_meta <= iFORCE_HPLL_ONE_STEP;
    force_hpll_sync <= force_hpll_meta;
    force_hpll_sync_prev <= force_hpll_sync;
    force_hpll_reverse_meta <= iFORCE_HPLL_REVERSE;
    force_hpll_reverse_sync <= force_hpll_reverse_meta;
    runtime_start_prev <= runtime_start;
    bus_done_prev <= bus_done;

    if (runtime_start && !runtime_start_prev)
      runtime_start_count <= runtime_start_count + 1'b1;
    if (bus_done && !bus_done_prev)
      bus_done_count <= bus_done_count + 1'b1;

    if (force_hpll_rise && !force_hpll_seen) begin
      force_hpll_seen <= 1'b1;
      force_trigger_count <= force_trigger_count + 1'b1;
      // The trigger is intentionally accepted only at the ready, idle
      // boundary.  The burst variant arms thirty-two requests and lets the
      // controller serialize them; the legacy path still admits one request.
      if (static_controller_ready && hpll_prev_valid &&
          (rt_state == 3'd0)) begin
        if (ENABLE_JTAG_HPLL_BURST) begin
          force_burst_remaining <= force_hpll_burst_size;
          force_burst_reverse <= force_hpll_reverse_sync;
          burst_trigger_count <= burst_trigger_count + 1'b1;
        end else begin
          hpll_pending <= 1'b1;
          hpll_pending_forced <= 1'b1;
          hpll_pending_forced_reverse <= 1'b0;
          forced_pending_count <= forced_pending_count + 1'b1;
        end
      end
    end

    if (iDPLL_LOAD) begin
      if (dpll_prev_valid && (iDPLL_DATA != dpll_prev_data)) begin
        dpll_pending <= 1'b1;
        dpll_dir <= (iDPLL_DATA > dpll_prev_data);
      end
      dpll_prev_data <= iDPLL_DATA;
      dpll_prev_valid <= 1'b1;
    end
    if (iHPLL_LOAD) begin
      // Keep the newest absolute target.  The idle-state tracker below
      // serializes one FINC/FDEC request at a time until applied==target.
      hpll_target_code <= iHPLL_DATA;
      // Preserve the proven A-polarity direction for forced calibration even
      // when the normal absolute-target tracker is disabled in the
      // calibration image.
      if (hpll_prev_valid && (iHPLL_DATA != hpll_prev_data))
        hpll_dir <= (iHPLL_DATA > hpll_prev_data);
      if (!hpll_tracker_initialized) begin
        // WR node helper_start() uses pi.y_min, which is 5 for the DE5a
        // generic 16-bit DAC configuration.
        hpll_applied_code <= 16'd5;
        hpll_tracker_initialized <= 1'b1;
      end
      if (ENABLE_SAME_CODE_TEST && hpll_prev_valid &&
                   (iHPLL_DATA == hpll_prev_data) &&
                   !same_code_test_fired) begin
        // Step5 causal A/B only: admit exactly one same-code request on the
        // Slave image, then permanently disarm this experiment path.
        hpll_pending <= 1'b1;
        hpll_pending_forced <= 1'b0;
        same_code_test_fired <= 1'b1;
      end
      hpll_prev_data <= iHPLL_DATA;
      hpll_prev_valid <= 1'b1;
    end

    case (rt_state)
      3'd0: begin
        rt_seen_busy <= 1'b0;
        if (static_controller_ready && dpll_pending) begin
          rt_state <= 3'd1;
          rt_state_enter_count <= rt_state_enter_count + 1'b1;
          rt_select_dpll <= 1'b1;
          rt_dir <= dpll_dir;
          dpll_pending <= 1'b0;
          current_request_forced <= 1'b0;
        end else if (static_controller_ready && hpll_pending) begin
          rt_state <= 3'd1;
          rt_state_enter_count <= rt_state_enter_count + 1'b1;
          rt_select_dpll <= 1'b0;
          rt_dir <= hpll_pending_forced_reverse ? ~hpll_dir : hpll_dir;
          hpll_pending <= 1'b0;
          current_request_forced <= hpll_pending_forced;
          current_request_bootstrap <= hpll_pending_bootstrap;
          if (!hpll_pending_forced)
            normal_hpll_request_count <= normal_hpll_request_count + 1'b1;
          hpll_pending_forced <= 1'b0;
          hpll_pending_bootstrap <= 1'b0;
        end else if (ENABLE_STEP5_BOOTSTRAP &&
                     static_controller_ready && hpll_tracker_initialized &&
                     hpll_prev_valid && !bootstrap_started &&
                     (STEP5_BOOTSTRAP_STEPS > 0)) begin
          // Start exactly once after the first valid HPLL target has been
          // observed.  The first physical step is queued here; the remaining
          // steps are serialized below at the idle boundary.
          bootstrap_started <= 1'b1;
          bootstrap_remaining <= STEP5_BOOTSTRAP_STEPS - 1;
          hpll_pending <= 1'b1;
          hpll_pending_forced <= 1'b1;
          hpll_pending_forced_reverse <= 1'b0;
          hpll_pending_bootstrap <= 1'b1;
        end else if (ENABLE_STEP5_BOOTSTRAP && bootstrap_started &&
                     !bootstrap_done && static_controller_ready &&
                     (bootstrap_remaining != 16'd0)) begin
          // Queue one A-direction bootstrap request at a time.  This uses
          // the same serialized runtime transaction path as the proven
          // forced-burst stimulus, but is automatic and runs before normal
          // tracker admission.
          hpll_pending <= 1'b1;
          hpll_pending_forced <= 1'b1;
          hpll_pending_forced_reverse <= 1'b0;
          hpll_pending_bootstrap <= 1'b1;
          bootstrap_remaining <= bootstrap_remaining - 1'b1;
        end else if (ENABLE_JTAG_HPLL_BURST &&
                     static_controller_ready &&
                     (force_burst_remaining != 16'd0)) begin
          // Queue only one forced request at a time.  The next request is
          // admitted after the current three-write runtime sequence returns
          // to idle, so the thirty-two-step burst is controller-serialized.
          hpll_pending <= 1'b1;
          hpll_pending_forced <= 1'b1;
          hpll_pending_forced_reverse <= force_burst_reverse;
          force_burst_remaining <= force_burst_remaining - 1'b1;
          forced_hpll_pending_count <= forced_hpll_pending_count + 1'b1;
        end else if (ENABLE_NORMAL_HPLL_TRACKER &&
                     static_controller_ready &&
                     hpll_tracker_initialized && hpll_prev_valid &&
                     (((hpll_target_code > hpll_applied_code) &&
                       ((hpll_target_code - hpll_applied_code) >= HPLL_TRACKER_CODE_PER_PHYSICAL_STEP[15:0])) ||
                      ((hpll_applied_code > hpll_target_code) &&
                       ((hpll_applied_code - hpll_target_code) >= HPLL_TRACKER_CODE_PER_PHYSICAL_STEP[15:0])))) begin
          // Normal HPLL closed-loop path: admit only one outstanding
          // transaction, but only when the residual spans a complete
          // physical DCO step.  A sub-step residual is retained until a
          // later target update moves it across the quantization boundary.
          hpll_pending <= 1'b1;
          hpll_pending_forced <= 1'b0;
          hpll_pending_forced_reverse <= 1'b0;
          hpll_dir <= (hpll_target_code > hpll_applied_code);
        end
      end
      3'd1: begin
        // runtime_start is generated in iCLK, while the I2C controller
        // observes iStart on its divided clock. Keep state 1 active until
        // bus_state confirms that the request was accepted.
        if (bus_state)
          rt_state <= 3'd2;
      end
      3'd2: begin
        if (bus_state)
          rt_seen_busy <= 1'b1;
        else if (rt_seen_busy) begin
          rt_state <= 3'd3;
          rt_seen_busy <= 1'b0;
        end
      end
      3'd3: begin
        if (bus_state)
          rt_state <= 3'd4;
      end
      3'd4: begin
        if (bus_state)
          rt_seen_busy <= 1'b1;
        else if (rt_seen_busy) begin
          rt_state <= 3'd5;
          rt_seen_busy <= 1'b0;
        end
      end
      3'd5: begin
        if (bus_state)
          rt_state <= 3'd6;
      end
      3'd6: begin
        if (bus_state)
          rt_seen_busy <= 1'b1;
        else if (rt_seen_busy) begin
          rt_state <= 3'd0;
          rt_seen_busy <= 1'b0;
          dco_step_count <= dco_step_count + 1'b1;
          if (current_request_forced) begin
            forced_hpll_completed_count <= forced_hpll_completed_count + 1'b1;
            if (current_request_bootstrap) begin
              bootstrap_completed_count <= bootstrap_completed_count + 1'b1;
              // remaining reaches zero when the final bootstrap transaction
              // is queued, so completion of that in-flight request is the
              // precise bootstrap_done boundary.
              if (bootstrap_remaining == 16'd0)
                bootstrap_done <= 1'b1;
              current_request_bootstrap <= 1'b0;
            end
            current_request_forced <= 1'b0;
          end else if (ENABLE_NORMAL_HPLL_TRACKER &&
                       !rt_select_dpll && hpll_tracker_initialized) begin
            // One physical FINC/FDEC maps to exactly one configured number
            // of virtual WR DAC
            // codes.  Keep the virtual position quantized: a completed
            // physical transaction always advances it by exactly one full
            // physical-step code.  The admission guard above prevents a
            // sub-step request, so no partial credit or target snap is
            // allowed here.
            if (rt_dir) begin
              hpll_applied_code <= hpll_applied_code + HPLL_TRACKER_CODE_PER_PHYSICAL_STEP[15:0];
              normal_finc_completed_count <= normal_finc_completed_count + 1'b1;
            end else begin
              hpll_applied_code <= hpll_applied_code - HPLL_TRACKER_CODE_PER_PHYSICAL_STEP[15:0];
              normal_fdec_completed_count <= normal_fdec_completed_count + 1'b1;
            end
            normal_hpll_completed_count <= normal_hpll_completed_count + 1'b1;
          end
        end
      end
      default: rt_state <= 3'd0;
    endcase
  end
end

endmodule
