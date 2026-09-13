#include "mlir/IR/Operation.h"
#include "mlir/Dialect/Arith/IR/Arith.h"
#include <cstdio>
#include <type_traits>
#include <utility>

using AddIHandle = decltype(llvm::dyn_cast<mlir::arith::AddIOp>(
    std::declval<mlir::Operation *>()));
static_assert(std::is_same_v<AddIHandle, mlir::arith::AddIOp>);
static_assert(!std::is_pointer_v<AddIHandle>);

int main() {
  std::printf("maxInlineResults=%u\n",
              mlir::detail::OpResultImpl::getMaxInlineResults());
  std::printf("sizeof(Operation)=%zu alignof(Operation)=%zu\n",
              sizeof(mlir::Operation), alignof(mlir::Operation));
  std::printf("sizeof(AddIOp)=%zu sizeof(Operation*)=%zu\n",
              sizeof(mlir::arith::AddIOp), sizeof(mlir::Operation *));
  std::printf("InlineOpResult=%zu OutOfLineOpResult=%zu\n",
              sizeof(mlir::detail::InlineOpResult),
              sizeof(mlir::detail::OutOfLineOpResult));
  std::printf("OperandStorage=%zu OpProperties=%zu BlockOperand=%zu Region=%zu OpOperand=%zu\n",
              sizeof(mlir::detail::OperandStorage), sizeof(mlir::detail::OpProperties),
              sizeof(mlir::BlockOperand), sizeof(mlir::Region), sizeof(mlir::OpOperand));
}
