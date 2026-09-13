# 第 2 章校订记录

本记录对应[第 2 章：MLIR 概述](../insider-compiler-ch2.md)。扫描来源为 `pdf/insider-compiler-ch2-ch3.pdf` 的 PDF 第 1–9 页（书页 16–24）。PDF 第 10 页开始第 3 章。原始 Apple Vision 识别结果保存在 `ocr/insider-compiler-ch2-ch3/`，本次校订未修改该目录。

## 基准与处理原则

- 源码位置：`/opt/llvm-project`。
- 提交：`3b5b5c1ec4a3095ab096dd780e84d7ab81f3d7ff`。
- 版本：**LLVM 18.1.8**，由 [llvm/CMakeLists.txt](/opt/llvm-project/llvm/CMakeLists.txt:18) 及 `/opt/llvm-project/build/bin/mlir-opt --version` 双重确认；工具输出为带断言的 Debug 构建。
- 原书称参考 LLVM 20。正文按用户指定的本地源码校订；本记录不声称已核对 LLVM 20 的所有实现。明确的术语、语法和概念问题与可能依版本变化的实现细节分别说明。
- 全章逐段保留；明显 OCR 错字直接修正。影响理解的原文技术错误在正文改正，并在这里记录原说法、修正和依据。跨页段落整合，页眉、页码、装饰文字不混入正文。
- 图 2-1 目视后改为 Mermaid，保留“操作包含区域，区域包含基本块，基本块包含操作”的展开关系及每层多个元素的含义。

## 逐页覆盖与目视检查

| PDF 页 | 书页 | 内容与检查重点 | 处理结果 |
|---|---:|---|---|
| 1 | 16 | 章标题、介绍、五项内容列表、2.1 | 完整转写；排除章首页装饰字的 OCR 噪声 |
| 2 | 17 | 2.1.1 操作、类型、属性、矩阵乘法示意 | 完整转写；逐个检查张量维度、`f32` 和变量名 |
| 3 | 18 | 方言、转换/翻译、代码清单 2-1、2-2 开头 | 完整转写；检查符号、区域括号和属性位置 |
| 4 | 19 | 代码清单 2-2 续、2.1.2、图 2-1、术语脚注 | 完整转写；实际目视示意图后重画 Mermaid |
| 5 | 20 | 区域、基本块、支配关系、存储及四条脚注 | 完整转写；核对 SSACFG、CFG 英文及引用链接 |
| 6 | 21 | 存储续、注意框、2.2.1、2.2.2 开头 | 完整转写；注意框保留，纠正验证阶段的概念 |
| 7 | 22 | 匹配/重写续、部分/完全转换、调试前 3 项、脚注 | 完整转写；核对 CLI 和 Debug Counter 行为 |
| 8 | 23 | 调试第 4 项、TableGen、2.3 位置追踪 | 完整转写；修复工具名，保留书籍交叉引用 |
| 9 | 24 | 位置追踪续、文档生成、并行编译、Python、2.4、脚注 | 完整转写；核对隔离边界和本地 Python 绑定实现 |

目视检查共 **9/9 页**，使用原页 PNG 实际检查正文与图。正文包含 9 个 `source` 页标记、2 个带原编号的代码清单、1 幅 Mermaid 图、7 条脚注。

## OCR 修复

代表性修复包括：`ML.IR` / `MLLIR` / `MILIR` → `MLIR`，`输人` → `输入`，`插人` → `插入`，`功飴` → `功能`，`字符申` → `字符串`，`t32` → `f32`，`tl` / `12` → `t1` / `t2`，代码内中文全角括号与冒号、`l` / `|` / `!` 混淆、`11` → `//`、`1lvm-tblgen` → `llvm-tblgen`、`pybindl1` → `pybind11`，以及脚注 URL 的斜杠、大小写和断行。每项均与页面图像对照；技术修正则另列如下，避免将原书错误误归为 OCR 错误。

## 矩阵乘法示意与验证

位置：PDF 第 2 页，2.1.1“操作”“类型”。

