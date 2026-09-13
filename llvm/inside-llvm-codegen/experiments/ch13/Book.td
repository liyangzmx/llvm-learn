// A complete TableGen input, but not a complete llc backend.
include "llvm/Target/Target.td"

class BookReg<bits<16> encoding, string name> : Register<name> {
  let Namespace = "Book";
  let HWEncoding = encoding;
}
def R0 : BookReg<0, "r0">;
def R1 : BookReg<1, "r1">;
def R2 : BookReg<2, "r2">;
def R3 : BookReg<3, "r3">;
def GPR : RegisterClass<"Book", [i32], 32, (add R0, R1, R2, R3)>;

def ADDrr : Instruction {
  let Namespace = "Book";
  let Size = 2;
  let OutOperandList = (outs GPR:$dst);
  let InOperandList = (ins GPR:$lhs, GPR:$rhs);
  let AsmString = "add $dst, $lhs, $rhs";
  let Pattern = [(set i32:$dst, (add i32:$lhs, i32:$rhs))];
  let hasSideEffects = 0;
  let mayLoad = 0;
  let mayStore = 0;
  bits<2> dst;
  bits<2> lhs;
  bits<2> rhs;
  field bits<16> Inst;
  field bits<16> SoftFail = 0;
  let Inst{15-12} = 0b0001;
  let Inst{11-10} = dst;
  let Inst{9-8} = lhs;
  let Inst{7-6} = rhs;
  let Inst{5-0} = 0;
}

def BookInstrInfo : InstrInfo;
def Book : Target {
  let InstructionSet = BookInstrInfo;
}
