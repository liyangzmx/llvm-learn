# 第 9 章 基于 SSA 形式的编译优化

> 原文转写，未经技术修订。来源：[原 PDF](../pdf/inside-llvm-codegen.pdf)，PDF 第 217–244 页。书中基线为 LLVM 15（示例 15.0.1）。
> 保留原文观点、命令及排印错误；代码缩进按 PDF 坐标恢复。保留原图裁剪及页码标记，图表、公式或特殊字体可对照原 PDF 读取。

<!-- PDF page 217; printed page 204 -->

Chapter 9 第 9 章

基于 SSA 形式的编译优化

在代码生成过程中也会进行编译优化，分别是在寄存器分配前和寄存器分配后进行。其中寄存器分配前的优化主要是基于 SSA 形式的优化，寄存器分配后的优化是基于非 SSA形式的优化，本章主要介绍寄存器分配前的优化，第 11 章会介绍寄存器分配后的优化。

目前基于 SSA 形式的机器指令优化主要包括尾代码重复、Phi 优化、栈着色等优化，具体如图 9-1 所示。

![图 9-1 基于 SSA 形式的机器指令优化](assets/figures/p217-9-1.png)

**图 9-1 基于 SSA 形式的机器指令优化**

<!-- PDF page 218; printed page 205 -->

每个优化的 Pass 功能如下。

1）前期尾代码重复（early tail duplication）：用于消除跳转指令。由于寄存器分配前后都会进行尾代码重复的优化，因此这里使用“前期”与寄存器分配后的尾代码重复优化进行区分。

2）Phi 优化：移除两类冗余 φ 函数。第一类是死变量（不会被使用的变量）插入的 φ函数，或者由死变量 φ 函数构成的循环 φ 函数；第二类是移除源操作数和目的操作数是同一个寄存器的 φ 函数。

3）栈着色（stack coloring）：优化局部变量的布局，减少栈空间的使用○一。

4）栈槽分配（local stack slot allocation）：将帧索引和栈槽关联在一起（等价于为栈变量分配栈空间）。

5）死指令消除（dead machine instruction elim）：根据基本块中 LiveIn、LiveOut 信息，从后向前依次遍历 MI 指令，将死指令删除。

6）IPL（指令并行层级）优化：依赖特定后端架构的特性进行并行指令优化。例如GPU、AArch64、x86 都可以使用 If-Conversion 将控制依赖变成数据依赖。

7）前期循环不变量外提（early machine LICM）：将循环不变量提出循环体，优化循环执行效率，加“前期”是为了与寄存器分配后的 LICM 进行区别。

8）公共表达式消除（machine CSE）：消除代码中的公共表达式，以减少不必要的计算。

9）代码下沉（machine sinking）：将分支节点的代码下沉到不同的分支中，本质上是将代码执行向后推迟，可能会因为分支不执行而获得执行收益。

10）窥孔优化（peephole optimizer）：对相邻指令进行局部优化。注意，因为窥孔优化可能产生新的死代码，所以会再次执行死指令消除操作。

本章将对上述优化逐一介绍。

## 9.1 前期尾代码重复

本节将对（前期）尾代码重复优化的原理、如何判断优化收益、如何执行优化进行介绍。

### 9.1.1 尾代码重复原理

尾代码重复的基本原理是，如果两个基本块之间存在跳转指令，那么将后继基本块里的代码提升到前驱基本块中可以移除跳转指令，示例如代码清单 9-1 所示。

**代码清单 9-1 两个基本块之间存在跳转指令示例**

```text
bool isEven(int x, int y)
{
```

○一 参考论文的地址为 https://gcc.gnu.org/pub/gcc/summit/2003/Optimal%20Stack%20Slot%20Assignment.pdf。

<!-- PDF page 219; printed page 206 -->

```text
    bool retValue = false;
    if (x % 2 == 0)
        retValue = true;
    else
        retValue = false;
    return retValue;
}
```

该代码片段对应的 CFG 如图 9-2a 所示。在图 9-2a 中，基本块 4 是基本块 2 和基本块3 的汇聚节点，基本块 2 和基本块 3 通常都会通过一个无条件跳转指令（图 9-2a 中的 jmp指令）到达基本块 4。当然也可以进行基本块布局优化，让其中一个基本块和基本块 4 相邻，这样可以节约一个 jmp 指令，这就是第 11 章要介绍的分支折叠。为了追求更高性能，可以将基本块 4 的代码重复放到基本块 2 和基本块 3 的尾部，然后删除基本块 4，从而得到图 9-2b 所示的 CFG。这就是尾代码重复优化的整个过程。

![图 9-2 尾代码重复示意图](assets/figures/p219-9-2.png)

**图 9-2 尾代码重复示意图**

比较图 9-2a 和图 9-2b 可以看出，图 9-2b 将 jmp 指令消除，执行效率更高，但是由于要将基本块 4 的代码重复放到基本块 2 和基本块 3 中，当基本块 4 的代码比较大时会增加代码量。为了控制代码量，LLVM 提供了参数 tail-dup-size 来控制最大重复的指令数。

目前 LLVM 尾代码优化主要在后端实现，包括寄存器分配前优化和寄存器分配后优化。在寄存器分配前进行的优化需要考虑优化对寄存器分配的影响。直观上看，将两个基本块的代码合并到一个基本块可能会增大变量的活跃区间，从而导致更多的寄存器冲突（参见第10 章）。所以尾代码重复优化会对重复代码进行更多的限制，例如包含 call、ret 指令的代码片段（这些指令对寄存器分配影响更大）不允许重复。

另外，因为尾代码重复会影响控制流，对于一些场景来说和第 11 章介绍的分支折叠优化效果相同，所以在进行尾代码优化时对基本块的布局有一定的要求（基本块之间一定存在跳转指令到达的情况）。典型的尾代码重复优化场景有如下两类。

1. 冗余 jmp 指令优化

基本块 CurBB 和前驱基本块之间存在 jmp 指令（见图 9-3a），并且这两个基本块不相邻

<!-- PDF page 220; printed page 207 -->

（11.2.1 节介绍的分支折叠也无法优化这种情况，必须调整基本块的布局后才可能通过分支折叠消除相邻基本块之间的 jmp 指令），可以将 CurBB 代码重复放到前驱基本块中，得到的结果如图 9-3b 所示。

![图 9-3 尾代码重复场景：冗余 jmp 指令优化](assets/figures/p220-9-3.png)

**图 9-3 尾代码重复场景：冗余 jmp 指令优化**

2. 汇聚基本块优化

如果基本块作为汇聚节点，且基本块和后继基本块不相邻，则当基本块重复有收益时（例如不超过允许的最大重复指令数）会进行尾代码重复。例如在图 9-4a 中，CurBB 和两个后继基本块都不相邻，可以将 CurBB 重复放到前驱基本块中，得到的结果如图 9-4b 所示；或者在图 9-4c 中，CurBB 和唯一的后继基本块不相邻，可以将 CurBB 重复放到前驱基本块中，得到的结果如图 9-4d 所示。

注 尾代码重复会增加代码大小，但是可能会带来一定执行效率的提升，并且为执行其

意

他的优化提供更多可能（例如复制传播优化）。

