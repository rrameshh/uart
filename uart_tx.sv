`default_nettype none

module configurable_uart_tx #(
    parameter DATA_WIDTH = 8
) (
    input  logic clk, 
    input  logic reset, 
    input  logic valid, 
    input  logic [DATA_WIDTH-1:0] data, 
    
    // Configuration inputs
    input  logic [15:0] baud_divisor,
    input  logic [2:0]  data_bits,      // 0=5bits, 1=6bits, 2=7bits, 3=8bits
    input  logic [1:0]  parity_mode,    // 00=none, 01=odd, 10=even, 11=mark
    input  logic        two_stop_bits,  // 0=1 stop bit, 1=2 stop bits
    input  logic        tx_enable,      // Enable transmitter
    
    output logic ready, 
    output logic done, 
    output logic out
);

    enum logic [2:0] {IDLE, START, TRANSMIT, PARITY, STOP, STOP2} state, nextState;

    logic baud_tick, half_baud_tick;
    logic byte_done, parity_done, stop_done;
    logic parity_bit;
    logic [3:0] actual_data_bits;
    
    // Convert encoded data bits to actual count
    assign actual_data_bits = data_bits + 4'd5;  // 0->5, 1->6, 2->7, 3->8

    // Configurable baud generator
    configurable_baud_gen baud_gen (
        .clk(clk),
        .reset(reset),
        .enable(tx_enable && (state != IDLE)),
        .baud_divisor(baud_divisor),
        .restart(valid && ready),  // Restart on new transmission
        .baud_tick(baud_tick),
        .half_baud_tick(half_baud_tick)
    );
    
    assign ready = (state == IDLE) && tx_enable;

    // Calculate parity bit
    always_comb begin
        case (parity_mode)
            2'b00: parity_bit = 1'b0;                    // No parity (unused)
            2'b01: parity_bit = ^data[actual_data_bits-1:0];     // Odd parity
            2'b10: parity_bit = ~(^data[actual_data_bits-1:0]);  // Even parity  
            2'b11: parity_bit = 1'b1;                    // Mark parity
        endcase
    end

    // State machine
    always_comb begin
        case (state) 
            IDLE: begin
                if (valid && ready) 
                    nextState = START;
                else 
                    nextState = IDLE;
            end
            
            START: begin
                if (baud_tick)
                    nextState = TRANSMIT;
                else
                    nextState = START;
            end
            
            TRANSMIT: begin
                if (byte_done && baud_tick) begin
                    if (parity_mode != 2'b00)  // Has parity
                        nextState = PARITY;
                    else
                        nextState = STOP;
                end else begin
                    nextState = TRANSMIT;
                end
            end
            
            PARITY: begin
                if (baud_tick)
                    nextState = STOP;
                else
                    nextState = PARITY;
            end
            
            STOP: begin
                if (baud_tick) begin
                    if (two_stop_bits)
                        nextState = STOP2;
                    else
                        nextState = IDLE;
                end else begin
                    nextState = STOP;
                end
            end
            
            STOP2: begin
                if (baud_tick)
                    nextState = IDLE;
                else
                    nextState = STOP2;
            end
            
            default: nextState = IDLE;
        endcase
    end

    assign done = ((state == STOP) && baud_tick && !two_stop_bits) || 
                  ((state == STOP2) && baud_tick);

    // Bit transmission counter
    logic [3:0] transmitted;
    always_ff @(posedge clk) begin
        if (reset) begin
            transmitted <= 4'h0;
        end else begin
            case (state) 
                IDLE, START: transmitted <= 4'h0;
                TRANSMIT: begin
                    if (baud_tick)
                        transmitted <= transmitted + 1'b1;
                end    
                default: transmitted <= 4'h0;
            endcase
        end
    end
    
    assign byte_done = (transmitted == actual_data_bits);

    // Output logic
    always_ff @(posedge clk) begin
        if (reset) begin
            out <= 1'b1;
        end else if (!tx_enable) begin
            out <= 1'b1;  // Idle high when disabled
        end else begin
            case (state) 
                IDLE: out <= (nextState == START) ? 1'b0 : 1'b1;
                START: out <= 1'b0;  // Start bit
                TRANSMIT: out <= lsb;
                PARITY: out <= parity_bit;
                STOP, STOP2: out <= 1'b1;  // Stop bit(s)
                default: out <= 1'b1;
            endcase
        end
    end
     
    // Data shift register
    logic [DATA_WIDTH-1:0] temp;
    always_ff @(posedge clk) begin
        if (reset) begin
            temp <= {DATA_WIDTH{1'b0}};
        end else if (valid && ready) begin
            temp <= data;
        end else if (baud_tick && state == TRANSMIT) begin
            temp <= {1'b0, temp[DATA_WIDTH-1:1]};  // Shift right, fill with 0
        end
    end

    logic lsb;
    assign lsb = temp[0];

    // State register
    always_ff @(posedge clk) begin
        if (reset) begin
            state <= IDLE;
        end else begin
            state <= nextState;  
        end
    end

endmodule

`default_nettype wire