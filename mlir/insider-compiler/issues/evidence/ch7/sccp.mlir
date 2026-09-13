func.func @conditional() -> i32 {
  %c = arith.constant true
  %a = arith.constant 42 : i32
  %b = arith.constant 99 : i32
  cf.cond_br %c, ^yes, ^no
^yes:
  cf.br ^join(%a : i32)
^no:
  cf.br ^join(%b : i32)
^join(%r: i32):
  return %r : i32
}
