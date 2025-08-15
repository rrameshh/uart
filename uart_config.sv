`default_nettype none

module uart_config #(
    parameter CLOCK_FREQ = 100_000_000  // System clock frequency
) (
    input  logic        clk,
    input  logic        reset,
    
    // Configuration interface (from AXI-Lite or direct)
    input  logic        config_write,
    input  logic [31:0] config_data,
    output logic [31:0] config_reg,
    
    // Decoded configuration outputs
    output logic [15:0] baud_divisor,    // Clock divisor for baud rate
    output logic [2:0]  data_bits,       // 5-8 data bits (encoded as 0-3)
    output logic [1:0]  parity_mode,     // 00=none, 01=odd, 10=even, 11=mark
    output logic        two_stop_bits,   // 0=1 stop bit, 1=2 stop bits
    output logic        tx_enable,       // Enable transmitter
    output logic        rx_enable,       // Enable receiver
    output logic        fifo_enable,     // Enable FIFOs
    output logic [2:0]  fifo_size,       // FIFO size (0=16, 1=32, 2=64, etc.)
    
    // Status (for readback)
    output logic        config_valid     // Configuration is valid
);

    // Configuration register bit allocation:
    // [31:16] - Baud divisor (16 bits)
    // [15:13] - FIFO size (3 bits) 
    // [12]    - FIFO enable
    // [11]    - RX enable  
    // [10]    - TX enable
    // [9]     - Two stop bits
    // [8:7]   - Parity mode (2 bits)
    // [6:4]   - Data bits (3 bits, 0=5bits, 1=6bits, 2=7bits, 3=8bits)
    // [3:0]   - Reserved/unused
    
    logic [31:0] config_register;
    
    // Write configuration register
    always_ff @(posedge clk) begin
        if (reset) begin
            // Default configuration: 9600 baud, 8N1, FIFOs enabled
            config_register <= calculate_default_config();
        end
        else if (config_write) begin
            config_register <= config_data;
        end
    end
    
    // Decode configuration fields
    assign baud_divisor  = config_register[31:16];
    assign fifo_size     = config_register[15:13];
    assign fifo_enable   = config_register[12];
    assign rx_enable     = config_register[11];
    assign tx_enable     = config_register[10];
    assign two_stop_bits = config_register[9];
    assign parity_mode   = config_register[8:7];
    assign data_bits     = config_register[6:4];
    
    assign config_reg = config_register;
    
    // Validation logic
    always_comb begin
        config_valid = 1'b1;
        
        // Check baud divisor is reasonable (not too small)
        if (baud_divisor < 16) config_valid = 1'b0;
        
        // Check data bits are in valid range (5-8)
        if (data_bits > 3'b011) config_valid = 1'b0;
        
        // Check FIFO size is reasonable
        if (fifo_size > 3'b110) config_valid = 1'b0;  // Max 1024 entries
    end
    
    // Function to calculate default configuration
    function automatic [31:0] calculate_default_config();
        logic [15:0] default_baud_div;
        logic [31:0] result;
        
        // Calculate divisor for 9600 baud
        // Baud rate = CLOCK_FREQ / (baud_divisor + 1)
        // So baud_divisor = (CLOCK_FREQ / desired_baud) - 1
        default_baud_div = (CLOCK_FREQ / 9600) - 1;
        
        result = {
            default_baud_div,    // [31:16] Baud divisor for 9600
            3'b010,              // [15:13] FIFO size = 64 entries  
            1'b1,                // [12]    FIFO enable
            1'b1,                // [11]    RX enable
            1'b1,                // [10]    TX enable  
            1'b0,                // [9]     One stop bit
            2'b00,               // [8:7]   No parity
            3'b011,              // [6:4]   8 data bits
            4'b0000              // [3:0]   Reserved
        };
        
        return result;
    endfunction
    
    // Helper functions for software/testbench
    function automatic [31:0] make_config(
        input [31:0] clock_freq,
        input [31:0] baud_rate,
        input [2:0]  data_bits_val,    // 5, 6, 7, or 8
        input [1:0]  parity,           // 0=none, 1=odd, 2=even, 3=mark
        input        stop_bits_2,      // 0=1 stop, 1=2 stop
        input        enable_fifos,
        input [2:0]  fifo_sz
    );
        logic [15:0] divisor;
        logic [2:0]  encoded_data_bits;
        logic [31:0] result;
        
        divisor = (clock_freq / baud_rate) - 1;
        encoded_data_bits = data_bits_val - 5;  // Convert 5-8 to 0-3
        
        result = {
            divisor,           // [31:16]
            fifo_sz,          // [15:13] 
            enable_fifos,     // [12]
            1'b1,             // [11] RX enable
            1'b1,             // [10] TX enable
            stop_bits_2,      // [9]
            parity,           // [8:7]
            encoded_data_bits, // [6:4]
            4'b0000           // [3:0]
        };
        
        return result;
    endfunction

endmodule

// `default_nettype wire]