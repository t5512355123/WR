// SI5340 static configuration plus WR SoftPLL DCO step control.
// This diagnostic wrapper keeps the original startup table and adds a
// serialized FINC/FDEC write path after static configuration is complete.

module si5340a_controller_dco(
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
output                  I2C_CLK,
inout                   I2C_DATA,
output                  oPLL_I2C_ID_READ_ERROR,
output                  oPLL_REG_CONFIG_DONE,
output                  oDCO_BUSY,
output                  oDCO_ERROR,
output    [15:0]        oDCO_STEP_COUNT,
output    [15:0]        oDCO_HPLL_INPUT_COUNT,
output    [15:0]        oDCO_DPLL_INPUT_COUNT,
output    [15:0]        oDCO_HPLL_ACCEPT_COUNT,
output    [15:0]        oDCO_DPLL_ACCEPT_COUNT,
output    [15:0]        oDCO_HPLL_DONE_COUNT,
output    [15:0]        oDCO_DPLL_DONE_COUNT,
output    [63:0]        oDCO_DPLL_STATE,
output    [63:0]        oDCO_HPLL_STATE,
output    [63:0]        oI2C_ACK_DIAG,
output    [63:0]        oI2C_READBACK
);

wire [6:0] static_slave_addr;
wire [7:0] static_byte_addr;
wire [7:0] static_byte_data;
wire       static_wr_cmd;
wire [7:0] static_read_data;
wire       static_read_data_rdy;
wire       static_read_data_valid;
wire       bus_state;
wire       bus_done;
wire       static_controller_ready;
wire       static_start_pulse;
wire       initial_start;
wire       user_start_rise;
wire       i2c_system_clk;
wire       system_start;
wire [63:0] i2c_ack_diag;

reg [3:0]  rt_state;
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
reg [15:0] dco_step_count;
reg [15:0] hpll_input_count;
reg [15:0] dpll_input_count;
reg [15:0] hpll_accept_count;
reg [15:0] dpll_accept_count;
reg [15:0] hpll_done_count;
reg [15:0] dpll_done_count;
reg        hpll_done_once;
reg        dpll_done_once;
reg        dco_error;

// One-shot diagnostic readback. It selects page 0 and reads 0x21, then
// reads the page-independent DEVICE_READY register 0xFE.
// It does not change the DCO request path. 0x1D is self-clearing FINC/FDEC,
// so it is not a reliable readback sanity check.
reg [3:0]  rb_state;
reg        rb_seen_busy;
reg [7:0]  rb_page0_0021_data;
reg [7:0]  rb_device_ready_data;
reg [7:0]  rb_current_page;

