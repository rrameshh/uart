`default_nettype none

module configurable_uart_rx #(
    parameter DATA_WIDTH = 8
) (
    input  logic clk, 
    input  logic reset,
    input  logic rx_in,
    
    // Configuration inputs
    input  logic [15:0] baud_divisor,
    input  logic [2:0]  data_bits,      // 0=5bits, 1=6bits, 2=7bits, 3=8bits  
    input  logic [1:0]  parity_mode,    // 00=none, 01=odd, 10=even, 11=mark
    input  logic        two_stop_bits,  // 0=1 stop bit, 1=2 stop bits
    input  logic        rx_enable,      // Enable receiver
    
    output logic [DATA_WIDTH-1:0] data,
    output logic valid,
    output logic ready,
    output logic frame_error,
    output logic parity_error
);

    enum logic [2:0] {IDLE, START, RECEIVING, PARITY, STOP, STOP2} state, nextState;

    logic baud_tick, half_baud_tick;
    logic byte_done, parity_done;
    logic expected_parity, received_parity;
    logic [3:0] actual_data_bits;
    logic start_detected;
    
    // Convert encoded data bits to actual count
    assign actual_data_bits = data_bits + 4'd5;  // 0->5, 1->6, 2->7, 3->8

    // Input synchronization and edge detection
    logic prev, curr, sync1, sync2;
    always_ff @(posedge clk) begin
        if (reset) begin
            sync1 <= 1'b1;
            sync2 <= 1'b1;
            prev <= 1'b1;
            curr <= 1'b1;
        end else begin
            sync1 <= rx_in;      // First sync stage
            sync2 <= sync1;      // Second sync stage  
            prev <= curr;
            curr <= sync2;       // Use synchronized input
        end
    end 
    
    assign start_detected = (state == IDLE) && prev && ~curr;

    // Configurable baud generator
    configurable_baud_gen baud_gen (
        .clk(clk),
        .reset(reset),
        .enable(rx_enable && (state != IDLE)),
        .baud_divisor(baud_divisor),
        .restart(start_detected),  // Restart on start bit detection
        .baud_tick(baud_tick),
        .half_baud_tick(half_baud_tick)
    );
    
    assign ready = (state == IDLE) && rx_enable;

    // Bit reception counter and shift register
    logic [3:0] received;
    logic [DATA_WIDTH-1:0] shift_reg;
    
    always_ff @(posedge clk) begin
        if (reset) begin
            received <= 4'h0;
            shift_reg <= {DATA_WIDTH{1'b0}};
        end else begin
            case (state) 
                RECEIVING: begin
                    if (half_baud_tick) begin  // Sample at center of bit
                        received <= received + 1'b1;
                        shift_reg <= {curr, shift_reg[DATA_WIDTH-1:1]};
                    end
                end
                PARITY: begin
                    if (half_baud_tick) begin
                        received_parity <= curr;
                    end
                end
                default: begin
                    received <= 4'h0;
                end
            endcase
        end
    end
    
    assign byte_done = (received == actual_data_bits);

    // Calculate expected parity
    always_comb begin
        case (parity_mode)
            2'b00: expected_parity = 1'b0;                    // No parity (unused)
            2'b01: expected_parity = ^shift_reg[actual_data_bits-1:0];     // Odd parity
            2'b10: expected_parity = ~(^shift_reg[actual_data_bits-1:0]);  // Even parity
            2'b11: expected_parity = 1'b1;                    // Mark parity
        endcase
    end

    // State machine
    always_comb begin
        case(state)
            IDLE: begin
                if (start_detected && rx_enable)
                    nextState = START;
                else
                    nextState = IDLE;
            end
            
            START: begin
                if (baud_tick)
                    nextState = RECEIVING;
                else
                    nextState = START;
            end
            
            RECEIVING: begin
                if (baud_tick && byte_done) begin
                    if (parity_mode != 2'b00)  // Has parity
                        nextState = PARITY;
                    else
                        nextState = STOP;
                end else begin
                    nextState = RECEIVING;
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

    // Error detection
    logic stop_bit_error, stop2_bit_error;
    assign stop_bit_error = (state == STOP) && half_baud_tick && ~curr;
    assign stop2_bit_error = (state == STOP2) && half_baud_tick && ~curr;
    assign frame_error = stop_bit_error || stop2_bit_error;
    
    assign parity_error = (parity_mode != 2'b00) && (state == PARITY) && 
                         baud_tick && (received_parity != expected_parity);

    // Output data and valid signal
    always_ff @(posedge clk) begin
        if (reset) begin
            data <= {DATA_WIDTH{1'b0}};
            valid <= 1'b0;
        end else begin
            valid <= 1'b0;  // Default: clear valid
            
            // Generate valid pulse when frame completes successfully
            if (((state == STOP) && baud_tick && !two_stop_bits) || 
                ((state == STOP2) && baud_tick)) begin
                if (!frame_error && !parity_error) begin
                    data <= shift_reg;
                    valid <= 1'b1;
                end
            end
        end
    end

    // State register
    always_ff @(posedge clk) begin
        if (reset) begin
            state <= IDLE;
        else begin
            state <= nextState;
        end
    end

endmodule

`default_nettype wire