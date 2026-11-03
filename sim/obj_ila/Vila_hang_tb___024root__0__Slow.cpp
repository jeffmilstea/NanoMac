// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vila_hang_tb.h for the primary calling header

#include "Vila_hang_tb__pch.h"

void Vila_hang_tb___024root___timing_ready(Vila_hang_tb___024root* vlSelf);

VL_ATTR_COLD void Vila_hang_tb___024root___eval_static(Vila_hang_tb___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vila_hang_tb___024root___eval_static\n"); );
    Vila_hang_tb__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    {
        // Inlined CFunc: _eval_static__TOP
        vlSelfRef.ila_hang_tb__DOT__clk = 0U;
        vlSelfRef.ila_hang_tb__DOT__reset = 1U;
        vlSelfRef.ila_hang_tb__DOT__probes = 0ULL;
        vlSelfRef.ila_hang_tb__DOT___cpuAS = 1U;
        vlSelfRef.ila_hang_tb__DOT__strobe = 0U;
        vlSelfRef.ila_hang_tb__DOT__start = 0U;
        vlSelfRef.ila_hang_tb__DOT__din = 0U;
        const uint64_t __VscopeHash = VL_MURMUR64_HASH(vlSelf->vlNamep);
        vlSelfRef.ila_hang_tb__DOT__active__Vstatic__k = VL_SCOPED_RAND_RESET_I(32, __VscopeHash, 7458199713462991716ull);
        vlSelfRef.ila_hang_tb__DOT__quiet__Vstatic__k = VL_SCOPED_RAND_RESET_I(32, __VscopeHash, 2568234208232907389ull);
    }
    vlSelfRef.__Vtrigprevexpr___TOP__ila_hang_tb__DOT__clk__0 = 0U;
    Vila_hang_tb___024root___timing_ready(vlSelf);
    do {
        vlSelfRef.__VactTriggeredAcc[vlSelfRef.__Vi] 
            = vlSelfRef.__VactTriggered[vlSelfRef.__Vi];
        vlSelfRef.__Vi = ((::IData)(1U) + vlSelfRef.__Vi);
    } while ((0U >= vlSelfRef.__Vi));
}

#ifdef VL_DEBUG
VL_ATTR_COLD void Vila_hang_tb___024root___dump_triggers__stl(const ::VlUnpacked<::QData/*63:0*/, 1> &triggers, const ::std::string &tag);
#endif  // VL_DEBUG
VL_ATTR_COLD bool Vila_hang_tb___024root___trigger_anySet__stl(const ::VlUnpacked<::QData/*63:0*/, 1> &in);

VL_ATTR_COLD bool Vila_hang_tb___024root___eval_stl(Vila_hang_tb___024root* vlSelf, ::CData/*0:0*/ firstIteration) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vila_hang_tb___024root___eval_stl\n"); );
    Vila_hang_tb__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    ::CData/*0:0*/ __VstlExecute;
    // Body
    vlSelfRef.__VstlTriggered[0U] = ((0xfffffffffffffffeULL 
                                      & vlSelfRef.__VstlTriggered[0U]) 
                                     | (::IData)((::IData)(firstIteration)));
#ifdef VL_DEBUG
    if (VL_UNLIKELY(vlSymsp->_vm_contextp__->debug())) {
        Vila_hang_tb___024root___dump_triggers__stl(vlSelfRef.__VstlTriggered, "stl"s);
    }
#endif
    __VstlExecute = Vila_hang_tb___024root___trigger_anySet__stl(vlSelfRef.__VstlTriggered);
    if (__VstlExecute) {
        {
            // Inlined CFunc: _eval_body__stl
            if ((((1ULL & vlSelfRef.__VstlTriggered[0U])) != 0ULL)) {
                {
                    // Inlined CFunc: _stl_comb__TOP__0
                    vlSelfRef.ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__fifo_count 
                        = (0x000001ffU & ((::IData)(vlSelfRef.ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__fifo_wptr) 
                                          - (::IData)(vlSelfRef.ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__fifo_rptr)));
                    vlSelfRef.ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__fifo_empty 
                        = ((::IData)(vlSelfRef.ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__fifo_wptr) 
                           == (::IData)(vlSelfRef.ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__fifo_rptr));
                }
            }
        }
    }
    return (__VstlExecute);
}

