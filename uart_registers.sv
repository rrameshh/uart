`default_nettype none

module uart_registers (
    input  logic        clk,
    input  logic        reset,
    
    // Simple register interface (will connect to AXI-Lite later)
    input  logic        reg_write,
    input  logic        reg_read,
    input  logic [3:0]  reg_addr,     // Word address (4-bit = 16 registers max)
    input  logic [31:0] reg_wdata,
    output logic [31:0] reg_rdata,
    output logic        reg_ready,
    
    // Configuration interface
    output logic        config_write,
    output logic [31:0] config_data,
    input  logic [31:0] config_reg,
    input  logic        config_valid,
    
    // Control signals
    output logic        tx_fifo_reset,
    output logic        rx_fifo_reset,
    output logic        global_reset,
    
    // Status inputs
    input  logic        tx_ready,
    input  logic        tx_busy,
    input  logic        rx_valid,
    input  logic        rx_frame_error,
    input  logic        tx_fifo_full,
    input  logic        tx_fifo_empty,
    input  logic        rx_fifo_full,
    input  logic        rx_fifo_empty,
    input  logic [9:0]  tx_fifo_count,
    input  logic [9:0]  rx_fifo_count,
    
    // Data interfaces
    output logic        tx_fifo_write,
    output logic [7:0]  tx_fifo_data,
    input  logic        rx_fifo_read,
    input  logic [7:0]  rx_fifo_data,
    
    // Interrupt
    output logic        interrupt
);

    // Register map:
    // 0x00 (0): CONFIG    - Configuration register
    // 0x04 (1): CONTROL   - Control register  
    // 0x08 (2): STATUS    - Status register (read-only)
    // 0x0C (3): TX_DATA   - Transmit data register
    // 0x10 (4): RX_DATA   - Receive data register (read-only)
    // 0x14 (5): FIFO_CTRL - FIFO control register
    // 0x18 (6): INT_CTRL  - Interrupt control register
    // 0x1C (7): INT_STAT  - Interrupt status register
    
    localparam [3:0] 
        ADDR_CONFIG    = 4'h0,
        ADDR_CONTROL   = 4'h1, 
        ADDR_STATUS    = 4'h2,
        ADDR_TX_DATA   = 4'h3,
        ADDR_RX_DATA   = 4'h4,
        ADDR_FIFO_CTRL = 4'h5,
        ADDR_INT_CTRL  = 4'h6,
        ADDR_INT_STAT  = 4'h7;
    
    // Internal registers
    logic [31:0] control_reg;
    logic [31:0] fifo_ctrl_reg;
    logic [31:0] int_ctrl_reg;
    logic [31:0] int_stat_reg;
    
    // Control register bit definitions
    assign global_reset    = control_reg[0];
    assign tx_fifo_reset   = control_reg[1];
    assign rx_fifo_reset   = control_reg[2];
    
    // Always ready for simple interface
    assign reg_ready = 1'b1;
    
    // Write logic
    always_ff @(posedge clk) begin
        if (reset) begin
            control_reg   <= 32'h0;
            fifo_ctrl_reg <= 32'h0;
            int_ctrl_reg  <= 32'h0;
            config_write  <= 1'b0;
            tx_fifo_write <= 1'b0;
        end
        else begin
            // Clear single-cycle pulses
            config_write  <= 1'b0;
            tx_fifo_write <= 1'b0;
            
            if (reg_write) begin
                case (reg_addr)
                    ADDR_CONFIG: begin
                        config_data  <= reg_wdata;
                        config_write <= 1'b1;
                    end
                    
                    ADDR_CONTROL: begin
                        control_reg <= reg_wdata;
                    end
                    
                    ADDR_TX_DATA: begin
                        tx_fifo_data  <= reg_wdata[7:0];
                        tx_fifo_write <= 1'b1;
                    end
                    
                    ADDR_FIFO_CTRL: begin
                        fifo_ctrl_reg <= reg_wdata;
                    end
                    
                    ADDR_INT_CTRL: begin
                        int_ctrl_reg <= reg_wdata;
                    end
                    
                    // Clear interrupt status bits that are written as 1
                    ADDR_INT_STAT: begin
                        int_stat_reg <= int_stat_reg & ~reg_wdata;
                    end
                    
                    default: begin
                        // Read-only or undefined registers
                    end
                endcase
            end
        end
    end
    
    // Read logic
    always_comb begin
        reg_rdata = 32'h0;
        
        if (reg_read) begin
            case (reg_addr)
                ADDR_CONFIG: begin
                    reg_rdata = config_reg;
                end
                
                ADDR_CONTROL: begin
                    reg_rdata = control_reg;
                end
                
                ADDR_STATUS: begin
                    reg_rdata = {
                        12'h0,              // [31:20] Reserved
                        rx_fifo_count,      // [19:10] RX FIFO count
                        tx_fifo_count,      // [9:0]   TX FIFO count
                        6'h0,               // [9:4]   Reserved  
                        rx_frame_error,     // [3]     RX frame error
                        rx_fifo_empty,      // [2]     RX FIFO empty
                        tx_fifo_full,       // [1]     TX FIFO full
                        tx_busy             // [0]     TX busy
                    };
                end
                
                ADDR_TX_DATA: begin
                    // Reading TX register gives FIFO status
                    reg_rdata = {
                        22'h0,              // [31:10] Reserved
                        tx_fifo_count,      // [9:0]   TX FIFO count
                        6'h0,               // [9:6]   Reserved
                        tx_fifo_full,       // [1]     TX FIFO full
                        tx_fifo_empty       // [0]     TX FIFO empty
                    };
                end
                
                ADDR_RX_DATA: begin
                    reg_rdata = {
                        14'h0,              // [31:18] Reserved
                        rx_frame_error,     // [17]    Frame error for this byte
                        rx_fifo_empty,      // [16]    RX FIFO empty
                        rx_fifo_data        // [7:0]   RX data
                    };
                end
                
                ADDR_FIFO_CTRL: begin
                    reg_rdata = fifo_ctrl_reg;
                end
                
                ADDR_INT_CTRL: begin
                    reg_rdata = int_ctrl_reg;
                end
                
                ADDR_INT_STAT: begin
                    reg_rdata = int_stat_reg;
                end
                
                default: begin
                    reg_rdata = 32'hDEADBEEF;  // Debug pattern for undefined reads
                end
            endcase
        end
    end
    
    // Interrupt status generation
    always_ff @(posedge clk) begin
        if (reset) begin
            int_stat_reg <= 32'h0;
        end
        else begin
            // Set interrupt status bits on events
            if (rx_valid && !rx_fifo_full) begin
                int_stat_reg[0] <= 1'b1;  // RX data available
            end
            
            if (tx_fifo_empty && int_ctrl_reg[1]) begin
                int_stat_reg[1] <= 1'b1;  // TX FIFO empty
            end
            
            if (rx_frame_error) begin
                int_stat_reg[2] <= 1'b1;  // Frame error
            end
            
            if (rx_fifo_full) begin
                int_stat_reg[3] <= 1'b1;  // RX FIFO overflow
            end
        end
    end
    
    // Generate interrupt output
    assign interrupt = |(int_stat_reg & int_ctrl_reg);

endmodule

`default_nettype wire