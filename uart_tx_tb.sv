`default_nettype none

module uart_tx_tb
    (input logic clk, 

     output logic reset,
     output logic [7:0] received_data,
     output logic received_valid,
     output logic frame_error);

    //clock, reset, valid, data comes from the testbench
    // ready, done, out comes from the testbench



    logic valid;
    logic [7:0] data;
    logic transmitter_ready;
     /* verilator lint_off UNUSEDSIGNAL */
    logic serial_out;
     /* verilator lint_off UNUSEDSIGNAL */
    logic receiver_ready;
    logic transmission_completed;
    logic start_baud;


    uart_tx transmitter(.clk(clk),
                        .reset(reset), 
                        .valid(valid), 
                        .data(data), 
                        .ready(transmitter_ready), 
                        .done(transmission_completed), 
                        .out(serial_out)
                        );


    uart_rx receiver(.clk(clk), 
                     .reset(reset), 
                     .rx_in(serial_out), 
                     .data(received_data), 
                     .valid(received_valid), 
                     .ready(receiver_ready), 
                     .frame_error(frame_error)
                    );


    initial begin

        reset = 0;
        @(posedge clk);
        reset = 1;
        @(posedge clk);
        reset = 0;
        // reset states, transmitter


        data = 8'hAB;
        repeat (900) @(posedge clk); // 900 cycles of nothing
        valid = 1'b1;
        @(posedge clk);
        valid = 1'b0;
        repeat (1) begin
            @(posedge clk);
            $display("TX Ready: %b, RX Ready: %b, TX Done: %b", 
                    transmitter_ready, receiver_ready, transmission_completed);
        end


        repeat (100000) @(posedge clk);
        $finish;


    end
   
endmodule
