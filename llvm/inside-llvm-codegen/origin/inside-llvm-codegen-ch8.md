# 第 8 章 指令调度

> 原文转写，未经技术修订。来源：[原 PDF](../pdf/inside-llvm-codegen.pdf)，PDF 第 160–216 页。书中基线为 LLVM 15（示例 15.0.1）。
> 保留原文观点、命令及排印错误；代码缩进按 PDF 坐标恢复。保留原图裁剪及页码标记，图表、公式或特殊字体可对照原 PDF 读取。

<!-- PDF page 160; printed page 147 -->

第 8 章 Chapter 8

指令调度

为什么需要指令调度？这和现代 CPU 架构相关。现代 CPU 一般都是流水线工作，例如在一个典型的流水线中单条指令的执行至少包括取指令、译码、执行、回写 4 个阶段。假设每个阶段的执行时间是一个时钟周期，功能单元串行执行，那么一条指令的执行时间就是 4 个周期，如图 8-1 所示。在 CPU 执行指令的 4 个时钟周期里，取指令单元只在第一个时钟周期里工作，且取指令单元工作时其余 3 个时钟周期都处于空闲状态，其他 3 个执行单元工作时也是如此，因此 CPU 总体执行效率很低。

![图 8-1 CPU 单条指令执行过程](assets/figures/p160-8-1.png)

**图 8-1 CPU 单条指令执行过程**

一条 CPU 流水线工作示意图如图 8-2 所示。引入流水线工作模式后，后 3 个工作单元除了在前 3 个时钟周期可以偷懒外，其余的时间都不能闲着。从第 2 个时钟周期开始，当译码单元在翻译指令 1 时，取指令单元要接着去取指令 2。从第 3 个时钟周期开始，当执行

<!-- PDF page 161; printed page 148 -->

单元执行指令 1 时，译码单元也不能闲着，要接着去翻译指令 2，而取指令单元要去取指令3。从第 5 个时钟周期开始，每个电路单元都会进入满荷负载工作状态，源源不断地执行一条条指令。

![图 8-2 一条 CPU 流水线工作示意图](assets/figures/p161-8-2.png)

**图 8-2 一条 CPU 流水线工作示意图**

引入流水线后，虽然每一条指令执行流程不变，还是需要 4 个时钟周期，但是从整条流水线的输出看，差不多平均每个时钟周期都能执行一条指令。原来执行一条指令需要 4个时钟周期，现在平均只需要 1 个时钟周期，CPU 性能提升了近 3 倍。

流水线的本质其实是用空间换时间。将每条指令分解为多步来执行，指令的每一步都由独立的电路来执行，让不同指令的各步并行操作，从而实现几条指令并行处理，加快程序的运行。

但利用流水线并行的前提是指令之间没有依赖关系，如果相邻的两条指令存在数据依赖，则下一条指令就需要等上一条指令回写完结果才能开始执行，这会使流水线停顿，从而影响程序的执行效率。指令之间的依赖通常分为结构依赖（也称为结构冲突，指不同指令使用相同的硬件资源导致流水线停顿）、数据依赖（也称为数据冲突，指的是指令间的数据有依赖）、控制依赖（也称为控制冲突，指的是由跳转指令确定下一条要执行的指令）。在LLVM 中常见依赖关系（属性）有 3 种。

1）data（数据依赖）：如果下一条指令的操作数为前一条指令的输出结果，那么这两条指令就存在数据依赖。

2）chain（链依赖）：当前指令调度时不能被移到所依赖的指令之前。通常处于相同内存的访存操作指令序列可以用这种依赖来固定访存操作的顺序。

3）glue（铰链依赖）：指令序列在调度时不能被分开。

<!-- PDF page 162; printed page 149 -->

注 从直观上看，本章仅讨论了数据依赖，实际上结构依赖在出现指令时延时有所涉及，

意

而控制依赖在进行编译优化时有所涉及。

指令调度的作用就是通过调整指令的顺序，减少指令间依赖对流水线的影响，使得程序在拥有指令流水线的中央处理器上能够高效运行。

根据调度发生的阶段可以将指令调度分为动态调度和静态调度。本书仅讨论静态调度。

1）动态调度：发生在运行时，需要相应的硬件支持。处理器会在运行时对指令序列进行重排，并乱序地发送到处理器功能单元，以便处理器能够同时处理更多的指令。

2）静态调度：在编译阶段对指令重排，消除指令间的依赖，提升指令并行度，从而利用流水线的空闲周期执行没有依赖冲突的其他指令。

根据指令调度的工作范围，通常可以将指令调度分为 3 类。

1）局部调度：针对单基本块进行调度。最典型的算法是 List Scheduling 算法（也称为表调度），这一类算法采用不同的启发式方法选择合适的指令，比如考虑停滞周期（stall cycles）○一、指令时延、寄存器压力等。论文“ A comparision of List Scheduling Heuristics in LLVM Targeting POWER8”○二将影响调度算法的启发式因素细分为 24 种，我们将在后文介绍具体的算法时详细描述算法所涉及的启发式因素。

2）全局调度：跨多个基本块进行调度。通常有 Trace Scheduling（识别频率高的执行路径，并根据路径调度多个基本块）、Superblock Scheduling（通常是选择一些具有单入口、多出口属性的基本块进行调度）、Hyperblock Scheduling（使用 If-Conversion 算法移除条件分支，获得超大基本块后进行调度）等调度算法。

3）循环调度：针对循环体内的基本块进行指令调度优化，从而提升循环执行的并行性能，这主要是针对软流水的优化。

本书讨论的指令调度算法主要是局部调度和循环调度。其中局部调度适用于所有的后端，而循环调度目前仅适用于 ARM、PPC 和 Hexagon 后端。

## 8.1 LLVM 指令调度

指令调度和寄存器分配会相互影响，所以 LLVM 实现了基于 MIR 的寄存器分配前指令调度和寄存器分配后指令调度，同时还提供了基于 SelectionDAG（DAG IR）的调度，并未针对 FastISel、GlobalISel 提供了指令调度算法。本节首先对 LLVM 中实现的调度算法（也称为调度器）进行介绍，然后介绍指令调度中使用的拓扑排序算法。

○一 本书统一翻译为停滞周期，但该词也不算特别贴切，所以笔者这里简单解释其含义：它是指在指令执行

过程中，由于存在依赖冲突、结构冲突等导致的 CPU 流水线停顿。

○二 在线论文地址为 https://lup.lub.lu.se/luur/download?func=downloadFile&recordOld=9079542&fileOld=9079543。

<!-- PDF page 163; printed page 150 -->

### 8.1.1 指令调度算法

LLVM 实现了多种指令调度的算法，基本的思路都是构建指令间的依赖图，基于依赖图进行拓扑排序。调度算法可以在 LLVM 后端的不同阶段实施。在图 8-3 中的①、②、③阶段都可以配置调度算法。

![图 8-3 调度算法实施阶段](assets/figures/p163-8-3.png)

**图 8-3 调度算法实施阶段**

为什么要在多个阶段配置调度算法？根本原因是指令调度和寄存器分配（第 10 章介绍）会相互影响。指令调度会调整寄存器的位置，影响寄存器的生命周期，从而影响寄存器分配；同理，寄存器分配选择物理寄存器会影响指令依赖，从而影响指令调度。所以 LLVM设计了 3 个可以配置调度算法的阶段，具体如下。

阶段①：基于 SelectionDAG 进行调度，Linearize、Fast、BURR List、Source List、Hybrid List 这些调度算法都在此阶段完成指令调度优化。

阶段②：基于寄存器分配前的 MIR 进行调度，调度算法包括 Pre-RA-MISched。这个阶段的指令调度会着重考虑指令顺序对寄存器分配压力的影响。另外，LLVM 的循环调度SMS（Swing Modulo Scheduling，摇摆模调度）也处于这个阶段。

阶段③：基于寄存器分配后的 MIR 进行调度，调度算法包括 Post-RA-TDList 和 Post- RA-MISched。

阶段③寄存器分配后的调度算法主要考虑影响指令并行性能的启发式因素，而阶段①、

②寄存器分配前的调度算法除了考虑并行性能之外，还要综合考虑寄存器分配压力等多种启发式因素。

虽然这三个阶段配置的调度算法实现略有不同（原因是输入不同，如图 8-3 所示），但算法原理相似，有很多代码可以复用。针对不同阶段和具体算法，LLVM 实现的调度类UML 如图 8-4 所示。

![图 8-4 调度类的 UML](assets/figures/p163-8-4.png)

**图 8-4 调度类的 UML**

<!-- PDF page 164; printed page 151 -->

这些不同调度算法对应的实现作用于不同的 IR 输入，如表 8-1 所示。

**表 8-1 调度算法在 LLVM 中对应的实现**

调度器 基于 IR 输入 实现类 和寄存器分配的关系

Linearize SelectionDAG ScheduleDAGLinearize pre-RA（寄存器分配前，下同）

Fast SelectionDAG ScheduleDAGFast pre-RA

BURR List SelectionDAG ScheduleDAGRRList pre-RA

Source List SelectionDAG ScheduleDAGRRList pre-RA

Hybrid List SelectionDAG ScheduleDAGRRList pre-RA

Pre-RA-MISched MachineInstr ScheduleDAGMILive pre-RA

SMS MachineInstr SwingSchedulerDAG pre-RA

Post-RA-MISched MachineInstr ScheduleDAGMI post-RA（寄存器分配后，下同）

Post-RA-TDList MachineInstr SchedulePostRATDList post-RA

这些调度算法将在后续章节一一展开介绍。

### 8.1.2 拓扑排序算法

指令调度的算法都是以拓扑排序为基础，每条指令按照依赖关系构成了 DAG 的节点，因此本节简要介绍一下拓扑排序算法。

对于一个 DAG，记为 G<E, V>，拓扑排序是将 G 中所有的顶点排成一个线性序列，对于图中任意一对顶点 u 和 v(u, v ∈ V)，如果边 <u, v> ∈ E(G)，则 u 出现在 v 之前。这样的线性序列被称为满足拓扑次序的序列，寻找线性序列的过程称为拓扑排序。拓扑排序的实现常常需要借助队列，步骤大致如下。

1）遍历图中所有的节点，将入度为 0 的节点放入队列。

2）从队列中选出一个节点，并消费该节点（从图 G 中删除节点），之后更新节点所指向的相邻节点的入度（减 1），如果相邻节点的入度为 0，则将该相邻节点放入队列。

3）重复以上步骤，直到队列为空。

**图 8-5 展示了一个拓扑排序的完整过程。假设原始 DAG 如图 8-5a 所示，因为其中只**

有 a 的入度为 0，所以 a 会被最先消费并从 DAG 中删除，然后更新相邻节点 b、c、d 的入度，得到结果如图 8-5b 所示。重复该过程，依次消费节点 c、b、f、d，分别如图 8-5c～图 8-5f 所示。整个图拓扑排序的最终结果为 acbfde。

指令调度算法会在拓扑排序的基础上进行增强，主要是在拓扑排序的第二步通过多种启发式因素计算出队列中调度优先级最高的节点，然后将该节点作为调度结果。

<!-- PDF page 165; printed page 152 -->

![图 8-5 拓扑排序过程](assets/figures/p165-8-5.png)

**图 8-5 拓扑排序过程**

## 8.2 Linearize 调度器

Linearize 调度器是 LLVM 中实现最简单的调度器，后续章节介绍的一些调度器都是基于它来增强实现。Linearize 调度器是以基本块为调度单元，对 SelectionDAG 的 SDNode 做了一次自底向上的拓扑排序，生成 SDNode 的序列。调度算法的实现步骤如下。

1) 构造 SDNode 依赖图。

2) 根据依赖图，按照深度优先遍历的方法对依赖图进行拓扑排序，依赖图中具有 glue属性的节点序列会被当作一个整体进行调度，从而保证具有 glue 属性的节点序列不会被拆开。

3) 重复以上步骤，直到所有节点调度完成。

Linearize 调度器实现非常简单，没有考虑任何启发式因素。在 LLVM 中通过编译选项 -pre-RA-sched=linearize 来选择使用 Linearize 调度器。下面通过一个示例演示 Linearize的实现过程，假设有一段经过指令选择后的示例代码如代码清单 8-1 所示。

**代码清单 8-1 调度前的 SelectionDAG 示例代码**

```text
t0：ch，glue = EntryToken
t12：i64，ch = CopyFromReg t0，Register：i64 %24
t2：i64，ch = CopyFromReg t0，Register：i64 %35
t5：i64，i32 = SAR64ri exact t2，TargetConstant：i8<3>
t8：i64 = MOV32ri64 TargetConstant：i64<1>
t59：i64，i32 = SUB64ri8 t5，TargetConstant：i64<2>
t67：ch，glue = CopyToReg t0，Register：i32 $eflags，t59：1
t62：i64 = CMOV64rr t8，t5，TargetConstant：i8<3>，t67：1
t46：i64，i32 = ADD64rr t62，t5
t49：i64，i32 = SUB64rr，t46，t12
t66：ch，glue = CopyToReg t0，Register：i32 $eflags，t49：1
t52：i64 = CMOV64rr t46，t12，TargetConstant：i8<7>，t66：1
t65：ch，glue = CopyToReg t0，Register：i32 $eflags，t46：1
t48：i64 = CMOV64rr t52，t12，TargetConstant：i8<2>，t65：1
t7：ch = CopyToReg t0，Register：i64 %36，t5
t20：ch = CopyToReg t0，Register：i64 %37，t48
t21：i64 = SUBREG_TO_REG，TargetConstant：i64<0>，MOV32r0：i32，i32，TargetConstant：i32<6>
```

<!-- PDF page 166; printed page 153 -->

```text
t25：ch = CopyToReg t0，Register：i64 %137，t21
t27：ch = TokenFactor t7，t20，t25
t43：i32 = TEST64rr t48，t48
t64：ch，glue = CopyToReg t27，Register：i32 $eflags，t43
t45：ch = JCC_1 BasicBlock：ch<_ZNst12_Vector_allocate.i.i.i 0x55556eb245c0>，
    TargetConstant：i8<4>，t64，t64：1
t30：ch = JMP_1 BasicBlock：ch<_ZNst16allocator_exit.i.i.i.i 0x55556eb244c0>，t45
```

该代码片段来自一个复杂的工程，下面以此为例来看看经过 Linearize 后生成的SDNode 序列是什么样子。

### 8.2.1 构造依赖图

为 SelectionDAG 中的 SDNode 构造依赖图，并计算各个 SDNode 的入度。其过程为自上向下依次遍历 SelectionDAG 的指令，根据指令之间的依赖关系在依赖图中添加相关依赖，并计算入度。

**图 8-6 展示了基于代码清单 8-1 所构造的依赖图。以指令 t49 ：i64, i32 = SUB64rr, t46,**

t12 为例，它的操作数分别为 t46、t12，且都是数据依赖关系，因此需要为 t49 和 t46、t12建立数据依赖，并且 t49 的操作数 0 指向 t46，t49 的操作数 1 指向 t12，同时分别增加 t46、t12 的入度。

在基本块遍历完成时，会增加一个虚拟的 Graph Root 节点，让 Graph Root 指向基本块的最后一条指令，Graph Root 不是基本块的指令节点，只是用来标记这个基本块的退出位置，自底向上地从 Graph Root 开始调度指令。

为了展示不同的依赖关系，我们使用蓝色虚线表示 chain 依赖边，用蓝色实线表示 glue依赖边，黑色实线表示数据依赖边。最后得到的依赖图如图 8-6 所示。

注 这和 LLVM 工具的输出略有不同，主要是为满足印刷排版所需进行了细微的调整。

意

另外，从 LLVM 工具输出的依赖图中还可能包括 EntryToken 节点，它是一个特殊

节点，但不影响调度顺序，为了简化依赖图，故未在图中体现。EntryToken 节点的

相关内容可以参考第 7 章。

### 8.2.2 对依赖图进行调度

第 1 步，对普通节点进行调度，并按照深度优先对依赖图进行拓扑排序。

从 Graph Root 节点出发，自底向上按深度优先进行拓扑排序。因为 Graph Root 是虚拟节点，它不依赖任何节点，所以从 Graph Root 开始调度。t30 依赖 Graph Root，故 t30 是第一个被调度的节点，将调度结果存入一个数组（这里使用 Sequence 表示）中，同时将 t30从图 8-6 所示依赖图中移除，并更新 t30 依赖节点的入度，即将 t45 的入度减 1。此时，t30调度后的局部依赖图如图 8-7 所示。

<!-- PDF page 167; printed page 154 -->

![图 8-6 SelectionDAG 基本块依赖图](assets/figures/p167-8-6.png)

**图 8-6 SelectionDAG 基本块依赖图**

此时，Sequence 中的调度结果为 t30。

第 2 步，处理具有 glue 属性的节点序列。

接下来需要调度 t45，但是 t45 和 t64 具有 glue 属性。此时，t64 仅被 t45 依赖，因为具有 glue 属性的节点序列必须作为整体被调度，所以将 t45、t64 的调度结果放入 Sequence 数

<!-- PDF page 168; printed page 155 -->

