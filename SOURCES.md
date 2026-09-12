# 来源、版本与校正说明

## 1. 使用哪一份事实

材料整理日期：2026-09-12。代码基准为本地 `/opt/llvm-project`：

```text
branch: release/18.x
commit: 3b5b5c1ec4a3095ab096dd780e84d7ab81f3d7ff
```

已浏览 [官方 Toy 教程及七章入口](https://mlir.llvm.org/docs/Tutorials/Toy/)，正文主要依据本地英文 Markdown、各章实现和对应测试进行译编与扩充。网页和本地文档中的历史片段与实际实现冲突时，以本地实现为准；必要时指出这是实现限制，而不把原文愿景写成已实现功能。

本次核对的三个子树没有未提交修改。仓库中其他目录已有用户修改，不在本任务范围内；本任务未改动 LLVM 源码、分支、现有构建配置或用户的其他文件。

[source-manifest.json](source-manifest.json) 记录上述三个子树内文件以及许可证、相关顶层 CMake 的 SHA-256 指纹，共 186 个文件，用于以后发现源码漂移。指纹是可复现基准，不代表每个字节都经过独立语义验证。

## 2. 本地原文与在线导航

| 章 | 本地原文 | 在线页面 |
|---|---|---|
| 1 | [Ch-1.md](/opt/llvm-project/mlir/docs/Tutorials/Toy/Ch-1.md) | [语言与 AST](https://mlir.llvm.org/docs/Tutorials/Toy/Ch-1/) |
| 2 | [Ch-2.md](/opt/llvm-project/mlir/docs/Tutorials/Toy/Ch-2.md) | [基础 MLIR](https://mlir.llvm.org/docs/Tutorials/Toy/Ch-2/) |
| 3 | [Ch-3.md](/opt/llvm-project/mlir/docs/Tutorials/Toy/Ch-3.md) | [高层变换](https://mlir.llvm.org/docs/Tutorials/Toy/Ch-3/) |
| 4 | [Ch-4.md](/opt/llvm-project/mlir/docs/Tutorials/Toy/Ch-4.md) | [接口](https://mlir.llvm.org/docs/Tutorials/Toy/Ch-4/) |
| 5 | [Ch-5.md](/opt/llvm-project/mlir/docs/Tutorials/Toy/Ch-5.md) | [部分降级](https://mlir.llvm.org/docs/Tutorials/Toy/Ch-5/) |
| 6 | [Ch-6.md](/opt/llvm-project/mlir/docs/Tutorials/Toy/Ch-6.md) | [LLVM 与代码生成](https://mlir.llvm.org/docs/Tutorials/Toy/Ch-6/) |
| 7 | [Ch-7.md](/opt/llvm-project/mlir/docs/Tutorials/Toy/Ch-7.md) | [复合类型](https://mlir.llvm.org/docs/Tutorials/Toy/Ch-7/) |

## 3. 主要源码校正

| 主题 | 本教材采用的本地事实 |
|---|---|
| 第 1 章泛型设想 | 第 4 章使用内联与函数内传播，没有按调用签名缓存专门化版本 |
| 语言与实现边界 | rank≤2 是原文教学目标；解析器与部分 lowering 更一般，错误检查并非处处完备 |
| 关键字与内建 | print/transpose 在 Lexer 中都是标识符；Parser 特判 print，MLIRGen 特判 transpose |
| 第 2 章命名空间 | IR 类型使用 mlir::toy；与前端 AST 的 toy 命名空间区分 |
| 常量类型 | F64Tensor 可无秩；double builder 创建零秩 tensor，而不是广播张量 |
| 第 3 章 DRR | 采用本地 ::llvm::cast<ShapedType>，并说明 TableGen 生成与 pattern 注册链 |
| 第 4 章接口 | 保留三个 isLegalToInline 重载、return 替换和 materializeCallConversion |
| 形状推断 | 判断 RankedTensorType，不等同于 hasStaticShape；Add/Mul 只传播左输入类型 |
| 第 5 章循环回调 | builder、重映射后的 MemRef operands、loopIvs 三个参数齐全 |
| 部分转换 | 明确 illegal 的操作必须消除；Print 通过更新输入满足动态合法性 |
| 内存管理 | 在单块无复杂控制流的假设下插入 alloc/dealloc，不是通用所有权或 GC |
| 后端前提 | 没有 generic_call/cast/reshape 的一般 lowering，前序必须消除它们 |
| 第 6 章规则集合 | 包含 MemRef→LLVM，使用 LLVMConversionTarget 与 LLVMTypeConverter |
| 指针与目标 API | 本地 opaque pointer；setupTargetTripleAndDataLayout |
| ExecutionEngine | ExecutionEngineOptions::transformer、create(module, options)、invokePacked |
| 输出通道 | AST/IR dump 写 stderr；JIT printf 写 stdout |
| 第 7 章访问器 | getIndex() 返回整数，不接旧式 getZExtValue() |
| 结构体后端连接 | fold→materializeConstant→ConstantOp 形状推断→旧 lowering |
| 结构体范围 | 结构式高层类型，不是已经实现运行时布局、ABI 或任意动态构造 |

C++、TableGen 与 MLIR 块均有“逐字源码”“译编”或“示意”标注。“逐字源码”保留注释和缩进，且必须附本地路径及起始行锚点；后两类可包含简化、重命名或中文改写，不作为本地逐字摘录。标签说明的是来源性质，不保证整个片段可独立编译。

## 4. 两套文本的关系

official 覆盖官方七章的章节骨架与主线语义，是结构化中文译编，压缩了部分手写替代实现、生成过程示例和较长 IR 清单，不宣称逐字全译。aiversion 第 1～7 章完整包含相应 official 正文，并追加入门解释、逐步演算、工程边界、Mermaid 示意和练习解析；第 0 章另补环境与基础知识。

“完整包含 official”只陈述两套中文正文的包含关系，不推出“完整覆盖官方英文原文”。本轮补入了 ODS 基类/builders 与生成入口、调用接口方法，以及结构体存储和解析/打印源码；未机械恢复与本地实现不同的历史 C++ 替代类和旧 LLVM IR 清单。

这是“原文主线＋代码校准＋系统扩充”，不是用几条学习笔记替代正文。新增图表表示的是代码关系或概念流程，不是未验证的性能实验数据。

## 5. 验证与尚未执行的部分

文档检查脚本：

```bash
node /opt/coding/mlir-toy/scripts/validate-materials.mjs
```

检查范围：章节齐全、Markdown 围栏闭合、本地文件链接及源代码行号、代码来源标签及其统计、带锚点的逐字源码一致性、两套章节的包含关系、实验中引用的本地测试文件、源码指纹以及许可证副本。

当前两套教材中 C++/TableGen/MLIR 块共 127 处：46 处逐字源码（23 段独立摘录在两套正文中各一次）、8 处译编、73 处示意，未分类 0 处。逐行比对只覆盖前 46 处；其余 81 处只检查分类、围栏及适用的文件引用，不代表其编译/运行正确性已验证。shell、Toy 源程序、text 与 Mermaid 块不在这 127 处统计范围内。

章节包含检查采用 H1 归一化后的字符串前缀比较；扩充部分至少 4 个二级标题且 2500 字符的条件只是防止明显截断的下限。二者都不能自动证明英文原文覆盖率、扩充深度或教学质量。代码块数量与源码比对比例也不是语义准确率。

脚本只做静态检查，不替代 C++ 编译、MLIR verifier、完整 Markdown 渲染或 Mermaid 布局检查。它不会改写文件或更新指纹；若上游源码变化，应重新人工核对再更新基准。

本地已有 build 未启用 MLIR，因此没有在本任务中编译 toyc、执行 JIT 或运行 FileCheck。正文输出标为数学推导或测试预期；可复现实验命令集中使用新的 TOY_BUILD，构建方法见 [第 0 章](aiversion/00-preflight.md)。Mermaid 图以源码形式随文保存，不将语法/文本检查称为浏览器渲染验收。

针对 [ds4.1 检查清单](issues/ds4.1check.md) 的独立复核、采纳项与不采纳理由见 [处理记录](issues/ds4.1-response.md)。原检查文件保持不变。

2026-09-13 对 [GLM 检查清单](issues/glmcheck.md) 的两项意见完成源码复核：限定 C++ 模式 benefit=1 的适用范围，并补充 DRR 的收益计算与第 6 章目录图。详见 [GLM 处理记录](issues/glm-response.md)。本次未改写两份原始检查清单。

## 6. 授权

LLVM Project 原文和源代码采用 Apache License 2.0 with LLVM Exceptions；完整许可证副本见 [LICENSE-LLVM.txt](LICENSE-LLVM.txt)，对应本地 [LICENSE.TXT](/opt/llvm-project/LICENSE.TXT)。中文翻译、结构重排、纠错与补充是修改部分。本材料不代表 LLVM 官方审阅或背书。
