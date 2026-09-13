# 第四部分扉页与导读校订记录

来源：`insider-compiler-ch14-end.pdf` 第 1 页。保留扉页标题、三段导读及其论述顺序，正文见[第四部分](../insider-compiler-part4.md)。本页没有编号清单、图表或原书脚注。

## 页码与目视

已目视原始扫描页，修复 `Prt a` 等装饰文字误识别。该页及下一页第 14 章章首页都未印页码，PDF 第 3 页印有 369，因此分别推定为书页 367、368；没有把推定页码写成原页印刷事实。

## 内容修正

1. 原书称 Linalg 主要用于实现线性代数算法。保留其矩阵运算例子，并补充“其他结构化计算”，对应本地 [Linalg 文档](/opt/llvm-project/mlir/docs/Dialects/Linalg/_index.md)的结构化操作抽象。
2. 原书把多面体循环优化一概归为连续凸优化。改为整数迭代域、仿射关系和约束分析；[IntegerRelation.h](/opt/llvm-project/mlir/include/mlir/Analysis/Presburger/IntegerRelation.h:37)明确区分凸多面体与其中的整数点。具体数学反例见[第 14 章独立复核](evidence/ch14/math-foundations-review.md)。
3. 原书没有提供 Google FHE 项目的精确名称。本地 LLVM 不含该项目的背景依据，因此仅补查官方仓库：[HEIR](https://github.com/google/heir)明确自述为基于 MLIR 的同态加密编译工具链；[Google FHE 仓库](https://github.com/google/fully-homomorphic-encryption)也单列 HEIR，并把旧 Transpiler 放在历史工具部分。正文明确以 HEIR 作可核实的例子，未声称它必然就是原书所指的项目。核对日期：2026-09-13；未下载或运行这些外部项目。

没有把新补充的来源链接伪装成原书脚注。第 1～13 章及此前导读正文保持不变。