VL_ATTR_COLD void Vila_hang_tb___024root___eval_dump_triggers__stl(Vila_hang_tb___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vila_hang_tb___024root___eval_dump_triggers__stl\n"); );
    Vila_hang_tb__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
#ifdef VL_DEBUG
    Vila_hang_tb___024root___dump_triggers__stl(vlSelfRef.__VstlTriggered, "stl"s);
#endif
}

#ifdef VL_DEBUG
VL_ATTR_COLD void Vila_hang_tb___024root___dump_triggers__ico(const ::VlUnpacked<::QData/*63:0*/, 1> &triggers, const ::std::string &tag);
#endif  // VL_DEBUG

VL_ATTR_COLD void Vila_hang_tb___024root___eval_dump_triggers__ico(Vila_hang_tb___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vila_hang_tb___024root___eval_dump_triggers__ico\n"); );
    Vila_hang_tb__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
#ifdef VL_DEBUG
    Vila_hang_tb___024root___dump_triggers__ico(vlSelfRef.__VicoTriggered, "ico"s);
#endif
}

#ifdef VL_DEBUG
VL_ATTR_COLD void Vila_hang_tb___024root___dump_triggers__act(const ::VlUnpacked<::QData/*63:0*/, 1> &triggers, const ::std::string &tag);
#endif  // VL_DEBUG

VL_ATTR_COLD void Vila_hang_tb___024root___eval_dump_triggers__act(Vila_hang_tb___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vila_hang_tb___024root___eval_dump_triggers__act\n"); );
    Vila_hang_tb__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
#ifdef VL_DEBUG
    Vila_hang_tb___024root___dump_triggers__act(vlSelfRef.__VactTriggered, "act"s);
#endif
}

VL_ATTR_COLD void Vila_hang_tb___024root___eval_dump_triggers__nba(Vila_hang_tb___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vila_hang_tb___024root___eval_dump_triggers__nba\n"); );
    Vila_hang_tb__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
#ifdef VL_DEBUG
    Vila_hang_tb___024root___dump_triggers__act(vlSelfRef.__VnbaTriggered, "nba"s);
#endif
}

VL_ATTR_COLD void Vila_hang_tb___024root___eval_dump_triggers__obs(Vila_hang_tb___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vila_hang_tb___024root___eval_dump_triggers__obs\n"); );
    Vila_hang_tb__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
}

VL_ATTR_COLD void Vila_hang_tb___024root___eval_dump_triggers__react(Vila_hang_tb___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vila_hang_tb___024root___eval_dump_triggers__react\n"); );
    Vila_hang_tb__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
}

VL_ATTR_COLD void Vila_hang_tb___024root___eval_final(Vila_hang_tb___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vila_hang_tb___024root___eval_final\n"); );
    Vila_hang_tb__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
}

#ifdef VL_DEBUG
VL_ATTR_COLD void Vila_hang_tb___024root___dump_triggers__stl(const ::VlUnpacked<::QData/*63:0*/, 1> &triggers, const ::std::string &tag) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vila_hang_tb___024root___dump_triggers__stl\n"); );
    // Body
    if ((1U & (~ (::IData)(Vila_hang_tb___024root___trigger_anySet__stl(triggers))))) {
        VL_DBG_MSGS("         No '" + tag + "' region triggers active\n");
    }
    if ((1U & (::IData)(triggers[0U]))) {
        VL_DBG_MSGS("         '" + tag + "' region trigger index 0 is active: Internal 'stl' trigger - first iteration\n");
    }
}
#endif  // VL_DEBUG

VL_ATTR_COLD bool Vila_hang_tb___024root___trigger_anySet__stl(const ::VlUnpacked<::QData/*63:0*/, 1> &in) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vila_hang_tb___024root___trigger_anySet__stl\n"); );
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

bool Vila_hang_tb___024root___trigger_anySet__ico(const ::VlUnpacked<::QData/*63:0*/, 1> &in);

