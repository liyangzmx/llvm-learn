define i32 @sum(i32 %n) {
entry:
  br label %header
header:
  %i = phi i32 [ 0, %entry ], [ %next, %body ]
  %s = phi i32 [ 0, %entry ], [ %sum, %body ]
  %cond = icmp slt i32 %i, %n
  br i1 %cond, label %body, label %exit
body:
  %sum = add i32 %s, %i
  %next = add i32 %i, 1
  br label %header
exit:
  ret i32 %s
}
