// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Symbol table internal header
//
// Internal details; most calling programs do not need this header,
// unless using verilator public meta comments.

#ifndef VERILATED_VTB_RAMWIN__SYMS_H_
#define VERILATED_VTB_RAMWIN__SYMS_H_  // guard

#include "verilated.h"

// INCLUDE MODEL CLASS

#include "Vtb_ramwin.h"

// INCLUDE MODULE CLASSES
#include "Vtb_ramwin___024root.h"

// SYMS CLASS (contains all model state)
class alignas(VL_CACHE_LINE_BYTES) Vtb_ramwin__Syms final : public VerilatedSyms {
  public:
    // INTERNAL STATE
    Vtb_ramwin* const __Vm_modelp;
    VlDeleter __Vm_deleter;
    bool& __Vm_didInit;

    // MODULE INSTANCE STATE
    union {
        struct {
            Vtb_ramwin___024root           TOP;
        } vlInst;
    };

    // CONSTRUCTORS
    Vtb_ramwin__Syms(VerilatedContext* contextp, const char* namep, Vtb_ramwin* modelp);
    ~Vtb_ramwin__Syms();

    // METHODS
    const char* name() const { return vlInst.TOP.vlNamep; }
};

#endif  // guard