原书把张量普遍称为矩阵，又给出形如 `t3: tensor<...> = matmul(...)` 的写法。该写法可以表达数学意图，但不是合法 MLIR 汇编；普通 `linalg.matmul` 使用二维输入/输出，并计算 `C += A * B`，输出张量必须具有初始值。正文保留原示意并明确其性质，纠正张量与二维矩阵的关系。

依据：本地 Linalg 命名操作定义及验证后的工具输出，见 [LinalgNamedStructuredOps.yaml](/opt/llvm-project/mlir/include/mlir/Dialect/Linalg/IR/LinalgNamedStructuredOps.yaml:667) 中的 `name: matmul`；张量编码的通用语义见 [BuiltinTypes.td](/opt/llvm-project/mlir/include/mlir/IR/BuiltinTypes.td:744)。`encoding` 是属性值位置的占位，不是任意裸标识符；编码属性可描述额外信息，并不限于压缩方式。

用于核验原书维度例子的完整补例（初始输出填零，因而得到纯矩阵乘积）：

```mlir
func.func @matmul(%t1: tensor<2x3xf32>, %t2: tensor<3x4xf32>) -> tensor<2x4xf32> {
  %zero = arith.constant 0.0 : f32
  %empty = tensor.empty() : tensor<2x4xf32>
  %init = linalg.fill ins(%zero : f32)
                      outs(%empty : tensor<2x4xf32>) -> tensor<2x4xf32>
  %t3 = linalg.matmul ins(%t1, %t2 : tensor<2x3xf32>, tensor<3x4xf32>)
                      outs(%init : tensor<2x4xf32>) -> tensor<2x4xf32>
  return %t3 : tensor<2x4xf32>
}
```

此补例已通过本地 `mlir-opt` 的解析和验证。它没有做数值执行；验证结论是 IR 合法及变换流程可执行，不是浮点数值结果的运行测试。

## 通用操作示例与验证

位置：PDF 第 3–4 页，代码清单 2-1、2-2。

原扫描明确把 `{attribute_name = ...}` 放在区域列表 `({ ... })` 之前。这与本地 [LangRef 通用操作文法](/opt/llvm-project/mlir/docs/LangRef.md:294) 不符：`region-list?` 位于 `dictionary-attribute?` 之前。因此正文两处示例都将属性字典放到区域列表之后。

其他修正：

- 原文的 `!operand_type`、`!argument_type` 可被读作类型别名引用，不足以示范方言类型的完整拼写；正文使用 `!dialect.operand_type`、`!dialect.argument_type`，结果类型亦同。
- 属性写为 `#dialect.attr_kind<"value">`，避免把带参数的方言属性与 `#alias` 混为一谈。
- `() -> ()` 表示无操作数、无结果，不是“输入类型和输出类型均为 void”。
- 该区域显式列出 `^block` 与 `^successor` 两个块，不是“包含一个基本块”。
- 后继列表声明后继块；是否、如何转移控制由操作语义规定，不能从未定义的操作名推导完整行为。
- 保留 `...` 的骨架示例不是完整程序，需要给出外部值定义和省略的操作。

将骨架补齐为如下输入后，执行 `mlir-opt --allow-unregistered-dialect` 成功，退出码为 0：

```mlir
%value_use = "dialect.source"() : () -> !dialect.operand_type
%value_definition = "dialect.operation"(%value_use) ({
^block(%block_argument : !dialect.argument_type):
  "dialect.further_operation"() [^successor] : () -> ()
^successor:
  "dialect.yield"() : () -> ()
}) {attribute_name = #dialect.attr_kind<"value">}
  : (!dialect.operand_type) -> !dialect.result_type<"may_be_parameterized">
```

允许未注册方言后，工具可以验证通用语法和基础结构；这不等价于实现或验证自定义 `dialect` 的领域语义。正文没有把补齐后的自定义操作描述成真实可执行方言。

## 方言、翻译与负载 IR

位置：PDF 第 3–4 页。

