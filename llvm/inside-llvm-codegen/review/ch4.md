# 第 4 章核查与实验记录

基线为 LLVM 18.1.8，源码提交 `3b5b5c1ec4a3095ab096dd780e84d7ab81f3d7ff`。全文按源码和本章实验修订；工具来自统一更新后的 Debug / assertions 构建。本文区分真实工具输出、教学算法模型和仅按源码核对的接口。

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
| 4.4 | 上述全部源码 | 本章理论与 LLVM 分析交叉验证，精度和复杂度的前提分别说明。 |

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

## 已执行覆盖与结论

| 本章位置 | 可复现实验 | 实际观察 |
|---|---|---|
| 4.1 / 表4-1 | `graph7.ll`，print<domtree> / print<domfrontier> | 解析 LLVM 输出，所有 idom 与 DF 集合和表格一致。 |
| 4.1 / PDT | `postdom-roots.ll` | 两个 ret 与无限自环；LLVM PDT 有虚拟根，Roots 包含 exit1/exit2/spin。 |
| 4.2 / 4.3 | 四节点有向图穷举 | 4,096 个无入口入边图中 2,432 个全部可达；删除节点法、Dom 集合、定义式 semi+NCA 全部一致；允许非入口自环。 |
| 4.2.1～4.2.2 / 图4-6 | 完整六节点图与固定 DFS 次序 | sdom(4)=1，但 idom(4)=0；路径0→5→3→4绕开1。正文给出全部边，不依赖隐含图信息。 |
| 4-1 | 直接 DF 定义与 DJ 子树扫描 | 上述 2,432 个图中逐节点一致。 |
| 4.2 / 增量概念 | 图4-2增加5→6后重算 | idom(6)由2改为1，演示边改变语义；不是调用增量 API 的覆盖测试。 |
| 4.2.3 / IDF | `join-loop.ll` → mem2reg,verify | join 与 header 各一个 PHI，显示新 PHI 定义引出进一步汇聚。 |

脚本与输入见 `experiments/ch4/`，命令和版本见 [experiments-ch4.json](experiments-ch4.json)。小规模枚举是交叉验证，不是对任意输入的数学证明；高效 link/eval 仍按 LLVM 源码说明，不声称 Python 模型实现 LLVM 的全部优化。没有测量历史性能百分比，也未穷举 DomTreeUpdater 的增量 API 序列。
