# 第 3 章校订记录

本记录对应[第 3 章：类型、属性、操作和方言详解](../insider-compiler-ch3.md)。扫描来源为 `pdf/insider-compiler-ch2-ch3.pdf` 的 PDF 第 10–50 页，即书页 25–65。原始 Apple Vision OCR 保留在 `ocr/insider-compiler-ch2-ch3/`，没有用校订文本覆盖原始识别结果。

## 基准与校订范围

- 本地源码：`/opt/llvm-project`，提交 `3b5b5c1ec4a3095ab096dd780e84d7ab81f3d7ff`。
- 版本：**LLVM 18.1.8**，由 [llvm/CMakeLists.txt](/opt/llvm-project/llvm/CMakeLists.txt:18) 和 `build/bin/mlir-opt --version` 确认；工具是带断言的 Debug 构建。
- 原书称参考 LLVM 20。下面的实现性差异只说明原扫描与本地代码不一致，不在没有核对 LLVM 20 对应提交的情况下断言它们由版本升级引起。明确的概念错误、内部矛盾、复制错误及上游文档与执行代码的差异另行说明。
- 保留章节层级、完整论述、例子、代码清单原编号、图表及脚注。跨页段落合并，页眉、页码和装饰元素不作为正文。原书已经省略的代码仍明确标为摘录；本次没有把整章压缩为摘要。
- 本章图示先查看扫描页，再按实际代码关系重绘；内存图中原有但错误的指针符号和字段偏移不机械照抄。

## 逐页覆盖与完成检查

全章 **41/41 页**均实际查看对应扫描 PNG：第 3 章校对代理检查 PDF 第 10–38 页，第 4 章校对代理协助检查第 39–50 页并提交完整尾稿，随后由第 3 章代理合并与通读；主校对代理另行复核了操作内存布局等关键页及图示。页标严格覆盖 PDF 第 10–50 页，无重复、无缺页。

| PDF 页 | 书页 | 完整保留并检查的主要内容 |
| --- | --- | --- |
| 10 | 25 | 章首介绍，3.1 类型，类型名称脚注 |
| 11 | 26 | 三种定义方式，清单 3-1 整数类型 TD |
| 12 | 27 | 整数类型主要字段说明 |
| 13 | 28 | 字段说明续，清单 3-2 基类与清单 3-3 记录开头 |
| 14 | 29 | 清单 3-3 续、记录脚注、清单 3-4 存储 |
| 15 | 30 | 位域存储说明，清单 3-5 C++ 类 |
| 16 | 31 | 清单 3-6、3-7、3-8 及构造调用链 |
| 17 | 32 | 类型与存储两部分说明，图 3-1，注册导语 |
| 18 | 33 | 清单 3-9 注册，3.1.2 文法与清单 3-10 开头 |
| 19 | 34 | 类型文法续、清单 3-11 整数文法、清单 3-12 打印 |
| 20 | 35 | 3.1.3 使用方式与清单 3-13 唯一化入口 |
| 21 | 36 | 清单 3-13 续，清单 3-14 存储查找 |
| 22 | 37 | 类型注册与实例化收尾，3.2 属性与清单 3-15 |
| 23 | 38 | 属性定义注册收尾，清单 3-16 文法 |
| 24 | 39 | 清单 3-17、固有／可丢弃属性与 properties、3.3 引入 |
| 25 | 40 | 清单 3-18 addi 定义与字段说明 |
| 26 | 41 | 字段说明续，清单 3-19 记录 |
| 27 | 42 | 记录与接口说明续，清单 3-20 适配器开头 |
| 28 | 43 | AddIOp 类接口与构造器清单 |
| 29 | 44 | AddIOp 类续，清单 3-21 构造／验证实现 |
| 30 | 45 | 清单 3-21 续，操作继承关系导语 |
| 31 | 46 | 图 3-2、3-3，CRTP 与尾分配说明，外链脚注 |
| 32 | 47 | 图 3-4，清单 3-22 方言操作注册 |
| 33 | 48 | 3.3.2，清单 3-23，构造状态与动态分配解释 |
| 34 | 49 | 清单 3-24 Operation 创建与前置结果存储 |
| 35 | 50 | 清单 3-24 续、图 3-5 本体与尾部布局 |
| 36 | 51 | 动态转换解释，清单 3-25、3-26 |
| 37 | 52 | 转换辅助模板续、清单 3-27、get/build 注意框 |
| 38 | 53 | 3.3.3，清单 3-28 与 3-29 前半 |
| 39 | 54 | 清单 3-29 续，3.4 方言、清单 3-30 |
| 40 | 55 | 方言字段、清单 3-31、清单 3-32 开头 |
| 41 | 56 | 方言类续、清单 3-33、注册与加载解释 |
| 42 | 57 | 方言接口、3.4.2 扩展、清单 3-34 开头 |
| 43 | 58 | 扩展类续、扩展条件、清单 3-35 接口附加 |
| 44 | 59 | 清单 3-36、注意框、3.4.3 类型管理开头 |
| 45 | 60 | 类型／属性／操作管理、图 3-6、内建方言及注意框 |
| 46 | 61 | 内建类型分类、表 3-1 全四行、ranked/unranked |
| 47 | 62 | clone/mutate 注意框、唯一化、位置与一般属性全列表 |
| 48 | 63 | 内建两种操作、3.5、图 3-7 与上下文说明 |
| 49 | 64 | 图 3-8 全部原有具名字段与说明、清单 3-37 开头 |
| 50 | 65 | 开发示例续、注册／加载说明、3.6 本章小结 |

最终正文有 **37 份原编号代码清单、8 幅原编号 Mermaid 图、表 3-1 的全部 4 行及 3 条脚注**。图 3-5、3-7、3-8 配有补充字段表以保留图中文字；原图不是 ABI 布局时已明确说明。全部 8 幅图由主校对代理使用 Mermaid 11.12 成功渲染；`tools/check_markdown.py` 验证全章页序、编号、围栏、脚注、链接与锚点通过。结构检查不代替上文记录的逐页目视及下文的源码核对。

本章没有尚未辨认的扫描文字或图示。验证集中于实际受改动的接口、数据布局和解析行为，不声称含原书省略号的清单能够逐份独立编译，也没有宣称核对了未提供的 LLVM 20 整棵源码。

## OCR 与版面修复