SSA 形式的尾代码重复实现比较复杂，主要原因是优化后还要保持 SSA 形式；非 SSA形式的尾代码优化相对简单（参见 11.2.2 节），两者原理相同（主要区别是 MIR 性质不同，优化时限制不同）。

尾代码重复优化一般先判断是否有收益，只有在有收益的情况下才会进行优化。

### 9.1.2 尾代码收益判断

是否可以对基本块进行尾代码重复优化，可以从以下方面来考虑。

1）只有特定的基本块结构才能进行尾代码重复优化，在一些场景下不能进行优化，例如单基本块循环不能进行优化（如果优化，则会导致无限循环重复）。

2）确定最大重复的指令数，可以通过参数设置 TailDupSize（默认值为 2）实现。当要求代码量最小化时，最大重复指令数为 1。如果优化发生在寄存器分配之前，且基本块最后

<!-- PDF page 221; printed page 208 -->

一条指令为间接跳转指令，则最大允许重复的指令数为 TailDupIndirectBranchSize（默认值为 20）。

![图 9-4 尾代码重复：汇聚基本块优化](assets/figures/p221-9-4.png)

**图 9-4 尾代码重复：汇聚基本块优化**

3）如果有指令明确不可以重复，则放弃执行尾代码重复优化。在 TD 文件中设置指令属性 isNotDuplicable = true，表示指令不可重复（例如 BPF 后端中 ret 指令不可重复）。

4）如果指令是聚合指令，则放弃执行尾代码重复优化。在 TD 文件中设置指令属性isConvergent = true，表示指令不可重复。（聚合指令通常和控制流相关，重复代码后会导致控制流变化，该属性通常用于 GPGPU 后端。）

5）如果优化发生在寄存器分配之前，且基本块中包含 ret、call 等指令，则放弃执行尾代码重复优化。ret 指令重复后可能会导致更多的代码“膨胀”（例如在 PEI 中，在 ret 指令之前通常会插入额外的 CSR（Callee Saved Register，被调用者保存寄存器）指令），而 call

<!-- PDF page 222; printed page 209 -->

指令重复可能会导致更多的寄存器溢出。

6）如果基本块中指令有汇编指令，且包含分支指令，则放弃优化。因为在一些场景中重复会导致逻辑错误（例如无法为 φ 函数准确寻找插入位置）。

7）如果基本块中所有指令数超过最大重复的指令数，则放弃优化。

8）如果所有的前驱基本块都包含多个后继基本块，则放弃优化。代码重复后，如果前驱基本块“走”另外的路径，则会多执行指令，所以不能重复代码。

9）如果所有的前驱基本块的最后一条指令不是无条件跳转指令，则放弃优化。

### 9.1.3 执行尾代码重复优化

尾代码重复优化实现思路如下。

1）对基本块的每一个前驱基本块都尝试进行尾代码合并。当前驱基本块只有一个后继基本块且最后一条指令为无条件跳转指令时开始执行代码重复优化，这分为以下两步。

① 删除前驱基本块最后一条无条件跳转指令。

② 将基本块中的每条指令重复放到前驱基本块中。如果是 φ 函数，指令重复操作本质上是在进行 φ 函数析构（执行方式为在前驱基本块最后位置增加 COPY 指令，并移除 φ 函数中对应前驱基本块的操作数）；如果是一般指令，则进行代码重复时要保证 SSA 属性；最后更新 CFG 图，即移除原来的后继基本块，并增加新的后继基本块。

2）如果基本块被重复放到了其全部前驱基本块中，则尝试将基本块也放到其相邻基本块中，之后就可以将基本块移除。

3）对循环场景做特殊处理可能需要重构 φ 函数，如图 9-5 所示。在图 9-5a 的基础上，对基本块 b2 进行尾代码重复优化，分别在基本块 b1 和 b3 后重复 b2 的代码，可以得到图 9-5b 所示的结果。对比图 9-5a 和图 9-5b 可以发现除了放置重复代码外，还需要考虑基本块 b3 中 φ 函数的变化，图 9-5a 中 φ 函数的源寄存器主要来自 b1 和 b3，图 9-5b 中 φ 函数的源寄存器也很可能来自 b2 和 b3，所以在 b3 中要重构 φ 函数。

![图 9-5 尾代码重复：循环场景的特殊处理](assets/figures/p222-9-5.png)

**图 9-5 尾代码重复：循环场景的特殊处理**

下面构造一个简单的尾代码重复优化示例，如代码清单 9-2 所示。

<!-- PDF page 223; printed page 210 -->

**代码清单 9-2 尾代码重复优化示例**

```text
bool isEven(int x, int y)
{
    bool returnValue = false;
    if (x % 2 == 0)
        returnValue = true;
    else
        returnValue = false;

    if (y % 3 == 0)
        returnValue = true;
    else
        returnValue = false;

    return returnValue;
}
```

代码可以通过 Clang 编译生成未经过优化的 LLVM IR。但是为了触发尾代码重复优化，需要对 LLVM IR 的顺序进行调整（如果不调整则不会执行尾代码重复优化）：让第一个 if 语句的两个分支的汇聚节点（if.end）向下移动，从而和第二个 if 语句的两个基本块（if.then3和 if.else4）不相邻。经过尾代码重复优化后的 LLVM IR 如代码清单 9-3 所示。

**代码清单 9-3 尾代码重复优化后的 LLVM IR**

```text
define dso_local noundef zeroext i1 @isEven(i32 noundef %x, i32 noundef %y) {
entry:
    %x.addr = alloca i32, align 4
    %y.addr = alloca i32, align 4
    %returnValue = alloca i8, align 1
    store i32 %x, ptr %x.addr, align 4
    store i32 %y, ptr %y.addr, align 4
    store i8 0, ptr %returnValue, align 1
    %0 = load i32, ptr %x.addr, align 4
    %rem = srem i32 %0, 2
    %cmp = icmp eq i32 %rem, 0
    br i1 %cmp, label %if.then, label %if.else

if.then:                                          ; preds = %entry
    store i8 1, ptr %returnValue, align 1
    br label %if.end

if.else:                                          ; preds = %entry
    store i8 0, ptr %returnValue, align 1
    br label %if.end

if.then3:                                         ; preds = %if.end
    store i8 1, ptr %returnValue, align 1
    br label %if.end5
```

<!-- PDF page 224; printed page 211 -->

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

<!-- PDF page 225; printed page 212 -->

## 9.2 Phi 优化

Phi 优化主要针对两种场景进行。

1. φ 函数的多个源都使用的是同一个寄存器

φ 函数的多个源使用的是同一个寄存器（即在 SSA 形式中并不需要真正的 φ 函数），主要有以下三种形式。

1）形式 1：φ 函数的源寄存器完全相同。例如，φ 函数的两个源寄存器相同，都是 R1。

R2 = φ(R1, R1)

2）形式 2 ：φ 函数有多个源寄存器，其中一个或者多个源寄存器使用了目的寄存器，且除目的寄存器外，其他的源寄存器都完全相同。例如，下面 φ 函数中的两个源寄存器分别是 R1 和 R2，其中 R2 是目的寄存器。

R2 = φ(R1, R2)

