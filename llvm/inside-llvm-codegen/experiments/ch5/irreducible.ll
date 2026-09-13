define i32 @irreducible(i1 %a, i1 %b) {
entry:
  br i1 %a, label %left, label %right
left:
  br i1 %b, label %right, label %exit
right:
  br i1 %b, label %left, label %exit
exit:
  ret i32 0
}
