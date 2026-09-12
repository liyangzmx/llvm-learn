# GLM 检查意见的独立复核与处理

复核日期：2026-09-13。检查输入：[glmcheck.md](glmcheck.md)。基准仍是 `/opt/llvm-project` 的 `release/18.x` / `3b5b5c1ec4a3095ab096dd780e84d7ab81f3d7ff`。

本轮先初始化 Git 并保存修订前快照 `b135529`，再修改教材。原检查清单与上游 LLVM 源码均未修改。

## 1. benefit 的适用范围：采纳

原句“本地 benefit=1”紧接通用规范化说明，范围确实不够清楚。它对 C++ 双重转置模式成立，但不能描述全部 DRR 规则。

核对依据：

- [ToyCombine.cpp](/opt/llvm-project/mlir/examples/toy/Ch3/mlir/ToyCombine.cpp:29)：SimplifyRedundantTranspose 构造函数显式使用 benefit=1。
- [Pattern::getBenefit()](/opt/llvm-project/mlir/lib/TableGen/Pattern.cpp:699)：以源模式的 getNumOps() 为初始值，再加 benefitDelta。
- [PatternBase.td](/opt/llvm-project/mlir/include/mlir/IR/PatternBase.td:92)：默认增量为 addBenefit 0。
- [ToyCombine.td](/opt/llvm-project/mlir/examples/toy/Ch3/mlir/ToyCombine.td:34)：三个 reshape 规则均未显式增加收益。

因此 RedundantReshapeOptPattern、ReshapeReshapeOptPattern、FoldConstantReshapeOptPattern 的收益依次是 1、2、2。这里统计的是源模式的**操作节点**，不是 operands 的数量。已在扩充版第 3 章 §8.1 增加适用范围、计算来源与对照表，并保留“收益是相对排序指标，不是性能测量”的说明。

这不推翻上一轮对 ds4.1 的判断：当时教材确实介绍过 benefit，且 C++ 构造函数默认值为 1。GLM 指出的是另一点——不应把 C++ 模式的数值泛化为 DRR 的默认规则；这点成立。

## 2. 第 6 章目录地图：采纳完善建议

核对 [Ch6/include/toy](/opt/llvm-project/mlir/examples/toy/Ch6/include/toy)，MLIRGen.h、ShapeInferenceInterface.h 和 ShapeInferenceInterface.td 均存在。原图是教学地图，省略文件不构成算法错误，但补充这三个入口能帮助读者找到生成器和接口定义。

已在第 0 章目录图中补入，并明确该图仍省略各层 CMakeLists.txt，不声称是目录的逐项完整清单。

## 3. 验证和范围

修订后运行 `node scripts/validate-materials.mjs` 和 `node scripts/validate-materials.test.mjs`，主校验、正常基线及三个内存变异拒绝场景均通过。127 个源码类代码块的分类未变；official 正文在对应扩充章节中的包含关系仍成立。

本轮只针对两项意见独立对照了相关源码，不将 GLM 报告列出的其他全部抽查项重新声称为本轮逐项验证。未构建 LLVM、执行 JIT/FileCheck 或进行 Mermaid 渲染验收。