#ifdef VL_DEBUG
VL_ATTR_COLD void Vila_hang_tb___024root___dump_triggers__ico(const ::VlUnpacked<::QData/*63:0*/, 1> &triggers, const ::std::string &tag) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vila_hang_tb___024root___dump_triggers__ico\n"); );
    // Body
    if ((1U & (~ (::IData)(Vila_hang_tb___024root___trigger_anySet__ico(triggers))))) {
        VL_DBG_MSGS("         No '" + tag + "' region triggers active\n");
    }
    if ((1U & (::IData)(triggers[0U]))) {
        VL_DBG_MSGS("         '" + tag + "' region trigger index 0 is active: Internal 'ico' trigger - first iteration\n");
    }
}
#endif  // VL_DEBUG

bool Vila_hang_tb___024root___trigger_anySet__act(const ::VlUnpacked<::QData/*63:0*/, 1> &in);

#ifdef VL_DEBUG
VL_ATTR_COLD void Vila_hang_tb___024root___dump_triggers__act(const ::VlUnpacked<::QData/*63:0*/, 1> &triggers, const ::std::string &tag) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vila_hang_tb___024root___dump_triggers__act\n"); );
    // Body
    if ((1U & (~ (::IData)(Vila_hang_tb___024root___trigger_anySet__act(triggers))))) {
        VL_DBG_MSGS("         No '" + tag + "' region triggers active\n");
    }
    if ((1U & (::IData)(triggers[0U]))) {
        VL_DBG_MSGS("         '" + tag + "' region trigger index 0 is active: @(posedge ila_hang_tb.clk)\n");
    }
    if ((1U & (::IData)((triggers[0U] >> 1U)))) {
        VL_DBG_MSGS("         '" + tag + "' region trigger index 1 is active: @(negedge ila_hang_tb.clk)\n");
    }
    if ((1U & (::IData)((triggers[0U] >> 2U)))) {
        VL_DBG_MSGS("         '" + tag + "' region trigger index 2 is active: @([true] __VdlySched.awaitingCurrentTime())\n");
    }
}
#endif  // VL_DEBUG