3）形式 3 ：多个 φ 函数相互为源，构成循环，并且除了循环的源寄存器外，所有 φ 函数使用的源寄存器都相同。例如，多个 φ 函数中 R2 和 R0 相互使用，并且都还使用了相同的源寄存器，即 R2 中的两个源寄存器分别是 R1 和 R0，R0 中的两个源寄存器分别是 R1 和R2。

R2 = φ(R0, R1)

…

R0 = φ(R1, R2)

上述三种形式都可以删除 R2，并且将使用 R2 的地方直接替换为 R1。

当然在实际代码优化中还可能会遇到一些变形，如一些 φ 函数中的源寄存器使用COPY 指令进行中转：

R0 = COPY R1

R2 = φ(R0, R1)

在该例中，R2 可以使用 R1 进行替换，并删除 R2。但 R0 = COPY R1 的指令并不会被删除，而是在后续的简单寄存器合并中进行处理。

2. φ 函数定义的寄存器只在其他 φ 函数中使用

第二个优化场景是 φ 函数定义的寄存器只在其他 φ 函数中使用，并且这些 φ 函数相互使用彼此定义的寄存器，最后形成环，符合这样条件的 φ 函数是死代码，如下所示。

R2 = φ(R0, R1)

…

R0 = φ(R1, R2)

<!-- PDF page 226; printed page 213 -->

…

R1 = φ(R0, R2)

R0，R1，R2 使用 φ 函数定义，并且这三个 φ 函数形成了循环，说明是无效的 φ 函数定义，可以将这三个 φ 函数都删除。

## 9.3 栈着色

LLVM 3.2 中正式引入栈着色实现，栈着色主要是优化栈变量的分配，减少栈空间的使用。下面通过例子来看栈着色的作用，例子对应的 C 代码如代码清单 9-4 所示。

**代码清单 9-4 栈着色示例的 C 代码**

```text
void bar(char *, int);
void foo(int var) {
A: {
        char z[4096];
        bar(z, 0);
    }

    char *p;
    char x[4096];
    char y[4096];
    if (var) {
        p = x;
    } else {
        bar(y, 1);
        p = y + 1024;
    }
B:
    bar(p, 2);
}
```

在上述代码中，代码块 A 定义了局部变量 z，它的生命周期和变量 x、y、p 的生命周期不重叠。z 在代码块 A 中执行完成后，占用的栈空间就可以被 x、y、p 使用。另外，x 和y 分别位于 if 分支的真、假条件中，而且在 if 执行完成后都不会再使用 x 和 y，所以理论上x 和 y 也可以共享相同的空间。上述代码经过优化后如代码清单 9-5 所示。

**代码清单 9-5 代码清单 9-4 最为理想的优化结果**

```text
void foo(int var) {
    char x[4096];
    char *p;
    bar(x, 0);
    if (var) {
        p = x;
```

<!-- PDF page 227; printed page 214 -->

```text
    } else {
        bar(x, 1);
        p = x + 1024;
    }
    bar(p, 2);
}
```

遗憾的是，目前 GCC 和 LLVM 都不能生成上述最优代码。在 O2 优化级别下，LLVM栈布局、GCC 栈布局、理想栈布局如图 9-7 所示。

![图 9-7 LLVM 栈布局、GCC 栈布局、理想栈布局](assets/figures/p227-9-7.png)

**图 9-7 LLVM 栈布局、GCC 栈布局、理想栈布局**

注 指针 p 会放在寄存器中，并不会放在栈分配空间。了解了 LLVM 中的栈着色实

意

现后，再来分析为何 LLVM 栈布局效果最差。GCC 中的栈着色是通过冲突图

（interference graph）判断栈变量是否冲突，不冲突的栈变量可共享栈槽。而 LLVM

是通过变量的作用域判断栈变量是否冲突，不冲突的栈变量可共享栈槽，上面示例

中的 x 和 y 在代码块 B 处进行了聚合，可以发现 x 和 y 生命周期完全冲突，所以在

LLVM 中 x 和 y 会使用不同的栈槽。

LLVM 中的栈着色功能依赖于 LLVM 伪指令 LIFETIME_START、LIFETIME_END。通常伪指令在前端处理器生成 LLVM IR 时产生，例如 Clang 在处理 C/C++ 源码生成 LLVM IR 时会增加栈变量的生命周期伪指令 LIFETIME_START、LIFETIME_END，用于标记栈变量的作用范围。例如基本块 A 定义栈变量 z，并且变量 z 仅作用于基本块 A 中。所以，Clang 可以插入伪指令用于标记 z 的作用范围，使用 Clang 15 生成的 LLVM IR，如代码清单 9-6 所示。

**代码清单 9-6 与代码清单 9-5 对应的 LLVM IR**

```text
define dso_local void @foo(i32 noundef %var) local_unnamed_addr {
entry:
    %z = alloca [4096 x i8], align 16
    %x = alloca [4096 x i8], align 16
    %y = alloca [4096 x i8], align 16
    call void @llvm.lifetime.start.p0(i64 4096, ptr nonnull %z)
    call void @bar(ptr noundef nonnull %z, i32 noundef 0)
    call void @llvm.lifetime.end.p0(i64 4096, ptr nonnull %z)
    %tobool.not = icmp eq i32 %var, 0
    br i1 %tobool.not, label %if.else, label %B
```

<!-- PDF page 228; printed page 215 -->

```text
if.else:                                          ; preds = %entry
    call void @bar(ptr noundef nonnull %y, i32 noundef 1)
    %add.ptr = getelementptr inbounds i8, ptr %y, i64 1024
    br label %B

B:                                                ; preds = %entry, %if.else
    %p.0 = phi ptr [ %add.ptr, %if.else ], [ %x, %entry ]
    call void @bar(ptr noundef nonnull %p.0, i32 noundef 2)
    ret void
}
```

其中 llvm.lifetime.start.p0、llvm.lifetime.end.p0 在指令选择时会变成伪指令 LIFETIME_ START、LIFETIME_END。

栈着色的基本思路如下。

1）识别 MIR 中所有的伪指令 LIFETIME_START、LIFETIME_END。由于栈着色会合并栈变量，因此当伪指令个数较少时就没必要执行栈着色优化，例如伪指令个数少于 2 个。

2）识别活跃变量，计算变量的活跃区间（死变量的活跃区间为空）。

3）根据变量的活跃区间判断是否可以合并。如果变量的活跃区间不冲突（即不重叠），则说明变量可以共享同一个栈槽，而共享同一个栈槽的变量可以合并它们的活跃区间。实际上要做到合并最优的变量活跃区间是非常困难的，该优化是一个 NP 难题，目前采用的是Greedy 算法。合并时会先对栈变量活跃区间进行排序（按照栈变量的存储空间从大到小排序），即最终目的是优先合并存储空间大的栈变量，并记录合并的栈变量信息。

根据合并栈变量信息对 MIR 进行修改，这会涉及如下几种情况。

① 栈变量都是通过 Alloca 指令分配的，若要进行栈变量合并，必须将多个 Alloca 指令合并为一个。合并时需要确保新的 Alloca 指令在所有使用它的指令之前定义。在使用前，多个 Alloca 指令类型应该一致（不一致则需要插入 cast 指令进行类型转换）。注意，旧的Alloca 指令需要替换为合并后的新指令。

② 在所有使用栈变量的 Alloca 指令合并前，栈槽的指令都要替换为合并后的栈槽。

