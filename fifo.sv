`default_nettype none

module fifo #(
    parameter DEPTH = 256,
    parameter DWIDTH = 8
) (
    input  logic clk, 
    input  logic reset,
    input  logic wr, 
    input  logic re,       
    input  logic [DWIDTH-1:0] data_in,
    output logic [DWIDTH-1:0] data_out,
    output logic full,
    output logic empty,
    output logic [9:0] count  // Added count output
);

    logic wr_able, re_able;
    assign wr_able = wr & ~full;
    assign re_able = re & ~empty;

    logic [DWIDTH-1:0] fifo_mem [DEPTH];
    logic [$clog2(DEPTH)-1:0] wr_addr, re_addr;
    
    // Write logic
    always_ff @(posedge clk) begin
        if (reset) begin
            wr_addr <= '0;
        end else if (wr_able) begin
            fifo_mem[wr_addr] <= data_in;
            wr_addr <= wr_addr + 1'b1;
        end
    end

    // Read logic
    always_ff @(posedge clk) begin
        if (reset) begin
            re_addr <= '0;
        end else if (re_able) begin
            re_addr <= re_addr + 1'b1;
        end
    end
    
    // Output data (combinational read)
    assign data_out = fifo_mem[re_addr];

    // Status flags
    assign full = (wr_addr + 1'b1) == re_addr;
    assign empty = (wr_addr == re_addr);
    
    // Count calculation
    always_comb begin
        if (wr_addr >= re_addr) begin
            count = wr_addr - re_addr;
        end else begin
            // Wrapped around
            count = (DEPTH - re_addr) + wr_addr;
        end
    end

endmodule

`default_nettype wire