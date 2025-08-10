
`default_nettype none

module uart_tx #(
     // BAUD_RATE = 870,
     // BAUD_WIDTH = $clog2(BAUD_RATE),
     DATA_WIDTH = 8
) (
     input logic clk, reset, 
     input logic valid, 
     input logic [DATA_WIDTH - 1:0] data, 
     output logic ready, done, out
);


     enum logic [1:0] {IDLE, START, TRANSMIT, STOP} state, nextState;

     /* verilator lint_off UNUSEDSIGNAL */
     logic baud, half_baud;
     /* verilator lint_on UNUSEDSIGNAL */
     logic byte_done;


     baud_gen baud_logic(.*);
    
     assign ready = (state == IDLE);

     always_comb begin //cleared
         case (state) 
               IDLE: nextState = (valid & ready) ? START :  IDLE;
               START: nextState = (baud) ? TRANSMIT : START;
               TRANSMIT: nextState = (byte_done & baud) ? STOP : TRANSMIT;
               STOP: nextState = (baud) ? IDLE : STOP;
         endcase
     end

     assign done = (state == STOP) & baud;

     logic [3:0] transmitted;
     always_ff @(posedge clk) begin
          if (reset) transmitted <= 'h0; 
          case (state) 
               IDLE: transmitted <= 'h0;
               START:
                    if (baud)
                        transmitted <= transmitted + 1; 
               TRANSMIT: begin
                    if (baud)
                         transmitted <= transmitted + 1;
               end    
               STOP: transmitted <= 'h0;
         endcase
     end
     assign byte_done = (transmitted == DATA_WIDTH);

 

     always_ff @(posedge clk) begin //cleared
          if (reset) out <= 1'b1;
          else 
               case (state) 
                    IDLE: out <= (nextState == START) ? 1'b0 : 1'b1;
                    START: out <=  (nextState == TRANSMIT) ? lsb : 1'b0;
                    TRANSMIT: out <=  (nextState == STOP) ? 1'b1 : lsb;
                    STOP: out <= 1;
         
               endcase
     end
     

     //eventually parameterize temp
     logic [DATA_WIDTH - 1:0] temp;
     /* FIX BAUD */
     always_ff @(posedge clk) begin
          if (reset) temp <= 'h0;
          else if (valid & ready) begin
               temp <= data;
          end
          else if (baud & state == TRANSMIT) begin //baud generator
               temp <= {1'b0, temp[DATA_WIDTH - 1:1]}; // logic as to what to do in teh STOP case
          end

     end

     logic lsb;
     assign lsb = temp[0]; // i think latching this should work

     always_ff @(posedge clk) begin
        if (reset) 
          state <= IDLE;
        else
          state <= nextState;  
     end




`ifdef FORMAL

    initial assume(reset);

    always @(posedge clk) begin
        if ($past(reset)) begin
            assume(!reset);
            assert(state == IDLE);
          //   assert(transmitted == 0);     FIX THIS

        end
    end
    
    always @(posedge clk) begin
        if (!reset && $past(!reset)) begin  // Only when reset has been stable low
            
            assert(ready == (state == IDLE));
            assert(done == (state == STOP && baud));
            assert(byte_done == (transmitted == DATA_WIDTH));

            
            // Output correctness
            if (state == IDLE || state == STOP) begin
                assert(out == 1'b1);
            end
            if (state == START) begin //FIXS
                assert(out == 1'b0);
            end
            
            // State transitions
            if ($past(state == IDLE && valid && ready)) begin
                assert(state == START);

            end
            
            if ($past(state == START && baud)) begin
                assert(state == TRANSMIT);

            end
            
            if ($past(state == TRANSMIT && byte_done && baud)) begin
                assert(state == STOP);
  
            end
            
            if ($past(state == STOP && baud)) begin
                assert(state == IDLE);
        
            end
        end
    end

    always @(posedge clk) begin
        if (!reset) begin
            cover(state == IDLE && $past(state == STOP));
        end
    end
    
    always @(posedge clk) begin
        cover(state == START);
        cover(state == TRANSMIT);
        cover(state == STOP);
    end
    
    always @(posedge clk) begin
        cover(valid && ready);
        cover(done);
    end

    logic transmission_started;
    logic  [15:0] timeout_counter;
    
    always @(posedge clk) begin
        if (reset) begin
            transmission_started <= 0;
            timeout_counter <= 0;
        end else if (valid && ready) begin
            transmission_started <= 1;
            timeout_counter <= 0;
        end else if (done) begin
            transmission_started <= 0;
        end else if (transmission_started) begin
            timeout_counter <= timeout_counter + 1;
            // Should complete within reasonable time
            assert(timeout_counter < 80000);
        end
    end

     logic [DATA_WIDTH-1:0] captured_data;
     logic data_captured;

     always @(posedge clk) begin
     if (reset) begin
          data_captured <= 0;
     end else if (valid && ready) begin
          captured_data <= data;
          data_captured <= 1;
     end else if (state == IDLE) begin
          data_captured <= 0;
     end
     end

     // Verify correct bit transmission
     always @(posedge clk) begin
     if (!reset && $past(!reset) && data_captured && state == TRANSMIT && baud) begin
          // This is complex but critical - verify the right bit is output
          assert(out == captured_data[transmitted-1]);
     end
     end


`endif

endmodule

// once we get a start signal
module baud_gen #(
     BAUD_RATE = 870,
     BAUD_WIDTH = $clog2(BAUD_RATE)
) (
     input logic clk, reset, valid, ready,
     output logic baud, half_baud
);

     logic [BAUD_WIDTH - 1:0] baud_cnt;

     always_ff @(posedge clk) begin
          if (reset) begin
               baud_cnt <= 0;
          end
          else if (valid & ready) begin
               baud_cnt <= BAUD_RATE - 1; // depending on what states we are in could this cause issues
                                          // since ready is dependent on current state (moore is off by one cycle)
          end
          else if (baud_cnt == 'h0) begin // if we have reached zero
               baud_cnt <= BAUD_RATE - 1;
          end
          else begin
               baud_cnt <= baud_cnt - 1;
          end  
     
     end
     
     assign baud = (baud_cnt == 'h0);
     assign half_baud = (baud_cnt == (BAUD_RATE/2));
     
endmodule

