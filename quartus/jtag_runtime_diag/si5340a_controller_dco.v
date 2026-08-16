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
output    [15:0]        oDCO_DPLL_DONE_COUNT
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
wire       initial_start;
wire       user_start_rise;
wire       i2c_system_clk;
wire       system_start;

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

wire [6:0] runtime_slave_addr = 7'b1110111;
wire       runtime_bus_enable = (rt_state != 4'd0);
// The static table leaves the SI5340 on page 0x0B.  N_FSTEP_MSK is
// page-3 register 0x39, while FINC/FDEC is page-0 register 0x1D.
// Select each page explicitly so the runtime command cannot land on
// page-0 register 0x39 (LOS1 clear threshold).
wire [7:0] runtime_byte_addr =
  (rt_state == 4'd1 || rt_state == 4'd2) ? 8'h01 :
  (rt_state == 4'd3 || rt_state == 4'd4) ? 8'h39 :
  (rt_state == 4'd5 || rt_state == 4'd6) ? 8'h01 : 8'h1D;
// Page select: page 3 for N_FSTEP_MSK, then page 0 for FINC/FDEC.
// Register 0x0339 uses zero to enable a divider and one to mask it.
// DPLL drives N0; HPLL/DMTD drives N1.  Keep the other N dividers masked.
wire [7:0] runtime_byte_data =
  (rt_state == 4'd1 || rt_state == 4'd2) ? 8'h03 :
  (rt_state == 4'd3 || rt_state == 4'd4) ?
    (rt_select_dpll ? 8'h0E : 8'h0D) :
  (rt_state == 4'd5 || rt_state == 4'd6) ? 8'h00 :
  // SI5340 FINC is bit 0 and FDEC is bit 1.  A larger WR DAC code is
  // treated as a request for FINC; this direction is verified on hardware.
  (rt_dir ? 8'h01 : 8'h02);
wire       runtime_start = ((rt_state == 4'd1 || rt_state == 4'd3 ||
                             rt_state == 4'd5 || rt_state == 4'd7) &&
                            !bus_state && static_controller_ready);

wire       static_bus_enable = system_start || !static_controller_ready || bus_state;
wire       bus_enable = static_bus_enable || runtime_bus_enable;
wire       bus_start = static_start_pulse || runtime_start;
wire [6:0] bus_slave_addr = runtime_bus_enable ? runtime_slave_addr : static_slave_addr;
wire [7:0] bus_byte_addr = runtime_bus_enable ? runtime_byte_addr : static_byte_addr;
wire [7:0] bus_byte_data = runtime_bus_enable ? runtime_byte_data : static_byte_data;
wire       bus_wr_cmd = runtime_bus_enable ? 1'b1 : static_wr_cmd;

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

// Serialize each WR DAC update as four I2C writes:
// select page 3, select the N0/N1 divider mask, select page 0,
// then issue FINC/FDEC.
always @(posedge iCLK or negedge iRST_n) begin
  if (!iRST_n) begin
    rt_state         <= 4'd0;
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
    // DPLL-only isolation experiment: suppress HPLL transactions.
    hpll_done_once  <= 1'b1;
    dpll_done_once  <= 1'b0;
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
        // DPLL-only isolation experiment: issue exactly one DPLL transaction
        // and suppress HPLL transactions.  This isolates the N0/reference
        // path while retaining the already validated I2C start handshake.
        if (static_controller_ready && dpll_pending && !dpll_done_once) begin
          rt_state <= 4'd1;
          rt_select_dpll <= 1'b1;
          rt_dir <= dpll_dir;
          dpll_pending <= 1'b0;
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
            hpll_done_once <= 1'b1;
          end
        end
      end
      default: rt_state <= 4'd0;
    endcase
  end
end

endmodule
