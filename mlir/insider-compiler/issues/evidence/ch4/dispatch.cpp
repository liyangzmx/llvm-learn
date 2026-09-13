#include "mlir/IR/Builders.h"
#include "mlir/IR/Dialect.h"
#include "mlir/IR/OpDefinition.h"
#include "mlir/IR/Verifier.h"
#include "llvm/Support/raw_ostream.h"
#include "CostInterface.h.inc"
#include "CostInterface.cpp.inc"
using namespace mlir;
static int verificationCount = 0;
class DirectOp : public Op<DirectOp, ComputationCostInterface::Trait> {
public:
  using Op::Op;
  static StringRef getOperationName() { return "cost.direct"; }
  static ArrayRef<StringRef> getAttributeNames() { return {}; }
  int64_t getComputationCost() { return 37; }
  LogicalResult verify() { ++verificationCount; return success(); }
};
class ExternalOp : public Op<ExternalOp> {
public:
  using Op::Op;
  static StringRef getOperationName() { return "cost.external"; }
  static ArrayRef<StringRef> getAttributeNames() { return {}; }
};
class CostDialect : public Dialect {
public:
  explicit CostDialect(MLIRContext *context)
      : Dialect("cost", context, TypeID::get<CostDialect>()) {
    addOperations<DirectOp, ExternalOp>();
  }
  static StringRef getDialectNamespace() { return "cost"; }
};
struct ExternalCost
    : ComputationCostInterface::ExternalModel<ExternalCost, ExternalOp> {
  int64_t getComputationCost(Operation *) const { return 41; }
};
struct ReplacementCost
    : ComputationCostInterface::ExternalModel<ReplacementCost, ExternalOp> {
  int64_t getComputationCost(Operation *) const { return 99; }
};
int main() {
  MLIRContext context;
  context.getOrLoadDialect<CostDialect>();
  Operation *direct = Operation::create(
      OperationState(UnknownLoc::get(&context), "cost.direct"));
  if (verificationCount != 0) return 1;
  if (failed(mlir::verify(direct)) || verificationCount != 1) return 2;
  auto directInterface = dyn_cast<ComputationCostInterface>(direct);
  if (!directInterface || directInterface.getComputationCost() != 37) return 3;
  Operation *external = Operation::create(
      OperationState(UnknownLoc::get(&context), "cost.external"));
  if (isa<ComputationCostInterface>(external)) return 4;
  ExternalOp::attachInterface<ExternalCost>(context);
  auto externalInterface = dyn_cast<ComputationCostInterface>(external);
  if (!externalInterface || externalInterface.getComputationCost() != 41) return 5;
  ExternalOp::attachInterface<ReplacementCost>(context);
  if (cast<ComputationCostInterface>(external).getComputationCost() != 41) return 6;
  direct->destroy();
  external->destroy();
  llvm::outs() << "PASS: direct Model=37, ExternalModel=41, duplicate ignored, explicit verify required\n";
}
