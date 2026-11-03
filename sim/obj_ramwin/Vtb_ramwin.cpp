// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Model implementation (design independent parts)

#include "Vtb_ramwin__pch.h"

//============================================================
// Constructors

Vtb_ramwin::Vtb_ramwin(VerilatedContext* _vcontextp__, const char* _vcname__)
    : VerilatedModel{*_vcontextp__}
    , vlSymsp{new Vtb_ramwin__Syms(contextp(), _vcname__, this)}
    , m_evalLoop{*this, /*convergeLimit:*/ 10000}
    , rootp{&(vlSymsp->vlInst.TOP)}
{
    // Register model with the context
    contextp()->addModel(this);
}

Vtb_ramwin::Vtb_ramwin(const char* _vcname__)
    : Vtb_ramwin(Verilated::threadContextp(), _vcname__)
{
}

//============================================================
// Destructor

Vtb_ramwin::~Vtb_ramwin() {
    delete vlSymsp;
}

//============================================================
// Evaluation function

#ifdef VL_DEBUG
void Vtb_ramwin___024root___eval_debug_assertions(Vtb_ramwin___024root* vlSelf);
#endif  // VL_DEBUG
VL_ATTR_COLD void Vtb_ramwin___024root___eval_static(Vtb_ramwin___024root* vlSelf);
void Vtb_ramwin___024root___eval_initial(Vtb_ramwin___024root* vlSelf);
VL_ATTR_COLD bool Vtb_ramwin___024root___eval_stl(Vtb_ramwin___024root* vlSelf, ::CData/*0:0*/ firstIteration);
void Vtb_ramwin___024root___eval_sample(Vtb_ramwin___024root* vlSelf);
bool Vtb_ramwin___024root___eval_ico(Vtb_ramwin___024root* vlSelf, ::CData/*0:0*/ firstIteration);
bool Vtb_ramwin___024root___eval_act(Vtb_ramwin___024root* vlSelf);
bool Vtb_ramwin___024root___eval_inact(Vtb_ramwin___024root* vlSelf);
bool Vtb_ramwin___024root___eval_nba(Vtb_ramwin___024root* vlSelf);
bool Vtb_ramwin___024root___eval_obs(Vtb_ramwin___024root* vlSelf);
bool Vtb_ramwin___024root___eval_react(Vtb_ramwin___024root* vlSelf);
void Vtb_ramwin___024root___eval_postponed(Vtb_ramwin___024root* vlSelf);
VL_ATTR_COLD void Vtb_ramwin___024root___eval_final(Vtb_ramwin___024root* vlSelf);
VL_ATTR_COLD void Vtb_ramwin___024root___eval_dump_triggers__stl(Vtb_ramwin___024root* vlSelf);
VL_ATTR_COLD void Vtb_ramwin___024root___eval_dump_triggers__ico(Vtb_ramwin___024root* vlSelf);
VL_ATTR_COLD void Vtb_ramwin___024root___eval_dump_triggers__act(Vtb_ramwin___024root* vlSelf);
VL_ATTR_COLD void Vtb_ramwin___024root___eval_dump_triggers__nba(Vtb_ramwin___024root* vlSelf);
VL_ATTR_COLD void Vtb_ramwin___024root___eval_dump_triggers__obs(Vtb_ramwin___024root* vlSelf);
VL_ATTR_COLD void Vtb_ramwin___024root___eval_dump_triggers__react(Vtb_ramwin___024root* vlSelf);

void Vtb_ramwin::eval_step() {
    VL_DEBUG_IF(VL_DBG_MSGF("+++++TOP Evaluate Vtb_ramwin::eval_step\n"); );
    m_evalLoop.eval();
}

void Vtb_ramwin::evalBegin() {
#ifdef VL_DEBUG
    // Debug assertions
    Vtb_ramwin___024root___eval_debug_assertions(&(vlSymsp->vlInst.TOP));
#endif  // VL_DEBUG
    vlSymsp->__Vm_deleter.deleteAll();
}

void Vtb_ramwin::evalEnd() {
    // Evaluate cleanup
    Verilated::endOfEval(vlSymsp->__Vm_evalMsgQp);
    vlSymsp->vlInst.TOP.__Vnontrivs.__VdlySched.cleanupForevered();
}

