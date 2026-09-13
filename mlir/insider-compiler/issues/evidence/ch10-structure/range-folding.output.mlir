module {
  func.func @nonzero_lower_bound(%arg0: memref<10xindex>) {
    %c1 = arith.constant 1 : index
    %c2 = arith.constant 2 : index
    %c4 = arith.constant 4 : index
    %0 = arith.muli %c4, %c2 : index
    %1 = arith.muli %c1, %c2 : index
    scf.for %arg1 = %c1 to %0 step %1 {
      memref.store %arg1, %arg0[%arg1] : memref<10xindex>
    }
    return
  }
}

