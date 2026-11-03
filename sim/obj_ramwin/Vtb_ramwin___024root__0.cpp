// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vtb_ramwin.h for the primary calling header

#include "Vtb_ramwin__pch.h"

VlCoroutine Vtb_ramwin___024root___eval_initial__TOP__Vtiming__0(Vtb_ramwin___024root* vlSelf);
VlCoroutine Vtb_ramwin___024root___eval_initial__TOP__Vtiming__1(Vtb_ramwin___024root* vlSelf);

void Vtb_ramwin___024root___eval_initial(Vtb_ramwin___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_ramwin___024root___eval_initial\n"); );
    Vtb_ramwin__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    Vtb_ramwin___024root___eval_initial__TOP__Vtiming__0(vlSelf);
    Vtb_ramwin___024root___eval_initial__TOP__Vtiming__1(vlSelf);
}

void Vtb_ramwin___024root___eval_sample(Vtb_ramwin___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_ramwin___024root___eval_sample\n"); );
    Vtb_ramwin__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
}

#ifdef VL_DEBUG
VL_ATTR_COLD void Vtb_ramwin___024root___dump_triggers__ico(const ::VlUnpacked<::QData/*63:0*/, 1> &triggers, const ::std::string &tag);
#endif  // VL_DEBUG

bool Vtb_ramwin___024root___eval_ico(Vtb_ramwin___024root* vlSelf, ::CData/*0:0*/ firstIteration) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_ramwin___024root___eval_ico\n"); );
    Vtb_ramwin__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    vlSelfRef.__VicoTriggered[0U] = ((0xfffffffffffffffeULL 
                                      & vlSelfRef.__VicoTriggered[0U]) 
                                     | (::IData)((::IData)(firstIteration)));
#ifdef VL_DEBUG
    if (VL_UNLIKELY(vlSymsp->_vm_contextp__->debug())) {
        Vtb_ramwin___024root___dump_triggers__ico(vlSelfRef.__VicoTriggered, "ico"s);
    }
#endif
    return (0U);
}

void Vtb_ramwin___024root___timing_ready(Vtb_ramwin___024root* vlSelf);
void Vtb_ramwin___024root___trigger_orInto__act_vec_vec(::VlUnpacked<::QData/*63:0*/, 1> &out, const ::VlUnpacked<::QData/*63:0*/, 1> &in);
#ifdef VL_DEBUG
VL_ATTR_COLD void Vtb_ramwin___024root___dump_triggers__act(const ::VlUnpacked<::QData/*63:0*/, 1> &triggers, const ::std::string &tag);
#endif  // VL_DEBUG
bool Vtb_ramwin___024root___trigger_anySet__act(const ::VlUnpacked<::QData/*63:0*/, 1> &in);
void Vtb_ramwin___024root___timing_resume(Vtb_ramwin___024root* vlSelf);

