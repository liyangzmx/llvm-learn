; Independent loads can move relative to one another, while store/result
; dependencies must be preserved. No noalias premise is needed to move the
; loads past one another; they are not moved across the final store to %p.
define i64 @schedule(ptr %p, ptr %q, ptr %r) {
entry:
  %a = load i64, ptr %p, align 8
  %b = load i64, ptr %q, align 8
  %c = load i64, ptr %r, align 8
  %x = mul i64 %a, 7
  %y = add i64 %b, 11
  %z = xor i64 %x, %y
  %out = add i64 %z, %c
  store i64 %out, ptr %p, align 8
  ret i64 %out
}
