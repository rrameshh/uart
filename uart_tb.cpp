

#include <stdio.h>
#include <stdlib.h>
#include <iostream>
#include "Vuart_tx_tb.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

// If you have uartsim.h from the original example, uncomment this:
#include "uartsim.h"

Vuart_tx_tb *tb;
VerilatedVcdC *tfp;

// Required by Verilator - time stamp function
double sc_time_stamp() {
    return 0.0;
}

// Function to advance simulation by one clock cycle
void tick(Vuart_tx_tb *tb, int cycles, VerilatedVcdC *tfp) {
    // Clock low phase
    tb->clk = 0;
    tb->eval();
    if (tfp) {
        tfp->dump(static_cast<uint64_t>(cycles * 10));
    }

    // Clock high phase
    tb->clk = 1;
    tb->eval();
    if (tfp) {
        tfp->dump(static_cast<uint64_t>(cycles * 10 + 5));
        tfp->flush();
    }
    
}



/* Simulating a receiver:

From the initial state, when you go high to low, we know that a data
transmission has started. we must then wait 1.5 baud periods to sample 
the first bit, then we wait 1 bit. If we have sampled 8 data bits, 
we must expect the stop bit (also high) and then return

we will get the data + ready stuff from the test bench??
*/





int main(int argc, char** argv)
{
    Verilated::commandArgs(argc, argv);
    Verilated::traceEverOn(true);


    tb = new Vuart_tx_tb;

    tfp = new VerilatedVcdC;
	tb->trace(tfp, 99);
	tfp->open("uart_tx.vcd");


    int cycles = 0;
    while ((cycles < 1) || !(tb->received_valid))
    {
        tick(tb, cycles, tfp);
        cycles++;
    }
    printf("cycles: %d received: %x frame error %d\n", cycles, tb->received_data, tb->frame_error);


}


