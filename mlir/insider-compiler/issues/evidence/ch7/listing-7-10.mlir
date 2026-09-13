func.func @cycle(%arg0: i64, %arg1: i1, %arg2: i64) {
  %alloca = memref.alloca() : memref<i64>
  memref.store %arg2, %alloca[] : memref<i64>
  cf.cond_br %arg1, ^bb1, ^bb2
^bb1:
  %use = memref.load %alloca[] : memref<i64>
  call @use(%use) : (i64) -> ()
  memref.store %arg0, %alloca[] : memref<i64>
  cf.br ^bb2
^bb2:
  cf.br ^bb1
}
func.func @use(%arg: i64) { return }
