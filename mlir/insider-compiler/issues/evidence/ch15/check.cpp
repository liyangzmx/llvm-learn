#include "mlir/Analysis/Presburger/Simplex.h"
#include "llvm/Support/raw_ostream.h"
#include <cstdlib>
using namespace mlir;
using namespace mlir::presburger;
static void require(bool ok, const char *msg) {
  if (!ok) { llvm::errs() << "FAIL " << msg << '\n'; std::exit(1); }
  llvm::outs() << "PASS " << msg << '\n';
}
static void add(SimplexBase &s, std::initializer_list<int64_t> a) {
  SmallVector<MPInt> v; for (auto x : a) v.emplace_back(x); s.addInequality(v);
}
static SmallVector<MPInt> vec(std::initializer_list<int64_t> a) {
  SmallVector<MPInt> v; for (auto x : a) v.emplace_back(x); return v;
}
int main() {
  Simplex lp(2);
  add(lp,{1,0,0}); add(lp,{0,1,0}); add(lp,{2,-1,2});
  add(lp,{-1,2,2}); add(lp,{-1,-1,5});
  auto opt=lp.computeOptimum(Simplex::Direction::Down,vec({1,-1,0}));
  require(opt.isBounded() && *opt==Fraction(-3), "book LP minimum = -3");
  Simplex half(1); add(half,{2,-1}); add(half,{-2,1});
  require(!half.isEmpty(), "2*x = 1 is rational feasible");
  require(!half.findIntegerSample().has_value(), "2*x = 1 has no integer sample");
  Simplex strong(1); add(strong,{1,-2});
  require(strong.isRedundantInequality(vec({1,0})), "x>=2 implies x>=0");
  Simplex weak(1); add(weak,{1,0});
  require(!weak.isRedundantInequality(vec({1,-2})), "x>=0 does not imply x>=2");
  LexSimplex rational(1), integer(1);
  for (auto *s : {&rational,&integer}) { add(*s,{2,-1}); add(*s,{-1,2}); }
  auto r=rational.findRationalLexMin(); auto i=integer.findIntegerLexMin();
  require(r.isBounded() && (*r)[0]==Fraction(1,2), "rational lexmin = 1/2");
  require(i.isBounded() && (*i)[0]==MPInt(1), "integer lexmin = 1 (cut path)");
  MPInt large(int64_t(1)<<62); MPInt square=large*large;
  require(square/large==large && square>large, "MPInt exact multiplication beyond int64");
  llvm::outs() << "square=" << square << '\n';
}
