`timescale 1ns / 1ps

module sample_controller(
input clk,                  // input clock
input rstn,                 // negative reset flag
input r_valid,              // a flag indicating that the testbench is sending data
input [31:0] in_data,       // the data being sent by the testbench
output reg [31:0] out_data, // the final output result of the FC computation
output reg t_valid          // a flag indicating that the transaction has finished
);
localparam      

// BRAM operating state
STATE_IDLE        = 3'd0,
STATE_DATA_RECEIVE  = 3'd1, // STATE_DATA_RECEIVE: Receive data from testbench and write data to BRAM.
STATE_INPUT_SET   = 3'd2,   // STATE_INPUT_SET: Read input from BRAM and set input
STATE_WEIGHT_SET  = 3'd3,   // STATE_WEIGHT_SET: Read weight from BRAM and set weight
STATE_BIAS_SET    = 3'd4,   // STATE_BIAS_SET: Read bias from BRAM and set bias

// MAC operating state
// STATE_IDLE         = 3'd0,
STATE_ACCUMULATE  = 3'd1, // STATE_ACCUMULATE: Accumulate productions of weight and value for one output.
STATE_BIAS_ADD    = 3'd2, // STATE_BIAS_ADD: Add bias for one output.
STATE_DATA_SEND   = 3'd3, // STATE_DATA_SEND: Send result data to testbench.

/////////////////////* Not allowed to change */////////////////////
// FC layer parameters
INPUT_SIZE = 8,                       // in bytes
OUTPUT_SIZE = 4,                      // in bytes
BYTE_SIZE = 8,                        // in bits
BIAS_SIZE = OUTPUT_SIZE,              // in bytes
WEIGHT_SIZE = INPUT_SIZE*OUTPUT_SIZE, // in bytes

// BRAM addresses
INPUT_START_ADDRESS = 4'b0000,
WEIGHT_START_ADDRESS = 4'b0100,
BIAS_START_ADDRESS = 4'b1110,
DUMP_ADDRESS = 4'b1111;        // a address used when performing invalid transactions to BRAM
///////////////////////////////////////////////////////////////////
  

/////////////////////* Not allowed to change */////////////////////  
//for DATA
reg [INPUT_SIZE*BYTE_SIZE-1:0] input_data;       // input feature size = 8 (each 8-bits)
reg [INPUT_SIZE*BYTE_SIZE-1:0] weight;           // weight size = 8 * 4 (each 8-bits). However just set 64-bits(8bytes) at one time.
reg [INPUT_SIZE*BYTE_SIZE-1:0] weight_buff;      // weight size = 8 * 4 (each 8-bits). However just set 64-bits(8bytes) at one time.
reg [BIAS_SIZE*BYTE_SIZE-1:0]  bias;             // bias size = 4 (each 8-bits)
///////////////////////////////////////////////////////////////////

// The BRAM can read / write 32 bits (4B) per cycle
// The BRAM read latency is 2 cycles (you receive your data after 2 cycles)

// For BRAM Operation
reg [2:0]   b_state;            // a register to keep track of the BRAM state
reg [11:0]  addr;               // address to r/w BRAM
reg [31:0]  din;                // data which will be written to the BRAM
wire [31:0] dout;               // data read from the BRAM
reg         bram_en;            // enable BRAM operations
reg         write_en;           // enable BRAM write operations  (bram_en : 1, write_en : 0 -> read / bram_en : 1, write_en : 1 -> write)
reg [1:0]   delay;              // a counter to keep track of BRAM latency (BRAM read latency is 2 cycles)
reg         b_write_done;       // a flag to indicate whether the data from the testbench is all written to the BRAM
reg         input_set_done;     // a flag to indicate whether the "input_data" register recieved data from BRAM and is ready for use by the MAC unit
reg         weight_set_done;    // a flag to indicate whether the "weight_buff" register recieved data from BRAM and is ready to be moved to the "weight" register
reg         bias_set_done;      // a flag to indicate whether the "bias" register recieved data from BRAM and is ready for use by the MAC unit
reg  [15:0] bram_counter;       // a counter to keep track of the number of data read by the BRAM 
reg         bram_oreg_set_done; // when the BRAM output registers ("input_data", "weight_buff", "bias") are all set with proper data
reg [3:0]   weight_counter;     // a counter to keep track of the number of weights columns processed

// For FC Calculation Operation with MAC module
reg [2:0]   c_state;            // a register to keep track of the MAC unit state
reg         mac_en;             // enable MAC operations
wire [7:0]  data_a;             // input to the MAC unit
wire [7:0]  data_b;             // input to the MAC unit
wire [17:0] data_c;             // input to the MAC unit
wire        mac_done;           // a flag indicating that the MAC operation finished
reg [3:0]   element_counter;    // a counter to keep track of the number of elements that has finished the MAC operation for weights and input corresponding to a single output element
reg [18:0]  partial_sum;        // a register keeping track of the intermediate sum of inner products
wire [18:0] result_accurate;    // the final result of a output element w/o quantization
wire [7:0]  result_quantized;   // the quantized value of "result_accurate"
reg         mac_ireg_set_done;  // a flag indicating that the input to the MAC unit is all set, and the BRAM can start sending weights to the "weight_buff"
reg [3:0]   out_counter;        // the number of output elements that are finished processing


// MAC unit
mac #(.A_BITWIDTH(8), .OUT_BITWIDTH(19))
  u_acc_sum (
    .clk(clk),
    .en(mac_en),
    .rstn(rstn),
    .data_a(data_a), 
    .data_b(data_b),
    .data_c(data_c),
    .mout(result_accurate),
    .done(mac_done)
);

// BRAM (IP block)
sram_32x16 u_sram_32x16(
    .addra(addr),
    .clka(clk),
    .dina(din),
    .douta(dout),
    .ena(bram_en),
    .wea(write_en)
);


///////////////////////////////////////////
//////////* For BRAM operating  *//////////
///////////////////////////////////////////

always @(posedge clk or negedge rstn) begin

  // when the negative reset sign is not set : reset
  if(!rstn) begin
    bram_en <= 1'b0;
    write_en <= 1'b0;
    addr <= DUMP_ADDRESS;
    din <= 8'd0;
    input_set_done <= 1'b0;
    weight_set_done <= 1'b0;
    bias_set_done <= 1'b0;
    b_write_done <= 1'b0;
    delay <= 2'b00;
    bram_counter <= 16'h0000;
    input_data <= {INPUT_SIZE*BYTE_SIZE{1'b0}};
    bias <= {BIAS_SIZE*BYTE_SIZE{1'b0}};
    weight_buff <= {INPUT_SIZE*BYTE_SIZE{1'b0}};
    b_state <= STATE_IDLE;
  end
  else begin
    case(b_state)
    
    // when the BRAM is idle
    STATE_IDLE: begin
      bram_en <= 1'b0;
      write_en <= 1'b0;
      b_write_done <= 1'b0;
      bram_counter <= 16'h0000;
      input_set_done <= 1'b0;
      weight_set_done <= 1'b0;
      bias_set_done <= 1'b0;
      bram_oreg_set_done <= 1'b0;
      weight_counter <= 4'd0;
      
      // change the state the start receiving data
      if(r_valid) begin
        b_state <= STATE_DATA_RECEIVE;
      end
    end
    
    /////////////////////* Not allowed to change except state */////////////////////
    // Receive data from testbench and write data to the BRAM.
    STATE_DATA_RECEIVE: begin
      if(b_write_done) begin
        bram_en <= 1'b0;
        write_en <= 1'b0;
        addr <= DUMP_ADDRESS;
        din <= 32'd0;
        b_write_done <= 1'b0;
        bram_counter <= 16'h0000;
        b_state <= STATE_INPUT_SET;
      end
      else begin
        if(r_valid) begin
          // enable BRAM write
          bram_en <= 1'b1;
          write_en <= 1'b1;

          // store to BRAM
          din <= in_data;

          // increment the BRAM counter
          bram_counter <= bram_counter + 16'h0001;

          if(bram_counter == 0) begin // receive input by (input_size/4) times considering 32-bit(4B) data write.
            addr <= INPUT_START_ADDRESS;
          end
          // received all the input data
          else if(bram_counter == INPUT_SIZE[9:2]) begin  // receive weight by (weight_size/4) times considering 32-bit(4B) data write.
            addr <= WEIGHT_START_ADDRESS;
          end
          // received all the weight data
          else if(bram_counter == WEIGHT_SIZE[9:2] + INPUT_SIZE[9:2]) begin // receive bias by (bias_size/4) times considering 32-bit(4B) data write.
            addr <= BIAS_START_ADDRESS;
          end
          // received all the bias data
          else if(bram_counter == BIAS_SIZE[9:2] + WEIGHT_SIZE[9:2] + INPUT_SIZE[9:2]) begin  // receive done
            b_write_done <= 1'b1;
          end
          // write to the next address
          else begin
            addr <= addr + 4'd1;
          end
        end
        else begin
          bram_en <= 1'b0;
          write_en <= 1'b0;
          addr <= DUMP_ADDRESS;
          din <= 32'd0;
          b_write_done <= 1'b1;
        end
      end
    end
    /////////////////////////////////////////////////////////////////// 
    
    // Read from BRAM and set input
    STATE_INPUT_SET: begin
      if(input_set_done) begin    // Setting input is done and move to STATE_BIAS_SET
        bram_en <= 1'b0;
        write_en <= 1'b0;
        addr <= DUMP_ADDRESS;

        input_set_done <= 1'b0;
        delay <= 2'b00;
        bram_counter <= 1'b0;
        b_state <= STATE_BIAS_SET;
      end
      else begin
        // set BRAM read bits
        bram_en <= 1'b1;
        write_en <= 1'b0;

        // set the address to read from BRAM
        addr <= INPUT_START_ADDRESS + bram_counter;

        // increment the BRAM counter
        bram_counter <= bram_counter + 16'd1;

        // check if the BRAM read latency is fullfilled
        if(delay < 2) begin
          delay <= delay + 1'b1;
          input_set_done <= 1'b0;
        end
        else begin
          // if the "input_data" is not fully set
          if(bram_counter < INPUT_SIZE[9:2] + 2) begin  // Read input (input_size/4) times considering 32-bits data write.
            input_data[32*(bram_counter-2)+:32] <= dout;
          end
          // "input_data" is set
          else begin
            input_set_done <= 1'b1;
          end
        end
      end
    end

    // Read from BRAM and set bias
    STATE_BIAS_SET: begin
      // ============ TODO  : Part 2 : Writing data into BRAM ================
      // HINT : It is VERY similar to the STATE_INPUT_SET code

      // =====================================================================
    end
    
    
    // read from BRAM and set weight(8-bytes)
    // when setting the weight(8-bytes) is done, set the bram_oreg_set_done as 1.
    // when mac_ireg_set_done is set(1), restart STATE_WEIGHT_SET to start reading the next weights
    // if weight_counter is above the output size, it means all calculation for this FC layer is done. So, move to STATE_IDLE
    
    STATE_WEIGHT_SET: begin
      if(weight_counter >= OUTPUT_SIZE) begin   //
        bram_en <= 1'b0;
        write_en <= 1'b0;
        addr <= DUMP_ADDRESS;
        delay <= 2'b00;
        bram_oreg_set_done <= 1'b0;
        bram_counter <= 1'b0;
        weight_counter <= 4'd0;
        mac_ireg_set_done <= 1'b0;
        weight_set_done <= 1'b0;
        b_state <= STATE_IDLE;
      end
      // if the "mac_ireg_set_done" is set
      else if(mac_ireg_set_done) begin
        // increment the weight counter
        weight_counter <= weight_counter + 4'd1;

        // initialize registers
        delay <= 2'b00;
        bram_oreg_set_done <= 1'b0;
        bram_counter <= 1'b0;
        mac_ireg_set_done <= 1'b0;
        weight_set_done <= 1'b0;
      end
      // the MAC starts in the next cycle after bram_oreg_set_done is set
      // also, weights are moved from "weight_buff" to "weight"
      else if(weight_set_done) begin
        bram_oreg_set_done <= 1'b1; //finish storing temp weight, move weight buffer values to weight
      end
      else begin
        // set BRAM read 
        bram_en <= 1'b1;
        write_en <= 1'b0;

        // set BRAM read address (each weight row(8B) takes 2 BRAM entries(4B))
        addr <= WEIGHT_START_ADDRESS + 2 * weight_counter + bram_counter; 

        // increment BRAM counter
        bram_counter <= bram_counter + 16'd1;

        // check if the BRAM read latency is fullfilled
        if(delay < 2) begin
          delay <= delay + 1'b1;
          weight_set_done <= 1'b0;
        end
        else begin
          // "weight_buff" is not fully set
          if(bram_counter < WEIGHT_SIZE[9:4]+2) begin  // **Read weight (weight_size(=8*4))/4/4) times considering 32-bits data write.
            weight_buff[32*(bram_counter-2)+:32] <= dout;
          end
          // "weight_buff is set
          else begin
            weight_set_done <= 1'b1;
          end
        end
      end
    end 
        
    default: begin
      bram_en <= 1'b0;
      write_en <= 1'b0;
      addr <= DUMP_ADDRESS;
      b_write_done <= 1'b0;
      input_set_done <= 1'b0;
      weight_set_done <= 1'b0;
      bias_set_done <= 1'b0;
    end
  endcase
end
end


///////////////////////////////////////////
/////* For FC Calculation operating  */////
///////////////////////////////////////////

////// Control path
always @(posedge clk or negedge rstn) begin
  if(!rstn) begin 
    c_state <= STATE_IDLE;
    mac_en <= 1'b0;
    t_valid <= 1'b0;
    element_counter <= 4'd0;
    out_counter <= 4'd0;
  end
  else begin
    case(c_state)      
      STATE_IDLE: begin 
        t_valid <= 1'b0;
        if(bram_oreg_set_done) begin
          c_state <= STATE_ACCUMULATE;
          mac_en <= 1'b1;
        end
        else begin
          c_state <= STATE_IDLE;
        end
      end
              
      // Accumulate productions of weight and value for one output.
      STATE_ACCUMULATE: begin
      if(mac_done) begin
        // all elements of the input finished
        if(element_counter >= INPUT_SIZE-1) begin
          c_state <= STATE_BIAS_ADD;
          element_counter <= 4'd0;
        end
        else begin
          // another vector element mac finished
          element_counter <= element_counter + 4'd1;
        end
      end
      end

      // Add bias for one output.
      STATE_BIAS_ADD: begin
      if(mac_done) begin
        // all output finished calculation
        if (out_counter >= OUTPUT_SIZE-1) begin
          c_state <= STATE_DATA_SEND;
          out_counter <= 4'd0;
          mac_en <= 1'b0;
        end
        // another output element computation finished
        else begin
          c_state <= STATE_IDLE;
          mac_en <= 1'b0;
          out_counter <= out_counter + 1;
        end
      end
      end

      // Send result data back to the testbench.
      STATE_DATA_SEND: begin
        if(t_valid) begin
          t_valid <= 1'b0;
          c_state <= STATE_IDLE;
          mac_en <= 1'b0;
        end
        else begin
          t_valid <= 1'b1;
          c_state <= STATE_DATA_SEND;
        end
      end
      
      default: begin
      end
    endcase
  end
end

////// Data path
// out_data
always @(posedge clk or negedge rstn) begin
  if(!rstn) begin
    out_data <= 32'd0;
  end
  else begin
    // insert the quantized result to the correct position of "out_data"
    if(c_state == STATE_BIAS_ADD && mac_done) begin
      out_data[8*(out_counter)+:8] <= result_quantized; 
    end
  end
end

// partial_sum
always @(posedge clk or negedge rstn) begin
  if(!rstn) begin
    partial_sum <= 19'd0;
  end
  else begin
    // save the intermediate MAC result in "partial_sum"
    partial_sum <= result_accurate;
  end
end

// weight, mac_ireg_set_done
always @(posedge clk or negedge rstn) begin
  if(!rstn) begin
    weight <= {WEIGHT_SIZE*BYTE_SIZE{1'b0}};
    mac_ireg_set_done <= 1'b0;
  end
  else begin
    // when the BRAM output registers "input_data", "bias", "weight_buff" is
    // set, copy "weight_buff" to "weight" so that the MAC can read the values
    // and perform computation
    // this is necessary to read the "weight" values while filling the
    // "weight_buff" from BRAM in parallel
    if(c_state == STATE_IDLE && bram_oreg_set_done) begin
      weight <= weight_buff;
      mac_ireg_set_done <= 1'b1;
    end
  end
end

// ======================= TODO  : Part 3 : MAC operations ===================
// STATE_ACCUMULATE : mac out = input * weight + partial_sum
// STATE_BIAS_ADD : mac out = bias * 1 + partial_sum
assign data_a = 
assign data_b = 
assign data_c = 
// ===========================================================================


// ======================= TODO  : Part 4 : Quantization =====================
// perform computation
// copy the sign bit
assign result_quantized[7] = 

// check for overflow
// - 2's complement representation
// - 01111111 : maximum positive value
// - 10000000 : negative value with the maximum absolute value
assign result_quantized[6:0] = 
// ===========================================================================


endmodule
