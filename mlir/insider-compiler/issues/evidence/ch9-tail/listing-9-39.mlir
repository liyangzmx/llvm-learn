#map = affine_map<(d0)[s0] -> (-d0 + 2000, s0)>
module {
  func.func @matmul(%arg0: tensor<1024x512xf32>,
                    %arg1: tensor<512x2000xf32>,
                    %arg2: tensor<1024x2000xf32>) -> tensor<1024x2000xf32> {
    %c16 = arith.constant 16 : index
    %vscale = vector.vscale
    %c16_vscale = arith.muli %c16, %vscale : index
    %c0 = arith.constant 0 : index
    %c1024 = arith.constant 1024 : index
    %c2000 = arith.constant 2000 : index
    %c512 = arith.constant 512 : index
    %c8 = arith.constant 8 : index
    %c1 = arith.constant 1 : index
    %0 = scf.for %arg3 = %c0 to %c1024 step %c8
        iter_args(%arg4 = %arg2) -> (tensor<1024x2000xf32>) {
      %1 = scf.for %arg5 = %c0 to %c2000 step %c16_vscale
          iter_args(%arg6 = %arg4) -> (tensor<1024x2000xf32>) {
        %2 = scf.for %arg7 = %c0 to %c512 step %c1
            iter_args(%arg8 = %arg6) -> (tensor<1024x2000xf32>) {
          %3 = affine.min #map(%arg5)[%c16_vscale]
          %extracted_slice = tensor.extract_slice %arg0[%arg3, %arg7]
              [8, 1] [1, 1] : tensor<1024x512xf32> to tensor<8x1xf32>
          %extracted_slice_0 = tensor.extract_slice %arg1[%arg7, %arg5]
              [1, %3] [1, 1] : tensor<512x2000xf32> to tensor<1x?xf32>
          %extracted_slice_1 = tensor.extract_slice %arg8[%arg3, %arg5]
              [8, %3] [1, 1] : tensor<1024x2000xf32> to tensor<8x?xf32>
          %4 = linalg.matmul
              ins(%extracted_slice, %extracted_slice_0
                  : tensor<8x1xf32>, tensor<1x?xf32>)
              outs(%extracted_slice_1 : tensor<8x?xf32>) -> tensor<8x?xf32>
          %inserted_slice = tensor.insert_slice %4 into %arg8[%arg3, %arg5]
              [8, %3] [1, 1] : tensor<8x?xf32> into tensor<1024x2000xf32>
          scf.yield %inserted_slice : tensor<1024x2000xf32>
        }
        scf.yield %2 : tensor<1024x2000xf32>
      }
      scf.yield %1 : tensor<1024x2000xf32>
    }
    return %0 : tensor<1024x2000xf32>
  }
}
