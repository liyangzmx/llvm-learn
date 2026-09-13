define i32 @bad(i1 %c) {
entry:
  br i1 %c, label %left, label %right
left:
  %x = add i32 1, 2
  br label %join
right:
  br label %join
join:
  ret i32 %x
}
