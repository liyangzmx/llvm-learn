# 第 3 章核查与实验记录

基线为 LLVM 18.1.8，源码提交 `3b5b5c1ec4a3095ab096dd780e84d7ab81f3d7ff`。全文按源码和本章实验修订；工具来自统一更新后的 Debug / assertions 构建。本文区分真实工具输出、教学算法模型和仅按源码核对的接口。

| 范围 | 核查位置/符号 | 结论与处理 |
|---|---|---|
| 3.1.1 | 半格代数定义；Clang DataFlowAnalysisIntro | 运算≠关系，修上下界严格比较、meet/join、顶底及偏序证明。 |
| 3.1.2/图3-1 | 幂集格；DataFlowAnalysisIntro | 补双运算吸收律、∅与全集、完备性不推出任意迭代终止；Mermaid修符号。 |
| 3.1.3 | 不动点定义与有限高度迭代；同上 | 自映射不要求满射；区分Tarski存在性、Kleene连续性版本与ACC/DCC有限终止。 |
| 3.2/表3-1～3-2/清单3-1 | DataFlowAnalysisIntro:278 | 方程转为可读表；统一join信息序、边界条件和顶初值；CFG方向不等于格方向。 |
| 3.2.1/清单3-2/图3-3～3-4 | 平坦常量格 / ValueLattice.h | 数学整数伪码与C int区分；无限元素有限高度，±∞不是整数元素，⊥不是源语言undef。 |
| 3.2.2/清单3-3/图3-5～3-6 | 单调性与分配律；DataFlowAnalysisIntro | 空路径id；修Ideal≤MOP≤MFP方向、条件假设、不总不可计算、复杂度需域高度；图3-6乱序恢复Mermaid。 |
| 3.3.1/清单3-4/表3-3 | LiveVariables.cpp + 原图3-7方程计算 | 修LiveUse E/D含已定义值、出口活跃≠整块活跃；保留完整稳定解与迭代变化。 |
| 3.3.2/清单3-5～3-6/表3-4 | ReachingDefAnalysis + 原图3-8 | Gen/Kill集合元素是定义点，GEN需到块尾；修B第一轮漏s3，补F；经典方程不直接等于LLVM实现。 |
| 3.3.3/清单3-7～3-8/表3-5 | ValueLattice / SCCPSolver | 修赋值覆盖、i++可常量折叠、S5最终flag=1；条件常量传播并非复制传播。 |
| 3.4～3.5 | PostOrderIterator | DFS/BFS同阶复杂度；RPO前驱优先仅无环保证，CFG不必有环。 |

## 证据定位

- [clang/docs/DataFlowAnalysisIntro.md:72](/opt/llvm-project/clang/docs/DataFlowAnalysisIntro.md:72)：`join-semilattice and concrete-value domain`。
- [clang/docs/DataFlowAnalysisIntro.md:278](/opt/llvm-project/clang/docs/DataFlowAnalysisIntro.md:278)：`fixpoint / finite-height termination / worklist`。
- [llvm/include/llvm/Analysis/ValueLattice.h:24](/opt/llvm-project/llvm/include/llvm/Analysis/ValueLattice.h:24)：`ValueLatticeElement state kinds`。
- [llvm/lib/Transforms/Utils/SCCPSolver.cpp:556](/opt/llvm-project/llvm/lib/Transforms/Utils/SCCPSolver.cpp:556)：`SCCPSolver / markEdgeExecutable`。
- [llvm/lib/CodeGen/LiveVariables.cpp:17](/opt/llvm-project/llvm/lib/CodeGen/LiveVariables.cpp:17)：`SSA virtual-register live analysis / PHI handling`。
- [llvm/lib/CodeGen/ReachingDefAnalysis.cpp:262](/opt/llvm-project/llvm/lib/CodeGen/ReachingDefAnalysis.cpp:262)：`getReachingDef / getGlobalReachingDefs`。
- [llvm/include/llvm/ADT/PostOrderIterator.h:295](/opt/llvm-project/llvm/include/llvm/ADT/PostOrderIterator.h:295)：`ReversePostOrderTraversal`。

## 已执行覆盖与结论

| 本章位置 | 可复现实验 | 实际观察 |
|---|---|---|
| 3.1 / 3-1 | 穷举四元素幂集格的全部自映射 | 256 个映射中 36 个单调；从底/顶迭代分别等于枚举出的最小/最大不动点。单调的交换映射从中间点可循环。 |
| 3-2～3-3 / 3.2 | 平坦常量域与非关系乘积域 | 两条路径先算和得到 5，先合并变量则得到 ⊤；正文明确分析域和边过滤条件。 |
| 3-4 / 表3-3 | 活跃性迭代与独立先用后定义路径搜索 | 所有块 LiveIn/LiveOut 逐项一致；G,F,E,D,C,B,A 顺序共三轮，含最终无变化检查。 |
| 3-5～3-6 / 表3-4 | 定义点集合迭代与逐定义穿透搜索 | B.Out={s3,s4,s5,s6,s7}，F.Out={s5,s6,s7,s8}；3 轮含最终检查。 |
| 3-7～3-8 / 表3-5 | 密集常量传播 | S5.Out=(⊤,1)，S7.Out=(⊤,⊤)，赋值覆盖旧值。 |
| 3-3 / 3-8 | Clang → mem2reg,sccp,simplifycfg,verify → lli interpreter | 平方分支返回 0；循环返回 11；关系示例两个分支都返回 5。前后语义一致；SCCP 删除 i++，但出口仍保留 10+flag，并未直接 ret 11。 |

脚本与输入见 `experiments/ch3/`，实际命令和版本见 [experiments-ch3.json](experiments-ch3.json)。有限枚举检验模型与算法实现，不代替任意格上的证明。终止性明确要求从相应极值开始、单调性和链条件；没有测量遍历顺序的真实编译性能。

正文还修正了具体状态与抽象状态的区别、ADCE 的必要性追溯、局部控制流方程的前提，以及常量传播后仍可能需要物化常量的情况。