组。从右向左遍历 t64 的操作数，首先是处理节点 t43，并将 t43 的入度设置为 0，然后处理节点 t27，得到的局部依赖图如图 8-8 所示。

![图 8-7 t30 调度后的局部依赖图](assets/figures/p168-8-7.png)

**图 8-7 t30 调度后的局部依赖图**

![图 8-8 t45、t64 调度后的局部依赖图](assets/figures/p168-8-8.png)

**图 8-8 t45、t64 调度后的局部依赖图**

此时，Sequence 中的调度结果为 t30、t45、t64。

重复第 1 步和第 2 步，直到所有节点完成调度。最后得到的调度结果为：t30，t45，t64，t43，t27，t25，t21，t20，t48，t65，t52，t66，t49，t12，t46，t62，t67，t59，t8，t7，t5，t2。

因为 Linearize 算法直接对 SDNode 进行调度，所以得到的结果即为指令执行顺序。我们来比较一下使用 Linearize 调度前后的指令执行顺序，如表 8-2 所示，主要的变化是 t7 和t12 的执行顺序。Linearize 的调度中并未引入任何启发式因素，因此调度结果对执行性能的影响也是不确定的，但是可以看到 t7 放在了 t5 的后面、t12 放在了 t49 的前面。结果显示，t7、t12 和它们依赖者或者被依赖者距离更近。

<!-- PDF page 169; printed page 156 -->

**表 8-2 使用 Linearize 算法调度前后的效果比较**

调度前 调度后

t0：ch，glue = EntryToken t0：ch，glue = EntryToken

t12：i64，ch = CopyFromReg t0，Register：i64 %24 t2：i64，ch = CopyFromReg t0，Register：i64 %35

t2：i64，ch = CopyFromReg t0，Register：i64 %35 t5 ：i64，i32 = SAR64ri exact t2，TargetConstant ：

t5 ：i64，i32 = SAR64ri exact t2，TargetConstant ： i8<3>

i8<3> t7：ch = CopyToReg t0，Register：i64 %36，t5

t8：i64 = MOV32ri64 TargetConstant：i64<1> t8：i64 = MOV32ri64 TargetConstant：i64<1>

t59 ：i64，i32 = SUB64ri8 t5，TargetConstant ： t59 ：i64，i32 = SUB64ri8 t5，TargetConstant ：

i64<2> i64<2>

t67：ch，glue = CopyToReg t0，Register：i32 $eflags， t67：ch，glue = CopyToReg t0，Register：i32 $eflags，

t59：1 t59：1

t62 ：i64 = CMOV64rr t8，t5，TargetConstant ： t62 ：i64 = CMOV64rr t8，t5，TargetConstant ：

i8<3>，t67：1 i8<3>，t67：1

t46：i64，i32 = ADD64rr t62，t5 t46：i64，i32 = ADD64rr t62，t5

t49：i64，i32 = SUB64rr，t46，t12 t12：i64，ch = CopyFromReg t0，Register：i64 %24

t66：ch，glue = CopyToReg t0，Register：i32 $eflags， t49：i64，i32 = SUB64rr，t46，t12

t49：1 t66：ch，glue = CopyToReg t0，Register：i32 $eflags，

t52 ：i64 = CMOV64rr t46，t12，TargetConstant ： t49：1

i8<7>，t66：1 t52 ：i64 = CMOV64rr t46，t12，TargetConstant ：

t65：ch，glue = CopyToReg t0，Register：i32 $eflags， i8<7>，t66：1

t46：1 t65：ch，glue = CopyToReg t0，Register：i32 $eflags，

t48 ：i64 = CMOV64rr t52，t12，TargetConstant ： t46：1

i8<2>，t65：1 t48 ：i64 = CMOV64rr t52，t12，TargetConstant ：

t7：ch = CopyToReg t0，Register：i64 %36，t5 i8<2>，t65：1

t20：ch = CopyToReg t0，Register：i64 %37，t48 t20：ch = CopyToReg t0，Register：i64 %37，t48

t21 ：i64 = SUBREG_TO_REG，TargetConstant ： t21 ：i64 = SUBREG_TO_REG，TargetConstant ：

i64<0>，MOV32r0：i32，i32，TargetConstant：i32<6> i64<0>，MOV32r0：i32，i32，TargetConstant：i32<6>

t25：ch = CopyToReg t0，Register：i64 %137，t21 t25：ch = CopyToReg t0，Register：i64 %137，t21

t27：ch = TokenFactor t7，t20，t25 t27：ch = TokenFactor t7，t20，t25

t43：i32 = TEST64rr t48，t48 t43：i32 = TEST64rr t48，t48

t64：ch，glue = CopyToReg t27，Register：i32 $eflags， t64 ：ch，glue = CopyToReg t27，Register ：i32

t43 $eflags，t43

t45 ：ch = JCC_1 BasicBlock ：ch<_ZNst12_Vector_ t45：ch = JCC_1 BasicBlock：ch<_ZNst12_Vector_

allocate.i.i.i 0x55556eb245c0>，TargetConstant ：i8<4>， allocate.i.i.i 0x55556eb245c0>，TargetConstant ：

t64，t64：1 i8<4>，t64，t64：1

t30 ：ch = JMP_1 BasicBlock ：ch<_ZNst16allocator_ t30：ch = JMP_1 BasicBlock：ch<_ZNst16allocator_

exit.i.i.i.i 0x55556eb244c0>，t45 exit.i.i.i.i 0x55556eb244c0>，t45

## 8.3 Fast 调度器

Fast 调度器和 Linearize 调度器一样都遵循自底向上的深度优先拓扑排序规则。和Linearize 调度器相比，Fast 调度器在实现上有 3 点不同。

1）Fast 调度器用 SUnit 封装了 SDNode，并以 SUnit 为节点来构造指令的依赖图。

2）Fast 调度器在构建依赖图前会做一些优化，为地址相近的内存操作的 SDNode 序列

<!-- PDF page 170; printed page 157 -->

设置 glue 属性，以提升数据局部性。

3）Fast 调度器对物理寄存器依赖场景做了特殊处理，笔者理解这是为了减小该物理寄存器的活跃区间范围。

LLVM 通过编译选项 -pre-RA-sched=fast 来使用 Fast 调度器，调度算法实现放在 Schedule- DAGFast 类。

### 8.3.1 Fast 调度器实现

从 Fast 调度器开始，本章后面介绍的局部调度器都会用 SUnit 来封装 SDNode 或者MIR。SUnit 类中有两个字段，分别是 SDNode 指针类型的 Node 和 MachineInstr 指针类型的 Instr，分别保存对应 SelectionDAG 形式的 SDNode 节点和 MIR 节点。例如，Fast 调度器中的 SUnit 是基于 SDNode 构造的，而 8.7 节介绍的算法的 SUnit 是基于 MIR 构造的。Fast 调度器算法的实现步骤如下。

1）以 SUnit 为节点构造依赖图，SUnit 由两类 SDNode 构成。第一类是具有 glue 属性的 SDNode 序列，这些 SDNode 将被合并成一个 SUnit ；第二类是没有 glue 属性的 SDNode，如 果 SDNode 包 含 机 器 操 作 数， 则 为 该 SDNode 生 成 一 个 SUnit。 另 外，SUnit 引 入 了NumSuccsLeft 字段来描述其入度。

2）基于依赖图进行调度。

3）重复以上步骤，直到所有节点调度完成。

注 为什么 LLVM 用 SUnit 封装 SDNode 或者 MIR ？笔者的理解是将影响指令调度的

意

启发式因素提取出来，封装在 SUnit 中，从而避免在 SDNode 和 MIR 中重复定义和

实现。

下面依然以代码清单 8-1 的 SelectionDAG 为例，Fast 调度器构造的 SUnit 依赖图如

**图 8-9 所示。示例中的 SUnit 标识了其对应的 SDNode 节点，比如 SUnit[6] 对应的是 t2。**

SUnit 的依赖边有两种类型：蓝色虚线的边是 Barrier 类型（SDNode 之间的 chain 依赖关系就是 Barrier 类型），黑色实线的边是 data 依赖类型。和 SDNode 依赖图相比，SUnit 依赖图的节点数量略有减少，主要是它把具有 glue 属性的 SDNode 序列合成为一个 SUnit 节点，比如图 8-9 中 SUnit[3] 节点表示具有 glue 属性的 t48 和 t65 的序列。

建立依赖图后，Fast 调度器从 Graph Root 出发，自底向上地对依赖图执行拓扑排序。当SUnit 节点的 NumSuccsLeft 为 0 时，表明该节点的所有后继节点都已调度完成，可以添加该节点到待调度队列。Fast 调度器与后面介绍的更复杂的调度器都会使用 AvailableQueue 队列。在 Fast 调度器中 AvailableQueue 是普通的队列，每个 SUnit 的优先级都是一样的，但在后面介绍的调度器中它是一个优先级队列，会根据启发式因素来决定队列中节点的优先级。

因为 Fast 调度器在调度过程中对物理寄存器的依赖场景进行了特殊处理，所以下面先介绍物理寄存器依赖场景的相关内容。

<!-- PDF page 171; printed page 158 -->

![图 8-9 Fast 调度器算法构造的 SUnit 依赖图](assets/figures/p171-8-9.png)

**图 8-9 Fast 调度器算法构造的 SUnit 依赖图**

### 8.3.2 物理寄存器依赖场景的处理

所谓物理寄存器依赖场景，是指令之间存在物理寄存器的依赖关系，如图 8-10 所示。物理寄存器 rx 在指令③中开始被赋值，在指令①中被使用，这就是一个物理寄存器依赖的场景。调度器使用 LiveRegDefs 和 LiveRegGens 数组来分别记录这个序列的开始与结束指令的索引。这两个数组的长度都为 TRI->getNumRegs()，其中 TRI->getNumRegs() 为当前目标后端物理寄存器的数量。存放物理寄存器指令的索引数组结构如图 8-11 所示。

![图 8-10 物理寄存器依赖示例](assets/figures/p171-8-10.png)

**图 8-10 物理寄存器依赖示例**

<!-- PDF page 172; printed page 159 -->

![图 8-11 存放物理寄存器指令的索引数组结构](assets/figures/p172-8-11.png)

**图 8-11 存放物理寄存器指令的索引数组结构**

在图 8-10 中，LiveRegDefs[rx] 存放指令③的索引，LiveRefGens[rx] 存放指令①的索引。

对于物理寄存器依赖导致其活跃区间太长的情况，Fast 调度器有两种处理方法可将活跃区间拆开，从而提升寄存器分配的性能。这两种方法分别是 CopyAndMoveSuccessors 和InsertCopiesAndMoveSuccs。

T CopyAndMoveSuccessors：通过插入重复指令的方式来缩短活跃区间，这和第 10 章

介绍的重新物化概念一致。

T InsertCopiesAndMoveSuccs：通过插入 COPY 指令的方式来缩短活跃区间。

1. CopyAndMoveSuccessors

物理寄存器依赖示例如图 8-12 所示，指令 LiveRegGens[reg]、CurSU、LiveRegDefs[reg]对物理寄存器 reg 存在依赖。假设当前指令调度已经进行到 CurSU 节点，则表明 LiveReg- Gens[reg] 和 S2 节点已经被调度过，其余的节点还未被调度。下面以图 8-12 为例来描述CopyAndMoveSuccessors 的大体步骤。

![图 8-12 物理寄存器依赖示例](assets/figures/p172-8-12.png)

**图 8-12 物理寄存器依赖示例**

第 1 步：把 LiveRegDefs[reg] 节点复制一份存放到新的节点，新的节点记为 clone of LRDef，并将 LiveRegDefs[reg] 节点的前驱节点 P1、P2 设置为 clone of LRDef 节点的前驱节点，如图 8-13 所示。

第 2 步：将 LiveRegDefs[reg] 的后继节点中已经调度过的节点指向 clone of LRDef 节点，这里将 S2 指向 clone of LRDef。将 CurSU 设置为 clone of LRDef 的前驱节点，其依赖

<!-- PDF page 173; printed page 160 -->

类型为 SDep::Artificial，也就是说要先调度 clone of LRDef，才能调度 CurSU，如图 8-14所示。这样就把物理寄存器 reg 的活跃区间从 [LiveRegDefs[reg], LiveRegGens[reg]] 分解成了两段：[clone of LRDef, LiveRegGens[reg]] 以及 [LiveRegDefs[reg], CurSU]。

![图 8-13 复制新节点并设置其前驱节点](assets/figures/p173-8-13.png)

**图 8-13 复制新节点并设置其前驱节点**

![图 8-14 将 CurSU 设置为 clone of LRDef 的前驱节点](assets/figures/p173-8-14.png)

**图 8-14 将 CurSU 设置为 clone of LRDef 的前驱节点**

2. InsertCopiesAndMoveSuccs

依然以图 8-12 为例，描述一下 InsertCopiesAndMoveSuccs 的大致步骤。

第 1 步：插入 CopyToSU 和 CopyFromSU 两个 SUnit 节点。CopyFromSU 就是将 Live- Reg-Defs[reg] 节点的 reg 赋给新的物理寄存器，比如 reg1。CopyToSU 将 CopyFromSU 节点的 reg1 重新赋给 reg，将 CopyFromSU 节点的前驱节点设置为 LiveRegDefs[reg] 节点，把 LiveRegDefs[reg] 的后继节点中已经调度的节点 S2 指向 CopyToSU 节点，如图 8-15所示。

第 2 步：CopyToSU 增加对 CopyFromSU 节点的数据依赖边。将 CopyToSU 指向 CurSU，依赖边类型为 SDep::Artificial，将 CurSU 节点的前驱节点设置为 CopyFromSU，其依赖类型

<!-- PDF page 174; printed page 161 -->

为 SDep::Artificial。也就是说先调度 CopyToSU，然后是 CurSU，最后才是 CopyFromSU，即 CopyToSU 增加了对 CopyFromSU 节点的数据依赖边，如图 8-16 所示。这样就把节点LiveRegGens[reg]、CurSU、LiveRegDefs[reg] 的物理寄存器 reg 的活跃区间 [LiveRegDefs[reg], LiveRegGens[reg]] 分解成了 [CopyToSU, LiveRegGens[reg]] 以及 [LiveRegDefs[reg], CurSU]这两段。但该方法插入了两条新的指令 CopyFromSU 和 CopyToSU，会带来额外的开销。

![图 8-15 S2 指向 CopyToSU 节点](assets/figures/p174-8-15.png)

**图 8-15 S2 指向 CopyToSU 节点**

![图 8-16 CopyToSU 增加了对 CopyFromSU 节点的数据依赖边](assets/figures/p174-8-16.png)

**图 8-16 CopyToSU 增加了对 CopyFromSU 节点的数据依赖边**

CopyAndMoveSuccessors 方法会复制 LiveRegDefs[rx] 指令，而 InsertCopiesAndMove- Succs 方法则会插入一对 copy 指令。笔者理解，CopyAndMoveSuccessors 方法会比 Insert- CopiesAndMoveSuccs 方 法 生 成 更 少 的 指 令 数， 所 以 LLVM 会 优 先 使 用 CopyAndMove- Successors 来处理物理寄存器依赖，但在一些特殊场景（比如涉及的指令具有 glue 属性）中会选择 InsertCopiesAndMoveSuccs 方法。

<!-- PDF page 175; printed page 162 -->

### 8.3.3 示例分析

依然以代码清单 8-1 为例说明 Fast 调度器如何调度指令序列。Fast 调度器使用了 3 个辅助数据结构，分别是 AvailableQueue、NotReady 和 Sequence。Sequence 数组存放调度的指令结果。队列 AvailableQueue 存放入度为 0 且可以被调度的指令序列，它们遵循先进先出的原则。NotReady 数组用来存放因为物理寄存器依赖被干扰暂时无法被调度的 SUnit 节点，比如图 8-12 中的 CurSU。NotReady 序列必须等到 AvailableQueue 中元素为 0 后才会被处理，处理方法就是 8.3.2 节介绍的 CopyAndMoveSuccessors 或者 InsertCopiesAndMoveSuccs方法。

为基本块的 SDNode 构建对应的 SUnit 的依赖图，结果如图 8-9 所示。

从 Graph Root 开始，此时 NotReady 和 Sequence 序列为空。选择入度为 0 的 SU[0]○一节点存入 AvailableQueue 中，从 Graph Root 开始调度后，Fast 调度器的运行结果如表 8-3所示。

**表 8-3 从 Graph Root 开始调度后 Fast 调度器的运行结果**

调度器数据结构 数据结构中的元素

AvailableQueue SU[0]

NotReady 空

Sequence 空

从 AvailableQueue 中选择可调度节点 SU[0] 存入 Sequence，将 SU[0] 的前驱节点 SU[1]的入度设置为 0，将 SU[1] 存入 AvailableQueue 中，Fast 调度器的运行结果如表 8-4 所示。

**表 8-4 调度 SU[0] 后 Fast 调度器的运行结果**

调度器数据结构 数据结构中的元素

AvailableQueue SU[1]

NotReady 空

Sequence SU[0]

