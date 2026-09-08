// SI5340 static configuration plus WR SoftPLL DCO step control.
// This diagnostic wrapper keeps the original startup table and adds a
// serialized FINC/FDEC write path after static configuration is complete.

module si5340a_controller_dco #(
parameter integer ENABLE_SAME_CODE_TEST = 0,
parameter integer ENABLE_JTAG_HPLL_BURST = 0,
parameter integer ENABLE_STEP5_ACTUATOR_IDENTIFICATION = 0,
// A4 calibration mode: complete the coarse bootstrap, then hold the normal
// Helper-to-HPLL tracker so externally triggered FINC/FDEC steps can identify
// the physical plant without a competing closed-loop request stream.
parameter integer ENABLE_STEP5_HPLL_PLANT_TEST = 0,
parameter integer ENABLE_NORMAL_HPLL_TRACKER = 1,
parameter integer ENABLE_STEP5_BOOTSTRAP = 0,
parameter integer STEP5_BOOTSTRAP_STEPS = 6336,
parameter integer STEP5_BOOTSTRAP_REVERSE = 0,
parameter integer HPLL_TRACKER_CODE_PER_PHYSICAL_STEP = 34,
parameter integer DPLL_TRACKER_CODE_PER_PHYSICAL_STEP = 16,
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
output    [63:0]        oDCO_STEP5_POSITION_ACCOUNTING_DEBUG,
output    [63:0]        oDCO_STEP5_ACTUATOR_DEBUG,
output    [63:0]        oDCO_STEP5_I2C_DEBUG,
output    [63:0]        oDCO_STEP5_I2C_SEQUENCE_DEBUG,
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
wire       i2c_ack_error;
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
// States 5/6 are reused for page restore, then the final command. Keeping
// the public three-bit state width avoids truncating existing JTAG probes.
reg        rt_final_write;
reg        dpll_pending;
reg        hpll_pending;
reg        dpll_dir;
reg        hpll_dir;
reg        dpll_prev_valid;
reg        hpll_prev_valid;
reg [15:0] dpll_prev_data;
reg [15:0] hpll_prev_data;
reg [31:0] dpll_target_position;
reg [31:0] dpll_applied_position;
reg        dpll_tracker_initialized;
reg [15:0] hpll_target_code;
// The helper target is a 16-bit WR code. Keep the fine-loop applied position
// as a signed wide accumulator so normal tracking cannot silently wrap at
// 0xffff. The coarse bootstrap establishes the physical origin and is not
// re-counted as fine-loop position; otherwise fine tracking can undo it.
reg signed [31:0] hpll_target_position;
reg signed [31:0] hpll_applied_position;
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
reg [15:0] forced_finc_completed_count;
reg [15:0] forced_fdec_completed_count;
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
reg [63:0] dco_step5_position_accounting_debug;
reg [63:0] dco_step5_actuator_debug;
reg [63:0] dco_step5_i2c_debug;
reg [63:0] dco_step5_i2c_sequence_debug;
reg [7:0]  last_runtime_addr;
reg [7:0]  last_runtime_data;
reg [2:0]  last_runtime_state;
reg        last_runtime_final_write;
reg        last_runtime_select_dpll;
reg        last_runtime_dir;
reg [3:0]  runtime_phase_seen;
reg [63:0] runtime_sequence_debug;
reg [15:0] bootstrap_remaining;
reg [15:0] bootstrap_completed_count;
reg        bootstrap_started;
reg        bootstrap_done;
reg [15:0] position_audit_epoch;

localparam signed [31:0] HPLL_STEP_CODE = HPLL_TRACKER_CODE_PER_PHYSICAL_STEP;
// Admit the nearest physical step once the residual is at least half a
// step. This removes the rail dead zone where an absolute target can be
// 54 codes away from the applied position while the actuator granularity is
// 64 codes.
localparam signed [31:0] HPLL_HALF_STEP_CODE =
  (HPLL_STEP_CODE > 1) ? (HPLL_STEP_CODE >>> 1) : 1;
localparam [31:0] DPLL_STEP_CODE = DPLL_TRACKER_CODE_PER_PHYSICAL_STEP;
localparam [31:0] DPLL_START_POSITION = 32'd32768;

