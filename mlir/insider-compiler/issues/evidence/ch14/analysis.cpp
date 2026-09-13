#include "mlir/Dialect/Affine/Analysis/AffineAnalysis.h"
#include "mlir/Dialect/Affine/Analysis/Utils.h"
#include "mlir/Dialect/Affine/IR/AffineOps.h"
#include "mlir/Dialect/Arith/IR/Arith.h"
#include "mlir/Dialect/Func/IR/FuncOps.h"
#include "mlir/Dialect/MemRef/IR/MemRef.h"
#include "mlir/IR/BuiltinOps.h"
#include "mlir/Parser/Parser.h"
#include "llvm/Support/raw_ostream.h"
using namespace mlir;
using namespace mlir::affine;
int main(int argc, char **argv) {
  if (argc != 2) return 2;
  MLIRContext context;
  context.loadDialect<AffineDialect, arith::ArithDialect, func::FuncDialect,
                      memref::MemRefDialect>();
  auto module = parseSourceFile<ModuleOp>(argv[1], &context);
  if (!module) return 3;
  for (func::FuncOp func : module->getOps<func::FuncOp>()) {
    llvm::outs() << "FUNCTION " << func.getName() << "\n";
    unsigned depth = 0;
    func.walk<WalkOrder::PreOrder>([&](AffineForOp loop) {
      llvm::outs() << "LOOP " << ++depth << " parallel=" << isLoopParallel(loop) << "\n";
    });
    if (func.getName() == "max_nested_1") {
      AffineLoadOp src;
      AffineStoreOp dst;
      func.walk([&](AffineLoadOp op) {
        if (op.getMemRef().getDefiningOp<memref::AllocOp>()) src = op;
      });
      func.walk([&](AffineStoreOp op) { dst = op; });
      for (unsigned d = 1; d <= 3; ++d) {
        FlatAffineValueConstraints cst;
        auto result = checkMemrefAccessDependence(MemRefAccess(src), MemRefAccess(dst), d, &cst);
        llvm::outs() << "DEPENDENCE depth=" << d << " result=" << static_cast<int>(result.value) << "\n";
        if (hasDependence(result)) { cst.print(llvm::outs()); llvm::outs() << "integerEmpty=" << cst.isIntegerEmpty() << "\n"; }
      }
    } else if (func.getName() == "access") {
      func.walk([&](Operation *op) {
        if (!isa<AffineLoadOp, AffineStoreOp>(op)) return;
        FlatAffineRelation relation;
        if (failed(MemRefAccess(op).getAccessRelation(relation))) return;
        llvm::outs() << op->getName() << "\n";
        relation.print(llvm::outs());
      });
    }
  }
  return 0;
}