按照拓扑排序的方式依次调度 SUnit 依赖图，直到出现 SU[3]。SU[3] 入度为 0，存入 Sequence 中，并将 SU[3] 的前驱节点 SU[11] 的入度减 1，变为 0 后存入 AvailableQueue中。SU[3] 的前驱节点 SU[4] 定义了 reg 为 28 的物理寄存器（为 EFLAG，如图 8-9 所示，SU[3]、SU[4] 分别对应 t48&t65、t46 节点）。SU[3] 使用了物理寄存器 EFLAG，此时将LiveRegDefs[28] 设置为 SU[4]。调度 SU[3] 后 Fast 调度器的运行结果如表 8-5 所示。

○一 为简便描述起见，后续正文和表格中的 SUnit[…] 形式的表述均简写为 SU[…]，例如 SUnit[0] 将简写为

SU[0] 形式。

<!-- PDF page 176; printed page 163 -->

**表 8-5 调度 SU[3] 后 Fast 调度器的运行结果**

调度器数据结构 数据结构中的元素

AvailableQueue SU[17],SU[11]

NotReady 空

Sequence SU[0],SU[1],SU[2],SU[13],SU[14],SU[15],SU[16],SU[3]

LiveRegDefs[28] SU[4]

从 AvailableQueue 中选择 SU[11]。SU[11] 的前驱节点 SU[12] 定义了 EFLAG 且 SU[12]不是 LiveRegDefs[28] 的值（其值为 SU[4]，参见表 8-5），故存在对物理寄存器 EFLAG 的依赖，此时将 SU[11] 存入 NotReady 队列中。调度 SU[11] 后 Fast 调度器的运行结果如表 8-6所示。

**表 8-6 调度 SU[11] 后 Fast 调度器的运行情况**

调度器数据结构 数据结构中的元素

AvailableQueue SU[17]

NotReady SU[11]

Sequence SU[0],SU[1],SU[2],SU[13],SU[14],SU[15],SU[16],SU[3]

LiveRegDefs[28] SU[4]

继续调度 AvailableQueue 中的元素，直到其中的元素为空。此时，将 SU[11] 从 NotReady序列存入 AvailableQueue 中。调度 SU[17] 后，Fast 调度器的运行结果如表 8-7 所示。

**表 8-7 调度 SU[17] 后 Fast 调度器的运行结果**

调度器数据结构 数据结构中的元素

AvailableQueue SU[11]

NotReady 空

Sequence SU[0],SU[1],SU[2],SU[13],SU[14],SU[15],SU[16],SU[3],SU[17]

LiveRegDefs[28] SU[4]

此时 SU[11]、SU[4]、SU[3] 便构成了对物理寄存器 EFLAG 的依赖，采用 CopyAnd- MoveSuccessors 方 法 来 处 理。 将 SU[4] 复 制 出 一 份， 得 到 SU[4]-clone， 并 利 用 SU[11]、SU[12]、SU[3]、SU[4] 构造如图 8-17 所示的局部依赖图。SU[4]-clone 的前驱节点继承自 SU[4]，即 SU[5]、SU[7]，因此将 SU[5]、SU[7] 的入度加 1，并将 SU[4]-clone 设置为SU[11] 的后继节点。此时，SU[11] 的入度加 1，并将 LiveRegDefs[28] 更新为 SU[4]-clone。处理物理寄存器依赖后，Fast 调度器的运行结果如表 8-8 所示。

<!-- PDF page 177; printed page 164 -->

![图 8-17 对 SU[4] 进行复制后的依赖图](assets/figures/p177-8-17.png)

**图 8-17 对 SU[4] 进行复制后的依赖图**

**表 8-8 处理物理寄存器依赖后 Fast 调度器的运行结果**

调度器数据结构 数据结构中的元素

AvailableQueue SU[4]-clone

NotReady SU[11]

Sequence SU[0],SU[1],SU[2],SU[13],SU[14],SU[15],SU[16],SU[3],SU[17]

LiveRegDefs[28] SU[4]-clone

继续按照深度优先的拓扑排序进行调度，直到 AvailableQueue、NotReady 序列都为空，最终结果存储在 Sequence 序列中，所有 SU 节点调度完成后，Fast 调度器的运行结果如表 8-9所示。

**表 8-9 所有 SU 节点调度完成后 Fast 调度器的运行结果**

调度器数据结构 数据结构中的元素

AvailableQueue 空

NotReady 空

Sequence SU[0],SU[1],SU[2],SU[13],SU[14],SU[15],SU[16],SU[3],SU[17],SU[4]-clone,SU[11],

SU[12],SU[10],SU[4],SU[7],SU[8],SU[5],SU[6],SU[9],

LiveRegDefs[28] 空

<!-- PDF page 178; printed page 165 -->

把 SUnit 节点转换成 SDNode 节点后，调度前后的结果如表 8-10 所示。除了指令顺序外，最显著的差异就是调度后生成了一个新的节点 t46。物理寄存器 EFLAG 的活跃区间由[t46, t48] 被拆解成了 [t46, t52] 以及 [t46, t48]。

**表 8-10 使用 Fast 调度器调度前后的效果比较**

调度前 调度后

t0：ch，glue = EntryToken t0：ch，glue = EntryToken

t12：i64，ch = CopyFromReg t0，Register：i64 %24 t8：i64 = MOV32ri64 TargetConstant：i64<1>

t2：i64，ch = CopyFromReg t0，Register：i64 %35 t2：i64，ch = CopyFromReg t0，Register：i64 %35

t5 ：i64，i32 = SAR64ri exact t2，TargetConstant ： t5：i64，i32 = SAR64ri exact t2，TargetConstant：i8<3>

i8<3> t59 ：i64，i32 = SUB64ri8 t5，TargetConstant ：

t8：i64 = MOV32ri64 TargetConstant：i64<1> i64<2>

t59 ：i64，i32 = SUB64ri8 t5，TargetConstant ： t67：ch，glue = CopyToReg t0，Register：i32 $eflags，

i64<2> t59：1

t67：ch，glue = CopyToReg t0，Register：i32 $eflags， t62 ：i64 = CMOV64rr t8，t5，TargetConstant ：

t59：1 i8<3>，t67：1

t62 ：i64 = CMOV64rr t8，t5，TargetConstant ： t46：i64，i32 = ADD64rr t62，t5

i8<3>，t67：1 t12：i64，ch = CopyFromReg t0，Register：i64 %24

t46：i64，i32 = ADD64rr t62，t5 t49：i64，i32 = SUB64rr，t46，t12

t49：i64，i32 = SUB64rr，t46，t12 t66：ch，glue = CopyToReg t0，Register：i32 $eflags，

t66：ch，glue = CopyToReg t0，Register：i32 $eflags， t49：1

t49：1 t52 ：i64 = CMOV64rr t46，t12，TargetConstant ：

t52 ：i64 = CMOV64rr t46，t12，TargetConstant ： i8<7>，t66：1

i8<7>，t66：1 t46：i64，i32 = ADD64rr t62，t5

t65：ch，glue = CopyToReg t0，Register：i32 $eflags， t7：ch = CopyToReg t0，Register：i64 %36，t5

t46：1 t65：ch，glue = CopyToReg t0，Register：i32 $eflags，

t48 ：i64 = CMOV64rr t52，t12，TargetConstant ： t46：1

i8<2>，t65：1 t48 ：i64 = CMOV64rr t52，t12，TargetConstant ：

t7：ch = CopyToReg t0，Register：i64 %36，t5 i8<2>，t65：1

t20：ch = CopyToReg t0，Register：i64 %37，t48 t20：ch = CopyToReg t0，Register：i64 %37，t48

t21 ：i64 = SUBREG_TO_REG，TargetConstant ： t21 ：i64 = SUBREG_TO_REG，TargetConstant ：

i64<0>，MOV32r0：i32，i32，TargetConstant：i32<6> i64<0>，MOV32r0：i32，i32，TargetConstant：i32<6>

t25：ch = CopyToReg t0，Register：i64 %137，t21 t25：ch = CopyToReg t0，Register：i64 %137，t21

t27：ch = TokenFactor t7，t20，t25 t27：ch = TokenFactor t7，t20，t25

t43：i32 = TEST64rr t48，t48 t43：i32 = TEST64rr t48，t48

t64：ch，glue = CopyToReg t27，Register：i32 $eflags， t64：ch，glue = CopyToReg t27，Register：i32 $eflags，

t43 t43

t45 ：ch = JCC_1 BasicBlock ：ch<_ZNst12_Vector_ t45 ：ch = JCC_1 BasicBlock ：ch<_ZNst12_Vector_

allocate.i.i.i 0x55556eb245c0>，TargetConstant ：i8<4>， allocate.i.i.i 0x55556eb245c0>，TargetConstant ：

t64，t64：1 i8<4>，t64，t64：1

t30：ch = JMP_1 BasicBlock：ch<_ZNst16allocator_ t30：ch = JMP_1 BasicBlock：ch<_ZNst16allocator_

exit.i.i.i.i 0x55556eb244c0>，t45 exit.i.i.i.i 0x55556eb244c0>，t45

注 这里演示的是通过复制 t46 指令（本节使用克隆方法，第 10 章将使用重新物化方法）

意

来解决指令依赖的问题。需要注意的是，因为引入了额外的重复指令，执行成本增

加了，所以一般在决定是否进行指令复制时都会进行收益分析，而本节并未进行收

益分析。

<!-- PDF page 179; printed page 166 -->

## 8.4 BURR List 调度器

BURR List 调度器和 Fast 调度器类似，也会先构造基于 SUnit 节点的依赖图，但它不再单纯基于深度优先进行拓扑排序来调度指令。BURR List 调度器在进行拓扑排序时会将所有可以被调度的指令节点存放在 AvailableQueue 中，然后综合考虑多种因素来计算它们的优先级，选择优先级最高的指令。

LLVM 通过 -pre-RA-sched=list-burr 选项来设置使用 BURR List 调度器，其调度算法实现在 ScheduleDAGRRList 类。

因为 BURR List 调度器在选择调度节点时会考虑多种因素，所以下面先介绍哪些因素会影响指令调度以及它们为什么会影响指令调度，然后介绍 BURR List 调度器的详细实现。

### 8.4.1 影响指令调度的关键因素

在 BURR List 调度器中，指令调度优先级主要考虑的因素有 SUnit 节点的后继节点数量（SuccsNumLeft）、前驱节点数量（PredsNumLeft）、SUnit 指令的时延（Latency），以及在依赖图中的高度（Height）和深度（Depth）、Sethi-Ullman 数值○一。

1）SuccsNumLeft ：依赖图中当前 SUnit 节点的后继节点数量，即 SUnit 节点的输出被其他节点使用的数量。以图 8-9 中的 SU[5] 为例，其 SucccsNumLeft 的值为 4。在相同条件下，该值越小越应该先调度，因为调度后可能会缩小寄存器的活跃区间。

2）PredsNumLeft ：依赖图中当前节点 SUnit 的前驱节点的数量，即该节点使用其他节点的数量。以图 8-9 中的 SU[5] 为例，其 PredsNumLeft 的值为 1。在相同条件下，该值越大越应该先调度，因为调度后可能会缩小寄存器的活跃区间。

3）Latency：节点的指令时延。带有机器操作数的 SDNode 节点，一般默认时延的值为1，有一些特殊的 SDNode 则不是这样，比如图 8-6 中 t27 的操作码为 TokenFactor，其时延值为 0。相同条件下，时延越大应该越先调度，因为调度后可以充分利用流水线的能力。

4）Height ：指按照自底向上的方式从 ExitEntry 到达当前 SUnit 节点的最长路径，其计算方法是遍历当前 SUnit 节点的后继节点，对每个后继节点的 Height 与 Latency求和，取最大值。相同条件下，该值越大应该越要先调度，因为调度后可以充分利用流水线的能力。以图 8-18 为例，SU 的后继节点 SuccSU1、SuccSU2、SuccSU3的 Height 值与 Latency 值相加，结果分别为 2、3、4，则 SU 的 Height 值为 4。 图 8-18 Height 属性计算方法

○一 具体请参见 https://en.wikipedia.org/wiki/Sethi-Ullman_algorithm。

<!-- PDF page 180; printed page 167 -->

Height 的计算公式如下。其中 Hu 表示节点 u 的高度，Succ(u) 为节点 u 的后继节点集合，Hv 为节点 v 的高度，λv 为节点 v 运行的时钟周期。

0,如果Succ(u) =φ

H u =  max

∀v∈Succ(u)

(H

v

+λ

v

)

5）Depth ：Depth 是指按照自顶向下的方式，从开始节点到达当前 SUnit 节点的最长路径，其计算方法是遍历当前 SUnit 节点的前驱节点，对每个前驱节点的 Depth 和Latency 求和，取最大值。相同条件下，该值越小应该越先调度，因为调度后可以充分利用流水线的能力。以图 8-19 为例，SU 的 前 驱 节 点 PredSU1、PredSU2、PredSU3 的 Depth 值与 Latency 值相加分

**图 8-19 Depth 属性计算方法**

别为 2、3、4，则 SU 的 Depth 值为 4。

Depth 计算公式如下。其中，Du 为节点 u 的 Depth，Pred(u) 为节点 u 的前驱节点集合。

0,如果Pred(u) =φ

D u =  max

∀v∈Pred(u)

(D

v

+λ

v

)

6）Sethi-Ullman 数值：这个概念来自 Ravi Sethi 和 Jeffrey D.Ullman 提出的 Sethi-Ullman算法，该算法用来帮助编译器在将抽象语法树转换成机器指令时，尽可能少地使用寄存器。调度器把它作为评判寄存器压力的指标来选择合适的指令，以期减少寄存器分配的压力。其计算方法涉及下面两种场景。

① 当前 SUnit 节点的所有数据依赖关系的前驱节点的 Sethi-Ullman 数值里存在唯一的最大值 x，此时其 Sethi-Ullman 数值就等于 x。以图 8-20 为例，假设 SU 节点的三个前驱 PredSU1、PredSU2、PredSU3的 Sethi-Ullman 分别为 1、1、2，则 SU 的 图 8-20 Sethi-Ullman 数值计算方法 1 Sethi-Ullman 数值为 2。

② SUnit 的所有前驱的 Sethi-Ullman数值中存在 n 个相同的最大值 x，且 n > 1，此时其 Sethi-Ullman 数值就等于 x + n –1。以图 8-21 为例，假设 SU 的三个前驱PredSU1、PredSU2、PredSU3 的 Sethi- 图 8-21 Sethi-Ullman 数值计算方法 2 Ullman 数值分别为 2、2、1，则 SU 的 Sethi-Ullman 数值为 2 + 2 – 1 = 3。

从计算方式来看，Sethi-Ullman 数值实际上是基于 PredsNumLeft 来计算的。而 Preds- NumLeft 本身就能粗略反映当前节点被调度后带来的寄存器压力影响。即 SU 被调度后，指

<!-- PDF page 181; printed page 168 -->

令中使用的寄存器都会形成新的活跃区间，活跃区间越小对于寄存器分配越友好。按照上述方法，图 8-9 中各个 SUnit 节点的各项属性计算结果如表 8-11 所示。

**表 8-11 图 8-9 中各个 SUnit 节点相关的调度属性**

调度属性

SUnit

节点 Preds Succs SUnit 指令 依赖图中的 依赖图中的 Sethi-Ullman

NumberLeft NumberLeft 时延 深度 高度 数值

SU[0]/t30 1 0 1 10 0 1

SU[1]/t64 2 1 1 9 1 4

SU[2]/t43 1 1 1 8 2 4

SU[3]/t48 3 2 1 7 3 4

SU[4]/t46 2 3 1 4 6 3

SU[5]/t5 1 4 1 1 9 1

SU[6]/t2 0 1 1 0 10 1

SU[7]/t62 3 1 1 3 7 3

SU[8]7/t59 1 1 1 2 8 1

SU[9]/t8 0 1 1 0 8 1

SU[10]/t12 0 3 1 0 6 1

SU[11]/t52 3 1 1 6 4 4

SU[12]/t49 2 1 1 5 5 3

SU[13]/t27 3 1 0 9 1 1

SU[14]/t25 1 1 1 2 2 1

SU[15]/t21 0 1 1 1 3 1

SU[16]/t20 1 1 1 8 2 4

SU[17]/t7 1 1 1 2 2 1

不同的调度算法在实现时会关注不同的影响因素，当同时存在多个影响因素时，需要按照一定的规则选择一个最优的节点。

### 8.4.2 指令优先级计算方法

BURR List 调度器在调度时会在考虑多个影响因素的情况下对可调度节点进行排序，排序工作由 BURRSort 函数实现。BURR List 算法指令优先级选择如图 8-22 所示，图中略去了算法的细枝末节（如对特殊指令 CopyFromReg、CopyToReg、Call 的处理）。算法实现会依次比较两个 SUnit 节点的 HasRegDef、Priority、ClosetSucc、MaxScratches、Height、Depth、Latency、NodeQueueID 属性。这些属性的含义如下。

<!-- PDF page 182; printed page 169 -->