VL_ATTR_COLD void Vila_hang_tb___024root___ctor_var_reset(Vila_hang_tb___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vila_hang_tb___024root___ctor_var_reset\n"); );
    Vila_hang_tb__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    const uint64_t __VscopeHash = VL_MURMUR64_HASH(vlSelf->vlNamep);
    vlSelf->ila_hang_tb__DOT__active__Vstatic__a = VL_SCOPED_RAND_RESET_I(24, __VscopeHash, 14434017956428456809ull);
    vlSelf->ila_hang_tb__DOT__active__Vstatic__n = VL_SCOPED_RAND_RESET_I(32, __VscopeHash, 4980673022606829944ull);
    vlSelf->ila_hang_tb__DOT__quiet__Vstatic__n = VL_SCOPED_RAND_RESET_I(32, __VscopeHash, 8104657828576843569ull);
    vlSelf->ila_hang_tb__DOT__dut__DOT__step_clock_cnt = VL_SCOPED_RAND_RESET_I(16, __VscopeHash, 5547130700742979832ull);
    vlSelf->ila_hang_tb__DOT__dut__DOT__step_bus_cnt = VL_SCOPED_RAND_RESET_I(16, __VscopeHash, 13251551314508223165ull);
    vlSelf->ila_hang_tb__DOT__dut__DOT__ice_cmd_strobe = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 12565978845822003623ull);
    vlSelf->ila_hang_tb__DOT__dut__DOT__ice_subcmd = VL_SCOPED_RAND_RESET_I(8, __VscopeHash, 10152284595189648493ull);
    vlSelf->ila_hang_tb__DOT__dut__DOT__ice_step_val = VL_SCOPED_RAND_RESET_I(16, __VscopeHash, 12654076264387960544ull);
    vlSelf->ila_hang_tb__DOT__dut__DOT___cpuAS_d = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 15778883311898191076ull);
    vlSelf->ila_hang_tb__DOT__dut__DOT__wr_ptr = VL_SCOPED_RAND_RESET_I(8, __VscopeHash, 13114504881055491171ull);
    vlSelf->ila_hang_tb__DOT__dut__DOT__ila_state = VL_SCOPED_RAND_RESET_I(3, __VscopeHash, 9548392200628588233ull);
    vlSelf->ila_hang_tb__DOT__dut__DOT__trigger_pos = VL_SCOPED_RAND_RESET_I(8, __VscopeHash, 5537978316302218592ull);
    vlSelf->ila_hang_tb__DOT__dut__DOT__pre_count = VL_SCOPED_RAND_RESET_I(8, __VscopeHash, 4800243032261218663ull);
    vlSelf->ila_hang_tb__DOT__dut__DOT__post_count = VL_SCOPED_RAND_RESET_I(8, __VscopeHash, 4849164476498351613ull);
    vlSelf->ila_hang_tb__DOT__dut__DOT__quiet_cnt = VL_SCOPED_RAND_RESET_I(16, __VscopeHash, 17943220458115525604ull);
    vlSelf->ila_hang_tb__DOT__dut__DOT__trig_mode = VL_SCOPED_RAND_RESET_I(3, __VscopeHash, 7630346276517281048ull);
    vlSelf->ila_hang_tb__DOT__dut__DOT__trig_addr = VL_SCOPED_RAND_RESET_I(24, __VscopeHash, 18292327937295754699ull);
    vlSelf->ila_hang_tb__DOT__dut__DOT__trig_mask = VL_SCOPED_RAND_RESET_I(24, __VscopeHash, 4393244311481632938ull);
    vlSelf->ila_hang_tb__DOT__dut__DOT__force_trigger = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 6986993519137874976ull);
    vlSelf->ila_hang_tb__DOT__dut__DOT__ila_arm_req = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 3703517354119678734ull);
    vlSelf->ila_hang_tb__DOT__dut__DOT__ila_disarm_req = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 9763662869580909185ull);
    vlSelf->ila_hang_tb__DOT__dut__DOT__force_trig_req = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 3021176120038426691ull);
    vlSelf->ila_hang_tb__DOT__dut__DOT__cmd = VL_SCOPED_RAND_RESET_I(8, __VscopeHash, 5047807205894806526ull);
    vlSelf->ila_hang_tb__DOT__dut__DOT__byte_cnt = VL_SCOPED_RAND_RESET_I(5, __VscopeHash, 1320176719952126073ull);
    vlSelf->ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__uart_halt_req = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 1035097906228205194ull);
    vlSelf->ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__uart_resume_req = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 11684085150748765911ull);
    vlSelf->ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__uart_reset_req = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 14755088712981061761ull);
    vlSelf->ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__uart_step_clock_req = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 13047824179368235186ull);
    vlSelf->ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__uart_step_bus_req = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 10237525508355682973ull);
    vlSelf->ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__uart_step_val = VL_SCOPED_RAND_RESET_I(16, __VscopeHash, 4928596689060540485ull);
    vlSelf->ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__uart_arm_req = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 8946721652708989548ull);
    vlSelf->ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__uart_disarm_req = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 12102035627706479611ull);
    vlSelf->ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__uart_force_trig_req = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 2588144499451254304ull);
    vlSelf->ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__uart_trig_mode = VL_SCOPED_RAND_RESET_I(3, __VscopeHash, 14963879911665012480ull);
    vlSelf->ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__uart_trig_addr = VL_SCOPED_RAND_RESET_I(24, __VscopeHash, 4205419607523300582ull);
    vlSelf->ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__uart_trig_mask = VL_SCOPED_RAND_RESET_I(24, __VscopeHash, 8200155861762281929ull);
    vlSelf->ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__rx_sync = VL_SCOPED_RAND_RESET_I(2, __VscopeHash, 8751725319427980118ull);
    vlSelf->ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__rx_state = VL_SCOPED_RAND_RESET_I(3, __VscopeHash, 2110870140761031454ull);
    vlSelf->ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__rx_clk_cnt = VL_SCOPED_RAND_RESET_I(6, __VscopeHash, 13747832950118284951ull);
    vlSelf->ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__rx_bit_idx = VL_SCOPED_RAND_RESET_I(3, __VscopeHash, 7213138291382800381ull);
    vlSelf->ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__rx_shreg = VL_SCOPED_RAND_RESET_I(8, __VscopeHash, 14058404283405698703ull);
    vlSelf->ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__rx_valid = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 6290286342545713533ull);
    vlSelf->ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__rx_byte = VL_SCOPED_RAND_RESET_I(8, __VscopeHash, 6878214650513588657ull);
    vlSelf->ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__fifo_wptr = VL_SCOPED_RAND_RESET_I(9, __VscopeHash, 4951783705554748539ull);
    vlSelf->ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__fifo_rptr = VL_SCOPED_RAND_RESET_I(9, __VscopeHash, 9424866734191786515ull);
    vlSelf->ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__fifo_wr = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 5948974579922264067ull);
    vlSelf->ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__fifo_count = VL_SCOPED_RAND_RESET_I(9, __VscopeHash, 11266575878218686659ull);
    vlSelf->ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__fifo_empty = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 15114670450273117963ull);
    vlSelf->ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__tx_state = VL_SCOPED_RAND_RESET_I(3, __VscopeHash, 2739992593491079089ull);
    vlSelf->ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__tx_clk_cnt = VL_SCOPED_RAND_RESET_I(6, __VscopeHash, 9600346733502771656ull);
    vlSelf->ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__tx_bit_idx = VL_SCOPED_RAND_RESET_I(3, __VscopeHash, 13777887042635033023ull);
    vlSelf->ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__state = VL_SCOPED_RAND_RESET_I(4, __VscopeHash, 17387142995366680207ull);
    vlSelf->ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__msg_idx = VL_SCOPED_RAND_RESET_I(8, __VscopeHash, 885803139793433905ull);
    vlSelf->ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__msg_len = VL_SCOPED_RAND_RESET_I(8, __VscopeHash, 7590789139467245378ull);
    vlSelf->ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__dump_cnt = VL_SCOPED_RAND_RESET_I(10, __VscopeHash, 14329651154110702819ull);
    vlSelf->ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__dump_col = VL_SCOPED_RAND_RESET_I(6, __VscopeHash, 9113693435232258965ull);
    vlSelf->ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__bin_byte_idx = VL_SCOPED_RAND_RESET_I(3, __VscopeHash, 800289489034297200ull);
    vlSelf->ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__bin_hdr = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 7816102240477685382ull);
    vlSelf->ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__peek_slot = VL_SCOPED_RAND_RESET_I(3, __VscopeHash, 16228681418242632028ull);
    vlSelf->ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__peek_settle = VL_SCOPED_RAND_RESET_I(2, __VscopeHash, 16427926553446759013ull);
    vlSelf->ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__poke_hi_rx = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 8154517608196687373ull);
    vlSelf->ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__print_after_step = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 3735601144606900261ull);
    vlSelf->ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__step_timeout = VL_SCOPED_RAND_RESET_I(20, __VscopeHash, 3806697489563802945ull);
    vlSelf->ila_hang_tb__DOT__dut__DOT__ila_uart_inst__DOT__cfg_idx = VL_SCOPED_RAND_RESET_I(3, __VscopeHash, 10968709309847113239ull);
    vlSelf->__VstlTriggered[0] = 0;
    VL_UNPACKED_FILL(vlSelf->__VstlTriggered.data(), sizeof(vlSelf->__VstlTriggered[0]), 1);
    vlSelf->__VicoTriggered[0] = 0;
    VL_UNPACKED_FILL(vlSelf->__VicoTriggered.data(), sizeof(vlSelf->__VicoTriggered[0]), 1);
    vlSelf->__VactTriggered[0] = 0;
    VL_UNPACKED_FILL(vlSelf->__VactTriggered.data(), sizeof(vlSelf->__VactTriggered[0]), 1);
    vlSelf->__VactTriggeredAcc[0] = 0;
    VL_UNPACKED_FILL(vlSelf->__VactTriggeredAcc.data(), sizeof(vlSelf->__VactTriggeredAcc[0]), 1);
    vlSelf->__Vtrigprevexpr___TOP__ila_hang_tb__DOT__clk__0 = 0;
    vlSelf->__VnbaTriggered[0] = 0;
    VL_UNPACKED_FILL(vlSelf->__VnbaTriggered.data(), sizeof(vlSelf->__VnbaTriggered[0]), 1);
    vlSelf->__Vi = 0;
}
