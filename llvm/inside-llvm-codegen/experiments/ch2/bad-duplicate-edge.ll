define i32 @bad(i1 %c) {
entry:
  br i1 %c, label %join, label %join
join:
  %x = phi i32 [ 1, %entry ], [ 2, %entry ]
  ret i32 %x
}