wire [6:0] runtime_slave_addr = 7'b1110111;
wire       runtime_bus_enable = (rt_state != 3'd0);
wire       force_hpll_rise = force_hpll_sync & ~force_hpll_sync_prev;
wire [15:0] force_hpll_burst_size =
  (iFORCE_HPLL_BURST_SIZE != 16'd0) ?
    iFORCE_HPLL_BURST_SIZE : JTAG_HPLL_BURST_SIZE[15:0];
// Four writes: PAGE=3, N_FSTEP_MSK, PAGE=0, FINC/FDEC. The mask is
// at 0x0339, NOT 0x0039. Page restore must complete before the command.
wire [7:0] runtime_byte_addr =
  (rt_state == 3'd1 || rt_state == 3'd2) ? 8'h01 :
  (rt_state == 3'd3 || rt_state == 3'd4) ? 8'h39 :
  (rt_final_write ? 8'h1D : 8'h01);
// Register 0x0339 uses zero to enable a divider and one to mask it.
// DPLL drives N0; HPLL/DMTD drives N1.  Keep the other N dividers masked.
wire [7:0] runtime_byte_data =
  (rt_state == 3'd1 || rt_state == 3'd2) ? 8'h03 :
  (rt_state == 3'd3 || rt_state == 3'd4) ?
    (rt_select_dpll ? 8'h0E : 8'h0D) :
  // SI5340 FINC is bit 0 and FDEC is bit 1.  A larger WR DAC code is
  // treated as a request for FINC; this direction is verified on hardware.
  (rt_final_write ? (rt_dir ? 8'h01 : 8'h02) : 8'h00);
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
assign oDCO_STEP5_POSITION_ACCOUNTING_DEBUG = dco_step5_position_accounting_debug;
assign oDCO_STEP5_ACTUATOR_DEBUG = dco_step5_actuator_debug;
assign oDCO_STEP5_I2C_DEBUG = dco_step5_i2c_debug;
assign oDCO_STEP5_I2C_SEQUENCE_DEBUG = dco_step5_i2c_sequence_debug;
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
  dco_step5_tracker_debug[31:16] = hpll_applied_position[15:0];
  dco_step5_tracker_debug[47:32] = normal_hpll_request_count;
  dco_step5_tracker_debug[63:48] = normal_hpll_completed_count;
end

// Step5 bootstrap evidence.  The bootstrap is intentionally separate from
// the normal tracker: after fresh-program, it applies the measured physical
// zero-point offset before any normal quantized tracker transaction is
// admitted.
// [15:0] remaining bootstrap steps, [31:16] completed bootstrap steps,
// bit 32 started, bit 33 done, bit 34 pending, bit 35 current transaction,
// bit 36 final-write phase, [52:37] signed applied-position upper bits.
always @* begin
  dco_step5_bootstrap_debug = 64'd0;
  dco_step5_bootstrap_debug[15:0]  = bootstrap_remaining;
  dco_step5_bootstrap_debug[31:16] = bootstrap_completed_count;
  dco_step5_bootstrap_debug[32] = bootstrap_started;
  dco_step5_bootstrap_debug[33] = bootstrap_done;
  dco_step5_bootstrap_debug[34] = hpll_pending_bootstrap;
  dco_step5_bootstrap_debug[35] = current_request_bootstrap;
  // Additive diagnostic: disambiguates the two visits to states 5/6.
  dco_step5_bootstrap_debug[36] = rt_final_write;
  dco_step5_bootstrap_debug[52:37] = hpll_applied_position[31:16];
end

// Step5 fine-loop position audit evidence. The counters retain the legacy
// normal FINC/FDEC layout, while the applied field is the low half of the
// signed fine-loop accumulator. Bootstrap/forced moves are intentionally
// excluded from this fine-loop coordinate; the host checks normal tracking.
// [15:0] target, [31:16] low 16 bits of signed applied position,
// [47:32] normal FINC completed, [63:48] normal FDEC completed.
always @* begin
  dco_step5_position_debug = 64'd0;
  dco_step5_position_debug[15:0]  = hpll_target_code;
  dco_step5_position_debug[31:16] = hpll_applied_position[15:0];
  dco_step5_position_debug[47:32] = normal_finc_completed_count;
  dco_step5_position_debug[63:48] = normal_fdec_completed_count;
end

// A second read-only audit word keeps the transaction accounting fields in
// one RTL snapshot.  The epoch increments on every completed physical
// transaction; the observer reads this word before and after probe 43 and
// accepts the pair only when the epoch is unchanged.
// [15:0] normal completed, [31:16] total DCO completed,
// [47:32] bootstrap completed, [63:48] completion epoch.
always @* begin
  dco_step5_position_accounting_debug = 64'd0;
  dco_step5_position_accounting_debug[15:0]  = normal_hpll_completed_count;
  dco_step5_position_accounting_debug[31:16] = dco_step_count;
  dco_step5_position_accounting_debug[47:32] = bootstrap_completed_count;
  dco_step5_position_accounting_debug[63:48] = position_audit_epoch;
end

// Explicit actuator-identification accounting. These counters include only
// completed JTAG-forced transactions, not bootstrap or normal tracker
// transactions. The direction encoding is the runtime FINC/FDEC encoding:
// FINC=1 and FDEC=0. Keeping this in a separate probe preserves the legacy
// burst and signed-position probe layouts.
always @* begin
  dco_step5_actuator_debug = 64'd0;
  dco_step5_actuator_debug[15:0]  = forced_finc_completed_count;
  dco_step5_actuator_debug[31:16] = forced_fdec_completed_count;
  dco_step5_actuator_debug[47:32] = forced_hpll_completed_count;
  dco_step5_actuator_debug[48]    = force_burst_reverse;
  dco_step5_actuator_debug[49]    = force_hpll_reverse_sync;
  dco_step5_actuator_debug[50]    = force_hpll_seen;
  dco_step5_actuator_debug[63:51] = force_burst_remaining[12:0];
end

// Read-only runtime transaction provenance.  The I2C controller exposes a
// sticky ACK error, while the fields below retain the most recent runtime
// command and a four-bit mask showing which members of the expected sequence
// were admitted since reset:
//   bit 0 = PAGE 3, bit 1 = N_FSTEP_MSK, bit 2 = PAGE 0,
//   bit 3 = FINC/FDEC.
// This does not change admission, serialization, or completion semantics.
// [7:0] last address, [15:8] last data, [18:16] state,
// bit 19 final write, bit 20 DPLL select, bit 21 direction,
// [25:22] phase mask, bit 26 sticky I2C ACK error, bit 27 dco_error,
// [35:28] runtime starts, [43:36] bus completions,
// [59:44] total completed physical transactions,
// bit 60 bus busy, bit 61 static ready, bit 62 runtime enabled.
always @* begin
  dco_step5_i2c_debug = 64'd0;
  dco_step5_i2c_debug[7:0]   = last_runtime_addr;
  dco_step5_i2c_debug[15:8]  = last_runtime_data;
  dco_step5_i2c_debug[18:16] = last_runtime_state;
  dco_step5_i2c_debug[19]    = last_runtime_final_write;
  dco_step5_i2c_debug[20]    = last_runtime_select_dpll;
  dco_step5_i2c_debug[21]    = last_runtime_dir;
  dco_step5_i2c_debug[25:22] = runtime_phase_seen;
  dco_step5_i2c_debug[26]    = i2c_ack_error;
  dco_step5_i2c_debug[27]    = dco_error;
  dco_step5_i2c_debug[35:28] = runtime_start_count;
  dco_step5_i2c_debug[43:36] = bus_done_count;
  dco_step5_i2c_debug[59:44] = dco_step_count;
  dco_step5_i2c_debug[60]    = bus_state;
  dco_step5_i2c_debug[61]    = static_controller_ready;
  dco_step5_i2c_debug[62]    = runtime_bus_enable;
end

// Sticky FPGA-side payload capture for all four runtime writes. Each phase
// occupies one 16-bit lane as {data[7:0], address[7:0]}:
//   lane 0 = PAGE 3, lane 1 = N_FSTEP_MSK, lane 2 = PAGE 0,
//   lane 3 = FINC/FDEC. This records the exact address/data presented to the
// bus controller, not a claim of silicon readback.
always @* begin
  dco_step5_i2c_sequence_debug = runtime_sequence_debug;
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
  .oCONFIG_DONE(bus_done),
  .oACK_ERROR(i2c_ack_error)
);

// Serialize each step as four I2C writes; only the final command completion
// advances position/step counters. Request admission is unchanged.
always @(posedge iCLK or negedge iRST_n) begin
  if (!iRST_n) begin
    rt_state         <= 3'd0;
    rt_dir           <= 1'b0;
    rt_select_dpll   <= 1'b0;
    rt_seen_busy     <= 1'b0;
    rt_final_write   <= 1'b0;
    dpll_pending     <= 1'b0;
    hpll_pending     <= 1'b0;
    dpll_dir         <= 1'b0;
    hpll_dir         <= 1'b0;
    dpll_prev_valid  <= 1'b0;
    hpll_prev_valid  <= 1'b0;
    dpll_prev_data   <= 16'd0;
    hpll_prev_data   <= 16'd0;
    dpll_target_position <= 32'd0;
    dpll_applied_position <= DPLL_START_POSITION;
    dpll_tracker_initialized <= 1'b0;
    hpll_target_code <= 16'd0;
    hpll_target_position <= 32'sd0;
    hpll_applied_position <= 32'sd0;
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
    forced_finc_completed_count <= 16'd0;
    forced_fdec_completed_count <= 16'd0;
    bootstrap_remaining <= 16'd0;
    bootstrap_completed_count <= 16'd0;
    bootstrap_started <= 1'b0;
    bootstrap_done <= 1'b0;
    position_audit_epoch <= 16'd0;
    rt_state_enter_count <= 8'd0;
    runtime_start_count <= 8'd0;
    bus_done_count <= 8'd0;
    runtime_start_prev <= 1'b0;
    bus_done_prev <= 1'b0;
    last_runtime_addr <= 8'd0;
    last_runtime_data <= 8'd0;
    last_runtime_state <= 3'd0;
    last_runtime_final_write <= 1'b0;
    last_runtime_select_dpll <= 1'b0;
    last_runtime_dir <= 1'b0;
    runtime_phase_seen <= 4'd0;
    runtime_sequence_debug <= 64'd0;
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

    if (runtime_start) begin
      last_runtime_addr <= runtime_byte_addr;
      last_runtime_data <= runtime_byte_data;
      last_runtime_state <= rt_state;
      last_runtime_final_write <= rt_final_write;
      last_runtime_select_dpll <= rt_select_dpll;
      last_runtime_dir <= rt_dir;
      if (rt_state == 3'd1)
        runtime_phase_seen[0] <= 1'b1;
      else if (rt_state == 3'd3)
        runtime_phase_seen[1] <= 1'b1;
      else if (rt_state == 3'd5 && !rt_final_write)
        runtime_phase_seen[2] <= 1'b1;
      else if (rt_state == 3'd5 && rt_final_write)
        runtime_phase_seen[3] <= 1'b1;
      if (rt_state == 3'd1) begin
        runtime_sequence_debug[7:0] <= runtime_byte_addr;
        runtime_sequence_debug[15:8] <= runtime_byte_data;
      end else if (rt_state == 3'd3) begin
        runtime_sequence_debug[23:16] <= runtime_byte_addr;
        runtime_sequence_debug[31:24] <= runtime_byte_data;
      end else if (rt_state == 3'd5 && !rt_final_write) begin
        runtime_sequence_debug[39:32] <= runtime_byte_addr;
        runtime_sequence_debug[47:40] <= runtime_byte_data;
      end else if (rt_state == 3'd5 && rt_final_write) begin
        runtime_sequence_debug[55:48] <= runtime_byte_addr;
        runtime_sequence_debug[63:56] <= runtime_byte_data;
      end
    end

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
          hpll_pending_forced_reverse <= STEP5_BOOTSTRAP_REVERSE;
          forced_pending_count <= forced_pending_count + 1'b1;
        end
      end
    end

    // Permit a second direction command after the first burst has fully
    // returned to idle.  The low level is required so an in-flight pulse
    // cannot accidentally retrigger or change the current burst.
    if (!force_hpll_sync && force_hpll_seen &&
        (rt_state == 3'd0) && !hpll_pending &&
        (force_burst_remaining == 16'd0)) begin
      force_hpll_seen <= 1'b0;
    end

    if (iDPLL_LOAD) begin
      // Main DAC values are absolute unsigned values in the same 16-bit
      // domain used by spll_main.c. The SI5340 starts at midscale, so keep
      // an independent virtual applied position and continue servicing a
      // residual even when the CPU repeats the same target value.
      dpll_target_position <= {16'd0, iDPLL_DATA};
      if (!dpll_tracker_initialized) begin
        dpll_applied_position <= DPLL_START_POSITION;
        dpll_tracker_initialized <= 1'b1;
      end
      if (dpll_tracker_initialized &&
          ((({16'd0, iDPLL_DATA} > dpll_applied_position) &&
            (({16'd0, iDPLL_DATA} - dpll_applied_position) >= DPLL_STEP_CODE)) ||
           ((dpll_applied_position > {16'd0, iDPLL_DATA}) &&
            ((dpll_applied_position - {16'd0, iDPLL_DATA}) >= DPLL_STEP_CODE)))) begin
        dpll_pending <= 1'b1;
      end
      dpll_prev_data <= iDPLL_DATA;
      dpll_prev_valid <= 1'b1;
    end
    if (iHPLL_LOAD) begin
      // Keep the newest absolute target.  The idle-state tracker below
      // serializes one FINC/FDEC request at a time until applied==target.
      hpll_target_code <= iHPLL_DATA;
      // HPLL DAC values are absolute unsigned PI outputs in the WR 16-bit
      // range [5, 65531], not signed error values.
      hpll_target_position <= {16'd0, iHPLL_DATA};
      // Preserve the proven A-polarity direction for forced calibration even
      // when the normal absolute-target tracker is disabled in the
      // calibration image.
      if (hpll_prev_valid && (iHPLL_DATA != hpll_prev_data))
        hpll_dir <= (iHPLL_DATA > hpll_prev_data);
      if (!hpll_tracker_initialized) begin
        // WR node helper_start() uses pi.y_min, which is 5 for the DE5a
        // generic 16-bit DAC configuration.
        hpll_applied_position <= 32'sd5;
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
        rt_final_write <= 1'b0;
        if (static_controller_ready && dpll_tracker_initialized &&
            (((dpll_target_position > dpll_applied_position) &&
              ((dpll_target_position - dpll_applied_position) >= DPLL_STEP_CODE)) ||
             ((dpll_applied_position > dpll_target_position) &&
              ((dpll_applied_position - dpll_target_position) >= DPLL_STEP_CODE)))) begin
          rt_state <= 3'd1;
          rt_state_enter_count <= rt_state_enter_count + 1'b1;
          rt_select_dpll <= 1'b1;
          // FINC moves the physical code downward; FDEC moves it upward.
          rt_dir <= (dpll_target_position < dpll_applied_position);
          dpll_pending <= 1'b0;
          current_request_forced <= 1'b0;
        end else if (static_controller_ready && hpll_pending) begin
          rt_state <= 3'd1;
          rt_state_enter_count <= rt_state_enter_count + 1'b1;
          rt_select_dpll <= 1'b0;
          if (hpll_pending_forced && ENABLE_STEP5_ACTUATOR_IDENTIFICATION)
            rt_dir <= hpll_pending_forced_reverse;
          else
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
          hpll_pending_forced_reverse <= STEP5_BOOTSTRAP_REVERSE;
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
          // Preserve the selected bootstrap polarity for every queued
          // transaction, not just the first one.  Clearing this here made a
          // nominal reverse bootstrap execute one reverse step followed by
          // forward steps, invalidating the operating-point experiment.
          hpll_pending_forced_reverse <= STEP5_BOOTSTRAP_REVERSE;
          hpll_pending_bootstrap <= 1'b1;
          bootstrap_remaining <= bootstrap_remaining - 1'b1;
        end else if (ENABLE_JTAG_HPLL_BURST &&
                     static_controller_ready &&
                     (force_burst_remaining != 16'd0)) begin
          // Queue only one forced request at a time.  The next request is
          // admitted after the current four-write runtime sequence returns
          // to idle, so the thirty-two-step burst is controller-serialized.
          hpll_pending <= 1'b1;
          hpll_pending_forced <= 1'b1;
          hpll_pending_forced_reverse <= force_burst_reverse;
          force_burst_remaining <= force_burst_remaining - 1'b1;
          forced_hpll_pending_count <= forced_hpll_pending_count + 1'b1;
        end else if (ENABLE_NORMAL_HPLL_TRACKER &&
                     !ENABLE_STEP5_HPLL_PLANT_TEST &&
                     static_controller_ready &&
                     hpll_tracker_initialized && hpll_prev_valid &&
                     (((hpll_target_position > hpll_applied_position) &&
                       ((hpll_target_position - hpll_applied_position) >= HPLL_HALF_STEP_CODE)) ||
                      ((hpll_applied_position > hpll_target_position) &&
                       ((hpll_applied_position - hpll_target_position) >= HPLL_HALF_STEP_CODE)))) begin
          // Normal HPLL closed-loop path: admit only one outstanding
          // transaction. Round the absolute target to the nearest physical
          // DCO step: a residual below half a step is retained, while a
          // residual at or above half a step executes one full step. The
          // applied position may therefore overshoot the target by less than
          // half a step, which is the correct quantized actuator contract.
          hpll_pending <= 1'b1;
          hpll_pending_forced <= 1'b0;
          hpll_pending_forced_reverse <= 1'b0;
          // The isolated plant test measured FINC as the direction that
          // increases FREQ_ERROR and FDEC as the direction that decreases it.
          // Therefore a larger Helper target maps to FINC (rt_dir=1), while
          // a smaller target maps to FDEC (rt_dir=0).
          hpll_dir <= (hpll_target_position > hpll_applied_position);
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
          if (!rt_final_write) begin
            // Page 0 is now selected. Reuse the handshake pair for FINC/FDEC.
            rt_final_write <= 1'b1;
            rt_state <= 3'd5;
            rt_seen_busy <= 1'b0;
          end else begin
          rt_state <= 3'd0;
          rt_seen_busy <= 1'b0;
          dco_step_count <= dco_step_count + 1'b1;
          position_audit_epoch <= position_audit_epoch + 1'b1;
          if (current_request_forced) begin
            forced_hpll_completed_count <= forced_hpll_completed_count + 1'b1;
            if (rt_dir)
              forced_finc_completed_count <= forced_finc_completed_count + 1'b1;
            else
              forced_fdec_completed_count <= forced_fdec_completed_count + 1'b1;
            // Bootstrap/forced moves establish or perturb the physical
            // origin, but remain outside the fine-loop code coordinate. This
            // prevents the fine tracker from immediately cancelling the
            // coarse operating-point move.
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
          end else if (rt_select_dpll && dpll_tracker_initialized) begin
            // Main uses the same unsigned WR DAC coordinate as the PI output,
            // but has its own origin and physical-step accounting. Only a
            // completed four-write transaction advances applied position.
            if (rt_dir)
              dpll_applied_position <= dpll_applied_position - DPLL_STEP_CODE;
            else
              dpll_applied_position <= dpll_applied_position + DPLL_STEP_CODE;
            dpll_pending <= 1'b0;
          end else if (ENABLE_NORMAL_HPLL_TRACKER &&
                       !rt_select_dpll && hpll_tracker_initialized) begin
            // One physical FINC/FDEC maps to exactly one configured number
            // of virtual WR DAC
            // codes. Keep the virtual position quantized: a completed
            // physical transaction always advances it by exactly one full
            // physical-step code. The half-step admission guard above
            // selects the nearest reachable position; no partial credit or
            // target snap is allowed here.
            if (rt_dir) begin
              // FINC increases the physical/WR HPLL code coordinate.
              hpll_applied_position <= hpll_applied_position + HPLL_STEP_CODE;
              normal_finc_completed_count <= normal_finc_completed_count + 1'b1;
            end else begin
              // FDEC decreases the physical/WR HPLL code coordinate.
              hpll_applied_position <= hpll_applied_position - HPLL_STEP_CODE;
              normal_fdec_completed_count <= normal_fdec_completed_count + 1'b1;
            end
            normal_hpll_completed_count <= normal_hpll_completed_count + 1'b1;
          end
          end
        end
      end
      default: rt_state <= 3'd0;
    endcase
  end
end

endmodule