原书将“每个操作本质上就是一个 IR”“同一方言构成一层 IR”“不同方言实现的功能相同”说得过于绝对。正文保留其从抽象层次介绍方言的路径，但改为：操作、类型、属性构成 IR；方言可以面向领域或抽象层次，不必与层次一一对应，也不必实现相同功能。例子使用已有 `linalg.matmul`、`affine.for`，同时说明还有 `scf.for`。

MLIR 的内存 IR 不是构建在 LLVM IR 对象之上；采用 LLVM 后端时，需由可导出的 MLIR 操作翻译到 LLVM IR。正文将原文“为 MLIR 中的 IR 构建在 LLVM IR 之上”的表述改正。依据为 [LangRef 对独立 IR 结构的定义](/opt/llvm-project/mlir/docs/LangRef.md:30) 及本地 [LLVM IR 导出实现](/opt/llvm-project/mlir/lib/Target/LLVMIR/ModuleTranslation.cpp)。

“负载 IR”也不是“操作内部具体处理过程”的通用结构名称。在 Transform 方言语境中，它指被变换的 IR，与描述变换的 transform IR 区分。正文增加限定，依据 [Transform.md](/opt/llvm-project/mlir/docs/Dialects/Transform.md:9)。

## 区域与支配关系

位置：PDF 第 5 页，2.1.2“区域”。

原文英文把 CFG 展开为 `Content Flow Graph`，应为 **Control Flow Graph**；SSACFG 相应展开为 **Static Single Assignment Control Flow Graph**。这是扫描中即可确认的原书内容错误，不是 OCR 凭空产生。

原书称 MLIR“仅计算基本块之间的支配关系”，还要求相关块位于同一区域或父区域相同。此表述与本地代码明显不符：

- [Dominance.h](/opt/llvm-project/mlir/include/mlir/IR/Dominance.h:136) 提供 `dominates(Operation *, Operation *)`、`dominates(Value, Operation *)` 和 `dominates(Block *, Block *)` 等接口。
- 同一头文件说明块查询考虑块包含关系，以及某个块是否支配另一块的父块；并非简单要求两者直接同层。
- [LangRef.md](/opt/llvm-project/mlir/docs/LangRef.md:493) 明确描述 hierarchical dominance。

正文按上述定义重写该段。图区域在本地版本只允许一个块的限制保留，依据 [LangRef.md](/opt/llvm-project/mlir/docs/LangRef.md:586)。图区域不以文本顺序约束执行先后，并不意味着所有具体操作都没有计算依赖或领域语义。

原书关于新增区域类型 RFC 的脚注保留为“2024 年 7 月”的历史说明，不将其状态更新为未经核实的当前结论。

## 存储与 IR 定义

位置：PDF 第 5–6 页，2.1.3。

原书说 MLIR“本质上以字符串形式定义 IR”，易使读者误以为字符串就是编译器中的基本表示。正文改为内存 IR、文本汇编、字节码三种表示；文本可解析为内存 IR，内存 IR 可以打印或序列化。内存对象也能直接通过 API 构建。字节码是紧凑二进制序列化格式，不应简单等同于把文本交给压缩算法所得的文件。

依据：[Operation.h](/opt/llvm-project/mlir/include/mlir/IR/Operation.h)、[Builders.h](/opt/llvm-project/mlir/include/mlir/IR/Builders.h)、[BytecodeFormat.md](/opt/llvm-project/mlir/docs/BytecodeFormat.md)。原注意框保留，并改正“自定义字符串格式是正确性问题根源”的暗示：无论从文本还是 API 构建，IR 都需满足语义约束。

## 谓词、约束、特质与验证

位置：PDF 第 6 页，2.2.1；属于本章较大的内容校订。

原书将谓词归为“IR 运行前静态约束”，将特质归为“IR 运行时动态约束”，并声称社区计划合并谓词和约束。这些说法不适合据本地代码教学：

