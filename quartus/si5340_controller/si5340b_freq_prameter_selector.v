module si5340b_freq_prameter_selector (

input         [4:0]   iPLL_OUT_FREQ_SEL,
//output   reg  		      OUT0_RDIV_FORCE2	,
//output   reg  	[2:0] 	OUT0_MUX_SEL	,
//output   reg  		      OUT1_RDIV_FORCE2	,
//output   reg  	[2:0] 	OUT1_MUX_SEL	,
//output   reg  		      OUT3_RDIV_FORCE2	,
//output   reg  	[2:0] 	OUT3_MUX_SEL	,
//output   reg  	[43:0]	M_NUM	,
//output   reg  	[31:0]	M_DEN	,
//output   reg  	[23:0]	R0_REG	,
//output   reg  	[23:0]	R1_REG	,
//output   reg  	[23:0]	R3_REG	,
output   reg  	[43:0]	N0_NUM	,
output   reg  	[43:0]	N1_NUM	,
//output   reg  	[31:0]	N1_DEN	,
output   reg  	[43:0]	N2_NUM	
//output   reg  	[31:0]	N2_DEN	,
//output   reg  	[4:0] 	N_CLK_TO_OUTX_EN	,
//output   reg  	[4:0] 	N_PIBYP 	,
//output   reg  	[4:0] 	N_PDNB	,
//output   reg  	[4:0] 	N_CLK_DIS	   

);




always @(*)
  begin
    case(iPLL_OUT_FREQ_SEL)
	
      5'h0 :   //case1 :  OUT0_DDR3 = 300Mhz , OUT1_PCIE = 100Mhz , OUT3_QDRII+ = 275Mhz
        begin
							N0_NUM	=	44'd48676296021  	; 
							N1_NUM	=	44'd146028888064	; 
							N2_NUM	=	44'd73014444032	    ; 
        end	
      5'h1 :   //case2 :  OUT0_DDR3 = 266.667Mhz , OUT1_PCIE = 100Mhz , OUT3_QDRII+ = 275Mhz
        begin
							N0_NUM	=	44'd54760833024	    ; 
							N1_NUM	=	44'd146028888064	; 
							N2_NUM	=	44'd73014444032	    ; 
        end
      5'h2 :   //case3 :  OUT0_DDR3 = 233.333Mhz , OUT1_PCIE = 100Mhz , OUT3_QDRII+ = 275Mhz

        begin
							N0_NUM	=	44'd62583809170     ; 
							N1_NUM	=	44'd146028888064	; 
							N2_NUM	=	44'd73014444032	    ;   
        end
      5'h3 :   //case4 :  OUT0_DDR3 = 200Mhz , OUT1_PCIE = 100Mhz , OUT3_QDRII+ = 275Mhz

        begin
							N0_NUM	=	44'd73014444032     ; 
							N1_NUM	=	44'd146028888064	; 
							N2_NUM	=	44'd73014444032	    ;     
        end 
      5'h4 :   //case5 :  OUT0_DDR3 = 150Mhz , OUT1_PCIE = 100Mhz , OUT3_QDRII+ = 275Mhz

        begin
							N0_NUM	=	44'd97352592043     ; 
							N1_NUM	=	44'd146028888064	; 
							N2_NUM	=	44'd73014444032	    ;     
        end
//===============================================================		
      5'h5 :   //case6 :  OUT0_DDR3 = 300Mhz , OUT1_PCIE = 100Mhz , OUT3_QDRII+ = 250Mhz
        begin
							N0_NUM	=	44'd48676296021	    ; 
							N1_NUM	=	44'd146028888064	; 
							N2_NUM	=	44'd80315888435		;       
        end		
      5'h6 :   //case7 :  OUT0_DDR3 = 266.667Mhz , OUT1_PCIE = 100Mhz , OUT3_QDRII+ = 250Mhz
        begin
							N0_NUM	=	44'd54760833024	    ; 
							N1_NUM	=	44'd146028888064	; 
							N2_NUM	=	44'd80315888435		;       
        end
      5'h7 :   //case8 :  OUT0_DDR3 = 233.333Mhz , OUT1_PCIE = 100Mhz , OUT3_QDRII+ = 250Mhz

        begin
							N0_NUM	=	44'd62583809170	    ; 
							N1_NUM	=	44'd146028888064	;
							N2_NUM	=	44'd80315888435 	;   
        end     
      5'h8 :   //case9 :  OUT0_DDR3 = 200Mhz , OUT1_PCIE = 100Mhz , OUT3_QDRII+ = 250Mhz

        begin
							N0_NUM	=	44'd73014444032     ;
							N1_NUM	=	44'd146028888064	;
							N2_NUM	=	44'd80315888435 	;     
        end 
      5'h9 :   //case10 :  OUT0_DDR3 = 150Mhz , OUT1_PCIE = 100Mhz , OUT3_QDRII+ = 250Mhz

        begin
							N0_NUM	=	44'd97352592043     ;
							N1_NUM	=	44'd146028888064	;
							N2_NUM	=	44'd80315888435 	;     
        end 