bool Vtb_ramwin___024root___eval_act(Vtb_ramwin___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_ramwin___024root___eval_act\n"); );
    Vtb_ramwin__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    ::CData/*0:0*/ __VactExecute;
    // Body
    {
        // Inlined CFunc: _eval_triggers_vec__act
        ::CData/*0:0*/ __Vinline_0__eval_triggers_vec__act___Vtrigprevexpr_h721d1614__0;
        __Vinline_0__eval_triggers_vec__act___Vtrigprevexpr_h721d1614__0 = 0;
        __Vinline_0__eval_triggers_vec__act___Vtrigprevexpr_h721d1614__0 
            = (1U & (~ (0U != (::IData)(vlSelfRef.tb_ramwin__DOT__sd__DOT__init_state))));
        vlSelfRef.__VactTriggered[0U] = (::QData)((::IData)(
                                                            ((vlSelfRef.__Vnontrivs.__VdlySched.awaitingCurrentTime() 
                                                              << 2U) 
                                                             | ((((::IData)(__Vinline_0__eval_triggers_vec__act___Vtrigprevexpr_h721d1614__0) 
                                                                  != (::IData)(vlSelfRef.__Vtrigprevexpr_h721d1614__1)) 
                                                                 << 1U) 
                                                                | ((::IData)(vlSelfRef.tb_ramwin__DOT__clk) 
                                                                   & (~ (::IData)(vlSelfRef.__Vtrigprevexpr___TOP__tb_ramwin__DOT__clk__0)))))));
        vlSelfRef.__Vtrigprevexpr___TOP__tb_ramwin__DOT__clk__0 
            = vlSelfRef.tb_ramwin__DOT__clk;
        vlSelfRef.__Vtrigprevexpr_h721d1614__1 = __Vinline_0__eval_triggers_vec__act___Vtrigprevexpr_h721d1614__0;
    }
    Vtb_ramwin___024root___timing_ready(vlSelf);
    Vtb_ramwin___024root___trigger_orInto__act_vec_vec(vlSelfRef.__VactTriggered, vlSelfRef.__VactTriggeredAcc);
#ifdef VL_DEBUG
    if (VL_UNLIKELY(vlSymsp->_vm_contextp__->debug())) {
        Vtb_ramwin___024root___dump_triggers__act(vlSelfRef.__VactTriggered, "act"s);
    }
#endif
    Vtb_ramwin___024root___trigger_orInto__act_vec_vec(vlSelfRef.__VnbaTriggered, vlSelfRef.__VactTriggered);
    __VactExecute = Vtb_ramwin___024root___trigger_anySet__act(vlSelfRef.__VactTriggered);
    if (__VactExecute) {
        vlSelfRef.__VactTriggeredAcc.fill(0ULL);
        Vtb_ramwin___024root___timing_resume(vlSelf);
        {
            // Inlined CFunc: _eval_body__act
            if ((((7ULL & vlSelfRef.__VactTriggered[0U])) != 0ULL)) {
                {
                    // Inlined CFunc: _act_comb__TOP__0
                    ::CData/*0:0*/ __Vinline_0__eval_body__act___Vinline_0__act_comb__TOP__0___Vdfg_Regularize_84;
                    __Vinline_0__eval_body__act___Vinline_0__act_comb__TOP__0___Vdfg_Regularize_84 = 0;
                    ::CData/*0:0*/ __Vinline_0__eval_body__act___Vinline_0__act_comb__TOP__0___Vdfg_Regularize_85;
                    __Vinline_0__eval_body__act___Vinline_0__act_comb__TOP__0___Vdfg_Regularize_85 = 0;
                    __Vinline_0__eval_body__act___Vinline_0__act_comb__TOP__0___Vdfg_Regularize_84 
                        = (1U & (~ ((~ (::IData)(vlSelfRef.tb_ramwin__DOT___cpuAS)) 
                                    | (::IData)(vlSelfRef.tb_ramwin__DOT__ac__DOT__video_dma_off))));
                    vlSelfRef.tb_ramwin__DOT__ac__DOT__lpx 
                        = ((::IData)(__Vinline_0__eval_body__act___Vinline_0__act_comb__TOP__0___Vdfg_Regularize_84) 
                           & (::IData)(vlSelfRef.tb_ramwin__DOT__ac__DOT__vt__DOT__loadPixels));
                    vlSelfRef.tb_ramwin__DOT__ac__DOT__lsnd 
                        = ((::IData)(__Vinline_0__eval_body__act___Vinline_0__act_comb__TOP__0___Vdfg_Regularize_84) 
                           & (::IData)(vlSelfRef.tb_ramwin__DOT__ac__DOT__loadSound));
                    __Vinline_0__eval_body__act___Vinline_0__act_comb__TOP__0___Vdfg_Regularize_85 
                        = ((::IData)(vlSelfRef.tb_ramwin__DOT__ac__DOT__lpx) 
                           | (::IData)(vlSelfRef.tb_ramwin__DOT__ac__DOT__lsnd));
                    vlSelfRef.tb_ramwin__DOT____Vcellinp__sd__oe 
                        = (1U & (((~ (::IData)(vlSelfRef.tb_ramwin__DOT__clk_i__DOT__busCycle)) 
                                  & (::IData)(__Vinline_0__eval_body__act___Vinline_0__act_comb__TOP__0___Vdfg_Regularize_85)) 
                                 | ((~ (::IData)(vlSelfRef.tb_ramwin__DOT___cpuAS)) 
                                    & ((~ ((::IData)(vlSelfRef.tb_ramwin__DOT__clk_i__DOT__busCycle) 
                                           | (::IData)(__Vinline_0__eval_body__act___Vinline_0__act_comb__TOP__0___Vdfg_Regularize_85))) 
                                       | (::IData)(vlSelfRef.tb_ramwin__DOT__clk_i__DOT__busCycle)))));
                }
            }
        }
    }
    return (__VactExecute);
}

bool Vtb_ramwin___024root___eval_inact(Vtb_ramwin___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_ramwin___024root___eval_inact\n"); );
    Vtb_ramwin__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    ::CData/*0:0*/ __VinactExecute;
    // Body
    __VinactExecute = vlSelfRef.__Vnontrivs.__VdlySched.awaitingZeroDelay();
    if (__VinactExecute) {
        VL_FATAL_MT("tb_ramwin.sv", 38, "", "ZERODLY: Design Verilated with '--no-sched-zero-delay', but #0 delay executed at runtime");
    }
    return (__VinactExecute);
}

void Vtb_ramwin___024root___nba_sequent__TOP__0(Vtb_ramwin___024root* vlSelf);
void Vtb_ramwin___024root___trigger_clear__act(::VlUnpacked<::QData/*63:0*/, 1> &out);

