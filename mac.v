`timescale 1ns / 1ps

module mac #(

    parameter integer A_BITWIDTH = 8,
    parameter integer B_BITWIDTH = A_BITWIDTH,
    parameter integer OUT_BITWIDTH = 19,
    parameter integer C_BITWIDTH = OUT_BITWIDTH - 1
)
(
    
    input                                   clk,
    input                                   en,
    input                                   rstn,
    input  [A_BITWIDTH-1:0]                  data_a, 
    input  [B_BITWIDTH-1:0]                  data_b,
    input  [C_BITWIDTH-1:0]                  data_c,
    output [OUT_BITWIDTH-1:0]               mout,
    output reg                              done
    );

localparam 
    STATE_IDLE = 2'b00, 
    STATE_MULT = 2'b01, 
    STATE_Addx = 2'b10,
    STATE_Done = 2'b11;
    
reg signed [OUT_BITWIDTH-1:0]          mout_temp;
reg signed [OUT_BITWIDTH-1:0]          mout_temp_2;
reg [1:0]                       m_state;
reg signed [A_BITWIDTH-1:0]            tmp_data_a;
reg signed [B_BITWIDTH-1:0]            tmp_data_b;
reg signed [C_BITWIDTH-1:0]            tmp_data_c;

assign mout = mout_temp_2;


always @( posedge clk or negedge rstn) begin
    if(!rstn) begin
        m_state <= 2'b00;
        

    end
    else begin
        case(m_state)
            STATE_IDLE: begin
                if(en && !done) begin
                    m_state <= STATE_MULT;
                end
                else begin
                     m_state <= STATE_IDLE;
                end
            end
            STATE_MULT: begin
                m_state <= STATE_Addx;
            end
            STATE_Addx: begin
                m_state <= STATE_IDLE;
            end
            
            default:;
           
        endcase
    end
end
                    

always @ (posedge clk or negedge rstn) begin
    if(!rstn) begin
        mout_temp <={OUT_BITWIDTH{1'b0}};
        
        tmp_data_a <= {A_BITWIDTH{1'b0}};
        tmp_data_b <= {B_BITWIDTH{1'b0}};
        tmp_data_c <= {C_BITWIDTH{1'b0}};

        done <= 1'b0;
    end
    else begin
        case(m_state)
            STATE_IDLE: begin
                done <=1'b0;
                mout_temp <= mout_temp;
                if(en && !done) begin
                    tmp_data_a <= data_a;
                    tmp_data_b <= data_b;
                    tmp_data_c <= data_c;
                end
            end
            
            STATE_MULT: begin
                mout_temp <= tmp_data_a * tmp_data_b;
            end
            
            STATE_Addx: begin
                mout_temp_2 <= mout_temp + tmp_data_c;

                done <= 1'b1;
            end
            
            default:;
       endcase
   end
end
endmodule
