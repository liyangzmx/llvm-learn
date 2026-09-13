# 第 3 章静态校核记录

基线：原书 LLVM 15.0.1 → 本地 LLVM 18.1.8，HEAD `3b5b5c1ec4a3095ab096dd780e84d7ab81f3d7ff`。完整阅读原章及相应实现；未编译或执行任何示例。原图保留为历史对照，正文覆盖修正。

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

## 限制

- 算法讲解、手写伪代码和原书截图已与实现边界区分；本次不声称编译通过或获得示例输出。
- LLVM IR 已修复可静态确认的语法/版本问题，完整解析、MIR verifier、Pass触发、汇编字节和性能留待后续。
- 源码中的目标钩子、功能属性和选项会改变具体流水线，通用 Pass 次序不能当作所有目标的无条件次序。
