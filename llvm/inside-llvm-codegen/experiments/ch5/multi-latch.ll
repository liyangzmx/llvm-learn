define i32 @multi(i32 %n, i1 %choose, i1 %enter) {
entry:
  br i1 %choose, label %left, label %right
left:
  br label %header
right:
  br i1 %enter, label %header, label %exit
header:
  %i = phi i32 [ 0, %left ], [ 0, %right ], [ %i1, %latch1 ], [ %i2, %latch2 ]
  %cond = icmp slt i32 %i, %n
  br i1 %cond, label %body, label %exit
body:
  %parity = and i32 %i, 1
  %odd = icmp ne i32 %parity, 0
  br i1 %odd, label %latch1, label %latch2
latch1:
  %i1 = add i32 %i, 1
  br label %header
latch2:
  %i2 = add i32 %i, 1
  br label %header
exit:
  %result = phi i32 [ 0, %right ], [ %i, %header ]
  ret i32 %result
}
define i32 @main() {
  %a = call i32 @multi(i32 0, i1 true, i1 true)
  %b = call i32 @multi(i32 5, i1 true, i1 true)
  %c = call i32 @multi(i32 10, i1 false, i1 true)
  %d = call i32 @multi(i32 10, i1 false, i1 false)
  %aok = icmp eq i32 %a, 0
  %bok = icmp eq i32 %b, 5
  %cok = icmp eq i32 %c, 10
  %dok = icmp eq i32 %d, 0
  %ab = and i1 %aok, %bok
  %cd = and i1 %cok, %dok
  %ok = and i1 %ab, %cd
  %r = select i1 %ok, i32 0, i32 1
  ret i32 %r
}