bool Vtb_ramwin___024root___eval_nba(Vtb_ramwin___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_ramwin___024root___eval_nba\n"); );
    Vtb_ramwin__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    ::CData/*0:0*/ __VnbaExecute;
    // Body
    __VnbaExecute = Vtb_ramwin___024root___trigger_anySet__act(vlSelfRef.__VnbaTriggered);
    if (__VnbaExecute) {
        {
            // Inlined CFunc: _eval_body__nba
            if ((((1ULL & vlSelfRef.__VnbaTriggered[0U])) != 0ULL)) {
                Vtb_ramwin___024root___nba_sequent__TOP__0(vlSelf);
            }
            if ((((7ULL & vlSelfRef.__VnbaTriggered[0U])) != 0ULL)) {
                {
                    // Inlined CFunc: _nba_comb__TOP__0
                    ::CData/*0:0*/ __Vinline_0__eval_body__nba___Vinline_0__nba_comb__TOP__0___Vdfg_Regularize_84;
                    __Vinline_0__eval_body__nba___Vinline_0__nba_comb__TOP__0___Vdfg_Regularize_84 = 0;
                    ::CData/*0:0*/ __Vinline_0__eval_body__nba___Vinline_0__nba_comb__TOP__0___Vdfg_Regularize_85;
                    __Vinline_0__eval_body__nba___Vinline_0__nba_comb__TOP__0___Vdfg_Regularize_85 = 0;
                    __Vinline_0__eval_body__nba___Vinline_0__nba_comb__TOP__0___Vdfg_Regularize_84 
                        = (1U & (~ ((~ (::IData)(vlSelfRef.tb_ramwin__DOT___cpuAS)) 
                                    | (::IData)(vlSelfRef.tb_ramwin__DOT__ac__DOT__video_dma_off))));
                    vlSelfRef.tb_ramwin__DOT__ac__DOT__lsnd 
                        = ((::IData)(__Vinline_0__eval_body__nba___Vinline_0__nba_comb__TOP__0___Vdfg_Regularize_84) 
                           & (::IData)(vlSelfRef.tb_ramwin__DOT__ac__DOT__loadSound));
                    vlSelfRef.tb_ramwin__DOT__ac__DOT__lpx 
                        = ((::IData)(__Vinline_0__eval_body__nba___Vinline_0__nba_comb__TOP__0___Vdfg_Regularize_84) 
                           & (::IData)(vlSelfRef.tb_ramwin__DOT__ac__DOT__vt__DOT__loadPixels));
                    __Vinline_0__eval_body__nba___Vinline_0__nba_comb__TOP__0___Vdfg_Regularize_85 
                        = ((::IData)(vlSelfRef.tb_ramwin__DOT__ac__DOT__lpx) 
                           | (::IData)(vlSelfRef.tb_ramwin__DOT__ac__DOT__lsnd));
                    vlSelfRef.tb_ramwin__DOT____Vcellinp__sd__oe 
                        = (1U & (((~ (::IData)(vlSelfRef.tb_ramwin__DOT__clk_i__DOT__busCycle)) 
                                  & (::IData)(__Vinline_0__eval_body__nba___Vinline_0__nba_comb__TOP__0___Vdfg_Regularize_85)) 
                                 | ((~ (::IData)(vlSelfRef.tb_ramwin__DOT___cpuAS)) 
                                    & ((~ ((::IData)(vlSelfRef.tb_ramwin__DOT__clk_i__DOT__busCycle) 
                                           | (::IData)(__Vinline_0__eval_body__nba___Vinline_0__nba_comb__TOP__0___Vdfg_Regularize_85))) 
                                       | (::IData)(vlSelfRef.tb_ramwin__DOT__clk_i__DOT__busCycle)))));
                }
            }
        }
        Vtb_ramwin___024root___trigger_clear__act(vlSelfRef.__VnbaTriggered);
    }
    return (__VnbaExecute);
}

bool Vtb_ramwin___024root___eval_obs(Vtb_ramwin___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_ramwin___024root___eval_obs\n"); );
    Vtb_ramwin__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    return (0U);
}

bool Vtb_ramwin___024root___eval_react(Vtb_ramwin___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_ramwin___024root___eval_react\n"); );
    Vtb_ramwin__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    return (0U);
}

void Vtb_ramwin___024root___eval_postponed(Vtb_ramwin___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_ramwin___024root___eval_postponed\n"); );
    Vtb_ramwin__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
}

void Vtb_ramwin___024root____VbeforeTrig_h04e7b3b1__0(Vtb_ramwin___024root* vlSelf, const char* __VeventDescription);
void Vtb_ramwin___024root____VbeforeTrig_h5608d255__0(Vtb_ramwin___024root* vlSelf, const char* __VeventDescription);

VlCoroutine Vtb_ramwin___024root___eval_initial__TOP__Vtiming__0(Vtb_ramwin___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_ramwin___024root___eval_initial__TOP__Vtiming__0\n"); );
    Vtb_ramwin__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    ::IData/*31:0*/ tb_ramwin__DOT__unnamedblk1_1__DOT____Vrepeat0;
    tb_ramwin__DOT__unnamedblk1_1__DOT____Vrepeat0 = 0;
    ::IData/*31:0*/ tb_ramwin__DOT__unnamedblk1_2__DOT____Vrepeat1;
    tb_ramwin__DOT__unnamedblk1_2__DOT____Vrepeat1 = 0;
    // Body
    vlSelfRef.tb_ramwin__DOT__reset = 1U;
    tb_ramwin__DOT__unnamedblk1_1__DOT____Vrepeat0 = 0x0000000aU;
    while (VL_LTS_III(32, 0U, tb_ramwin__DOT__unnamedblk1_1__DOT____Vrepeat0)) {
        Vtb_ramwin___024root____VbeforeTrig_h04e7b3b1__0(vlSelf, 
                                                         "@(posedge tb_ramwin.clk)");
        co_await vlSelfRef.__Vnontrivs.__VtrigSched_h04e7b3b1__0.trigger(0U, 
                                                                         nullptr, 
                                                                         "@(posedge tb_ramwin.clk)", 
                                                                         "tb_ramwin.sv", 
                                                                         229);
        tb_ramwin__DOT__unnamedblk1_1__DOT____Vrepeat0 
            = (tb_ramwin__DOT__unnamedblk1_1__DOT____Vrepeat0 
               - (::IData)(1U));
    }
    vlSelfRef.tb_ramwin__DOT__reset = 0U;
    while ((0U != (::IData)(vlSelfRef.tb_ramwin__DOT__sd__DOT__init_state))) {
        Vtb_ramwin___024root____VbeforeTrig_h5608d255__0(vlSelf, 
                                                         "@( (~ (| tb_ramwin.sd.init_state)))");
        co_await vlSelfRef.__Vnontrivs.__VtrigSched_h5608d255__0.trigger(1U, 
                                                                         nullptr, 
                                                                         "@( (~ (| tb_ramwin.sd.init_state)))", 
                                                                         "tb_ramwin.sv", 
                                                                         231);
    }
    tb_ramwin__DOT__unnamedblk1_2__DOT____Vrepeat1 = 4U;
    while (VL_LTS_III(32, 0U, tb_ramwin__DOT__unnamedblk1_2__DOT____Vrepeat1)) {
        Vtb_ramwin___024root____VbeforeTrig_h04e7b3b1__0(vlSelf, 
                                                         "@(posedge tb_ramwin.clk)");
        co_await vlSelfRef.__Vnontrivs.__VtrigSched_h04e7b3b1__0.trigger(0U, 
                                                                         nullptr, 
                                                                         "@(posedge tb_ramwin.clk)", 
                                                                         "tb_ramwin.sv", 
                                                                         232);
        tb_ramwin__DOT__unnamedblk1_2__DOT____Vrepeat1 
            = (tb_ramwin__DOT__unnamedblk1_2__DOT____Vrepeat1 
               - (::IData)(1U));
    }
    co_await vlSelfRef.__Vnontrivs.__VdlySched.delay(0x0000000000989e50ULL, 
                                                     nullptr, 
                                                     "tb_ramwin.sv", 
                                                     235);
    vlSelfRef.tb_ramwin__DOT___cpuAS = 1U;
    co_return;
}