1）HasRegDef ：如果 SUnit 节点定义了物理寄存器，则值为 true，否则值为 false。该属性的含义可以理解为在按照自底向上顺序调度指令时，会优先选择定义了物理寄存器的SUnit 节点，这样可以减少该寄存器的活跃区间。

2）Priority ：SUnit 的 Priority 属性就是 SUnit 节点的 Sethi-Ullman 数值。但存在特殊的 SUnit 节点，比如 TokenFactor、CopyToReg、Extract_SubReg 的 priority 为 0。

3）ClosestSucc ：基于 SuccsNumLeft 计算得出，用于描述寄存器的活跃区间，优先选择使寄存器活跃区间变小的 SUnit。

4）MaxScratches：基于 PredsNumLeft 计算得出，用于描述寄存器的活跃区间，优先选择使寄存器活跃区间变小的 SUnit。

5）Height、Depth、Latency ：即 8.4.1 节所描述的 SUnit 的 Height、Depth、Latency 的值。这里可以理解为优先调度处于最长关键路径上的节点，以提升指令的并行性能。

6）NodeQueueID ：表示 SUnit 存入 AvailableQueue 的序号（ID），越早存入 Available- Queue 的 ID 数值越小。

![图 8-22 BURR List 算法指令优先级选择](assets/figures/p182-8-22.png)

**图 8-22 BURR List 算法指令优先级选择**

<!-- PDF page 183; printed page 170 -->

### 8.4.3 示例分析

仍然以代码清单 8-1 为例来介绍 BURR List 调度器如何调度指令序列，SUnit 对应的依赖图如图 8-9 所示。BURR List 调度器用 Sequence 数组存放调度的指令结果，用优先级队列 AvailableQueue 来存放入度为 0 且可以被调度的执行序列，用 BURRSort 函数从AvailableQueue 中选出优先级最高的 SUnit。调度过程描述如下。

从 Graph Root 开始，依次调度 SU[0]、SU[1]，在这个过程中，AvailableQueue 始终最多只有一个元素，不需要做比较、选择。SU[1] 被调度后，AvailableQueue 会存入 SU[2] 和SU[13]。调度 SU[1] 后，BURR List 调度器的运行结果如表 8-12 所示。

**表 8-12 调度 SU[1] 后 BURR List 调度器的运行结果**

调度器数据结构 数据结构中的元素

AvailableQueue SU[2],SU[13]

Sequence SU[0],SU[1]

因为 AvailableQueue 中有多个 SU 节点，需要选择最优节点进行调度，所以比较 SU[2]和 SU[13] 的优先级，SU[13] 的操作码是 TokenFactor，故优先选择 SU[13]。将入度为 0 的SU[17]、SU[16]、SU[14] 存入 AvailableQueue 中。调度 SU[13] 后，BURR List 调度器的运行结果如表 8-13 所示。

**表 8-13 调度 SU[13] 后 BURR List 调度器的运行结果**

调度器数据结构 数据结构中的元素

AvailableQueue SU[2],SU[17],SU[16],SU[14]

Sequence SU[0],SU[1],SU[13]

同样，需要比较 AvailableQueue 中的 4 个 SUnit 的优先级。SU[2] 定义了物理寄存器， 故 SU[2] 优 先 级 最 高， 将 SU[2] 存 入 Sequence。 继 续 比 较 剩 余 的 3 个 SUnit 的 优先级，SU[16] 的 Depth 值最大，故优先调度 SU[16]。此时，SU[3] 入度为 0，将其存入AvailableQueue。得到的结果如表 8-14 所示。

**表 8-14 调度 SU[2]、SU[16] 后 BURR List 调度器的运行结果**

调度器数据结构 数据结构中的元素

AvailableQueue SU[17],SU[14],SU[3]

Sequence SU[0],SU[1],SU[13],SU[2],SU[16]

再次比较 AvailableQueue 中 3 个 SUnit 的优先级，SU[17] 的 NodeQueueID 小于 SU[14]且 Priority 值小于 SU[3]，故优先调度 SU[17]。继续比较 SU[14] 和 SU[3]，SU[14] 的优先级较小，所以调度 SU[14]，并将入度为 0 的 SU[15] 存入 AvailableQueue 中。调度 SU[17]、

<!-- PDF page 184; printed page 171 -->

SU[14] 后，BURR List 调度器的运行结果如表 8-15 所示。

**表 8-15 调度 SU[17]、SU[14] 后 BURR List 调度器的运行结果**

调度器数据结构 数据结构中的元素

AvailableQueue SU[3],SU[15]

Sequence SU[0],SU[1],SU[13],SU[2],SU[16],SU[17],SU[14]

继续比较 SU[3] 和 SU[15]，SU[15] 的 Priority 的值较小，依次调度 SU[15]、SU[3]，因 为 SU[11] 的 入 度 为 0， 所 以 存 入 AvailableQueue 中。 调 度 SU[15]、SU[3] 后，BURR List 调度器的运行结果如表 8-16 所示。

**表 8-16 调度 SU[15]、SU[3] 后 BURR List 调度器的运行结果**

调度器数据结构 数据结构中的元素

AvailableQueue SU[11]

Sequence SU[0],SU[1],SU[13],SU[2],SU[16],SU[17],SU[14],SU[15],SU[3]

此时，SU[3]、SU[11]、SU[4] 构成了物理寄存器依赖，采用 Fast 调度器中的 CopyAnd- MoveSuccessors 方法来处理。将 SU[4] 复制出一份，得到 SU[4]-clone，将依赖图构造成

**图 8-17 所 示 的 形 态， 依 次 调 度 SU[4]-clone、SU[11]、SU[12]， 其 中 入 度 为 0 的 SU[4]、**

SU[10] 会 存 入 AvailableQueue 中。 重 复 SU[4] 并 调 度 SU[4]-clone、SU[11]、SU[12] 后，BURR List 调度器的运行结果如表 8-17 所示。

**表 8-17 复制 SU[4] 并调度 SU[4]-clone、SU[11]、SU[12] 后 BURR List 调度器的运行结果**

调度器数据结构 数据结构中的元素

AvailableQueue SU[4],SU[10]

SU[0],SU[1],SU[13],SU[2],SU[16],SU[17],SU[14],SU[15],SU[3],SU[4]-

Sequence

clone,SU[11],SU[12]

SU[4] 定义了物理寄存器，优先调度 SU[4]，将入度为 0 的 SU[7] 存入 AvailableQueue中。调度 SU[4] 后，BURR List 调度器的运行结果如表 8-18 所示。

**表 8-18 调度 SU[4] 后 BURR List 调度器的运行结果**

调度器数据结构 数据结构中的元素

AvailableQueue SU[10],SU[7]

SU[0],SU[1],SU[13],SU[2],SU[16],SU[17],SU[14],SU[15],SU[3],SU[4]-

Sequence

clone,SU[11],SU[12],SU[4]

因为 SU[10] 的 Priority 值较小，因此先调度 SU[10]，然后调度 SU[7]，同时将入度为0 的 SU[9] 和 SU[8] 存入 AvailableQueue 中。调度 SU[10]、SU[7] 后，BURR List 调度器的

<!-- PDF page 185; printed page 172 -->

运行结果如表 8-19 所示。

**表 8-19 调度 SU[10]、SU[7] 后，BURR List 调度器的运行结果**

调度器数据结构 数据结构中的元素

AvailableQueue SU[9],SU[8]

SU[0],SU[1],SU[13],SU[2],SU[16],SU[17],SU[14],SU[15],SU[3],SU[4]-clone,SU[11],

Sequence

SU[12],SU[4],SU[10],SU[7]

由于 SU[8] 中含有物理寄存器的定义，故优先调度 SU[8]，并将入度为 0 的 SU[5] 存入AvailableQueue 中。调度 SU[8] 后，BURR List 调度器的运行结果如表 8-20 所示。

**表 8-20 调度 SU[8] 后 BURR List 调度器的运行结果**

调度器数据结构 数据结构中的元素

AvailableQueue SU[9],SU[5]

SU[0],SU[1],SU[13],SU[2],SU[16],SU[17],SU[14],SU[15],SU[3],SU[4]-clone,SU[11],

Sequence

SU[12],SU[4],SU[10],SU[7],SU[8]

SU[9] 的优先级较小要先调度，用同样的方法调度 SU[5]、SU[6]，所有节点全部调度完毕，得到的运行结果如表 8-21 所示。

**表 8-21 全部节点调度后，BURR List 调度器的运行结果**

调度器数据结构 数据结构中的元素

AvailableQueue

SU[0],SU[1],SU[13],SU[2],SU[16],SU[17],SU[14],SU[15],SU[3],SU[4]-clone,SU[11],

Sequence

SU[12],SU[4],SU[10],SU[7],SU[8],SU[9],SU[5],SU[6]

将 Sequence 中 SU 节点换成 SDNode 并倒序后得到指令的执行顺序如表 8-22 所示，其中 t12、t21、t43 节点调度顺序受到调度器的多种启发式因素影响而发生了变化。

**表 8-22 使用 BURR List 调度前后的效果比较**

调度前 调度后

t0：ch，glue = EntryToken t0：ch，glue = EntryToken

t12：i64，ch = CopyFromReg t0，Register：i64 %24 t2：i64，ch = CopyFromReg t0，Register：i64 %35

t2：i64，ch = CopyFromReg t0，Register：i64 %35 t5 ：i64，i32 = SAR64ri exact t2，TargetConstant ：

t5：i64，i32 = SAR64ri exact t2，TargetConstant：i8<3> i8<3>

t8：i64 = MOV32ri64 TargetConstant：i64<1> t8：i64 = MOV32ri64 TargetConstant：i64<1>

t59 ：i64，i32 = SUB64ri8 t5，TargetConstant ： t59 ：i64，i32 = SUB64ri8 t5，TargetConstant ：

i64<2> i64<2>

t67：ch，glue = CopyToReg t0，Register：i32 $eflags， t67：ch，glue = CopyToReg t0，Register：i32 $eflags，

t59：1 t59：1

t62 ：i64 = CMOV64rr t8，t5，TargetConstant ： t62 ：i64 = CMOV64rr t8，t5，TargetConstant ：

i8<3>，t67：1 i8<3>，t67：1

<!-- PDF page 186; printed page 173 -->

（续）

调度前 调度后

t46：i64，i32 = ADD64rr t62，t5 t12：i64，ch = CopyFromReg t0，Register：i64 %24

t49：i64，i32 = SUB64rr，t46，t12 t46：i64，i32 = ADD64rr t62，t5

t66：ch，glue = CopyToReg t0，Register：i32 $eflags， t49：i64，i32 = SUB64rr，t46，t12

t49：1 t66：ch，glue = CopyToReg t0，Register：i32 $eflags，

t52 ：i64 = CMOV64rr t46，t12，TargetConstant ： t49：1

i8<7>，t66：1 t52 ：i64 = CMOV64rr t46，t12，TargetConstant ：

t65：ch，glue = CopyToReg t0，Register：i32 $eflags， i8<7>，t66：1

t46：1 t46：i64，i32 = ADD64rr t62，t5

t48 ：i64 = CMOV64rr t52，t12，TargetConstant ： t65：ch，glue = CopyToReg t0，Register：i32 $eflags，

i8<2>，t65：1 t46：1

t7：ch = CopyToReg t0，Register：i64 %36，t5 t48 ：i64 = CMOV64rr t52，t12，TargetConstant ：

t20：ch = CopyToReg t0，Register：i64 %37，t48 i8<2>，t65：1

t21 ：i64 = SUBREG_TO_REG，TargetConstant ： t21 ：i64 = SUBREG_TO_REG，TargetConstant ：

i64<0>，MOV32r0 ：i32，i32，TargetConstant ： i64<0>，MOV32r0 ：i32，i32，TargetConstant ：

i32<6> i32<6>

t25：ch = CopyToReg t0，Register：i64 %137，t21 t25：ch = CopyToReg t0，Register：i64 %137，t21

t27：ch = TokenFactor t7，t20，t25 t7：ch = CopyToReg t0，Register：i64 %36，t5

t43：i32 = TEST64rr t48，t48 t20：ch = CopyToReg t0，Register：i64 %37，t48

t64：ch，glue = CopyToReg t27，Register：i32 $eflags， t43：i32 = TEST64rr t48，t48

t43 t27：ch = TokenFactor t7，t20，t25

t45 ：ch = JCC_1 BasicBlock ：ch<_ZNst12_Vector_ t64：ch，glue = CopyToReg t27，Register：i32 $eflags，

allocate.i.i.i 0x55556eb245c0>，TargetConstant ： t43

i8<4>，t64，t64：1 t45 ：ch = JCC_1 BasicBlock ：ch<_ZNst12_Vector_

t30：ch = JMP_1 BasicBlock：ch<_ZNst16allocator_ allocate.i.i.i 0x55556eb245c0>，TargetConstant ：i8<4>，

exit.i.i.i.i 0x55556eb244c0>，t45 t64，t64：1

t30：ch = JMP_1 BasicBlock：ch<_ZNst16allocator_

exit.i.i.i.i 0x55556eb244c0>，t45

注 这里并没有给出调度前后直观的性能数据，8.11 节会统一介绍不同调度算法的性能

意

数据。

## 8.5 Source List 调度器

Source List 调度器和 BURR List 调度器共用 ScheduleDAGRRList 类。它和 BURR List调度器类似，仅在计算 AvailableQueue 中可调度的 SUnit 的优先级时略有差异。Source List调度器会优先比较与 SUnit 节点对应的 LLVM IR 的顺序，优先调度在源码中比较靠前的指令（因此被称为 Source List）。如果无法比较出优先级，它会继续使用 BURR List 调度器的算法 BURRSort 来选择优先级高的指令。由于该算法和 BURR List 调度器中的基本一样，因此这里不再展开介绍。

LLVM 通过选项 -pre-RA-sched=source 来设置使用 Source List 调度器。

<!-- PDF page 187; printed page 174 -->

## 8.6 Hybrid List 调度器

Hybrid List 调度器和 BURR List 调度器共用 ScheduleDAGRRList 类。它也和 BURR List 调度器类似，区别在于计算 AvailableQueue 中可调度的 SUnit 的优先级的方法有差异。它会先比较 SUnit 节点是否会造成比较高的寄存器压力，自底向上地优先选择没有造成高寄存器压力的指令。如果无法比较出优先级，则继续比较指令的时延，自底向上地优先选择时延较小的指令；如果仍然无法区分优先级，它会继续使用 BURR List 调度器的算法BURRSort 来选择优先级高的指令。由于该算法和 BURR List 调度器中的基本一样，因此不再展开介绍。

LLVM 通过选项 -pre-RA-sched=list-hybrid 来使能 Hybrid List 调度器。

## 8.7 Pre-RA-MISched 调度器

8.2 节～8.6 节介绍的调度器都是基于 SelectionDAG 进行指令调度的，从本节开始介绍的调度器都是基于 MIR 指令进行调度的。Pre-RA-MISched 调度器支持自顶向下、自底向上以及双向拓扑三种调度顺序，本节介绍的示例是按照自底向上进行拓扑排序的。

LLVM 通过选项 -enable-misched 来使能 Pre-RA-MISched 调度器，该调度器由 Schedule- DAGMILive 类实现。

### 8.7.1 Pre-RA-MISched 调度器实现

Pre RA 指的是在寄存器分配前进行调度，此时，MIR 中包含了虚拟寄存器和物理寄存器。这个阶段的指令调度，在特定的场景下（调度指令数量至少超过可分配寄存器数量的50%）会优先考虑调度后带来的寄存器压力，要尽量减小寄存器分配的压力。此外，还要考虑指令并行的性能（此时会用到 8.4.2 节提到的 Latency 属性，本节会详细介绍如何基于 TD文件的描述计算 MIR 指令的时延）。需要注意的是，和基于 SelectionDAG 实现的调度算法不同，基于 MIR 的调度算法不再以基本块为调度单元，而是以调度区域为调度单元，通常一个基本块可以划分为一个或多个调度区域。

调度过程还是基于拓扑排序完成的。在进行拓扑排序时，入度为 0 的可调度指令也不是全部存入 AvailableQueue 中，会通过 Use-Def 依赖边的时延计算各个节点最快执行需要等待的指令周期。如果这个时延超过一定的阈值，也就说明该指令的 Stall Cycles 比较大，会将它存入 Pending 队列中。如果指令的时延小于当前阈值，则将它存入 AvailableQueue中。这里说的阈值是指已调度指令执行所需的时延，它会随着指令的调度结果而增长。调度算法会遍历 Pending 序列中的指令，把时延小于当前阈值的指令移到 AvailableQueue 中，然后遍历 AvailableQueue 中所有的指令，根据启发式的影响因素，选择优先级最高的指令。

<!-- PDF page 188; printed page 175 -->

### 8.7.2 调度区域的划分

调度区域的划分就是按照顺序遍历基本块的指令，遇到边界指令则生成一个新的调度区域。一个基本块可以包含多个调度区域，如

**图 8-23 所示。**

读者可能有疑惑：为什么调度算法使用调度区域而不是基本块来调度指令？因为一些指令会给程序执行时延、寄存器压力等带来不确定性，所以要将这些指令识别出来，作为调度边界，从而形成调度区域。调度区域的边界涉及 3 类指令。

