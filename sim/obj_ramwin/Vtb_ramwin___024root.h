// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design internal header
// See Vtb_ramwin.h for the primary calling header

#ifndef VERILATED_VTB_RAMWIN___024ROOT_H_
#define VERILATED_VTB_RAMWIN___024ROOT_H_  // guard

#include "verilated.h"
#include "verilated_timing.h"


class Vtb_ramwin__Syms;

class alignas(VL_CACHE_LINE_BYTES) Vtb_ramwin___024root final {
  public:

    // TRIVIALLY CONSTRUCTIBLE STATE
    ::CData/*0:0*/ tb_ramwin__DOT__clk;
    ::CData/*0:0*/ tb_ramwin__DOT__reset;
    ::CData/*0:0*/ tb_ramwin__DOT___cpuAS;
    ::CData/*0:0*/ tb_ramwin__DOT____Vcellinp__sd__oe;
    ::CData/*0:0*/ tb_ramwin__DOT__chk_pending;
    ::CData/*1:0*/ tb_ramwin__DOT__chk_owner;
    ::CData/*0:0*/ tb_ramwin__DOT__ac__DOT__loadSound;
    ::CData/*0:0*/ tb_ramwin__DOT__ac__DOT__video_dma_off;
    ::CData/*0:0*/ tb_ramwin__DOT__ac__DOT__sndReq;
    ::CData/*0:0*/ tb_ramwin__DOT__ac__DOT__sndReqCycle;
    ::CData/*0:0*/ tb_ramwin__DOT__ac__DOT__vblankD;
    ::CData/*0:0*/ tb_ramwin__DOT__ac__DOT__hblankD;
    ::CData/*0:0*/ tb_ramwin__DOT__ac__DOT__lpx;
    ::CData/*0:0*/ tb_ramwin__DOT__ac__DOT__lsnd;
    ::CData/*0:0*/ tb_ramwin__DOT__ac__DOT__vt__DOT__loadPixels;
    ::CData/*2:0*/ tb_ramwin__DOT__sd__DOT__state;
    ::CData/*4:0*/ tb_ramwin__DOT__sd__DOT__init_state;
    ::CData/*2:0*/ tb_ramwin__DOT__clk_i__DOT__busPhase;
    ::CData/*0:0*/ tb_ramwin__DOT__clk_i__DOT__busCycle;
    ::CData/*0:0*/ __Vtrigprevexpr___TOP__tb_ramwin__DOT__clk__0;
    ::CData/*0:0*/ __Vtrigprevexpr_h721d1614__1;
    ::SData/*9:0*/ tb_ramwin__DOT__ac__DOT__vt__DOT__xpos;
    ::SData/*8:0*/ tb_ramwin__DOT__ac__DOT__vt__DOT__ypos;
    ::IData/*20:0*/ tb_ramwin__DOT__chk_expect;
    ::IData/*31:0*/ tb_ramwin__DOT__ticks;
    ::IData/*31:0*/ tb_ramwin__DOT__fails;
    ::IData/*31:0*/ tb_ramwin__DOT__cpu_fetches;
    ::IData/*31:0*/ tb_ramwin__DOT__cpu_ok;
    ::IData/*31:0*/ tb_ramwin__DOT__vid_fetches;
    ::IData/*31:0*/ tb_ramwin__DOT__vid_ok;
    ::IData/*31:0*/ tb_ramwin__DOT__snd_fetches;
    ::IData/*31:0*/ tb_ramwin__DOT__snd_ok;
    ::IData/*20:0*/ tb_ramwin__DOT__ac__DOT__audioAddr;
    ::IData/*20:0*/ tb_ramwin__DOT__ac__DOT__vt__DOT__videoAddr;
    ::IData/*21:0*/ tb_ramwin__DOT__sd__DOT__rd_addr_r;
    ::IData/*31:0*/ __Vi;
    ::VlUnpacked<::QData/*63:0*/, 1> __VstlTriggered;
    ::VlUnpacked<::QData/*63:0*/, 1> __VicoTriggered;
    ::VlUnpacked<::QData/*63:0*/, 1> __VactTriggered;
    ::VlUnpacked<::QData/*63:0*/, 1> __VactTriggeredAcc;
    ::VlUnpacked<::QData/*63:0*/, 1> __VnbaTriggered;

    // NOT TRIVIALLY CONSTRUCTIBLE STATE
    union {
        struct {
            ::VlDelayScheduler __VdlySched;
            ::VlTriggerScheduler __VtrigSched_h04e7b3b1__0;
            ::VlTriggerScheduler __VtrigSched_h5608d255__0;
        } __Vnontrivs;
    };

    // INTERNAL VARIABLES
    Vtb_ramwin__Syms* vlSymsp;
    const char* vlNamep;

    // CONSTRUCTORS
    Vtb_ramwin___024root(Vtb_ramwin__Syms* symsp, const char* namep);
    ~Vtb_ramwin___024root();
    VL_UNCOPYABLE(Vtb_ramwin___024root);
    VL_UNMOVABLE(Vtb_ramwin___024root);

    // INTERNAL METHODS
};


#endif  // guard
