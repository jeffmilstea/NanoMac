// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vtb_ramwin.h for the primary calling header

#include "Vtb_ramwin__pch.h"

void Vtb_ramwin___024root___timing_ready(Vtb_ramwin___024root* vlSelf);

VL_ATTR_COLD void Vtb_ramwin___024root___eval_static(Vtb_ramwin___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_ramwin___024root___eval_static\n"); );
    Vtb_ramwin__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    {
        // Inlined CFunc: _eval_static__TOP
        vlSelfRef.tb_ramwin__DOT__clk = 0U;
        vlSelfRef.tb_ramwin__DOT__reset = 1U;
        vlSelfRef.tb_ramwin__DOT___cpuAS = 0U;
        vlSelfRef.tb_ramwin__DOT__chk_pending = 0U;
        vlSelfRef.tb_ramwin__DOT__ticks = 0U;
        vlSelfRef.tb_ramwin__DOT__fails = 0U;
        vlSelfRef.tb_ramwin__DOT__cpu_fetches = 0U;
        vlSelfRef.tb_ramwin__DOT__cpu_ok = 0U;
        vlSelfRef.tb_ramwin__DOT__vid_fetches = 0U;
        vlSelfRef.tb_ramwin__DOT__vid_ok = 0U;
        vlSelfRef.tb_ramwin__DOT__snd_fetches = 0U;
        vlSelfRef.tb_ramwin__DOT__snd_ok = 0U;
    }
    vlSelfRef.__VactTriggered[0U] = (2ULL | vlSelfRef.__VactTriggered[0U]);
    vlSelfRef.__Vtrigprevexpr___TOP__tb_ramwin__DOT__clk__0 = 0U;
    vlSelfRef.__Vtrigprevexpr_h721d1614__1 = (1U & 
                                              (~ (0U 
                                                  != (::IData)(vlSelfRef.tb_ramwin__DOT__sd__DOT__init_state))));
    Vtb_ramwin___024root___timing_ready(vlSelf);
    do {
        vlSelfRef.__VactTriggeredAcc[vlSelfRef.__Vi] 
            = vlSelfRef.__VactTriggered[vlSelfRef.__Vi];
        vlSelfRef.__Vi = ((::IData)(1U) + vlSelfRef.__Vi);
    } while ((0U >= vlSelfRef.__Vi));
}

#ifdef VL_DEBUG
VL_ATTR_COLD void Vtb_ramwin___024root___dump_triggers__stl(const ::VlUnpacked<::QData/*63:0*/, 1> &triggers, const ::std::string &tag);
#endif  // VL_DEBUG
VL_ATTR_COLD bool Vtb_ramwin___024root___trigger_anySet__stl(const ::VlUnpacked<::QData/*63:0*/, 1> &in);

VL_ATTR_COLD bool Vtb_ramwin___024root___eval_stl(Vtb_ramwin___024root* vlSelf, ::CData/*0:0*/ firstIteration) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_ramwin___024root___eval_stl\n"); );
    Vtb_ramwin__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    ::CData/*0:0*/ __VstlExecute;
    // Body
    vlSelfRef.__VstlTriggered[0U] = ((0xfffffffffffffffeULL 
                                      & vlSelfRef.__VstlTriggered[0U]) 
                                     | (::IData)((::IData)(firstIteration)));
#ifdef VL_DEBUG
    if (VL_UNLIKELY(vlSymsp->_vm_contextp__->debug())) {
        Vtb_ramwin___024root___dump_triggers__stl(vlSelfRef.__VstlTriggered, "stl"s);
    }
