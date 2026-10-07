`define WIDTH 4
`define FREQ_NUM 8

module si5340b_clk_frq_sel_gen (


input wire iCLK,
input wire iRST_n,
input wire iCHANGE,
output reg [`WIDTH-1 :0] oCLK_FEQ_SEL ,
output wire oCHANGE_FREQ 

);

wire change_freq;
 
assign oCHANGE_FREQ = change_freq;

edge_detector edge_detector(

.iCLK(iCLK),
.iRST_n(iRST_n),
.iIn(iCHANGE),
.oDEBOUNCE_OUT(change_freq)
);


always@(posedge iCLK or negedge iRST_n)
begin
	if (!iRST_n)
		begin 
			oCLK_FEQ_SEL <= 0;
		end
	else if (change_freq)
		begin
			oCLK_FEQ_SEL <= oCLK_FEQ_SEL + 1;
		end 

end 



endmodule 