常见识别错误包括 `MILIR`、`ML.IR` → `MLIR`，`miir-tblgen` → `mlir-tblgen`，`11vm` → `llvm`，`0peration` → `Operation`，`AddlOp` → `AddIOp`，`TypeUniguer` → `TypeUniquer`，`输人` → `输入`，`字符申` → `字符串`，以及模板尖括号、花括号、`::`、`&&`、`...`、`#`、`!`、`$lhs`、正则表达式转义和注释标记的混淆。代码按扫描页面与对应本地定义共同校核，原文技术错误没有混入“OCR 错误”的分类。

## 类型基础概念

位置：PDF 第 10–11、17–18、20–22 页，3.1 及 3.1.1、3.1.3。

原文将方言、类型和属性多次说成“全局唯一”，并将它们描述为在方言中统一保存的单例。实际需要区分：具体类型／属性的轻量句柄、按参数唯一化的存储、抽象注册元数据，以及方言实例。唯一化的范围是一个 `MLIRContext`，不是整个进程；参数不同的 `IntegerType` 使用不同存储，参数相同且 context 相同时才共享。方言关联定义及行为，不直接拥有所有操作实例。

依据：[TypeSupport.h 中 AbstractType 与 TypeStorage](/opt/llvm-project/mlir/include/mlir/IR/TypeSupport.h:29)、[TypeUniquer 的 get 与 registerType](/opt/llvm-project/mlir/include/mlir/IR/TypeSupport.h:210)、[MLIRContext.cpp 的实例存储与缓存](/opt/llvm-project/mlir/lib/IR/MLIRContext.cpp)、[AttributeSupport.h](/opt/llvm-project/mlir/include/mlir/IR/AttributeSupport.h)。正文相应修正“类型对象只需一份”等说法，并明确无参数类型也仍有基础存储。

PDF 第 11 页关于定义方式的三项说明另有以下问题。

| 原说法 | 修正与依据 |
| --- | --- |
| 内建类型在降级时由框架自动转换为 LLVM 支持的类型 | 转换依赖所选流程和类型转换器，并非所有内建类型自动一步转换。张量通常要先缓冲化。参见 [LLVMCommon/TypeConverter.cpp](/opt/llvm-project/mlir/lib/Conversion/LLVMCommon/TypeConverter.cpp)。 |
| 用 C++ 直接定义的类型不通过 TD 定义，所以不能被操作采用；结构体不能被操作显式使用 | C++ 类型可以成为操作类型及 TD 约束描述的对象。`LLVMStructType` 是手写类型，`llvm.extractvalue`、`llvm.insertvalue` 明确处理聚合值。参见 [LLVMTypes.h](/opt/llvm-project/mlir/include/mlir/Dialect/LLVMIR/LLVMTypes.h:105)、[LLVMOps.td](/opt/llvm-project/mlir/include/mlir/Dialect/LLVMIR/LLVMOps.td:695)。 |
| IRDL 定义类型本质上基于 TD | IRDL 用 MLIR 操作描述方言与约束，可以用于动态定义；IRDL 方言自身用 TD 实现不等于用户 IRDL 定义本身是 TD。参见 [IRDL.td](/opt/llvm-project/mlir/include/mlir/Dialect/IRDL/IR/IRDL.td)、[IRDLOps.td](/opt/llvm-project/mlir/include/mlir/Dialect/IRDL/IR/IRDLOps.td)。 |

## 类型存储与构造

位置：PDF 第 11–22 页，代码清单 3-1 至 3-14，图 3-1。

1. `CArg<"SignednessSemantics", "Signless">` 表示 C++ 构造参数的类型与默认实参，不是谓词约束。依据 [Utils.td](/opt/llvm-project/mlir/include/mlir/IR/Utils.td:64) 和 [AttrTypeBase.td 的 builder 描述](/opt/llvm-project/mlir/include/mlir/IR/AttrTypeBase.td:83)。
2. 本地 `Builtin_Type` 还接收 `typeMnemonic`，并设置 `typeName = "builtin." # typeMnemonic`；`Builtin_Integer` 写作 `Builtin_Type<"Integer", "integer">`。原书漏掉的这个参数已经在清单 3-1、3-2、3-3 中同步修正。依据 [BuiltinTypes.td](/opt/llvm-project/mlir/include/mlir/IR/BuiltinTypes.td:26)。
3. `genStorageClass = 0` 意味着不自动生成存储类。`IntegerTypeStorage` 是手写实现，位置为 [TypeDetail.h](/opt/llvm-project/mlir/lib/IR/TypeDetail.h:28)。生成器会生成其名称引用，不会生成该类的定义。位宽 30 位、符号语义 2 位只解释两个参数如何压缩，不表示包含基类和对齐后的整个对象仅占 32 位。
4. `genVerifyDecl` 生成验证函数声明，具体类型验证逻辑仍要实现。`get()` 中的验证使用断言；需要诊断与失败返回时使用 `getChecked()`。类型构造验证不能与操作完整验证流程混淆。依据 [StorageUniquerSupport.h](/opt/llvm-project/mlir/include/mlir/IR/StorageUniquerSupport.h) 和 [IntegerType::verify](/opt/llvm-project/mlir/lib/IR/BuiltinTypes.cpp:63)。
5. `TypeBase` 是 `StorageUserBase` 的模板别名，`TypeUniquer` 是类型唯一化的访问辅助类，实际持有数据的是 context 中的 `StorageUniquer`。原书清单 3-14 的标题错误及缺失的最终 `getParametricStorageTypeImpl()` 调用已修正。依据 [TypeSupport.h](/opt/llvm-project/mlir/include/mlir/IR/TypeSupport.h:210)、[StorageUniquer.h](/opt/llvm-project/mlir/include/mlir/Support/StorageUniquer.h:196)。
6. `IntegerType::get()` 对常用整数类型先查快速缓存，随后调用通用唯一化机制，后者也会避免相同键重复分配。依据 [MLIRContext.cpp](/opt/llvm-project/mlir/lib/IR/MLIRContext.cpp:1066)。哈希值不是唯一键，查找还需进行键相等比较。
7. `registerType()` 为参数化类型准备存储基础设施，不会预先实例化所有参数组合，也不是先创建一个“没有位宽的 IntegerType”。无参数类型的 singleton 存储同样只在当前 context 内唯一。依据 [TypeSupport.h 的两个 registerType 重载](/opt/llvm-project/mlir/include/mlir/IR/TypeSupport.h:274)。
8. `GET_TYPEDEF_LIST` 展开为逗号分隔的类型类名列表，供 `addTypes<...>()` 使用，不是前向声明。`Types.cpp.inc` 是构建规则指定的输出名，不是 `mlir-tblgen` 的固定默认文件名。依据本地生成的 [BuiltinTypes.cpp.inc](/opt/llvm-project/build/tools/mlir/include/mlir/IR/BuiltinTypes.cpp.inc) 及 [IR/CMakeLists.txt](/opt/llvm-project/mlir/include/mlir/IR/CMakeLists.txt)。

