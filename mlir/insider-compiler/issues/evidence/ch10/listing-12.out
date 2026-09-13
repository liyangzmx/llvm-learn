module {
  func.func @tensor.extract(%arg0: tensor<?xf32>, %arg1: index) -> f32 {
    %extracted = tensor.extract %arg0[%arg1] : tensor<?xf32>
    return %extracted : f32
  }
}

