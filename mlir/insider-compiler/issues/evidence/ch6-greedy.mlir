func.func @f(%arg0: i1) {
  %0 = arith.constant 0 : i32
  %if = scf.if %arg0 -> (i32) {
    scf.yield %0 : i32
  } else {
    scf.yield %0 : i32
  }
  %dead_leaf = arith.addi %if, %if : i32
  return
}
