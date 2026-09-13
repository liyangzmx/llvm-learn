#map = affine_map<(d0)[s0] -> (s0, -d0 + 2000)>
#map1 = affine_map<(d0) -> (d0 - 1)>
module {
  module {
    func.func @matmul(%arg0: tensor<1024x512xf32>, %arg1: tensor<512x2000xf32>, %arg2: tensor<1024x2000xf32>) -> tensor<1024x2000xf32> {
      %c16 = arith.constant 16 : index
      %0 = vector.vscale
      %1 = arith.muli %c16, %0 : index
      %c0 = arith.constant 0 : index
      %c1024 = arith.constant 1024 : index
      %c8 = arith.constant 8 : index
      %2 = scf.for %arg3 = %c0 to %c1024 step %c8 iter_args(%arg4 = %arg2) -> (tensor<1024x2000xf32>) {
        %c0_0 = arith.constant 0 : index
        %c2000 = arith.constant 2000 : index
        %3 = scf.for %arg5 = %c0_0 to %c2000 step %1 iter_args(%arg6 = %arg4) -> (tensor<1024x2000xf32>) {
          %c2000_1 = arith.constant 2000 : index
          %4 = affine.min #map(%arg5)[%1]
          %c0_2 = arith.constant 0 : index
          %c512 = arith.constant 512 : index
          %c1 = arith.constant 1 : index
          %5 = scf.for %arg7 = %c0_2 to %c512 step %c1 iter_args(%arg8 = %arg6) -> (tensor<1024x2000xf32>) {
            %6 = affine.apply #map1(%4)
            %7 = affine.apply #map1(%4)
            %8 = affine.apply #map1(%4)
            %extracted_slice = tensor.extract_slice %arg0[%arg3, %arg7] [8, 1] [1, 1] : tensor<1024x512xf32> to tensor<8x1xf32>
            %extracted_slice_3 = tensor.extract_slice %arg1[%arg7, %arg5] [1, %4] [1, 1] : tensor<512x2000xf32> to tensor<1x?xf32>
            %extracted_slice_4 = tensor.extract_slice %arg8[%arg3, %arg5] [8, %4] [1, 1] : tensor<1024x2000xf32> to tensor<8x?xf32>
            %9 = linalg.matmul ins(%extracted_slice, %extracted_slice_3 : tensor<8x1xf32>, tensor<1x?xf32>) outs(%extracted_slice_4 : tensor<8x?xf32>) -> tensor<8x?xf32>
            %10 = affine.apply #map1(%4)
            %11 = affine.apply #map1(%4)
            %inserted_slice = tensor.insert_slice %9 into %arg8[%arg3, %arg5] [8, %4] [1, 1] : tensor<8x?xf32> into tensor<1024x2000xf32>
            scf.yield %inserted_slice : tensor<1024x2000xf32>
          }
          scf.yield %5 : tensor<1024x2000xf32>
        }
        scf.yield %3 : tensor<1024x2000xf32>
      }
      return %2 : tensor<1024x2000xf32>
    }
  }
  module attributes {transform.with_named_sequence} {
    transform.named_sequence @__transform_main(%arg0: !transform.any_op {transform.readonly}) {
      %0 = transform.structured.match ops{["linalg.matmul"]} in %arg0 : (!transform.any_op) -> !transform.any_op
      %tiled_linalg_op, %loops:3 = transform.structured.tile_using_for %0[8, [16], 1] : (!transform.any_op) -> (!transform.any_op, !transform.op<"scf.for">, !transform.op<"scf.for">, !transform.op<"scf.for">)
      transform.yield 
    }
  }
}

