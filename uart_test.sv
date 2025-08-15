`default_nettype none

module config_test;

    logic clk = 0;
    logic reset = 1;
    
    // Generate clock
    always #5 clk = ~clk;  // 100MHz clock
    
    // Test signals
    logic        reg_write = 0;
    logic        reg_read = 0;
    logic [3:0]  reg_addr = 0;
    logic [31:0] reg_wdata = 0;
    logic [31:0] reg_rdata;
    logic        reg_ready;
    
    // Configuration outputs
    logic        config_write;
    logic [31:0] config_data;
    logic [31:0] config_reg;
    logic        config_valid;
    logic [15:0] baud_divisor;
    logic [2:0]  data_bits;
    logic [1:0]  parity_mode;
    logic        two_stop_bits;
    logic        tx_enable;
    logic        rx_enable;
    logic        fifo_enable;
    logic [2:0]  fifo_size;
    
    // Dummy status signals
    logic tx_ready = 1;
    logic tx_busy = 0;
    logic rx_valid = 0;
    logic rx_frame_error = 0;
    logic tx_fifo_full = 0;
    logic tx_fifo_empty = 1;
    logic rx_fifo_full = 0;
    logic rx_fifo_empty = 1;
    logic [9:0] tx_fifo_count = 0;
    logic [9:0] rx_fifo_count = 0;
    logic [7:0] rx_fifo_data = 0;
    
    // DUT instances
    uart_config #(
        .CLOCK_FREQ(100_000_000)
    ) config_inst (
        .clk(clk),
        .reset(reset),
        .config_write(config_write),
        .config_data(config_data),
        .config_reg(config_reg),
        .baud_divisor(baud_divisor),
        .data_bits(data_bits),
        .parity_mode(parity_mode),
        .two_stop_bits(two_stop_bits),
        .tx_enable(tx_enable),
        .rx_enable(rx_enable),
        .fifo_enable(fifo_enable),
        .fifo_size(fifo_size),
        .config_valid(config_valid)
    );
    
    uart_registers reg_inst (
        .clk(clk),
        .reset(reset),
        .reg_write(reg_write),
        .reg_read(reg_read),
        .reg_addr(reg_addr),
        .reg_wdata(reg_wdata),
        .reg_rdata(reg_rdata),
        .reg_ready(reg_ready),
        .config_write(config_write),
        .config_data(config_data),
        .config_reg(config_reg),
        .config_valid(config_valid),
        .tx_ready(tx_ready),
        .tx_busy(tx_busy),
        .rx_valid(rx_valid),
        .rx_frame_error(rx_frame_error),
        .tx_fifo_full(tx_fifo_full),
        .tx_fifo_empty(tx_fifo_empty),
        .rx_fifo_full(rx_fifo_full),
        .rx_fifo_empty(rx_fifo_empty),
        .tx_fifo_count(tx_fifo_count),
        .rx_fifo_count(rx_fifo_count),
        .tx_fifo_write(),  // Not connected for this test
        .tx_fifo_data(),   // Not connected for this test
        .rx_fifo_read(1'b0),
        .rx_fifo_data(rx_fifo_data),
        .tx_fifo_reset(),
        .rx_fifo_reset(),
        .global_reset(),
        .interrupt()
    );
    
    // Test tasks
    task write_register(input [3:0] addr, input [31:0] data);
        @(posedge clk);
        reg_addr = addr;
        reg_wdata = data;
        reg_write = 1;
        @(posedge clk);
        reg_write = 0;
        @(posedge clk);
    endtask
    
    task read_register(input [3:0] addr, output [31:0] data);
        @(posedge clk);
        reg_addr = addr;
        reg_read = 1;
        @(posedge clk);
        data = reg_rdata;
        reg_read = 0;
        @(posedge clk);
    endtask
    
    // Test sequence
    initial begin
        // Reset sequence
        #100;
        reset = 0;
        #50;
        
        $display("=== UART Configuration Test ===");
        
        // Test 1: Read default configuration
        logic [31:0] read_data;
        read_register(4'h0, read_data);
        $display("Default config: 0x%08h", read_data);
        $display("  Baud divisor: %d (should be %d for 9600 baud)", 
                baud_divisor, (100_000_000/9600)-1);
        $display("  Data bits: %d (should be 3 for 8 bits)", data_bits);
        $display("  Parity: %d (should be 0 for none)", parity_mode);
        $display("  Config valid: %b", config_valid);
        
        // Test 2: Write custom configuration for 115200 baud, 7E1
        logic [31:0] custom_config;
        custom_config = config_inst.make_config(
            .clock_freq(100_000_000),
            .baud_rate(115200),
            .data_bits_val(7),      // 7 data bits
            .parity(2),             // Even parity
            .stop_bits_2(0),        // 1 stop bit
            .enable_fifos(1),
            .fifo_sz(3'b011)        // 128 entries
        );
        
        $display("\n--- Writing custom config for 115200 7E1 ---");
        write_register(4'h0, custom_config);
        
        #20;  // Wait for config to take effect
        
        read_register(4'h0, read_data);
        $display("Custom config: 0x%08h", read_data);
        $display("  Baud divisor: %d (should be %d for 115200 baud)", 
                baud_divisor, (100_000_000/115200)-1);
        $display("  Data bits: %d (should be 2 for 7 bits)", data_bits);
        $display("  Parity: %d (should be 2 for even)", parity_mode);
        $display("  Config valid: %b", config_valid);
        
        // Test 3: Test status register
        $display("\n--- Testing status register ---");
        read_register(4'h2, read_data);
        $display("Status register: 0x%08h", read_data);
        
        // Test 4: Test invalid configuration
        $display("\n--- Testing invalid config (bad data bits) ---");
        write_register(4'h0, 32'h12345070);  // data_bits = 7 (invalid, >3)
        
        #20;
        $display("Config valid after invalid write: %b (should be 0)", config_valid);
        
        $display("\n=== Test Complete ===");
        $finish;
    end
    
    // Monitor key signals
    initial begin
        $monitor("Time=%0t, baud_div=%d, data_bits=%d, parity=%d, valid=%b", 
                $time, baud_divisor, data_bits, parity_mode, config_valid);
    end

endmodule

`default_nettype wire