③ 更新内存指令中别名信息。如果栈变量合并后仍然可以得到合并后变量的别名信息，则更新合并后栈变量的别名信息；如果无法计算得到别名信息，则将合并后的栈变量的别名信息清空。

4）删除 MIR 中所有的 LIFETIME_START、LIFETIME_END 伪指令。

在上面的例子中，只有栈变量 z 通过伪指令（LIFETIME_START、LIFETIME_END）定义了其生命周期，而栈变量 x 和 y 没有使用对应的伪指令来定义它们的生命周期，导致LLVM 编译器无法正确优化栈变量的分配。这显然是 Clang 的问题，即没有为所有的栈变量准确地生成伪指令。为了验证栈着色算法的效果，可以在 LLVM IR 中为栈变量 x 和 y 显式增加伪指令，修改后的 IR 如代码清单 9-7 所示。

<!-- PDF page 229; printed page 216 -->

**代码清单 9-7 为栈变量 x 和 y 显式增加伪指令**

```text
0 define dso_local void @foo(i32 noundef %var) local_unnamed_addr {
1 entry:
2   %z = alloca [4096 x i8], align 16
3   %x = alloca [4096 x i8], align 16
4   %y = alloca [4096 x i8], align 16
5   call void @llvm.lifetime.start.p0(i64 4096, ptr nonnull %z)
6   call void @bar(ptr noundef nonnull %z, i32 noundef 0)
7   call void @llvm.lifetime.end.p0(i64 4096, ptr nonnull %z)
8   %tobool.not = icmp eq i32 %var, 0
9   call void @llvm.lifetime.start.p0(i64 4096, ptr nonnull %x)
10   br i1 %tobool.not, label %if.else, label %B

11 if.else:                                          ; preds = %entry
12   call void @llvm.lifetime.start.p0(i64 4096, ptr nonnull %y)
13   call void @bar(ptr noundef nonnull %y, i32 noundef 1)
14   %add.ptr = getelementptr inbounds i8, ptr %y, i64 1024
15   br label %B

16 B:                                                ; preds = %entry, %if.else
17   %p.0 = phi ptr [ %add.ptr, %if.else ], [ %x, %entry ]
18   call void @bar(ptr noundef nonnull %p.0, i32 noundef 2)
19   call void @llvm.lifetime.end.p0(i64 4096, ptr nonnull %x)
20   call void @llvm.lifetime.end.p0(i64 4096, ptr nonnull %y)
21   ret void
22 }
```

根据 IR 可以计算栈变量 z、x、y 的活跃区间为 z[5, 7]、x[9, 19]、y[12, 20]。

z 和 x、y 活跃区间不冲突，而 x 和 y 活跃区间冲突，所以可以将 z、x 安排在一个栈槽中，将 y 安排在另一个栈槽中。此时使用 llc 编译后可以发现栈空间布局能够被优化，和预期效果一样。

在栈着色中要特别注意活跃变量分析。在 LLVM 3.9 之前，活跃变量分析使用的是后向数据流分析（参见 3.3.1 节），但是从 LLVM 3.9 开始使用的是前向数据流分析。之所以有这样的变化主要是因为在一些场景下基于后向数据流分析会得出不正确的结果，例如一些编译优化可能会导致栈变量在分配空间之前被使用。代码清单 9-8 演示了一个简单的例子。

**代码清单 9-8 活跃变量分析示例**

```text
int bar() {
    char b1[1024], b2[1024];
    if (...) {
        <uses of b2>
        return y;
    } else {
        <uses of b1>
        while (...) {
            char b3[1024];
```

<!-- PDF page 230; printed page 217 -->

```text
            <uses of b3>
        }
    }
}
```

在代码清单 9-8 中，while 循环使用了栈变量 b3，而在使用过程中，可能发现 b3 是一个循环不变量，通过 LICM 可以将循环不变量外提（上提至 b1 使用处），此时就存在一个问题：b3 的定义在循环内（即真正的栈变量分配在循环体内），而栈变量的使用在定义之前，如果没有进行栈变量合并，不会出现问题。因为此时栈变量的空间已经被预留，只是在循环内被声明。但是当栈变量合并后，就会出现问题，例如循环体内栈变量被合并，即循环体预留的栈空间不存在了，此时上移至循环体外的代码就会发生使用非法内存空间的情况。

所以必须重新准确定义活跃变量以及活跃变量的活跃区间。LLVM 3.9 使用前向数据流分析，通过 LIFETIME_START 确定栈变量的活跃区间起始位置，通过 LIFETIME_END 确定栈变量活跃区间的结束位置，从上向下迭代计算活跃变量。同时，在计算活跃区间时将在定义之前就被使用的变量调整至定义位置。

## 9.4 栈槽分配

栈槽分配 Pass 主要确保指令在栈空间的访问是合法的。如果不合法则调整指令，同时为栈变量分配栈槽。处理逻辑是，首先为指令中的栈槽分配栈空间（即将指令中基于栈槽的访问变换为基于栈空间的访问），然后推断指令访问栈空间是否合法，将不合法的指令访问引入新的虚拟寄存器，将原来基于偏移值访问栈空间的方式修改为基于寄存器的访问方式（还需要增加一条指令，将偏移值赋给新的寄存器）。指令中栈空间访问的合法性取决于具体的后端指令设计，目前只有 AArch64、AMDGPU、PowerPC、ARM 等少数后端才有这样的指令约束。在栈变量分配时，需要考虑栈空间增长的方向、变量对齐等信息，以计算栈变量的位置。另外，LLVM 也支持栈保护机制，栈槽分配优化会为栈保护的变量进行重新布局（大对象在前、小对象在后，以防止溢出）。

栈槽分配是在 LLVM 2.8 中首次引入，最初该功能的实现放在 PEI（即前言 / 后序插入，参见 11.1 节）中。从 PEI 分离出该功能主要是为了解决在寄存器分配后一些栈变量访问指令可能仍然不合法的问题。例如 AArch64 对 load/store 指令有多种寻址模式：偏移寻址（offset addressing）、前变址寻址（pre-indexed addressing）、后变址寻址（post-indexed addressing）。而这些寻址模式又支持不同类型的数据访问，一些指令使用立即数作为偏移值，而偏移的范围在指令中有对应的约束。例如在 load/store 指令对中，32 位数据加载指令支持的偏移范围为 [–64，63]○一，如果相对于基寄存器（base-register，通常为 FP）的栈变量偏

○一 关于 load/store 指令格式可以参考 ARM 官方文档：https://developer.arm.com/documentation/ddi0596/2020-

12/Index-by-Encoding/Loads-and-Stores。

<!-- PDF page 231; printed page 218 -->

移超过该范围，需要对指令进行改写（通常是引入一个新的寄存器，将原来指令变换成基于寄存器的访存指令）。这一操作在 PEI 阶段的执行性能较差○一，而将该工作调整至寄存器分配前，只需引入一个新的虚拟寄存器（由寄存器分配阶段统一完成虚拟寄存器到物理寄存器的映射）然后改写指令。

注 在 SSA 阶段提取一个单独的 Pass 有不少好处。在 PEI 阶段提取需要用复杂度较高

意

的算法寻址一个真正的物理寄存器。在 SSA 阶段引入虚拟寄存器，在寄存器分配阶

