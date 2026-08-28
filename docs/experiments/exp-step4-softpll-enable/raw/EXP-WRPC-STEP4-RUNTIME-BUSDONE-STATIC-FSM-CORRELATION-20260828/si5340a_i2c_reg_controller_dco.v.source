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
// Major Functions: This function is used for configuring si570 register value via 
// i2c_bus_controller .
//
//
// ============================================================================
// Design Description:
//
//
//
//
// ===========================================================================
// Revision History :
// ============================================================================
// Ver :| Author :| Mod. Date :| Changes Made:
// V1.0 :| Johnny Fan :| 11/09/30 :| Initial Version
// ============================================================================

`define REG_NUM 117
`define DEVICE_SLAVE_ID 7'b1110111
`define M_NUM_REG 44'd603979776000
`define M_DEN_REG 32'd2147483648

module si5340a_i2c_reg_controller_dco(

input                         iCLK,
input                         iRST_n,
input                         iENABLE,

input         [2:0]           iPLL_OUT0_FREQ_SEL,
input         [2:0]         	 iPLL_OUT1_FREQ_SEL,
input         [2:0]         	 iPLL_OUT2_FREQ_SEL, 
input         [2:0]         	 iPLL_OUT3_FREQ_SEL,


input                         iI2C_CONTROLLER_STATE,
input                         iI2C_CONTROLLER_CONFIG_DONE,


output        [6:0]           oSLAVE_ADDR,
output        [7:0]       	   oBYTE_ADDR,
output        [7:0]           oBYTE_DATA ,
output                        oWR_CMD,
output                        oStart,
input                         iI2C_READ_DATA_RDY,
input         [7:0]           iI2C_READ_DATA,
output                        oONE_CLK_CONFIG_DONE,
output	  reg                  oController_Ready,
output        [7:0]           oDEBUG_STATIC_STATE,
output                        oDEBUG_STATIC_CONFIG_DONE_PULSE,
output                        oDEBUG_STATIC_ACCESS_START

);

//=============================================================================
// PARAMETER declarations
//=============================================================================
parameter write_cmd = 1'b1;
parameter read_cmd = 1'b0;      
parameter NOT_LAST = 1'b0;
parameter LAST_REG = 1'b1;
//===========================================================================
// PORT declarations
//===========================================================================




