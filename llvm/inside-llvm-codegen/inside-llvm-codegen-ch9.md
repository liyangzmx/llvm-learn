# 第 9 章 基于 SSA 形式的编译优化

> 本章以 LLVM 18.1.8（源码 HEAD `3b5b5c1ec4a3095ab096dd780e84d7ab81f3d7ff`）的实现和本地实验为准。原书 LLVM 15.0.1 全文留在 `origin/`；本章保留节次和清单编号，重写过时推导与输出。实验使用 Debug、Assertions 构建，MIR 命令启用 `-verify-machineinstrs`，结果见 [校核记录](review/ch9.md) 和 [实验结果](review/experiments-ch9.json)。

机器级优化处理的是已经选成目标指令的 MIR。寄存器分配前的这一组 Pass 通常使用虚拟寄存器 SSA：每个虚拟寄存器只有一个定义，控制流汇聚处使用机器 PHI。SSA 简化了追溯定义、判定等价和移动指令的工作，但没有消除内存别名、物理寄存器副作用或目标约束。寄存器分配准备阶段会销毁 PHI、转换两地址指令，届时 MIR 不再具有同样的 SSA 性质。

`TargetPassConfig::addMachinePasses` 在优化级别不是 `None` 时调用 `addMachineSSAOptimization`。通用顺序如下；`addILPOpts` 是目标钩子，目标还可以替换或禁用 Pass。

```mermaid
flowchart TD
 A[前期尾代码重复] --> B[PHI 优化]
 B --> C[栈着色] --> D[局部栈槽预布局]
 D --> E[死机器指令消除] --> F[目标 ILP 优化]
 F --> G[前期 Machine LICM] --> H[Machine CSE]
 H --> I[Machine Sinking] --> J[Peephole Optimizer]
 J --> K[再次消除死机器指令]
```

`-O0` 不运行整个序列，但通用路径仍会加入局部栈槽分配。是否真正处理栈槽，还取决于目标是否需要虚拟基址寄存器。本章的例子刻意分别测试一个 Pass，避免把后续 Pass 的效果误归给当前算法。

先设置工具、输入和输出目录，随后逐节运行命令。完整自动检查仍可通过 [runner.py](experiments/ch9/runner.py) 重跑。

<details>
<summary>动手实验前展开：本章环境初始化（首次阅读推导可先略过）</summary>

<!-- manual-lab:ch9-setup -->

```sh
# 开启严格检查，使未处理的命令/管道失败与未定义变量尽早暴露。
set -euo pipefail
# 可提前 export 覆盖默认路径；各阶段使用同一套 LLVM 构建。
export LLVM_BUILD="${LLVM_BUILD:-/opt/llvm-project/build}"
export LLVM_SRC="${LLVM_SRC:-/opt/llvm-project}"
export BOOK_ROOT="${BOOK_ROOT:-/opt/coding/mlir-toy/llvm/inside-llvm-codegen}"
BOOK_INPUT="$BOOK_ROOT/experiments/ch9"
# 每次创建独立目录，保留前后阶段文件供比较，实验输入保持只读。
CODEGEN_LAB=$(mktemp -d)
export BOOK_INPUT CODEGEN_LAB
"$LLVM_BUILD/bin/llc" --version
printf '实验输出目录：%s\n' "$CODEGEN_LAB"
```

</details>

以下命令按正文顺序在同一个 Bash 会话运行；输入取自本章实验目录，所有新文件写入刚创建的临时目录。

## 9.1 前期尾代码重复

**沿两条路径看为什么“复制代码”反而可能有利。** 设 P、Q 都跳到 T，T 中只有一小段计算与分支。保留共享 T，静态代码较少，但执行到 T 要经过一次跳转，且 T 的输入可能要用 PHI 汇合。把 T 分别复制到 P、Q 后，各副本只接收本路径的输入，就可能消去 PHI、折叠常量或与前面的指令合并。

例如 P 给 x=0，Q 给 x=1，T 判断 x 是否为零。共享形式在 T 使用合并值；复制到两前驱后，P 的副本直接知道真，Q 的副本直接知道假，各自的条件分支可以简化。这说明收益不仅是少一次跳转，还可能来自路径信息变得明确。

复制后还要修复 T 后继中的 PHI 输入、活跃性和 CFG 分析；若 T 很大，代码膨胀又可能损害指令缓存。因此本节先研究变换的合法性，再讨论大小、频率和目标限制。第 11 章的后期尾代码重复发生在更晚的机器阶段，能利用和必须维护的信息有所不同。

### 9.1.1 尾代码重复原理

尾代码重复把公共后继块的指令复制到合适的前驱末尾，消除原先到该块的跳转。它可能增加静态代码量，却缩短热路径并为常量传播、PHI 化简和布局提供机会。是否更快需要测量，不能从少了一条 `jmp` 直接推出。

**代码清单 9-1 两个分支汇聚后返回的 C++ 例子**

```cpp
bool isEven(int x) {
    // 两条路径分别定义结果，在公共返回点汇合；SSA 中可由 PHI 表达。
    bool result;
    if (x % 2 == 0)
        result = true;
    else
        result = false;
    return result;
}
```

在概念 CFG 中，可以把共同的返回块复制到两个赋值块末尾。但这个示意不保证由优化后的 Clang 产生：前端或中端可能直接把函数化简为一次比较。还必须区分概念变换与 EarlyTailDuplicate 的实际限制——LLVM 18 的寄存器分配前路径拒绝包含 return 的候选。

```mermaid
flowchart LR
 subgraph before[变换前]
 E[条件] --> T[赋值 true]
 E --> F[赋值 false]
 T --> R[公共尾部]
 F --> R
 end
 subgraph after[概念变换后]
 E2[条件] --> T2[赋值 true 和尾部副本]
 E2 --> F2[赋值 false 和尾部副本]
 end
```

已有直通关系、能直接合并的相邻块和必须跳转才能到达的公共尾块，具有不同收益。不能仅以两个块是否相邻决定能否重复；`TailDuplicator` 还会询问目标的分支分析接口，并考虑是否处于基本块布局阶段。

### 9.1.2 尾代码收益判断

LLVM 18 的 `shouldTailDuplicate` 先判定结构和指令是否合法，再估算大小。需要掌握以下约束。

- 不展开自循环，也不随意处理异常入口、地址被引用或不可分析的控制流。
- `-tail-dup-size` 默认值是 2。未显式覆盖时，面向最小代码量的限制通常更紧；寄存器分配前以间接跳转结束的块另有 `TailDupIndirectBranchSize`，默认 20。它们是候选成本限制，不是“最多复制多少个基本块”。
- 指令带 `isNotDuplicable`、`isConvergent`，或属于不能安全重复的内联汇编分支等情况，会被拒绝。收敛性约束与多执行通道之间的会合有关，不能把它等同于普通控制依赖。
- 分配前还拒绝 call、return 等候选，避免调用引起的寄存器压力和后续保存/恢复代码膨胀。分配后取消的是这项阶段限制，指令自身的不可重复属性仍有效。
- 复制到某个前驱必须保持该前驱的其他出边语义。前驱只有一个后继、存在可消除的无条件跳转，是最容易理解的情况；源码还有布局与合并的专门处理。

