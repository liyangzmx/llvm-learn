module {
  func.func @conversion_static(%arg0: memref<2xf32>) -> memref<2xf32> {
    %alloc = memref.alloc() : memref<2xf32>
    memref.copy %arg0, %alloc : memref<2xf32> to memref<2xf32>
    memref.dealloc %arg0 : memref<2xf32>
    return %alloc : memref<2xf32>
  }
}

