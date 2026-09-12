# ds4.1 检查清单的独立复核与处理

核查输入：[ds4.1check.md](ds4.1check.md)。基准仍为本地 LLVM `release/18.x` / `3b5b5c1ec4a3095ab096dd780e84d7ab81f3d7ff`。本文件记录独立判断，不修改原检查清单；本轮只修改教材、说明与文档校验器，不改动 LLVM 源码。

结论：来源分类不够清楚、Ch5 对原文的无依据归因、Ch4 条件/文件归属说明以及部分源码教学覆盖不足，值得修正。但“benefit 彻底消失”“两个 reshape 计数错误”“llvm-lowering.mlir 是可以直接使用的 FileCheck 入口”等判断不成立或不完整，未照单采纳。代码行数减少本身不能证明语义错误，也不能用来证明内容已完整覆盖。

## 逐项裁定

| 项目 | 判断 | 处理 |
|---|---|---|
| A1 来源标注 | 主要成立；不能把重命名/简化直接判作语义错误 | 所有 C++/TableGen/MLIR 块显式分为逐字源码、译编、示意；强制标签与源码锚点一致 |
| A2 覆盖边界 | 原记录只声称源码摘录通过，但可更明确 | 明列各类总数与逐行检查范围，不将它表述为全体代码经过编译/语义验证 |
| B1 回调参数归因 | 成立 | 删除“原文旧片段常省略第二个参数”；本地原文和实现均给出三个参数 |
| B2 注释归属 | 成立，属于定位表述问题 | 明确链接 ShapeInferencePass.cpp 文件头第 9 行 |
| B3 Ch4 的 -opt 条件 | 成立 | 明确全部四类 pass 受 enableOpt 门控，并区分 Ch5/6 请求 lowering 的行为 |
| B4 前半/后半 | 非事实性重大错误，但容易误解为等长 | 改成“先承接正文，再追加讲解” |
| C1 llvm-lowering.mlir | 文件引用确实遗漏；其测试性质判断不准确 | 补入口与三种 emit 命令；不添加原样 FileCheck 管道，说明历史 CHECK 问题 |
| C2 英文覆盖 | 压缩事实成立，但部分“概念缺失”判断过强 | 明确不是英文全文对照；补关键代码连接，不机械恢复旧 API 或全部 dump |
| D1 reshape 数量 | 不成立 | 保留两变量、两个 reshape 的独立教学例子，不擅自补第三变量 |
| D2 包含检查强度 | 成立 | 明确前缀检查与最低篇幅条件只验证结构，不证明教学质量或英文覆盖 |

## A1 中哪些是来源差异，而不是知识错误

中文 description/summary、中文错误串、缩短变量名及折叠中间变量，确实不是本地逐字代码。因此它们现在标为“译编”或“示意”，不能拿中文错误串去匹配运行时实际诊断。按源码锚点标出的摘录仍保留原样并逐行校验。

但以下细节不支持清单中的强结论：

- **benefit 没有“彻底消失”。** 修订前扩充版第 3 章 §8.1 已写明 benefit=1 是模式排序的相对值。其示意类使用继承构造函数，也不是漏设正确性必需参数：[PatternMatch.h](/opt/llvm-project/mlir/include/mlir/IR/PatternMatch.h:361) 中 OpRewritePattern 构造函数默认 benefit 就是 1。[本地模式](/opt/llvm-project/mlir/examples/toy/Ch3/mlir/ToyCombine.cpp:29) 显式传 1。两种写法不是逐字相同，但这里的默认收益值一致，保留原解释和示意。
- **变量改名及 replaceOp 参数形式不是天然错误。** 示意代码的目的在于解释匹配/替换；本轮通过来源标注区别它与逐字实现，不把所有简化重写回去。
- **TypeConverter 不只涉及块参数。** 原文说本章不需要它，不是对框架能力的完整限制。本地 Ch6 的 LLVMTypeConverter 参与更广泛的类型合法化。保留框架能力解释，另在 Ch5 列表后立即声明本章未构造 TypeConverter。
- **StructTypeStorage 的省略确实值得补。** 本轮直接换成完整本地存储类，连同 hashKey/getKey 保留；相应扩充段落同步更新。StructType 外层类仍是明确标注的简化示意，未把它冒充实际头文件。
- **StructType 的 ODS 判定** 补全为本地写法 `::llvm::isa<StructType>`。fold 的缩写实现仍标为示意；其省略中间变量并未改变已说明的常量提取逻辑。