段统一完成寄存器分配，以获得更好的性能。此外，还可以让多个指令栈变量访存

重用同一个虚拟寄存器，只要虚拟寄存器满足后端指令范围约束。另外，栈槽分配

Pass 和 PEI 都可以确认局部变量的栈位置，但是 PEI 计算位置会比栈槽分配 Pass 更

为准确，因为在栈槽分配优化阶段无法确定 CSR 具体信息（只能假设所有的 CSR

都会保存，例如 AArch64 会保存 20 个寄存器，共计 320 字节），无法确定寄存器分

配过程中溢出寄存器的空间大小（只能给一个估计值，例如在 AArch64 中的估计值

为 128 字节），而在 PEI 阶段所有信息都已经确定，可以更为准确地计算所有栈变量

的分配位置。因为栈槽分配可能会带来一定的浪费（因为 CSR、溢出寄存器等不确

定的信息），所以在分配的过程中，如果发现不需要引入新的虚拟寄存器，则会将栈

槽分配重新推迟到 PEI 阶段。（通常将栈槽分配过程中的栈分配称为预分配，在 PEI

中需要判断是否启用栈槽分配，如果启用则直接使用栈空间预分配的结果，否则会

在 PEI 阶段再次进行分配。）

## 9.5 死指令消除

死指令消除（也称为死代码消除）是编译优化中最基础的优化。

死指令消除的思想可以简单概括为：如果变量 V 没有被使用（即除了定义变量 V 的指令外，没有任何指令使用变量 V），并且定义 V 的指令没有任何负面影响（指的是指令有volatile 属性，或者 call 等特殊指令），则可以删除定义变量 V 的指令。

一个简单的实现方法：为每一个变量设置一个计数器，例如 counter[V] = 0，如果变量V 没有使用，则计数器保持不变，可以删除定义变量 V 的指令。同时还可以对 COPY 指令做进一步处理，如果有类似 V = COPY E 的指令，当 E 被删除后，V 的计数也相应地减 1。

LLVM 的实现更为简单，其中有几个要点。

1）从后向前处理基本块的指令，能够更为准确、快速地完成死指令的删除（参见3.3.1 节）。

○一 PEI 在寄存器分配后才执行，因为此时寄存器已经分配完成，所以需要较为复杂的算法才能找到一个合

适的寄存器完成指令变换，算法的复杂度为 O(n2)。

<!-- PDF page 232; printed page 219 -->

2）检测指令中使用的变量（指虚拟寄存器），指令中直接使用或者跨基本块的活跃变量（或者一些保留的物理寄存器）都需要识别。

3）对于没有被使用的变量，删除定义该变量的指令。

4）因为没有处理 COPY 这样的指令的功能，所以不会进行递归处理。

## 9.6 IPL 优化之 If-Conversion

IPL 优化和后端密切相关，本节介绍 IPL 优化中使用较为广泛的 If-Conversion 算法。If-Conversion 算法用于消除跳转指令，并将控制依赖转换成数据依赖。本节主要介绍LLVM 后端基于 MIR 的算法实现—EarlyIfConverter，它在寄存器分配之前执行。

下面先看一段简单的 if-else 代码，如代码清单 9-9 所示。假设代码生成后的指令分别为 S1、S2、S3、S4。

**代码清单 9-9 if-else 代码**

```text
if (A) {
    B = 1;    // 指令S1
    C = 2;    // 指令S2
} else {
    B = 3;    // 指令S3
    C = 4;    // 指令S4
}
```

如果不进行 IPL 优化，当 A 为 true 时会执行 S1、S2，当 A 为 false 时会执行 S3、S4。生成的汇编代码如代码清单 9-10 所示，可以看到 goto 指令会根据 A 的值进行跳转。

**代码清单 9-10 使用 goto 进行跳转**

```text
goto    A!, Label; // 如果A=false，则跳转
mov    B, 1;     // S1
mov    C, 2;     // S2
Label1:
mov    B, 3;     // S3
mov    C, 4;     // S4
```

我们可以通过 If-Conversion 算法消除汇编指令中的 goto 指令（当然，执行该优化要求后端支持 select 指令）。假设用 p0 表示 A = true 时会执行 S1、S2，用 p1 表示 A = false 时会执行 S3、S4，最后得到的伪代码如代码清单 9-11 所示。

**代码清单 9-11 goto 被消除的伪代码效果**

```text
(p0)  mov    B, 1; // S1
(p0)  mov    C, 2; // S2
(p1)  mov    B, 3; // S3
(p1)  mov    C, 4; // S4
```

<!-- PDF page 233; printed page 220 -->

LLVM 中的 If-Conversion 算法的实现过程大致如下。

1）后序遍历当前函数的支配树基本块节点。

2）检查当前基本块是否可以进行 If- Conversion 优化，如果不符合优化约束条件，则跳过。LLVM 检查的约束条件非常严格，它只支持非常特定的场景下的优化，此处列举了比较重要的约束条件。

① 控制流形态：只有满足特定控制流形态的代码才能执行优化，当前只支持对 图 9-8 能够执行 If-Conversion 的两种控制流形态如图 9-8 所示的两种控制流形态做优化。

② Head 基本块中的条件跳转语句：跳转语句中的跳转条件是可明确分析的，要求相应的目标硬件由明确的状态寄存器来实现指令的跳转，比如 x86 后端的 EFLAGS 寄存器。

③ 硬件支持 select 指令：Tail 中的 φ 函数需要被重写为 select 指令，以便将控制流转换成顺序指令。

④ TBB 和 FBB 不能有活跃入参（Liveins）的物理寄存器：TBB、FBB 和 Head 基本块之间的指令依赖只能是虚拟寄存器间的数据依赖关系。

⑤ TBB 和 FBB 不能有访存指令：TBB 和 FBB 指令会被移入 Head 基本块中，访存指令的移动可能会影响之后的访存一致性。

下面以代码清单 9-12 中所示的源码为例，来看看 LLVM 中 If-Conversion 的优化过程。

**代码清单 9-12 If-Conversion 的优化过程**

```text
int MUL(int x, int y, bool flag) {
    int aaa = y * x;
    int z = 0;
    int q = 0;
    if (flag) {
        z = y * x;
        q = x * aaa;
    } else {
        z = y + x;
        q = x + aaa;
    }
    return z * q;
}
```

当编译器执行到 If-Conversion 的 Pass 前时，代码清单 9-12 对应的 MIR 如代码清单 9-13所示。

**代码清单 9-13 与代码清单 9-12 对应的 MIR（If-Conversion 优化前）**

```text
Function Live Ins: $edi in %6, %esi in %7, $edx in %8
bb.0.entry:
```

<!-- PDF page 234; printed page 221 -->

