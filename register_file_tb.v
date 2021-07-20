`timescale 1ns / 100ps
module register_file_tb;


wire [15:0] SRC, DEST;

reg [3:0] ADDR_A, ADDR_B;
reg [15:0] DATA_IN;
reg WR, CLK, RSTn;


register_file register
( .CLK(CLK),
  .RSTn(RSTn),
  .ADDR_A(ADDR_A),
  .ADDR_B(ADDR_B),
  .DATA_IN(DATA_IN),
  .WR(WR),
  .SRC(SRC),
  .DEST(DEST)
);

integer i;

initial forever
  #5 CLK = ~CLK;

initial
begin

  CLK=1;

  RSTn = 1;
  #2 	RSTn = 0;
  WR=0;
  #20 	RSTn = 1;
  $display($time, " ********************** ");
  $display($time, " ** Start Simulation ** ");
  $display($time, " ********************** ");

  $display($time, " *** Register File **** ");
  $display($time, " ********************** ");
  for (i=0;i<8;i=i+1) begin
    $display($time, " Reg[%d]: %h (%b)", i, register.reg_array[i], register.reg_array[i]);
  end

  ////////// WRITE /////////

  $display($time, " ********************************* ");
  $display($time, " ** Write Data to Register File ** ");
  $display($time, " ********************************* ");
  ADDR_A = 4'b0000; 		// Select R0
  ADDR_B = 4'b0001; 		// Select R1

  #20 	DATA_IN = 16'h1234;

  #20 	WR = 1;			// Write to R1
  #10 	WR = 0;

  $display($time, "[WRITE] Reg[1]: %h", register.reg_array[1]);
  if (register.reg_array[1] == 16'h1234) begin
    $display($time, "[WRITE] Correctly Write!");
  end
  else begin
    $display($time, "[WRITE] Incorrectly Written to Reg[1]..");
    $display($time, "[WRITE] True result is Reg[1]: 0x1234");
  end

  #20 	ADDR_B = 4'b0111;		// Select R7

  #20 	DATA_IN = 16'h5678;

  #20 	WR = 1;			// Write to R7
  #10 	WR = 0;


  $display($time);
  $display($time, "[WRITE] Reg[7]: %h", register.reg_array[7]);
  if (register.reg_array[7] == 16'h5678) begin
    $display($time, "[WRITE] Correctly Write!");
  end
  else begin
    $display($time, "[WRITE] Incorrectly Written to Reg[7]..");
    $display($time, "[WRITE] True result is Reg[7]: 0x5678");
  end


  ///////////////////////////



  /////////// READ //////////

  $display($time, " ********************************** ");
  $display($time, " ** Read Data from Register File ** ");
  $display($time, " ********************************** ");
  #20 	ADDR_A = 4'b0100;		// Read R4
  ADDR_B = 4'b0101;		// Read R5
  $display($time, "[READ] Reg[4]: %h", SRC);
  if (SRC == 16'h0000) begin
    $display($time, "[READ] Correctly Read!");
  end
  else begin
    $display($time, "[READ] Incorrectly Read from Reg[4]..");
    $display($time, "[READ] True result is Reg[4]: 0x0000");
  end
  $display($time);
  $display($time, "[READ] Reg[5]: %h", DEST);
  if (DEST == 16'h0000) begin
    $display($time, "[READ] Correctly Read!");
  end
  else begin
    $display($time, "[READ] Incorrectly Read from Reg[5]..");
    $display($time, "[READ] True result is Reg[5]: 0x0000");
  end
  

  #20 	ADDR_A = 4'b0111;		// Read R7
  $display($time);
  $display($time, "[READ] Reg[7]: %h", SRC);
  if (SRC == 16'h5678) begin
    $display($time, "[READ] Correctly Read!");
  end
  else begin
    $display($time, "[READ] Incorrectly Read from Reg[7]..");
    $display($time, "[READ] True result is Reg[7]: 0x5678");
  end

  #20 	ADDR_B = 4'b0001;		// Read R1
  $display($time);
  $display($time, "[READ] Reg[1]: %h", DEST);
  if (DEST == 16'h1234) begin
    $display($time, "[READ] Correctly Read!");
  end
  else begin
    $display($time, "[READ] Incorrectly Read from Reg[1]..");
    $display($time, "[READ] True result is Reg[1]: 0x1234");
  end

  ////////////////////////////
  $display($time, " *********************** ");
  $display($time, " ** Finish Simulation ** ");
  $display($time, " *********************** ");
  $display($time, " *** Register File ***** ");
  $display($time, " *********************** ");
  for (i=0;i<8;i=i+1) begin
    $display($time, " Reg[%d]: %h (%b)", i, register.reg_array[i], register.reg_array[i]);
  end


  #20 	RSTn = 0;
  #20 	RSTn = 1;

  #40
  $finish;
end

// dump the state of the design
// VCD (Value Change Dump) is a standard dump format defined in Verilog.
initial begin
  $dumpfile("sim.vcd");
  $dumpvars(0, register_file_tb);
end

endmodule
