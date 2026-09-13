include "mlir/IR/OpBase.td"
def ComputationCostInterface : OpInterface<"ComputationCostInterface"> {
  let description = [{ get Op computation cost }];
  let cppNamespace = "::mlir";
  let methods = [InterfaceMethod<[{}], "int64_t", "getComputationCost", (ins)>];
}