```text
successors: %bb.1, %bb.2;
    Liveins: $edi, $esi, $edx
    %8:gr32 = COPY $edx
    %7:gr32 = COPY $esi
    %6:gr32 = COPY %edi
    %0:gr32 = nsw IMUL32rr %7:gr32, %6:gr32, implicit-def dead $eflags
    TEST32rr %8:gr32, %8:gr32, implicit-def $eflags
    JCC_1 %bb.2, 4, implicit-def $eflags
    JMP_1 %bb.1

bb.1.if.then:
; Predecessors: %bb.0
 Successors: %bb.3
    %1:gr32 = nsw IMUL32rr %0:gr32, %6:gr32, implicit-def dead $eflags
    JMP_1 %bb.3

%bb.2.if.else:
; Predecessors: %bb.0
 Successors: %bb.3
    %2:gr32 = nsw ADD32rr %7:gr32, %6:gr32, implicit-def dead $eflags
    %3:gr32 = nsw ADD32rr %0:gr32, %6:gr32, implicit-def dead $eflags

%bb.3.if.end:
; Predecessors: %bb.2, %bb.1
    %4:gr32 = PHI %2:gr32, %bb.2, %0:gr32, %bb.1
        %5:gr32 = PHI %3:gr32, %bb.2, %1:gr32, %bb.1
    %9:gr32 = nsw IMUL32rr %4:gr32, %5:gr32, implicit-def dead $eflags
    $eax = COPY %9:gr32
    RET 0, $eax
```

此时的控制流和支配树分别如图 9-9a 和图 9-9b 所示。

![图 9-9 代码清单 9-12 对应的控制流和支配树](assets/figures/p234-9-9.png)

**图 9-9 代码清单 9-12 对应的控制流和支配树**

If-Conversion 执行步骤如下。

1）按照支配树进行后序遍历，依次判断出节点 %bb.1、%bb.2、%bb.3 都不符合 If- Conversion 的优化形态。

2）继续遍历，直至 Head = %bb.0，TBB = %bb.1，FBB = %bb.2，Tail = %bb.3。

<!-- PDF page 235; printed page 222 -->

3）从后向前遍历基本块 Head 指令，在 Head 中找到指令插入位置，以便能将基本块TBB 和 FBB 的指令移到 Head 中，插入位置为指令 TEST32rr %8:gr32, %8:gr32 之前。

4）将 TBB 和 FBB 中除 Terminate 以外的指令移入 Head 中。此时，函数的 MIR 如代码清单 9-14 所示，移动的指令使用蓝色标出。

**代码清单 9-14 将 TBB 和 FBB 中除 Terminate 以外的指令移入 Head 中**

```text
Function Live Ins: $edi in %6, %esi in %7, $edx in %8
bb.0.entry:
successors: %bb.1, %bb.2;
    Liveins: $edi, $esi, $edx
    %8:gr32 = COPY $edx
    %7:gr32 = COPY $esi
    %6:gr32 = COPY %edi
    %0:gr32 = nsw IMUL32rr %7:gr32, %6:gr32, implicit-def dead $eflags
    %2:gr32 = nsw ADD32rr %7:gr32, %6:gr32, implicit-def dead $eflags
    %3:gr32 = nsw ADD32rr %0:gr32, %6:gr32, implicit-def dead $eflags
    %1:gr32 = nsw IMUL32rr %0:gr32, %6:gr32, implicit-def dead $eflags
    TEST32rr %8:gr32, %8:gr32, implicit-def $eflags
    JCC_1 %bb.2, 4, implicit-def $eflags
    JMP_1 %bb.1

bb.1.if.then:
; Predecessors: %bb.0
    Successors: %bb.3
    JMP_1 %bb.3

%bb.2.if.else:
; Predecessors: %bb.0
    Successors: %bb.3

%bb.3.if.end:
; Predecessors: %bb.2, %bb.1
    %4:gr32 = PHI %2:gr32, %bb.2, %0:gr32, %bb.1
        %5:gr32 = PHI %3:gr32, %bb.2, %1:gr32, %bb.1
    %9:gr32 = nsw IMUL32rr %4:gr32, %5:gr32, implicit-def dead $eflags
    $eax = COPY %9:gr32
    RET 0, $eax
```

将基本块 Tail 中的 φ 函数用搜索（select）指令（本例中是 CMOV32rr）进行重写替换，将相应的搜索指令插入 TEST32rr %8:gr32, %8:gr32 之后，并删除原先的 φ 函数，如代码清单 9-15 所示。

**代码清单 9-15 将 select 指令插入 Test32rr 后**

```text
Function Live Ins: $edi in %6, %esi in %7, $edx in %8
bb.0.entry:
successors: %bb.1, %bb.2;
    Liveins: $edi, $esi, $edx
```

<!-- PDF page 236; printed page 223 -->

```text
    %8:gr32 = COPY $edx
    %7:gr32 = COPY $esi
    %6:gr32 = COPY %edi
    %0:gr32 = nsw IMUL32rr %7:gr32, %6:gr32, implicit-def dead $eflags
    %2:gr32 = nsw ADD32rr %7:gr32, %6:gr32, implicit-def dead $eflags
    %3:gr32 = nsw ADD32rr %0:gr32, %6:gr32, implicit-def dead $eflags
    %1:gr32 = nsw IMUL32rr %0:gr32, %6:gr32, implicit-def dead $eflags
    TEST32rr %8:gr32, %8:gr32, implicit-def $eflags
    %4:gr32 = CMOV32rr %0:gr32, %2:gr32, 4, implicit $eflags
    %5:gr32 = CMOV32rr %1:gr32, %3:gr32, 4, implicit $eflags
    JCC_1 %bb.2, 4, implicit-def $eflags
    JMP_1 %bb.1

bb.1.if.then:
; Predecessors: %bb.0
Successors: %bb.3
    JMP_1 %bb.3

%bb.2.if.else:
; Predecessors: %bb.0
 Successors: %bb.3

%bb.3.if.end:
; Predecessors: %bb.2, %bb.1
    %9:gr32 = nsw IMUL32rr %4:gr32, %5:gr32, implicit-def dead $eflags
    $eax = COPY %9:gr32
    RET 0, $eax
```

删除基本块 TBB、FBB 以及基本块 Head 中的跳转指令，并将 Tail 和 Head 合并成一个基本块，最终经 If-Conversion 优化后的 MIR 如代码清单 9-16 所示。

**代码清单 9-16 与代码清单 9-12 对应的 MIR（If-Conversion 优化后）**

```text
Function Live Ins: $edi in %6, %esi in %7, $edx in %8
bb.0.entry:
successors: %bb.1, %bb.2;
    Liveins: $edi, $esi, $edx
    %8:gr32 = COPY $edx
    %7:gr32 = COPY $esi
    %6:gr32 = COPY %edi
    %0:gr32 = nsw IMUL32rr %7:gr32, %6:gr32, implicit-def dead $eflags
    %2:gr32 = nsw ADD32rr %7:gr32, %6:gr32, implicit-def dead $eflags
    %3:gr32 = nsw ADD32rr %0:gr32, %6:gr32, implicit-def dead $eflags
    %1:gr32 = nsw IMUL32rr %0:gr32, %6:gr32, implicit-def dead $eflags
    TEST32rr %8:gr32, %8:gr32, implicit-def $eflags
    %4:gr32 = CMOV32rr %0:gr32, %2:gr32, 4, implicit $eflags
        %5:gr32 = CMOV32rr %1:gr32, %3:gr32, 4, implicit $eflags
    %9:gr32 = nsw IMUL32rr %4:gr32, %5:gr32, implicit-def dead $eflags
    $eax = COPY %9:gr32
    RET 0, $eax
```

<!-- PDF page 237; printed page 224 -->

