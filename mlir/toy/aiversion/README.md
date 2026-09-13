# MLIR Toy 中文扩充教材

这套教材是 [official 中文译编](../official/README.md) 的逐章扩充，不是另一套提纲或学习笔记。第 1～7 章完整承接对应 official 章节正文，再追加基础概念、源码推导、示意图、实验观察方法及带解析的练习，因此可以在本目录连续阅读，不必在两套正文间来回跳转。

面向会读基本 C++、但尚未系统学习编译器、LLVM 或 MLIR 的读者。遇到 unique_ptr、ArrayRef、SSA、Region 等概念，正文会解释它们在当前代码中的实际作用，而不是要求先掌握整套框架。

## 目录与各章扩充内容

| 章 | 教材 | 重点补充 |
|---|---|---|
| 0 | [开课准备与环境](00-preflight.md) | 全局地图、三个运行时刻、独立构建目录、实验与诊断方法 |
| 1 | [从源码到 AST](01-from-source-to-ast.md) | Token、递归下降、优先级、张量 shape、AST 所有权与位置 |
| 2 | [生成第一份 MLIR](02-first-mlir.md) | Operation/Region/Block、SSA、属性与类型、ODS 到 C++、生成器追踪 |
| 3 | [高层重写](03-rewriting.md) | 等价性证明、共享 use-def 图、贪心终止、fold/CSE/DCE/DRR 区别 |
| 4 | [接口、内联与形状](04-interfaces-and-shapes.md) | 接口分工、值映射、cast 的信息边界、worklist 手工演算、pass 嵌套 |
| 5 | [渐进式降级](05-progressive-lowering.md) | 值与存储语义、非方阵下标推导、conversion 重映射、内存生命周期与融合 |
| 6 | [LLVM 与 JIT](06-llvm-and-jit.md) | MemRef 描述符、地址公式、CFG/块参数、printf ABI、翻译与执行边界 |
| 7 | [自定义类型](07-custom-types.md) | 结构类型、唯一化与所有权、字段名解析、嵌套常量折叠与形状恢复 |

每章先完整承接对应 official 正文，再追加深入讲解；两部分长度不要求各占一半。想先补基础时，可先读第 0 章，再在具体章节中结合前后两部分阅读。练习答案紧随题目，适合先自行推导，再核对原因。

## 关键代码与实验入口

各章新增了独立的源码阅读与实验部分：只选决定行为的入口或转换点，每段后解释它的输入、修改与后续使用，不复制整个实现文件。所有新实验先设置第 0 章的 TOY_ROOT、TOY_BUILD 与 TOY_LAB；分别定位教材输入、构建产物与独立临时输出目录。

| 章 | 直接阅读 | 主要观察目标 |
|---|---|---|
| 0 | [实验工作流](00-preflight.md#code-lab) | 复用已有构建、查找源码、捕获输出和失败诊断 |
| 1 | [Parser 入口与优先级](01-from-source-to-ast.md#code-lab) | 文件→Lexer→Parser→AST，乘法如何先结合 |
| 2 | [声明与二元表达式生成](02-first-mlir.md#code-lab) | reshape 插入点，紧凑/通用 IR 与往返 |
| 3 | [匹配、共享值与生成规则](03-rewriting.md#code-lab) | 只替换外层转置，比较重写前后与 TableGen 产物 |
| 4 | [worklist 与 pass 追踪](04-interfaces-and-shapes.md#code-lab) | 就绪条件、-opt 门控、阶段日志与最终 IR |
| 5 | [元素计算与 Print 边界](05-progressive-lowering.md#code-lab) | load/标量计算/store 分工，不支持 reshape 的失败路径 |
| 6 | [printf 到 JIT](06-llvm-and-jit.md#code-lab) | 符号声明与调用分离，四层 IR 和运行输出 |
| 7 | [字段到张量](07-custom-types.md#code-lab) | 名字→索引→属性→常量→精确 shape |

另有两个小型教学输入，文件中只保留观察该问题所需的程序：

- [共享转置结果](examples/03-shared-transpose.mlir)：规范化应删除外层转置，但保留仍被单独打印的内层结果。
- [活跃的非恒等 reshape](examples/05-live-reshape.toy)：Toy IR 可生成，但按当前规则应在 Affine 合法化阶段失败。

2026-09-13 已复用 `/opt/llvm-project/build` 的 LLVM 18.1.8 工具运行逐章实验和这两个输入，官方 Toy 的 56 个测试全部通过，第 6、7 章 JIT 数值正确。新增输入分别验证了共享结果的保留与预期的 reshape 降级失败；详情、实现边界和复跑命令见 [运行验证报告](RUNTIME-VALIDATION.md)。

## 版本规则

唯一代码基准是本地 `/opt/llvm-project` 的 `release/18.x`，提交 `3b5b5c1ec4a3095ab096dd780e84d7ab81f3d7ff`。源码目录为 `mlir/examples/toy/Ch1` 到 `Ch7`，测试为 `mlir/test/Examples/Toy/Ch1` 到 `Ch7`。网页原文会继续变化，不要从最新网页拷贝 API 后与这套本地代码混用。

这里会明确区分三种说法：“官方原文的语言设想”“本地实现确实完成的行为”“为了理解而构造的示意或扩展方向”。例如，本地 shape inference 不等于完整动态 shape 求解器，结构体例子也没有定义通用运行时 ABI。

“完整承接”仅指包含对应 official 中文正文，不表示已经逐段覆盖官方英文原文。official 压缩了不少教学替代实现和完整 IR 清单；扩充版补充概念与本地关键实现，但不是英文原件的全文对照本。

C++、TableGen 与 MLIR 块均标为“逐字源码”“译编”或“示意”。只有带源码锚点的“逐字源码”做逐行一致性检查；其他两类是讲解材料，不应当作本地原样代码或实测输出。

详细来源、修改说明和验证限制见 [SOURCES.md](../SOURCES.md)。

## 图、实验与证据

正文采用可随 Markdown 一起维护的 Mermaid 图和少量文本示意；无需联网图片服务。支持 Mermaid 的阅读器可直接渲染，不支持时仍可阅读图附近的文字说明。

实验使用本地已有的官方测试文件，命令以 `TOY_BUILD` 指定构建产物位置。数学推导、测试 CHECK 预期和实际运行日志会分别说明，不以预期代替实测。当前已完成文档、源码一致性与运行检查，全程没有重新配置或构建 LLVM；未完整的 C++/TableGen/MLIR 示意片段不作为独立编译单元验收。

## 贯穿全书的几个区分

| 容易混淆的概念 | 应当区分的边界 |
|---|---|
| AST 与 MLIR | 源语言语法结构，与可验证、可重写的通用 IR 基础设施 |
| Type、Attribute、Value | 类型信息、编译期元数据/常量、SSA 计算结果 |
| tensor 与 memref | 抽象不可变值，与可读写内存引用 |
| infer 与 verify | 推导缺失信息，与检查已有声明是否满足约束 |
| fold 与 lowering | 在当前抽象中简化，与换到更具体的表示 |
| LLVM 方言与 LLVM IR | MLIR 内部表示，与 LLVM 后端自己的表示 |
| 编译 toyc 与运行 toyc | 构建编译器程序，与用它编译用户 Toy 程序 |

原文与摘录代码遵循 [LLVM 许可证](../LICENSE-LLVM.txt)；中文扩充不是 LLVM 官方文档。
