target triple = "bpfel"

declare i64 @external(i64)

define i64 @add64(i64 %x, i64 %y) {
entry:
  %sum = add i64 %x, %y
  ret i64 %sum
}

define i64 @call_external(i64 %x) {
entry:
  %result = call i64 @external(i64 %x)
  ret i64 %result
}

define i64 @stack_roundtrip(i64 %x) {
entry:
  %slot = alloca i64, align 8
  store volatile i64 %x, ptr %slot, align 8
  %result = load volatile i64, ptr %slot, align 8
  ret i64 %result
}
