// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Symbol table implementation internals

#include "Vila_hang_tb__pch.h"


void Vila_hang_tb__Syms__ctor(Vila_hang_tb__Syms* vlSymsp, const char* namep) {
    // Setup top module instance
    VL_INPLACE_CONSTRUCT(vlSymsp->vlInst.TOP, vlSymsp, namep);
    // Check resources
    Verilated::stackCheck(109);
    // Setup sub module instances
    // Configure time unit / time precision
    vlSymsp->_vm_contextp__->timeunit(-9);
    vlSymsp->_vm_contextp__->timeprecision(-12);
    // Setup each module's pointers to their submodules
}

Vila_hang_tb__Syms::Vila_hang_tb__Syms(VerilatedContext* contextp, const char* namep, Vila_hang_tb* modelp)
    : VerilatedSyms{contextp}
    // Setup internal state of the Syms class
    , __Vm_modelp{modelp}
    , __Vm_didInit{modelp->m_didInit}
{
    Vila_hang_tb__Syms__ctor(this, namep);
}

void Vila_hang_tb__Syms__dtor(Vila_hang_tb__Syms* vlSymsp) {
    // Tear down scopes
    // Tear down sub module instances
    // Tear down top module instance
    VL_INPLACE_DESTRUCT(vlSymsp->vlInst.TOP);
}

Vila_hang_tb__Syms::~Vila_hang_tb__Syms() {
    Vila_hang_tb__Syms__dtor(this);
}
