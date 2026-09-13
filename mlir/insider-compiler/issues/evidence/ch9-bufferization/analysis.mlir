// Minimal independent check of buffer reuse, RaW conflicts, and deallocation.
func.func @no_conflict(%fill: f32, %value: f32, %write_index: index,
                       %read_index: index) -> f32 {
  %t = tensor.from_elements %fill, %fill, %fill : tensor<3xf32>
  %updated = tensor.insert %value into %t[%write_index] : tensor<3xf32>
  %result = tensor.extract %updated[%read_index] : tensor<3xf32>
  return %result : f32
}

func.func @conflict(%fill: f32, %value: f32, %write_index: index,
                   %read_index: index) -> (f32, f32) {
  %t = tensor.from_elements %fill, %fill, %fill : tensor<3xf32>
  %updated = tensor.insert %value into %t[%write_index] : tensor<3xf32>
  %old = tensor.extract %t[%read_index] : tensor<3xf32>
  %new = tensor.extract %updated[%read_index] : tensor<3xf32>
  return %old, %new : f32, f32
}
