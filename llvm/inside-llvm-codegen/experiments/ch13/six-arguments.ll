target triple = "bpfel"
define i64 @six(i64 %a, i64 %b, i64 %c, i64 %d, i64 %e, i64 %f) {
  %r = add i64 %a, %f
  ret i64 %r
}