图 3-1 保留 Type、IntegerType、TypeStorage、IntegerTypeStorage 及模板基类关系；将容易误解为句柄独占所有权的菱形箭头改为非拥有的 `impl` 指针关联，并补齐实际模板参数。

## 属性与特性

位置：PDF 第 22–24 页，代码清单 3-15 至 3-17。

属性表示编译时数据；`IntegerAttr` 是给定类型下的具体整数值，`IntegerType` 是位宽和符号语义，两者使用类似的句柄／唯一化存储机制，但语义不同。本地定义为 `Builtin_Attr<"Integer", "integer", [TypedAttrInterface]>`，原书缺少的助记参数和接口已补齐。依据 [BuiltinAttributes.td](/opt/llvm-project/mlir/include/mlir/IR/BuiltinAttributes.td:657)。

固有属性（inherent attributes）与可丢弃属性（discardable attributes）是属性语义上的分类，不能把它们直接当作 C++ 存储类层级；`Property` 也不是 `Attribute` 的一个子类。properties 是操作专有、由具体操作拥有的存储，可以承载固有属性或其他专用数据。采用 properties 的操作会把固有数据移出顶层属性字典；未采用该机制的操作仍可在顶层字典中保存固有属性。因此，这种演进不应解释为“方言是全局唯一，固有属性原先都是全局数据”。

`arith.cmpi` 的 `predicate` 仍保留为固有属性例子，正文完整列出十种取值。可丢弃属性则按由外部机制／方言定义和验证的语义说明，并以 `gpu.container_module` 为例。依据 [LangRef 的 Properties 与 Attributes](/opt/llvm-project/mlir/docs/LangRef.md:744)、[Operation.h 的 properties 存储接口](/opt/llvm-project/mlir/include/mlir/IR/Operation.h:885)、[DialectBase.td](/opt/llvm-project/mlir/include/mlir/IR/DialectBase.td:92)。

## addi 及生成代码差异

位置：PDF 第 25–30 页，代码清单 3-18 至 3-21。

原书展示 `Arith_AddIOp : Arith_TotalIntBinaryOp<"addi", [Commutative]>`，并给出没有属性的生成类。本地 LLVM 18 已将 `addi` 定义在 `Arith_IntBinaryOpWithOverflowFlags` 之上，包含默认值为 `none` 的 `overflowFlags`，具备溢出接口，并使用 properties 保存这一数据。正文仍保留原书解释的公共基类，又补入实际使用的基类，同时更新四份相互关联的清单，避免只改单处后导致 TD、记录、C++ 声明与构造实现互相矛盾。

依据：[ArithOps.td 的溢出标记基类](/opt/llvm-project/mlir/include/mlir/Dialect/Arith/IR/ArithOps.td:140)、[Arith_AddIOp](/opt/llvm-project/mlir/include/mlir/Dialect/Arith/IR/ArithOps.td:209)、[生成的 AddIOp 声明](/opt/llvm-project/build/tools/mlir/include/mlir/Dialect/Arith/IR/ArithOps.h.inc:538)、[生成实现](/opt/llvm-project/build/tools/mlir/include/mlir/Dialect/Arith/IR/ArithOps.cpp.inc)。这是扫描与本地实现的差异；不能据此推论“LLVM 20 去掉了 overflowFlags”。

其他修正：

- 原书清单 3-20 在 `AddIOp` 内返回操作名 `"arith.andi"`，末尾 TypeID 宏也使用 `AndIOp`。这两处属于明确的复制／内容错误，改为 `"arith.addi"` 与 `AddIOp`。
- `SignlessIntegerLike` 不是“无符号整数类型”，而是无符号语义整数、索引及相应元素类型的向量／张量约束。`Signless` 和 `Unsigned` 已区分。
- `Pure` 包含 `AlwaysSpeculatable` 和 `NoMemoryEffect`，不是只表示没有内存副作用。依据 [SideEffectInterfaces.td](/opt/llvm-project/mlir/include/mlir/Interfaces/SideEffectInterfaces.td:146)。
- `hasVerifier = 0` 表示没有用户自定义的 `verify()`，不表示没有生成的 ODS 不变式验证。`hasRegionVerifier` 对应 `verifyRegions()`，不是原注释中的 `regionVerify()`。
- `build()` 向传入的 `OperationState` 填入构造参数；生成类的 `build()` 返回 `void`，不直接返回 state，也不创建底层 `Operation`。未指定结果类型的重载调用 `inferReturnTypes()`，本地版本需要传入 properties。
- 生成的 `verifyInvariantsImpl()` 验证属性、操作数和结果的约束；单个约束辅助函数返回成功不代表全部操作验证完成。操作构造动作本身也不自动保证执行完整验证。
- `fold()` 不限于常量折叠，也能折叠到已有 SSA 值；归一化模式用于规范化 IR，而不是“对 Pass 执行过程”本身进行优化。
- 清单 3-20 的五类原有 builder 接口已保留并调整签名；另有三个接受 `IntegerOverflowFlagsAttr` 的重载，正文明确说明，清单 3-21 展示其中两个。生成代码里新增的完整 properties 序列化接口不作为原书遗漏正文补写，但保留源码入口。

用 [ch3-addi-overflow.mlir](evidence/ch3-addi-overflow.mlir) 运行本地 `mlir-opt --mlir-print-op-generic`，解析验证成功，通用输出包含：

```mlir
%0 = "arith.addi"(%arg0, %arg1)
  <{overflowFlags = #arith.overflow<nsw, nuw>}> : (i32, i32) -> i32
```

这验证了本地已有溢出标记及其 properties 表示，不是对加法数值行为的运行测试。完整输出见 [ch3-grammar-check.txt](evidence/ch3-grammar-check.txt)。

## TableGen 记录核验

实际执行本地 `mlir-tblgen` 展开 `BuiltinTypes.td` 和 `ArithOps.td`，并与清单 3-3、3-19 对照。可复现命令：

```sh
/opt/llvm-project/build/bin/mlir-tblgen \
  -I /opt/llvm-project/mlir/include \
  -I /opt/llvm-project/llvm/include \
  /opt/llvm-project/mlir/include/mlir/IR/BuiltinTypes.td

/opt/llvm-project/build/bin/mlir-tblgen \
  -I /opt/llvm-project/mlir/include \
  -I /opt/llvm-project/llvm/include \
  /opt/llvm-project/mlir/include/mlir/Dialect/Arith/IR/ArithOps.td
```

