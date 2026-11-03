// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Model implementation (design independent parts)

#include "Vila_hang_tb__pch.h"

//============================================================
// Constructors

Vila_hang_tb::Vila_hang_tb(VerilatedContext* _vcontextp__, const char* _vcname__)
    : VerilatedModel{*_vcontextp__}
    , vlSymsp{new Vila_hang_tb__Syms(contextp(), _vcname__, this)}
    , m_evalLoop{*this, /*convergeLimit:*/ 10000}
    , rootp{&(vlSymsp->vlInst.TOP)}
{
    // Register model with the context
    contextp()->addModel(this);
}

Vila_hang_tb::Vila_hang_tb(const char* _vcname__)
    : Vila_hang_tb(Verilated::threadContextp(), _vcname__)
{
}

//============================================================
// Destructor

Vila_hang_tb::~Vila_hang_tb() {
    delete vlSymsp;
}

//============================================================
// Evaluation function

#ifdef VL_DEBUG
void Vila_hang_tb___024root___eval_debug_assertions(Vila_hang_tb___024root* vlSelf);
#endif  // VL_DEBUG
VL_ATTR_COLD void Vila_hang_tb___024root___eval_static(Vila_hang_tb___024root* vlSelf);
void Vila_hang_tb___024root___eval_initial(Vila_hang_tb___024root* vlSelf);
VL_ATTR_COLD bool Vila_hang_tb___024root___eval_stl(Vila_hang_tb___024root* vlSelf, ::CData/*0:0*/ firstIteration);
void Vila_hang_tb___024root___eval_sample(Vila_hang_tb___024root* vlSelf);
bool Vila_hang_tb___024root___eval_ico(Vila_hang_tb___024root* vlSelf, ::CData/*0:0*/ firstIteration);
bool Vila_hang_tb___024root___eval_act(Vila_hang_tb___024root* vlSelf);
bool Vila_hang_tb___024root___eval_inact(Vila_hang_tb___024root* vlSelf);
bool Vila_hang_tb___024root___eval_nba(Vila_hang_tb___024root* vlSelf);
bool Vila_hang_tb___024root___eval_obs(Vila_hang_tb___024root* vlSelf);
bool Vila_hang_tb___024root___eval_react(Vila_hang_tb___024root* vlSelf);
void Vila_hang_tb___024root___eval_postponed(Vila_hang_tb___024root* vlSelf);
VL_ATTR_COLD void Vila_hang_tb___024root___eval_final(Vila_hang_tb___024root* vlSelf);
VL_ATTR_COLD void Vila_hang_tb___024root___eval_dump_triggers__stl(Vila_hang_tb___024root* vlSelf);
VL_ATTR_COLD void Vila_hang_tb___024root___eval_dump_triggers__ico(Vila_hang_tb___024root* vlSelf);
VL_ATTR_COLD void Vila_hang_tb___024root___eval_dump_triggers__act(Vila_hang_tb___024root* vlSelf);
VL_ATTR_COLD void Vila_hang_tb___024root___eval_dump_triggers__nba(Vila_hang_tb___024root* vlSelf);
VL_ATTR_COLD void Vila_hang_tb___024root___eval_dump_triggers__obs(Vila_hang_tb___024root* vlSelf);
VL_ATTR_COLD void Vila_hang_tb___024root___eval_dump_triggers__react(Vila_hang_tb___024root* vlSelf);

void Vila_hang_tb::eval_step() {
    VL_DEBUG_IF(VL_DBG_MSGF("+++++TOP Evaluate Vila_hang_tb::eval_step\n"); );
    m_evalLoop.eval();
}

void Vila_hang_tb::evalBegin() {
#ifdef VL_DEBUG
    // Debug assertions
    Vila_hang_tb___024root___eval_debug_assertions(&(vlSymsp->vlInst.TOP));
#endif  // VL_DEBUG
    vlSymsp->__Vm_deleter.deleteAll();
}

void Vila_hang_tb::evalEnd() {
    // Evaluate cleanup
    Verilated::endOfEval(vlSymsp->__Vm_evalMsgQp);
    vlSymsp->vlInst.TOP.__Vnontrivs.__VdlySched.cleanupForevered();
}