大小满足阈值只是必要检查之一。分支概率、寄存器压力、直通关系和目标能力都可能改变收益。

### 9.1.3 执行尾代码重复优化

分配前复制一条定义虚拟寄存器的指令时，必须为副本创建新虚拟寄存器，并重写副本内的数据依赖。PHI 的值由所复制到的前驱入边决定，不能把原 PHI 原封不动放进前驱。算法相应生成 COPY、移除旧 PHI 入边，并使用 SSA 更新机制修复流向其他块的用途。最后更新后继、前驱和概率；只有原块确实无须保留时才删除它。循环中的 PHI 尤其要按变换后的 CFG 入边重新建立，不能沿用原基本块编号。

**代码清单 9-2 用于保留控制流的 C++ 说明**

```cpp
bool isEven(int x, int y) {
    bool result = false;
    if (x % 2 == 0) result = true;
    else result = false;
    // 此处两条分支都重新赋值，所以最终结果已不依赖上一组对 x 的判断。
    if (y % 3 == 0) result = true;
    else result = false;
    return result;
}
```

这个函数的最终返回值只依赖 `y % 3 == 0`：第二组赋值覆盖了第一组。它是控制流教学输入，名称不能被当成函数真实语义。为了稳定观察后端，实验直接提供以下 IR，未先运行能删去第一组分支的中端流水线。

**代码清单 9-3 tail.ll：尾代码重复的完整 IR**

```llvm
define dso_local noundef zeroext i1 @isEven(i32 noundef %x, i32 noundef %y) {
entry:
    %x.addr = alloca i32, align 4
    %y.addr = alloca i32, align 4
    ; 栈中的布尔值占一个字节；返回接口使用 i1，末尾需要截断。
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
if.else4:                                        ; preds = %if.end
    store i8 0, ptr %returnValue, align 1
    br label %if.end5

; 两个前驱共用此尾部，重复尾部时必须分别维护后续 CFG 入边。
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

实验指定 `bpfel`、`-mcpu=v4`、`-O2`。这里使用 v4 是因为输入含有符号余数，不把 generic BPF 的指令能力当成前提。分别在 `early-tailduplication` 前后截取 MIR：默认阈值保留 7 个块；增加 `-tail-dup-size=10` 后为 6 个块，公共 `if.end` 尾部复制到两条前驱路径。阈值变大后仍不会强迫所有块被复制，特别是 return 约束仍然成立。

<!-- manual-lab:ch9-taildup -->

```sh
# 先检查 IR；再只改变停止点或复制阈值，让基本块数量的差异有明确归因。
"$LLVM_BUILD/bin/llvm-as" "$BOOK_INPUT/tail.ll" -o "$CODEGEN_LAB/tail.bc"
"$LLVM_BUILD/bin/opt" -passes=verify "$CODEGEN_LAB/tail.bc" -disable-output
for variant in before default size10; do
  case "$variant" in
    before) TAIL_FLAGS=(-stop-before=early-tailduplication) ;;
    default) TAIL_FLAGS=(-stop-after=early-tailduplication) ;;
    size10) TAIL_FLAGS=(-stop-after=early-tailduplication -tail-dup-size=10) ;;
  esac
  "$LLVM_BUILD/bin/llc" -mtriple=bpfel -mcpu=v4 -O2 -verify-machineinstrs \
    "${TAIL_FLAGS[@]}" "$BOOK_INPUT/tail.ll" -o "$CODEGEN_LAB/tail-$variant.mir"
done
for variant in before default size10; do
  printf '%s: ' "$variant"
  sed -n '/^body:/,$p' "$CODEGEN_LAB/tail-$variant.mir" | \
    awk '/^[[:space:]]*bb\.[0-9]+[^:]*:/ {n++} END {print n " blocks"}'
done
```

输出依次为 7、7、6 个基本块；进一步打开 `tail-size10.mir` 的 body，可看到公共尾部副本。

## 9.2 PHI 优化

可以从“所有可选路径是否给出同一个值”入手。`r=PHI(a,P,a,Q)` 无论走哪条边都得到 a，所以在支配等条件满足时可以把 r 的使用替换为 a。若两个输入分别为 a、b，即使打印名称很相似，也不能这样替换。

循环中的 PHI 可能相互引用，例如 r 从入口接 a，从回边接 s，s 又只把 r 传回。逐条看，r/s 的输入并不完全相同；把这组 PHI 的循环关系作为一个整体看，如果唯一外部来源是 a，就有机会把整组化成 a。若还有另一个外部来源 b，则不能套用这个结论。由此可理解本节为什么需要看 PHI 之间的连通关系，而非只扫描相邻两行文字。

`OptimizePHIs` 解决两类问题：单值 PHI/COPY 环和死 PHI 环。单值环的所有外部输入都可追溯到同一个值，因此整个环不需要真正的合流。例如 `R2 = PHI(R1,R1)` 可以用 R1 代替；`R2 = PHI(R1,R2)` 中的自引用也不引入另一个外部值。多个 PHI 相互引用时，算法需在访问集合中避免无限递归，并追过可处理的 COPY；不能只逐条比较输入寄存器编号。

```text
R2 = PHI(R0, R1)
R0 = PHI(R1, R2)
# 若该 PHI 环的唯一外部值为 R1，则环内结果都可替换为 R1。
```

死环则不需要有共同外部值。只要环内定义的结果除了调试用途和相互引用，没有真正流向外部的计算，就可删除。反过来，看到“PHI 形成环”不能立刻判死，循环归纳变量也常形成这样的依赖环。

实验 `phi.mir` 构造一个菱形 CFG，汇聚处 `%1 = PHI %0, %bb.1, %0, %bb.2`。运行 `-run-pass=opt-phis` 后 PHI 消失，返回值直接 `COPY %0`。这验证了最简单的单值情形；循环情形的判定边界以上述源码为准。

<!-- manual-lab:ch9-phi -->

```sh
# 只运行 PHI 化简，观察同值 PHI 环是否消失；MIR 校验会检查变换后的结构。
"$LLVM_BUILD/bin/llc" -mtriple=bpfel -mcpu=generic -verify-machineinstrs \
  -run-pass=opt-phis "$BOOK_INPUT/phi.mir" -o "$CODEGEN_LAB/phi.mir"