#endif
    __VstlExecute = Vtb_ramwin___024root___trigger_anySet__stl(vlSelfRef.__VstlTriggered);
    if (__VstlExecute) {
        {
            // Inlined CFunc: _eval_body__stl
            if ((((1ULL & vlSelfRef.__VstlTriggered[0U])) != 0ULL)) {
                {
                    // Inlined CFunc: _stl_comb__TOP__0
                    ::CData/*0:0*/ __Vinline_0__eval_body__stl___Vinline_0__stl_comb__TOP__0___Vdfg_Regularize_84;
                    __Vinline_0__eval_body__stl___Vinline_0__stl_comb__TOP__0___Vdfg_Regularize_84 = 0;
                    ::CData/*0:0*/ __Vinline_0__eval_body__stl___Vinline_0__stl_comb__TOP__0___Vdfg_Regularize_85;
                    __Vinline_0__eval_body__stl___Vinline_0__stl_comb__TOP__0___Vdfg_Regularize_85 = 0;
                    vlSelfRef.tb_ramwin__DOT__ac__DOT__vt__DOT__videoAddr 
                        = (0x001fffffU & ((::IData)(0x001f9380U) 
                                          + (((::IData)(vlSelfRef.tb_ramwin__DOT__ac__DOT__vt__DOT__ypos) 
                                              << 5U) 
                                             | (0x0000001fU 
                                                & ((::IData)(vlSelfRef.tb_ramwin__DOT__ac__DOT__vt__DOT__xpos) 
                                                   >> 4U)))));
                    vlSelfRef.tb_ramwin__DOT__ac__DOT__loadSound 
                        = ((~ (::IData)(vlSelfRef.tb_ramwin__DOT__clk_i__DOT__busCycle)) 
                           & (::IData)(vlSelfRef.tb_ramwin__DOT__ac__DOT__sndReqCycle));
                    vlSelfRef.tb_ramwin__DOT__ac__DOT__vt__DOT__loadPixels 
                        = ((0x0156U > (::IData)(vlSelfRef.tb_ramwin__DOT__ac__DOT__vt__DOT__ypos)) 
                           & ((~ (::IData)(vlSelfRef.tb_ramwin__DOT__clk_i__DOT__busCycle)) 
                              & ((~ ((::IData)(vlSelfRef.tb_ramwin__DOT__ac__DOT__vt__DOT__xpos) 
                                     >> 3U)) & (0x0200U 
                                                > (::IData)(vlSelfRef.tb_ramwin__DOT__ac__DOT__vt__DOT__xpos)))));
                    __Vinline_0__eval_body__stl___Vinline_0__stl_comb__TOP__0___Vdfg_Regularize_84 
                        = (1U & (~ ((~ (::IData)(vlSelfRef.tb_ramwin__DOT___cpuAS)) 
                                    | (::IData)(vlSelfRef.tb_ramwin__DOT__ac__DOT__video_dma_off))));
                    vlSelfRef.tb_ramwin__DOT__ac__DOT__lpx 
                        = ((::IData)(__Vinline_0__eval_body__stl___Vinline_0__stl_comb__TOP__0___Vdfg_Regularize_84) 
                           & (::IData)(vlSelfRef.tb_ramwin__DOT__ac__DOT__vt__DOT__loadPixels));
                    vlSelfRef.tb_ramwin__DOT__ac__DOT__lsnd 
                        = ((::IData)(__Vinline_0__eval_body__stl___Vinline_0__stl_comb__TOP__0___Vdfg_Regularize_84) 
                           & (::IData)(vlSelfRef.tb_ramwin__DOT__ac__DOT__loadSound));
                    __Vinline_0__eval_body__stl___Vinline_0__stl_comb__TOP__0___Vdfg_Regularize_85 
                        = ((::IData)(vlSelfRef.tb_ramwin__DOT__ac__DOT__lpx) 
                           | (::IData)(vlSelfRef.tb_ramwin__DOT__ac__DOT__lsnd));
                    vlSelfRef.tb_ramwin__DOT____Vcellinp__sd__oe 
                        = (1U & (((~ (::IData)(vlSelfRef.tb_ramwin__DOT__clk_i__DOT__busCycle)) 
                                  & (::IData)(__Vinline_0__eval_body__stl___Vinline_0__stl_comb__TOP__0___Vdfg_Regularize_85)) 
                                 | ((~ (::IData)(vlSelfRef.tb_ramwin__DOT___cpuAS)) 
                                    & ((~ ((::IData)(vlSelfRef.tb_ramwin__DOT__clk_i__DOT__busCycle) 
                                           | (::IData)(__Vinline_0__eval_body__stl___Vinline_0__stl_comb__TOP__0___Vdfg_Regularize_85))) 
                                       | (::IData)(vlSelfRef.tb_ramwin__DOT__clk_i__DOT__busCycle)))));
                }
            }
        }
    }
    return (__VstlExecute);
}

VL_ATTR_COLD void Vtb_ramwin___024root___eval_dump_triggers__stl(Vtb_ramwin___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_ramwin___024root___eval_dump_triggers__stl\n"); );
    Vtb_ramwin__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
#ifdef VL_DEBUG
    Vtb_ramwin___024root___dump_triggers__stl(vlSelfRef.__VstlTriggered, "stl"s);
#endif
}

#ifdef VL_DEBUG
VL_ATTR_COLD void Vtb_ramwin___024root___dump_triggers__ico(const ::VlUnpacked<::QData/*63:0*/, 1> &triggers, const ::std::string &tag);
#endif  // VL_DEBUG

VL_ATTR_COLD void Vtb_ramwin___024root___eval_dump_triggers__ico(Vtb_ramwin___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_ramwin___024root___eval_dump_triggers__ico\n"); );
    Vtb_ramwin__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
#ifdef VL_DEBUG
    Vtb_ramwin___024root___dump_triggers__ico(vlSelfRef.__VicoTriggered, "ico"s);
#endif
}

