#include "mlir/IR/PatternMatch.h"
#include "mlir/Transforms/DialectConversion.h"
using namespace mlir;

// Syntax-check the corrected LLVM 18.1.8 constructor and virtual signatures.
class MyPattern : public RewritePattern {
public:
  MyPattern(PatternBenefit benefit, MLIRContext *context)
      : RewritePattern("test.my_op", benefit, context) {}
  MyPattern(MatchAnyOpTypeTag tag, PatternBenefit benefit, MLIRContext *context)
      : RewritePattern(tag, benefit, context) {}
  LogicalResult match(Operation *op) const override;
  void rewrite(Operation *op, PatternRewriter &rewriter) const override;
};

struct MyConversionPattern : public ConversionPattern {
  using ConversionPattern::ConversionPattern;
  LogicalResult matchAndRewrite(Operation *op, ArrayRef<Value> operands,
                               ConversionPatternRewriter &rewriter) const override;
};
