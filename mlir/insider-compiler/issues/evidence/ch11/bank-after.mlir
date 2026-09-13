module {
  func.func @shared_memory(%arg0: f32, %arg1: index, %arg2: index) -> f32 {
    %alloc = memref.alloc() : memref<128x128xf32, 3>
    %c31 = arith.constant 31 : index
    %0 = arith.andi %arg1, %c31 : index
    %c2 = arith.constant 2 : index
    %1 = arith.shli %0, %c2 : index
    %2 = arith.xori %arg2, %1 : index
    memref.store %arg0, %alloc[%arg1, %2] : memref<128x128xf32, 3>
    %c31_0 = arith.constant 31 : index
    %3 = arith.andi %arg1, %c31_0 : index
    %c2_1 = arith.constant 2 : index
    %4 = arith.shli %3, %c2_1 : index
    %5 = arith.xori %arg2, %4 : index
    %6 = memref.load %alloc[%arg1, %5] : memref<128x128xf32, 3>
    memref.dealloc %alloc : memref<128x128xf32, 3>
    return %6 : f32
  }
}