sed -n '/^body:/,$p' "$CODEGEN_LAB/phi.mir"
```

结果中机器 PHI 消失，返回值改为直接 `COPY %0`。

## 9.3 栈着色

**以两个局部数组说明“共享”的条件。** 在一个作用阶段使用数组 a，a 的生命周期结束后，才开始使用数组 b；若布局的大小和对齐条件允许，两者可以复用同一片栈空间。每次使用仍访问自己的逻辑对象，只是其物理存储在不同时段重合。

如果 a 的指针逃逸到后续仍可能读取的位置，就不能只按源代码最后一次显式使用判断生命周期。生命周期标记为优化提供信息，但需要与实际 IR 语义和逃逸情况一致。两个对象的源代码作用域看起来分开，不自动证明所有执行路径上的存储需求不重叠。

可以先列时间线：a 开始→a 的各次访问→a 结束→b 开始→b 的访问。若某条路径把 b 的开始提前到 a 结束前，便出现干涉。着色的核心是对所有相关路径建立这种兼容关系，然后才把兼容对象放入同一槽。

栈着色合并生命周期不重叠的局部栈对象，让它们共享物理存储。它处理的是局部对象；第 10 章的 StackSlotColoring 主要处理寄存器分配产生的溢出槽，两者所处阶段和输入不同。

**代码清单 9-4 局部数组生命周期示例**

```c
void bar(char *, int);
void foo(int var) {
A: {
        // z 的块作用域先结束；存储能否复用还需后端掌握实际 lifetime 信息。
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
        // p 指向数组内部，复用栈槽时必须保留这个相对偏移。
        p = y + 1024;
    }
B:
    bar(p, 2);
}
```

z 的作用域在 A 后结束；x、y 中有一个地址经 p 到达 B，因此不能在 `if` 结束处随意结束两者生命周期。若只按真实访问路径想象复用空间，可写出下面的存储复用示意。

**代码清单 9-5 在额外语义前提下的理想存储复用示意**

```c
void foo(int var) {
    // 理想化复用模型：仅在前文语义前提成立时，可让不冲突对象共享存储。
    char storage[4096];
    char *p;
    bar(storage, 0);
    if (var) p = storage;
    else {
        bar(storage, 1);
        p = storage + 1024;
    }
    bar(p, 2);
}
```

这不是对任意外部 `bar` 的通用源码等价变换证明。地址逃逸、保存地址后的比较以及对象生命周期的合同，均会影响可证明性。机器栈着色依据 IR 的有效生命周期合同和实际用途工作，不以这段手改 C 代替证明。

用本章 Clang 18 AArch64 命令生成的 IR 仍只给 z 添加了 lifetime intrinsic。下面保留完整可解析的 IR，包括 bar/intrinsic 声明和属性组；runner 同时输出这一 `stack.ll` 文件。

**代码清单 9-6 Clang 18 实际生成的完整 stack.ll**

以下片段中的新增中文注释用于阅读，不属于原始工具输出。

```llvm
; ModuleID = '/opt/coding/mlir-toy/llvm/inside-llvm-codegen/experiments/ch9/stack.c'
source_filename = "/opt/coding/mlir-toy/llvm/inside-llvm-codegen/experiments/ch9/stack.c"
target datalayout = "e-m:e-i8:8:32-i16:16:32-i64:64-i128:128-n32:64-S128"
target triple = "aarch64-unknown-linux-gnu"

; Function Attrs: nounwind uwtable
define dso_local void @foo(i32 noundef %var) local_unnamed_addr #0 {
entry:
  %z = alloca [4096 x i8], align 1
  %x = alloca [4096 x i8], align 1
  %y = alloca [4096 x i8], align 1
  call void @llvm.lifetime.start.p0(i64 4096, ptr nonnull %z) #3
  call void @bar(ptr noundef nonnull %z, i32 noundef 0) #3
  ; 结束的是 z 对象的活跃存储期，不是执行释放内存的库函数。
  call void @llvm.lifetime.end.p0(i64 4096, ptr nonnull %z) #3
  %tobool.not = icmp eq i32 %var, 0
  br i1 %tobool.not, label %if.else, label %B

if.else:                                          ; preds = %entry
  call void @bar(ptr noundef nonnull %y, i32 noundef 1) #3
  %add.ptr = getelementptr inbounds i8, ptr %y, i64 1024
  br label %B

B:                                                ; preds = %entry, %if.else
  ; PHI 按实际进入 B 的前驱选择指针；它本身不读取数组内容。
  %p.0 = phi ptr [ %add.ptr, %if.else ], [ %x, %entry ]
  call void @bar(ptr noundef nonnull %p.0, i32 noundef 2) #3
  ret void
}

; Function Attrs: mustprogress nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.start.p0(i64 immarg, ptr nocapture) #1

declare void @bar(ptr noundef, i32 noundef) local_unnamed_addr #2

; Function Attrs: mustprogress nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.end.p0(i64 immarg, ptr nocapture) #1

attributes #0 = { nounwind uwtable "frame-pointer"="non-leaf" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="generic" "target-features"="+fp-armv8,+neon,+v8a,-fmv" }
attributes #1 = { mustprogress nocallback nofree nosync nounwind willreturn memory(argmem: readwrite) }
attributes #2 = { "frame-pointer"="non-leaf" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="generic" "target-features"="+fp-armv8,+neon,+v8a,-fmv" }
attributes #3 = { nounwind }

!llvm.module.flags = !{!0, !1, !2, !3, !4}
!llvm.ident = !{!5}

!0 = !{i32 1, !"wchar_size", i32 4}
!1 = !{i32 8, !"PIC Level", i32 2}
!2 = !{i32 7, !"PIE Level", i32 2}
!3 = !{i32 7, !"uwtable", i32 2}
!4 = !{i32 7, !"frame-pointer", i32 1}
!5 = !{!"clang version 18.1.8 (https://github.com/llvm/llvm-project.git 3b5b5c1ec4a3095ab096dd780e84d7ab81f3d7ff)"}
```

`llvm.lifetime.start/end` 是 IR intrinsic，在指令选择后成为 MIR 的 `LIFETIME_START/END`。栈着色识别标记，结合 CFG 计算对象活跃范围，寻找互不重叠的对象；通常先处理较大的槽，采用启发式合并，不能保证得到最小帧。合并时需维护 FrameIndex、内存操作数、别名及调试信息。对应 IR alloca 的用途也可能被重映射，但不能说原 alloca 一定全部删除。最后清除已处理的机器生命周期伪指令。

清单 9-6 的实验在栈着色前后都保留 3 个大小为 4096 的槽。仅看到某个 pass 消除了 lifetime 伪指令，不意味着发生了空间合并。下面为 x/y 提供明确有效的生命周期边界，用独立 IR 测试这些信息的影响。

**代码清单 9-7 stack-marked.ll：显式添加 x/y 生命周期**

```llvm
define dso_local void @foo(i32 noundef %var) local_unnamed_addr {
entry:
  %z = alloca [4096 x i8], align 1
  %x = alloca [4096 x i8], align 1
  %y = alloca [4096 x i8], align 1
  call void @llvm.lifetime.start.p0(i64 4096, ptr nonnull %z)
  call void @bar(ptr noundef nonnull %z, i32 noundef 0)
  call void @llvm.lifetime.end.p0(i64 4096, ptr nonnull %z)
  ; 此时 z 已结束，x/y 才开始；二者彼此仍有重叠，不能据此合成一个槽。
  call void @llvm.lifetime.start.p0(i64 4096, ptr %x)
  call void @llvm.lifetime.start.p0(i64 4096, ptr %y)
  %tobool.not = icmp eq i32 %var, 0
  br i1 %tobool.not, label %if.else, label %B

if.else:                                          ; preds = %entry
  call void @bar(ptr noundef nonnull %y, i32 noundef 1)
  %add.ptr = getelementptr inbounds i8, ptr %y, i64 1024
  br label %B

B:                                                ; preds = %entry, %if.else
  %p.0 = phi ptr [ %add.ptr, %if.else ], [ %x, %entry ]
  call void @bar(ptr noundef nonnull %p.0, i32 noundef 2)
  ; 最后一次 bar 返回后，两个对象都不再需要保留其值。
  call void @llvm.lifetime.end.p0(i64 4096, ptr %x)
  call void @llvm.lifetime.end.p0(i64 4096, ptr %y)
  ret void
}