## B1/B2/B3 的直接依据

[英文 Ch-5.md](/opt/llvm-project/mlir/docs/Tutorials/Toy/Ch-5.md:118) 的转置 lowering lambda 已有 rewriter、memRefOperands、loopIvs 三参数，因此不能归因于“旧原文省略”。

[Ch4/toyc.cpp](/opt/llvm-project/mlir/examples/toy/Ch4/toyc.cpp:124) 的 if(enableOpt) 包住 Inliner、ShapeInference、Canonicalizer、CSE。[ShapeInferencePass.cpp](/opt/llvm-project/mlir/examples/toy/Ch4/mlir/ShapeInferencePass.cpp:9) 的文件头才有 interprocedural/specialization 注释；同文件类说明为 intra-procedural。教材现已分别给出对应链接和条件。

## C1：测试文件存在，不等于 CHECK 已被执行

[llvm-lowering.mlir](/opt/llvm-project/mlir/test/Examples/Toy/Ch6/llvm-lowering.mlir:1) 的实际 RUN 为 `toyc-ch6 %s -emit=llvm -opt`，没有 FileCheck。文件输入是 Toy 方言张量 IR，不是预先完成 Tensor→MemRef 的混合 IR；使用不同 emit 选项才会经过那些中间阶段。

最后一个 CHECK 写的是 `3.000000e+01`（30）。但输入元素 6 转置后再与自身逐元素相乘，应是 36。这个判断来自文件输入、MulOp lowering 与算术推导，不是本轮运行 LLVM 优化得到的实测输出。不能为了“补现成 FileCheck 实验”直接启用有问题的历史检查，更不能改动正确的教材数值去迎合它。

因此补入原文测试入口，说明其局限；未修改上游测试，也未声称三种 emit 命令已运行成功。

## C2：补哪些内容，不补哪些内容

本轮补入：

1. Ch2 的 Toy_Op 基类与 ConstantOp builders 逐字摘录；summary/description 的职责、文档不等于验证，以及三个生成器入口。
2. Ch4 的 CallableOpInterface 与 FunctionOpInterface 连接，以及 GenericCallOp 查询/修改 callee、查询/修改参数的四个实际方法。
3. Ch7 的完整 StructTypeStorage、parseType 和 printType，并解释错误路径、递归类型解析和往返语义。

这些补充同步进入 official 与 aiversion。没有仅靠更改 README 来掩盖实际教学连接的压缩。

同时，清单声称 Ch2 verifier/builders 概念缺失、Ch4 Callable/Call 教学线完全缺失，并不准确：修订前已有常量 verify/build 的完整源码、生成文件连接、调用接口说明与图示；不足主要是若干实现连接没有展开。Ch4 也已经解释 OperationPass 的嵌套层级，并不是没有介绍 pass 作用域。

原文的手写 ConstantOp 替代类、手写 Print parser/printer，以及较长的历史 LLVM IR dump，不是本地全部采用的实现。尤其旧指针/API 与本地版本不一致时，不应为补行数重新引入。保留其职责解释，读者可通过本地英文链接逐段对照；教材明确不宣称英文全文覆盖。

## D1：为何不修改两次 reshape 的例子

扩充版第 3 章 §9 写的是独立表达式 `var a<2,1> = [1,2]; var b<2,1> = a;`，紧接着正确描述两次 reshape。该段没有声称是 trivial_reshape.toy 的完整逐字清单。

对应 official 主线中的示例则有 a/b/c 三个变量，二者不能混作同一份输入来数操作。为满足检查意见而把两变量解释改成三次 reshape，反而会制造事实错误，因此保留。

## 验证结果

主校验通过：127 个源码类块全部分类，其中 46 个逐字源码块、8 个译编块、73 个示意块；46 个逐字块对应 23 段独立源码，在两套正文中各出现一次。其他 81 个块没有被宣称通过逐行源码比对或运行验证。

新增只读的内存变异回归测试，验证校验器会拒绝缺少标签、逐字块没有锚点、逐字源码被篡改三种情况。前缀包含、来源文件指纹及 shell 语法检查仍通过。运行入口和完整限制见 [VALIDATION.md](../VALIDATION.md)。

本轮没有重建 LLVM、执行 Toy/JIT、运行 FileCheck 或完成 Mermaid 渲染验收；原始检查清单与上游仓库保持不变。