- [Constraints.td](/opt/llvm-project/mlir/include/mlir/IR/Constraints.td:137) 的 `Constraint<Pred pred, string desc>` 显式保存 `Pred predicate` 和描述性 `summary`；其注释说明记录用于生成操作验证代码与模式匹配代码。
- [Traits 文档](/opt/llvm-project/mlir/docs/Traits/_index.md:39) 说明 `verifyTrait` / `verifyRegionTrait` 在验证具体操作时被调用；[OpDefinition.h](/opt/llvm-project/mlir/include/mlir/IR/OpDefinition.h:431) 有大量实际例子。
- [Pass.cpp](/opt/llvm-project/mlir/lib/Pass/Pass.cpp:527) 在开启 `verifyPasses` 时调用验证器；[PassManager.h](/opt/llvm-project/mlir/include/mlir/Pass/PassManager.h:276) 提供 `enableVerifier`。

因此正文保留原本“解析、构建、后续处理”的三方面结构，改为编译器运行过程中的 IR 检查，并明确区分最终目标程序的运行时行为。去掉无本地依据的未来合并承诺，保留谓词和约束的实际关系。特质提供不变量、性质、行为及可选验证逻辑；接口提供统一查询/调用行为的抽象。

## 匹配、缓冲化与转换

位置：PDF 第 7 页，2.2.2；属于本章较大的内容校订。

1. **常规重写并非规定类型永远不变。** 原文“默认操作类型不变”改为需要自行维持相关 IR 一致性。方言转换框架额外提供合法性目标、类型转换及映射机制，见 [DialectConversion.md](/opt/llvm-project/mlir/docs/DialectConversion.md)。
2. **张量 `matmul` 不由 `convert-linalg-to-affine-loops` 自动一步改成缓冲区程序。** 本地 [Loops.cpp](/opt/llvm-project/mlir/lib/Dialect/Linalg/Transforms/Loops.cpp:267) 检查 `hasPureBufferSemantics()`，张量语义的操作不匹配该循环降级模式。正文改为先缓冲化，再降级缓冲区语义的 Linalg 操作。`affine.for` 自身并不是矩阵参数从 tensor 变为 memref 的操作。
3. **SSA 使用方引用的是操作结果，不是把操作对象作为操作数。** 原书括号里的混淆已修正。
4. **部分／完全转换取决于目标合法性。** [DialectConversion.md](/opt/llvm-project/mlir/docs/DialectConversion.md:21) 说明，部分转换允许预先存在、未明确标记为非法的操作不转换；完全转换要求全部相关操作满足目标合法性。二者均可保留多个合法方言，原书“某一方言全部降级”的表述不足以定义完全转换。

实际验证使用上文矩阵乘法补例：

```sh
/opt/llvm-project/build/bin/mlir-opt matmul.mlir \
  --one-shot-bufferize='bufferize-function-boundaries' \
  --convert-linalg-to-affine-loops
```

命令退出码为 0，输出为使用 `memref` 参数、`affine.for`、`affine.load` / `affine.store` 的合法 IR。结果中矩阵乘法部分为三层循环，内层包含 `arith.mulf` 与 `arith.addf`。

作为对照，仅执行 `--convert-linalg-to-affine-loops` 也成功返回，但输出仍保留张量语义的 `linalg.matmul`。这证实该 Pass 不会自动完成 tensor 到 memref 的缓冲化，不能把“命令成功”误解为矩阵乘法已完成循环降级。

## 调试机制

位置：PDF 第 7–8 页，2.2.3。

- 原文的 `print-before`、`print-after` 是不完整的实际选项名；本地名称为 `mlir-print-ir-before`、`mlir-print-ir-after` 等，见 [PassManagerOptions.cpp](/opt/llvm-project/mlir/lib/Pass/PassManagerOptions.cpp:36)。正文加入命令行前缀 `--`。
- **Debug Counter 控制 Action 执行，不是输出 IR 的次数。** [Counter.h](/opt/llvm-project/mlir/include/mlir/Debug/Counter.h:22) 说明 `skip` / `count` 的执行含义；[ActionTracing.md](/opt/llvm-project/mlir/docs/ActionTracing.md:148) 给出跳过前 47 次、执行 2 次的例子。正文修正原书有关“仅支持 IR 单次处理”和“指定 Pass 在特定条件下才输出 IR”的描述。
- `mlir-reduce` 依赖用户提供的 interestingness 判定缩减复现用例；启发式归约不保证在全体可能 IR 中得到数学上的全局最小输入。正文将绝对“最小”改为“较小且仍满足测试条件”，参见本地 [mlir-reduce 文档](/opt/llvm-project/mlir/docs/Tools/mlir-reduce.md)。
- 原书“错误捕捉回复机制”改为“错误捕捉与复现机制”。实际 crash reproducer 包含用于重放的 IR、流水线和相关配置；它不是任意执行历史的完整记录，参见 [PassManagement.md](/opt/llvm-project/mlir/docs/PassManagement.md) 的 Crash and Failure Reproduction 部分，以及 [PassManagerOptions.cpp](/opt/llvm-project/mlir/lib/Pass/PassManagerOptions.cpp:24)。

