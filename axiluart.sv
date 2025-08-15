`default_nettype none

module axiluart #(
    parameter CLOCK_FREQ = 100_000_000,
    parameter FIFO_DEPTH = 256,
    parameter C_S_AXI_DATA_WIDTH = 32,
    parameter C_S_AXI_ADDR_WIDTH = 8
) (
    // Global signals
    input  logic                            S_AXI_ACLK,
    input  logic                            S_AXI_ARESETN,
    
    // AXI-Lite Write Address Channel
    input  logic [C_S_AXI_ADDR_WIDTH-1:0]  S_AXI_AWADDR,
    input  logic [2:0]                      S_AXI_AWPROT,
    input  logic                            S_AXI_AWVALID,
    output logic                            S_AXI_AWREADY,
    
    // AXI-Lite Write Data Channel
    input  logic [C_S_AXI_DATA_WIDTH-1:0]  S_AXI_WDATA,
    input  logic [(C_S_AXI_DATA_WIDTH/8)-1:0] S_AXI_WSTRB,
    input  logic                            S_AXI_WVALID,
    output logic                            S_AXI_WREADY,
    
    // AXI-Lite Write Response Channel
    output logic [1:0]                      S_AXI_BRESP,
    output logic                            S_AXI_BVALID,
    input  logic                            S_AXI_BREADY,
    
    // AXI-Lite Read Address Channel
    input  logic [C_S_AXI_ADDR_WIDTH-1:0]  S_AXI_ARADDR,
    input  logic [2:0]                      S_AXI_ARPROT,
    input  logic                            S_AXI_ARVALID,
    output logic                            S_AXI_ARREADY,
    
    // AXI-Lite Read Data Channel
    output logic [C_S_AXI_DATA_WIDTH-1:0]  S_AXI_RDATA,
    output logic [1:0]                      S_AXI_RRESP,
    output logic                            S_AXI_RVALID,
    input  logic                            S_AXI_RREADY,
    
    // UART physical interface
    input  logic                            uart_rx,
    output logic                            uart_tx,
    
    // Optional flow control
    input  logic                            cts_n,
    output logic                            rts_n,
    
    // Interrupt
    output logic                            interrupt
);

    // AXI-Lite state machines
    typedef enum logic [1:0] {
        IDLE = 2'b00,
        RDATA = 2'b01,
        RWAIT = 2'b10
    } axi_read_state_t;
    
    typedef enum logic [1:0] {
        WIDLE = 2'b00,
        WWAIT = 2'b01,
        WRESP = 2'b10
    } axi_write_state_t;
    
    axi_read_state_t  axi_read_state;
    axi_write_state_t axi_write_state;
    
    // Internal signals
    logic        reg_write;
    logic        reg_read;
    logic [3:0]  reg_addr;
    logic [31:0] reg_wdata;
    logic [31:0] reg_rdata;
    logic        reg_ready;
    
    // Address decode
    logic [3:0] awaddr_reg, araddr_reg;
    assign awaddr_reg = S_AXI_AWADDR[5:2];  // Word address (byte addr / 4)
    assign araddr_reg = S_AXI_ARADDR[5:2];  // Word address (byte addr / 4)
    
    // AXI-Lite Write State Machine
    always_ff @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            axi_write_state <= WIDLE;
            S_AXI_AWREADY <= 1'b0;
            S_AXI_WREADY <= 1'b0;
            S_AXI_BVALID <= 1'b0;
            S_AXI_BRESP <= 2'b00;
            reg_write <= 1'b0;
            reg_addr <= 4'h0;
            reg_wdata <= 32'h0;
        end else begin
            reg_write <= 1'b0;  // Default: clear write pulse
            
            case (axi_write_state)
                WIDLE: begin
                    S_AXI_AWREADY <= 1'b1;
                    S_AXI_WREADY <= 1'b1;
                    S_AXI_BVALID <= 1'b0;
                    
                    if (S_AXI_AWVALID && S_AXI_WVALID) begin
                        // Both address and data are valid
                        S_AXI_AWREADY <= 1'b0;
                        S_AXI_WREADY <= 1'b0;
                        reg_addr <= awaddr_reg;
                        reg_wdata <= S_AXI_WDATA;
                        reg_write <= 1'b1;
                        axi_write_state <= WWAIT;
                    end
                end
                
                WWAIT: begin
                    if (reg_ready) begin
                        S_AXI_BVALID <= 1'b1;
                        S_AXI_BRESP <= 2'b00;  // OKAY response
                        axi_write_state <= WRESP;
                    end
                end
                
                WRESP: begin
                    if (S_AXI_BREADY) begin
                        S_AXI_BVALID <= 1'b0;
                        axi_write_state <= WIDLE;
                    end
                end
                
                default: axi_write_state <= WIDLE;
            endcase
        end
    end
    
    // AXI-Lite Read State Machine
    always_ff @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            axi_read_state <= IDLE;
            S_AXI_ARREADY <= 1'b0;
            S_AXI_RVALID <= 1'b0;
            S_AXI_RDATA <= 32'h0;
            S_AXI_RRESP <= 2'b00;
            reg_read <= 1'b0;
        end else begin
            reg_read <= 1'b0;  // Default: clear read pulse
            
            case (axi_read_state)
                IDLE: begin
                    S_AXI_ARREADY <= 1'b1;
                    S_AXI_RVALID <= 1'b0;
                    
                    if (S_AXI_ARVALID) begin
                        S_AXI_ARREADY <= 1'b0;
                        reg_addr <= araddr_reg;
                        reg_read <= 1'b1;
                        axi_read_state <= RDATA;
                    end
                end
                
                RDATA: begin
                    if (reg_ready) begin
                        S_AXI_RDATA <= reg_rdata;
                        S_AXI_RVALID <= 1'b1;
                        S_AXI_RRESP <= 2'b00;  // OKAY response
                        axi_read_state <= RWAIT;
                    end
                end
                
                RWAIT: begin
                    if (S_AXI_RREADY) begin
                        S_AXI_RVALID <= 1'b0;
                        axi_read_state <= IDLE;
                    end
                end
                
                default: axi_read_state <= IDLE;
            endcase
        end
    end
    
    // UART Controller instance
    uart_controller #(
        .CLOCK_FREQ(CLOCK_FREQ),
        .FIFO_DEPTH(FIFO_DEPTH)
    ) uart_core (
        .clk(S_AXI_ACLK),
        .reset(~S_AXI_ARESETN),
        .reg_write(reg_write),
        .reg_read(reg_read),
        .reg_addr(reg_addr),
        .reg_wdata(reg_wdata),
        .reg_rdata(reg_rdata),
        .reg_ready(reg_ready),
        .uart_rx(uart_rx),
        .uart_tx(uart_tx),
        .interrupt(interrupt)
    );
    
    // Flow control (simple implementation)
    assign rts_n = 1'b0;  // Always ready to receive (can be enhanced)

endmodule

`default_nettype wire