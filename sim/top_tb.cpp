#include <verilated.h>
#include "Vtop.h"
#include <iostream>

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vtop* top = new Vtop;

    // Initialize inputs
    top->clk = 0;
    top->reset = 1; // Assuming active-high or button-based reset
    top->user = 0;

    std::cout << "Starting simulation..." << std::endl;

    // Apply reset
    for(int i = 0; i < 20; ++i) {
        top->clk = !top->clk;
        top->eval();
    }
    top->reset = 0;
    
    // Run for a few thousand cycles just to test clocking and bridge logic
    long cycles = 0;
    while (!Verilated::gotFinish() && cycles < 100000) {
        top->clk = !top->clk;
        top->eval();
        cycles++;
    }

    std::cout << "Simulation completed " << cycles << " half-cycles." << std::endl;

    top->final();
    delete top;
    return 0;
}
