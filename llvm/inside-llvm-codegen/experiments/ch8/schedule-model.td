// A self-contained TableGen teaching target. Parsing/record validation does not
// make this a registered LLVM backend or an executable processor simulator.
include "llvm/Target/Target.td"
def R0 : Register<"r0">;
def GPR : RegisterClass<"Demo", [i32], 32, (add R0)>;
def II_ALUrr : InstrItinClass;
def II_CSRrr : InstrItinClass;
def ISSUE : FuncUnit;
def ALU : FuncUnit;
def CSR : FuncUnit;
def DemoItineraries : ProcessorItineraries<[ISSUE, ALU, CSR], [], [
  InstrItinData<II_CSRrr,
    [InstrStage<1, [ISSUE], 0>, InstrStage<1, [ALU], 2>,
     InstrStage<1, [CSR], 0>], [4, 4]>,
  InstrItinData<II_ALUrr,
    [InstrStage<1, [ISSUE]>, InstrStage<1, [ALU]>], [2, 2, 2]>
]>;
def ALUOut : SchedWrite;
def MULOut : SchedWrite;
def EXIn : SchedRead;
def OrdinaryRead : SchedRead;
def DemoModel : SchedMachineModel {
  let IssueWidth = 1;
  let CompleteModel = 0;
}
let SchedModel = DemoModel in {
  def UnitALU : ProcResource<1>;
  def : WriteRes<ALUOut, [UnitALU]> { let Latency = 2; }
  def : WriteRes<MULOut, [UnitALU]> { let Latency = 4; }
  def : ReadAdvance<EXIn, 1, [ALUOut]>;
  def : ReadAdvance<OrdinaryRead, 0>;
}
class BinOp<list<SchedReadWrite> rw> : Instruction {
  let Namespace = "Demo";
  let OutOperandList = (outs GPR:$dst);
  let InOperandList = (ins GPR:$src1, GPR:$src2);
  let SchedRW = rw;
  let Itinerary = II_ALUrr;
  let hasSideEffects = 0;
  let mayLoad = 0;
  let mayStore = 0;
}
def DemoADD : BinOp<[ALUOut, OrdinaryRead, OrdinaryRead]>;
def DemoMUL : BinOp<[MULOut, EXIn, OrdinaryRead]>;
def DemoInstrInfo : InstrInfo;
def Demo : Target { let InstructionSet = DemoInstrInfo; }