VlCoroutine Vtb_ramwin___024root___eval_initial__TOP__Vtiming__1(Vtb_ramwin___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_ramwin___024root___eval_initial__TOP__Vtiming__1\n"); );
    Vtb_ramwin__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    while (VL_LIKELY(!vlSymsp->_vm_contextp__->gotFinish())) {
        co_await vlSelfRef.__Vnontrivs.__VdlySched.delay(0x0000000000001388ULL, 
                                                         nullptr, 
                                                         "tb_ramwin.sv", 
                                                         45);
        vlSelfRef.tb_ramwin__DOT__clk = (1U & (~ (::IData)(vlSelfRef.tb_ramwin__DOT__clk)));
    }
    co_return;
}

bool Vtb_ramwin___024root___trigger_anySet__ico(const ::VlUnpacked<::QData/*63:0*/, 1> &in) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_ramwin___024root___trigger_anySet__ico\n"); );
    // Locals
    ::IData/*31:0*/ n;
    // Body
    n = 0U;
    do {
        if (in[n]) {
            return (1U);
        }
        n = ((::IData)(1U) + n);
    } while ((1U > n));
    return (0U);
}

bool Vtb_ramwin___024root___trigger_anySet__act(const ::VlUnpacked<::QData/*63:0*/, 1> &in) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_ramwin___024root___trigger_anySet__act\n"); );
    // Locals
    ::IData/*31:0*/ n;
    // Body
    n = 0U;
    do {
        if (in[n]) {
            return (1U);
        }
        n = ((::IData)(1U) + n);
    } while ((1U > n));
    return (0U);
}

