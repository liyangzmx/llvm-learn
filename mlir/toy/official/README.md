# MLIR Toy 官方教程中文译编（本地源码校准版）

本目录按官方七章的主题顺序，将教程主线、关键代码、实验方法整理为中文教材。它是经过结构整理和源码校正的译编，不是逐段双语对照或逐字全译；压缩了部分手写替代实现、生成过程示例和完整 IR dump，保留章节骨架与主线语义，并补充原文与本地实现不一致之处。更完整的入门解释见 [扩充教材](../aiversion/README.md)。

## 版本和来源

本次内容基准是用户提供的 `/opt/llvm-project`，不是滚动更新的网页代码：

- 分支：`release/18.x`。
- 提交：`3b5b5c1ec4a3095ab096dd780e84d7ab81f3d7ff`。
- 原文：[本地 Toy 教程目录](/opt/llvm-project/mlir/docs/Tutorials/Toy)。
- 实现：[本地 Toy 示例目录](/opt/llvm-project/mlir/examples/toy)。
- 测试：[本地 Toy 测试目录](/opt/llvm-project/mlir/test/Examples/Toy)。
- 在线入口：[MLIR Toy Tutorial](https://mlir.llvm.org/docs/Tutorials/Toy/)，已浏览其七章；在线内容仅辅助对照，冲突以本地代码为准。

具体校正、文件指纹与验证边界见 [来源与版本说明](../SOURCES.md)。本材料不是 LLVM 官方发布的中文版本。

## 章节

| 章 | 中文教材 | 本地原文 |
|---|---|---|
| 1 | [Toy 语言与 AST](01-language-and-ast.md) | [Ch-1.md](/opt/llvm-project/mlir/docs/Tutorials/Toy/Ch-1.md) |
| 2 | [生成基础 MLIR](02-emitting-basic-mlir.md) | [Ch-2.md](/opt/llvm-project/mlir/docs/Tutorials/Toy/Ch-2.md) |
| 3 | [高级语言相关的分析与变换](03-high-level-transformations.md) | [Ch-3.md](/opt/llvm-project/mlir/docs/Tutorials/Toy/Ch-3.md) |
| 4 | [通过接口启用通用变换](04-interfaces.md) | [Ch-4.md](/opt/llvm-project/mlir/docs/Tutorials/Toy/Ch-4.md) |
| 5 | [部分降级到低层方言以便优化](05-partial-lowering.md) | [Ch-5.md](/opt/llvm-project/mlir/docs/Tutorials/Toy/Ch-5.md) |
| 6 | [降级到 LLVM 并生成代码](06-lowering-to-llvm.md) | [Ch-6.md](/opt/llvm-project/mlir/docs/Tutorials/Toy/Ch-6.md) |
| 7 | [为 Toy 添加复合类型](07-composite-type.md) | [Ch-7.md](/opt/llvm-project/mlir/docs/Tutorials/Toy/Ch-7.md) |

## 阅读与代码约定

operation 译为“操作”，dialect 译为“方言”，lowering 译为“降级”，canonicalization 译为“规范化”，rank 译为“秩”。`tensor<*xf64>` 是无秩张量，`tensor<?x3xf64>` 是秩已知但一个维度动态，`tensor<2x3xf64>` 才是完整静态 shape。

C++、TableGen 与 MLIR 块使用三类显式标注：

- “逐字源码”：保留原始标识符、注释和缩进，带文件及起始行锚点，由脚本逐行核对；局部摘录未必能独立编译。
- “译编”：含中文说明、诊断或其他教学改写，不是本地文件的逐字副本。
- “示意”：简化定义、组合片段或用于推导的 IR，不声称逐字来自本地文件。

后两类不参与源码逐行一致性检查，也没有经过 C++ 编译或 MLIR 执行验证；包括故意构造的错误例子。Toy 源程序示例的注释可以译为中文，shell/text/图示不在这三种语言的源码类统计中。重复的源码实现位于各自章节的 ChN 中，不要混用不同章节的头文件和二进制。

所有实验先按 [第 0 章](../aiversion/00-preflight.md) 设置 `TOY_BUILD`。本地已有的 LLVM build 未启用 MLIR；本文提供构建和实验命令，但未把未执行的构建、JIT 或 FileCheck 声称为实测。

## 授权与改动声明

原文与引用代码来自 LLVM Project，采用 Apache License 2.0 with LLVM Exceptions，见随材料附带的 [LLVM 许可证](../LICENSE-LLVM.txt)。中文翻译、编排、源码校正和扩充说明是对上游材料的修改；请保留来源与许可证信息。
