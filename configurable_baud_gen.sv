`default_nettype none

module configurable_baud_gen (
    input  logic        clk,
    input  logic        reset,
    input  logic        enable,        // Enable baud generation
    input  logic [15:0] baud_divisor,  // From configuration register
    input  logic        restart,       // Restart/sync the counter
    
    output logic        baud_tick,     // Full baud period tick
    output logic        half_baud_tick // Half baud period tick (for sampling)
);

    logic [15:0] counter;
    logic [15:0] half_divisor;
    
    // Calculate half divisor for half_baud_tick
    assign half_divisor = {1'b0, baud_divisor[15:1]};  // Divide by 2
    
    always_ff @(posedge clk) begin
        if (reset || restart) begin
            counter <= baud_divisor;
        end
        else if (enable) begin
            if (counter == 16'h0) begin
                counter <= baud_divisor;
            end
            else begin
                counter <= counter - 1'b1;
            end
        end
        // If not enabled, counter holds its value
    end
    
    // Generate ticks
    assign baud_tick = enable && (counter == 16'h0);
    assign half_baud_tick = enable && (counter == half_divisor);

endmodule

`default_nettype wire