void Vtb_ramwin___024root___nba_sequent__TOP__0(Vtb_ramwin___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_ramwin___024root___nba_sequent__TOP__0\n"); );
    Vtb_ramwin__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    ::IData/*20:0*/ __Vdly__tb_ramwin__DOT__ac__DOT__audioAddr_2;
    __Vdly__tb_ramwin__DOT__ac__DOT__audioAddr_2 = 0;
    ::SData/*9:0*/ __Vdly__tb_ramwin__DOT__ac__DOT__vt__DOT__xpos_5;
    __Vdly__tb_ramwin__DOT__ac__DOT__vt__DOT__xpos_5 = 0;
    ::SData/*8:0*/ __Vdly__tb_ramwin__DOT__ac__DOT__vt__DOT__ypos_6;
    __Vdly__tb_ramwin__DOT__ac__DOT__vt__DOT__ypos_6 = 0;
    ::CData/*2:0*/ __Vdly__tb_ramwin__DOT__sd__DOT__state_7;
    __Vdly__tb_ramwin__DOT__sd__DOT__state_7 = 0;
    ::CData/*4:0*/ __Vdly__tb_ramwin__DOT__sd__DOT__init_state_8;
    __Vdly__tb_ramwin__DOT__sd__DOT__init_state_8 = 0;
    ::CData/*2:0*/ __Vdly__tb_ramwin__DOT__clk_i__DOT__busPhase_10;
    __Vdly__tb_ramwin__DOT__clk_i__DOT__busPhase_10 = 0;
    // Body
    __Vdly__tb_ramwin__DOT__sd__DOT__init_state_8 = vlSelfRef.tb_ramwin__DOT__sd__DOT__init_state;
    __Vdly__tb_ramwin__DOT__clk_i__DOT__busPhase_10 
        = vlSelfRef.tb_ramwin__DOT__clk_i__DOT__busPhase;
    __Vdly__tb_ramwin__DOT__sd__DOT__state_7 = vlSelfRef.tb_ramwin__DOT__sd__DOT__state;
    __Vdly__tb_ramwin__DOT__ac__DOT__vt__DOT__ypos_6 
        = vlSelfRef.tb_ramwin__DOT__ac__DOT__vt__DOT__ypos;
    __Vdly__tb_ramwin__DOT__ac__DOT__vt__DOT__xpos_5 
        = vlSelfRef.tb_ramwin__DOT__ac__DOT__vt__DOT__xpos;
    __Vdly__tb_ramwin__DOT__ac__DOT__audioAddr_2 = vlSelfRef.tb_ramwin__DOT__ac__DOT__audioAddr;
    if ((1U & (~ (::IData)(vlSelfRef.tb_ramwin__DOT__reset)))) {
        if (vlSelfRef.tb_ramwin__DOT__chk_pending) {
            if (((0x001fffffU & vlSelfRef.tb_ramwin__DOT__sd__DOT__rd_addr_r) 
                 == vlSelfRef.tb_ramwin__DOT__chk_expect)) {
                if ((0U == (::IData)(vlSelfRef.tb_ramwin__DOT__chk_owner))) {
                    vlSelfRef.tb_ramwin__DOT__cpu_ok 
                        = ((::IData)(1U) + vlSelfRef.tb_ramwin__DOT__cpu_ok);
                } else if ((1U == (::IData)(vlSelfRef.tb_ramwin__DOT__chk_owner))) {
                    vlSelfRef.tb_ramwin__DOT__vid_ok 
                        = ((::IData)(1U) + vlSelfRef.tb_ramwin__DOT__vid_ok);
                } else if ((2U == (::IData)(vlSelfRef.tb_ramwin__DOT__chk_owner))) {
                    vlSelfRef.tb_ramwin__DOT__snd_ok 
                        = ((::IData)(1U) + vlSelfRef.tb_ramwin__DOT__snd_ok);
                }
            } else {
                vlSelfRef.tb_ramwin__DOT__fails = ((::IData)(1U) 
                                                   + vlSelfRef.tb_ramwin__DOT__fails);
                if (VL_UNLIKELY((VL_GTES_III(32, 0x0000000cU, vlSelfRef.tb_ramwin__DOT__fails)))) {
                    VL_WRITEF_NX("*** MISMATCH @tick %0d: rd_addr=%06h expect=%06h owner=%b lp=%b ls=%b vbm=%b\n",7
                                 , '~',32,vlSelfRef.tb_ramwin__DOT__ticks
                                 , '#',21,(0x001fffffU 
                                           & vlSelfRef.tb_ramwin__DOT__sd__DOT__rd_addr_r)
                                 , '#',21,vlSelfRef.tb_ramwin__DOT__chk_expect
                                 , '#',2,(::IData)(vlSelfRef.tb_ramwin__DOT__chk_owner)
                                 , '#',1,vlSelfRef.tb_ramwin__DOT__ac__DOT__vt__DOT__loadPixels
                                 , '#',1,(::IData)(vlSelfRef.tb_ramwin__DOT__ac__DOT__loadSound)
                                 , '#',1,(1U & (~ (::IData)(vlSelfRef.tb_ramwin__DOT__clk_i__DOT__busCycle))));
                }
            }
            vlSelfRef.tb_ramwin__DOT__chk_pending = 0U;
        }
        if (((~ (0U != (::IData)(vlSelfRef.tb_ramwin__DOT__sd__DOT__init_state))) 
             & (2U == (::IData)(vlSelfRef.tb_ramwin__DOT__clk_i__DOT__busPhase)))) {
            if (vlSelfRef.tb_ramwin__DOT____Vcellinp__sd__oe) {
                vlSelfRef.tb_ramwin__DOT__chk_pending = 1U;
                if (vlSelfRef.tb_ramwin__DOT___cpuAS) {
                    if (vlSelfRef.tb_ramwin__DOT__ac__DOT__vt__DOT__loadPixels) {
                        vlSelfRef.tb_ramwin__DOT__chk_expect 
                            = vlSelfRef.tb_ramwin__DOT__ac__DOT__vt__DOT__videoAddr;
                        vlSelfRef.tb_ramwin__DOT__chk_owner = 1U;
                        vlSelfRef.tb_ramwin__DOT__vid_fetches 
                            = ((::IData)(1U) + vlSelfRef.tb_ramwin__DOT__vid_fetches);
                    } else if (vlSelfRef.tb_ramwin__DOT__ac__DOT__loadSound) {
                        vlSelfRef.tb_ramwin__DOT__chk_expect 
                            = vlSelfRef.tb_ramwin__DOT__ac__DOT__audioAddr;
                        vlSelfRef.tb_ramwin__DOT__chk_owner = 2U;
                        vlSelfRef.tb_ramwin__DOT__snd_fetches 
                            = ((::IData)(1U) + vlSelfRef.tb_ramwin__DOT__snd_fetches);
                    } else {
                        vlSelfRef.tb_ramwin__DOT__chk_pending = 0U;
                    }
                } else {
                    vlSelfRef.tb_ramwin__DOT__chk_expect = 0x0000001fU;
                    vlSelfRef.tb_ramwin__DOT__chk_owner = 0U;
                    vlSelfRef.tb_ramwin__DOT__cpu_fetches 
                        = ((::IData)(1U) + vlSelfRef.tb_ramwin__DOT__cpu_fetches);
                }
            }
        }
        vlSelfRef.tb_ramwin__DOT__ticks = ((::IData)(1U) 
                                           + vlSelfRef.tb_ramwin__DOT__ticks);
        if (VL_UNLIKELY(((0x00000fa0U == vlSelfRef.tb_ramwin__DOT__ticks)))) {
            VL_WRITEF_NX("===================================================\nticks=%0d  cpu-fetches=%0d ok=%0d  video-fetches=%0d ok=%0d  audio-fetches=%0d ok=%0d\nMISMATCHES: %0d\n",8
                         , '~',32,vlSelfRef.tb_ramwin__DOT__ticks
                         , '~',32,vlSelfRef.tb_ramwin__DOT__cpu_fetches
                         , '~',32,vlSelfRef.tb_ramwin__DOT__cpu_ok
                         , '~',32,vlSelfRef.tb_ramwin__DOT__vid_fetches
                         , '~',32,vlSelfRef.tb_ramwin__DOT__vid_ok
                         , '~',32,vlSelfRef.tb_ramwin__DOT__snd_fetches
                         , '~',32,vlSelfRef.tb_ramwin__DOT__snd_ok
                         , '~',32,vlSelfRef.tb_ramwin__DOT__fails);
            if (VL_UNLIKELY((((0U == vlSelfRef.tb_ramwin__DOT__fails) 
                              & VL_LTS_III(32, 0U, vlSelfRef.tb_ramwin__DOT__cpu_fetches))))) {
                VL_WRITEF_NX("RESULT: PASS - every CPU RAM access wins its phase-2 SDRAM slot\n",0);
            } else if (VL_LTS_III(32, 0U, vlSelfRef.tb_ramwin__DOT__fails)) {
                VL_WRITEF_NX("RESULT: FAIL - %0d fetch(es) not serviced for the requesting owner\n",1
                             , '~',32,vlSelfRef.tb_ramwin__DOT__fails);
            } else {
                VL_WRITEF_NX("RESULT: INCONCLUSIVE - no CPU fetches observed\n",0);
            }
            VL_WRITEF_NX("===================================================\n",0);
            VL_FINISH_MT("tb_ramwin.sv", 222, "");
        }
    }
    if (vlSelfRef.tb_ramwin__DOT__reset) {
        __Vdly__tb_ramwin__DOT__sd__DOT__init_state_8 = 0x1fU;
        __Vdly__tb_ramwin__DOT__sd__DOT__state_7 = 0U;
    } else {
        if (((4U == (::IData)(vlSelfRef.tb_ramwin__DOT__sd__DOT__state)) 
             & (0U != (::IData)(vlSelfRef.tb_ramwin__DOT__sd__DOT__init_state)))) {
            __Vdly__tb_ramwin__DOT__sd__DOT__init_state_8 
                = (0x0000001fU & ((::IData)(vlSelfRef.tb_ramwin__DOT__sd__DOT__init_state) 
                                  - (::IData)(1U)));
        }
        if ((0U != (::IData)(vlSelfRef.tb_ramwin__DOT__sd__DOT__init_state))) {
            __Vdly__tb_ramwin__DOT__sd__DOT__state_7 
                = (7U & ((::IData)(1U) + (::IData)(vlSelfRef.tb_ramwin__DOT__sd__DOT__state)));
        }
    }
    __Vdly__tb_ramwin__DOT__clk_i__DOT__busPhase_10 
        = (7U & ((::IData)(1U) + (::IData)(vlSelfRef.tb_ramwin__DOT__clk_i__DOT__busPhase)));
    if ((0U == (::IData)(vlSelfRef.tb_ramwin__DOT__sd__DOT__init_state))) {
        if ((0U == (::IData)(vlSelfRef.tb_ramwin__DOT__sd__DOT__state))) {
            if ((2U == (::IData)(vlSelfRef.tb_ramwin__DOT__clk_i__DOT__busPhase))) {
                if (vlSelfRef.tb_ramwin__DOT____Vcellinp__sd__oe) {
                    __Vdly__tb_ramwin__DOT__sd__DOT__state_7 = 1U;
                    vlSelfRef.tb_ramwin__DOT__sd__DOT__rd_addr_r 
                        = ((::IData)(vlSelfRef.tb_ramwin__DOT__ac__DOT__lpx)
                            ? vlSelfRef.tb_ramwin__DOT__ac__DOT__vt__DOT__videoAddr
                            : ((::IData)(vlSelfRef.tb_ramwin__DOT__ac__DOT__lsnd)
                                ? vlSelfRef.tb_ramwin__DOT__ac__DOT__audioAddr
                                : 0x0000001fU));
                }
            }
        } else {
            __Vdly__tb_ramwin__DOT__sd__DOT__state_7 
                = (7U & ((::IData)(1U) + (::IData)(vlSelfRef.tb_ramwin__DOT__sd__DOT__state)));
            if ((4U == (::IData)(vlSelfRef.tb_ramwin__DOT__sd__DOT__state))) {
                __Vdly__tb_ramwin__DOT__sd__DOT__state_7 = 0U;
            }
        }
    }
    if ((0x02bfU == (::IData)(vlSelfRef.tb_ramwin__DOT__ac__DOT__vt__DOT__xpos))) {
        __Vdly__tb_ramwin__DOT__ac__DOT__vt__DOT__ypos_6 
            = ((0x0171U == (::IData)(vlSelfRef.tb_ramwin__DOT__ac__DOT__vt__DOT__ypos))
                ? 0U : (0x000001ffU & ((::IData)(1U) 
                                       + (::IData)(vlSelfRef.tb_ramwin__DOT__ac__DOT__vt__DOT__ypos))));
        __Vdly__tb_ramwin__DOT__ac__DOT__vt__DOT__xpos_5 = 0U;
    } else {
        __Vdly__tb_ramwin__DOT__ac__DOT__vt__DOT__xpos_5 
            = (((0U == (::IData)(vlSelfRef.tb_ramwin__DOT__ac__DOT__vt__DOT__xpos)) 
                & (::IData)(vlSelfRef.tb_ramwin__DOT__clk_i__DOT__busCycle))
                ? 0U : (0x000003ffU & ((::IData)(1U) 
                                       + (::IData)(vlSelfRef.tb_ramwin__DOT__ac__DOT__vt__DOT__xpos))));
    }
    if ((7U == (::IData)(vlSelfRef.tb_ramwin__DOT__clk_i__DOT__busPhase))) {
        vlSelfRef.tb_ramwin__DOT__clk_i__DOT__busCycle 
            = (1U & (~ (::IData)(vlSelfRef.tb_ramwin__DOT__clk_i__DOT__busCycle)));
        vlSelfRef.tb_ramwin__DOT__ac__DOT__sndReqCycle 
            = vlSelfRef.tb_ramwin__DOT__ac__DOT__sndReq;
        if (vlSelfRef.tb_ramwin__DOT__ac__DOT__loadSound) {
            __Vdly__tb_ramwin__DOT__ac__DOT__audioAddr_2 
                = (0x001fffffU & ((::IData)(1U) + vlSelfRef.tb_ramwin__DOT__ac__DOT__audioAddr));
            vlSelfRef.tb_ramwin__DOT__ac__DOT__sndReq = 0U;
        }
    }
    if ((1U & (::IData)(vlSelfRef.tb_ramwin__DOT__clk_i__DOT__busPhase))) {
        if (((::IData)(vlSelfRef.tb_ramwin__DOT__ac__DOT__vblankD) 
             & (0x0156U <= (::IData)(vlSelfRef.tb_ramwin__DOT__ac__DOT__vt__DOT__ypos)))) {
            __Vdly__tb_ramwin__DOT__ac__DOT__audioAddr_2 = 0x001ffe80U;
        }
        if ((1U & (~ ((::IData)(vlSelfRef.tb_ramwin__DOT__ac__DOT__vblankD) 
                      & (0x0156U <= (::IData)(vlSelfRef.tb_ramwin__DOT__ac__DOT__vt__DOT__ypos)))))) {
            if (((::IData)(vlSelfRef.tb_ramwin__DOT__ac__DOT__hblankD) 
                 & (0x0208U <= (::IData)(vlSelfRef.tb_ramwin__DOT__ac__DOT__vt__DOT__xpos)))) {
                vlSelfRef.tb_ramwin__DOT__ac__DOT__sndReq = 1U;
            }
        }
        vlSelfRef.tb_ramwin__DOT__ac__DOT__hblankD 
            = (0x0208U > (::IData)(vlSelfRef.tb_ramwin__DOT__ac__DOT__vt__DOT__xpos));
        vlSelfRef.tb_ramwin__DOT__ac__DOT__vblankD 
            = (0x0156U > (::IData)(vlSelfRef.tb_ramwin__DOT__ac__DOT__vt__DOT__ypos));
    }
    vlSelfRef.tb_ramwin__DOT__sd__DOT__state = __Vdly__tb_ramwin__DOT__sd__DOT__state_7;
    vlSelfRef.tb_ramwin__DOT__ac__DOT__audioAddr = __Vdly__tb_ramwin__DOT__ac__DOT__audioAddr_2;
    vlSelfRef.tb_ramwin__DOT__sd__DOT__init_state = __Vdly__tb_ramwin__DOT__sd__DOT__init_state_8;
    vlSelfRef.tb_ramwin__DOT__ac__DOT__loadSound = 
        ((~ (::IData)(vlSelfRef.tb_ramwin__DOT__clk_i__DOT__busCycle)) 
         & (::IData)(vlSelfRef.tb_ramwin__DOT__ac__DOT__sndReqCycle));
    vlSelfRef.tb_ramwin__DOT__ac__DOT__vt__DOT__xpos 
        = __Vdly__tb_ramwin__DOT__ac__DOT__vt__DOT__xpos_5;
    vlSelfRef.tb_ramwin__DOT__clk_i__DOT__busPhase 
        = __Vdly__tb_ramwin__DOT__clk_i__DOT__busPhase_10;
    vlSelfRef.tb_ramwin__DOT__ac__DOT__vt__DOT__ypos 
        = __Vdly__tb_ramwin__DOT__ac__DOT__vt__DOT__ypos_6;
    vlSelfRef.tb_ramwin__DOT__ac__DOT__vt__DOT__videoAddr 
        = (0x001fffffU & ((::IData)(0x001f9380U) + 
                          (((::IData)(vlSelfRef.tb_ramwin__DOT__ac__DOT__vt__DOT__ypos) 
                            << 5U) | (0x0000001fU & 
                                      ((::IData)(vlSelfRef.tb_ramwin__DOT__ac__DOT__vt__DOT__xpos) 
                                       >> 4U)))));
    vlSelfRef.tb_ramwin__DOT__ac__DOT__vt__DOT__loadPixels 
        = ((0x0156U > (::IData)(vlSelfRef.tb_ramwin__DOT__ac__DOT__vt__DOT__ypos)) 
           & ((~ (::IData)(vlSelfRef.tb_ramwin__DOT__clk_i__DOT__busCycle)) 
              & ((~ ((::IData)(vlSelfRef.tb_ramwin__DOT__ac__DOT__vt__DOT__xpos) 
                     >> 3U)) & (0x0200U > (::IData)(vlSelfRef.tb_ramwin__DOT__ac__DOT__vt__DOT__xpos)))));
}

