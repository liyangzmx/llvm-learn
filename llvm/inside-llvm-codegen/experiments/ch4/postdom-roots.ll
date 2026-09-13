define void @roots(i1 %a, i1 %b) {
entry:
  br i1 %a, label %dispatch, label %spin
dispatch:
  br i1 %b, label %exit1, label %exit2
exit1:
  ret void
exit2:
  ret void
spin:
  br label %spin
}
