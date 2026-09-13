func.func @use(%arg0: i64) {
  return
}
func.func @cycle(%arg0: i64, %arg1: i1, %arg2: i64) {
  cf.cond_br %arg1, ^bb1(%arg2 : i64), ^bb2(%arg2 : i64)
^bb1(%0: i64):  // 2 preds: ^bb0, ^bb2
  call @use(%0) : (i64) -> ()
  cf.br ^bb2(%arg0 : i64)
^bb2(%1: i64):  // 2 preds: ^bb0, ^bb1
  cf.br ^bb1(%1 : i64)
}