保留了相关完整记录到 [ch3-tblgen-records.td](evidence/ch3-tblgen-records.td)。正文使用实际输出的匿名编号：整数类型的谓词为 `anonymous_7`，CArg 和 builder 为 `anonymous_345`、`anonymous_346`；Arith 的向量展开／整数范围接口为 `anonymous_441`、`anonymous_442`，溢出接口及默认属性为 `anonymous_457`、`anonymous_458`。匿名编号是该输入集合的生成细节，不是稳定 API。

## 操作类、注册与 CRTP

位置：PDF 第 30–33 页，图 3-2 至 3-4、代码清单 3-22、3-23。

`AddIOp` 是包含 `Operation*` 的轻量句柄，其基类 `Op` 与多个特质通过 CRTP 组合。CRTP 仍然使用模板继承，不能解释为“不使用继承”或防止“各具体操作类互相影响”。`Operation` 与 `AddIOp` 没有基类／派生类关系；前者的分配块承载具体操作数据，后者提供该种操作的访问接口。

`TrailingObjects` 为一次分配中的尾部对象提供尺寸计算、对齐和寻址，不会在运行时增删 C++ 类成员或改变 `sizeof(Operation)`。模板本身不限制尾部类型数量为 5；当前 `Operation` 恰好使用 `OperandStorage`、`OpProperties`、`BlockOperand`、`Region`、`OpOperand` 五类。

原图 3-4 的递归尾部出现 `TrailingObjectsAligner<4>`，而本地代码以 `alignas(Align) TrailingObjectsImpl : TrailingObjectsBase` 终止递归。本机这些尾部类型的最大对齐为 8。正文重绘了本地递归关系，使用 `A` 表示最大对齐值、`T` 代表完整 `TrailingObjects` 特化，并明确说明缩写。依据 [TrailingObjects.h](/opt/llvm-project/llvm/include/llvm/Support/TrailingObjects.h:191)。

清单 3-22 原书使用 `ArithmeticDialect`／`ArithmeticOps.cpp.inc`，本地名称为 `arith::ArithDialect` 和 `mlir/Dialect/Arith/IR/ArithOps.cpp.inc`，已修正。`GET_OP_LIST` 展开为操作类名列表，不是前向声明。注册建立元数据，不在此实例化全部操作。依据 [ArithDialect.cpp](/opt/llvm-project/mlir/lib/Dialect/Arith/IR/ArithDialect.cpp:38)、[RegisteredOperationName](/opt/llvm-project/mlir/include/mlir/IR/OperationSupport.h:528)。

带具体类型的 `OpBuilder::create<OpTy>()` 要求操作已经注册；通用操作在允许未注册方言的场景中可另行构造。清单 3-23 的实际调用顺序是创建 state、执行 `build()` 填充、创建 `Operation`、构造并返回具体类型句柄。依据 [Builders.h](/opt/llvm-project/mlir/include/mlir/IR/Builders.h:474)。

<a id="operation-layout"></a>

## Operation 内存布局与实测

位置：PDF 第 34–35 页，代码清单 3-24、图 3-5。

原清单同时存在参数缺失、空间计算未包含 properties、未定义变量及原图错误，无法作为本地代码直接使用。正文采用 [Operation.cpp 的 DictionaryAttr 重载](/opt/llvm-project/mlir/lib/IR/Operation.cpp:81) 的完整关键实现，保留全部结果、区域、操作数及后继引用初始化步骤，并补充以下信息。

| 项目 | 原扫描问题与处理 |
| --- | --- |
| `NamedAttrList` 重载 | 本地此重载补默认属性，然后转交给 `DictionaryAttr` 重载；后者才执行实际分配。正文说明重载关系。 |
| properties | 原参数及 `totalSizeToAlloc` 类型列表漏掉这一项，和正文声称“五类”相矛盾。本地签名有 `OpaqueProperties properties`，分配量为 `alignTo<8>(name.getOpPropertyByteSize())`。 |
| `needsOperandStorage`、`numResults` | 原清单使用但没有给出定义。已补齐。空操作数且有 `ZeroOperands` 特质时可省略操作数管理存储。 |
| 后继 | `successors.size()` 是后继引用数量；构造的 `BlockOperand` 引用基本块，不是在此分配基本块对象。 |
| 结果存储 | 直接 placement-new 构造 `InlineOpResult` 和 `OutOfLineOpResult` 对象，不是指针数组。它们位于 `Operation` 之前，以反向索引寻址。 |
| 指针位置 | `Operation*` 指向本体起点，与 `malloc` 分配块起点相差前置结果空间。 |
| 构造收尾 | 必须在 properties 初始化后 `op->setAttrs(attributes)`；原清单漏掉，正文补齐。 |
| 大小 | 固定的是当前 ABI 的 `sizeof(Operation)`，变长的是整个分配块；原文将 C++ 对象大小与分配块大小混淆。 |

前 6 个结果内联这一点**原书正确**。本地 `Operation.h` 开头概述注释写“前 5 个”，但执行代码为 [Value.h 的 `Kind::OutOfLineOpResult = 6`](/opt/llvm-project/mlir/include/mlir/IR/Value.h:55)，[`getMaxInlineResults()`](/opt/llvm-project/mlir/include/mlir/IR/Value.h:386) 返回这个数值，[Value.cpp 的 `getNumInline()`](/opt/llvm-project/mlir/lib/IR/Value.cpp:185) 使用该上限。因此本次没有机械依据上游过时注释将 6 改为 5。

主校对代理编译运行了 [ch3-operation-layout.cpp](evidence/ch3-operation-layout.cpp)，并用 Clang 的记录布局输出核对字段。结果保留在 [ch3-operation-sizes.txt](evidence/ch3-operation-sizes.txt) 与 [ch3-operation-record-layout.txt](evidence/ch3-operation-record-layout.txt)。本机结果为：

```text
maxInlineResults=6
sizeof(Operation)=64 alignof(Operation)=8
sizeof(AddIOp)=8 sizeof(Operation*)=8
InlineOpResult=16 OutOfLineOpResult=24
OperandStorage=16 OpProperties=1 BlockOperand=32 Region=24 OpOperand=32
```

`OpProperties` 是以 `char` 为底层类型的枚举占位类型，`sizeof` 为 1 并不表示属性整体只需 1 字节，更不表示是一个 8 字节指针。`propertiesStorageSize` 字段按 8 字节单位编码大小，分配和寻址使用实际对齐后的字节数量。依据 [Operation.h](/opt/llvm-project/mlir/include/mlir/IR/Operation.h:28) 与 [属性大小字段说明](/opt/llvm-project/mlir/include/mlir/IR/Operation.h:1049)。

