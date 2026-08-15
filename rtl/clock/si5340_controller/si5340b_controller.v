// ============================================================================
// Copyright (c) 2015 by Terasic Inc.
// ============================================================================
//
// Permission:
//
// Terasic grants permission to use and modify this code for use
// in synthesis for all Terasic Development Boards and Altera Development
// Kits made by Terasic. Other use of this code, including the selling
// ,duplication, or modification of any portion is strictly prohibited.
//
// Disclaimer:
//
// This VHDL/Verilog or C/C++ source code is intended as a design reference
// which illustrates how these types of functions can be implemented.
// It is the user's responsibility to verify their design for
// consistency and functionality through the use of formal
// verification methods. Terasic provides no warranty regarding the use
// or functionality of this code.
//
// ============================================================================
//
// Terasic Technologies Inc
//  9F., No.176, Sec.2, Gongdao 5th Rd, East Dist, Hsinchu City, 30070. Taiwan
// HsinChu County, Taiwan
// 302
//
// web: http://www.terasic.com/
// email: support@terasic.com
//
// ============================================================================
// Major Functions:
//  This code is using for configuring the output frequency of 
//  SI570 I2C Programable XO/VCXO
// ============================================================================
// Design Description:
// 
//
//
// ===========================================================================
// Revision History :
// ============================================================================
// Ver :| Author :| Mod. Date :| Changes Made:
// V1.0 :| Johnny Fan :| 15/01/20 :| Initial Version
// ============================================================================

module si5340b_controller(

input                   iCLK, 
input                   iRST_n,
input                   iStart,
input     [4:0]         iPLL_OUT_FREQ_SEL,
output			               I2C_CLK,
inout				               I2C_DATA,
output			               oPLL_I2C_ID_READ_ERROR,
output                  oPLL_REG_CONFIG_DONE

);

//=============================================================================
// PARAMETER declarations
//=============================================================================



//=============================================================================
// REG/WIRE declarations
//=============================================================================

wire [6:0]  slave_addr;
wire [7:0]  byte_addr;
wire [7:0]  byte_data;
wire        wr_cmd;
wire [7:0]  oREAD_Data;
wire        i2c_control_start;
wire 			    i2c_reg_control_start;
wire 			    i2c_bus_controller_state;
//wire			     iINITIAL_ENABLE;
wire 			    system_start;
wire 			    i2c_system_clk;
wire			     i2c_controller_config_done;
wire			     oController_Ready;
wire			     initial_start;
wire					i2c_read_data_rdy;
//=============================================================================
// Structural coding
//=============================================================================


// 10ms delay for done / assume iCLK 50MHz
wire wPLL_REG_CONFIG_DONE;
reg [31:0] cnt;
always@ (posedge iCLK) begin
   if(wPLL_REG_CONFIG_DONE)begin
	    if(cnt < 32'd500_000) cnt <=cnt + 1'b1; 
	end else begin
	    cnt <= 32'd0;
	end
end

assign oPLL_REG_CONFIG_DONE = (cnt ==  32'd500_000)?1'b1:1'b0;

si5340b_i2c_reg_controller si5340b_i2c_reg_controller(

.iCLK(iCLK),
.iRST_n(iRST_n),
.iENABLE(system_start),
.iPLL_OUT_FREQ_SEL(iPLL_OUT_FREQ_SEL),
.iI2C_CONTROLLER_STATE(i2c_bus_controller_state),
.iI2C_CONTROLLER_CONFIG_DONE(i2c_controller_config_done),
.oSLAVE_ADDR(slave_addr),
.oBYTE_ADDR(byte_addr),
.oBYTE_DATA(byte_data),
.oWR_CMD(wr_cmd),
.oStart(i2c_reg_control_start),
.iI2C_READ_DATA(oREAD_Data),
.iI2C_READ_DATA_RDY(i2c_read_data_rdy),
.oONE_CLK_CONFIG_DONE(wPLL_REG_CONFIG_DONE),
.oController_Ready(oController_Ready)
);


initial_config initial_config(

.iCLK(iCLK), // system   clock 50mhz 
.iRST_n(iRST_n), // system reset 
.oINITIAL_START(initial_start),
.iINITIAL_ENABLE(1'b1)
);


wire istart_rsing;

//assign system_start = iStart|initial_start;
//assign system_start = iStart;
assign system_start = istart_rsing|initial_start;


edge_detector edge_detector(

.iCLK(iCLK),
.iRST_n(iRST_n),
.iIn(iStart),
.oFallING_EDGE(),
.oRISING_EDGE(istart_rsing)
);




clock_divider clock_divider(
.iCLK(iCLK),
.iRST_n(iRST_n),
.oCLK_OUT(i2c_system_clk)
);


i2c_bus_controller i2c_bus_controller	(

	.iCLK(i2c_system_clk),
	.iRST_n(iRST_n),
	.iStart(i2c_reg_control_start),
	.iSlave_addr(slave_addr),
	.iWord_addr(byte_addr),
	.iSequential_read(1'b0),
	.iRead_length(8'd1),
	
	.i2c_clk(I2C_CLK),
	.i2c_data(I2C_DATA),
	.i2c_read_data(oREAD_Data),
	.i2c_read_data_rdy(i2c_read_data_rdy),
	.wr_data(byte_data),
	.wr_cmd(wr_cmd),
  .oSYSTEM_STATE(i2c_bus_controller_state),
	.oCONFIG_DONE(i2c_controller_config_done)
				);














endmodule 
