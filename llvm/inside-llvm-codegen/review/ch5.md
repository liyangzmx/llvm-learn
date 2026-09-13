# 第 5 章核查与实验记录

- 原书：LLVM 15.0.1。校订基线：本地 `/opt/llvm-project`，LLVM 18.1.8，提交 `3b5b5c1ec4a3095ab096dd780e84d7ab81f3d7ff`。
- 方法：基线为 LLVM 18.1.8，源码提交 `3b5b5c1ec4a3095ab096dd780e84d7ab81f3d7ff`。全文按源码和本章实验修订；工具来自统一更新后的 Debug / assertions 构建。本文区分真实工具输出、教学算法模型和仅按源码核对的接口。
- 校订全文：[inside-llvm-codegen-ch5.md](../inside-llvm-codegen-ch5.md)。原始转写和原图裁剪保留在 origin，完整版面见原 PDF。

## 逐代码清单核查

| 清单 | LLVM 18 证据（行号以基线为准） | 结论与处理 |
| --- | --- | --- |
| 5-1 | `llvm/docs/LoopTerminology.rst:501`（Loops are rotated by）；`llvm/lib/Transforms/Utils/LoopRotationUtils.cpp:406`（bool LoopRotate::rotateLoop(） | C 示例已生成 IR，运行 LoopRotate 并验证循环/支配树；n=-1/0/1/5/8/12 前后返回1/1/1/120/40320/479001600。图 5-12b 在无法证明至少执行一次时不是等价替换，正文强调 n ≤ 0 的 guard 及独立 dedicated exit。 |
| 5-2 | `llvm/docs/LoopTerminology.rst:321`（X3 = phi(X1, X2);  // X3 defined）；`llvm/lib/Transforms/Utils/LCSSA.cpp:77`（bool llvm::formLCSSAForInstructions） | 改写为完整 @closed LLVM IR；循环头 last 取初值7或前次x3，并在出口使用。llvm-as/verifier 通过，显式覆盖零次迭代。 |
| 5-3 | `llvm/docs/LoopTerminology.rst:340`（X4 = phi(X3);）；`llvm/lib/Transforms/Utils/LCSSA.cpp:151`（Insert the LCSSA phi） | 实际 lcssa,verify 输出新增 last.lcssa 单输入 PHI，出口 add 改用该值；前后解释执行得到11/24/14，必须保持 LCSSA 的 Pass 不能任意删除相应PHI。 |

## 算法与正文核查

| 项目 | 证据 | 结论与处理 |
| --- | --- | --- |
| SCC 与自然循环 | `llvm/docs/LoopTerminology.rst:17`（A loop is a subset）；`llvm/docs/LoopTerminology.rst:80`（A single block that has no branch） | 强连通需要互达路径，不要求直接有边；不同 SCC 可单向可达。自然循环最大性在固定 header 下定义，允许嵌套，不等同全 CFG 极大 SCC。 |
| 不可归约范围 | `llvm/docs/LoopTerminology.rst:264`（LoopInfo does not contain）；`llvm/include/llvm/Analysis/CycleAnalysis.h:26`（class CycleInfoWrapperPass） | LoopInfo 不覆盖所有 cycle；移除“现代编译器只支持自然循环 / 不可归约一般不优化”的绝对推论。 |
| 回边与自然循环集合 | `llvm/include/llvm/Support/GenericLoopInfoImpl.h:566`（void LoopInfoBase<BlockT, LoopT>::analyze(）；`llvm/include/llvm/Support/GenericLoopInfoImpl.h:447`（static void discoverAndMapSubloop(） | 回边目标支配来源；h 单独纳入集合，其他节点逆向到达 latch 且不越过 h，同 header 回边合并。 |
| 循环节点角色 | `llvm/docs/LoopTerminology.rst:44`（An **entering block**）；`llvm/docs/LoopTerminology.rst:54`（An **exiting edge**） | exit 是 exiting 的循环外后继，原书 entering 为错误；header 唯一，其他角色可多、可合并，也可能没有退出。 |
| preheader | `llvm/include/llvm/Support/GenericLoopInfoImpl.h:199`（BlockT *LoopBase<BlockT, LoopT>::getLoopPreheader() const） | 不仅唯一循环外前驱，还须允许外提且仅有一条到 header 的后继边；区分 getLoopPredecessor。 |
| LoopInfo 构建 | `llvm/include/llvm/Support/GenericLoopInfoImpl.h:566`（void LoopInfoBase<BlockT, LoopT>::analyze(）；`llvm/include/llvm/Support/GenericLoopInfoImpl.h:456`（ReverseCFGWorklist(Backedges.begin()） | 支配树 post_order；初始工作项为 latch，不是 header；跳过入口不可达块。已发现子循环从其 header 前驱继续，随后 PopulateLoopsDFS 填列表。 |
| LoopSimplify | `llvm/lib/Transforms/Utils/LoopSimplify.cpp:478`（static bool simplifyOneLoop(）；`llvm/lib/Transforms/Utils/LoopSimplify.cpp:26`（contains or is entered by an indirectbr） | preheader、单回边、dedicated exits 三条件；多回边可分离嵌套或汇合；清理不可达前驱边不等于删所有不可达块，indirectbr 等可使规范化失败。 |
| 旋转谓词与变换 | `llvm/include/llvm/Analysis/LoopInfo.h:307`（bool isRotatedForm() const）；`llvm/lib/Transforms/Utils/LoopRotationUtils.cpp:406`（bool LoopRotate::rotateLoop(） | isRotatedForm 仅检查唯一 latch 为 exiting，不保证整个 LoopSimplify 形式。旋转受结构 / 成本限制；guard 仅在必要时保留或建立。 |
| LCSSA 构造 | `llvm/lib/Transforms/Utils/LCSSA.cpp:77`（bool llvm::formLCSSAForInstructions）；`llvm/lib/Transforms/Utils/LCSSA.cpp:519`（PreservedAnalyses LCSSAPass::run(）；`llvm/include/llvm/Analysis/LoopInfo.h:319`（bool isLCSSAForm(） | 说明普通值、PHI 边上使用、token 例外和冗余 PHI 保留要求；值范围等优化仍需分析循环。 |
| LCSSA 验证 | `llvm/include/llvm/Analysis/LoopPass.h:124`（struct LCSSAVerificationPass）；`llvm/lib/Analysis/LoopPass.cpp:241`（FIXME: Loop-sink currently break LCSSA.）；`llvm/lib/Transforms/Utils/LCSSA.cpp:464`（if (VerifyLoopLCSSA)） | LCSSAVerificationPass::runOnFunction 只返回 false，为旧管理器标记；其显式逐循环 assert 在 LLVM 18 的 #if 0 中。LCSSAWrapperPass::verifyAnalysis 等仍有受配置控制的实际验证。不是循环不变值分析。 |

## 已执行覆盖与边界

- `multi-latch.ll` 同时缺 preheader、有两条回边、exit 有外部前驱。LoopSimplify 后重新从 CFG 和支配关系检查三项性质，全部满足；前后解释执行均得到0/5/10/0。
- `book-loop.c` 实际旋转后，for.body 是 header，for.inc 是 latch/exiting，入口 guard 与 dedicated exit 分离。零次、一次、多次迭代值均验证，输入未越过 C 有符号算术范围。
- `lcssa.ll` 的完整函数及输出分别对应清单5-2/5-3，覆盖0/1/4次迭代与两个选择值。
- `nested.ll` 打印自然循环深度1/2；`irreducible.ll` 的双入口环合法，但未被 LoopInfo 表示为自然循环。

运行 `llvm-as`、IR verifier、支配树和 LoopInfo verifier；纯 IR 值语义用 lli interpreter。命令、版本和输出性质见 [experiments-ch5.json](experiments-ch5.json)。实验没有把“普通分支样例可规范化”推广为任意合法 CFG 都能成功，也没有测量目标性能。旧 Pass Manager 的 LCSSAVerificationPass 只按源码说明，本章实验使用新管理器。