## 隔离、常量与并行编译

位置：PDF 第 9 页，2.3“并行编译”；属于本章较大的内容校订。

原书把“与上方隔离”称为属性，并将规则描述成值引用不能跨越“该操作所在的区域”。正文改为：`IsolatedFromAbove` 是操作特质，限制的是**该操作所包含的区域**不能隐式捕获定义在区域外的 SSA 值，而不是禁止所有显式传参。

依据：

- [Traits/_index.md](/opt/llvm-project/mlir/docs/Traits/_index.md:276) 对 `IsolatedFromAbove` 的定义。
- [OpDefinition.h](/opt/llvm-project/mlir/include/mlir/IR/OpDefinition.h:1246) 的 C++ 特质名 `OpTrait::IsIsolatedFromAbove` 及其 `verifyRegionTrait`。
- [PassManagement.md](/opt/llvm-project/mlir/docs/PassManagement.md:357) 要求 PassManager 锚定的操作注册并具有此特质，且 Pass 不能任意修改当前操作之外或上方的 IR。
- [Pass.cpp](/opt/llvm-project/mlir/lib/Pass/Pass.cpp:744) 的异步嵌套流水线执行实现。

原书“使用常量通过与操作关联的属性达成”也不完整：常量操作仍产生 SSA 值，具体常量值可由属性表示。例如 [ArithOps.td](/opt/llvm-project/mlir/include/mlir/Dialect/Arith/IR/ArithOps.td:158) 的 `arith.constant` 及 [OpDefinition.h](/opt/llvm-project/mlir/include/mlir/IR/OpDefinition.h:1225) 的 `ConstantLike` 定义。正文保留符号引用避免跨隔离边界 SSA 捕获的动机，同时补足常量操作这一环节。

## 其他小项与版本边界

- `Table Gen` 统一为标准工具名称 TableGen。
- 安全代码一段保留“看似冗余的计算可能承担安全作用”和“需保留高层语义”的含义，但避免把“加入冗余计算”写成普遍保证安全的充分条件。
- Python 绑定使用 pybind11 在本地 LLVM 18 得到确认，依据 [PybindAdaptors.h](/opt/llvm-project/mlir/include/mlir/Bindings/Python/PybindAdaptors.h:21)。正文加上本地版本限定，不据此推断 LLVM 20 或更新版本的绑定实现。
- 原书 2024 年 7 月的参考资料访问日期保留。这里未开展当前社区状态或性能数字的外部考证。

## 验证结果与未解决项

| 检查 | 结果 |
|---|---|
| 实际工具版本 | LLVM 18.1.8，Debug，assertions enabled |
| 补齐的通用操作示例 | `--allow-unregistered-dialect` 下解析与验证成功 |
| 2×3 与 3×4 张量矩阵乘法补例 | 解析与验证成功 |
| 缓冲化后转换为 affine 循环 | 成功，输出 memref 访存与三层乘法循环 |
| 直接对张量例子运行 affine 循环降级 | 保留 `linalg.matmul`，符合纯缓冲区语义限制 |
| 扫描覆盖 | 9/9 页全部目视，图 2-1 已检查并转换为 Mermaid |

本章没有仍无法辨认的文字或图示。未验证范围是 LLVM 20 的逐项实现差异、原书所引历史 RFC 的现状、最终机器码数值运行；这些不影响本次以 LLVM 18.1.8 为准的逐页校订结论。