declare void @bar(ptr, i32)
declare void @llvm.lifetime.start.p0(i64 immarg, ptr nocapture)
declare void @llvm.lifetime.end.p0(i64 immarg, ptr nocapture)
```

在 AArch64 上，这份输入的 x 槽合并进 z，MIR 中保留 `%stack.0.z` 与 `%stack.2.y` 两个对象。原来的 12288 字节对象容量变成 8192 字节；这是局部对象容量，不等于包含保存区、对齐等项目的整个函数帧大小。x/y 的地址和 PHI 用途导致分析保留其重叠可能性，不能从两条分支互斥推出本实现必然合并成一个 4096 字节槽。

更小的正例 `lifetime.ll` 含两个顺序使用、各 64 字节的对象，每个对象的使用完整位于自己的 lifetime.start/end 之间。BPF 栈着色实测把两个槽合为一个，PEI 后访问相对 R10 的 -64 偏移。这个正例隔离了生命周期复用机制，也避免把 AArch64 大栈帧套用到 BPF。

**代码清单 9-8 生命周期和实际使用必须同时建模的算法示意**

```text
entry:
    # 提前算出地址不等于对象已活跃；判断还要追踪 lifetime 与实际访问。
    address1 = address_of(stack_object_1)
    address2 = address_of(stack_object_2)
    branch condition, loop, exit
loop:
    lifetime_start(stack_object_1)
    use(address1)
    lifetime_end(stack_object_1)
    use(address2)
    branch more, loop, exit
exit:
    ...
```

清单 9-8 是算法说明，`address_of/use` 不是可编译语法。栈对象的地址计算可能被移动，且循环回边会带来跨块活跃性，文件行号区间不能代替 CFG 数据流。LLVM 18 使用前向数据流，并可把生命周期开始推迟到首次使用；对象逃逸和生命周期外实际使用又可能迫使分析采用更保守的范围。这里的“使用”及逃逸依据实现中的 frame-index、内存操作数等信息判定，并不等于所有指针地址计算都立即读取对象。错误合并会使两个仍活跃对象互相覆盖，因此不确定时保留独立槽。

<!-- manual-lab:ch9-stack-coloring -->

```sh
# 对比前端实际发出的 lifetime 与手工补全版本，观察哪些栈对象能共享槽。
"$LLVM_BUILD/bin/clang" --target=aarch64-unknown-linux-gnu -O2 -S -emit-llvm \
  "$BOOK_INPUT/stack.c" -o "$CODEGEN_LAB/stack.ll"
for point in before after; do
  "$LLVM_BUILD/bin/llc" -mtriple=aarch64-unknown-linux-gnu -O2 -verify-machineinstrs \
    "-stop-$point=stack-coloring" "$CODEGEN_LAB/stack.ll" \
    -o "$CODEGEN_LAB/stack-$point.mir"
done
"$LLVM_BUILD/bin/llc" -mtriple=aarch64-unknown-linux-gnu -O2 -verify-machineinstrs \
  -stop-after=stack-coloring "$BOOK_INPUT/stack-marked.ll" \
  -o "$CODEGEN_LAB/stack-marked.mir"
sed -n '/^stack:/,/^body:/p' "$CODEGEN_LAB/stack-after.mir"
sed -n '/^stack:/,/^body:/p' "$CODEGEN_LAB/stack-marked.mir"

# 小型 BPF 例子继续观察 lifetime 标记的消除，以及 PEI 后的实际槽偏移。
"$LLVM_BUILD/bin/llvm-as" "$BOOK_INPUT/lifetime.ll" -o "$CODEGEN_LAB/lifetime.bc"
"$LLVM_BUILD/bin/opt" -passes=verify "$CODEGEN_LAB/lifetime.bc" -disable-output
for point in before after pei; do
  case "$point" in
    before) STOP_POINT=-stop-before=stack-coloring ;;
    after) STOP_POINT=-stop-after=stack-coloring ;;
    pei) STOP_POINT=-stop-after=prologepilog ;;
  esac
  "$LLVM_BUILD/bin/llc" -mtriple=bpfel -mcpu=generic -O2 -verify-machineinstrs \
    "$STOP_POINT" "$BOOK_INPUT/lifetime.ll" -o "$CODEGEN_LAB/lifetime-$point.mir"
done
sed -n '/^body:/,$p' "$CODEGEN_LAB/lifetime-after.mir"
sed -n '/^body:/,$p' "$CODEGEN_LAB/lifetime-pei.mir"
```

AArch64 的原始/标记版分别保留 3/2 个 4096 字节槽；BPF 顺序生命周期例子合并为一个 64 字节槽，PEI 后出现 R10 相对偏移。

## 9.4 栈槽分配

本节应沿“抽象对象怎样成为机器栈对象”理解。IR 的 alloca 给出对象类型、数量与对齐等信息；进入机器层后，后端需要用 frame index 标识相应对象。此时的 FI 是栈对象编号，不是已经固定的 `SP+16` 地址。

最终偏移为什么不能现在全定下来？后续寄存器分配还可能产生新的溢出槽，函数使用的 callee-saved 寄存器也影响保存区域，目标还要满足栈对齐。于是先保留对象身份与约束，到第 11 章统一布局，再把 FI 替换成目标基址加偏移。若把这里的“分配栈槽”与“已经写出最后机器地址”混同，后续 PEI 就会显得多余。

`LocalStackSlotPass` 在 `TargetRegisterInfo::requiresVirtualBaseRegisters(MF)` 为真且存在局部对象时，预先安排局部对象相对布局。它通过 `needsFrameBaseReg` 等接口判断某些引用是否需要虚拟基址寄存器。如果需要，就在寄存器分配前引入基址计算，使后续分配器统一处理这个寄存器，并让多个访问有机会共享基址。

这解决的是寻址范围问题。例如 AArch64 32 位 LDP/STP 的有符号 7 位立即数按 4 字节缩放，字节偏移为 -256 到 252；超范围访问不能原样编码。实际目标可能采用其他 load/store 形式，或者在 PEI 阶段用临时寄存器展开。不同寻址形式的立即数范围不能混为一谈。

本 Pass 不完成最终栈帧，也不负责证明所有最终访问已经合法。寄存器分配还可能新增溢出槽，PEI 才掌握最终保存区和对象偏移。预布局需遵守增长方向、对齐和栈保护分组等约束；仅当确实插入了基址寄存器时才设置使用局部预分配块的状态，否则 PEI 仍可重新布局。不能把原书对某目标保存区的固定字节估计推广到所有函数。

## 9.5 死指令消除

**先删末端，再看上游是否也死。** 有 `a=纯计算; b=a+1`，b 没有任何使用。如果 b 指令没有必须保留的副作用，可以先删 b；此时 a 的唯一用户也没了，又可能删 a。这是重复消除或工作表传播的原因，一次只按原始 use 数扫描可能留下新出现的死节点。

反例是调用返回值未使用：调用可能写内存、抛异常或产生其他可观察效果，不能只看返回寄存器 dead 就删调用。机器指令还可能隐式定义或使用状态寄存器，所以判断使用关系要包括隐式操作数。理解“结果不用”与“操作无效果”这两个条件，比记一个 Pass 名更重要。

一条指令的所有结果都不再需要，并且该指令没有必须保留的副作用，才可能删除。普通无用加法与 volatile 访问、调用、返回、栅栏不同：后几类不能仅按寄存器用途计数判死。物理寄存器也有隐式定义、别名和保留寄存器限制。

`DeadMachineInstructionElim` 在基本块内部反向扫描，跟踪物理寄存器活跃性，并查询虚拟寄存器的非调试用途。删除一个消费者后，它的输入定义可能成为新的死指令；函数级处理重复进行，直至一轮不再删除。传播方向是从已删除用途追溯到其定义，不能先删除仍被使用的定义。

实验 `dce.mir` 输入的核心如下：

```text
; %1 的计算只被 %2 使用，而 %2 没有用途；删除 %2 后还要继续消除 %1。
%0:gpr = COPY $r1
%1:gpr = ADD_ri %0, 7
%2:gpr = COPY %1
$r0 = COPY %0
RET implicit $r0
```

`-run-pass=dead-mi-elimination` 删除 `%2` 的 COPY 和 `%1` 的 ADD，只留下从 R1 到 R0 的返回路径。验证器通过，但这不代表 DCE 可以任意删除任一没有显式输出的指令。

<!-- manual-lab:ch9-dead-mi -->

```sh
# 单独运行死机器指令消除，确认无用定义链被删而有副作用或返回所需值仍保留。
"$LLVM_BUILD/bin/llc" -mtriple=bpfel -mcpu=generic -verify-machineinstrs \
  -run-pass=dead-mi-elimination "$BOOK_INPUT/dce.mir" -o "$CODEGEN_LAB/dce.mir"