#ifdef VL_DEBUG
VL_ATTR_COLD void Vtb_ramwin___024root___dump_triggers__act(const ::VlUnpacked<::QData/*63:0*/, 1> &triggers, const ::std::string &tag);
#endif  // VL_DEBUG

VL_ATTR_COLD void Vtb_ramwin___024root___eval_dump_triggers__act(Vtb_ramwin___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_ramwin___024root___eval_dump_triggers__act\n"); );
    Vtb_ramwin__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
#ifdef VL_DEBUG
    Vtb_ramwin___024root___dump_triggers__act(vlSelfRef.__VactTriggered, "act"s);
#endif
}

VL_ATTR_COLD void Vtb_ramwin___024root___eval_dump_triggers__nba(Vtb_ramwin___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_ramwin___024root___eval_dump_triggers__nba\n"); );
    Vtb_ramwin__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
#ifdef VL_DEBUG
    Vtb_ramwin___024root___dump_triggers__act(vlSelfRef.__VnbaTriggered, "nba"s);
#endif
}

VL_ATTR_COLD void Vtb_ramwin___024root___eval_dump_triggers__obs(Vtb_ramwin___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_ramwin___024root___eval_dump_triggers__obs\n"); );
    Vtb_ramwin__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
}

VL_ATTR_COLD void Vtb_ramwin___024root___eval_dump_triggers__react(Vtb_ramwin___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_ramwin___024root___eval_dump_triggers__react\n"); );
    Vtb_ramwin__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
}

VL_ATTR_COLD void Vtb_ramwin___024root___eval_final(Vtb_ramwin___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_ramwin___024root___eval_final\n"); );
    Vtb_ramwin__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
}

#ifdef VL_DEBUG
VL_ATTR_COLD void Vtb_ramwin___024root___dump_triggers__stl(const ::VlUnpacked<::QData/*63:0*/, 1> &triggers, const ::std::string &tag) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_ramwin___024root___dump_triggers__stl\n"); );
    // Body
    if ((1U & (~ (::IData)(Vtb_ramwin___024root___trigger_anySet__stl(triggers))))) {
        VL_DBG_MSGS("         No '" + tag + "' region triggers active\n");
    }
    if ((1U & (::IData)(triggers[0U]))) {
        VL_DBG_MSGS("         '" + tag + "' region trigger index 0 is active: Internal 'stl' trigger - first iteration\n");
    }
}
#endif  // VL_DEBUG

VL_ATTR_COLD bool Vtb_ramwin___024root___trigger_anySet__stl(const ::VlUnpacked<::QData/*63:0*/, 1> &in) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_ramwin___024root___trigger_anySet__stl\n"); );
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

bool Vtb_ramwin___024root___trigger_anySet__ico(const ::VlUnpacked<::QData/*63:0*/, 1> &in);

#ifdef VL_DEBUG
VL_ATTR_COLD void Vtb_ramwin___024root___dump_triggers__ico(const ::VlUnpacked<::QData/*63:0*/, 1> &triggers, const ::std::string &tag) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_ramwin___024root___dump_triggers__ico\n"); );
    // Body
    if ((1U & (~ (::IData)(Vtb_ramwin___024root___trigger_anySet__ico(triggers))))) {
        VL_DBG_MSGS("         No '" + tag + "' region triggers active\n");
    }
    if ((1U & (::IData)(triggers[0U]))) {
        VL_DBG_MSGS("         '" + tag + "' region trigger index 0 is active: Internal 'ico' trigger - first iteration\n");
    }
}
#endif  // VL_DEBUG

bool Vtb_ramwin___024root___trigger_anySet__act(const ::VlUnpacked<::QData/*63:0*/, 1> &in);

#ifdef VL_DEBUG
VL_ATTR_COLD void Vtb_ramwin___024root___dump_triggers__act(const ::VlUnpacked<::QData/*63:0*/, 1> &triggers, const ::std::string &tag) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_ramwin___024root___dump_triggers__act\n"); );
    // Body
    if ((1U & (~ (::IData)(Vtb_ramwin___024root___trigger_anySet__act(triggers))))) {
        VL_DBG_MSGS("         No '" + tag + "' region triggers active\n");
    }
    if ((1U & (::IData)(triggers[0U]))) {
        VL_DBG_MSGS("         '" + tag + "' region trigger index 0 is active: @(posedge tb_ramwin.clk)\n");
    }
    if ((1U & (::IData)((triggers[0U] >> 1U)))) {
        VL_DBG_MSGS("         '" + tag + "' region trigger index 1 is active: @( (~ (| tb_ramwin.sd.init_state)))\n");
    }
    if ((1U & (::IData)((triggers[0U] >> 2U)))) {
        VL_DBG_MSGS("         '" + tag + "' region trigger index 2 is active: @([true] __VdlySched.awaitingCurrentTime())\n");
    }
}
#endif  // VL_DEBUG

