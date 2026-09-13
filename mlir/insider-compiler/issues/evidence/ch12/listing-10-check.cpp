#include "mlir/IR/PatternMatch.h"
#include "mlir/IR/BuiltinOps.h"
#include "mlir/Parser/Parser.h"
#include "listing-12-10.cpp"
void check(mlir::MLIRContext *context) { ReplaceTenWithEleven pattern(context); }
