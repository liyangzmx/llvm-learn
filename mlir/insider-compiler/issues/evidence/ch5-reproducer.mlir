func.func @foo() {
  %0 = arith.constant 0 : i32
  return
}
func.func @bar() {
  return
}
{-#
  external_resources: {
    mlir_reproducer: {
      verify_each: true,
      pipeline: "builtin.module(func.func(cse,canonicalize{max-iterations=1 max-num-rewrites=-1 region-simplify=false top-down=false}))",
      disable_threading: true
    }
  }
#-}
