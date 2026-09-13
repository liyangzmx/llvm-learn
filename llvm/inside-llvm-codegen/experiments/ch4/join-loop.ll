define i32 @join_loop(i32 %n, i1 %c) {
entry:
  %x = alloca i32
  store i32 0, ptr %x
  br label %header
header:
  %v = load i32, ptr %x
  %more = icmp slt i32 %v, %n
  br i1 %more, label %body, label %exit
body:
  br i1 %c, label %left, label %right
left:
  %l = add i32 %v, 1
  store i32 %l, ptr %x
  br label %join
right:
  %r = add i32 %v, 2
  store i32 %r, ptr %x
  br label %join
join:
  br label %header
exit:
  ret i32 %v
}
