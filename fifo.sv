module fifo #(
    DEPTH = 8,
    DWIDTH = 16

) (
    input logic clk, reset,
    input logic wr, re,       
    input logic [DATA_WIDTH-1:0] data_in     
    output logic [DATA_WIDTH-1:0] data_out
);

    logic full, empty;
    logic wr_able, re_able;
    assign wr_able = wr & ~full;
    assign re_able = re & ~empty;

    logic [DWIDTH-1 : 0] fifo[DEPTH];

    logic [$clog2(DEPTH)-1:0] wr_addr, re_addr;
    

    always_ff @(posedge clk) begin
        if (reset) 
            wr_addr <= 'h0;
        else if (wr_able) begin
            fifo[wr_addr] <= data_in;
            wr_addr <= wr_addr + 1;
        end
    end

    always_ff @(posedge clk) begin
        if (reset) 
            re_addr <= 'h0;
        else if (re_able) begin
            data_out <= fifo[re_addr];
            re_addr <= re_addr + 1;
        end
    end

    assign full = (wr_addr + 1) == re_addr;
    assign empty = (wr_addr == re_addr);


    // assign data_out = fifo[re_addr];

endmodule


