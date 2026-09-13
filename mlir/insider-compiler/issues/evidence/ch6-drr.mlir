func.func @equal(%a: i32, %b: i32, %c: i32, %d: i32, %e: i32, %f: i32) -> i32 {
  %p = "test.op_p"(%a, %b, %c, %d, %e, %f) : (i32, i32, i32, i32, i32, i32) -> i32
  %n = "test.op_n"(%b, %p) : (i32, i32) -> i32
  return %n : i32
}
func.func @unequal(%a: i32, %b: i32, %c: i32, %d: i32, %e: i32, %f: i32) -> i32 {
  %p = "test.op_p"(%a, %b, %c, %d, %e, %f) : (i32, i32, i32, i32, i32, i32) -> i32
  %n = "test.op_n"(%a, %p) : (i32, i32) -> i32
  return %n : i32
}
