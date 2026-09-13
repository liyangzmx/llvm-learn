// Index-rewrite fixture; no GPU performance measurement is implied.
func.func @shared_memory(%value: f32, %row: index, %col: index) -> f32 {
  %smem = memref.alloc() : memref<128x128xf32, 3>
  memref.store %value, %smem[%row, %col] : memref<128x128xf32, 3>
  %result = memref.load %smem[%row, %col] : memref<128x128xf32, 3>
  memref.dealloc %smem : memref<128x128xf32, 3>
  return %result : f32
}