void Vtb_ramwin::evalStatic() {
    Vtb_ramwin___024root___eval_static(&(vlSymsp->vlInst.TOP));
}

void Vtb_ramwin::evalInitial() {
    Vtb_ramwin___024root___eval_initial(&(vlSymsp->vlInst.TOP));
}

bool Vtb_ramwin::evalStl(bool firstIteration) {
    return Vtb_ramwin___024root___eval_stl(&(vlSymsp->vlInst.TOP), firstIteration);
}

void Vtb_ramwin::evalSample() {
    Vtb_ramwin___024root___eval_sample(&(vlSymsp->vlInst.TOP));
}

bool Vtb_ramwin::evalIco(bool firstIteration) {
    return Vtb_ramwin___024root___eval_ico(&(vlSymsp->vlInst.TOP), firstIteration);
}

bool Vtb_ramwin::evalAct() {
    return Vtb_ramwin___024root___eval_act(&(vlSymsp->vlInst.TOP));
}

bool Vtb_ramwin::evalInact() {
    return Vtb_ramwin___024root___eval_inact(&(vlSymsp->vlInst.TOP));
}

bool Vtb_ramwin::evalNba() {
    return Vtb_ramwin___024root___eval_nba(&(vlSymsp->vlInst.TOP));
}

bool Vtb_ramwin::evalObs() {
    return Vtb_ramwin___024root___eval_obs(&(vlSymsp->vlInst.TOP));
}

bool Vtb_ramwin::evalReact() {
    return Vtb_ramwin___024root___eval_react(&(vlSymsp->vlInst.TOP));
}

void Vtb_ramwin::evalPostponed() {
    Vtb_ramwin___024root___eval_postponed(&(vlSymsp->vlInst.TOP));
}

void Vtb_ramwin::evalFinal() {
    Vtb_ramwin___024root___eval_final(&(vlSymsp->vlInst.TOP));
}

VL_ATTR_COLD void Vtb_ramwin::dumpTriggersStl() {
    Vtb_ramwin___024root___eval_dump_triggers__stl(&(vlSymsp->vlInst.TOP));
}

VL_ATTR_COLD void Vtb_ramwin::dumpTriggersIco() {
    Vtb_ramwin___024root___eval_dump_triggers__ico(&(vlSymsp->vlInst.TOP));
}

VL_ATTR_COLD void Vtb_ramwin::dumpTriggersAct() {
    Vtb_ramwin___024root___eval_dump_triggers__act(&(vlSymsp->vlInst.TOP));
}

VL_ATTR_COLD void Vtb_ramwin::dumpTriggersNba() {
    Vtb_ramwin___024root___eval_dump_triggers__nba(&(vlSymsp->vlInst.TOP));
}

VL_ATTR_COLD void Vtb_ramwin::dumpTriggersObs() {
    Vtb_ramwin___024root___eval_dump_triggers__obs(&(vlSymsp->vlInst.TOP));
}

VL_ATTR_COLD void Vtb_ramwin::dumpTriggersReact() {
    Vtb_ramwin___024root___eval_dump_triggers__react(&(vlSymsp->vlInst.TOP));
}

//============================================================
// Events and timing
bool Vtb_ramwin::eventsPending() { return !vlSymsp->vlInst.TOP.__Vnontrivs.__VdlySched.empty() && !contextp()->gotFinish(); }

uint64_t Vtb_ramwin::nextTimeSlot() { return vlSymsp->vlInst.TOP.__Vnontrivs.__VdlySched.nextTimeSlot(); }

//============================================================
// Utilities

const char* Vtb_ramwin::name() const {
    return vlSymsp->name();
}

//============================================================
// Invoke final blocks

VL_ATTR_COLD void Vtb_ramwin::final() {
    contextp()->executingFinal(true);
    evalFinal();
    contextp()->executingFinal(false);
}

//============================================================
// Implementations of abstract methods from VerilatedModel

const char* Vtb_ramwin::hierName() const { return vlSymsp->name(); }
const char* Vtb_ramwin::modelName() const { return "Vtb_ramwin"; }
unsigned Vtb_ramwin::threads() const { return 1; }
void Vtb_ramwin::prepareClone() const { contextp()->prepareClone(); }
void Vtb_ramwin::atClone() const {
    contextp()->threadPoolpOnClone();
}
