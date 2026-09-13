; Arithmetic has wrapping semantics unless nsw/nuw is explicitly present.
define i64 @add_reg(i64 %a, i64 %b) {
entry:
  %r = add i64 %a, %b
  ret i64 %r
}
define i64 @add_imm(i64 %a) {
entry:
  %r = add i64 %a, 42
  ret i64 %r
}
define i32 @add32(ptr %p, ptr %q) {
entry:
  %a = load i32, ptr %p, align 4
  %b = load i32, ptr %q, align 4
  %r = add i32 %a, %b
  store i32 %r, ptr %p, align 4
  ret i32 %r
}
define i64 @choose(i1 %cond, ptr %p, ptr %q) {
entry:
  br i1 %cond, label %yes, label %no
yes:
  %a = load volatile i64, ptr %p, align 8
  br label %join
no:
  %b = load volatile i64, ptr %q, align 8
  br label %join
join:
  %r = phi i64 [ %a, %yes ], [ %b, %no ]
  ret i64 %r
}
