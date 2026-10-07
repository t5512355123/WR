module si5340a_freq_prameter_selector (

input         [2:0]          iPLL_OUT_FREQ_SEL,
//output   reg  [23:0]         RX_REG,
output   reg                 OUTX_OE,
output   reg  [43:0]         NX_NUM,
output   reg  [31:0]         NX_DEN       

);




always @(*)
  begin
    case(iPLL_OUT_FREQ_SEL)
      3'h1 :   //644.53125 MHz
        begin
//          RX_REG = 24'd0;
          OUTX_OE = 1'b1 ;
          NX_NUM = 44'd23622320128;//44'd22490010568;
//          NX_DEN = 32'd165;
        end
      3'h2 :   //322.265625 MHz
        begin
//          RX_REG = 24'd1;
          OUTX_OE = 1'b1 ;
          NX_NUM = 44'd47244640256;//44'd44980021136;
//          NX_DEN = 32'd165;          
        end
      3'h3 :   //312.5 MHz
        begin
//          RX_REG = 24'd0;
          OUTX_OE = 1'b1;
          NX_NUM = 44'd48721035264;//44'd46459982769;
//          NX_DEN = 32'd5;          
        end                     
      3'h4 :   //250.0 MHz
        begin
//          RX_REG = 24'd1;
          OUTX_OE = 1'b1;
          NX_NUM = 44'd60901294080;//44'd57982058496;
//          NX_DEN = 32'd1;          
        end
      3'h5 :   //156.25 MHz
        begin
//          RX_REG = 24'd1;
          OUTX_OE = 1'b1;
          NX_NUM = 44'd97442070528;//44'd92771293594;
//          NX_DEN = 32'd5;          
        end     
      3'h6 :   //125.0 MHz
        begin
//          RX_REG = 24'd3;
          OUTX_OE = 1'b1;
          NX_NUM = 44'd121802588160;//44'd115964116992;
//          NX_DEN = 32'd1;            
        end                     
      3'h7 :   //124.992 MHz (WR DDMTD offset clock)
        begin
//          RX_REG = 24'd4;
          OUTX_OE = 1'b1;
          NX_NUM = 44'd121810384025;
//          NX_DEN = 32'd1;           
        end               
      3'h0 :   //power down
        begin
//          RX_REG = 24'd0;
          OUTX_OE = 1'b0;
          NX_NUM = 44'd0;
//          NX_DEN = 32'd0;           
        end                 
      default :   //100Mhz
        begin
//          RX_REG = 24'd4;
          OUTX_OE = 1'b1;
          NX_NUM = 44'd152253235200;//44'd144955146240;
//          NX_DEN = 32'd1;           
        end                         
      endcase
  end


endmodule
