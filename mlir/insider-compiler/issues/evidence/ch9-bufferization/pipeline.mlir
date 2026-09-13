module {
  func.func @no_conflict(%arg0: f32, %arg1: f32, %arg2: index, %arg3: index) -> f32 {
    %from_elements = tensor.from_elements %arg0, %arg0, %arg0 : tensor<3xf32>
    %inserted = tensor.insert %arg1 into %from_elements[%arg2] : tensor<3xf32>
    %extracted = tensor.extract %inserted[%arg3] : tensor<3xf32>
    return %extracted : f32
  }
  func.func @conflict(%arg0: f32, %arg1: f32, %arg2: index, %arg3: index) -> (f32, f32) {
    %from_elements = tensor.from_elements %arg0, %arg0, %arg0 : tensor<3xf32>
    %inserted = tensor.insert %arg1 into %from_elements[%arg2] : tensor<3xf32>
    %extracted = tensor.extract %from_elements[%arg3] : tensor<3xf32>
    %extracted_0 = tensor.extract %inserted[%arg3] : tensor<3xf32>
    return %extracted, %extracted_0 : f32, f32
  }
}

