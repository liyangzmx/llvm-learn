#include "mlir/IR/PatternMatch.h"
#include "mlir/IR/BuiltinOps.h"
#include "mlir/Parser/Parser.h"
#include "pdll-cpp.out"
void checkGeneratedPDLL(mlir::RewritePatternSet &patterns) {
  populateGeneratedPDLLPatterns(patterns);
}
