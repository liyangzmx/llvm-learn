module {
  func.func @test_scf_if_sink(%arg0: i1, %arg1: i32) -> i32 {
    %0 = scf.if %arg0 -> (i32) {
      %1 = arith.addi %arg1, %arg1 : i32
      scf.yield %1 : i32
    } else {
      %1 = arith.muli %arg1, %arg1 : i32
      scf.yield %1 : i32
    }
    return %0 : i32
  }
}