原图漏掉偏移 32 的 `orderIndex`，其后计数字段也有错位；正文给出实际字段表。链表基类的真实字段名为 `PrevAndSentinel` 和 `Next`，对应原图的逻辑前驱／后继。`numRegions` 占 23 位，而 `hasOperandStorage` 在字节 46 的第 7 位。上述字节偏移和大小仅描述本机编译器、ABI 与构建配置，不是跨平台保证。

## dyn_cast 与具体操作句柄

位置：PDF 第 36–37 页，代码清单 3-25 至 3-27。

原文多次写“`Operation*` 到 `AddIOp*`”，与实际 `dyn_cast<AddIOp>(op)` 返回类型不符。正确结果是 `AddIOp` 值句柄。转换先调用 `AddIOp::classof()` 比较注册的 `TypeID`，成功后用 `AddIOp(Operation*)` 构造句柄，不新建底层 `Operation`，也不是将两个没有继承关系的对象强行指针重解释。

原清单 3-27 将 `Op(std::nullptr_t)` 标为上述转换的构造函数，这是明确内容错误：它只创建空句柄。真正使用的是 `explicit Op(Operation *state) : OpState(state)`。正文同时保留空句柄构造器以说明区别，并补齐 Debug 构建中同名但未注册操作的诊断分支。

依据：[Operation.h 的 CastInfo 特化](/opt/llvm-project/mlir/include/mlir/IR/Operation.h:1100)、[Casting.h 的 DefaultDoCastIfPossible 与 ValueFromPointerCast](/opt/llvm-project/llvm/include/llvm/Support/Casting.h:309)、[OpDefinition.h 的 classof 与构造函数](/opt/llvm-project/mlir/include/mlir/IR/OpDefinition.h:1687)。[布局验证程序](evidence/ch3-operation-layout.cpp) 还使用 `static_assert` 检查返回值恰为 `mlir::arith::AddIOp` 且不是指针，编译通过。

关于标准 C++ 的说明也作了限定：需要运行时检查的向下转换要求源类型多态；并非所有 `dynamic_cast` 都要求虚函数，无歧义向上转换不需要这一前提。常见 ABI 用虚表支持 RTTI，但 C++ 标准不强制某种具体虚表布局。LLVM 的定制转换机制不应简单说成标准机制“不合理”的替代品。

<a id="operation-grammar"></a>

## 文法核验：原书、上游说明与实际解析器

位置：PDF 第 18–19、38–39 页，代码清单 3-10、3-11、3-28、3-29。

本次不仅修复 OCR 中的括号和转义，还实际检查了执行解析代码。发现三处原书文法与本地文档／注释相同、但与执行代码不同的情况：

| 项目 | 原文／上游说明 | 本地实现与修正 |
| --- | --- | --- |
| 函数输入类型 | `(type \| type-list-parens) -> ...` 允许输入不带括号 | [TypeParser.cpp](/opt/llvm-project/mlir/lib/AsmParser/TypeParser.cpp:153) 要求 `type-list-parens`。改为输入必须有括号，结果使用 `function-result-type`；`i32 -> i32` 被拒绝，`(i32) -> i32` 通过。 |
| 整数位宽词法 | `[1-9][0-9]*` 排除 0 及前导零 | [Lexer.cpp](/opt/llvm-project/mlir/lib/AsmParser/Lexer.cpp:224) 检查后缀全是数字，[Token.cpp](/opt/llvm-project/mlir/lib/AsmParser/Token.cpp:64) 按十进制解析，[TypeParser.cpp](/opt/llvm-project/mlir/lib/AsmParser/TypeParser.cpp:286) 与 [IntegerType::verify](/opt/llvm-project/mlir/lib/IR/BuiltinTypes.cpp:63) 只检查最大位宽。`i0`、`si0`、`ui0` 与 `i032` 都通过；正文写 `[0-9]+` 并补充数值上界和后端支持限制。 |
| 通用操作后继 | `caret-id (':' block-arg-list)?` | [Parser.cpp 的 parseSuccessor](/opt/llvm-project/mlir/lib/AsmParser/Parser.cpp:1240) 仅消费一个基本块标识符，随后只接受逗号或右方括号。因此通用形式改为 `successor ::= caret-id`；传入后继的值在操作数列表中，由操作定义映射。自定义 `parseSuccessorAndUseList` 使用直接的小括号参数列表，也没有冒号。 |

另外，`%r:2` 的冒号表示绑定一组 2 个结果，并非访问“子结果”。访问该组中各结果使用 `%r#0`、`%r#1`。字典属性条目和多个区域都以逗号分隔；区域使用大括号包围；操作类型前是冒号，不是分号。这些地方在正文同时修正原注释及 OCR。

验证输入与结果：

- [ch3-grammar-valid.mlir](evidence/ch3-grammar-valid.mlir)：通用 `cf.br` 传参、两个结果绑定及访问、零位宽／前导零整数类型、合法函数类型；`mlir-opt --allow-unregistered-dialect` 退出 0。
- [ch3-grammar-bad-successor.mlir](evidence/ch3-grammar-bad-successor.mlir)：按原后继文法写冒号参数，退出 1，诊断 `expected ',' or ']'`。
- [ch3-grammar-bad-function.mlir](evidence/ch3-grammar-bad-function.mlir)：无括号函数输入，退出 1，解析不能将 `i32 -> i32` 作为该属性值。
- 完整命令、版本、返回码与打印／诊断输出保存在 [ch3-grammar-check.txt](evidence/ch3-grammar-check.txt)。

合法样例中的 `test.*` 是用于语法核验的未注册操作；允许未注册方言不等于实现了其领域语义。零位宽类型可以解析，也不意味着每种算术操作或向 LLVM IR 的转换都支持它。

## 第 3 章尾部校订：PDF p. 39–50（书页 54–65）

本补充覆盖 `insider-compiler-ch2-ch3.pdf` 的 PDF 第 39–50 页：代码清单 3-29 的续篇、3.4 方言、3.5 编译上下文管理和 3.6 本章小结。基于 Apple Vision 原始 OCR 逐页核对对应 PNG，已实际目视全部 12 页。保留 12 个来源页标记、代码清单 3-30–3-37 的完整内容及 3-29 的续篇、表 3-1 全部 4 行、图 3-6–3-8 全部节点与说明。三图均已重建为 Mermaid，图 3-7/3-8 另用字段表保留原图标注；本页段未发现页脚脚注，全部“注意”说明保留并校订。

