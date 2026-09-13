define i32 @closed(i32 %n, i1 %c) {
entry:
  br label %header
header:
  %i = phi i32 [ 0, %entry ], [ %next, %merge ]
  %last = phi i32 [ 7, %entry ], [ %x3, %merge ]
  %cond = icmp slt i32 %i, %n
  br i1 %cond, label %body, label %exit
body:
  br i1 %c, label %left, label %right
left:
  br label %merge
right:
  br label %merge
merge:
  %x3 = phi i32 [ 10, %left ], [ 20, %right ]
  %next = add i32 %i, 1
  br label %header
exit:
  %result = add i32 %last, 4
  ret i32 %result
}
define i32 @main() {
  %a = call i32 @closed(i32 0, i1 true)
  %b = call i32 @closed(i32 1, i1 false)
  %c = call i32 @closed(i32 4, i1 true)
  %aok = icmp eq i32 %a, 11
  %bok = icmp eq i32 %b, 24
  %cok = icmp eq i32 %c, 14
  %ab = and i1 %aok, %bok
  %ok = and i1 %ab, %cok
  %r = select i1 %ok, i32 0, i32 1
  ret i32 %r
}