1）基 本 块 的 边 界 指 令， 比 如 ret、branch、jmp 等。

2）函数调用指令，比如 call，因为指令调度不能跨函数调用。

3）修改堆栈指针的指令。 图 8-23 调度区域的划分示意图

### 8.7.3 影响 Pre-RA-MISched 调度器的关键因素

在 Pre-RA-MISched 调度器中影响优先级的因素包括指令节点是否包含物理寄存器（BiasPhysReg）、指令的时延、寄存器压力、停滞周期（Stall Cycles）等。

1）物理寄存器：根据指令是否包含物理寄存器来设置指令调度的优先级，目的是获得更小的物理寄存器活跃区间。

2）时延：一般使用 SUnit 节点的 Depth 和 Height 属性表示（参见 8.4.1 节）。SUnit 节点中的 SDNode 指令的时延多数默认为 1，而 SUnit 节点中的 MIR 指令的时延需要根据 TD文件的描述计算得到，8.7.4 节会详细介绍计算方法。

3）寄存器压力：每个 SUnit 节点都有 Pressure Diff 属性，以描述当前指令被调度时产生的寄存器压力变化。基于 Pressure Diff 通过 Excess、CriticalMax 和 CurrentMax 来描述指令被调度后产生的寄存器压力的变化。8.7.5 节会详细介绍寄存器压力的计算过程。

4）停滞周期：可以理解为指令访存所占用的时钟周期，该属性反映了 CPU 因为执行某些指令需要等待的时钟周期。

### 8.7.4 MIR 指令时延的计算

LLVM 指令调度里的时延有多种计算方式，总结起来大致分为：基于 SUnit 节点的时延计算和基于 Use-Def 依赖边的时延计算。前者一般用于 SDNode 或 MIR 生成 SUnit 节点的时候，它在一定程度上反映了指令执行消耗的时钟周期；后者用于构建 SUnit 节点的依赖关系的时候，会计算有 Use-Def 依赖边的调度时延，它反映了数据从 Def 节点流向 Use 节

<!-- PDF page 189; printed page 176 -->

点所需的时钟周期。我们分别来看看这两种场景下的时延计算过程。

1. 基于 SUnit 节点的时延计算

LLVM 实现了两种 SUnit 节点的时延计算方法，分别为基于指令行程模型的计算方法（InstrItinerary）以及基于指令调度模型的计算方法（MCSchedModel）。

（1）指令行程模型

指令的行程模型信息由 TD 文件描述，例如有 TD 代码片段如代码清单 8-2 所示。

**代码清单 8-2 指令行程模型的 TD 描述**

```text
InstrItinData<II_CSRrr,    [InstrStage<1,    [ISSUE],   0>,
                            InstrStage<1,    [ALU],     2>,
                            InstrStage<1,    [CSR]>,    0],    [4,    4]
```

**代码清单 8-2 描述了 CSRrr 指令有三个执行单元（stage），分别是 ISSUE、ALU 以及**

CSR，它们的执行周期分别为 1、1、1（表示执行该功能单元的时钟周期）。InstrStage<1, [ALU], 2> 中的2 表示从 ALU 到 CSR 需要经过 2 个额外的时钟周期（ISSUE 和 ALU 之间不需要额外的周期，因为 TD 中定义的时延为 0）。整条指令执行的流水如图 8-24 所示，因此 CSRrr 指令的时延为 3。 图 8-24 指令行程流水

（2）指令调度模型

指令调度模型的信息也由 TD 文件描述的，例如有 TD 代码片段如代码清单 8-3 所示，它描述了指令的每个执行单元输出所需的时延。

**代码清单 8-3 指令调度模型的 TD 描述**

```text
def  :  WriteRes<ALUOut,    [UnitALU]>    {  let  Latency = 2; }
def  :  WriteRes<MULOut,    [UnitALU]>    {  let  Latency = 4; }
def  EXIn  :  SchedReadAdvance<1>;
```

**代码清单 8-3 描述了 ALU（ALUOut）执行单元的时延为 2，MUL（MULOut）执行单**

元的时延为 4。LLVM 在计算某条指令的时延时，只需遍历它所有执行单元的时延，并选择最大的值作为指令的时延即可。乘法指令用到的执行单元只有 MULOut，根据代码清单 8-3中的描述，可得知它的时延为 4。

2. 基于 Use-Def 依赖边的时延计算

和 SUnit 节点时延的计算方式一样，基于 Use-Def 依赖边的时延计算方法也分为指令行程模型计算方法以及指令调度模型计算方法。

（1）指令行程模型

根据 TD 文件中描述的指令行程信息，获取 Def 寄存器的 DefCycle 属性和 Use 寄存器的 UseCycle 属性，然后计算 DefCycle – UseCycle + 1 得到依赖边的时延。例如有如代码清

<!-- PDF page 190; printed page 177 -->

单 8-4 所示的代码片段。

**代码清单 8-4 指令行程模型示例**

```text
ADD  r3,  r3,  r2
MUL  r4,  r3,  r2
```

以寄存器 r3 为例，Def 和 Use 指令分别对应 ADD 和 MUL 指令，因此 ADD、MUL 存在依赖关系。另外，ADD 和 MUL 都是 TD 中的 ALUrr 定义的指令。其中，ALUrr 指令行程信息的 TD 描述如代码清单 8-5 所示。

**代码清单 8-5 ALUrr 指令行程信息的 TD 描述**

```text
InstrItinData<II_ALUrr,    [InstrStage<1,    [ISSUE]>,
                            InstrStage<1,    [ALU]>],    [2,  2,  2]>,
```

在代码清单 8-5 中，数组 [2, 2, 2] 描述了各个寄存器索引对应的时钟周期，ADD 指令中的 r3 对应的是数组中索引为 0 的元素，即 DefCycles = 2，MUL 指令中 r3 对应数组中索引为 1 的元素，即 UseCycles = 2， 所以 ADD 和 MUL 的依赖边的时延为 2 – 2 + 1 = 1。

（2）指令调度模型

指令调度模型的计算方法为，Def 指令的 WriteRes 的时延减去 Use 指令的 ReadAdvance的时延。其中，ReadAdvance 可以理解为 Use 指令何时需要 Def 指令的输出，ADD 和MUL 两条指令的调度模型信息的 TD 描述如代码清单 8-3 所示。以代码清单 8-4 为例，ADD 和 MUL 通过 r3 存在依赖关系。Def 指令 ADD 所需的 WriteRes 的时延为 2，MUL 指令的 ReadAdvance 的时延为 1（来自代码清单 8-3 中的 EXIn），因此它们的依赖边时延为2 – 1 = 1。

### 8.7.5 寄存器压力的计算

寄存器压力的计算主要由 RegPressureTrack 类来实现，它的计算过程分别实现在调度算法中的两个阶段，即构造 SUnit 节点的依赖图和调度指令。接下来我们将详细介绍在这两个阶段如何计算寄存器压力。

1. 构建依赖图并计算相关属性

构造依赖图时按照自底向上的顺序计算每条指令被调度时造成的寄存器压力变化值（即 PressureDiff）、寄存器压力（CurrentSetPressure）以及调度到当前指令时出现过的最大寄存器压力（MaxSetPressure）。下面以代码清单 8-6 为例详细介绍 PressureDiff、CurrentSetPressure、MaxSetPressure 是如何计算的。

**代码清单 8-6 寄存器压力示例源码（8-6.cpp）**

```text
void test(int a, int *x, int *y) {
    int b = a * x[0] + y[0];
```

<!-- PDF page 191; printed page 178 -->

```text
    int c = b + x[1];
    int d = c * y[1];
    y[2] = b + c + d;
}
```

通过 clang++ -mllvm -enable-misched --target=riscv32-unknown-elf -o main.o -c 8-6.cpp -O2 命令，可在 Pre-RA-MISched 调度前生成与代码清单 8-6 对应的 MIR 指令，如代码清单 8-7 所示。

**代码清单 8-7 与代码清单 8-6 对应的 MIR（8-7.mir）**

```text
bb.0.entry
    liveins: $x10, $x11, $x12
    SU[0]    %2:gpr = COPY $x12
    SU[1]    %1:gpr = COPY $x11
    SU[2]    %0:gpr = COPY $x10
    SU[3]    %3:gpr = LW %1:gpr, 0
    SU[4]    %4:gpr = MULW %3:gpr, %0:gpr
    SU[5]    %5:gpr = LW %2:gpr, 0
    SU[6]    %6:gpr = ADDW %4:gpr, %5:gpr
    SU[7]    %7:gpr = LW %1:gpr, 4
    SU[8]    %8:gpr = ADDW %6:gpr, %7:gpr
    SU[9]    %9:gpr = LW %2:gpr, 4
    SU[10]   %10:gpr = MULW %8:gpr, %9:gpr
    SU[11]   %11:gpr = ADDW %8:gpr, %6:gpr
    SU[12]   %12:gpr = ADDW %11:gpr, %10:gpr
    SU[13]   SW %12:gpr, %2:gpr, 8
            PseudoRET
```

这是以 RISCV32 为编译后端的 MIR，它有 11 种寄存器类型（GPRX0、SP、VCSR、FPR32C、GPRC、VMV0、GPRTC、VRM8NoV0、FPR16、GPR、VM），因此 PressureDiff、CurrentSetPressure、MaxSetPressure 就是 3 个长度为 11 的数组，初始时所有元素为 0。自底向上调度指令时，如果是 Def 寄存器，则表明该寄存器活跃区间到当前指令结束，寄存器压力减少；如果是 Use 寄存器，则表明该寄存器的活跃区间从当前指令开始，寄存器压力增加。一般 32 位的寄存器压力增加值（用 Weight 表示）为 1，64 位的寄存器压力增加值为 2，依此类推。接下来，我们计算一下自底向上遍历 8-7.mir 中的指令后 PressureDiff、CurrentSetPressure、MaxSetPressure 的状态变化。

首先看第一条指令 SU[13]：SW %12:gpr, %2:gpr, 8。

该指令没有 Def 寄存器，有两个 Use 虚拟寄存器，它们的寄存器压力变化值 Weight都为 1，只影响 GPR 类型的寄存器，因此所有寄存器造成的压力影响值之和（用 PDiff 表示）PDiff[GPR] = 1 + 1 = 2。每个寄存器的当前压力值○一CurrentSetPressure[GPR] = Current- SetPressure[GPR] + PDiff[GPR]，故 CurrentSetPressure[GPR] 为 2。最大寄存器压力○二MaxSet-

○一 表中用 CurrenSet 表示。

○二 表中用 MaxSet 表示。

<!-- PDF page 192; printed page 179 -->

PdiffPressure[GPR] = max(MaxSetPdiffPressure[GPR], CurrentSetPressure[GPR])，因此MaxSetPdiffPressure[GPR] 也为 2。处理 SU[13] 后各寄存器的压力值结果如表 8-23 所示。

**表 8-23 处理 SU[13] 后 11 种寄存器类型的压力值、当前值、最大值**

寄存器

压力指标 FPR- VRM8-

GPRX0 SP VCSR GPRC VMV0 GPRTC FPR16 GPR VM

32C NoV0

PDiff 0 0 0 0 0 0 0 0 0 2 0

CurrentSet 0 0 0 0 0 0 0 0 0 2 0

MaxSet 0 0 0 0 0 0 0 0 0 2 0

依此类推，第二条指令 SU[12] ：%12:gpr = ADDW %11:gpr, %10:gpr。%12 在此处定义，其 Weight 值为 –1。新增两个 Use 寄存器（%11 和 %10），其 Weight 值都为 1。计算PDiff[GPR] = 1 + 1 – 1 = 1，CurrentSetPressure[GPR] = 3，MaxSetPdiffPressure[GPR] = 3，得到结果如表 8-24 所示。

**表 8-24 处理 SU[12] 后 11 种寄存器类型的压力值、当前值、最大值**

寄存器

压力指标 FPR- VRM8-

GPRX0 SP VCSR GPRC VMV0 GPRTC FPR16 GPR VM

32C NoV0

PDiff 0 0 0 0 0 0 0 0 0 1 0

CurrentSet 0 0 0 0 0 0 0 0 0 3 0

MaxSet 0 0 0 0 0 0 0 0 0 3 0

同样处理指令 SU[11]：%11:gpr = ADDW %8:gpr, %6:gpr，得到的结果如表 8-25 所示。

**表 8-25 处理 SU[11] 后 11 种寄存器类型的压力值、当前值、最大值**

寄存器

压力指标 FPR- VRM8-

GPRX0 SP VCSR GPRC VMV0 GPRTC FPR16 GPR VM

32C NoV0

PDiff 0 0 0 0 0 0 0 0 0 1 0

CurrentSet 0 0 0 0 0 0 0 0 0 4 0

MaxSet 0 0 0 0 0 0 0 0 0 4 0

接下来处理指令 SU[10] ：%10:gpr = MULW %8:gpr, %9:gpr。寄存器 %8 和上条指令中的 %8 具有相同的 Def，它作为 Use 寄存器时对 CurrentSetPressure 和 MaxSetPressure 的影响已经包含在上条指令中了（也就是说 %8 不产生新的寄存器活跃区间），只有 %10 和 %9会影响 CurrentSetPressure 和 MaxSetPressure。这里值得注意的是，PDiff 描述的是当前指

<!-- PDF page 193; printed page 180 -->

令导致的寄存器压力变化情况，所以它的计算只受当前指令影响。该指令使用 %8、%9 增加了寄存器压力，定义 %10 减小了寄存器压力，所以得到的 PDiff 为 1。处理 SU[10] 后各寄存器类型的压力值结果如表 8-26 所示。

**表 8-26 处理 SU[10] 后 11 种寄存器类型的压力值、当前值、最大值**

寄存器

压力指标 FPR- VRM8-

GPRX0 SP VCSR GPRC VMV0 GPRTC FPR16 GPR VM

32C NoV0

PDiff 0 0 0 0 0 0 0 0 0 1 0

CurrentSet 0 0 0 0 0 0 0 0 0 4 0

MaxSet 0 0 0 0 0 0 0 0 0 4 0

接下来处理 SU[9]：%9:gpr = LW %2:gpr, 4。指令使用的 %2 对 CurrentSetPressure 和MaxSetPressrure 的影响已经包含在第一条指令（SU[13]）计入对 CurrentSetPressure 和MaxSetPressrure 的影响。该指令定义了 %9，所以 CurrentSetPressure 需要减 1。该指令分别定义和使用了相同数量的寄存器，故 PDiff 为 0。处理 SU[9] 后各寄存器的压力值结果如表 8-27 所示。

**表 8-27 处理 SU[9] 后 11 种寄存器类型的压力值、当前值、最大值**

寄存器

压力指标 FPR- VRM8-

GPRX0 SP VCSR GPRC VMV0 GPRTC FPR16 GPR VM

32C NoV0

PDiff 0 0 0 0 0 0 0 0 0 0 0

CurrentSet 0 0 0 0 0 0 0 0 0 3 0

MaxSet 0 0 0 0 0 0 0 0 0 4 0

用同样的方式依次处理其他指令，最后得到的结果如表 8-28 所示。

**表 8-28 处理完所有指令后，11 种寄存器类型的压力值、当前值、最大值**

寄存器

压力指标 FPR- VRM8-

GPRX0 SP VCSR GPRC VMV0 GPRTC FPR16 GPR VM

32C NoV0

PDiff 0 0 0 0 1 0 1 0 0 0 0

CurrentSet 0 0 0 0 3 0 3 0 0 3 0

MaxSet 0 0 0 0 3 0 3 0 0 4 0

至此，所有寄存器的压力变化值都计算完成了。在这个过程还需要处理当前调度区间的 LiveIn 和 LiveOut 寄存器集合对压力值的影响。比如我们按照自底向上的顺序调度指令时，需要处理 LiveOut 寄存器的影响，它们会作为 Use 寄存器而计算初始化的压力值；按

<!-- PDF page 194; printed page 181 -->

照自顶向下的顺序调度指令时，则需要将 LiveIn 寄存器作为 Use 寄存器计算初始化的压力值。当前的示例中的 LiveOut 恰好为空，我们就不在此具体叙述了，过程和上述的指令压力值计算类似。

另外，TD 文件还会给出每一类寄存器压力的参考阈值（即 Limit），比如表 8-29 的第一行为后端压力的参考阈值。如果按照上述的顺序调度完后，当 MaxSet 超出了参考阈值，会把它记录到长度为 11 的 RegionCriticalPSet（记录寄存器压力超出阈值的过载量）数组中，这个数组在后续的调度过程中也会用到。当前示例中的 MaxSet 恰好没有超出参考阈值，因此 RegionCriticalPSet 所有的值为 0。Limit、MaxSet 和对应的 RegionCriticalPSet 的计算结果如表 8-29 所示。

**表 8-29 寄存器压力参考阈值**

寄存器

压力指标 FPR- VRM8-

GPRX0 SP VCSR GPRC VMV0 GPRTC FPR16 GPR VM

32C NoV0

