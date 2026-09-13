module {
  func.func private @linalg_dot_viewsxf32_viewsxf32_viewf32(memref<?xf32, strided<[?], offset: ?>>, memref<?xf32, strided<[?], offset: ?>>, memref<f32, strided<[], offset: ?>>) attributes {llvm.emit_c_interface}
  func.func @dot(%arg0: memref<?xf32, strided<[1], offset: ?>>, %arg1: memref<?xf32, strided<[1], offset: ?>>, %arg2: memref<f32>) {
    %cast = memref.cast %arg0 : memref<?xf32, strided<[1], offset: ?>> to memref<?xf32, strided<[?], offset: ?>>
    %cast_0 = memref.cast %arg1 : memref<?xf32, strided<[1], offset: ?>> to memref<?xf32, strided<[?], offset: ?>>
    %cast_1 = memref.cast %arg2 : memref<f32> to memref<f32, strided<[], offset: ?>>
    call @linalg_dot_viewsxf32_viewsxf32_viewf32(%cast, %cast_0, %cast_1) : (memref<?xf32, strided<[?], offset: ?>>, memref<?xf32, strided<[?], offset: ?>>, memref<f32, strided<[], offset: ?>>) -> ()
    return
  }
}
