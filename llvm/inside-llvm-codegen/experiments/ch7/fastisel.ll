define i32 @add32(i32 %a, i32 %b) {
entry:
  %r = add i32 %a, %b
  ret i32 %r
}
define i64 @add64(i64 %a, i64 %b) {
entry:
  %r = add i64 %a, %b
  ret i64 %r
}
