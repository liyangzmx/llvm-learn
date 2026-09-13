```text
    store i32 %a, i32* %p1
    %b = zext i32 %a to i64
    store i64 %b, i64* %p2
    br i1 %cond, label %bb.1, label %bb.2

bb.1:
    %c = add i32 %y, %x
    store i32 %c, i32* %p1
    %d = zext i32 %a to i64
    store i64 %d, i64* %p2
    br label %bb.2

bb.2:
    ret void
}
```

这里使用 RISC-V-64 架构进行说明，启动该架构的编译选项为：llc -mtriple=riscv64。在 goldbolt 中可以看到，经过公共子表达式消除优化前后的 MIR 变化如图 9-11 所示。

**图 9-11 公共子表达式消除优化前后 MIR 变化**

在公共子表达式消除优化前的 MIR 中，%1～%5 分别对应函数的 5 个入参。可以看到，%0 与 %11 的表达式中，操作数顺序不同，但由于它们的 MIR 操作为加法指令 ADDW，加法指令的两个操作数交换位置不影响结果（加法交换律），故而 %11:gpr = ADDW %7:gpr, %6:gpr 等价于 %11:gpr = ADDW %6:gpr, %7:gpr，又因为 %6 复制了 %1，%7 复制了 %0，从 %7 和 %6 被赋值一直执行到当前 %11 节点的过程中，%1 和 %2 未发生变化，所以可将 %11 进一步转换为 %11:gpr = ADDW %1:gpr, %2:gpr。该转换结果与 %0 节
