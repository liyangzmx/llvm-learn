define signext i16 @add16_signed(i16 signext %a, i16 signext %b) {
entry:
  %r = add i16 %a, %b
  ret i16 %r
}
define void @add128(ptr %dst, ptr %p, ptr %q) {
entry:
  %a = load i128, ptr %p, align 8
  %b = load i128, ptr %q, align 8
  %r = add i128 %a, %b
  store i128 %r, ptr %dst, align 8
  ret void
}
define void @vector_add(ptr %dst, ptr %p, ptr %q) {
entry:
  %a = load <2 x i64>, ptr %p, align 8
  %b = load <2 x i64>, ptr %q, align 8
  %r = add <2 x i64> %a, %b
  store <2 x i64> %r, ptr %dst, align 8
  ret void
}
