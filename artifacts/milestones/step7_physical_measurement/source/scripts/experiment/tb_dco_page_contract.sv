`timescale 1ns/1ps
// Pin-level runtime contract test. Static startup is bypassed explicitly;
// the production serializer and I2C bit engine are NOT mocked.
module tb_dco_page_contract;
  reg clk=0, rst=1, dl=0, hl=0, trigger=0;
  reg [15:0] dd=0, hd=5;
  always #5 clk=~clk;
  wire scl;
  tri1 sda;
  reg ack=0;
  assign sda=ack ? 1'b0 : 1'bz;
  wire [15:0] completed;
  si5340a_controller_dco #(.ENABLE_NORMAL_HPLL_TRACKER(0)) dut (
    .iCLK(clk), .iRST_n(rst), .iStart(1'b0),
    .iPLL_OUT0_FREQ_SEL(3'd0), .iPLL_OUT1_FREQ_SEL(3'd0),
    .iPLL_OUT2_FREQ_SEL(3'd0), .iPLL_OUT3_FREQ_SEL(3'd0),
    .iDPLL_LOAD(dl), .iDPLL_DATA(dd), .iHPLL_LOAD(hl), .iHPLL_DATA(hd),
    .iFORCE_HPLL_ONE_STEP(trigger), .iFORCE_HPLL_REVERSE(1'b0),
    .iFORCE_HPLL_BURST_SIZE(16'd1), .I2C_CLK(scl), .I2C_DATA(sda),
    .oDCO_STEP_COUNT(completed));
  reg active=0;
  integer bits=0, bytes=0, writes=0, n0=0, n1=0, wrong_mask=0;
  reg [7:0] shift=0, address=0, page=0, mask=8'h0c;
  integer old0, old1, old_completed;
  reg expect_fixed;
  always @(negedge sda) if (scl === 1'b1 && rst) begin
    active=1; bits=0; bytes=0; shift=0;
  end
  always @(posedge sda) if (scl === 1'b1 && rst) active=0;
  always @(negedge scl) ack = active && (bits==8);
  always @(posedge scl) if (active) begin
    if (bits==8) begin bits=0; bytes=bytes+1; end
    else begin
      shift={shift[6:0],sda}; bits=bits+1;
      if (bits==8) begin
        if (bytes==0 && shift!=8'hee) $fatal(1,"Unexpected slave address %h",shift);
        if (bytes==1) address=shift;
        if (bytes==2) begin
          writes=writes+1;
          $display("PIN_WRITE page=%02h offset=%02h data=%02h",page,address,shift);
          if (address==8'h01) page=shift;
          else if (page==3 && address==8'h39) mask=shift;
          else if (page==0 && address==8'h39) wrong_mask=wrong_mask+1;
          else if (page==0 && address==8'h1d) begin
            if (!mask[0]) n0=n0+((shift==1)?1:-1);
            if (!mask[1]) n1=n1+((shift==1)?1:-1);
          end
        end
      end
    end
  end
  task load_main(input [15:0] value);
    begin @(negedge clk); dd=value; dl=1; @(negedge clk); dl=0; end
  endtask
  initial begin
    expect_fixed=$test$plusargs("fixed");
    force dut.initial_start=0;
    force dut.static_start_pulse=0;
    force dut.static_controller_ready=1;
    force dut.i2c_system_clk=clk;
    #20; rst=0; #100; rst=1;
    load_main(16'd100);
    load_main(16'd10000);
    wait(completed==1); #1000;
    $display("MAIN_JUMP code_delta=9900 completed=%0d N0=%0d N1=%0d",completed,n0,n1);
    if (n0!=1 || n1!=(expect_fixed?0:1)) $fatal(1,"Main isolation mismatch");
    repeat(10) load_main(16'd10000);
    #100000;
    if(completed!=1) $fatal(1,"Unexpected same-code work");
    $display("MAIN_ABSOLUTE_CONTRACT=KNOWN_FAIL constant target has no residual drain");
    old0=n0; old1=n1;
    @(negedge clk); hl=1; @(negedge clk); hl=0;
    @(negedge clk); trigger=1;
    wait(completed==2); #1000; trigger=0;
    if(n1-old1!=-1 || n0-old0!=(expect_fixed?0:-1)) $fatal(1,"Helper isolation mismatch");
    if(wrong_mask!=(expect_fixed?0:2)) $fatal(1,"Wrong-page count mismatch");
    if(writes!=(expect_fixed?8:6)) $fatal(1,"Unexpected write count %0d",writes);
    if(dut.u_i2c_bus.oACK_ERROR) $fatal(1,"Pin model ACK failure");
    $display("PAGE_CONTRACT_TEST=PASS expected_fixed=%0d writes=%0d wrong_page=%0d",expect_fixed,writes,wrong_mask);
    $finish;
  end
  initial begin #2000000; $display("rt=%h bus=%h bit=%h start=%h",dut.rt_state,dut.u_i2c_bus.i2c_state,dut.u_i2c_bus.i2c_bit_cnt,dut.bus_start); $fatal(1,"Runtime timeout"); end
endmodule
