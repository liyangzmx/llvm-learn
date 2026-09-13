func.func @forward(%x: i32) -> i32 {
  "cf.br"(%x)[^bb1] : (i32) -> ()
^bb1(%y: i32):
  return %y : i32
}
module {
  %pair:2 = "test.pair"() : () -> (i32, i32)
  "test.consume"(%pair#0, %pair#1) : (i32, i32) -> ()
  "test.zero_width"() : () -> (i0, si0, ui0, i032)
  "test.function_type"() {t = (i32) -> i32} : () -> ()
}