Limit 2 2 3 8 8 8 16 24 32 32 32

MaxSet 0 0 0 0 3 0 3 0 0 4 0

RegionCriticalPSet 0 0 0 0 0 0 0 0 0 0 0

接下来将介绍如何使用本节计算的每条指令的寄存器压力变化值以及 RegionCriticalPSet进行指令调度。

2. 指令调度

在自底向上调度依赖图中节点，如果 AvailableQueue 中出现多个可调度的节点，寄存器压力将作为计算指令优先级的重要因素。注意，每个节点被调度后，依然需要计算当前调度过程中的 CurrentSet 和 MaxSet 的变化，计算过程和前面介绍的方法类似。LLVM 定义了如下 3 种指标来描述 MIR 指令被调度后对寄存器压力的影响。

1）RegPressureDelta.Excess ：用于描述该指令被调度后，CurrentSet 是否超出了参考阈值。

2）RegPressureDelta.CriticalMax ：用于描述该指令被调度后，MaxSet 是否超出了RegionCriticalPSet 相关索引对应的值。

3）RegPressureDelta.CurrentMax ：用于描述该指令调度后是否超出了默认顺序遍历过程中出现的最大的寄存器压力值。

### 8.7.6 示例分析

Pre-RA-MISched 算法按照 BasPhysReg、RegPressure、停滞周期、指令时延依次比较AvailableQueue 中可调度节点的优先级，选择优先级最高的节点。我们依然以代码清单 8-7

<!-- PDF page 195; printed page 182 -->

为例来演示整个调度区间的指令经过该调度算法处理后，如何形成新的指令序列。调度过程仍然使用 AvailableQueue 存储当前可调度的节点，并用 Pending 存储时延超过阈值的可调度节点，用 CurCycle 来表示当前的阈值。指令调度步骤如下。

1）构造依赖图，过程和 8.3.1 节介绍的一样，得到结果如图 8-25 所示。

![图 8-25 基于 SUnit 构造依赖图](assets/figures/p195-8-25.png)

**图 8-25 基于 SUnit 构造依赖图**

2） 从 Graph Root 出 发， 按 照 拓 扑 排 序 的 方 式， 依 次 调 度 入 度 为 0 的 节 点 SU[13]、

<!-- PDF page 196; printed page 183 -->

SU[12]。此时 SU[10] 和 SU[11] 入度为 0，阈值 CurCycle 更新为 2。SU[10] 和 SU[11] 的调度时延的计算方法为：SU[12] 的调度时延 1 加上 SU[12] 的节点时延 1（图 8-25 节点中的 Latency的值），等于 2。没有超过阈值，因此存入 AvailableQueue。得到的运行结果如表 8-30 所示。

**表 8-30 调度 SU[13]、SU[12] 后的运行结果**

调度器数据结构 数据结构中的元素

result SU[13],SU[12]

AvailableQueue SU[10],SU[11]

Pending

CurCycle 2

3）此时，AvailableQueue 中存在 SU[10] 和 SU[11] 两个节点，比较 SU[10] 和 SU[11]的优先级，它们的 BasPhysReg、RegPressure、停滞周期、调度时延都相等，因此按照指令顺序依次调度 SU[11]、SU[10]，并更新阈值为 4。此时 SU[8]、SU[9] 入度为 0，SU[8] 的调度时延为 SU[10] 的调度时延 3 加上 SU[10] 的节点时延 1，等于 4，没有超过阈值，存入AvailableQueue。同理，SU[9] 的调度时延为 7，超过阈值意味着该指令存在较大的停滞周期，因此降低它的优先级，将它存入 Pending。得到的运行结果如表 8-31 所示。

**表 8-31 调度 SU[11]、SU[10] 后的运行结果**

调度器数据结构 数据结构中的元素

result SU[13],SU[12],SU[11],SU[10]

AvailableQueue SU[8]

Pending SU[9]

CurCycle 4

4）因为此时 SU[9] 的调度时延为 7，超过时延阈值 4，因此优先调度 AvailableQueue中的 SU[8]，并更新阈值为 5。此时，SU[6] 和 SU[7] 入度为 0。计算得到 SU[6] 的调度时延为 5，SU[7] 的调度时延为 8，所以将 SU[6] 存入 AvailableQueue，将 SU[7] 存入 Pending中。得到的运行结果如表 8-32 所示。

**表 8-32 调度 SU[8] 后的运行结果**

调度器数据结构 数据结构中的元素

result SU[13],SU[12],SU[11],SU[10],SU[8]

AvailableQueue SU[6]

Pending SU[9],SU[7]

CurCycle 5

<!-- PDF page 197; printed page 184 -->

5）此时，Pening 中所有节点的调度时延都超过阈值 5，所以先调度 SU[6]，阈值更新为 6。SU[4] 与 SU[5] 的调度时延分别为 6 和 9。将 SU[4] 存入 AvailableQueue，将 SU[5]存入 Pending。得到的运行结果如表 8-33 所示。

**表 8-33 调度 SU[6] 后的运行结果**

调度器数据结构 数据结构中的元素

result SU[13],SU[12],SU[11],SU[10],SU[8],SU[6]

AvailableQueue SU[4]

Pending SU[9],SU[7],SU[5]

CurCycle 6

6）此时，Pening 中所有节点的调度时延都超过阈值 6，所以先调度 SU[4]，阈值更新为 7。SU[3] 与 SU[2] 的调度时延分别为 10 和 6，将 SU[2] 存入 AvailableQueue，将 SU[3]存入 Pending。得到的运行结果如表 8-34 所示。

**表 8-34 调度 SU[4] 后的运行结果**

调度器数据结构 数据结构中的元素

result SU[13],SU[12],SU[11],SU[10],SU[8],SU[6],SU[4]

AvailableQueue SU[2]

Pending SU[9],SU[7],SU[5],SU[3]

CurCycle 7

7）Pending 中只有 SU[9] 的调度时延为 7，但没超过当前阈值 7，将 SU[9] 存入 Available- Queue。得到的运行结果如表 8-35 所示。

**表 8-35 SU[9] 存入 AvailableQueue 后的运行结果**

调度器数据结构 数据结构中的元素

result SU[13],SU[12],SU[11],SU[10],SU[8],SU[6],SU[4]

AvailableQueue SU[2],SU[9]

Pending SU[7],SU[5],SU[3]

CurCycle 7

8）比较 SU[9] 和 SU[2] 的优先级。SU[2] 的操作数包含物理寄存器 $x11，PredsNumLeft为 0，计算得到 BiasPhysReg 为 –1 ；而 SU[9] 不包含物理寄存器，因此优先调度 SU[9]，阈值更新为 8，得到的运行结果如表 8-36 所示。

9）依此类推，调度 SU[7]、SU[5]、SU[3]，阈值更新为 11。得到的运行结果如表 8-37所示。

<!-- PDF page 198; printed page 185 -->

**表 8-36 调度 SU[9] 后的运行结果**

调度器数据结构 数据结构中的元素

result SU[13],SU[12],SU[11],SU[10],SU[8],SU[6],SU[4],S（U续[9）]

AvailableQueue SU[2]

Pending SU[7],SU[5],SU[3]

CurCycle 8

**表 8-37 调度 SU[7]、SU[5]、SU[3] 后的运行结果**

调度器数据结构 数据结构中的元素

result SU[13],SU[12],SU[11],SU[10],SU[8],SU[6],SU[4],SU[9],SU[7],SU[5],SU[3]

AvailableQueue SU[2],SU[0],SU[1]

Pending

CurCycle 11

10）AvailableQueue 中的 SU[2]、SU[0]、SU[1] 三条指令的 BasPhysReg、RegPressure、停滞周期、调度时延都相等。按照默认的顺序依次调度 SU[2]、SU[1] 和 SU[0]。将最终的调度结果做一次逆序变换，得到的指令顺序为 SU[0]、SU[1]、SU[2]、SU[3]、SU[5]、SU[7]、SU[9]、SU[4]、SU[6]、SU[8]、SU[10]、SU[11]、SU[12]、SU[13]。

最后来看一下 Pre-RA-MISched 调度器的调度结果，如表 8-38 所示。和默认顺序相比最大的区别是，在停滞周期内较大的访存指令 SU[3]、SU[5]、SU[7]、SU[9] 被移到更靠前的位置执行了，这样能充分利用 CPU 的流水线能力。

**表 8-38 使用 Pre-RA-MISched 调度前后的效果比较**

调度前 调度后

SU[0] %2:gpr = COPY $x12 SU[0] %2:gpr = COPY $x12

SU[1] %1:gpr = COPY $x11 SU[1] %1:gpr = COPY $x11

SU[2] %0:gpr = COPY $x10 SU[2] %0:gpr = COPY $x10

SU[3] %3:gpr = LW %1:gpr, 0 SU[3] %3:gpr = LW %1:gpr, 0

SU[4] %4:gpr = MULW %3:gpr, %0:gpr SU[5] %5:gpr = LW %2:gpr, 0

SU[5] %5:gpr = LW %2:gpr, 0 SU[7] %7:gpr = LW %1:gpr, 4

SU[6] %6:gpr = ADDW %4:gpr, %5:gpr SU[9] %9:gpr = LW %2:gpr, 4

SU[7] %7:gpr = LW %1:gpr, 4 SU[4] %4:gpr = MULW %3:gpr, %0:gpr

SU[8] %8:gpr = ADDW %6:gpr, %7:gpr SU[6] %6:gpr = ADDW %4:gpr, %5:gpr

SU[9] %9:gpr = LW %2:gpr, 4 SU[8] %8:gpr = ADDW %6:gpr, %7:gpr

SU[10] %10:gpr = MULW %8:gpr, %9:gpr SU[10] %10:gpr = MULW %8:gpr, %9:gpr

SU[11] %11:gpr = ADDW %8:gpr, %6:gpr SU[11] %11:gpr = ADDW %8:gpr, %6:gpr

SU[12] %12:gpr = ADDW %11:gpr, %10:gpr SU[12] %12:gpr = ADDW %11:gpr, %10:gpr

SU[13] SW %12:gpr, %2:gpr, 8 SU[13] SW %12:gpr, %2:gpr, 8

<!-- PDF page 199; printed page 186 -->

## 8.8 Post-RA-TDList 调度器

Post-RA-TDList 调度器作用于寄存器分配后，它采用自顶向下的拓扑排序方式，着重考虑通过最长关键路径（Depth、Height）提升指令重排后的流水线性能。

### 8.8.1 Post-RA-TDList 调度器实现

LLVM 通过选项 -post-RA-scheduler 来启用 Post-RA-TDList 调度器，该调度器由 Schedule- PostRATDList 类实现。调度器用 AvailableQueue 存储当前可调度的节点指令，用 Pending存储时延超过阈值的可调度节点，用 CurCycle 来表示当前的阈值，用 Sequence 存储调度后的指令序列。

### 8.8.2 示例分析

我们以代码清单 8-8 为示例来演示 Post-RA-TDList 调度器是如何调度指令的。

**代码清单 8-8 Post-RA-TDList 调度器示例（8-8.cpp）**

```text
int g_val = 1;
int MUL(int x, int y) {
    int a = y * x;
    int z = g_val * x;
    int q = x + a;
    return z * q;
}
```

在使用命令 clang++ -mllvm -enable-misched --target=riscv32-unknown-elf -o main.o -c 8-8. cpp -O2 后，代码清单 8-8 经过 LLVM 后端寄存器分配后生成的 MIR 指令如代码清单 8-9所示。

**代码清单 8-9 与代码清单 8-8 对应的 MIR**

```text
liveins:  $x10,  $x11
SU[0]:    $x12 = LUI target-flags @g_val
SU[1]:    $x12 = LW $x12, target-flags @g_val
SU[2]:    $x11 = MULW $x11, $x10
SU[3]:    $x11 = ADDW $x11, $x10
SU[4]:    $x10 = MULW $x11, $x10
SU[5]:    $x10 = MULW $x10, $x12
        PseudoRET $x10
```

指令调度步骤如下。

1）按照调度区间的粒度构建 SUnit 节点的依赖图，构造过程和 8.3.1 节介绍的相同，如图 8-26 所示。

<!-- PDF page 200; printed page 187 -->

![图 8-26 基于 SUnit 构建的依赖图](assets/figures/p200-8-26.png)

**图 8-26 基于 SUnit 构建的依赖图**

2）对依赖图中的指令自顶向下进行调度。初始化阈值 CurCycle 为 0，将入度为 0 的SU[0]、SU[2] 存入 AvailableQueue 中。得到的运行结果如表 8-39 所示。

**表 8-39 初始调度将 SU[0]、SU[2] 存入 AvailableQueue 中**

调度器数据结构 数据结构中的元素

Sequence

AvailableQueue SU[0],SU[2]

Pending

CurCycle 0

3）比较 AvailableQueue 中 SU[0] 和 SU[2] 的 Height 值，显然 SU[0] 的 Height 值更大，所以优先调度 SU[0]。此时，入度为 0 的 SU[1] 的 Depth 值为 1，大于阈值，将 SU[1] 存入Pending 中。得到的运行结果如表 8-40 所示。

**表 8-40 调度 SU[0] 后的运行结果**

调度器数据结构 数据结构中的元素

Sequence SU[0]

AvailableQueue SU[2]

Pending SU[1]

CurCycle 0

<!-- PDF page 201; printed page 188 -->

4）接着调度 AvailableQueue 中的 SU[2]。此时，入度为 0 的 SU[3] 的 Depth 值为 1，大于阈值，因此将 SU[3] 存入 Pending 中。得到的运行结果如表 8-41 所示。

**表 8-41 调度 SU[2] 后的运行结果**

调度器数据结构 数据结构中的元素

Sequence SU[0],SU[2]

AvailableQueue

Pending SU[1],SU[3]

CurCycle 0

5）此时，AvailableQueue 中没有元素，将阈值 CurCycle 加 1。Pending 中的 SU[1]、SU[3]的 Depth 值都和阈值相等，将它们存入 AvailableQueue 中。得到的运行结果如表 8-42所示。

**表 8-42 更新 AvailableQueue 状态后的运行结果**

调度器数据结构 数据结构中的元素

Sequence SU[0],SU[2]

AvailableQueue SU[1],SU[3]

Pending

CurCycle 1

6）因为 SU[1] 的 Height 值大于 SU[3]，所以优先调度 SU[1]。依次调度完 SU[1]、SU[3]后，将入度为 0 的 SU[4]（其 Depth 为 2，大于阈值）存入 Pending。得到的运行结果如表 8-43所示。

**表 8-43 调度 SU[1]、SU[3] 后的运行结果**

调度器数据结构 数据结构中的元素

Sequence SU[0],SU[2],SU[1],SU[3]

AvailableQueue

Pending SU[4]

CurCycle 1

7）此时，AvailableQueue 中没有元素，阈值加 1 后为 2。Pending 中 SU[4] 的 Depth 值等于阈值，因此将它存入 AvailableQueue 中。调度 SU[4]。将阈值不断加 1 直到等于 SU[5]的 Depth，调度 SU[5]。得到的运行结果如表 8-44 所示。

<!-- PDF page 202; printed page 189 -->

**表 8-44 调度 SU[4]、SU[5] 后的运行结果**

调度器数据结构 数据结构中的元素

Sequence SU[0],SU[2],SU[1],SU[3],SU[4],SU[5]

AvailableQueue

Pending

CurCycle 5

最后得到的调度结果为，SU[0]、SU[2]、SU[1]、SU[3]、SU[4]、SU[5]，如表 8-45 所示。

从最终的效果来看，SU[1] 和 SU[2] 指令发生了调换。这里需要注意的是，SU[1] 作为一条访存指令的时延较长，调度后的性能未必会比调度前的性能更好。

**表 8-45 使用 Post-RA-TDList 调度前后的效果比较**

调度前 调度后

liveins: $x10, $x11 liveins: $x10, $x11

SU[0]: $x12 = LUI target-flags @g_val SU[0]: $x12 = LUI target-flags @g_val

SU[1]: $x12 = LW $x12, target-flags @g_val SU[2]: $x11 = MULW $x11, $x10

SU[2]: $x11 = MULW $x11, $x10 SU[1]: $x12 = LW $x12, target-flags @g_val

SU[3]: $x11 = ADDW $x11, $x10 SU[3]: $x11 = ADDW $x11, $x10

SU[4]: $x10 = MULW $x11, $x10 SU[4]: $x10 = MULW $x11, $x10

SU[5]: $x10 = MULW $x10, $x12 SU[5]: $x10 = MULW $x10, $x12

PseudoRET $x10 PseudoRET $x10

## 8.9 Post-RA-MISched 调度器

Post-RA-MISched 调度器也是作用于寄存器分配后，它和 Post-RA-TDList 调度器一样自顶向下调度指令。Post-RA-TDList 调度器使用了 SUnit 的 Depth 和 Height 属性，Post- RA-MISched 调度器则增加了更多的启发式因素来计算 AvailableQueue 中可调度指令的优先级，包括停滞周期、关键资源（Critial Resources）、必需资源（Demanded Resources）。其中停滞周期的含义参考 8.7.3 的介绍，关键资源用于描述指令访问调度区间内资源的时钟周期开销，必需资源用于描述指令跨调度区间访问资源的时钟周期开销，它们分别描述了指令节点时延的不同子集。Post-RA-MISched 的总体调度过程和 Post-RA-TDList 比较相似，本节不再用具体示例演示了，读者可以自行阅读 LLVM 相关的代码实现。

