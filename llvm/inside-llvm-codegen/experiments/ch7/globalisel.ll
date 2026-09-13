define i32 @add32(i32 %a, i32 %b) {
entry:
  %r = add nsw i32 %a, %b
  ret i32 %r
}
define i16 @add16(i16 %a, i16 %b) {
entry:
  %r = add i16 %a, %b
  ret i16 %r
}
define i32 @or32(i32 %a, i32 %b) {
entry:
  %r = or i32 %a, %b
  ret i32 %r
}
