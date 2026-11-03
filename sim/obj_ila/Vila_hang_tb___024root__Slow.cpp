// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vila_hang_tb.h for the primary calling header

#include "Vila_hang_tb__pch.h"

void Vila_hang_tb___024root___ctor_var_reset(Vila_hang_tb___024root* vlSelf);

void Vila_hang_tb___024root__ctor(Vila_hang_tb___024root* vlSelf, Vila_hang_tb__Syms* symsp, const char* namep) {
    vlSelf->vlSymsp = symsp;
    vlSelf->vlNamep = strdup(namep);
    // Construct members
    VL_INPLACE_CONSTRUCT(vlSelf->__Vnontrivs.__VdlySched, *vlSelf->vlSymsp->_vm_contextp__);
    VL_INPLACE_CONSTRUCT(vlSelf->__Vnontrivs.__VtrigSched_hf3b002a5__0);
    // Reset structure values
    Vila_hang_tb___024root___ctor_var_reset(vlSelf);
}

Vila_hang_tb___024root::Vila_hang_tb___024root(Vila_hang_tb__Syms* symsp, const char* namep) {
    Vila_hang_tb___024root__ctor(this, symsp, namep);
}

void Vila_hang_tb___024root__dtor(Vila_hang_tb___024root* vlSelf) {
    // Destroy members
    VL_INPLACE_DESTRUCT(vlSelf->__Vnontrivs.__VtrigSched_hf3b002a5__0);
    VL_INPLACE_DESTRUCT(vlSelf->__Vnontrivs.__VdlySched);
    VL_DO_DANGLING(std::free(const_cast<char*>(vlSelf->vlNamep)), vlSelf->vlNamep);
}

Vila_hang_tb___024root::~Vila_hang_tb___024root() {
    Vila_hang_tb___024root__dtor(this);
}