sed -n '/^body:/,$p' "$CODEGEN_LAB/dce.mir"
```

无用的 ADD 和后续 COPY 都被删除，保留返回所需的 R1→R0 路径。

## 9.6 ILP 优化之 If-Conversion

**把控制选择改成值选择，需要先证明两侧能安全执行。** 源结构是 `if c then x=a+b else x=a-b`。若两侧都是适合转换的无副作用运算，可以考虑先得到候选结果，再按 c 选择，或使用目标支持的谓词/条件指令，减少控制流分支。

但若 then 分支执行可能非法的 load，原程序在 c=false 时根本不访问它；把 load 无条件提前就可能新增错误行为。即使语义允许，原先每次只算一侧，转换后可能两侧都算，增加指令与寄存器压力。因此收益取决于分支代价、可预测性、目标条件执行能力以及额外工作。下面实验中的变化应同时检查分支减少与新增操作，不能只数基本块变少了几个。

If-Conversion 把分支控制依赖变为数据选择或谓词执行。它可能减少错误预测和跳转，却会执行原先只在某一分支上执行的计算，并延长某些值的活跃期。因此安全性与收益必须分别检查。

**代码清单 9-9 原始控制流的伪代码**

```text
if (A) { z = S1(); q = S2(); }
else   { z = S3(); q = S4(); }
use(z, q);
```

**代码清单 9-10 显式分支形式**

```text
if (!A) goto False;
z = S1(); q = S2();
goto Join;
False:
z = S3(); q = S4();
Join:
use(z, q);
```

**代码清单 9-11 可安全推测执行时的数据选择形式**

```text
# 这里会执行两边计算：只有额外执行安全，才能用 select 代替分支。
zt = S1(); qt = S2();
zf = S3(); qf = S4();
z = select(A, zt, zf);
q = select(A, qt, qf);
use(z, q);
```

清单 9-11 不适用于任意 S1～S4。未选择一侧若会写内存、发起调用、触发不可接受的故障或破坏物理寄存器状态，不能无条件执行。EarlyIfConverter 的 `SSAIfConv` 检查菱形/三角形结构、分支可分析性、PHI、目标 `canInsertSelect` 能力以及待移动指令是否可安全推测执行，再用关键路径等模型评估收益。“目标有谓词指令”与“目标能够生成所需 select”是不同接口条件。

**代码清单 9-12 if-conversion.cpp：可复现的整数计算例子**

```cpp
int MUL(int x, int y, bool flag) {
    // aaa 供两个分支复用；提前计算越多值，潜在的同时活跃值也越多。
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

实验先以 `-O0 -Xclang -disable-O0-optnone` 生成 IR，再单独运行 `mem2reg`，保留菱形 CFG。直接使用 Clang `-O2` 可能在进入这个机器 Pass 前已改变输入。以 X86-64 generic 为例，Pass 前 MIR 的 body 为：

**代码清单 9-13 EarlyIfConverter 之前的实际 MIR**

以下片段中的新增中文注释用于阅读，不属于原始工具输出。

```text
bb.0.entry:
    successors: %bb.1(0x40000000), %bb.2(0x40000000)
    liveins: $edi, $esi, $edx

    ; 本例三个实参来自 EDI/ESI/EDX；%9 保存决定分支的 flag。
    %9:gr32 = COPY $edx
    %8:gr32 = COPY $esi
    %7:gr32 = COPY $edi
    %0:gr32 = nsw IMUL32rr %8, %7, implicit-def dead $eflags
    TEST32rr %9, %9, implicit-def $eflags
    JCC_1 %bb.2, 4, implicit $eflags
    JMP_1 %bb.1

  bb.1.if.then:
    successors: %bb.3(0x80000000)

    %1:gr32 = nsw IMUL32rr %8, %7, implicit-def dead $eflags
    %2:gr32 = nsw IMUL32rr %7, %0, implicit-def dead $eflags
    JMP_1 %bb.3

  bb.2.if.else:
    successors: %bb.3(0x80000000)

    %3:gr32 = nsw ADD32rr %8, %7, implicit-def dead $eflags
    %4:gr32 = nsw ADD32rr %7, %0, implicit-def dead $eflags

  bb.3.if.end:
    ; PHI 根据前驱选择 z；下一条 PHI 同样选择 q，二者随后相乘。
    %5:gr32 = PHI %3, %bb.2, %1, %bb.1
    %6:gr32 = PHI %4, %bb.2, %2, %bb.1
    %10:gr32 = nsw IMUL32rr %5, %6, implicit-def dead $eflags
    $eax = COPY %10
    RET 0, $eax
```

LLVM 18 X86 的 `enableEarlyIfConversion()` 同时要求 CMOV 能力和 `-x86-early-ifcvt` 开关。该开关默认 false：默认实验前后都是 4 个基本块。显式打开后，本例无需 `-stress-early-ifcvt` 就能变换。以下两步是对实际算法的分解说明，不是额外的 Pass 截图。

**代码清单 9-14 把可推测的两个分支计算移到 Head：概念中间态**

```text
Head:
    aaa = y * x
    z_false = y + x
    q_false = x + aaa
    z_true  = y * x
    q_true  = x * aaa
    test(flag)
    # 此时还需将 Tail 的 PHI 改为选择，不能直接删去所有控制流。
```

**代码清单 9-15 把两个 PHI 替换为条件选择：实际指令片段**

```text
TEST32rr %9, %9, implicit-def $eflags
%5:gr32 = CMOV32rr %1, %3, 4, implicit $eflags
%6:gr32 = CMOV32rr %2, %4, 4, implicit $eflags
```

条件码 4 在这里表示等于零，因而 flag 为零时选择 false 一侧。必须在算术指令之后重新设置 flags，不能让先前的 ADD/IMUL 随意覆盖 select 依赖的状态。删除冗余分支并合并汇聚块后，得到下面的实际结果：

**代码清单 9-16 显式启用 -x86-early-ifcvt 后的实际 MIR**

以下片段中的新增中文注释用于阅读，不属于原始工具输出。

```text
bb.0.entry:
    liveins: $edi, $esi, $edx

    %9:gr32 = COPY $edx
    %8:gr32 = COPY $esi
    %7:gr32 = COPY $edi
    %0:gr32 = nsw IMUL32rr %8, %7, implicit-def dead $eflags
    %3:gr32 = nsw ADD32rr %8, %7, implicit-def dead $eflags
    %4:gr32 = nsw ADD32rr %7, %0, implicit-def dead $eflags
    %1:gr32 = nsw IMUL32rr %8, %7, implicit-def dead $eflags
    %2:gr32 = nsw IMUL32rr %7, %0, implicit-def dead $eflags
    ; 两边算术已执行完，重新测试 flag，避免算术指令覆盖选择所需的 EFLAGS。
    TEST32rr %9, %9, implicit-def $eflags
    ; 条件码 4 表示相等：flag 为零时选 %3，否则保留 %1；下一条同理。
    %5:gr32 = CMOV32rr %1, %3, 4, implicit $eflags
    %6:gr32 = CMOV32rr %2, %4, 4, implicit $eflags
    %10:gr32 = nsw IMUL32rr %5, %6, implicit-def dead $eflags
    $eax = COPY %10
    RET 0, $eax
```

四块变成一块，包含两条 `CMOV32rr`，而分支两侧算术都保留。本实验验证结构变化；未运行 X86 硬件性能测试，也不把条件选择假定为恒定优于分支。

<!-- manual-lab:ch9-if-conversion -->

```sh
# 禁用 O0 的 optnone 后仅做 mem2reg：暴露 SSA 值，同时尽量保留供后端观察的分支。
"$LLVM_BUILD/bin/clang++" --target=x86_64-unknown-linux-gnu -O0 \
  -Xclang -disable-O0-optnone -S -emit-llvm "$BOOK_INPUT/if-conversion.cpp" \
  -o "$CODEGEN_LAB/if-raw.ll"
"$LLVM_BUILD/bin/opt" -passes=mem2reg -S "$CODEGEN_LAB/if-raw.ll" \
  -o "$CODEGEN_LAB/if.ll"
# enabled 显式打开 X86 前期 if-conversion，另两组用于区分默认禁用与 Pass 前状态。
for variant in before disabled enabled; do
  case "$variant" in
    before) IFCVT_FLAGS=(-stop-before=early-ifcvt) ;;
    disabled) IFCVT_FLAGS=(-stop-after=early-ifcvt) ;;
    enabled) IFCVT_FLAGS=(-stop-after=early-ifcvt -x86-early-ifcvt) ;;
  esac
  "$LLVM_BUILD/bin/llc" -mtriple=x86_64-unknown-linux-gnu -O2 -verify-machineinstrs \
    "${IFCVT_FLAGS[@]}" "$CODEGEN_LAB/if.ll" -o "$CODEGEN_LAB/if-$variant.mir"
done
sed -n '/^body:/,$p' "$CODEGEN_LAB/if-enabled.mir"
```

默认关闭时仍是四块；显式开启后输出只有一个块，并包含两条 CMOV32rr。

## 9.7 循环不变量外提

假设循环每次计算 `t=a+b`，a、b 都来自循环外且在循环内不变。那么 t 的数值每次相同，可以考虑移动到 preheader，循环内只使用结果。这一步复用了第 5 章建立统一进入块的结构。

数值不变仍不是全部条件。如果操作可能陷阱、访问会被循环内 store 改变的内存，或者循环可能执行零次，外提都需要额外论证：原来不执行循环时不会发生该操作，移动后却会执行。对机器指令还要考虑物理寄存器及目标约束。先证明输入不变，再证明位置移动合法，最后估算多占寄存器与减少重复计算的收益。

循环不变指令的输入在循环内不变，因而可能只计算一次。一个值“只有一个 SSA 定义”并不足以证明循环不变：由循环 PHI 或随迭代变化的加载计算出的值，每次动态执行仍可能不同。

**代码清单 9-17 外提循环不变乘法的 C 说明**

```c
void fill(long *out, long a, long b) {
    // a、b 不随迭代变化，乘法可考虑外提；out[i] 的逐次存储仍须保留。
    for (int i = 0; i != 10; ++i)
        out[i] = a * b;
}
```

这里忽略 C 中有符号乘法溢出的调用输入；MIR 实验 `licm.mir` 直接指定机器整数计算以隔离外提。BPF `early-machinelicm` 把循环体内的 `MUL_rr` 移到前置块，循环里的 store 和归纳变量更新保留。

MachineLICM 按循环层次寻找候选，判断所有输入定义是否来自循环外或已证明不变的指令，并检查可移动性、内存别名、调用和物理寄存器影响。加载还需证明循环内不会改变所读内存。可能陷阱或不可安全推测执行的操作，要证明移动不会引入原先不执行的行为；不能把“支配每个循环退出”当成全部合法指令的统一必要条件。安全乘法可以从条件执行路径外提，而会故障的加载可能不行。

外提位置通常为循环 preheader，并且必须保持对所有用途的支配关系；没有可用 preheader 时，能否创建或采用其他位置取决于实现与目标。外提也可能延长活跃区间，导致溢出。因此 LLVM 18 还评估寄存器压力、廉价重算和收益，并非找到不变量就移动。

<!-- manual-lab:ch9-licm -->

```sh
# 直接从 MIR 运行循环外提，检查乘法的所在块，避免把 IR 优化的效果混入。
"$LLVM_BUILD/bin/llc" -mtriple=bpfel -mcpu=generic -verify-machineinstrs \
  -run-pass=early-machinelicm "$BOOK_INPUT/licm.mir" -o "$CODEGEN_LAB/licm.mir"
sed -n '/^body:/,$p' "$CODEGEN_LAB/licm.mir"
```

MUL_rr 出现在 bb.1 循环头之前的入口块，store 和归纳变量更新仍在循环中。

## 9.8 公共子表达式消除

对 `t=a+b` 与后面的 `u=a+b`，如果两次引用的是同一组值、操作语义相同，并且 t 的定义支配 u 的使用位置，就可以考虑用 t 替代 u。这里的“同一组值”在 SSA 中比源变量名更明确：若第二次 a 实际来自另一个定义，就不是相同表达式。

如果第一次计算只在左分支，第二次在左右汇合后，第一次并不支配第二次，直接复用会让右分支读取没有定义的值。若是 load，还要证明中间没有可能改变所读内存的操作。由此可见 CSE 同时依赖值等价、控制流可用性和内存信息，不只是建立一张 opcode 文本哈希表。

公共子表达式消除用可复用的早先结果替代冗余计算。对 SSA 虚拟寄存器，单个寄存器本身不会在后面被重新定义；但内存、物理寄存器和指令 flags 仍可能改变等价性。LLVM 的 MachineCSE 使用支配树范围内的表达式表，处理可交换操作数和 COPY 等机会，并通过目标信息检查合法性。

消除一个定义会减少计算，却可能延长另一个值的活跃区间。所以 CSE 不保证降低寄存器压力，也不保证所有输入都更快。跨块替换还要求早先结果支配该用途，不能因两条文本相同就从不相关分支直接复用。

**代码清单 9-18 cse.ll：跨基本块的重复计算**

```llvm
define void @cse(i32 %x, i32 %y, ptr %p1, ptr %p2, i1 %cond) {
bb.0:
    %a = add i32 %x, %y
    store i32 %a, ptr %p1
    %b = zext i32 %a to i64
    store i64 %b, ptr %p2
    br i1 %cond, label %bb.1, label %bb.2

bb.1:
    ; 加法交换输入后仍与支配本块的 %a 等价，因此可复用已有结果。
    %c = add i32 %y, %x
    ; 计算冗余不代表这次内存写入冗余；CSE 不能随手删除存储副作用。
    store i32 %c, ptr %p1
    ; %b 已完成相同的零扩展，后端可复用它对应的机器值。
    %d = zext i32 %a to i64
    store i64 %d, ptr %p2
    br label %bb.2

bb.2:
    ret void
}
```

以 RISCV64 generic、`-O2` 在 `machine-cse` 前后截取 MIR，ADDW/SLLI/SRLI 总数从 6 条变为 3 条。第二块的交换输入加法复用 `%0`，零扩展结果复用 `%10`；4 条 store 都仍然存在。这个 Pass 消除的是值计算，不据此认定有副作用的写操作也可删除。

以下片段中的新增中文注释用于阅读，不属于原始工具输出。

```text
; 优化前 bb.1 中的核心计算
%11:gpr = ADDW %7, %6
SW killed %11, %3, 0
; 左移后逻辑右移会清除高 32 位，完成这里 i32 到 i64 的零扩展。
%12:gpr = SLLI %0, 32
%13:gpr = SRLI killed %12, 32
SD killed %13, %4, 0

; 优化后 bb.1 中只剩下复用结果的存储
SW %0, %3, 0
SD %10, %4, 0
```

独立的 `cse.mir` 还验证了 BPF 同块内两次 `ADD_ri %0,7` 合并为一次，后续加法使用同一结果两次。MachineCSE 属于机器级 Pass；IR 层的 GVN 等算法也能消除冗余计算，但它们的输入和机会不同。

<!-- manual-lab:ch9-cse -->

```sh
# 用 BPF 检查单 Pass，再用 RISC-V 完整流水线的前后截面观察零扩展等计算复用。
"$LLVM_BUILD/bin/llc" -mtriple=bpfel -mcpu=generic -verify-machineinstrs \
  -run-pass=machine-cse "$BOOK_INPUT/cse.mir" -o "$CODEGEN_LAB/cse.mir"
"$LLVM_BUILD/bin/llvm-as" "$BOOK_INPUT/cse.ll" -o "$CODEGEN_LAB/cse.bc"
"$LLVM_BUILD/bin/opt" -passes=verify "$CODEGEN_LAB/cse.bc" -disable-output
for point in before after; do
  "$LLVM_BUILD/bin/llc" -mtriple=riscv64-unknown-linux-gnu -O2 -verify-machineinstrs \
    "-stop-$point=machine-cse" "$BOOK_INPUT/cse.ll" \
    -o "$CODEGEN_LAB/cse-riscv-$point.mir"
done
sed -n '/^body:/,$p' "$CODEGEN_LAB/cse.mir"
sed -n '/^body:/,$p' "$CODEGEN_LAB/cse-riscv-after.mir"
```

BPF 的两个重复立即数加法合为一个；RISCV 的第二块复用早先结果，四条 store 保留。

## 9.9 代码下沉

入口计算 t，但只有冷分支用 t，热分支直接返回。在可移动条件满足时，把 t 的计算放入冷分支，可以避免热路径做无用工作。与外提相比，下沉把操作移向使用者，通常缩短某些活跃范围，但若有多个使用分支，复制计算到多个分支又可能增加静态代码。

检查一个下沉候选，可按三步：目标位置是否仍被所有操作数定义支配；是否仍支配需要它的使用；从原位置到新位置是否越过不能交换的副作用或寄存器约束。如果不能找到满足所有使用的位置，就不能只看某一条热点路径决定移动。后面的跨边拆块，正是为了获得更精确的插入位置。

下沉推迟计算，使不需要结果的路径有机会完全不执行该指令。它也可能缩短结果的活跃区间。与 LICM 相反方向的移动并不矛盾：二者依赖不同的控制流与频率条件。

实验 `sink.mir` 的入口有 `%2 = ADD_ri %0,7`，但结果只在 bb.1 返回路径使用。运行 `machine-sink` 后，该 ADD 位于 bb.1，另一条返回零的路径无需计算它。其余控制流保持，验证器确认移动后的定义/用途合法。

通用算法需要同时考虑下列事项。

- 可处理 COPY 时先尝试消除中转，但须满足寄存器类和数据流限制。
- 移动必须安全，不能跨越影响其内存或寄存器语义的指令；收敛操作、目标禁止移动的指令和隐式空检查相关条件也会限制下沉。
- 找到的目标块必须支配所有真正用途。PHI 的使用位置在对应入边上，不能把它当作汇聚块中普通的使用。候选除直接后继，还可能包含特定支配树子节点。
- 若同块中还有必须保留的用途，不能只把定义单独移动到其他块。算法可能分轮下沉依赖链，但每次移动都须维持定义可达性。
- 目标不后支配原块，意味着有路径可能避开执行；目标循环深度更浅、活跃范围缩短等也可能带来收益。后支配、频率和压力是收益分析要素，不是无条件的速度保证。
- 关键边可能需要先计划拆分，更新 CFG、PHI 入边和频率，再执行移动；不能在共享后继的入口无条件插入一条只属于某条入边的计算。

`sink-insts-to-avoid-spills` 所关联的循环内压力优化还有额外候选规则，不能将其与所有普通下沉混成一套必要充分条件。每次选择的插入点还需位于 PHI 等块入口特殊指令之后，并保持调试信息有效。

<!-- manual-lab:ch9-machine-sink -->

```sh
# 检查定义是否移到唯一需要它的后继，以及相应的活跃寄存器信息是否更新。
"$LLVM_BUILD/bin/llc" -mtriple=bpfel -mcpu=generic -verify-machineinstrs \
  -run-pass=machine-sink "$BOOK_INPUT/sink.mir" -o "$CODEGEN_LAB/sink.mir"
sed -n '/^body:/,$p' "$CODEGEN_LAB/sink.mir"
```

ADD_ri 移入唯一使用它的 bb.1，返回零的另一条路径不再执行该加法。

## 9.10 窥孔优化

窥孔优化从小范围指令组合寻找更合适的等价形式。最简单的例子是复制链 `b=COPY a; c=COPY b`，若中间 a 没被覆盖且寄存器约束兼容，可以尝试让 c 直接引用 a；若 b 的唯一使用因此消失，还可能继续删除第一条复制。

窗口小不代表语义条件少。转换类型、子寄存器、标志位和隐式操作数都可能使表面相同的模式具有不同含义。先写出该模式需要保持的值或位关系，再对照目标指令约束，会比背诵“某种 COPY 总能消去”可靠。小变换也可能串联：一次改写暴露下一次机会，所以实现需要控制重新访问与终止。

PeepholeOptimizer 对机器指令模式进行局部改写，但搜索范围不等于严格相邻两条指令。它以目标钩子和虚拟寄存器数据流为基础，改善后续合并与代码生成。通用实现的主要模式如下。

| 模式 | 目的与边界 |
|---|---|
| 可交换的循环递归指令 | 当运算和循环 PHI 形成递归关系，交换可交换的源，使未来两地址约束与 PHI 值更容易共用寄存器；必须是合法交换。 |
| 非合并友好的伪指令 | 追踪 REG_SEQUENCE、INSERT_SUBREG、EXTRACT_SUBREG、位转换等值来源，把能证明的中转化为更易合并的 COPY；并非每条此类指令都可删除。 |
| 比较优化 | 目标可复用先前运算产生的条件码时，消除冗余比较；必须检查 flags 语义和中间破坏。 |
| 选择优化 | 通过目标 `optimizeSelect` 简化 select；可能使用逻辑或条件指令，不保证统一变成与/或。 |
| 条件跳转优化 | 通过 `optimizeCondBranch` 把测试和分支合成目标形式，如适用的按位测试跳转；掩码、位宽和分支方向都需吻合。 |
| COPY 来源重写 | 绕过跨寄存器类的中转，在合法寄存器类/子寄存器范围内寻找更直接来源。 |
| 冗余 COPY 消除 | 重用已存在的完整或子寄存器复制，正确维护各 lane，不能把部分定义视为整个寄存器定义。 |
| 扩展结果复用 | 已扩展值的子寄存器有机会替代原输入的其他用途，帮助后续寄存器合并。 |
| 立即数折叠 | 目标支持立即数操作数时，将常量定义折入消费者；仍受编码范围和定义用途约束。 |
| 加载折叠 | 目标有等价寄存器—内存形式时，将独立 load 合入消费者；要求内存顺序、volatile/atomic、别名和使用次数等条件都允许。 |

例如 `load p; add x,loaded` 不能仅凭目标存在内存 add 就合并：两条指令间若有可能写 p 的操作，移动读取时间便可能改变值。合并后若 load 还有其他用途，也不能直接删除它。类似地，比较和算术不只是结果数值一致，条件码的定义必须一致。

一些模式通过改写输入而暂时留下无用定义，因此通用 SSA 流水线在 PeepholeOptimizer 后再运行一次 DCE。目标还可加入自己的机器窥孔 Pass，例如 AArch64 的目标专用简化；它们并不是本表中通用 Pass 的同义名。本节按源码核查模式，没有把全部架构专用模式逐一构造为运行样例。

## 9.11 本章小结

机器 SSA 优化围绕定义—用途、CFG、生命周期和目标能力展开。合并与复制、外提与下沉都可能合理，关键是语义保持和具体收益。本章实测覆盖尾代码阈值、单值 PHI、死链清除、局部及全局 CSE、LICM、下沉、栈着色和 If-Conversion；局部栈槽预布局及窥孔各子模式以静态源码边界说明。机器验证器证明的是输入/输出结构满足机器 IR 约束，不能替代所有输入的语义等价证明或硬件性能测量。

## LLVM 18 源码依据

- [llvm/lib/CodeGen/TargetPassConfig.cpp:1094](/opt/llvm-project/llvm/lib/CodeGen/TargetPassConfig.cpp:1094)：`addMachinePasses / addMachineSSAOptimization`。
- [llvm/lib/CodeGen/TailDuplicator.cpp:556](/opt/llvm-project/llvm/lib/CodeGen/TailDuplicator.cpp:556)：`shouldTailDuplicate`。
- [llvm/lib/CodeGen/OptimizePHIs.cpp:96](/opt/llvm-project/llvm/lib/CodeGen/OptimizePHIs.cpp:96)：`IsSingleValuePHICycle / IsDeadPHICycle`。
- [llvm/lib/CodeGen/StackColoring.cpp:475](/opt/llvm-project/llvm/lib/CodeGen/StackColoring.cpp:475)：`applyFirstUse / remapInstructions / runOnMachineFunction`。
- [llvm/lib/CodeGen/LocalStackSlotAllocation.cpp:112](/opt/llvm-project/llvm/lib/CodeGen/LocalStackSlotAllocation.cpp:112)：`LocalStackSlotPass::runOnMachineFunction`。
- [llvm/lib/CodeGen/DeadMachineInstructionElim.cpp:105](/opt/llvm-project/llvm/lib/CodeGen/DeadMachineInstructionElim.cpp:105)：`runOnMachineFunction / eliminateDeadMI`。
- [llvm/lib/CodeGen/EarlyIfConversion.cpp:199](/opt/llvm-project/llvm/lib/CodeGen/EarlyIfConversion.cpp:199)：`SSAIfConv::canSpeculateInstrs / canConvertIf`。
- [llvm/lib/CodeGen/MachineLICM.cpp:1006](/opt/llvm-project/llvm/lib/CodeGen/MachineLICM.cpp:1006)：`IsLICMCandidate / IsProfitableToHoist`。
- [llvm/lib/CodeGen/MachineCSE.cpp:938](/opt/llvm-project/llvm/lib/CodeGen/MachineCSE.cpp:938)：`runOnMachineFunction / isProfitableToCSE`。
- [llvm/lib/CodeGen/MachineSink.cpp:1043](/opt/llvm-project/llvm/lib/CodeGen/MachineSink.cpp:1043)：`isProfitableToSinkTo / SinkInstruction`。
- [llvm/lib/CodeGen/PeepholeOptimizer.cpp:689](/opt/llvm-project/llvm/lib/CodeGen/PeepholeOptimizer.cpp:689)：`optimizeSelect / optimizeCondBranch`。

- [llvm/lib/Target/X86/X86Subtarget.cpp:373](/opt/llvm-project/llvm/lib/Target/X86/X86Subtarget.cpp:373)：X86 EarlyIfConversion 的目标开关。