void Vtb_ramwin___024root___timing_ready(Vtb_ramwin___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_ramwin___024root___timing_ready\n"); );
    Vtb_ramwin__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    if ((((1ULL & vlSelfRef.__VactTriggered[0U])) != 0ULL)) {
        vlSelfRef.__Vnontrivs.__VtrigSched_h04e7b3b1__0.ready(
                                                              "@(posedge tb_ramwin.clk)");
    }
    if ((((2ULL & vlSelfRef.__VactTriggered[0U])) != 0ULL)) {
        vlSelfRef.__Vnontrivs.__VtrigSched_h5608d255__0.ready(
                                                              "@( (~ (| tb_ramwin.sd.init_state)))");
    }
}

void Vtb_ramwin___024root___timing_resume(Vtb_ramwin___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_ramwin___024root___timing_resume\n"); );
    Vtb_ramwin__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    vlSelfRef.__Vnontrivs.__VtrigSched_h04e7b3b1__0.moveToResumeQueue(
                                                                      "@(posedge tb_ramwin.clk)");
    vlSelfRef.__Vnontrivs.__VtrigSched_h5608d255__0.moveToResumeQueue(
                                                                      "@( (~ (| tb_ramwin.sd.init_state)))");
    vlSelfRef.__Vnontrivs.__VtrigSched_h04e7b3b1__0.resume(
                                                           "@(posedge tb_ramwin.clk)");
    vlSelfRef.__Vnontrivs.__VtrigSched_h5608d255__0.resume(
                                                           "@( (~ (| tb_ramwin.sd.init_state)))");
    if ((((4ULL & vlSelfRef.__VactTriggered[0U])) != 0ULL)) {
        vlSelfRef.__Vnontrivs.__VdlySched.resume();
    }
}