最后还要更新支配树和循环分析结果，由于细节较多，限于篇幅，这里不再展开。最后提一点，LLVM 实现的 If-Conversion 算法是一个简化版本，比较复杂的 If-Conversion 算法可以参考论文“On Predicated Execution”○一。

## 9.7 循环不变量外提

LICM（循环不变量外提）优化通过减少不必要的重复运算，达到减少执行指令的目的。以代码清单 9-17 中的代码为例，每次循环迭代都为 tmp 变量赋一个常量值。实际上，赋值操作可以提到循环外面，这样仅需要进行一次赋值即可。

**代码清单 9-17 循环不变量外提示例**

```text
void test()
{
    for (int i = 0; i < 10; ++i) {
        int tmp = 100;
        cout << tmp + i << endl;
    }
}
```

循环不变量外提优化的基本步骤如下。

1）识别自然循环（参考第 5 章）。

2）识别自然循环中的循环不变量。在自然循环中，若表达式仅被定义了一次，且这个定义在循环过程中是不变的，那么这个表达式就是循环不变的。

3）判断循环不变量是否可以外提。若要外提，则表达式需要满足如下条件。

① 表达式支配所有循环退出点。

② 循环中表达式是唯一的定义点。

③ 定义点支配所有使用点。

4）将满足条件的循环不变量提到循环外，将可外提的表达式提到一个新的基本块中，并将该块放在循环之前，调整相应的跳转逻辑。

## 9.8 公共子表达式消除

在编译优化过程中，如果存在一个表达式 E 之前被计算过，且从之前的计算点到当前程序的执行点，E 用到的所有变量的值都没有发生过变化，那么 E 就被称为公共子表达式。E 的值不需要再进行重复运算，可直接重用，这种优化称为公共子表达式消除（即 CSE）。如果优化的范围仅在基本块内，则称为局部公共子表达式消除（local common subexpression

○一 具体请参见 https://web.eecs.umich.edu/~mahlke/courses/583f12/reading/HPL-91-58.pdf。

<!-- PDF page 238; printed page 225 -->

elimation）；如果优化范围在函数范围内覆盖了多个基本块，则称为全局公共子表达式消除（global common subexpression elimination）。

公共子表达式消除为编译器提供了以下收益。

1）优化代码大小：消除了冗余的代码序列，直接减少代码量。

2）减少代码执行时间：减少了重复的运算，可以让程序的执行效率得到提升。

3）助力其他优化：消除了无用的表达式，可以简化数据流、控制流的分析过程；消除冗余指令也让编译器可以更充分地使用指令的并发特性，以优化 CPU 的资源利用。

4）减少寄存器压力：多余的变量将被替代，代码需要使用的寄存器数量将会减少。

如图 9-10a 所示，在左侧的表达式序列中，b 和 c 有相同的表达式：a + 6×2。在计算从 b 到 c 的过程中，变量 a 的值没有发生变化，所以 c 直接复用 b 的计算结果即可。因此，可以消除表达式 c = a + 6×2，将 e = a + c 替换为 e = a + b。进一步，d 和 e 产生了相同的表达式，且在计算从 d 到 e 的过程中，变量 a 和 b 的值没有发生过变化，因此可继续消除表达式 e = a + c，e 直接复用 d 的计算结果。公共子表达式消除的示意图如图 9-10b所示。

![图 9-10 公共子表达式消除示意图](assets/figures/p238-9-10.png)

**图 9-10 公共子表达式消除示意图**

考虑有代码清单 9-18 所示的 IR 片段，该片段中 cse 函数接受 5 个入参，函数体内存在3 个基本块。其中，基本块 bb.0 中的 %a 与基本块 bb.1 中的 %c 都以 %x 和 %y 作为输入进行加法运算，但两个输入的顺序不同，而 %b 和 %d 的表达式完全相同。该 IR 片段将用于演示基本块之间的公共子表达式消除，即全局公共子表达式消除。

**代码清单 9-18 公共子表达式消除示例**

```text
define void @cse(i32 %x, i32 %y, i32* %p1, i64* %p2, i1 %cond) {
bb.0:
    %a = add i32 %x, %y
```

<!-- PDF page 239; printed page 226 -->

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

<!-- PDF page 240; printed page 227 -->

点的表达式完全相同，所以 %11 将被作为公共子表达式消除，后面用到 %11 的地方都会用 %0 替代。同理，%9 和 %12 表达式相同，%12 被消除并用 %9 替代，%13 节点被转换为 %13:gpr = SRLI killed %9:gpr, 32，转换结果与 %10 节点处的表达式相同，所以 %13 也会被消除，并使用 %10 替代。最终生成如图 9-11 中右侧所示的序列。

注 意 公共子表达式消除优化不仅可以作用于 MIR，也可以作用于 LLVM IR 上。

## 9.9 代码下沉

代码下沉是为了减少执行的代码，例如定义的变量只在一个分支语句中使用，那么将变量定义下沉到分支中可以有效减少执行的代码。代码下沉的示意图如图 9-12 所示。

![图 9-12 代码下沉示意图](assets/figures/p240-9-12.png)

**图 9-12 代码下沉示意图**

在图 9-12 左侧的图中，变量 v1 只在一个分支中使用，故将 v1 的定义下沉到使用它的分支中，得到如图 9-12 右侧图所示的结果。

在代码下沉的 CFG 中，下沉代码所在的基本块必须有多个后继基本块，否则没有下沉的必要。具体实现如下。

1）针对 COPY 指令进行优化（即进行 COPY 指令合并）。对于 dst = COPY src 这样的指令，如果 src 不是通过 COPY 指令定义，并且 src 和 dst 寄存器类型相同，则可以将所有的 dst 替换为 src，从而优化 COPY 指令。

2）对于一般的指令：

① 后端允许下沉，例如 ARM 后端对 CMP 指令有特殊约定，在一些情况下不能下沉。

② 不能移动的指令，不允许下沉。

③ 聚合指令，不允许下沉。

④ 用于保证实现 NULL Check（判空校验的指令）功能，不允许下沉。

⑤ 如果定义和使用寄存器的指令在同一个基本块中，不允许下沉（仅仅下沉定义寄存器指令，而不下沉使用寄存器的指令会导致程序逻辑错误）。

⑥ 指令必须下沉到当前基本块的一个后继基本块，并且下沉指令的目标基本块必须支配所有使用该指令定义的寄存器，否则程序逻辑会存在错误，不能下沉。

⑦ 只有存在收益的场景才能下沉，收益场景主要如下。

<!-- PDF page 241; printed page 228 -->

T 下沉的基本块不能逆支配指令下沉前的基本块，由于不存在逆支配约束，因此下沉

后的指令次数少于下沉前指令执行的次数，否则需要进一步判断收益。

T 指令下沉前位于内部循环，下沉后位于外部循环。下沉后指令执行次数能大幅减

少，若执行次数不能大幅减少则不能下沉。

T 下沉的基本块逆支配指令下沉前的基本块，如果下沉后指令定义的寄存器是用在 φ

函数中的，则可以继续下沉。

T 下沉的基本块逆支配指令下沉前的基本块，同时指令还可以再下沉并且有收益，则

继续下沉。

注 意 下沉的基本块逆支配指令下沉前的基本块，但指令不属于循环，则不能下沉。

