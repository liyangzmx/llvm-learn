func.func @simple_std_for_loop(%arg0: index, %arg1: index, %arg2: index) {
  scf.for %i0 = %arg0 to %arg1 step %arg2 {
    %c1 = arith.constant 1 : index
  }
  return
}