void Vtb_ramwin___024root___trigger_orInto__act_vec_vec(::VlUnpacked<::QData/*63:0*/, 1> &out, const ::VlUnpacked<::QData/*63:0*/, 1> &in) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_ramwin___024root___trigger_orInto__act_vec_vec\n"); );
    // Locals
    ::IData/*31:0*/ n;
    // Body
    n = 0U;
    do {
        out[n] = (out[n] | in[n]);
        n = ((::IData)(1U) + n);
    } while ((0U >= n));
}

void Vtb_ramwin___024root___trigger_clear__act(::VlUnpacked<::QData/*63:0*/, 1> &out) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_ramwin___024root___trigger_clear__act\n"); );
    // Locals
    ::IData/*31:0*/ n;
    // Body
    n = 0U;
    do {
        out[n] = 0ULL;
        n = ((::IData)(1U) + n);
    } while ((1U > n));
}

void Vtb_ramwin___024root____VbeforeTrig_h04e7b3b1__0(Vtb_ramwin___024root* vlSelf, const char* __VeventDescription) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_ramwin___024root____VbeforeTrig_h04e7b3b1__0\n"); );
    Vtb_ramwin__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    ::VlUnpacked<::QData/*63:0*/, 1> __VTmp;
    // Body
    __VTmp[0U] = (::QData)((::IData)(((::IData)(vlSelfRef.tb_ramwin__DOT__clk) 
                                      & (~ (::IData)(vlSelfRef.__Vtrigprevexpr___TOP__tb_ramwin__DOT__clk__0)))));
    vlSelfRef.__Vtrigprevexpr___TOP__tb_ramwin__DOT__clk__0 
        = vlSelfRef.tb_ramwin__DOT__clk;
    if ((1ULL & __VTmp[0U])) {
        vlSelfRef.__Vnontrivs.__VtrigSched_h04e7b3b1__0.ready(__VeventDescription);
        vlSelfRef.__Vnontrivs.__VtrigSched_h04e7b3b1__0.ready(__VeventDescription);
    }
    vlSelfRef.__VactTriggeredAcc[0U] = (vlSelfRef.__VactTriggeredAcc[0U] 
                                        | __VTmp[0U]);
}

