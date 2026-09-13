#include "mlir/IR/BuiltinAttributes.h"
#include "mlir/IR/BuiltinDialect.h"
#include "mlir/IR/BuiltinTypes.h"
#include "mlir/IR/Dialect.h"
#include "mlir/IR/DialectRegistry.h"
#include "mlir/IR/MLIRContext.h"
#include <cassert>
#include <iostream>
using namespace mlir;
class FirstDialect : public Dialect {
public:
  MLIR_DEFINE_EXPLICIT_INTERNAL_INLINE_TYPE_ID(FirstDialect)
  static StringRef getDialectNamespace() { return "first"; }
  FirstDialect(MLIRContext *c) : Dialect(getDialectNamespace(), c, TypeID::get<FirstDialect>()) {}
};
class SecondDialect : public Dialect {
public:
  MLIR_DEFINE_EXPLICIT_INTERNAL_INLINE_TYPE_ID(SecondDialect)
  static StringRef getDialectNamespace() { return "second"; }
  SecondDialect(MLIRContext *c) : Dialect(getDialectNamespace(), c, TypeID::get<SecondDialect>()) {}
};
int main() {
  unsigned calls = 0;
  DialectRegistry registry;
  registry.insert<FirstDialect, SecondDialect>();
  registry.addExtension(std::function<void(MLIRContext *, FirstDialect *, SecondDialect *)>(
      [&](MLIRContext *c, FirstDialect *first, SecondDialect *second) {
        assert(first->getContext() == c && second->getContext() == c);
        assert(first->getNamespace() == "first" && second->getNamespace() == "second");
        ++calls;
      }));
  MLIRContext c(registry, MLIRContext::Threading::DISABLED);
  assert(c.getLoadedDialect<BuiltinDialect>());
  assert(!c.getLoadedDialect<FirstDialect>() && !c.getLoadedDialect<SecondDialect>());
  auto *first = c.getOrLoadDialect<FirstDialect>();
  assert(calls == 0);
  c.getOrLoadDialect<SecondDialect>();
  assert(calls == 1 && c.getOrLoadDialect<FirstDialect>() == first);
  assert(calls == 1);
  MLIRContext another(MLIRContext::Threading::DISABLED);
  assert(Float32Type::get(&c) != Float32Type::get(&another));
  auto i1 = IntegerType::get(&c, 1), i7 = IntegerType::get(&c, 7);
  assert(i1.getTypeID() == i7.getTypeID());
  assert(i7 == IntegerType::get(&c, 7));
  auto f32 = Float32Type::get(&c);
  auto ranked = MemRefType::get({ShapedType::kDynamic}, f32);
  assert(ranked.hasRank() && !ranked.hasStaticShape());
  assert(ranked.clone(ranked.getShape()) == ranked);
  auto zero = MemRefType::get({0}, f32);
  assert(zero.hasStaticShape() && zero.getNumElements() == 0);
  auto space = IntegerAttr::get(IntegerType::get(&c, 64), 3);
  auto unranked = UnrankedMemRefType::get(f32, space);
  assert(!unranked.hasRank() && unranked.getMemorySpace() == space);
  assert(DistinctAttr::create(UnitAttr::get(&c)) != DistinctAttr::create(UnitAttr::get(&c)));
  std::cout << "PASS: lazy loading; two-dialect extension ordering; per-context uniquing; IntegerType kind; ranked dynamic shape; clone reuse; zero extent; unranked memory space; DistinctAttr identity\n";
}
