`default_nettype none

module uart_controller #(
    parameter CLOCK_FREQ = 100_000_000,
    parameter FIFO_DEPTH = 256
) (
    input  logic        clk,
    input  logic        reset,
    
    // Register interface (will connect to AXI-Lite)
    input  logic        reg_write,
    input  logic        reg_read,
    input  logic [3:0]  reg_addr,
    input  logic [31:0] reg_wdata,
    output logic [31:0] reg_rdata,
    output logic        reg_ready,
    
    // UART physical interface
    input  logic        uart_rx,
    output logic        uart_tx,
    
    // Interrupt
    output logic        interrupt
);

    // Configuration signals
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
    
    // Control signals
    logic        tx_fifo_reset;
    logic        rx_fifo_reset;
    logic        global_reset;
    
    // UART core signals
    logic        tx_valid, tx_ready, tx_done;
    logic        rx_valid, rx_ready, rx_frame_error, rx_parity_error;
    logic [7:0]  tx_data_to_uart, rx_data_from_uart;
    
    // FIFO signals
    logic        tx_fifo_write, tx_fifo_read, tx_fifo_full, tx_fifo_empty;
    logic        rx_fifo_write, rx_fifo_read, rx_fifo_full, rx_fifo_empty;
    logic [7:0]  tx_fifo_data_in, tx_fifo_data_out;
    logic [7:0]  rx_fifo_data_in, rx_fifo_data_out;
    logic [9:0]  tx_fifo_count, rx_fifo_count;
    
    // Reset logic
    logic combined_reset;
    assign combined_reset = reset || global_reset;

    // Configuration module
    uart_config #(
        .CLOCK_FREQ(CLOCK_FREQ)
    ) config_inst (
        .clk(clk),
        .reset(combined_reset),
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
    
    // Register interface
    uart_registers reg_inst (
        .clk(clk),
        .reset(combined_reset),
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
        .tx_fifo_reset(tx_fifo_reset),
        .rx_fifo_reset(rx_fifo_reset),
        .global_reset(global_reset),
        .tx_ready(tx_ready && !tx_fifo_full),
        .tx_busy(!tx_ready || !tx_fifo_empty),
        .rx_valid(rx_valid),
        .rx_frame_error(rx_frame_error),
        .tx_fifo_full(tx_fifo_full),
        .tx_fifo_empty(tx_fifo_empty),
        .rx_fifo_full(rx_fifo_full),
        .rx_fifo_empty(rx_fifo_empty),
        .tx_fifo_count(tx_fifo_count),
        .rx_fifo_count(rx_fifo_count),
        .tx_fifo_write(tx_fifo_write),
        .tx_fifo_data(tx_fifo_data_in),
        .rx_fifo_read(rx_fifo_read),
        .rx_fifo_data(rx_fifo_data_out),
        .interrupt(interrupt)
    );
    
    // TX FIFO
    fifo #(
        .DEPTH(FIFO_DEPTH),
        .DWIDTH(8)
    ) tx_fifo (
        .clk(clk),
        .reset(combined_reset || tx_fifo_reset),
        .wr(tx_fifo_write && fifo_enable),
        .re(tx_fifo_read),
        .data_in(tx_fifo_data_in),
        .data_out(tx_fifo_data_out),
        .full(tx_fifo_full),
        .empty(tx_fifo_empty),
        .count(tx_fifo_count)
    );
    
    // RX FIFO  
    fifo #(
        .DEPTH(FIFO_DEPTH),
        .DWIDTH(8)
    ) rx_fifo (
        .clk(clk),
        .reset(combined_reset || rx_fifo_reset),
        .wr(rx_fifo_write),
        .re(rx_fifo_read && fifo_enable),
        .data_in(rx_fifo_data_in),
        .data_out(rx_fifo_data_out),
        .full(rx_fifo_full),
        .empty(rx_fifo_empty),
        .count(rx_fifo_count)
    );
    
    // TX path: FIFO -> UART
    assign tx_fifo_read = tx_ready && !tx_fifo_empty && tx_enable;
    assign tx_valid = tx_fifo_read;  // Valid when we read from FIFO
    assign tx_data_to_uart = fifo_enable ? tx_fifo_data_out : tx_fifo_data_in;
    
    // RX path: UART -> FIFO
    assign rx_fifo_write = rx_valid && !rx_fifo_full && rx_enable;
    assign rx_fifo_data_in = rx_data_from_uart;
    
    // UART TX core
    configurable_uart_tx tx_core (
        .clk(clk),
        .reset(combined_reset),
        .valid(tx_valid),
        .data(tx_data_to_uart),
        .baud_divisor(baud_divisor),
        .data_bits(data_bits),
        .parity_mode(parity_mode),
        .two_stop_bits(two_stop_bits),
        .tx_enable(tx_enable),
        .ready(tx_ready),
        .done(tx_done),
        .out(uart_tx)
    );
    
    // UART RX core
    configurable_uart_rx rx_core (
        .clk(clk),
        .reset(combined_reset),
        .rx_in(uart_rx),
        .baud_divisor(baud_divisor),
        .data_bits(data_bits),
        .parity_mode(parity_mode),
        .two_stop_bits(two_stop_bits),
        .rx_enable(rx_enable),
        .data(rx_data_from_uart),
        .valid(rx_valid),
        .ready(rx_ready),
        .frame_error(rx_frame_error),
        .parity_error(rx_parity_error)
    );

endmodule

`default_nettype wire