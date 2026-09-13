define void @cse(i32 %x, i32 %y, ptr %p1, ptr %p2, i1 %cond) {
bb.0:
    %a = add i32 %x, %y
    store i32 %a, ptr %p1
    %b = zext i32 %a to i64
    store i64 %b, ptr %p2
    br i1 %cond, label %bb.1, label %bb.2

bb.1:
    %c = add i32 %y, %x
    store i32 %c, ptr %p1
    %d = zext i32 %a to i64
    store i64 %d, ptr %p2
    br label %bb.2

bb.2:
    ret void
}
