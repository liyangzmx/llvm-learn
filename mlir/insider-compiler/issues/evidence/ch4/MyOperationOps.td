include "mlir/IR/OpBase.td"
include "mlir/Interfaces/SideEffectInterfaces.td"
def MyDialect : Dialect { let name = "my"; let cppNamespace = "::my"; }
class MyDialect_Op<string mnemonic, list<Trait> traits = []> : Op<MyDialect, mnemonic, traits>;
def MyOperation : MyDialect_Op<"MyOperation", [Pure]> {
  let arguments = (ins F16:$lhs, F32:$rhs);
  let results = (outs F64:$result);
}
def MyTrait : NativeOpTrait<"MyTrait">;
class MyParametricTrait<int prop> : ParamNativeOpTrait<"MyParametricTrait", !cast<string>(prop)>;
class CheckNumOperands<int i> : CPred<"$_op.getNumOperands() == " # i>;
def TraitTestOp : MyDialect_Op<"trait_test", [MyTrait, MyParametricTrait<10>, PredOpTrait<"has two operands", CheckNumOperands<2>>]> {
  let arguments = (ins F16:$lhs, F32:$rhs);
  let results = (outs F64:$result);
}
