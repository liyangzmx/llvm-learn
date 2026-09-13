module @patterns {
  pdl.pattern @ReplaceTenWithEleven : benefit(0) {
    %0 = operands loc(#loc1)
    %1 = attribute = 10 : i32 loc(#loc2)
    %2 = types loc(#loc1)
    %3 = operation "arith.constant"(%0 : !pdl.range<value>)  {"value" = %1} -> (%2 : !pdl.range<type>) loc(#loc1)
    rewrite %3 {
      %4 = attribute = 11 : i32 loc(#loc4)
      %5 = operation "arith.constant"  {"value" = %4} loc(#loc5)
      replace %3 with %5 loc(#loc6)
    } loc(#loc3)
  } loc(#loc)
} loc(#loc)
#loc = loc("/opt/coding/mlir-toy/mlir/insider-compiler/issues/evidence/ch12/replace.pdll":1:1)
#loc1 = loc("/opt/coding/mlir-toy/mlir/insider-compiler/issues/evidence/ch12/replace.pdll":3:18)
#loc2 = loc("/opt/coding/mlir-toy/mlir/insider-compiler/issues/evidence/ch12/replace.pdll":3:46)
#loc3 = loc("/opt/coding/mlir-toy/mlir/insider-compiler/issues/evidence/ch12/replace.pdll":5:3)
#loc4 = loc("/opt/coding/mlir-toy/mlir/insider-compiler/issues/evidence/ch12/replace.pdll":6:48)
#loc5 = loc("/opt/coding/mlir-toy/mlir/insider-compiler/issues/evidence/ch12/replace.pdll":6:20)
#loc6 = loc("/opt/coding/mlir-toy/mlir/insider-compiler/issues/evidence/ch12/replace.pdll":7:5)

module @ir {
  func.func @constant() -> i32 {
    %c = arith.constant 10 : i32
    return %c : i32
  }
}