//=============================================================================
// REG/WIRE declarations
//=============================================================================
reg   [7:0] i2c_reg_state;
wire  [6:0] slave_addr = `DEVICE_SLAVE_ID;
reg   [24:0] 	i2c_ctrl_data;// end_reg_instruction ,  slave_addr(7bit) + byte_addr(8bit) + byte_data(8bit)+ wr_cmd (1bit) = 24bit

wire        access_next_i2c_reg_cmd;
wire        i2c_controller_config_done;
wire        access_i2c_reg_start;

//wire        oONE_CLK_CONFIG_DONE;
//reg	        oController_Ready;

assign  oSLAVE_ADDR = i2c_ctrl_data[23:17];
assign  oBYTE_ADDR  = i2c_ctrl_data[16:9];
assign  oBYTE_DATA  = i2c_ctrl_data[8:1];
assign  oWR_CMD     = i2c_ctrl_data[0];
assign  oStart      = access_next_i2c_reg_cmd;
assign  oDEBUG_STATIC_STATE = i2c_reg_state;
assign  oDEBUG_STATIC_CONFIG_DONE_PULSE = i2c_controller_config_done;
assign  oDEBUG_STATIC_ACCESS_START = access_i2c_reg_start;

//=============    wire   all  reg  =========================

wire	[7:0]	REG_0018,REG_0021,REG_0102,REG_0112,REG_0113,REG_0114,REG_0115,REG_0117,REG_0118,
REG_0119,REG_011A,REG_0126,REG_0127,REG_0128,REG_0129,REG_012B,REG_012C,REG_012D,REG_012E,
REG_0141,REG_0235,REG_0236,REG_0237,REG_0238,REG_0239,REG_023A,REG_023B,REG_023C,REG_023D,
REG_023E,REG_023F,REG_0253,REG_0254,REG_0255,REG_0256,REG_0257,REG_0258,REG_025F,REG_0260,
REG_0261,REG_0262,REG_0263,REG_0264,REG_0302,REG_0303,REG_0304,REG_0305,REG_0306,REG_0307,
REG_0308,REG_0309,REG_030A,REG_030B,REG_030C,REG_030D,REG_030E,REG_030F,REG_0310,REG_0311,
REG_0312,REG_0313,REG_0314,REG_0315,REG_0316,REG_0317,REG_0318,REG_0319,REG_031A,REG_031B,
REG_031C,REG_031D,REG_031E,REG_031F,REG_0320,REG_0321,REG_0322,REG_0323,REG_0324,REG_0325,
REG_0326,REG_0327,REG_0328,REG_0329,REG_032A,REG_032B,REG_032C,REG_032D,REG_0338,REG_0339,
REG_033B,REG_033C,REG_033D,REG_033E,REG_033F,REG_0340,REG_0341,REG_0342,REG_0343,REG_0344,
REG_0345,REG_0346,REG_090E,REG_091C,REG_0949,REG_094A,REG_0A03,REG_0A04,REG_0A05,REG_0B44,REG_0B4A;

//=============    wire   all  reg  end =========================

//=============    wire   all  reg  address value ===============
wire	[7:0]	REG_ADDR_PAGE	=	8'h01	;

wire	[7:0]	REG_ADDR_0018	=	8'h18	;
wire	[7:0]	REG_ADDR_0021	=	8'h21	;
wire	[7:0]	REG_ADDR_0102	=	8'h02	;
wire	[7:0]	REG_ADDR_0112	=	8'h12	;
wire	[7:0]	REG_ADDR_0113	=	8'h13	;
wire	[7:0]	REG_ADDR_0114	=	8'h14	;
wire	[7:0]	REG_ADDR_0115	=	8'h15	;
wire	[7:0]	REG_ADDR_0117	=	8'h17	;
wire	[7:0]	REG_ADDR_0118	=	8'h18	;
wire	[7:0]	REG_ADDR_0119	=	8'h19	;
wire	[7:0]	REG_ADDR_011A	=	8'h1A	;
wire	[7:0]	REG_ADDR_0126	=	8'h26	;
wire	[7:0]	REG_ADDR_0127	=	8'h27	;
wire	[7:0]	REG_ADDR_0128	=	8'h28	;
wire	[7:0]	REG_ADDR_0129	=	8'h29	;
wire	[7:0]	REG_ADDR_012B	=	8'h2B	;
wire	[7:0]	REG_ADDR_012C	=	8'h2C	;
wire	[7:0]	REG_ADDR_012D	=	8'h2D	;
wire	[7:0]	REG_ADDR_012E	=	8'h2E	;
wire	[7:0]	REG_ADDR_0141	=	8'h41	;
wire	[7:0]	REG_ADDR_0235	=	8'h35	;
wire	[7:0]	REG_ADDR_0236	=	8'h36	;
wire	[7:0]	REG_ADDR_0237	=	8'h37	;
wire	[7:0]	REG_ADDR_0238	=	8'h38	;
wire	[7:0]	REG_ADDR_0239	=	8'h39	;
wire	[7:0]	REG_ADDR_023A	=	8'h3A	;
wire	[7:0]	REG_ADDR_023B	=	8'h3B	;
wire	[7:0]	REG_ADDR_023C	=	8'h3C	;
wire	[7:0]	REG_ADDR_023D	=	8'h3D	;
wire	[7:0]	REG_ADDR_023E	=	8'h3E	;
wire	[7:0]	REG_ADDR_023F	=	8'h3F	;
wire	[7:0]	REG_ADDR_0253	=	8'h53	;
wire	[7:0]	REG_ADDR_0254	=	8'h54	;
wire	[7:0]	REG_ADDR_0255	=	8'h55	;
wire	[7:0]	REG_ADDR_0256	=	8'h56	;
wire	[7:0]	REG_ADDR_0257	=	8'h57	;
wire	[7:0]	REG_ADDR_0258	=	8'h58	;
//wire	[7:0]	REG_ADDR_0259	=	8'h59	;
wire	[7:0]	REG_ADDR_025F	=	8'h5F	;
wire	[7:0]	REG_ADDR_0260	=	8'h60	;
wire	[7:0]	REG_ADDR_0261	=	8'h61	;
wire	[7:0]	REG_ADDR_0262	=	8'h62	;
wire	[7:0]	REG_ADDR_0263	=	8'h63	;
wire	[7:0]	REG_ADDR_0264	=	8'h64	;
wire	[7:0]	REG_ADDR_0302	=	8'h02	;
wire	[7:0]	REG_ADDR_0303	=	8'h03	;
wire	[7:0]	REG_ADDR_0304	=	8'h04	;
wire	[7:0]	REG_ADDR_0305	=	8'h05	;
wire	[7:0]	REG_ADDR_0306	=	8'h06	;
wire	[7:0]	REG_ADDR_0307	=	8'h07	;
wire	[7:0]	REG_ADDR_0308	=	8'h08	;
wire	[7:0]	REG_ADDR_0309	=	8'h09	;
wire	[7:0]	REG_ADDR_030A	=	8'h0A	;
wire	[7:0]	REG_ADDR_030B	=	8'h0B	;
wire	[7:0]	REG_ADDR_030C	=	8'h0C	;
wire	[7:0]	REG_ADDR_030D	=	8'h0D	;
wire	[7:0]	REG_ADDR_030E	=	8'h0E	;
wire	[7:0]	REG_ADDR_030F	=	8'h0F	;
wire	[7:0]	REG_ADDR_0310	=	8'h10	;
wire	[7:0]	REG_ADDR_0311	=	8'h11	;
wire	[7:0]	REG_ADDR_0312	=	8'h12	;
wire	[7:0]	REG_ADDR_0313	=	8'h13	;
wire	[7:0]	REG_ADDR_0314	=	8'h14	;
wire	[7:0]	REG_ADDR_0315	=	8'h15	;
wire	[7:0]	REG_ADDR_0316	=	8'h16	;
wire	[7:0]	REG_ADDR_0317	=	8'h17	;
wire	[7:0]	REG_ADDR_0318	=	8'h18	;
wire	[7:0]	REG_ADDR_0319	=	8'h19	;
wire	[7:0]	REG_ADDR_031A	=	8'h1A	;
wire	[7:0]	REG_ADDR_031B	=	8'h1B	;
wire	[7:0]	REG_ADDR_031C	=	8'h1C	;
wire	[7:0]	REG_ADDR_031D	=	8'h1D	;
wire	[7:0]	REG_ADDR_031E	=	8'h1E	;
wire	[7:0]	REG_ADDR_031F	=	8'h1F	;
wire	[7:0]	REG_ADDR_0320	=	8'h20	;
wire	[7:0]	REG_ADDR_0321	=	8'h21	;
wire	[7:0]	REG_ADDR_0322	=	8'h22	;
wire	[7:0]	REG_ADDR_0323	=	8'h23	;
wire	[7:0]	REG_ADDR_0324	=	8'h24	;
wire	[7:0]	REG_ADDR_0325	=	8'h25	;
wire	[7:0]	REG_ADDR_0326	=	8'h26	;
wire	[7:0]	REG_ADDR_0327	=	8'h27	;
wire	[7:0]	REG_ADDR_0328	=	8'h28	;
wire	[7:0]	REG_ADDR_0329	=	8'h29	;
wire	[7:0]	REG_ADDR_032A	=	8'h2A	;
wire	[7:0]	REG_ADDR_032B	=	8'h2B	;
wire	[7:0]	REG_ADDR_032C	=	8'h2C	;
wire	[7:0]	REG_ADDR_032D	=	8'h2D	;
wire	[7:0]	REG_ADDR_0338	=	8'h38	;
wire	[7:0]	REG_ADDR_0339	=	8'h39	;
wire	[7:0]	REG_ADDR_033B	=	8'h3B	;
wire	[7:0]	REG_ADDR_033C	=	8'h3C	;
wire	[7:0]	REG_ADDR_033D	=	8'h3D	;
wire	[7:0]	REG_ADDR_033E	=	8'h3E	;
wire	[7:0]	REG_ADDR_033F	=	8'h3F	;
wire	[7:0]	REG_ADDR_0340	=	8'h40	;
wire	[7:0]	REG_ADDR_0341	=	8'h41	;
wire	[7:0]	REG_ADDR_0342	=	8'h42	;
wire	[7:0]	REG_ADDR_0343	=	8'h43	;
wire	[7:0]	REG_ADDR_0344	=	8'h44	;
wire	[7:0]	REG_ADDR_0345	=	8'h45	;
wire	[7:0]	REG_ADDR_0346	=	8'h46	;
wire	[7:0]	REG_ADDR_090E	=	8'h0E	;
wire	[7:0]	REG_ADDR_091C	=	8'h1C	;
wire	[7:0]	REG_ADDR_0949	=	8'h49	;
wire	[7:0]	REG_ADDR_094A	=	8'h4A	;
wire	[7:0]	REG_ADDR_0A03	=	8'h03	;
wire	[7:0]	REG_ADDR_0A04	=	8'h04	;
wire	[7:0]	REG_ADDR_0A05	=	8'h05	;
wire	[7:0]	REG_ADDR_0B44	=	8'h44	;
wire	[7:0]	REG_ADDR_0B4A	=	8'h4A	;


//=============    wire   all  reg  address value  end ===============

//=============   assign all parameter value  ===============

wire 	[3:0]  	LOSFB_IN_INTR_MSK      	=	15	;
wire 		       IN_SEL_REGCTRL         	=	1	;
wire 	[1:0]  	IN_SEL                 	=	3	;

wire        		OUTALL_DISABLE_LOW     	=	1	;
wire        		OUT0_PDN               	=	0	;
wire        		OUT0_OE                	;//=	1	;
wire        		OUT0_RDIV_FORCE2       	=	1	;
wire 	[2:0]  	OUT0_FORMAT            	=	1	;
wire        		OUT0_SYNC_EN           	=	1	;
wire 	[1:0]  	OUT0_DIS_STATE         	=	0	;
wire 	[1:0]  	OUT0_CMOS_DRV          	=	0	;
wire 	[3:0]  	OUT0_CM                	=	14	;
wire 	[2:0]  	OUT0_AMPL              	=	3	;
wire 	[2:0]  	OUT0_MUX_SEL           	=	0	;
wire 	[1:0]  	OUT0_INV               	=	0	;

wire        		OUT1_PDN               	=	0	;
wire        		OUT1_OE                	;//=	1	;
wire        		OUT1_RDIV_FORCE2       	=	1	;
wire 	[2:0]  	OUT1_FORMAT            	=	1	;
wire        		OUT1_SYNC_EN           	=	1	;
wire 	[1:0]  	OUT1_DIS_STATE         	=	0	;
wire 	[1:0]  	OUT1_CMOS_DRV          	=	0	;
wire 	[3:0]  	OUT1_CM                	=	14	;
wire 	[2:0]  	OUT1_AMPL              	=	3	;
wire 	[2:0]  	OUT1_MUX_SEL           	=	1	;
wire 	[1:0]  	OUT1_INV               	=	0	;

wire        		OUT2_PDN               	=	0	;
wire        		OUT2_OE                	;//=	1	;
wire        		OUT2_RDIV_FORCE2       	=	1	;
wire 	[2:0]  	OUT2_FORMAT            	=	1	;
wire        		OUT2_SYNC_EN           	=	1	;
wire 	[1:0]  	OUT2_DIS_STATE         	=	0	;
wire 	[1:0]  	OUT2_CMOS_DRV          	=	0	;
wire 	[3:0]  	OUT2_CM                	=	14	;
wire 	[2:0]  	OUT2_AMPL              	=	3	;
wire 	[2:0]  	OUT2_MUX_SEL           	=	2	;
wire 	[1:0]  	OUT2_INV               	=	0	;

wire        		OUT3_PDN               	=	0	;
wire        		OUT3_OE                	;//=	0	;
wire        		OUT3_RDIV_FORCE2       	=	1	;
wire 	[2:0]  	OUT3_FORMAT            	=	1	;
wire        		OUT3_SYNC_EN           	=	1	;
wire 	[1:0]  	OUT3_DIS_STATE         	=	0	;
wire 	[1:0]  	OUT3_CMOS_DRV          	=	0	;
wire 	[3:0]  	OUT3_CM                	=	14	;
wire 	[2:0]  	OUT3_AMPL              	=	3	;
wire 	[2:0]  	OUT3_MUX_SEL           	=	3	;
wire 	[1:0]  	OUT3_INV               	=	0	;


wire        		OUT_DIS_LOL_MSK        	=	0	;
wire        		OUT_DIS_MSK_LOS_PFD    	=	0	;


wire 	[43:0] 	M_NUM                  	=	44'd634388480000;//44'd603979776000	;
wire 	[31:0] 	M_DEN                  	=	32'd2147483648	;
wire 	[23:0] 	R0_REG                 	=	0	;
wire 	[23:0] 	R1_REG                 	=	0	;
wire 	[23:0] 	R2_REG                 	=	0	;
wire 	[23:0] 	R3_REG                 	=	0	;

wire 	[43:0] 	N0_NUM                 	;//=	44'd72477573120	;
wire 	[31:0] 	N0_DEN                 	=	32'd2147483648	;
wire 	[43:0] 	N1_NUM                 	;//=	44'd64424509440	;
wire 	[31:0] 	N1_DEN                 	=	32'd2147483648	;
wire 	[43:0] 	N2_NUM                 	;//=	44'd144955146240	;
wire 	[31:0] 	N2_DEN                 	=	32'd2147483648	;
wire 	[43:0] 	N3_NUM                 	;//=	0	;
wire 	[31:0] 	N3_DEN                 	=	32'd2147483648	;
wire 	[4:0]  	N_FSTEP_MSK            	=	5'b11100;
// Diagnostic starting point. The final FSTEPW should come from ClockBuilder Pro.
wire 	[43:0] 	N0_FSTEPW              	=	44'd128;
wire 	[43:0] 	N1_FSTEPW              	=	44'd128;

wire 	        XAXB_EXTCLK_EN         	=	0	;
wire 		       XAXB_PDNB              	=	1	;
wire 	[2:0]  	ZDM_EN                 	=	4	;
wire 		       IO_VDD_SEL             	=	0	;
wire 	[3:0]  	IN_EN                  	=	8	;
wire 	[3:0]  	IN_CMOS_EN             	=	0	;
wire 	[3:0]  	SLAB_REFCLK_CLK2PLL_EN 	=	8	;
wire 	[4:0]  	N_CLK_TO_OUTX_EN       	=	15	;//15
wire 	[4:0]  	N_PIBYP                	=	0	;//0
wire 	[4:0]  	N_PDNB                 	=	15	;//15
wire 	[3:0]  	PDIV_ENB               	=	7	;
wire 	[4:0]  	N_CLK_DIS              	=	0	;//0

wire				M_UPDATE						=  1 ;
wire				N0_UPDATE						=  1 ;
wire				N1_UPDATE						=  1 ;
wire				N2_UPDATE						=  1 ;
wire				N3_UPDATE						=  1 ;
wire				N_UPDATE						=  1 ;
//=============   assign all parameter value end ===============


//=============   assign all parameter value to reg  ===============


assign	REG_0018     =	{4'b1111,LOSFB_IN_INTR_MSK};
assign	REG_0021     =	{5'd1,IN_SEL,IN_SEL_REGCTRL}; 

assign	REG_0102     =	{7'd0,OUTALL_DISABLE_LOW};

assign	REG_0112     =	{5'd0,OUT0_RDIV_FORCE2,OUT0_OE,OUT0_PDN};
assign	REG_0113     =	{OUT0_CMOS_DRV,OUT0_DIS_STATE,OUT0_SYNC_EN,OUT0_FORMAT};
assign	REG_0114     =	{1'b0,OUT0_AMPL,OUT0_CM};
assign	REG_0115     =	{OUT0_INV,3'd0,OUT0_MUX_SEL};

assign	REG_0117     =	{5'd0,OUT1_RDIV_FORCE2,OUT1_OE,OUT1_PDN};
assign	REG_0118     =	{OUT1_CMOS_DRV,OUT1_DIS_STATE,OUT1_SYNC_EN,OUT1_FORMAT};
assign	REG_0119     =	{1'b0,OUT1_AMPL,OUT1_CM};
assign	REG_011A     =	{OUT1_INV,3'd0,OUT1_MUX_SEL};

assign	REG_0126     =	{5'd0,OUT2_RDIV_FORCE2,OUT2_OE,OUT2_PDN};
assign	REG_0127     =	{OUT2_CMOS_DRV,OUT2_DIS_STATE,OUT2_SYNC_EN,OUT2_FORMAT};
assign	REG_0128     =	{1'b0,OUT2_AMPL,OUT2_CM};
assign	REG_0129     =	{OUT2_INV,3'd0,OUT2_MUX_SEL};

assign	REG_012B     =	{5'd0,OUT3_RDIV_FORCE2,OUT3_OE,OUT3_PDN};
assign	REG_012C     =	{OUT3_CMOS_DRV,OUT3_DIS_STATE,OUT3_SYNC_EN,OUT3_FORMAT};
assign	REG_012D     =	{1'b0,OUT3_AMPL,OUT3_CM};
assign	REG_012E     =	{OUT3_INV,3'd0,OUT3_MUX_SEL};


assign	REG_0141     =	{OUT_DIS_MSK_LOS_PFD,1'b1,OUT_DIS_LOL_MSK,5'd0};

assign	REG_0235	    =	M_NUM[7:0]	;
assign	REG_0236	    =	M_NUM[15:8]	;
assign	REG_0237	    =	M_NUM[23:16]	;
assign	REG_0238	    =	M_NUM[31:24]	;
assign	REG_0239	    =	M_NUM[39:32]	;
assign	REG_023A     =	{4'd0,M_NUM[43:40]};

assign	REG_023B	    =	M_DEN[7:0]	;
assign	REG_023C	    =	M_DEN[15:8]	;
assign	REG_023D	    =	M_DEN[23:16]	;
assign	REG_023E	    =	M_DEN[31:24]	;

assign	REG_023F	    =	{7'b0,M_UPDATE}	;


assign	REG_0253   	=	R0_REG[7:0]	;
assign	REG_0254   	=	R0_REG[15:8]	;
assign	REG_0255   	=	R0_REG[23:16]	;

assign	REG_0256	    =	R1_REG[7:0]	;
assign	REG_0257	    =	R1_REG[15:8]	;
assign	REG_0258	    =	R1_REG[23:16]	;


assign	REG_025F	    =	R2_REG[7:0]	;
assign	REG_0260    =	R2_REG[15:8]	;
assign	REG_0261	    =	R2_REG[23:16]	;


assign	REG_0262	    =	R3_REG[7:0]	;
assign	REG_0263	    =	R3_REG[15:8]	;
assign	REG_0264	    =	R3_REG[23:16]	;


assign	REG_0302	    =	N0_NUM[7:0]	;
assign	REG_0303	    =	N0_NUM[15:8]	;
assign	REG_0304	    =	N0_NUM[23:16]	;
assign	REG_0305	    =	N0_NUM[31:24]	;
assign	REG_0306	    =	N0_NUM[39:32]	;
assign	REG_0307     =	{4'd0,N0_NUM[43:40]};

assign	REG_0308	    =	N0_DEN[7:0]	;
assign	REG_0309	    =	N0_DEN[15:8]	;
assign	REG_030A	    =	N0_DEN[23:16]	;
assign	REG_030B	    =	N0_DEN[31:24]	;

assign	REG_030C	    =	{7'b0,N0_UPDATE}	;

assign	REG_030D	    =	N1_NUM[7:0]	;
assign	REG_030E	    =	N1_NUM[15:8]	;
assign	REG_030F	    =	N1_NUM[23:16]	;
assign	REG_0310	    =	N1_NUM[31:24]	;
assign	REG_0311	    =	N1_NUM[39:32]	;
assign	REG_0312     =	{4'd0,N1_NUM[43:40]};

assign	REG_0313	    =	N1_DEN[7:0]	;
assign	REG_0314	    =	N1_DEN[15:8]	;
assign	REG_0315	    =	N1_DEN[23:16]	;
assign	REG_0316	    =	N1_DEN[31:24]	;

assign	REG_0317	    =	{7'b0,N1_UPDATE}	;

assign	REG_0318	    =	N2_NUM[7:0]	;
assign	REG_0319	    =	N2_NUM[15:8]	;
assign	REG_031A	    =	N2_NUM[23:16]	;
assign	REG_031B	    =	N2_NUM[31:24]	;
assign	REG_031C	    =	N2_NUM[39:32]	;
assign	REG_031D     =	{4'd0,N2_NUM[43:40]};

assign	REG_031E	    =	N2_DEN[7:0]	;
assign	REG_031F	    =	N2_DEN[15:8]	;
assign	REG_0320	    =	N2_DEN[23:16]	;
assign	REG_0321	    =	N2_DEN[31:24]	;

assign	REG_0322	    =	{7'b0,N2_UPDATE}	;

assign	REG_0323	    =	N3_NUM[7:0]	;
assign	REG_0324	    =	N3_NUM[15:8]	;
assign	REG_0325	    =	N3_NUM[23:16]	;
assign	REG_0326	    =	N3_NUM[31:24]	;
assign	REG_0327	    =	N3_NUM[39:32]	;
assign	REG_0328     =	{4'd0,N3_NUM[43:40]};

assign	REG_0329	    =	N3_DEN[7:0]	;
assign	REG_032A	    =	N3_DEN[15:8]	;
assign	REG_032B	    =	N3_DEN[23:16]	;
assign	REG_032C	    =	N3_DEN[31:24]	;

assign	REG_032D	    =	{7'b0,N3_UPDATE}	;

assign	REG_0338	    =	{7'b0,N_UPDATE}	;

assign	REG_0339     =	{3'd0,N_FSTEP_MSK};

assign	REG_033B     = N0_FSTEPW[7:0];
assign	REG_033C     = N0_FSTEPW[15:8];
assign	REG_033D     = N0_FSTEPW[23:16];
assign	REG_033E     = N0_FSTEPW[31:24];
assign	REG_033F     = N0_FSTEPW[39:32];
assign	REG_0340     = {4'd0,N0_FSTEPW[43:40]};
assign	REG_0341     = N1_FSTEPW[7:0];
assign	REG_0342     = N1_FSTEPW[15:8];
assign	REG_0343     = N1_FSTEPW[23:16];
assign	REG_0344     = N1_FSTEPW[31:24];
assign	REG_0345     = N1_FSTEPW[39:32];
assign	REG_0346     = {4'd0,N1_FSTEPW[43:40]};


assign	REG_090E     =	{6'd0,XAXB_PDNB,XAXB_EXTCLK_EN};
assign	REG_091C     =	{5'd0,ZDM_EN};
assign	REG_0949     =	{IN_CMOS_EN,IN_EN};

assign	REG_094A     =	{SLAB_REFCLK_CLK2PLL_EN,4'd0};
assign	REG_0A03     =	{3'd0,N_CLK_TO_OUTX_EN};
assign	REG_0A04     =	{3'd0,N_PIBYP};
assign	REG_0A05     =	{3'd0,N_PDNB};
assign	REG_0B44     =	{4'd0,PDIV_ENB};
assign	REG_0B4A     =	{3'd0,N_CLK_DIS};




//=============================================================================
// Structural coding
//=============================================================================


si5340a_freq_prameter_selector f1(

.iPLL_OUT_FREQ_SEL(iPLL_OUT0_FREQ_SEL),
//.RX_REG(R0_REG),
.OUTX_OE(OUT0_OE),
.NX_NUM(N0_NUM)
//.NX_DEN(N0_DEN)   
);


si5340a_freq_prameter_selector f2(

.iPLL_OUT_FREQ_SEL(iPLL_OUT1_FREQ_SEL),
//.RX_REG(R1_REG),
.OUTX_OE(OUT1_OE),
.NX_NUM(N1_NUM)
//.NX_DEN(N1_DEN)   
);


si5340a_freq_prameter_selector f3(

.iPLL_OUT_FREQ_SEL(iPLL_OUT2_FREQ_SEL),
//.RX_REG(R2_REG),
.OUTX_OE(OUT2_OE),
.NX_NUM(N2_NUM)
//.NX_DEN(N2_DEN)   
);

si5340a_freq_prameter_selector f4(

.iPLL_OUT_FREQ_SEL(iPLL_OUT3_FREQ_SEL),
//.RX_REG(R3_REG),
.OUTX_OE(OUT3_OE),
.NX_NUM(N3_NUM)
//.NX_DEN(N3_DEN)   
);




//=====================================
//  State control
//=====================================
			
			
always@(posedge iCLK or negedge iRST_n)
	begin
		if (!iRST_n)
			begin
				i2c_reg_state <= 0;
			end
		else
			begin
				if (access_i2c_reg_start)
					i2c_reg_state <= 1'b1;
				else if (i2c_controller_config_done)
					i2c_reg_state <= i2c_reg_state+1;
				else if (i2c_reg_state == (`REG_NUM+1))
					i2c_reg_state <= 0;	
			end
	end