VL_ATTR_COLD void Vtb_ramwin___024root___ctor_var_reset(Vtb_ramwin___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_ramwin___024root___ctor_var_reset\n"); );
    Vtb_ramwin__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    vlSelf->tb_ramwin__DOT____Vcellinp__sd__oe = 0;
    const uint64_t __VscopeHash = VL_MURMUR64_HASH(vlSelf->vlNamep);
    vlSelf->tb_ramwin__DOT__chk_expect = VL_SCOPED_RAND_RESET_I(21, __VscopeHash, 14597694674079719042ull);
    vlSelf->tb_ramwin__DOT__chk_owner = VL_SCOPED_RAND_RESET_I(2, __VscopeHash, 14403289378024404737ull);
    vlSelf->tb_ramwin__DOT__ac__DOT__loadSound = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 3916370606452394994ull);
    vlSelf->tb_ramwin__DOT__ac__DOT__video_dma_off = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 6191007409852049960ull);
    vlSelf->tb_ramwin__DOT__ac__DOT__sndReq = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 12536307185972504104ull);
    vlSelf->tb_ramwin__DOT__ac__DOT__sndReqCycle = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 6178702357944750478ull);
    vlSelf->tb_ramwin__DOT__ac__DOT__audioAddr = VL_SCOPED_RAND_RESET_I(21, __VscopeHash, 16202953883932526745ull);
    vlSelf->tb_ramwin__DOT__ac__DOT__vblankD = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 7273465271389764267ull);
    vlSelf->tb_ramwin__DOT__ac__DOT__hblankD = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 10389741702176459629ull);
    vlSelf->tb_ramwin__DOT__ac__DOT__lpx = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 14231243873618053783ull);
    vlSelf->tb_ramwin__DOT__ac__DOT__lsnd = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 5809776968139952681ull);
    vlSelf->tb_ramwin__DOT__ac__DOT__vt__DOT__videoAddr = VL_SCOPED_RAND_RESET_I(21, __VscopeHash, 16474398250426538667ull);
    vlSelf->tb_ramwin__DOT__ac__DOT__vt__DOT__loadPixels = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 15128899937396820901ull);
    vlSelf->tb_ramwin__DOT__ac__DOT__vt__DOT__xpos = VL_SCOPED_RAND_RESET_I(10, __VscopeHash, 1283041464774372697ull);
    vlSelf->tb_ramwin__DOT__ac__DOT__vt__DOT__ypos = VL_SCOPED_RAND_RESET_I(9, __VscopeHash, 8037949004602133162ull);
    vlSelf->tb_ramwin__DOT__sd__DOT__state = VL_SCOPED_RAND_RESET_I(3, __VscopeHash, 13633508344650247536ull);
    vlSelf->tb_ramwin__DOT__sd__DOT__init_state = VL_SCOPED_RAND_RESET_I(5, __VscopeHash, 7956146596319390544ull);
    vlSelf->tb_ramwin__DOT__sd__DOT__rd_addr_r = VL_SCOPED_RAND_RESET_I(22, __VscopeHash, 18162116601585886103ull);
    vlSelf->tb_ramwin__DOT__clk_i__DOT__busPhase = VL_SCOPED_RAND_RESET_I(3, __VscopeHash, 3589660788660086109ull);
    vlSelf->tb_ramwin__DOT__clk_i__DOT__busCycle = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 9752534648771007462ull);
    vlSelf->__VstlTriggered[0] = 0;
    VL_UNPACKED_FILL(vlSelf->__VstlTriggered.data(), sizeof(vlSelf->__VstlTriggered[0]), 1);
    vlSelf->__VicoTriggered[0] = 0;
    VL_UNPACKED_FILL(vlSelf->__VicoTriggered.data(), sizeof(vlSelf->__VicoTriggered[0]), 1);
    vlSelf->__VactTriggered[0] = 0;
    VL_UNPACKED_FILL(vlSelf->__VactTriggered.data(), sizeof(vlSelf->__VactTriggered[0]), 1);
    vlSelf->__VactTriggeredAcc[0] = 0;
    VL_UNPACKED_FILL(vlSelf->__VactTriggeredAcc.data(), sizeof(vlSelf->__VactTriggeredAcc[0]), 1);
    vlSelf->__Vtrigprevexpr___TOP__tb_ramwin__DOT__clk__0 = 0;
    vlSelf->__Vtrigprevexpr_h721d1614__1 = 0;
    vlSelf->__VnbaTriggered[0] = 0;
    VL_UNPACKED_FILL(vlSelf->__VnbaTriggered.data(), sizeof(vlSelf->__VnbaTriggered[0]), 1);
    vlSelf->__Vi = 0;
}
