#include <verilated.h>
#include "Vtb_via_irq_storm.h"
#include <iostream>
#include <iomanip>

double sc_time_stamp() { return 0; }

void run_test(Vtb_via_irq_storm* top, int turbo) {
    top->reset = 1;
    top->turbo_mode = turbo;

    for (int i = 0; i < 50; ++i) {
        top->clk = !top->clk;
        top->eval();
    }
    top->reset = 0;

    std::cout << "\n========================================" << std::endl;
    std::cout << "Starting Test in " << (turbo ? "TURBO (19.58 MHz)" : "STOCK (7.83 MHz)") << " Mode..." << std::endl;
    std::cout << "========================================" << std::endl;

    long cycle = 0;
    int prev_as = 1;
    int prev_irq = 0;
    int isr_entry_count = 0;
    int isr_exit_count = 0;
    int user_loop_cycles = 0;
    bool after_rte = false;
    int after_rte_steps = 0;

    for (long step = 0; step < 200000; ++step) {
        top->clk = !top->clk;
        top->eval();
        cycle++;

        if (top->clk == 1) {
            if (!prev_irq && top->dbg_via_irq) {
                std::cout << "[Cycle " << std::dec << cycle << "] VIA IRQ ASSERTED! flags=0x"
                          << std::hex << (int)top->dbg_irq_flags 
                          << " mask=0x" << (int)top->dbg_irq_mask
                          << " t2_cnt=0x" << (int)top->dbg_t2_count 
                          << " t2_trig=" << (int)top->dbg_t2_trig << std::endl;
            }
            if (prev_irq && !top->dbg_via_irq) {
                std::cout << "[Cycle " << std::dec << cycle << "] VIA IRQ DEASSERTED! flags=0x"
                          << std::hex << (int)top->dbg_irq_flags << std::endl;
            }
            prev_irq = top->dbg_via_irq;

            if (!prev_as && top->dbg_as) {
                uint32_t addr = top->dbg_addr;
                if (after_rte && after_rte_steps < 5) {
                    after_rte_steps++;
                    std::cout << "    [Post-RTE " << after_rte_steps << "] Addr 0x" << std::hex << addr 
                              << " " << (top->dbg_rw ? "R" : "W") << " FC=" << std::dec << (int)top->dbg_fc << std::endl;
                }
                if (addr == 0x400200) {
                    isr_entry_count++;
                    std::cout << "  >>> ENTERED Timer 2 ISR (#" << isr_entry_count << ") at cycle " << cycle << std::endl;
                }
                if (addr == 0x401A82) { // RTE
                    isr_exit_count++;
                    after_rte = true;
                    std::cout << "  <<< EXITED via RTE (#" << isr_exit_count << ") at cycle " << cycle << std::endl;
                    std::cout << "      [At RTE exit] t2_cnt=0x" << std::hex << (int)top->dbg_t2_count 
                              << " t2_trig=" << (int)top->dbg_t2_trig 
                              << " flags=0x" << (int)top->dbg_irq_flags << std::endl;
                }
                if (addr == 400118 || addr == 0x40011C) {
                    user_loop_cycles++;
                    if (user_loop_cycles == 1) {
                        std::cout << "[Cycle " << cycle << "] In user loop! Timer armed, waiting for IRQ..." << std::endl;
                    }
                }
                if (top->dbg_fc == 7) {
                    std::cout << "  [IACK] Addr 0x" << std::hex << addr << " pswI=" << std::dec << (int)top->dbg_pswi << std::endl;
                }
            }
            prev_as = top->dbg_as;
        }
    }

    std::cout << "Results summary for " << (turbo ? "TURBO" : "STOCK") << ":" << std::endl;
    std::cout << "  ISR entries: " << isr_entry_count << std::endl;
    std::cout << "  ISR exits:   " << isr_exit_count << std::endl;
    std::cout << "  User loop executions: " << user_loop_cycles << std::endl;

    if (isr_entry_count == 1 && isr_exit_count == 1) {
        std::cout << ">>> " << (turbo ? "TURBO" : "STOCK") << " TEST PASSED! <<<\n" << std::endl;
    } else {
        std::cerr << ">>> " << (turbo ? "TURBO" : "STOCK") << " TEST FAILED! <<<\n" << std::endl;
        exit(1);
    }
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vtb_via_irq_storm* top = new Vtb_via_irq_storm;
    top->clk = 0;

    run_test(top, 0); // Stock mode
    run_test(top, 1); // Turbo mode

    top->final();
    delete top;
    return 0;
}
