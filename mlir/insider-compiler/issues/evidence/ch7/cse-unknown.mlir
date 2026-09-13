func.func @unknown(%a: i32) -> (i32, i32) {
  %0 = "unknown.op"(%a) : (i32) -> i32
  %1 = "unknown.op"(%a) : (i32) -> i32
  return %0, %1 : i32, i32
}
