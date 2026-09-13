func.func @callee(%x: i32) -> i32 { return %x : i32 }
func.func @caller(%x: i32) -> i32 {
  %r = call @callee(%x) : (i32) -> i32
  return %r : i32
}