LLVM 通 过 选 项 -enable-post-misched 启 用 Post-RA-MISched 调 度 器， 调 度 算 法 由ScheduleDAGMI 类实现。

<!-- PDF page 203; printed page 190 -->

## 8.10 循环调度

循环调度是针对循环体进行的指令调度，在 LLVM 中被称为 SMS。

### 8.10.1 循环调度算法实现

SMS 是针对循环实现的与架构无关的软流水（Software Pipelining）指令调度框架。如果我们将每次循环的指令称为一次迭代，那么 SMS 的目的是通过将不同迭代的指令同时发射来提升并行度。考虑有如代码清单 8-10 所示的 SMS 处理前的伪代码，不考虑跳转指令，该循环一次迭代需要独立发射三条指令（指令之间相互依赖）。

**代码清单 8-10 SMS 处理前的伪代码**

```text
1 BB1:
2   A1 = A0  ①
3   A2 = A1  ②
4   A3 = A2  ③
5   b BB1 if cond
```

如果将其改变为代码清单 8-11 所示，因为指令①与指令③之间无直接依赖，所以可以将本次迭代的指令③与下次迭代的指令①放在同一时刻发射，提高并行度。这便是 SMS 调度的一个简单示例。

**代码清单 8-11 SMS 处理后的伪代码**

```text
1   A1 = A0
2 BB1:
3   A2 = A1
4   A3 = A2; A1 = A0;
5   b BB1 if cond
6   A2 = A1
7   A3 = A2
```

目 前 LLVM 中 的 SMS 是 基 于 文 档“ An Implementation of Swing Modulo Scheduling with Extensions for Superblocks”○一的描述实现的，现在支持 PPC、ARM 和 Hexagon 三种后端，大致步骤如下。

步骤 1：判断循环是否可以做软流水调度

完全满足以下条件才会继续进行指令调度。

1）循环里的基本块数量为 1。

2）函数没有被标记为不可做软流水调度。

3）循环可以被分析出分支信息。

○一 请参见 https://llvm.org/pubs/2005-06-17-LattnerMSThesis.html。

<!-- PDF page 204; printed page 191 -->

4）循环可以被分析出循环指令等信息。

5）循环需要有 PreHeader 基本块。

步骤 2：构建依赖图并计算相关属性

为循环体中基本块包含的指令构建依赖关系，过程和前几节中的构建依赖图类似，但需要增加跨迭代过程的指令依赖。比如在图 8-27 所示的依赖图示例中，假设指令 A 和 F 都是对同一内存的访问操作，A 读内存，F 写内存，那么下个循环迭代中的 A 指令必须等待前一个迭代中的 F 指令执行完。因此 A 和 F 存在一个Anti 类型的依赖关系，图中用蓝色虚线表示。依此类推，G 和 M 也属于这样的情况。

步骤 3：计算调度所需的启发式属性 图 8-27 依赖构建跨循环迭代示意图

1）ResMII（Resource Minimum Initiation Interval，资源最小启动间隔）：用来描述硬件资源限制下的循环基本块指令的最小间隔。编译器一般使用简单的近似值计算方法，即用循环基本块中的指令数除以基本块中指令使用最多的硬件资源数量。但 LLVM 使用了更复杂的计算方法，即用 DFA（Deterministic Finite Automation，确定性有限自动机）模拟 CPU使用硬件资源执行指令的过程来计算 ResMII，过程如下。

① 将基本块指令按照使用硬件关键资源（比如 ALU 单元）的数量由高到低排序，也就是说使用关键资源多的指令优先执行。

② 按步骤①中的指令顺序调用 DFA 以保存关键资源。

③ 如果 DFA 不够○一，则新增 DFA。

④ 迭代步骤②、③，直到所有的指令都有 DFA 来保存资源。

⑤ 最终 DFA 的数量就是 ResMII，即 ResMII 等于 DFA 的数量。

2）RecMII（Recrrence Minimum Initiation Interval，循环依赖最小启动间隔）：如果循环基本块中存在跨迭代的依赖，比如图 8-27 中的 A 和 F 指令，我们称之为依赖图中存在循环依赖，而 {A，C，D，F} 便为一个循环依赖的集合。为了保证两次循环迭代的循环依赖集合中的指令依赖满足执行的顺序，我们用 RecMII 来描述循环基本块中所有循环依赖集合的最小启动间隔。计算过程如下。

① 通过约翰逊电路算法（Johnson’s circuit algorithm）○二找到循环基本块中所有的循环依赖集合。

② 遍历循环依赖集合，计算每个循环依赖的执行间隔 II = ceil(delay / distance)。其中

○一 笔者理解 DFA 描述了硬件拥有的资源，所谓 DFA 不够指的是当前资源已经被使用，需要等待相应硬件

执行完才会空出。

○二 请参见 Donald B. Johnson. Finding all the elementary circuits of a directed graph. SIAM Journal on Computing,

4(1): 77–84, March 1975.

<!-- PDF page 205; printed page 192 -->

distance 表示循环执行的迭代次数，LLVM 中默认为 1，delay 表示循环依赖集合中指令执行的时钟周期。

③ 选择最大的循环依赖集合的 II 作为 RecMII。

3）MII（Minimum Initiation Interval，最小启动间隔）：MII 描述了每次循环迭代执行的最小启动间隔，取 ResMII 和 RecMII 的最大值，MII = max(ResMII, RecMII)。

4）ASAP（As Soon As Possible，最早调度时间）：ASAP 表示指令最早允许被调度的时间，计算公式如下所示。其中，u 和 v 表示依赖图中的指令节点；Pred(u) 表示节点 u 的前驱节点集合；λ 表示节点执行所需的时钟周期；δv,u 表示当节点 u 和 v 存在跨迭代依赖时，当前迭代的节点 u 和前一次迭代中的节点 v 的依赖边时延（后续变量与此类似，不一一指出）。

0, 如果Pred(u) =φ

ASAP u =  max

∀v∈Pred(u)

(ASAP

v

+λ

v

−δ

v,u

×MII)

5）ALAP（As Late As Possible，最迟调度时间）：ALAP 表示指令最晚允许被调度的时间，计算公式如下所示，其中 Succ(u) 表示节点 u 的后继节点的集合。

0,如果Pred(u) =φ

ALAP u =  max

∀v∈Pred(u)

(ALAP

v

−λ

v

+δ

u,v

×MII)

6）MOV：MOV 表示指令允许被调度的时间区间，一般 MOV 越大说明该指令的调度窗口越大，越容易被调度。指令 u 的 MOV 的计算方法为：MOVu = ALAPu – ASAPu。

7）Depth：含义参考 8.4.1 节里的介绍。

8）Height：含义参考 8.4.1 节里的介绍。

下面以图 8-28 所示的指令依赖图为例计算相关属性。 图 8-28 指令依赖图

假设 λa = λb = λc = λd = 1，δa,b = δa,c = δa,d = δb,e = δc,e = δd,e = 0，MII = 1，则节点属性的计算结果如表 8-46 所示。

**表 8-46 循环调度相关属性的计算结果**

节点

属性

a b c d e

ASAP 0 1 1 1 2

ALAP 0 1 1 1 2

MOV 0 0 0 0 0

Depth 0 1 1 1 2

Height 2 1 1 1 0

步骤 4：节点排序

为什么要给节点排序呢？理想的调度结果达成两个目标：一是循环迭代执行周期（II）

<!-- PDF page 206; printed page 193 -->

尽可能小；二是单次迭代中保持寄存器活跃区间（MaxLive）最小。前者要求我们能按顺序对一条链路进行调度，如果指令的前驱节点和后继节点都被调度，它很容易失去调度的时间窗口。后者要求我们尽可能减小寄存器的生命周期，也就是节点尽可能紧跟着它的前驱节点调度。排序算法大致步骤如下。

1）将循环基本块中所有的递归集合按照 RecMII 由高到低进行排序。

2）按照步骤 1 中的顺序遍历递归集合，对递归集合中的指令按照启发式因素 Depth、Height、MOV 进行排序，存入列表中。如果节点出现在多个递归中，则由 RecMII 最高的递归处理一次即可，其他的递归不再处理该节点。

3）处理没有出现在任何递归集合中的节点，按照步骤 2 的启发式因素排序，直到所有节点都被遍历过并存入列表中。

步骤 5：调度

调度过程就是根据上一步生成的指令序列依次处理每一条指令。调度过程着重考虑将当前节点尽可能靠近已经被调度过的前驱节点或者后继节点，从而减少寄存器压力。算法流程大致如下。

1）将 II（执行间隔）设置为 MII，初始化二维数组存放的调度结果，横坐标为指令被调度的时钟周期，纵坐标为在该时钟周期中被调度的指令序列。

2）如果当前节点 u 没有任何相邻的前驱节点或者后继节点被调度过，则该指令的可调度时间区间为 [Early_Startu, Early_Startu + II – 1]，其中 Early_Startu = ASAPu。

3）如果当前节点 u 只有相邻的前驱节点被调度过，没有后继节点被调度过，则其调度区间为 [Early_Startu, Early_Startu + II – 1]。其中 Early_Startu = maxv∈PSP(u)(tv + λv – δv,u ×II)，tv 是节点 v 的调度时钟周期，λv 是节点 v 的时延，δv,u 是前一次迭代节点 v 到当前迭代节点 u 的依赖边时延，PSP(u) 是在与节点 u 相邻的前驱节点中被调度过的节点集合。

4）如果当前节点 u 只有相邻的后继节点被调度过，没有前驱节点被调度过，则其调度区间为 [Late_Startu, Late_Startu – II + 1]。其中 Late_Startu = minv∈PSS(u)(tv – λv + δu,v× II)，PSS(u) 是在与节点 u 相邻的后继节点中被调度过的节点集合。

5）如果当前节点 u 同时存在相邻的前驱节点和后继节点被调度过，则该节点的调度区间为 [Late_Startu, Early_Startu + II – 1]。

6）如果上述过程有节点找不到合适的调度区间，则将 II 加 1，重新开始从步骤 1 执行，直到所有节点找到合适的调度区间。

步骤 6：生成并行化循环

根据调度结果重新构造循环指令，该操作主要是生成 3 个基本块：

1）Prologue：充当新的循环结构中的 PreHeader 基本块。

2）Kernel：充当新的循环结构中的循环体基本块。

3）Epilogue：充当新的循环结构中循环退出的基本块。

LLVM 根据每条指令被调度后所属的执行单元来决定哪些指令需要被放入 Prologue、

<!-- PDF page 207; printed page 194 -->

Kernel 或者 Epilogue 基本块中。每条指令的执行单元计算方法为：stage = floor(cycle / II)，其中 cycle 为该指令被调度的时钟周期，II 为步骤 5 中调度成功的执行间隔。图 8-29 展示了一个简单的示例，原始的循环体内有两条指令 op1 和 op2，假设 op1 的 stage 为 0，op2 的stage 为 1。经过完整的调度后，将 stage 为 0的 op1 复制到 Prologue 基本块中，将 stage 为1 的 op2 复制到 Epilogue 基本块中，最终生成的基本块 Prologue 的指令为 op1，Kernel的指令为 op2、op1，Epilogue 的指令为 op2。当然还要重命名迭代间依赖的指令操作数并更新各个基本块的控制流指令分支。

**图 8-29 并行化循环示意图**

### 8.10.2 示例分析

下面通过一段 LLVM IR 示例代码来大致描述 SMS 是如何对指令进行调度的，我们主要关注其中涉及的循环语句基本块 b7（蓝色字体）在调度过程中的变化，如代码清单 8-12 所示。

**代码清单 8-12 SMS 示例 IR（8-12.ll）**

```text
; Function Attrs: nounwind
define void @f0(ptr nocapture %a0, i32 %a1, ptr nocapture %a2) #0 {
b0:
    %v0 = icmp sgt i32 %a1, 0
    br i1 %v0, label %b1, label %b9
b1:                                               ; preds = %b0
    %v1 = icmp ugt i32 %a1, 3
    %v2 = add i32 %a1, -3
    br i1 %v1, label %b2, label %b5
b2:                                               ; preds = %b1
    br label %b3
b3:                                               ; preds = %b3, %b2
    %v3 = phi i32 [ %v48, %b3 ], [ 0, %b2 ]
    %v4 = phi i32 [ %v46, %b3 ], [ 0, %b2 ]
    %v5 = phi i32 [ %v49, %b3 ], [ 0, %b2 ]
    %v6 = getelementptr inbounds [576 x i32], ptr %a0, i32 0, i32 %v5
    %v7 = load i32, ptr %v6, align 4, !tbaa !0
    %v8 = getelementptr inbounds [576 x i32], ptr %a0, i32 1, i32 %v5
    %v9 = load i32, ptr %v8, align 4, !tbaa !0
    %v10 = add nsw i32 %v9, %v7
    store i32 %v10, ptr %v6, align 4, !tbaa !0
    %v11 = sub nsw i32 %v7, %v9
    store i32 %v11, ptr %v8, align 4, !tbaa !0
    %v12 = tail call i32 @llvm.hexagon.A2.abs(i32 %v10)
    %v13 = or i32 %v12, %v4
    %v14 = tail call i32 @llvm.hexagon.A2.abs(i32 %v11)
```

<!-- PDF page 208; printed page 195 -->

```text
    %v15 = or i32 %v14, %v3
    %v16 = add nsw i32 %v5, 1
    %v17 = getelementptr inbounds [576 x i32], ptr %a0, i32 0, i32 %v16
    %v18 = load i32, ptr %v17, align 4, !tbaa !0
    %v19 = getelementptr inbounds [576 x i32], ptr %a0, i32 1, i32 %v16
    %v20 = load i32, ptr %v19, align 4, !tbaa !0
    %v21 = add nsw i32 %v20, %v18
    store i32 %v21, ptr %v17, align 4, !tbaa !0
    %v22 = sub nsw i32 %v18, %v20
    store i32 %v22, ptr %v19, align 4, !tbaa !0
    %v23 = tail call i32 @llvm.hexagon.A2.abs(i32 %v21)
    %v24 = or i32 %v23, %v13
    %v25 = tail call i32 @llvm.hexagon.A2.abs(i32 %v22)
    %v26 = or i32 %v25, %v15
    %v27 = add nsw i32 %v5, 2
    %v28 = getelementptr inbounds [576 x i32], ptr %a0, i32 0, i32 %v27
    %v29 = load i32, ptr %v28, align 4, !tbaa !0
    %v30 = getelementptr inbounds [576 x i32], ptr %a0, i32 1, i32 %v27
    %v31 = load i32, ptr %v30, align 4, !tbaa !0
    %v32 = add nsw i32 %v31, %v29
    store i32 %v32, ptr %v28, align 4, !tbaa !0
    %v33 = sub nsw i32 %v29, %v31
    store i32 %v33, ptr %v30, align 4, !tbaa !0
    %v34 = tail call i32 @llvm.hexagon.A2.abs(i32 %v32)
    %v35 = or i32 %v34, %v24
    %v36 = tail call i32 @llvm.hexagon.A2.abs(i32 %v33)
    %v37 = or i32 %v36, %v26
    %v38 = add nsw i32 %v5, 3
    %v39 = getelementptr inbounds [576 x i32], ptr %a0, i32 0, i32 %v38
    %v40 = load i32, ptr %v39, align 4, !tbaa !0
    %v41 = getelementptr inbounds [576 x i32], ptr %a0, i32 1, i32 %v38
    %v42 = load i32, ptr %v41, align 4, !tbaa !0
    %v43 = add nsw i32 %v42, %v40
    store i32 %v43, ptr %v39, align 4, !tbaa !0
    %v44 = sub nsw i32 %v40, %v42
    store i32 %v44, ptr %v41, align 4, !tbaa !0
    %v45 = tail call i32 @llvm.hexagon.A2.abs(i32 %v43)
    %v46 = or i32 %v45, %v35
    %v47 = tail call i32 @llvm.hexagon.A2.abs(i32 %v44)
    %v48 = or i32 %v47, %v37
    %v49 = add nsw i32 %v5, 4
    %v50 = icmp slt i32 %v49, %v2
    br i1 %v50, label %b3, label %b4
b4:                                               ; preds = %b3
    br label %b5
b5:                                               ; preds = %b4, %b1
    %v51 = phi i32 [ 0, %b1 ], [ %v49, %b4 ]
    %v52 = phi i32 [ 0, %b1 ], [ %v48, %b4 ]
    %v53 = phi i32 [ 0, %b1 ], [ %v46, %b4 ]
    %v54 = icmp eq i32 %v51, %a1
```

<!-- PDF page 209; printed page 196 -->

