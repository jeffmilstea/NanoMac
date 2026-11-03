// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vtb_ramwin.h for the primary calling header

#include "Vtb_ramwin__pch.h"

void Vtb_ramwin___024root___ctor_var_reset(Vtb_ramwin___024root* vlSelf);

void Vtb_ramwin___024root__ctor(Vtb_ramwin___024root* vlSelf, Vtb_ramwin__Syms* symsp, const char* namep) {
    vlSelf->vlSymsp = symsp;
    vlSelf->vlNamep = strdup(namep);
    // Construct members
    VL_INPLACE_CONSTRUCT(vlSelf->__Vnontrivs.__VdlySched, *vlSelf->vlSymsp->_vm_contextp__);
    VL_INPLACE_CONSTRUCT(vlSelf->__Vnontrivs.__VtrigSched_h04e7b3b1__0);
    VL_INPLACE_CONSTRUCT(vlSelf->__Vnontrivs.__VtrigSched_h5608d255__0);
    // Reset structure values
    Vtb_ramwin___024root___ctor_var_reset(vlSelf);
}

Vtb_ramwin___024root::Vtb_ramwin___024root(Vtb_ramwin__Syms* symsp, const char* namep) {
    Vtb_ramwin___024root__ctor(this, symsp, namep);
}

void Vtb_ramwin___024root__dtor(Vtb_ramwin___024root* vlSelf) {
    // Destroy members
    VL_INPLACE_DESTRUCT(vlSelf->__Vnontrivs.__VtrigSched_h5608d255__0);
    VL_INPLACE_DESTRUCT(vlSelf->__Vnontrivs.__VtrigSched_h04e7b3b1__0);
    VL_INPLACE_DESTRUCT(vlSelf->__Vnontrivs.__VdlySched);
    VL_DO_DANGLING(std::free(const_cast<char*>(vlSelf->vlNamep)), vlSelf->vlNamep);
}

Vtb_ramwin___024root::~Vtb_ramwin___024root() {
    Vtb_ramwin___024root__dtor(this);
}
