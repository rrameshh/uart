module uart_rx #(
    // parameter BAUD_RATE = 870,
    parameter DATA_WIDTH = 8
) (
    input logic clk, reset,
    input logic rx_in,                    // Serial data input
    output logic [DATA_WIDTH-1:0] data,   // Parallel data output
    output logic valid,                   // Data valid pulse (like done)
    output logic ready,                   // Ready to receive
    output logic frame_error             // Frame error (missing stop bit)
    // output logic break_detected           // Break condition detected (low for too long)

);

    enum logic [1:0] {IDLE, START, RECEIVING, STOP} state, nextState;


    logic baud, half_baud, start_baud;
    baud_gen timing_generator(.valid(start_baud), .*);
  

    logic byte_done;
    logic prev, curr;
    always_ff @(posedge clk) begin
        prev <= curr;
        curr <= rx_in;
    end 
    
    assign start_baud = (state == IDLE) & prev & ~curr;
    logic [3:0] received;
    logic[DATA_WIDTH - 1:0] shift_reg;
    always_ff @(posedge clk) begin
          if (reset) received <= 'h0; 
          case (state) 
               RECEIVING: begin
                    if (half_baud) begin
                        received <= received + 1;
                        shift_reg <= {curr, shift_reg[DATA_WIDTH - 1:1]}; 
                        // should i use curr here??
                    end
               end    
               default: begin
                    received <= 'h0;
               end
         endcase
     end
    assign byte_done = (received == DATA_WIDTH);

    always_comb begin
        case(state)
            IDLE: nextState = (start_baud) ? START : IDLE;
            START:  nextState = (baud) ? RECEIVING : START;
            RECEIVING: nextState = (baud & byte_done) ? STOP : RECEIVING;
            STOP: nextState = (baud) ? IDLE : STOP;
            default: nextState = IDLE;
        endcase
    end
    assign ready = (state == IDLE);
    assign frame_error = ((nextState == STOP) & half_baud) & ~rx_in;
    // assign frame_error = (state == STOP) & ~rx_in;
    assign valid = ((nextState == STOP) ) & ~frame_error;
    // assign valid = ~frame_error & baud;

// LETS FIGURE THIS OUT FORRRRRRRRR REALLLLLLLLLLL

    always_ff @(posedge clk) begin
        if (reset)
            data <= 'h0;
        else if (((nextState == STOP)) & ~frame_error)
            data <= shift_reg;
    end



    always_ff @(posedge clk) begin
        if (reset)
            state <= IDLE;
        else    
            state <= nextState;
    end


endmodule


