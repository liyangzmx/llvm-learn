#include "mlir/Conversion/LLVMCommon/TypeConverter.h"
#include "mlir/Dialect/LLVMIR/LLVMDialect.h"
#include "mlir/IR/MLIRContext.h"
#include "mlir/AsmParser/AsmParser.h"
#include "llvm/Support/raw_ostream.h"

int main() {
  mlir::MLIRContext context;
  context.getOrLoadDialect<mlir::LLVM::LLVMDialect>();
  mlir::LLVMTypeConverter converter(&context);
  const char *inputs[] = {
    "memref<f32>", "memref<1xf32>", "memref<?xf32>",
    "memref<10x42x42x43x123xf32>", "memref<10x?x42x?x123xf32>",
    "memref<1x?xvector<4xf32>>", "memref<*xf32>", "memref<?xf32, 3>",
    "vector<f32>", "vector<4xf32>", "vector<2x3x4xf32>"
  };
  for (const char *input : inputs) {
    auto type = mlir::parseType(input, &context);
    if (!type) return 2;
    auto result = converter.convertType(type);
    if (!result) return 3;
    llvm::outs() << input << " -> " << result << '\n';
  }
}
