// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Symbol table implementation internals

#include "Vtb_ramwin__pch.h"


void Vtb_ramwin__Syms__ctor(Vtb_ramwin__Syms* vlSymsp, const char* namep) {
    // Setup top module instance
    VL_INPLACE_CONSTRUCT(vlSymsp->vlInst.TOP, vlSymsp, namep);
    // Check resources
    Verilated::stackCheck(24);
    // Setup sub module instances
    // Configure time unit / time precision
    vlSymsp->_vm_contextp__->timeunit(-9);
    vlSymsp->_vm_contextp__->timeprecision(-12);
    // Setup each module's pointers to their submodules
}

Vtb_ramwin__Syms::Vtb_ramwin__Syms(VerilatedContext* contextp, const char* namep, Vtb_ramwin* modelp)
    : VerilatedSyms{contextp}
    // Setup internal state of the Syms class
    , __Vm_modelp{modelp}
    , __Vm_didInit{modelp->m_didInit}
{
    Vtb_ramwin__Syms__ctor(this, namep);
}

void Vtb_ramwin__Syms__dtor(Vtb_ramwin__Syms* vlSymsp) {
    // Tear down scopes
    // Tear down sub module instances
    // Tear down top module instance
    VL_INPLACE_DESTRUCT(vlSymsp->vlInst.TOP);
}

Vtb_ramwin__Syms::~Vtb_ramwin__Syms() {
    Vtb_ramwin__Syms__dtor(this);
}
