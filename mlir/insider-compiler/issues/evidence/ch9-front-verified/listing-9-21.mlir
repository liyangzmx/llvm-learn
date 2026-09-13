module {
  func.func @matmul_tensors(%arg0: tensor<?x?xf32>, %arg1: tensor<?x?xf32>, %arg2: tensor<?x?xf32>) -> tensor<?x?xf32> {
    %c1 = arith.constant 1 : index
    %c3 = arith.constant 3 : index
    %c0 = arith.constant 0 : index
    %c2 = arith.constant 2 : index
    %c4 = arith.constant 4 : index
    %dim = tensor.dim %arg2, %c0 : tensor<?x?xf32>
    %dim_0 = tensor.dim %arg2, %c1 : tensor<?x?xf32>
    %dim_1 = tensor.dim %arg1, %c1 : tensor<?x?xf32>
    %dim_2 = tensor.dim %arg0, %c1 : tensor<?x?xf32>
    %dim_3 = tensor.dim %arg1, %c0 : tensor<?x?xf32>
    %0 = scf.for %arg3 = %c0 to %dim step %c2 iter_args(%arg4 = %arg2) -> (tensor<?x?xf32>) {
      %extracted_slice = tensor.extract_slice %arg0[%arg3, 0] [2, %dim_2] [1, 1] : tensor<?x?xf32> to tensor<2x?xf32>
      %1 = scf.for %arg5 = %c0 to %dim_1 step %c3 iter_args(%arg6 = %arg4) -> (tensor<?x?xf32>) {
        %2 = scf.for %arg7 = %c0 to %dim_0 step %c4 iter_args(%arg8 = %arg6) -> (tensor<?x?xf32>) {
          %extracted_slice_4 = tensor.extract_slice %arg8[%arg3, %arg5] [2, 3] [1, 1] : tensor<?x?xf32> to tensor<2x3xf32>
          %extracted_slice_5 = tensor.extract_slice %arg1[%arg7, %arg5] [4, 3] [1, 1] : tensor<?x?xf32> to tensor<4x3xf32>
          %extracted_slice_6 = tensor.extract_slice %arg2[%arg3, %arg7] [2, 4] [1, 1] : tensor<?x?xf32> to tensor<2x4xf32>
          %extracted_slice_7 = tensor.extract_slice %arg1[0, %arg7] [%dim_3, 4] [1, 1] : tensor<?x?xf32> to tensor<?x4xf32>
          %3 = linalg.matmul ins(%extracted_slice, %extracted_slice_7 : tensor<2x?xf32>, tensor<?x4xf32>) outs(%extracted_slice_6 : tensor<2x4xf32>) -> tensor<2x4xf32>
          %4 = linalg.matmul ins(%3, %extracted_slice_5 : tensor<2x4xf32>, tensor<4x3xf32>) outs(%extracted_slice_4 : tensor<2x3xf32>) -> tensor<2x3xf32>
          %inserted_slice = tensor.insert_slice %4 into %arg8[%arg3, %arg5] [2, 3] [1, 1] : tensor<2x3xf32> into tensor<?x?xf32>
          scf.yield %inserted_slice : tensor<?x?xf32>
        }
        scf.yield %2 : tensor<?x?xf32>
      }
      scf.yield %1 : tensor<?x?xf32>
    }
    return %0 : tensor<?x?xf32>
  }
}