```text
    br i1 %v54, label %b9, label %b6
b6:                                               ; preds = %b5
    br label %b7
b7:                                               ; preds = %b7, %b6
    %v55 = phi i32 [ %v67, %b7 ], [ %v52, %b6 ]
    %v56 = phi i32 [ %v65, %b7 ], [ %v53, %b6 ]
    %v57 = phi i32 [ %v68, %b7 ], [ %v51, %b6 ]
    %v58 = getelementptr inbounds [576 x i32], ptr %a0, i32 0, i32 %v57
    %v59 = load i32, ptr %v58, align 4, !tbaa !0
    %v60 = getelementptr inbounds [576 x i32], ptr %a0, i32 1, i32 %v57
    %v61 = load i32, ptr %v60, align 4, !tbaa !0
    %v62 = add nsw i32 %v61, %v59
    store i32 %v62, ptr %v58, align 4, !tbaa !0
    %v63 = sub nsw i32 %v59, %v61
    store i32 %v63, ptr %v60, align 4, !tbaa !0
    %v64 = tail call i32 @llvm.hexagon.A2.abs(i32 %v62)
    %v65 = or i32 %v64, %v56
    %v66 = tail call i32 @llvm.hexagon.A2.abs(i32 %v63)
    %v67 = or i32 %v66, %v55
    %v68 = add nsw i32 %v57, 1
    %v69 = icmp eq i32 %v68, %a1
    br i1 %v69, label %b8, label %b7
b8:                                               ; preds = %b7
    br label %b9
b9:                                               ; preds = %b8, %b5, %b0
    %v70 = phi i32 [ 0, %b0 ], [ %v52, %b5 ], [ %v67, %b8 ]
    %v71 = phi i32 [ 0, %b0 ], [ %v53, %b5 ], [ %v65, %b8 ]
    %v72 = load i32, ptr %a2, align 4, !tbaa !0
    %v73 = or i32 %v72, %v71
    store i32 %v73, ptr %a2, align 4, !tbaa !0
    %v74 = getelementptr inbounds i32, ptr %a2, i32 1
    %v75 = load i32, ptr %v74, align 4, !tbaa !0
    %v76 = or i32 %v75, %v70
    store i32 %v76, ptr %v74, align 4, !tbaa !0
    ret void
}
; Function Attrs: nounwind readnone
declare i32 @llvm.hexagon.A2.abs(i32) #1
attributes #0 = { nounwind }
attributes #1 = { nounwind readnone }
!0 = !{!1, !1, i64 0}
!1 = !{!"int", !2}
!2 = !{!"omnipotent char", !3}
!3 = !{!"Simple C/C++ TBAA"}
```

通过命令 llc -march=hexagon -enable-pipeliner -enable-aa-sched-mi 8-12.ll 可得到基本块b7 在 SMS 调度前生成的 MIR，如代码清单 8-13 所示。其中，bb.5.b6 为 PreHeader 基本块，bb.6.b7 为循环体基本块，bb.7.b9 为循环退出基本块。

<!-- PDF page 210; printed page 197 -->

**代码清单 8-13 SMS 调度前的 MIR**

```text
bb.5.b6:
; predecessors: %bb.4
    successors: %bb.6(0x80000000); %bb.6(100.00%)

    %13:intregs = A2_sub %26:intregs, %10:intregs
    %14:intregs = S2_addasl_rrri %25:intregs, %10:intregs, 2
    %71:intregs = COPY %13:intregs
    J2_loop0r %bb.6, %71:intregs, implicit-def $lc0, implicit-def $sa0, implicit-
        def $usr

bb.6.b7 (machine-block-address-taken):
; predecessors: %bb.5, %bb.6

successors: %bb.7(0x04000000), %bb.6(0x7c000000); %bb.7(3.12%), %bb.6(96.88%)

    %15:intregs = PHI %14:intregs, %bb.5, %22:intregs, %bb.6
    %17:intregs = PHI %11:intregs, %bb.5, %20:intregs, %bb.6
    %18:intregs = PHI %12:intregs, %bb.5, %19:intregs, %bb.6
    %63:intregs = L2_loadri_io %15:intregs, 0 :: (load (s32) from %ir.lsr.iv1,
        !tbaa !0)
    %64:intregs = L2_loadri_io %15:intregs, 2304 :: (load (s32) from %ir.cgep23,
        !tbaa !0)
    %65:intregs = nsw A2_add %64:intregs, %63:intregs
    S2_storeri_io %15:intregs, 0, %65:intregs :: (store (s32) into %ir.lsr.iv1,
        !tbaa !0)
    %66:intregs = nsw A2_sub %63:intregs, %64:intregs
    S2_storeri_io %15:intregs, 2304, %66:intregs :: (store (s32) into %ir.cgep23,
        !tbaa !0)
    %67:intregs = A2_abs %65:intregs
    %19:intregs = A2_or %67:intregs, %18:intregs
    %68:intregs = A2_abs %66:intregs
    %20:intregs = A2_or %68:intregs, %17:intregs
    %22:intregs = A2_addi %15:intregs, 4
    ENDLOOP0 %bb.6, implicit-def $pc, implicit-def $lc0, implicit $sa0, implicit $lc0
    J2_jump %bb.7, implicit-def dead $pc

bb.7.b9:
; predecessors: %bb.4, %bb.6, %bb.8

    %23:intregs = PHI %28:intregs, %bb.8, %11:intregs, %bb.4, %20:intregs, %bb.6
    %24:intregs = PHI %28:intregs, %bb.8, %12:intregs, %bb.4, %19:intregs, %bb.6
    L4_or_memopw_io %27:intregs, 0, %24:intregs :: (store (s32) into %ir.a2,
        !tbaa !0), (load (s32) from %ir.a2, !tbaa !0)
    L4_or_memopw_io %27:intregs, 4, %23:intregs :: (store (s32) into %ir.cgep25,
        !tbaa !0), (load (s32) from %ir.cgep25, !tbaa !0)
    PS_jmpret $r31, implicit-def dead $pc
```

循环调度步骤如下。

1）将循环体基本块 bb.6.b7 的指令序列按照指令顺序编号为 SU[0]～SU[13]，并构建依赖图，如图 8-30 所示。其中虚线为跨迭代的 Anti 类型依赖，实线为访存操作的依赖边。

<!-- PDF page 211; printed page 198 -->

![图 8-30 针对循环指令建立的 SUnit 依赖图](assets/figures/p211-8-30.png)

**图 8-30 针对循环指令建立的 SUnit 依赖图**

2）使用约翰逊电路算法，找到依赖图中所有的递归（Recurrence）集合。这个实例中的递归集合为 {{SU[0], SU[13]}, {SU[1], SU[12]}, {SU[2], SU[10]}, {SU[3], SU[7],SU[8]}}。

3）计算 ResMII、RecMII 以及各节点的属性。其中 ResMII = 3，RecMII = 2，II = 3。各个 SUnit 节点的属性如表 8-47 所示。

**表 8-47 各个 SUnit 节点的属性值**

属性

SUnit

ASAP ALAP MOV Depth Height

SU[0] 0 0 0 0 3

SU[1] 0 3 3 0 1

SU[2] 0 3 3 0 1

SU[3] 0 0 0 0 3

SU[4] 0 0 0 0 3

SU[5] 1 1 0 1 2

SU[6] 1 3 2 1 0

SU[7] 1 1 0 1 2

SU[8] 1 3 2 1 0

SU[9] 2 2 0 2 1

SU[10] 3 3 0 3 0

SU[11] 2 2 0 2 1

SU[12] 3 3 0 3 0

SU[13] 0 3 3 1 0

<!-- PDF page 212; printed page 199 -->

4）将递归的集合按照 RecMII 从大到小排序。将递归集合没有包含的节点或存入已存在的递归集合中，或存入新的递归集合中，结果为 {{SU3, SU7, SU8}, {SU1, SU12, SU11}, {SU2, SU10, SU9, SU5}, {SU0, SU13, SU4}, {SU6}}。对所有的节点排序，结果为 {SU8, SU7, SU3, SU11, SU12, SU1, SU5, SU9, SU10, SU2, SU4, SU0, SU13, SU6}。

5）按照步骤 4 的排序结果进行指令调度。调度成功时 II = 3，整个基本块的指令处于 0和 1 两个阶段。表 8-48 显示了各个节点所处的不同阶段。

**表 8-48 调度阶段划分**

阶段 时钟周期 节点

0 SU3, SU4, SU0

0 1 SU8, SU7, SU5, SU13

2 SU11, SU9, SU6

1 3 SU12, SU1, SU10, SU2

6）根据步骤 5 的结果生成的并行化循环结果如代码清单 8-14 所示。其中，bb.9.b7 为Prologue 基本块，bb.10.b7 为 Kernel 基本块，bb.11 为 Epilogue 基本块。从结果可以看出，位于阶段 1 的 SU12 和 SU10（蓝色字体）被复制到 Epilogue 基本块中，其余节点被复制到Prologue 基本块中，并且 SU12 和 SU10 被移到了 Kernel 基本块开始的位置。此外，指令操作数和 φ 函数也被更新。

**代码清单 8-14 SMS 调度后的 IR**

```text
bb.9.b7:
; predecessors: %bb.5

successors: %bb.10(0x40000000), %bb.11(0x40000000); %bb.10(50.00%), %bb.11(50.00%)

    %74:intregs = L2_loadri_io %14:intregs, 0 :: (load (s32) from %ir.lsr.iv1,
        !tbaa !0)
    %75:intregs = L2_loadri_io %14:intregs, 2304 :: (load (s32) from %ir.cgep23,
        !tbaa !0)
    %76:intregs = nsw A2_add %75:intregs, %74:intregs
    S2_storeri_io %14:intregs, 0, %76:intregs :: (store (s32) into %ir.lsr.iv1,
        !tbaa !0)
    %77:intregs = nsw A2_sub %74:intregs, %75:intregs
    S2_storeri_io %14:intregs, 2304, %77:intregs :: (store (s32) into %ir.cgep23,
        !tbaa !0)
    %78:intregs = A2_abs %76:intregs
    %79:intregs = A2_abs %77:intregs
    %80:intregs = A2_addi %14:intregs, 4
    %102:predregs = C2_cmpgtui %71:intregs, 1
    %103:intregs = A2_addi %71:intregs, -1
    J2_loop0r %bb.10, %103:intregs, implicit-def $lc0, implicit-def $sa0,
        implicit-def $usr
```

<!-- PDF page 213; printed page 200 -->

```text
    J2_jumpf %102:predregs, %bb.11, implicit-def $pc
    J2_jump %bb.10, implicit-def $pc

bb.10.b7:
; predecessors: %bb.9, %bb.10

successors: %bb.11(0x04000000), %bb.10(0x7c000000); %bb.11(3.12%), %bb.10(96.88%)

    %90:intregs = PHI %80:intregs, %bb.9, %87:intregs, %bb.10
    %91:intregs = PHI %11:intregs, %bb.9, %81:intregs, %bb.10
    %92:intregs = PHI %12:intregs, %bb.9, %82:intregs, %bb.10
    %93:intregs = PHI %78:intregs, %bb.9, %89:intregs, %bb.10
    %94:intregs = PHI %79:intregs, %bb.9, %88:intregs, %bb.10
    %81:intregs = A2_or %94:intregs, %91:intregs
    %82:intregs = A2_or %93:intregs, %92:intregs
    %83:intregs = L2_loadri_io %90:intregs, 0 :: (load (s32) from %ir.lsr.iv1 + 4,
        !tbaa !0)
    %84:intregs = L2_loadri_io %90:intregs, 2304 :: (load (s32) from %ir.cgep23
        + 4, !tbaa !0)
    %85:intregs = nsw A2_sub %83:intregs, %84:intregs
    S2_storeri_io %90:intregs, 2304, %85:intregs :: (store (s32) into %ir.cgep23
        + 4, !tbaa !0)
    %86:intregs = nsw A2_add %84:intregs, %83:intregs
    %87:intregs = A2_addi %90:intregs, 4
    %88:intregs = A2_abs %85:intregs
    %89:intregs = A2_abs %86:intregs
    S2_storeri_io %90:intregs, 0, %86:intregs :: (store (s32) into %ir.lsr.iv1 + 4,
        !tbaa !0)
    ENDLOOP0 %bb.10, implicit-def $pc, implicit-def $lc0, implicit $sa0, implicit
        $lc0
    J2_jump %bb.11, implicit-def $pc

bb.11:
; predecessors: %bb.10, %bb.9
    successors: %bb.7(0x80000000); %bb.7(100.00%)

    %98:intregs = PHI %11:intregs, %bb.9, %81:intregs, %bb.10
    %99:intregs = PHI %12:intregs, %bb.9, %82:intregs, %bb.10
    %100:intregs = PHI %78:intregs, %bb.9, %89:intregs, %bb.10
    %101:intregs = PHI %79:intregs, %bb.9, %88:intregs, %bb.10
    %95:intregs = A2_or %100:intregs, %99:intregs
    %96:intregs = A2_or %101:intregs, %98:intregs
    J2_jump %bb.7, implicit-def $pc

bb.7.b9:
......
```

## 8.11 扩展阅读：调度算法的影响因素

寄存器分配前（Pre-RA）和分配后（Post-RA）的指令调度需要考虑的指令优先级的影

<!-- PDF page 214; printed page 201 -->

响因素有较大的差异。寄存器分配前的调度算法主要关注指令的流水性能，因此影响其调度优先级的因素主要包括关键路径（高度、深度、时延、关键资源、必需资源）、停滞周期。而寄存器分配后的调度算法除了要考虑指令的流水性能外，还需要关注寄存器分配的压力（寄存器压力值、Sethi-Ullman 数值、BiasPhysReg、PredsNumLeft）。

读者可能会比较关心在实际的开发构建过程中，到底该选择什么样的调度算法，从而让自己的软件达到最优性能？

寻找最优的指令调度是一个 NP（非确定性多项式时间）完全问题。就笔者经验而言，一般在编译器后端的设计过程中，寄存器分配前的调度算法会优先考虑重排的指令序列对寄存器分配压力的影响，寄存器分配后的调度算法则会专注于指令的流水性能。但因为不同的调度算法的计算指令优先级差异，在不同的场景中效果也有差异。开发者可以直接选择 LLVM 中不同的调度算法及组合来验证自己的场景，也可以基于 LLVM 的框架选择适合自己场景的启发式因素来实现新的调度算法。

有学者将影响调度算法的启发式因素细分为 24 种，并基于 LLVM 在 SPEC CPU 2017整型和浮点类型的基准测试集上进行了实验，论文为“ A Comparision of List Scheduling Heuristics in LLVM Targeting POWER8”。这 24 种启发式因素中有一些已经在本章介绍LLVM 调度算法时使用，比如寄存器分配压力相关的 rp max、rp critical、rp excess 等，也有一些是作者自己设计的，比如 dispatch、rb、slack、delaySucc 等，这些启发式因素的含义及具体的计算方法可以参考论文的详细介绍，这里就不展开了。我们直接引用论文中的实验数据和结论。

**图 8-31 为 SPEC 2017 整型基准测试的结果，图 8-32 为 SPEC 2017 浮点型基准测试的**

结果。其中，generic 是 LLVM 提供的调度信息，它组合了其他的因素。纵坐标为影响指令调度的 24 个启发式因素，横坐标为采用某种启发式因素进行指令调度后的性能和基线性能的对比（百分比）。结果为负则表明调度后性能比基线性能差。这里的基线性能就是程序按照默认指令顺序执行的性能。

在整型基准测试结果中，只有反映寄存器分配压力的 rp critical 和 rp excess 因素会让指令调度后的性能稍微超过基线。使用反映寄存器分配压力的 rp max 和指令流水的 dispatch作为启发式因素调度后，性能接近基线性能。使用其余的启发式因素则比基线性能下降2%～6%。

浮点型基准测试结果有些超越了基线性能，有些则比基线性能差。和整型基准测试结果相比，几乎所有的启发式因素在浮点型基准测试集中表现更好。

另外，作者还对这 24 种启发式因素试验了 22 种组合的调度性能。本书中同样直接引用了论文的结论：总体而言，寄存器分配压力、关键路径、停滞行为（Stall Behavior）在整型和浮点型的基准测试中有比较好的性能表现，其他的启发因素在整型基准测试中的性能表现出色，但在浮点型的基准测试中反而性能较差，反之亦然。

<!-- PDF page 215; printed page 202 -->

![图 8-31 SPEC 2017 整型基准测试的结果](assets/figures/p215-8-31.png)

**图 8-31 SPEC 2017 整型基准测试的结果**

![图 8-32 SPEC 2017 浮点型基准测试的结果](assets/figures/p215-8-32.png)

**图 8-32 SPEC 2017 浮点型基准测试的结果**

<!-- PDF page 216; printed page 203 -->

## 8.12 本章小结

本章着重介绍了 LLVM 中指令调度相关的不同算法的原理和实现，包括 Linearize 调度 器、Fast 调 度 器、BURR List 调 度 器、Source List 调 度 器、Hybrid 调 度 器、Pre-RA- MISched 调度器、Post-RA-TDList 调度器、Post-RA-MISched 调度器，并在最后对影响调度算法的因素进行了简单的介绍。
