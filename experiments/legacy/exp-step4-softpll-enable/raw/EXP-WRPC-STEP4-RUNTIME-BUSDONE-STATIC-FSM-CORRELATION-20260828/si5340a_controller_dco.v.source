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
output    [63:0]        oDCO_DEBUG,
output    [7:0]         oDEBUG_STATIC_STATE,
output                  oDEBUG_STATIC_CONFIG_DONE_PULSE,
output                  oDEBUG_STATIC_ACCESS_START,
output    [2:0]         oDEBUG_RUNTIME_STATE,
output                  oDEBUG_BUS_STATE,
output                  oDEBUG_BUS_DONE,
output                  oDEBUG_RUNTIME_START,
output                  oDEBUG_RUNTIME_BUS_ENABLE,
output                  oDEBUG_SYSTEM_START
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
reg [15:0] dco_step_count;
reg        dco_error;
reg [63:0] dco_debug;

wire [6:0] runtime_slave_addr = 7'b1110111;
wire       runtime_bus_enable = (rt_state != 3'd0);
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
  // Bit 52 is retained as zero so existing JTAG decoders remain compatible.
  dco_debug[52]    = 1'b0;
  dco_debug[63:53] = hpll_prev_data[10:0];
end

assign oDCO_DEBUG = dco_debug;

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
    dco_step_count   <= 16'd0;
    dco_error        <= 1'b0;
  end else begin
    if (iDPLL_LOAD) begin
      if (dpll_prev_valid && (iDPLL_DATA != dpll_prev_data)) begin
        dpll_pending <= 1'b1;
        dpll_dir <= (iDPLL_DATA > dpll_prev_data);
      end
      dpll_prev_data <= iDPLL_DATA;
      dpll_prev_valid <= 1'b1;
    end
    if (iHPLL_LOAD) begin
      if (hpll_prev_valid && (iHPLL_DATA != hpll_prev_data)) begin
        hpll_pending <= 1'b1;
        hpll_dir <= (iHPLL_DATA > hpll_prev_data);
      end
      hpll_prev_data <= iHPLL_DATA;
      hpll_prev_valid <= 1'b1;
    end

    case (rt_state)
      3'd0: begin
        rt_seen_busy <= 1'b0;
        if (static_controller_ready && dpll_pending) begin
          rt_state <= 3'd1;
          rt_select_dpll <= 1'b1;
          rt_dir <= dpll_dir;
          dpll_pending <= 1'b0;
        end else if (static_controller_ready && hpll_pending) begin
          rt_state <= 3'd1;
          rt_select_dpll <= 1'b0;
          rt_dir <= hpll_dir;
          hpll_pending <= 1'b0;
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
        end
      end
      default: rt_state <= 3'd0;
    endcase
  end
end

endmodule
