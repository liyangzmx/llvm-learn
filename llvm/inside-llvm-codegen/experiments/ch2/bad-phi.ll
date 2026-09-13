define i32 @bad(i1 %c) {
entry:
  br i1 %c, label %left, label %right
left:
  br label %join
right:
  br label %join
join:
  %x = phi i32 [ 1, %left ]
  ret i32 %x
}