void Vila_hang_tb::evalStatic() {
    Vila_hang_tb___024root___eval_static(&(vlSymsp->vlInst.TOP));
}

void Vila_hang_tb::evalInitial() {
    Vila_hang_tb___024root___eval_initial(&(vlSymsp->vlInst.TOP));
}

bool Vila_hang_tb::evalStl(bool firstIteration) {
    return Vila_hang_tb___024root___eval_stl(&(vlSymsp->vlInst.TOP), firstIteration);
}

void Vila_hang_tb::evalSample() {
    Vila_hang_tb___024root___eval_sample(&(vlSymsp->vlInst.TOP));
}

bool Vila_hang_tb::evalIco(bool firstIteration) {
    return Vila_hang_tb___024root___eval_ico(&(vlSymsp->vlInst.TOP), firstIteration);
}

bool Vila_hang_tb::evalAct() {
    return Vila_hang_tb___024root___eval_act(&(vlSymsp->vlInst.TOP));
}

bool Vila_hang_tb::evalInact() {
    return Vila_hang_tb___024root___eval_inact(&(vlSymsp->vlInst.TOP));
}

bool Vila_hang_tb::evalNba() {
    return Vila_hang_tb___024root___eval_nba(&(vlSymsp->vlInst.TOP));
}

bool Vila_hang_tb::evalObs() {
    return Vila_hang_tb___024root___eval_obs(&(vlSymsp->vlInst.TOP));
}

bool Vila_hang_tb::evalReact() {
    return Vila_hang_tb___024root___eval_react(&(vlSymsp->vlInst.TOP));
}

void Vila_hang_tb::evalPostponed() {
    Vila_hang_tb___024root___eval_postponed(&(vlSymsp->vlInst.TOP));
}

void Vila_hang_tb::evalFinal() {
    Vila_hang_tb___024root___eval_final(&(vlSymsp->vlInst.TOP));
}

VL_ATTR_COLD void Vila_hang_tb::dumpTriggersStl() {
    Vila_hang_tb___024root___eval_dump_triggers__stl(&(vlSymsp->vlInst.TOP));
}

VL_ATTR_COLD void Vila_hang_tb::dumpTriggersIco() {
    Vila_hang_tb___024root___eval_dump_triggers__ico(&(vlSymsp->vlInst.TOP));
}

VL_ATTR_COLD void Vila_hang_tb::dumpTriggersAct() {
    Vila_hang_tb___024root___eval_dump_triggers__act(&(vlSymsp->vlInst.TOP));
}

VL_ATTR_COLD void Vila_hang_tb::dumpTriggersNba() {
    Vila_hang_tb___024root___eval_dump_triggers__nba(&(vlSymsp->vlInst.TOP));
}

VL_ATTR_COLD void Vila_hang_tb::dumpTriggersObs() {
    Vila_hang_tb___024root___eval_dump_triggers__obs(&(vlSymsp->vlInst.TOP));
}

VL_ATTR_COLD void Vila_hang_tb::dumpTriggersReact() {
    Vila_hang_tb___024root___eval_dump_triggers__react(&(vlSymsp->vlInst.TOP));
}

//============================================================
// Events and timing
bool Vila_hang_tb::eventsPending() { return !vlSymsp->vlInst.TOP.__Vnontrivs.__VdlySched.empty() && !contextp()->gotFinish(); }

uint64_t Vila_hang_tb::nextTimeSlot() { return vlSymsp->vlInst.TOP.__Vnontrivs.__VdlySched.nextTimeSlot(); }

//============================================================
// Utilities

const char* Vila_hang_tb::name() const {
    return vlSymsp->name();
}

//============================================================
// Invoke final blocks

VL_ATTR_COLD void Vila_hang_tb::final() {
    contextp()->executingFinal(true);
    evalFinal();
    contextp()->executingFinal(false);
}

//============================================================
// Implementations of abstract methods from VerilatedModel

const char* Vila_hang_tb::hierName() const { return vlSymsp->name(); }
const char* Vila_hang_tb::modelName() const { return "Vila_hang_tb"; }
unsigned Vila_hang_tb::threads() const { return 1; }
void Vila_hang_tb::prepareClone() const { contextp()->prepareClone(); }
void Vila_hang_tb::atClone() const {
    contextp()->threadPoolpOnClone();
}
