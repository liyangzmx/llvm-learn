module {
  func.func @matmul(%arg0: memref<?xi8>, %arg1: memref<?xi8>, %arg2: memref<?xi8>, %arg3: index, %arg4: index, %arg5: index) {
    %c1 = arith.constant 1 : index
    %c0 = arith.constant 0 : index
    %view = memref.view %arg0[%c0][%arg3, %arg5] : memref<?xi8> to memref<?x?xf32>
    %view_0 = memref.view %arg1[%c0][%arg5, %arg4] : memref<?xi8> to memref<?x?xf32>
    %view_1 = memref.view %arg2[%c0][%arg3, %arg4] : memref<?xi8> to memref<?x?xf32>
    scf.for %arg6 = %c0 to %arg3 step %c1 {
      scf.for %arg7 = %c0 to %arg4 step %c1 {
        scf.for %arg8 = %c0 to %arg5 step %c1 {
          %0 = memref.load %view[%arg6, %arg8] : memref<?x?xf32>
          %1 = memref.load %view_0[%arg8, %arg7] : memref<?x?xf32>
          %2 = memref.load %view_1[%arg6, %arg7] : memref<?x?xf32>
          %3 = arith.mulf %0, %1 : f32
          %4 = arith.addf %2, %3 : f32
          memref.store %4, %view_1[%arg6, %arg7] : memref<?x?xf32>
        }
      }
    }
    return
  }
}

