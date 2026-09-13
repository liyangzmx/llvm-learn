define i64 @frame(i64 %v) {
  %slot = alloca i64, align 8
  store volatile i64 %v, ptr %slot, align 8
  %r = load volatile i64, ptr %slot, align 8
  ret i64 %r
}