//=====================================
//  i2c bus address & data control 
//=====================================	



always@(*)
  begin
    i2c_ctrl_data = 0;
    case (i2c_reg_state)
0	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	8'd0	,	8'd0	,	read_cmd	}	;	
1	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_PAGE	,	8'h00	,	write_cmd	}	;	//change_page 0
2	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_0018	,	REG_0018	,	write_cmd	}	;	
3	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_0021	,	REG_0021	,	write_cmd	}	;	
4	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_PAGE	,	8'h01	,	write_cmd	}	;	//change_page 1
5	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_0102	,	REG_0102	,	write_cmd	}	;	
6	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_0112	,	REG_0112	,	write_cmd	}	;	
7	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_0113	,	REG_0113	,	write_cmd	}	;	
8	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_0114	,	REG_0114	,	write_cmd	}	;	
9	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_0115	,	REG_0115	,	write_cmd	}	;	
10	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_0117	,	REG_0117	,	write_cmd	}	;	
11	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_0118	,	REG_0118	,	write_cmd	}	;	
12	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_0119	,	REG_0119	,	write_cmd	}	;	
13	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_011A	,	REG_011A	,	write_cmd	}	;	
14	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_0126	,	REG_0126	,	write_cmd	}	;	
15	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_0127	,	REG_0127	,	write_cmd	}	;	
16	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_0128	,	REG_0128	,	write_cmd	}	;	
17	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_0129	,	REG_0129	,	write_cmd	}	;	
18	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_012B	,	REG_012B	,	write_cmd	}	;	
19	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_012C	,	REG_012C	,	write_cmd	}	;	
20	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_012D	,	REG_012D	,	write_cmd	}	;	
21	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_012E	,	REG_012E	,	write_cmd	}	;	
22	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_0141	,	REG_0141	,	write_cmd	}	;	
23	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_PAGE	,	8'h02	,	write_cmd	}	;	//change_page 2
24	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_0235	,	REG_0235	,	write_cmd	}	;	
25	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_0236	,	REG_0236	,	write_cmd	}	;	
26	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_0237	,	REG_0237	,	write_cmd	}	;	
27	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_0238	,	REG_0238	,	write_cmd	}	;	
28	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_0239	,	REG_0239	,	write_cmd	}	;	
29	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_023A	,	REG_023A	,	write_cmd	}	;	
30	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_023B	,	REG_023B	,	write_cmd	}	;	
31	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_023C	,	REG_023C	,	write_cmd	}	;	
32	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_023D	,	REG_023D	,	write_cmd	}	;	
33	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_023E	,	REG_023E	,	write_cmd	}	;	
34	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_023F	,	REG_023F	,	write_cmd	}	;	
35	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_0253	,	REG_0253	,	write_cmd	}	;	
36	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_0254	,	REG_0254	,	write_cmd	}	;	
37	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_0255	,	REG_0255	,	write_cmd	}	;	
38	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_0256	,	REG_0256	,	write_cmd	}	;	
39	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_0257	,	REG_0257	,	write_cmd	}	;	
40	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_0258	,	REG_0258	,	write_cmd	}	;	
41	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_025F	,	REG_025F	,	write_cmd	}	;	
42	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_0260	,	REG_0260	,	write_cmd	}	;	
43	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_0261	,	REG_0261	,	write_cmd	}	;	
44	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_0262	,	REG_0262	,	write_cmd	}	;	
45	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_0263	,	REG_0263	,	write_cmd	}	;	
46	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_0264	,	REG_0264	,	write_cmd	}	;	
47	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_PAGE	,	8'h03	,	write_cmd	}	;	//change_page 3
48	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_0302	,	REG_0302	,	write_cmd	}	;	
49	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_0303	,	REG_0303	,	write_cmd	}	;	
50	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_0304	,	REG_0304	,	write_cmd	}	;	
51	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_0305	,	REG_0305	,	write_cmd	}	;	
52	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_0306	,	REG_0306	,	write_cmd	}	;	
53	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_0307	,	REG_0307	,	write_cmd	}	;	
54	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_0308	,	REG_0308	,	write_cmd	}	;	
55	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_0309	,	REG_0309	,	write_cmd	}	;	
56	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_030A	,	REG_030A	,	write_cmd	}	;	
57	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_030B	,	REG_030B	,	write_cmd	}	;	
58	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_030C	,	REG_030C	,	write_cmd	}	;	
59	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_030D	,	REG_030D	,	write_cmd	}	;	
60	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_030E	,	REG_030E	,	write_cmd	}	;	
61	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_030F	,	REG_030F	,	write_cmd	}	;	
62	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_0310	,	REG_0310	,	write_cmd	}	;	
63	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_0311	,	REG_0311	,	write_cmd	}	;	
64	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_0312	,	REG_0312	,	write_cmd	}	;	
65	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_0313	,	REG_0313	,	write_cmd	}	;	
66	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_0314	,	REG_0314	,	write_cmd	}	;	
67	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_0315	,	REG_0315	,	write_cmd	}	;	
68	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_0316	,	REG_0316	,	write_cmd	}	;	
69	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_0317	,	REG_0317	,	write_cmd	}	;	
70	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_0318	,	REG_0318	,	write_cmd	}	;	
71	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_0319	,	REG_0319	,	write_cmd	}	;	
72	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_031A	,	REG_031A	,	write_cmd	}	;	
73	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_031B	,	REG_031B	,	write_cmd	}	;	
74	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_031C	,	REG_031C	,	write_cmd	}	;	
75	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_031D	,	REG_031D	,	write_cmd	}	;	
76	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_031E	,	REG_031E	,	write_cmd	}	;	
77	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_031F	,	REG_031F	,	write_cmd	}	;	
78	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_0320	,	REG_0320	,	write_cmd	}	;	
79	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_0321	,	REG_0321	,	write_cmd	}	;	
80	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_0322	,	REG_0322	,	write_cmd	}	;	
81	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_0323	,	REG_0323	,	write_cmd	}	;	
82	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_0324	,	REG_0324	,	write_cmd	}	;	
83	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_0325	,	REG_0325	,	write_cmd	}	;	
84	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_0326	,	REG_0326	,	write_cmd	}	;	
85	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_0327	,	REG_0327	,	write_cmd	}	;	
86	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_0328	,	REG_0328	,	write_cmd	}	;	
87	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_0329	,	REG_0329	,	write_cmd	}	;	
88	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_032A	,	REG_032A	,	write_cmd	}	;	
89	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_032B	,	REG_032B	,	write_cmd	}	;	
90	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_032C	,	REG_032C	,	write_cmd	}	;	
91	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_032D	,	REG_032D	,	write_cmd	}	;	
92	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_0338	,	REG_0338	,	write_cmd	}	;	
93	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_0339	,	REG_0339	,	write_cmd	}	;	
94	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_033B	,	REG_033B	,	write_cmd	}	;	
95	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_033C	,	REG_033C	,	write_cmd	}	;	
96	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_033D	,	REG_033D	,	write_cmd	}	;	
97	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_033E	,	REG_033E	,	write_cmd	}	;	
98	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_033F	,	REG_033F	,	write_cmd	}	;	
99	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_0340	,	REG_0340	,	write_cmd	}	;	
100	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_0341	,	REG_0341	,	write_cmd	}	;	
101	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_0342	,	REG_0342	,	write_cmd	}	;	
102	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_0343	,	REG_0343	,	write_cmd	}	;	
103	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_0344	,	REG_0344	,	write_cmd	}	;	
104	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_0345	,	REG_0345	,	write_cmd	}	;	
105	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_0346	,	REG_0346	,	write_cmd	}	;	
106	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_PAGE	,	8'h09	,	write_cmd	}	;	//change_page 9
107	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_090E	,	REG_090E	,	write_cmd	}	;	
108	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_091C	,	REG_091C	,	write_cmd	}	;	
109	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_0949	,	REG_0949	,	write_cmd	}	;	
110	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_094A	,	REG_094A	,	write_cmd	}	;	
111	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_PAGE	,	8'h0A	,	write_cmd	}	;	//change_page A
112	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_0A03	,	REG_0A03	,	write_cmd	}	;	
113	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_0A04	,	REG_0A04	,	write_cmd	}	;	
114	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_0A05	,	REG_0A05	,	write_cmd	}	;	
115	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_PAGE	,	8'h0B	,	write_cmd	}	;	//change_page B
116	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_0B44	,	REG_0B44	,	write_cmd	}	;	
117	:	i2c_ctrl_data	=	{	NOT_LAST	,	slave_addr	,	REG_ADDR_0B4A	,	REG_0B4A	,	write_cmd	}	;	





    endcase	
  end 



edge_detector u1(

.iCLK(iCLK),
.iRST_n(iRST_n),
.iIn(iI2C_CONTROLLER_CONFIG_DONE),
.oFallING_EDGE(i2c_controller_config_done),
.oRISING_EDGE()
);


always@(posedge iCLK or negedge iRST_n)
	begin
		if (!iRST_n)
			begin
				oController_Ready <= 1'b0;
			end
		else if (i2c_reg_state == `REG_NUM+1)	
			begin
				oController_Ready <= 1'b1;
			end
		else if (i2c_reg_state >0)
			begin
				oController_Ready <= 1'b0;
			end
	end


assign oONE_CLK_CONFIG_DONE = (i2c_reg_state == 0) ? 1'b1 : 1'b0;
assign access_next_i2c_reg_cmd = ((iI2C_CONTROLLER_STATE == 1'b0)&&
                                  ((i2c_reg_state <= `REG_NUM) && (i2c_reg_state > 0))
                                 ) ? 1'b1 : 1'b0;
assign access_i2c_reg_start = ((iENABLE == 1'b1)&&(iI2C_CONTROLLER_STATE == 1'b0)) ? 1'b1 : 1'b0;
		
		
		

endmodule 
