module {
  func.func @no_conflict(%arg0: f32, %arg1: f32, %arg2: index, %arg3: index) -> f32 {
    %c2 = arith.constant 2 : index
    %c1 = arith.constant 1 : index
    %c0 = arith.constant 0 : index
    %alloc = memref.alloc() {alignment = 64 : i64} : memref<3xf32>
    memref.store %arg0, %alloc[%c0] : memref<3xf32>
    memref.store %arg0, %alloc[%c1] : memref<3xf32>
    memref.store %arg0, %alloc[%c2] : memref<3xf32>
    memref.store %arg1, %alloc[%arg2] : memref<3xf32>
    %0 = memref.load %alloc[%arg3] : memref<3xf32>
    memref.dealloc %alloc : memref<3xf32>
    return %0 : f32
  }
  func.func @conflict(%arg0: f32, %arg1: f32, %arg2: index, %arg3: index) -> (f32, f32) {
    %c2 = arith.constant 2 : index
    %c1 = arith.constant 1 : index
    %c0 = arith.constant 0 : index
    %alloc = memref.alloc() {alignment = 64 : i64} : memref<3xf32>
    memref.store %arg0, %alloc[%c0] : memref<3xf32>
    memref.store %arg0, %alloc[%c1] : memref<3xf32>
    memref.store %arg0, %alloc[%c2] : memref<3xf32>
    %alloc_0 = memref.alloc() {alignment = 64 : i64} : memref<3xf32>
    memref.copy %alloc, %alloc_0 : memref<3xf32> to memref<3xf32>
    memref.store %arg1, %alloc_0[%arg2] : memref<3xf32>
    %0 = memref.load %alloc[%arg3] : memref<3xf32>
    %1 = memref.load %alloc_0[%arg3] : memref<3xf32>
    memref.dealloc %alloc : memref<3xf32>
    memref.dealloc %alloc_0 : memref<3xf32>
    return %0, %1 : f32, f32
  }
}