//===============================================================	
      5'hA :   //case11 :  OUT0_DDR3 = 300Mhz , OUT1_PCIE = 100Mhz , OUT3_QDRII+ = 225Mhz
        begin
							N0_NUM	=	44'd48676296021	    ; 
							N1_NUM	=	44'd146028888064	;
							N2_NUM	=	44'd89239876039		;        
        end   
		
      5'hB :   //case12 :  OUT0_DDR3 = 266.667Mhz , OUT1_PCIE = 100Mhz , OUT3_QDRII+ = 225Mhz
        begin
							N0_NUM	=	44'd54760833024	    ; 
							N1_NUM	=	44'd146028888064	;
							N2_NUM	=	44'd89239876039		;        
        end               
      5'hC :   //case13 :  OUT0_DDR3 = 233.333Mhz , OUT1_PCIE = 100Mhz , OUT3_QDRII+ = 225Mhz
        begin
							N0_NUM	=	44'd62583809170	    ; 
							N1_NUM	=	44'd146028888064	; 
							N2_NUM	=	44'd89239876039 	;     
        end 
        
       5'hD :   //case14 :  OUT0_DDR3 = 200Mhz , OUT1_PCIE = 100Mhz , OUT3_QDRII+ = 225Mhz
        begin
							N0_NUM	=	44'd73014444032     ; 
							N1_NUM	=	44'd146028888064	; 
							N2_NUM	=	44'd89239876039 	;  
        end   
       5'hE :   //case15 :  OUT0_DDR3 = 150Mhz , OUT1_PCIE = 100Mhz , OUT3_QDRII+ = 225Mhz
        begin
							N0_NUM	=	44'd97352592043     ; 
							N1_NUM	=	44'd146028888064	; 
							N2_NUM	=	44'd89239876039 	;  
        end 
//===========================================================	
      5'hF :   //case16 :  OUT0_DDR3 = 300Mhz , OUT1_PCIE = 100Mhz , OUT3_QDRII+ = 233.333Mhz
        begin
							N0_NUM	=	44'd48676296021	    ; 
							N1_NUM	=	44'd146028888064	; 
							N2_NUM	=	44'd86052737610	    ; 
        end
	
      5'h10 :   //case17 :  OUT0_DDR3 = 266.667Mhz , OUT1_PCIE = 100Mhz , OUT3_QDRII+ = 233.333Mhz
        begin
							N0_NUM	=	44'd54760833024	    ; 
							N1_NUM	=	44'd146028888064	; 
							N2_NUM	=	44'd86052737610	    ; 
        end
      5'h11 :   //case18 :  OUT0_DDR3 = 233.333Mhz , OUT1_PCIE = 100Mhz , OUT3_QDRII+ = 233.333Mhz

        begin
							N0_NUM	=	44'd62583809170     ; 
							N1_NUM	=	44'd146028888064	; 
							N2_NUM	=	44'd86052737610	    ;   
        end
      5'h12 :   //case19 :  OUT0_DDR3 = 200Mhz , OUT1_PCIE = 100Mhz , OUT3_QDRII+ = 233.333Mhz

        begin
							N0_NUM	=	44'd73014444032     ; 
							N1_NUM	=	44'd146028888064	; 
							N2_NUM	=	44'd86052737610	    ;     
        end  	
      5'h13 :   //case20 :  OUT0_DDR3 = 150Mhz , OUT1_PCIE = 100Mhz , OUT3_QDRII+ = 233.333Mhz

        begin
							N0_NUM	=	44'd97352592043     ; 
							N1_NUM	=	44'd146028888064	; 
							N2_NUM	=	44'd86052737610	    ;     
        end 
//================================================================		
      default :   //case1 :  OUT0_DDR3 = 300Mhz , OUT1_PCIE = 100Mhz , OUT3_QDRII+ = 275Mhz
        begin
							N0_NUM	=	44'd48676296021	    ; 
							N1_NUM	=	44'd146028888064	; 
							N2_NUM	=	44'd73014444032	    ; 
        end                         
      endcase
  end


endmodule