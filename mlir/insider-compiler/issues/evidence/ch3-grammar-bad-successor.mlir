func.func @forward(%x: i32) -> i32 {
  "cf.br"(%x)[^bb1 : (%x : i32)] : (i32) -> ()
^bb1(%y: i32):
  return %y : i32
}