wire [6:0] runtime_slave_addr = 7'b1110111;
wire       runtime_bus_enable = (rt_state != 4'd0);
wire       readback_bus_enable = (rb_state >= 4'd1 && rb_state <= 4'd4);
wire       readback_is_read = (rb_state == 4'd2 || rb_state == 4'd4);
// The static table leaves the SI5340 on page 0x0B. Select page 0
// explicitly so the diagnostic read is independent of that final page.
wire [7:0] runtime_byte_addr =
  (rt_state == 4'd1 || rt_state == 4'd2) ? 8'h01 :
  (rt_state == 4'd3 || rt_state == 4'd4) ? 8'h39 :
  (rt_state == 4'd5 || rt_state == 4'd6) ? 8'h01 : 8'h1D;
// Readback sequence: page 0 register 0x21, then page-independent 0xFE.
// The static table writes REG_0021 = 0x0F.
// DPLL drives N0; HPLL/DMTD drives N1.  Keep the other N dividers masked.
wire [7:0] runtime_byte_data =
  (rt_state == 4'd1 || rt_state == 4'd2) ? 8'h03 :
  (rt_state == 4'd3 || rt_state == 4'd4) ?
    (rt_select_dpll ? 8'h0E : 8'h0D) :
  (rt_state == 4'd5 || rt_state == 4'd6) ? 8'h00 :
  // SI5340 FINC is bit 0 and FDEC is bit 1.  A larger WR DAC code is
  // treated as a request for FINC; this direction is verified on hardware.
  (rt_dir ? 8'h01 : 8'h02);
wire [7:0] readback_byte_addr =
  (rb_state == 4'd1 || rb_state == 4'd3) ? 8'h01 :
  (rb_state == 4'd2) ? 8'h21 : 8'hFE;
wire [7:0] readback_byte_data = 8'h00;
wire       runtime_start = ((rt_state == 4'd1 || rt_state == 4'd3 ||
                             rt_state == 4'd5 || rt_state == 4'd7) &&
                            !bus_state && static_controller_ready);
wire       readback_start = ((rb_state == 4'd1 || rb_state == 4'd2 ||
                              rb_state == 4'd3 || rb_state == 4'd4) &&
                             !bus_state && static_controller_ready);

wire       static_bus_enable = system_start || !static_controller_ready || bus_state;
wire       bus_enable = static_bus_enable || runtime_bus_enable || readback_bus_enable;
wire       bus_start = static_start_pulse || runtime_start || readback_start;
wire [6:0] bus_slave_addr = readback_bus_enable ? runtime_slave_addr :
                            (runtime_bus_enable ? runtime_slave_addr : static_slave_addr);
wire [7:0] bus_byte_addr = readback_bus_enable ? readback_byte_addr :
                           (runtime_bus_enable ? runtime_byte_addr : static_byte_addr);
wire [7:0] bus_byte_data = readback_bus_enable ? readback_byte_data :
                           (runtime_bus_enable ? runtime_byte_data : static_byte_data);
wire       bus_wr_cmd = readback_bus_enable ? !readback_is_read :
                        (runtime_bus_enable ? 1'b1 : static_wr_cmd);
wire       bus_sequential_read = readback_bus_enable ? readback_is_read : 1'b0;

assign oPLL_REG_CONFIG_DONE = static_controller_ready;
assign oDCO_BUSY = (rt_state != 4'd0);
assign oDCO_ERROR = dco_error;
assign oDCO_STEP_COUNT = dco_step_count;
assign oDCO_HPLL_INPUT_COUNT = hpll_input_count;
assign oDCO_DPLL_INPUT_COUNT = dpll_input_count;
assign oDCO_HPLL_ACCEPT_COUNT = hpll_accept_count;
assign oDCO_DPLL_ACCEPT_COUNT = dpll_accept_count;
assign oDCO_HPLL_DONE_COUNT = hpll_done_count;
assign oDCO_DPLL_DONE_COUNT = dpll_done_count;
assign oI2C_READBACK = {35'd0, rb_current_page, rb_device_ready_data,
                        rb_page0_0021_data, (rb_state == 4'd5), rb_state[3:0]};
// Read-only HPLL request snapshot. The low fields mirror the DPLL snapshot:
// previous data, current input, runtime state, pending/select/direction,
// I2C state, controller readiness, previous-data validity, and done-once.
assign oDCO_HPLL_STATE = {19'd0, hpll_done_once, hpll_prev_valid,
                          bus_done, static_controller_ready, bus_state,
                          rt_dir, rt_select_dpll, hpll_pending, dpll_pending,
                          rt_state, iHPLL_DATA, hpll_prev_data};
// Read-only DPLL request/FSM snapshot:
// [15:0] previous loaded data, [31:16] current input data,
// [35:32] runtime state, [36] DPLL pending, [37] HPLL pending,
// [38] selected DPLL, [39] direction, [40] I2C bus state,
// [41] static controller ready, [42] bus done, [43] previous data valid,
// [44] DPLL transaction already consumed.
assign oDCO_DPLL_STATE = {19'd0, dpll_done_once, dpll_prev_valid,
                          bus_done, static_controller_ready, bus_state,
                          rt_dir, rt_select_dpll, hpll_pending, dpll_pending,
                          rt_state, iDPLL_DATA, dpll_prev_data};
assign oPLL_I2C_ID_READ_ERROR = 1'b0;

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
  .oController_Ready(static_controller_ready)
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
  .iSequential_read(bus_sequential_read),
  .iRead_length(8'd1),
  .i2c_clk(I2C_CLK),
  .i2c_data(I2C_DATA),
  .i2c_read_data(static_read_data),
  .i2c_read_data_rdy(static_read_data_rdy),
  .i2c_read_data_valid(static_read_data_valid),
  .wr_data(bus_byte_data),
  .wr_cmd(bus_wr_cmd),
  .oSYSTEM_STATE(bus_state),
  .oCONFIG_DONE(bus_done),
  .oACK_DIAG(i2c_ack_diag)
);

assign oI2C_ACK_DIAG = i2c_ack_diag;

// Serialize each WR DAC update as four I2C writes:
// select page 3, select the N0/N1 divider mask, select page 0,
// then issue FINC/FDEC.
always @(posedge iCLK or negedge iRST_n) begin
  if (!iRST_n) begin
    rt_state         <= 4'd0;
    rb_state         <= 4'd0;
    rb_seen_busy     <= 1'b0;
    rb_page0_0021_data <= 8'd0;
    rb_device_ready_data <= 8'd0;
    rb_current_page  <= 8'h0B;
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
    dco_step_count   <= 16'd0;
    hpll_input_count <= 16'd0;
    dpll_input_count <= 16'd0;
    hpll_accept_count <= 16'd0;
    dpll_accept_count <= 16'd0;
    hpll_done_count <= 16'd0;
    dpll_done_count <= 16'd0;
    // HPLL-only isolation experiment: keep the helper actuator running,
    // while suppressing the DPLL/N0 actuator until the helper can be tested.
    hpll_done_once  <= 1'b0;
    dpll_done_once  <= 1'b1;
    dco_error        <= 1'b0;
  end else begin
    if (iDPLL_LOAD) begin
      dpll_input_count <= dpll_input_count + 1'b1;
      if (dpll_prev_valid && (iDPLL_DATA != dpll_prev_data)) begin
        dpll_pending <= 1'b1;
        dpll_dir <= (iDPLL_DATA > dpll_prev_data);
        dpll_accept_count <= dpll_accept_count + 1'b1;
      end
      dpll_prev_data <= iDPLL_DATA;
      dpll_prev_valid <= 1'b1;
    end
    if (iHPLL_LOAD) begin
      hpll_input_count <= hpll_input_count + 1'b1;
      if (hpll_prev_valid && (iHPLL_DATA != hpll_prev_data)) begin
        hpll_pending <= 1'b1;
        hpll_dir <= (iHPLL_DATA > hpll_prev_data);
        hpll_accept_count <= hpll_accept_count + 1'b1;
      end
      hpll_prev_data <= iHPLL_DATA;
      hpll_prev_valid <= 1'b1;
    end

    case (rt_state)
      4'd0: begin
        rt_seen_busy <= 1'b0;
        // HPLL-only isolation experiment: service every pending HPLL update
        // and suppress DPLL/N0 transactions.  The helper needs repeated HPLL
        // updates before the normal Slave sequencing can reach the main PLL.
        if (static_controller_ready && rb_state == 4'd0 && hpll_pending) begin
          rt_state <= 4'd1;
          rt_select_dpll <= 1'b0;
          rt_dir <= hpll_dir;
          hpll_pending <= 1'b0;
        end
      end
      4'd1: begin
        // Hold the start request until the divided I2C state machine
        // acknowledges it by asserting bus_state.
        if (bus_state)
          rt_state <= 4'd2;
      end
      4'd2: begin
        if (bus_state)
          rt_seen_busy <= 1'b1;
        else if (rt_seen_busy) begin
          rt_state <= 4'd3;
          rt_seen_busy <= 1'b0;
        end
      end
      4'd3: begin
        if (bus_state)
          rt_state <= 4'd4;
      end
      4'd4: begin
        if (bus_state)
          rt_seen_busy <= 1'b1;
        else if (rt_seen_busy) begin
          rt_state <= 4'd5;
          rt_seen_busy <= 1'b0;
        end
      end
      4'd5: begin
        if (bus_state)
          rt_state <= 4'd6;
      end
      4'd6: begin
        if (bus_state)
          rt_seen_busy <= 1'b1;
        else if (rt_seen_busy) begin
          rt_state <= 4'd7;
          rt_seen_busy <= 1'b0;
        end
      end
      4'd7: begin
        if (bus_state)
          rt_state <= 4'd8;
      end
      4'd8: begin
        if (bus_state)
          rt_seen_busy <= 1'b1;
        else if (rt_seen_busy) begin
          rt_state <= 4'd0;
          rt_seen_busy <= 1'b0;
          dco_step_count <= dco_step_count + 1'b1;
          if (rt_select_dpll)
          begin
            dpll_done_count <= dpll_done_count + 1'b1;
            dpll_done_once <= 1'b1;
          end
            else begin
              hpll_done_count <= hpll_done_count + 1'b1;
              hpll_done_once <= 1'b0;
            end
        end
      end
      default: rt_state <= 4'd0;
    endcase

    case (rb_state)
      4'd0: begin
        rb_seen_busy <= 1'b0;
        if (static_controller_ready && rt_state == 4'd0)
          rb_state <= 4'd1;
      end
      4'd1: begin
        if (bus_state)
          rb_state <= 4'd2;
      end
      4'd2: begin
        if (static_read_data_valid)
          rb_page0_0021_data <= static_read_data;
        if (bus_state)
          rb_seen_busy <= 1'b1;
        else if (rb_seen_busy) begin
          rb_state <= 4'd3;
          rb_seen_busy <= 1'b0;
          rb_current_page <= 8'h00;
        end
      end
      4'd3: begin
        if (bus_state)
          rb_state <= 4'd4;
      end
      4'd4: begin
        if (static_read_data_valid)
          rb_device_ready_data <= static_read_data;
        if (bus_state)
          rb_seen_busy <= 1'b1;
        else if (rb_seen_busy) begin
          rb_state <= 4'd5;
          rb_seen_busy <= 1'b0;
          rb_current_page <= 8'h00;
        end
      end
      4'd5: begin
        rb_state <= rb_state;
      end
      default: rb_state <= 4'd0;
    endcase
  end
end

endmodule
