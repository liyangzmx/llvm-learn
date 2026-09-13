module {
  func.func @tensor.extract(%arg0: tensor<?xf32>, %arg1: index) -> f32 {
    %0 = bufferization.to_memref %arg0 : memref<?xf32, strided<[?], offset: ?>>
    %1 = memref.load %0[%arg1] : memref<?xf32, strided<[?], offset: ?>>
    return %1 : f32
  }
}