核对基准为本地 `/opt/llvm-project`，提交 `3b5b5c1ec4a3095ab096dd780e84d7ab81f3d7ff`，`mlir-tblgen --version` 与 `mlir-opt --version` 均报告 **LLVM 18.1.8、DEBUG build with assertions**。书稿参考 LLVM 20，本记录只据本地已查证的实现修订；未核对 LLVM 20 的细节不会仅因与本地不同就断言书稿对应版本错误。正文采用本地字段和接口名称；原始 OCR 不改动。

| 位置 | 原文问题与处理 | 本地依据 |
| --- | --- | --- |
| p. 39，清单 3-29 续篇 | 恢复 `block-label`、`block-id`、`caret-id`、`value-id-and-type` 与参数列表的完整产生式，修复 OCR 吞失的 `^`、`::=`、括号和星号。 | [LangRef.md](/opt/llvm-project/mlir/docs/LangRef.md:359) |
| p. 39–40，3.4.1 | 本节实际先以 `arith` 定义方言，再以内建方言举例，调整导语。`name` 是方言名，不是“字段名称”。默认属性解析/打印除声明外还有分派实现。 | [ArithBase.td](/opt/llvm-project/mlir/include/mlir/Dialect/Arith/IR/ArithBase.td:15)、[DialectBase.td](/opt/llvm-project/mlir/include/mlir/IR/DialectBase.td:72) |
| p. 40，清单 3-31 | `hasNonDefaultDestructor` 表示是否自行提供非默认析构实现，0 时生成默认实现；`usePropertiesForAttributes` 表示将 ODS 固有属性存到 properties，原文把方向写反。`hasOperationInterfaceFallback` 是接口后备查询钩子；区域参数/结果校验针对其属性。 | [DialectBase.td](/opt/llvm-project/mlir/include/mlir/IR/DialectBase.td:56)、[DialectBase.td](/opt/llvm-project/mlir/include/mlir/IR/DialectBase.td:92) |
| p. 40，清单 3-31 | `DialectBase.td` 中 `description` 声明为 `string`，但本地实际 `--print-records` 对这里的代码块值打印为 `code description = [{...}]`。已用真实输出核对并保留书中 `code` 形式，未凭声明类型误改记录。 | [DialectBase.td](/opt/llvm-project/mlir/include/mlir/IR/DialectBase.td:29)，本次实际生成的 `/private/tmp/insider-ch3-tail-check/Arith.records` |
| p. 40，dependentDialects | 原文要求所有降级/变换都必须在源方言 TD 声明目标方言，过于绝对。该字段描述方言构造时加载的依赖；独立 Pass 创建的方言构造通常由 Pass 的 `getDependentDialects` 声明。 | [DialectBase.td](/opt/llvm-project/mlir/include/mlir/IR/DialectBase.td:31)、[Pass.h](/opt/llvm-project/mlir/include/mlir/Pass/Pass.h:72) |
| p. 40–41，清单 3-32/3-33 | 补全原清单隐含的 `mlir::arith` 命名空间范围，恢复析构函数、友元、类型 ID 宏、属性解析/打印和常量物化函数。`initialize()` 不是唯一可能需要开发者实现的函数；启用的 `materializeConstant` 也需要实现。 | [ArithDialect.cpp](/opt/llvm-project/mlir/lib/Dialect/Arith/IR/ArithDialect.cpp:38)、[ArithDialect.cpp](/opt/llvm-project/mlir/lib/Dialect/Arith/IR/ArithDialect.cpp:52)，并重新生成方言声明/定义核对 |
| p. 41、48、50，上下文与注册 | `DialectRegistry::insert` 保存名称到 `(TypeID, constructor)` 的注册信息；加入 registry 不立刻构造全部方言。加载才会构造并缓存。`MLIRContext` 非进程唯一，亦非每线程必须唯一。 | [DialectRegistry.h](/opt/llvm-project/mlir/include/mlir/IR/DialectRegistry.h:133)、[MLIRContext.cpp](/opt/llvm-project/mlir/lib/IR/MLIRContext.cpp:450) |
| p. 42，方言接口 | 修正为本地名称 `arm_sve`、`DialectInlinerInterface`；`gpu` 为高层 GPU 抽象，不能推出其所有操作可直接翻译到 LLVM IR。内联 Pass 根据调用/区域/操作分派钩子，不是简单遍历方言分别执行内联。 | [LLVMTranslationInterface.h](/opt/llvm-project/mlir/include/mlir/Target/LLVMIR/LLVMTranslationInterface.h:38)、[InliningUtils.h](/opt/llvm-project/mlir/include/mlir/Transforms/InliningUtils.h:43) |
| p. 42–44，3.4.2 | `extensions` 存扩展对象而不是方言对象；`apply` 首参是上下文，不是“功能类”；`extensions` 属于 registry 而不是直接属于 context。定义扩展类后还须注册。依赖全部加载后才应用，空依赖列表对各已加载方言分别应用。 | [DialectRegistry.h](/opt/llvm-project/mlir/include/mlir/IR/DialectRegistry.h:36)、[Dialect.cpp](/opt/llvm-project/mlir/lib/IR/Dialect.cpp:215) |
| p. 42，扩展能力范围 | 通用接口扩展不能等同于任意方言均可动态加入新操作/类型。`TransformDialect` 自身提供扩展入口；动态操作等能力还涉及 `ExtensibleDialect`/动态方言注册。正文保留扩展示例并补充分界。 | [DialectBase.td](/opt/llvm-project/mlir/include/mlir/IR/DialectBase.td:88)、[DialectRegistry.h](/opt/llvm-project/mlir/include/mlir/IR/DialectRegistry.h:169) |
| p. 43，清单 3-34 | 按本地代码使用 `std::tuple<DialectsT *...>{ ... }`，避免圆括号实参求值顺序使递增索引与方言参数对应失序；恢复被 OCR 破坏的模板参数、`static_cast`、`make_unique`、引用和 `std::apply`。 | [DialectRegistry.h](/opt/llvm-project/mlir/include/mlir/IR/DialectRegistry.h:89) |
| p. 43，清单 3-35 | `ArithToLLVMDialectInterface` 提供转换为 LLVM 方言的模式，不是直接翻译为 LLVM IR；后者由 `LLVMTranslationDialectInterface` 在另一个阶段执行。该示例在本地存在。 | [ArithToLLVM.cpp](/opt/llvm-project/mlir/lib/Conversion/ArithToLLVM/ArithToLLVM.cpp:461)、[ArithToLLVM.cpp](/opt/llvm-project/mlir/lib/Conversion/ArithToLLVM/ArithToLLVM.cpp:480) |
| p. 44，清单 3-36 | 文中及标题多处将 `addExtension()` 误写为 `addExtensions()`；按代码区分单个回调/对象注册与扩展类参数包注册。函数指针重载转发到 `std::function` 重载，后者再封装局部 Extension 类。 | [DialectRegistry.h](/opt/llvm-project/mlir/include/mlir/IR/DialectRegistry.h:209)、[DialectRegistry.h](/opt/llvm-project/mlir/include/mlir/IR/DialectRegistry.h:229) |
| p. 44，注意 | “扩展不会改变原始对象本身”容易误导。接口附加不改变 C++ 类布局，但会改变内部已注册接口等状态，正文明确此区别。 | [Dialect.h](/opt/llvm-project/mlir/include/mlir/IR/Dialect.h:361) |
| p. 44–45，类型/属性管理 | 原文将 Type 与 TypeStorage 解释成先实例化一个无存储 Type、使用时再单独造 Storage，错误。注册建立 `AbstractType` 元数据并登记存储类型；Type 是对具体存储的轻量引用。普通参数化类型/属性按上下文、种类与参数唯一化；`DistinctAttr` 是专门例外。 | [TypeSupport.h](/opt/llvm-project/mlir/include/mlir/IR/TypeSupport.h:269)、[MLIRContext.cpp](/opt/llvm-project/mlir/lib/IR/MLIRContext.cpp:271) |
| p. 45，操作与图 3-6 | 操作随编译器创建/变换/删除 IR 而生灭，不随目标程序执行而生灭；registry/context 管元数据，IR 基本块等拥有具体实例。重建原图的 add/sub/insertElement、array/function、CConv/linkage 等节点，并明确此图是逻辑关系。 | [Block.h](/opt/llvm-project/mlir/include/mlir/IR/Block.h:129)、[MLIRContext.cpp](/opt/llvm-project/mlir/lib/IR/MLIRContext.cpp:185) |
| p. 45–46，内建方言与跨方言类型 | 原文称内建方言不参与匹配/转换，且“只有内建类型能被其他方言使用”，理由是 C++ 命名空间。前者被 unrealized cast 直接反例否定，后者混淆命名空间与访问限制。保留提示位置与解释主题，改为任何方言类型均可在满足声明/加载和操作约束后跨方言使用。 | [BuiltinOps.td](/opt/llvm-project/mlir/include/mlir/IR/BuiltinOps.td:101)、[LLVMTypes.cpp](/opt/llvm-project/mlir/lib/Dialect/LLVMIR/IR/LLVMTypes.cpp:458)（以通用 `Type` 元素表构建 LLVM 结构体的实例） |
| p. 46，类型分类 | `i1`、`i32` 等均为带位宽/符号性参数的 `IntegerType` 实例，不是独立单例种类或其子类。常用实例由上下文缓存；`f8` 需指明具体格式。`complex` 支持整数或浮点元素，函数类型可有多个结果。 | [BuiltinTypes.td](/opt/llvm-project/mlir/include/mlir/IR/BuiltinTypes.td:333)、[MLIRContext.cpp](/opt/llvm-project/mlir/lib/IR/MLIRContext.cpp:326)、[BuiltinTypes.cpp](/opt/llvm-project/mlir/lib/IR/BuiltinTypes.cpp:51) |
| p. 46，表 3-1 | 修正本地 C++ 类名 `MemRefType`/`UnrankedMemRefType`；保留全部四字段。修复示例 `1x0x32` 为 `memref<1x0xf32>`，说明 0 是零长度，动态维度为 `?`。 | [BuiltinTypes.td](/opt/llvm-project/mlir/include/mlir/IR/BuiltinTypes.td:415)、[BuiltinTypes.td](/opt/llvm-project/mlir/include/mlir/IR/BuiltinTypes.td:628) |
| p. 46，ranked/unranked | 有秩不代表全部维度静态、字节数已知。补充 `memref<?xf32>`、`tensor<?xf32>` 与可伸缩向量；无秩 memref 还具有 memory space，不能说只保存元素类型。 | [BuiltinTypes.td](/opt/llvm-project/mlir/include/mlir/IR/BuiltinTypes.td:604)、[BuiltinTypes.td](/opt/llvm-project/mlir/include/mlir/IR/BuiltinTypes.td:925)、[BuiltinTypes.td](/opt/llvm-project/mlir/include/mlir/IR/BuiltinTypes.td:1100) |
| p. 47，clone/mutate/唯一化 | `clone` 仍返回唯一化后的类型，未必新分配；`mutate` 只用于已声明可变特性的类型并保持键不变。以 LLVM 具名结构体设置 body 解释受控可变性。底层存储既有类型映射也有 DenseSet，而非简单一张 DenseMap。 | [BuiltinTypes.cpp](/opt/llvm-project/mlir/lib/IR/BuiltinTypes.cpp:386)、[StorageUniquerSupport.h](/opt/llvm-project/mlir/include/mlir/IR/StorageUniquerSupport.h:215)、[LLVMTypes.cpp](/opt/llvm-project/mlir/lib/Dialect/LLVMIR/IR/LLVMTypes.cpp:458)、[StorageUniquer.cpp](/opt/llvm-project/mlir/lib/Support/StorageUniquer.cpp:76) |
| p. 47，属性介绍 | 恢复全部位置属性与一般属性名称。元素属性“具有 tensor/vector 类型”，并非操作结果。整数集可含等式；SparseElements 不限于二维矩阵；OpaqueAttr 的不透明表示不等于方言一定未定义；`StridedLayoutAttr` 为偏移/步长布局，不是“条状布局”。 | [BuiltinAttributes.td](/opt/llvm-project/mlir/include/mlir/IR/BuiltinAttributes.td:156)、[BuiltinAttributes.td](/opt/llvm-project/mlir/include/mlir/IR/BuiltinAttributes.td:746)、[BuiltinAttributes.td](/opt/llvm-project/mlir/include/mlir/IR/BuiltinAttributes.td:969) |
| p. 48，内建操作 | Graph 区域不要求 SSA 支配，但仍有 SSA 值与定义使用规则；可以有前向引用，Module 并非唯一合法根操作。UnrealizedConversionCast 是过渡类型连接，没有运行时转换语义，不是修补缺失类型。 | [LangRef.md](/opt/llvm-project/mlir/docs/LangRef.md:587)、[BuiltinOps.td](/opt/llvm-project/mlir/include/mlir/IR/BuiltinOps.td:101) |
| p. 48，图 3-7 | 保留七个字段和解释，按源码修正 `Name/ID` 为 `name/dialectID`、`unknownOpsAllowed/unknownTypesAllowed` 拼写和完整 `unresolvedPromisedInterfaces` 名称。后者为“已承诺但尚未提供实现”的接口，不是任意未实现接口。 | [Dialect.h](/opt/llvm-project/mlir/include/mlir/IR/Dialect.h:339) |
| p. 49，图 3-8 | 保留原图全部具名字段和省略组，修复 OCR 标识符。`allowUnregisteredDialects` 不是加载开关；`operations` 的未注册信息不是动态注册；`registeredTypes/registeredAttributes` 存抽象元数据；线程池指针不只指外部池；`distinctAttributeAllocator` 为独立身份属性分配器，不是字典属性管理器。实际成员位于 pImpl 且本地还有原图省略的成员，图不是 ABI 布局。 | [MLIRContext.cpp](/opt/llvm-project/mlir/lib/IR/MLIRContext.cpp:123)、[MLIRContext.cpp](/opt/llvm-project/mlir/lib/IR/MLIRContext.cpp:147)、[MLIRContext.cpp](/opt/llvm-project/mlir/lib/IR/MLIRContext.cpp:215)、[MLIRContext.cpp](/opt/llvm-project/mlir/lib/IR/MLIRContext.cpp:271) |
| p. 49–50，清单 3-37与小结 | 恢复 `addExtensions` 拼写，将不可编译占位符 `***DialectExtension` 改为明确说明的 `MyDialectExtension`，把方言列表省略号改为注释。强调 registry 构造 Context 后只有内建方言保证预加载，其他按需加载；小结同步修正注册/加载与实例生命周期。 | [MLIRContext.cpp](/opt/llvm-project/mlir/lib/IR/MLIRContext.cpp:292)、[DialectRegistry.h](/opt/llvm-project/mlir/include/mlir/IR/DialectRegistry.h:215) |

