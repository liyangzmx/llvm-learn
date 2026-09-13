# 第 4 章静态校核记录

基线：原书 LLVM 15.0.1 → 本地 LLVM 18.1.8，HEAD `3b5b5c1ec4a3095ab096dd780e84d7ab81f3d7ff`。完整阅读原章及相应实现；未编译或执行任何示例。原图保留为历史对照，正文覆盖修正。

| 范围 | 核查位置/符号 | 结论与处理 |
|---|---|---|
| 4.1.1/表4-1 | GenericDomTree / CFG定义 | 单入口与虚拟入口区分、proper翻译、idom排除自身、DF可含自身、PDT无限循环根处理。 |
| 4.1.2/图4-4 | GenericDomTree + ReverseIDFCalculator | 修执行方向：A支配B不推出执行A必执行B；控制依赖不要求直接后继/最近分支；补支配外的数据移动条件。 |
| 4.2总述 | GenericDomTreeConstruction:10 | LLVM18 Semi-NCA完整构建与Depth Based Search增量区分，历史性能/版本叙述不当当前验证结果。 |
| 4.2.1/图4-5～4-6 | SemiNCAInfo::runDFS/runSemiNCA | 修DFS树/前向/交叉边定义；semi内部节点编号必须大于终点而非起点，旁排破碎公式重排。 |
| 4.2.2 | runSemiNCA:271 | 去混用n/u/w错误LT公式并解释bucket/link/eval和修正；Semi-NCA NCA在支配关系中，给与源码相符两阶段伪码。 |
| 4.2.3/清单4-1 | DominanceFrontierImpl / GenericIteratedDominanceFrontier | DF与IDF区分；祖先边界有条件、完整DF可能二次规模；补初始化/遍历后继/返回值并修拼写。 |
| 4.3.1/表4-2 | GenericDomTreeConstruction注释+集合方程 | OUT并自身而非交自身；补全Dom初始化；区分显式Dom O(n²)空间与idom链。 |
| 4.3.2/图4-7/表4-3 | dominates / updateDFSNumbers | 区间来自DT不是CFG；补32慢查询阈值、不可达特殊规则和编号失效；表重新对齐。 |
| 4.4 | 上述全部源码 | 无编译命令，本章算法示例为理论/说明性内容，静态核对完成。 |

## 证据定位

- [llvm/include/llvm/Support/GenericDomTreeConstruction.h:10](/opt/llvm-project/llvm/include/llvm/Support/GenericDomTreeConstruction.h:10)：`Semi-NCA and Depth Based Search overview`。
- [llvm/include/llvm/Support/GenericDomTreeConstruction.h:271](/opt/llvm-project/llvm/include/llvm/Support/GenericDomTreeConstruction.h:271)：`SemiNCAInfo::runSemiNCA`。
- [llvm/include/llvm/Support/GenericDomTreeConstruction.h:347](/opt/llvm-project/llvm/include/llvm/Support/GenericDomTreeConstruction.h:347)：`FindRoots / infinite-loop handling`。
- [llvm/include/llvm/Support/GenericDomTree.h:432](/opt/llvm-project/llvm/include/llvm/Support/GenericDomTree.h:432)：`dominates / SlowQueries`。
- [llvm/include/llvm/Support/GenericDomTree.h:747](/opt/llvm-project/llvm/include/llvm/Support/GenericDomTree.h:747)：`updateDFSNumbers`。
- [llvm/include/llvm/Analysis/DominanceFrontierImpl.h:158](/opt/llvm-project/llvm/include/llvm/Analysis/DominanceFrontierImpl.h:158)：`ForwardDominanceFrontierBase::calculate`。
- [llvm/include/llvm/Support/GenericIteratedDominanceFrontier.h:130](/opt/llvm-project/llvm/include/llvm/Support/GenericIteratedDominanceFrontier.h:130)：`IDFCalculatorBase::calculate`。
- [llvm/lib/Transforms/Utils/PromoteMemoryToRegister.cpp:730](/opt/llvm-project/llvm/lib/Transforms/Utils/PromoteMemoryToRegister.cpp:730)：`IDF and live-in PHI placement`。
- [llvm/lib/Transforms/Scalar/ADCE.cpp:493](/opt/llvm-project/llvm/lib/Transforms/Scalar/ADCE.cpp:493)：`ReverseIDFCalculator / control dependence`。

## 限制

- 算法讲解、手写伪代码和原书截图已与实现边界区分；本次不声称编译通过或获得示例输出。
- LLVM IR 已修复可静态确认的语法/版本问题，完整解析、MIR verifier、Pass触发、汇编字节和性能留待后续。
- 源码中的目标钩子、功能属性和选项会改变具体流水线，通用 Pass 次序不能当作所有目标的无条件次序。
