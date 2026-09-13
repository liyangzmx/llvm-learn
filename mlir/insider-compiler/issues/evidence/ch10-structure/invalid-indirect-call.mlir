// Generic syntax deliberately gives the callee and argument different types.
func.func @bad(%callee: (i32) -> i32, %value: f32) -> i32 {
  %r = "func.call_indirect"(%callee, %value) : ((i32) -> i32, f32) -> i32
  return %r : i32
}