### 本地验证

1. 使用本地 `mlir-tblgen` 对真正的 `ArithOps.td` 执行 `--print-records`、`--gen-dialect-decls --dialect=arith`、`--gen-dialect-defs --dialect=arith`，均退出 0。核对了清单 3-31 的全部字段、`code description` 的真实打印形式、清单 3-32 声明以及清单 3-33 构造器调用 `initialize()`。
2. 编译并运行一个链接本地 MLIR IR/Support 库的 C++ 程序（[context.cpp](/opt/coding/mlir-toy/mlir/insider-compiler/issues/evidence/ch3-tail/context.cpp)）。程序验证：注册不立即加载方言；Context 默认已加载 Builtin；一个依赖两种方言的扩展仅在两者都加载后执行，并且传入方言指针顺序正确；重复 getOrLoad 复用对象且不重复执行扩展；不同 Context 的 f32 存储不同；`i1/i7` 同属 IntegerType 且相同参数复用；有秩 memref 可含动态维度；相同参数的 clone 复用原存储；零长度为静态形状且元素数为 0；无秩 memref 保存 memory space；两个 DistinctAttr 即使引用相同 UnitAttr 仍身份不同。最终输出 `PASS: lazy loading; two-dialect extension ordering; per-context uniquing; IntegerType kind; ranked dynamic shape; clone reuse; zero extent; unranked memory space; DistinctAttr identity`。
3. 使用 `mlir-opt` 解析并验证 Module Graph 区域中先 `arith.addi %x, %x`、后定义 `%x = arith.constant 1 : i32` 的程序，退出 0 且打印后仍保留前向使用，验证“不要求 SSA 支配”的表述。

