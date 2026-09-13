include "CostInterface.td"
def Uniform : Dialect { let name = "uniform"; let cppNamespace = "::uniform"; }
class Uniform_Op<string mnemonic, list<Trait> traits = []> : Op<Uniform, mnemonic, traits>;
def Uniform_Conv2D1Op : Uniform_Op<"Conv2D1", [ComputationCostInterface]> {
  let extraClassDeclaration = [{ int64_t getComputationCost(); }];
}
def Uniform_Conv2D2Op : Uniform_Op<"Conv2D2", [DeclareOpInterfaceMethods<ComputationCostInterface>]>;
def Uniform_Conv2D3Op : Uniform_Op<"Conv2D3", [DeclareOpInterfaceMethods<ComputationCostInterface, ["getComputationCost"]>]>;
