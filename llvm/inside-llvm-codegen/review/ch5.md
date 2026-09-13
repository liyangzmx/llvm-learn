# 第 5 章静态校对记录

- 原书：LLVM 15.0.1。校订基线：本地 `/opt/llvm-project`，LLVM 18.1.8，提交 `3b5b5c1ec4a3095ab096dd780e84d7ab81f3d7ff`。
- 方法：完整阅读本章原文，逐清单与涉及的本地实现 / 同版本文档对照，直接修正全文。未编译 LLVM，未运行 C/C++、TableGen、IR/MIR、lit 或性能测试。
- 校订全文：[inside-llvm-codegen-ch5.md](../inside-llvm-codegen-ch5.md)。原始转写和原图裁剪保留在 origin，完整版面见原 PDF。

## 逐代码清单核查

| 清单 | LLVM 18 证据（行号以基线为准） | 结论与处理 |
| --- | --- | --- |
| 5-1 | `llvm/docs/LoopTerminology.rst:501`（Loops are rotated by）；`llvm/lib/Transforms/Utils/LoopRotationUtils.cpp:406`（bool LoopRotate::rotateLoop(） | C 示例的循环和算术关系保留；未生成 IR。图 5-12b 在无法证明至少执行一次时不是等价替换，正文强调 n ≤ 0 的 guard 及独立 dedicated exit。 |
| 5-2 | `llvm/docs/LoopTerminology.rst:321`（X3 = phi(X1, X2);  // X3 defined）；`llvm/lib/Transforms/Utils/LCSSA.cpp:77`（bool llvm::formLCSSAForInstructions） | 确认 X3 是逃逸值。明确这是 C / SSA 混合伪代码，不是可独立解析的 LLVM IR；跨页代码合并，完整 IR 需补零次迭代路径和 PHI 入边。 |
| 5-3 | `llvm/docs/LoopTerminology.rst:340`（X4 = phi(X3);）；`llvm/lib/Transforms/Utils/LCSSA.cpp:151`（Insert the LCSSA phi） | 出口 PHI 转接循环外使用，incoming use 在 LCSSA 中归于循环内前驱；伪代码保留，说明必须保持 LCSSA 的 Pass 不能任意删去这些 PHI。 |

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

## 限制与后续验证

本章仅作源码和文档静态核查。后续需由清单 5-1 生成完整 IR 并确定 Pass 流水线，观察零次 / 一次 / 多次迭代；清单 5-2、5-3 先补为 verifier 可接受的 IR。原图不作为 LLVM 18 输出断言。原书引用的论文作为文献保留，未联网检索或宣称重新核对论文。