验证是针对上述具体内容修正，不代表整章所有仅展示声明、片段或占位符的清单可以独立编译。原书显式省略的描述内容和方言列表仍按省略示例保留，未虚构被省略的正文。本页段没有尚未辨认的扫描文字或图中节点。

### 验证证据与复现命令

已将 C++ 检查程序与 Graph 区域输入保存到 [context.cpp](/opt/coding/mlir-toy/mlir/insider-compiler/issues/evidence/ch3-tail/context.cpp) 和 [graph.mlir](/opt/coding/mlir-toy/mlir/insider-compiler/issues/evidence/ch3-tail/graph.mlir)。以下是本次使用的生成、编译与运行命令；构建产物留在临时目录，不提交二进制文件。

```sh
mkdir -p /private/tmp/insider-ch3-tail-check
/opt/llvm-project/build/bin/mlir-tblgen \
  -I /opt/llvm-project/mlir/include -I /opt/llvm-project/llvm/include \
  --print-records /opt/llvm-project/mlir/include/mlir/Dialect/Arith/IR/ArithOps.td \
  -o /private/tmp/insider-ch3-tail-check/Arith.records
/opt/llvm-project/build/bin/mlir-tblgen \
  -I /opt/llvm-project/mlir/include -I /opt/llvm-project/llvm/include \
  --gen-dialect-decls --dialect=arith \
  /opt/llvm-project/mlir/include/mlir/Dialect/Arith/IR/ArithOps.td \
  -o /private/tmp/insider-ch3-tail-check/ArithDialect.h.inc
/opt/llvm-project/build/bin/mlir-tblgen \
  -I /opt/llvm-project/mlir/include -I /opt/llvm-project/llvm/include \
  --gen-dialect-defs --dialect=arith \
  /opt/llvm-project/mlir/include/mlir/Dialect/Arith/IR/ArithOps.td \
  -o /private/tmp/insider-ch3-tail-check/ArithDialect.cpp.inc
clang++ -std=c++17 -fno-rtti -fno-exceptions \
  -I /opt/llvm-project/mlir/include -I /opt/llvm-project/llvm/include \
  -I /opt/llvm-project/build/include \
  -I /opt/llvm-project/build/tools/mlir/include \
  /opt/coding/mlir-toy/mlir/insider-compiler/issues/evidence/ch3-tail/context.cpp \
  -L /opt/llvm-project/build/lib -L /opt/homebrew/lib \
  -lMLIRIR -lMLIRSupport -lLLVMCore -lLLVMBinaryFormat -lLLVMRemarks \
  -lLLVMBitstreamReader -lLLVMSupport -lLLVMDemangle \
  -lz -lzstd -lcurses -lxml2 \
  -o /private/tmp/insider-ch3-tail-check/context
/private/tmp/insider-ch3-tail-check/context
/opt/llvm-project/build/bin/mlir-opt \
  /opt/coding/mlir-toy/mlir/insider-compiler/issues/evidence/ch3-tail/graph.mlir
```
