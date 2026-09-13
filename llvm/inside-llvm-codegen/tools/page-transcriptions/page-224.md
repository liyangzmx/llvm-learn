```text
if.else4:                                        ; preds = %if.end
    store i8 0, ptr %returnValue, align 1
    br label %if.end5

if.end:                                          ; preds = %if.else, %if.then
    %1 = load i32, ptr %y.addr, align 4
    %rem1 = srem i32 %1, 3
    %cmp2 = icmp eq i32 %rem1, 0
    br i1 %cmp2, label %if.then3, label %if.else4

if.end5:                                         ; preds = %if.else4, %if.then3
    %2 = load i8, ptr %returnValue, align 1
    %tobool = trunc i8 %2 to i1
    ret i1 %tobool
}
```

因为 if.end 基本块代码行数为 5 条，所以要执行优化，必须将参数设置为允许重复最大指令数如设置参数 -tail-dup-size=5，否则看不到效果。使用 Compiler Explorer，可以直接观察尾代码重复优化前后的区别，如图 9-6 所示。

**图 9-6 尾代码重复优化前后的区别**