void Vtb_ramwin___024root____VbeforeTrig_h5608d255__0(Vtb_ramwin___024root* vlSelf, const char* __VeventDescription) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_ramwin___024root____VbeforeTrig_h5608d255__0\n"); );
    Vtb_ramwin__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    ::VlUnpacked<::QData/*63:0*/, 1> __VTmp;
    ::CData/*0:0*/ __Vtrigprevexpr_h721d1614__0;
    __Vtrigprevexpr_h721d1614__0 = 0;
    // Body
    __Vtrigprevexpr_h721d1614__0 = (1U & (~ (0U != (::IData)(vlSelfRef.tb_ramwin__DOT__sd__DOT__init_state))));
    __VTmp[0U] = (::QData)((::IData)((((::IData)(__Vtrigprevexpr_h721d1614__0) 
                                       != (::IData)(vlSelfRef.__Vtrigprevexpr_h721d1614__1)) 
                                      << 1U)));
    vlSelfRef.__Vtrigprevexpr_h721d1614__1 = __Vtrigprevexpr_h721d1614__0;
    if ((2ULL & __VTmp[0U])) {
        vlSelfRef.__Vnontrivs.__VtrigSched_h5608d255__0.ready(__VeventDescription);
    }
    vlSelfRef.__VactTriggeredAcc[0U] = (vlSelfRef.__VactTriggeredAcc[0U] 
                                        | __VTmp[0U]);
}

#ifdef VL_DEBUG
void Vtb_ramwin___024root___eval_debug_assertions(Vtb_ramwin___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_ramwin___024root___eval_debug_assertions\n"); );
    Vtb_ramwin__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
}
#endif  // VL_DEBUG
