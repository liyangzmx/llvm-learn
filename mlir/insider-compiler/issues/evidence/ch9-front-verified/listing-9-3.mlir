func.func @matmul(%bufferA: memref<?xi8>, %bufferB: memref<?xi8>,
                  %bufferC: memref<?xi8>, %M: index, %N: index, %K: index) {
  %c0 = arith.constant 0 : index
  %c1 = arith.constant 1 : index
  %A = memref.view %bufferA[%c0][%M, %K] : memref<?xi8> to memref<?x?xf32>
  %B = memref.view %bufferB[%c0][%K, %N] : memref<?xi8> to memref<?x?xf32>
  %C = memref.view %bufferC[%c0][%M, %N] : memref<?xi8> to memref<?x?xf32>
  linalg.matmul ins(%A, %B : memref<?x?xf32>, memref<?x?xf32>)
                outs(%C : memref<?x?xf32>)
  return
}
