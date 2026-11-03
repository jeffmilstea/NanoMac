// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Symbol table internal header
//
// Internal details; most calling programs do not need this header,
// unless using verilator public meta comments.

#ifndef VERILATED_VILA_HANG_TB__SYMS_H_
#define VERILATED_VILA_HANG_TB__SYMS_H_  // guard

#include "verilated.h"

// INCLUDE MODEL CLASS

#include "Vila_hang_tb.h"

// INCLUDE MODULE CLASSES
#include "Vila_hang_tb___024root.h"

// SYMS CLASS (contains all model state)
class alignas(VL_CACHE_LINE_BYTES) Vila_hang_tb__Syms final : public VerilatedSyms {
  public:
    // INTERNAL STATE
    Vila_hang_tb* const __Vm_modelp;
    VlDeleter __Vm_deleter;
    bool& __Vm_didInit;

    // MODULE INSTANCE STATE
    union {
        struct {
            Vila_hang_tb___024root         TOP;
        } vlInst;
    };

    // CONSTRUCTORS
    Vila_hang_tb__Syms(VerilatedContext* contextp, const char* namep, Vila_hang_tb* modelp);
    ~Vila_hang_tb__Syms();

    // METHODS
    const char* name() const { return vlInst.TOP.vlNamep; }
};

#endif  // guard