T 下沉的基本块逆支配指令下沉前的基本块，并且当前指令属于循环，下沉后指令中

操作数的活跃区间变小或者寄存器压力没有增加则可以下沉。○一

⑧ 若下沉后的基本块存在关键边，判断是否可以拆分关键边：能拆分则规划如何拆分关键边，不能拆分关键边则不能下沉。

⑨ 计算下沉指令的位置（通常是 φ 函数后的第一条指令），并下沉代码。

⑩ 拆分关键边，并更新拆分边后的频率。

3）进行循环的特别情况处理，如果参数 SinkInstsIntoCycle 为 True（默认为 False），则进行下沉处理。

在循环中，候选的下沉指令必须同时满足：

T 是循环不变量。

T 可以安全移动。

T 不能下沉 GOT、常量。

T 不是聚合指令。

T 只有一处定义。

注 意 下沉循环指令需要满足支配属性，否则逻辑不正确。

## 9.10 窥孔优化

窥孔优化主要是做一些琐碎的、细粒度的优化，优化策略和优化模式会随着目标架构的指令特征的变化而变化。窥孔优化的基本过程如下。遍历每一条待优化指令，然后判断每一条待优化指令与相关指令组成的指令序列是否存在可以优化的模式。如果是，则将匹配的指令序列转换成更高效的新指令序列；如果没有匹配上，则不做优化。因为窥孔优化

○一 例如，使用和定义寄存器的指令位于同一循环，但是寄存器压力没有超过预定义的阈值—寄存器压力

模型并不准确，仅仅是一种估计方法。

<!-- PDF page 242; printed page 229 -->

需要遍历每条指令，所以它的时间复杂度随着需要匹配的指令序列的复杂度增加而增加。此外，因为窥孔优化针对特定指令场景，所以通用性不高。如果待编译代码具有较多的可优化指令序列，则优化效果明显；反之则效果一般。

LLVM 在后端提供了一个多架构共用的窥孔优化 Pass，里面有 10 个左右的子优化项，下面简单介绍一下每个子优化项进行优化的条件和效果。

1）操作数可交换指令优化：这个优化是为了在寄存器分配之后消除循环依赖产生的冗余复制指令而做的前置优化，主要是将循环里一些满足条件的三元操作数指令的两个源操作数交换位置。具体优化条件如下。

条件 1：三元操作数指令和循环头里的 φ 函数形成了循环数据依赖（即 φ 函数用到了三元操作数指令的目的寄存器，三元操作数指令也使用了 φ 函数的目的寄存器）。

条件 2 ：三元操作数的目的操作数和其中一个源操作数共用寄存器（即指令汇编形如add r1, r1, r2）。

条件 3：三元操作数指令的两个源操作数是可交换的。

条件 4 ：在使用三元操作数指令时，φ 函数的目的操作数不是条件 2 中共用寄存器的源操作数。

如图 9-13 所示，ADD 指令满足上述条件，所以优化后 ADD 指令的 %2 和 %1 两个操作数就互换位置了。

![图 9-13 操作数可交换指令优化示意图](assets/figures/p242-9-13.png)

**图 9-13 操作数可交换指令优化示意图**

2）寄存器合并不友好指令优化：旨在识别和处理一些伪指令和拆分指令（如 REG_ SEQUENCE、INSERT_SUBREG 和 EXTRACT_SUBREG）以及 Bitcast 指令。因为通过这些指令无法看出寄存器的使用情况，寄存器合并优化不会对它们进行处理，所以将它们称为寄存器合并不友好指令。此优化就是为了识别出这些指令，然后在满足一定条件的情况下，可将这些指令转换为 COPY 指令，从而提高后续寄存器的合并优化（该优化是主要针对 COPY 指令）的效果。

3）比较指令优化：如果目标架构减法指令具有直接设置条件码的特性，则可用带条件码的减法指令替代一部分比较指令，因此在比较指令与减法指令相邻且操作数相关的时候，可以将两者合并，从而消除冗余的比较指令。

4）选择指令优化：将选择指令优化成与或、异或等逻辑运算指令。

5）条件跳转指令优化：将条件跳转指令和其他的指令合并，生成另一种形式的条件跳转指令，从而删除冗余的指令。例如在 AArch64 后端可以将 and 和 cbnz 合并成 tbnz，如

<!-- PDF page 243; printed page 230 -->

**图 9-14 所示。**

![图 9-14 将 and 和 cbnz 指令合并示意图](assets/figures/p243-9-14.png)

**图 9-14 将 and 和 cbnz 指令合并示意图**

6）寄存器合并友好指令优化：将目的操作数和源操作数不同的寄存器类型的 COPY 指令优化成相同的寄存器类型的 COPY 指令，便于后面进行寄存器合并优化。如图 9-15 所示，可以将第二条 COPY 指令变成从 A 复制的 COPY 指令，从而避免了跨寄存器的复制操作。

![图 9-15 COPY 指令优化示意图](assets/figures/p243-9-15.png)

**图 9-15 COPY 指令优化示意图**

7）删除冗余复制优化：对于连续的 COPY 指令，如果第二个 COPY 指令的源寄存器是第一个 COPY 指令中源寄存器的子寄存器，则可以删除第二条 COPY 指令，并将用到第二条 COPY 指令的目的寄存器的地方替换为第一条 COPY 指令中目的寄存器的子寄存器，用例如图 9-16 所示。

![图 9-16 删除冗余复制优化示意图](assets/figures/p243-9-16.png)

**图 9-16 删除冗余复制优化示意图**

8）位扩展指令优化：当位扩展指令的源操作数寄存器还有其他使用点时，在满足数据流正确的情况下，将其他使用点替换为使用 COPY 位扩展指令的目的操作数寄存器。完成这个优化后，后续可以进一步做寄存器合并优化。

9）常量折叠优化：做立即数的常量折叠。

10）load 指令优化：这个优化针对的是“寄存器 – 内存”架构指令集中的内存加载指令（即 load 指令），因为这种指令集中的指令大部分都是可以直接操作内存的，所以在一些场景下可以将 load 指令折叠到运算指令里，从而减少生成代码的指令数。优化的主要过程如下。

① 遍历函数中的每条 load 指令，并判断 load 指令是否满足以下条件。

T load 指令具有可折叠属性（在指令信息中描述）。

T 有一条指令 I 使用了 load 指令加载结果寄存器，并且这条指令 I 具有等价的可以直

接操作内存的指令 I'。

T load 指令到指令 I 之间没有其他指令会改变 load 指令结果寄存器中的值。

② 如果满足①中的条件，则将指令 I 转变成指令 I' 的形式，并且如果 load 指令没有其

<!-- PDF page 244; printed page 231 -->

他使用点，就可以直接将其删除。

除了上述的通用优化外，不同的目标架构也会根据自身架构特征新增一个或多个窥孔优化 Pass，如 AArch64 新增了 Aarch64MIPeephole Pass。因为这类 Pass 都是架构相关的，只有用到特定架构的时候才会用到它们，此处不再过多描述，读者可以根据需要阅读相关代码。

## 9.11 本章小结

本章主要介绍 LLVM 代码生成过程中基于 SSA 形式的编译优化，涵盖尾代码重复、栈槽分配、If-Conversion、代码下沉等优化算法，并通过示例演示了各算法的主要功能。
