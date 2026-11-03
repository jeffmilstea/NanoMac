// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design internal header
// See Vila_hang_tb.h for the primary calling header

#ifndef VERILATED_VILA_HANG_TB___024ROOT_H_
#define VERILATED_VILA_HANG_TB___024ROOT_H_  // guard

#include "verilated.h"
#include "verilated_timing.h"


class Vila_hang_tb__Syms;

class alignas(VL_CACHE_LINE_BYTES) Vila_hang_tb___024root final {
  public:

    // TRIVIALLY CONSTRUCTIBLE STATE
    // Anonymous structures to workaround compiler member-count bugs
    struct {
        ::CData/*0:0*/ ila_hang_tb__DOT__clk;
        ::CData/*0:0*/ ila_hang_tb__DOT__reset;
        ::CData/*0:0*/ ila_hang_tb__DOT___cpuAS;
        ::CData/*0:0*/ ila_hang_tb__DOT__strobe;
        ::CData/*0:0*/ ila_hang_tb__DOT__start;
        ::CData/*7:0*/ ila_hang_tb__DOT__din;
        ::CData/*0:0*/ ila_hang_tb__DOT__dut__DOT__ice_cmd_strobe;
        ::CData/*7:0*/ ila_hang_tb__DOT__dut__DOT__ice_subcmd;
        ::CData/*0:0*/ ila_hang_tb__DOT__dut__DOT___cpuAS_d;
        ::CData/*7:0*/ ila_hang_tb__DOT__dut__DOT__wr_ptr;
        ::CData/*2:0*/ ila_hang_tb__DOT__dut__DOT__ila_state;
        ::CData/*7:0*/ ila_hang_tb__DOT__dut__DOT__trigger_pos;
        ::CData/*7:0*/ ila_hang_tb__DOT__dut__DOT__pre_count;
        ::CData/*7:0*/ ila_hang_tb__DOT__dut__DOT__post_count;
        ::CData/*2:0*/ ila_hang_tb__DOT__dut__DOT__trig_mode;
        ::CData/*0:0*/ ila_hang_tb__DOT__dut__DOT__force_trigger;
        ::CData/*0:0*/ ila_hang_tb__DOT__dut__DOT__ila_arm_req;
        ::CData/*0:0*/ ila_hang_tb__DOT__dut__DOT__ila_disarm_req;
        ::CData/*0:0*/ ila_hang_tb__DOT__dut__DOT__force_trig_req;
        ::CData/*7:0*/ ila_hang_tb__DOT__dut__DOT__cmd;
        ::CData/*4:0*/ ila_hang_tb__DOT__dut__DOT__byte_cnt;
        ::CData/*0:0*/ ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__uart_halt_req;
        ::CData/*0:0*/ ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__uart_resume_req;
        ::CData/*0:0*/ ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__uart_reset_req;
        ::CData/*0:0*/ ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__uart_step_clock_req;
        ::CData/*0:0*/ ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__uart_step_bus_req;
        ::CData/*0:0*/ ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__uart_arm_req;
        ::CData/*0:0*/ ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__uart_disarm_req;
        ::CData/*0:0*/ ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__uart_force_trig_req;
        ::CData/*2:0*/ ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__uart_trig_mode;
        ::CData/*1:0*/ ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__rx_sync;
        ::CData/*2:0*/ ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__rx_state;
        ::CData/*5:0*/ ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__rx_clk_cnt;
        ::CData/*2:0*/ ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__rx_bit_idx;
        ::CData/*7:0*/ ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__rx_shreg;
        ::CData/*0:0*/ ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__rx_valid;
        ::CData/*7:0*/ ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__rx_byte;
        ::CData/*0:0*/ ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__fifo_wr;
        ::CData/*0:0*/ ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__fifo_empty;
        ::CData/*2:0*/ ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__tx_state;
        ::CData/*5:0*/ ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__tx_clk_cnt;
        ::CData/*2:0*/ ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__tx_bit_idx;
        ::CData/*3:0*/ ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__state;
        ::CData/*7:0*/ ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__msg_idx;
        ::CData/*7:0*/ ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__msg_len;
        ::CData/*5:0*/ ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__dump_col;
        ::CData/*2:0*/ ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__bin_byte_idx;
        ::CData/*0:0*/ ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__bin_hdr;
        ::CData/*2:0*/ ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__peek_slot;
        ::CData/*1:0*/ ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__peek_settle;
        ::CData/*0:0*/ ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__poke_hi_rx;
        ::CData/*0:0*/ ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__print_after_step;
        ::CData/*2:0*/ ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__cfg_idx;
        ::CData/*0:0*/ __Vtrigprevexpr___TOP__ila_hang_tb__DOT__clk__0;
        ::SData/*15:0*/ ila_hang_tb__DOT__dut__DOT__step_clock_cnt;
        ::SData/*15:0*/ ila_hang_tb__DOT__dut__DOT__step_bus_cnt;
        ::SData/*15:0*/ ila_hang_tb__DOT__dut__DOT__ice_step_val;
        ::SData/*15:0*/ ila_hang_tb__DOT__dut__DOT__quiet_cnt;
        ::SData/*15:0*/ ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__uart_step_val;
        ::SData/*8:0*/ ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__fifo_wptr;
        ::SData/*8:0*/ ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__fifo_rptr;
        ::SData/*8:0*/ ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__fifo_count;
        ::SData/*9:0*/ ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__dump_cnt;
        ::IData/*23:0*/ ila_hang_tb__DOT__active__Vstatic__a;
    };
    struct {
        ::IData/*31:0*/ ila_hang_tb__DOT__active__Vstatic__n;
        ::IData/*31:0*/ ila_hang_tb__DOT__active__Vstatic__k;
        ::IData/*31:0*/ ila_hang_tb__DOT__quiet__Vstatic__n;
        ::IData/*31:0*/ ila_hang_tb__DOT__quiet__Vstatic__k;
        ::IData/*23:0*/ ila_hang_tb__DOT__dut__DOT__trig_addr;
        ::IData/*23:0*/ ila_hang_tb__DOT__dut__DOT__trig_mask;
        ::IData/*23:0*/ ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__uart_trig_addr;
        ::IData/*23:0*/ ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__uart_trig_mask;
        ::IData/*19:0*/ ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__step_timeout;
        ::IData/*31:0*/ __Vi;
        ::QData/*63:0*/ ila_hang_tb__DOT__probes;
        ::VlUnpacked<::QData/*63:0*/, 1> __VstlTriggered;
        ::VlUnpacked<::QData/*63:0*/, 1> __VicoTriggered;
        ::VlUnpacked<::QData/*63:0*/, 1> __VactTriggered;
        ::VlUnpacked<::QData/*63:0*/, 1> __VactTriggeredAcc;
        ::VlUnpacked<::QData/*63:0*/, 1> __VnbaTriggered;
    };

    // NOT TRIVIALLY CONSTRUCTIBLE STATE
    union {
        struct {
            ::VlDelayScheduler __VdlySched;
            ::VlTriggerScheduler __VtrigSched_hf3b002a5__0;
        } __Vnontrivs;
    };

    // INTERNAL VARIABLES
    Vila_hang_tb__Syms* vlSymsp;
    const char* vlNamep;

    // CONSTRUCTORS
    Vila_hang_tb___024root(Vila_hang_tb__Syms* symsp, const char* namep);
    ~Vila_hang_tb___024root();
    VL_UNCOPYABLE(Vila_hang_tb___024root);
    VL_UNMOVABLE(Vila_hang_tb___024root);

    // INTERNAL METHODS
};


#endif  // guard
