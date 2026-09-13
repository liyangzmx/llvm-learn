module {
  func.func @matmul(%arg0: tensor<1024x512xf32>, %arg1: tensor<512x2000xf32>, %arg2: tensor<1024x2000xf32>) -> tensor<1024x2000xf32> {
    %0 = linalg.matmul ins(%arg0, %arg1 : tensor<1024x512xf32>, tensor<512x2000xf32>) outs(%arg2 : tensor<1024x2000xf32>) -> tensor<1024x2000xf32>
    return %0 : tensor<1024x2000xf32>
  }
}
