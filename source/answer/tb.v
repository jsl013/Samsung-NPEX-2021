`timescale 1ns / 1ps

module tb();
parameter CLK_CYCLE = 5;
parameter INPUT_SIZE = 8; // byte
parameter OUTPUT_SIZE = 4;  // byte
parameter BYTE_SIZE = 8;
parameter BIAS_SIZE = OUTPUT_SIZE;  // byte
parameter WEIGHT_SIZE = INPUT_SIZE*OUTPUT_SIZE; // byte



reg clk;
reg rstn;
reg r_valid;
reg [31:0] data_input;
wire [31:0] data_output;
wire t_valid;

integer iter;

reg [INPUT_SIZE*BYTE_SIZE-1:0] input_1;
reg [INPUT_SIZE*OUTPUT_SIZE*BYTE_SIZE-1:0] weight_1;
reg [OUTPUT_SIZE*BYTE_SIZE-1:0] bias_1;
reg [OUTPUT_SIZE*BYTE_SIZE-1:0] expected_1;

reg [INPUT_SIZE*BYTE_SIZE-1:0] input_2;
reg [INPUT_SIZE*OUTPUT_SIZE*BYTE_SIZE-1:0] weight_2;
reg [OUTPUT_SIZE*BYTE_SIZE-1:0] bias_2;
reg [OUTPUT_SIZE*BYTE_SIZE-1:0] expected_2;

always #CLK_CYCLE clk = ~clk;

initial begin
    clk  = 1'b0;
    rstn = 1'b0;
    
    input_1 = 64'h12102AB4_FF1A53BD;
    weight_1 = 256'b10000001_11110000_00011111_10111000_00001011_11101011_11110110_00110100_00111100_10111101_11110111_10111111_01010010_01100110_10100001_00001001_00001010_01011111_11100110_01010111_00111011_00111111_01011010_11101111_00110111_00111000_01000000_01010000_00100100_01010001_01111111_00111100;
    bias_1 = 32'b11101111_00011001_11110010_11101111;
    expected_1 = 32'hE503335D;
    
    input_2 = 64'b00001110_00000110_11110101_10010001_00101001_00101110_11000011_00100001;
    weight_2 = 256'b11110100_00011111_10000001_01001111_00100111_00100011_00011011_10101111_00011010_11111010_11011000_01110001_00010111_11000010_01000101_11110110_10011111_11110111_10101110_01101111_11100100_10100111_11100001_10000001_00011100_00001011_10101011_11111001_11011100_11110100_01110101_00001100;
    bias_2 = 32'b11001000_01000010_11100001_01001110;
    expected_2 = 32'b10000000_10000000_10000000_11100110;
    
    //////1st///////
    $display();
    $display("///////////////////////////////////////////////////////////");
    $display("//////////////////// First Test Start /////////////////////");
    $display("///////////////////////////////////////////////////////////");
    $display();
    
    r_valid = 1'b0;
    data_input = 32'd0;
    repeat(10)
      @(posedge clk);
    rstn = 1'b1;
  
    r_valid = 1'b1;
    iter = INPUT_SIZE[9:2];
    repeat(INPUT_SIZE[9:2])
      @(posedge clk) begin
        data_input = big_to_little(input_1[32*iter-1-:32]);
        iter = iter - 1;
      end
    iter = WEIGHT_SIZE[9:2];
    repeat(WEIGHT_SIZE[9:2])
      @(posedge clk) begin
        data_input = big_to_little(weight_1[32*iter-1-:32]);
        iter = iter - 1;
      end      
    iter = BIAS_SIZE[9:2];
    repeat(BIAS_SIZE[9:2])
      @(posedge clk) begin
        data_input = big_to_little(bias_1[32*iter-1-:32]);
        iter = iter - 1;
      end
      
    repeat(1)
      @(posedge clk);

    r_valid = 1'b0;

    wait(t_valid);
    repeat(1)
      @(posedge clk);
    if(data_output == big_to_little(expected_1)) begin
      $display("///////////////////////////////////////////////////////////");
      $display("///////////////// First Result is correct! ////////////////");
      $display("///////////////////////////////////////////////////////////");
      $display();
    end
    else begin
      $display("///////////////////////////////////////////////////////////");
      $display("////////////////// First Result is wrong! /////////////////");
      $display("///////////////////////////////////////////////////////////");
      $display();
    end
    
    //////2nd///////
    
    $display("///////////////////////////////////////////////////////////");
    $display("//////////////////// Second Test Start ////////////////////");
    $display("///////////////////////////////////////////////////////////");
    $display();
    
       
    r_valid = 1'b0;
    data_input = 32'd0;
    repeat(10)
      @(posedge clk);
    rstn = 1'b1;
  
    r_valid = 1'b1;
    iter = INPUT_SIZE[9:2];
    repeat(INPUT_SIZE[9:2])
      @(posedge clk) begin
        data_input = big_to_little(input_2[32*iter-1-:32]);
        iter = iter - 1;
      end
    iter = WEIGHT_SIZE[9:2];
    repeat(WEIGHT_SIZE[9:2])
      @(posedge clk) begin
        data_input = big_to_little(weight_2[32*iter-1-:32]);
        iter = iter - 1;
      end      
    iter = BIAS_SIZE[9:2];
    repeat(BIAS_SIZE[9:2])
      @(posedge clk) begin
        data_input = big_to_little(bias_2[32*iter-1-:32]);
        iter = iter - 1;
      end
      
    repeat(1)
      @(posedge clk);
    r_valid = 1'b0;

    wait(t_valid);
    repeat(1)
      @(posedge clk);
    if(data_output == big_to_little(expected_2)) begin
      $display("///////////////////////////////////////////////////////////");
      $display("//////////////// Second Result is correct! ////////////////");
      $display("///////////////////////////////////////////////////////////");
      $display();
    end
    else begin
      $display("///////////////////////////////////////////////////////////");
      $display("///////////////// Second Result is wrong! /////////////////");
      $display("///////////////////////////////////////////////////////////");
      $display();
    end
    $finish;
end

  function [31:0] big_to_little(input [31:0] big);
    begin
      big_to_little[31:24] = big[7:0];
      big_to_little[23:16] = big[15:8];
      big_to_little[15:8] = big[23:16];
      big_to_little[7:0] = big[31:24];
    end
  endfunction

  sample_controller u_sample_controller(
    .clk(clk),
    .rstn(rstn),
    .r_valid(r_valid),
    .in_data(data_input),
    .out_data(data_output),
    .t_valid(t_valid)
);
endmodule
