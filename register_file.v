`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/09/10 15:03:30
// Design Name: 
// Module Name: Register_file
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module register_file(
    input CLK,
    input WR,
    input RSTn,
    input [3:0] ADDR_A,
    input [3:0] ADDR_B,
    input [15:0] DATA_IN,
    output [15:0] SRC,
    output [15:0] DEST
    );
    
    reg [15:0] reg_array [7:0];
    integer i;
    always @(posedge CLK, negedge RSTn)
    begin
        if(!RSTn) begin
            reg_array[0] <= 16'h0000;
            reg_array[1] <= 16'h0000;
            reg_array[2] <= 16'h0000;
            reg_array[3] <= 16'h0000;
            reg_array[4] <= 16'h0000;
            reg_array[5] <= 16'h0000;
            reg_array[6] <= 16'h0000;
            reg_array[7] <= 16'h0000;
        end
        else if(WR) begin
            reg_array[ADDR_B] <= DATA_IN;
        end
    end
    assign SRC = reg_array[ADDR_A];
    assign DEST = reg_array[ADDR_B];
endmodule
