#include "mlir/IR/BuiltinOps.h"
#include "mlir/IR/Dominance.h"
#include "mlir/Dialect/SPIRV/IR/SPIRVOps.h"
#include "mlir/Pass/Pass.h"
#include "mlir/Pass/PassManager.h"
#include "mlir/Pass/PassRegistry.h"
#include "mlir/Transforms/Passes.h"
#include "mlir/Dialect/Affine/Passes.h"
using namespace mlir;
struct DominanceCounterInstrumentation : public PassInstrumentation {
  unsigned &count;
  DominanceCounterInstrumentation(unsigned &count) : count(count) {}
  void runAfterAnalysis(llvm::StringRef, TypeID id, Operation *) override {
    if (id == TypeID::get<DominanceInfo>()) ++count;
  }
};
void check(MLIRContext *ctx) {
  auto pm = PassManager::on<ModuleOp>(ctx);
  auto &nested = pm.nest<spirv::ModuleOp>();
  nested.nest<spirv::FuncOp>().addPass(createCSEPass());
  auto &any = nested.nestAny();
  any.addPass(createCanonicalizerPass());
  any.addPass(createCSEPass());
  unsigned count = 0;
  pm.addInstrumentation(std::make_unique<DominanceCounterInstrumentation>(count));
  PassPipelineRegistration<>("example", "example", [](OpPassManager &pm) {
    pm.addPass(createCSEPass());
  });
  registerPass([]() -> std::unique_ptr<Pass> {
    return affine::createAffineLoopInvariantCodeMotionPass();
  });
}
