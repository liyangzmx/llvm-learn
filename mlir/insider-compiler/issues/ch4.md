# 第 4 章校订记录

本记录对应 [第 4 章：谓词、特质和接口](../insider-compiler-ch4.md)。来源为 `pdf/insider-compiler-ch4.pdf`，共 25 个 PDF 页面，对应书页 66～90。PDF 第 1 页为带正文的章节首页，不能跳过。

## 核对范围与依据

- 已通过 `view_image` 实际目视 **25/25 页**，与 Apple Vision 的逐页原始 OCR 文本对照。原始 `ocr/insider-compiler-ch4/page-NNN.txt`、`.json`、`.png` 未作修改。
- 校订 Markdown 含完整的 4.1～4.4 节、**19 个代码清单（4-1～4-19）**、**2 幅图（4-1、4-2）**、3 条原书脚注及两个“注意”说明框。此章没有原书表格。跨页代码块为放置来源标记分开，阅读时应视为同一清单的续段。
- 每页内容前均有 `<!-- source: insider-compiler-ch4.pdf, PDF p. N -->`，程序检查确认 1～25 连续、无重复、无缺页。
- 代码依据：`/opt/llvm-project`，提交 `3b5b5c1ec4a3095ab096dd780e84d7ab81f3d7ff`。`build/bin/mlir-opt --version` 和 `build/bin/mlir-tblgen --version` 均显示 **LLVM 18.1.8，DEBUG build with assertions**，本次按工具与实际检出版本记录。
- 原书以 LLVM 20 为背景。下面“本地差异”只说明 LLVM 18.1.8 的事实；没有检出 LLVM 20 源码，因此不把所有不一致都武断归为原书错误或版本演进。
- 本章的语法省略号 `...` 仍为原书示意代码，未杜撰卷积计算成本等业务实现。正文的文字订正均尽量保留原有论述目的。

## OCR 与排版修正

逐页改正了 `MILIR`/`MIL.IR` → `MLIR`，`11vm`/`lvm` → `llvm`，`1hs` → `lhs`，`Imp1` → `Impl`，`getImp1` → `getImpl`，`0p` → `Op`，以及 `I1`/`11`、`I32`/`132`、`F32`/`E32` 等混淆。统一恢复 `$` 占位符、C++ `::`、花括号、模板尖括号、`->`、`==`、`||`、分号与真实缩进；合并因扫描换行断开的 API 名称，去除重复页眉页脚。代码是否正确不只以 OCR 为准，已再对照图像及源码。

## 实质校订与源码依据

表中的页码格式为“PDF 页 / 书页”。

| 位置 | 原书表述或问题 | 本次处理 | 本地依据 |
| --- | --- | --- | --- |
| 1 / 66 | `Constraint` 继承谓词；谓词属于构建阶段“静态约束” | 改为 `Constraint` 包含 `Pred predicate`；TD 声明生成的是编译器运行时的验证代码，不是 C++ 编译期检查 | [Constraints.td:137](/opt/llvm-project/mlir/include/mlir/IR/Constraints.td:137)、[Verifier.cpp:179](/opt/llvm-project/mlir/lib/IR/Verifier.cpp:179) |
| 1 / 66 | `concat` 连接多个谓词、`negative` 等名称 | 使用真实类名 `And`、`Or`、`Neg`、`Concat`、`SubstLeaves`；`Concat` 为一个子表达式添加前后字符串，`SubstLeaves` 做叶节点字符串替换 | [Constraints.td:85](/opt/llvm-project/mlir/include/mlir/IR/Constraints.td:85) |
| 2 / 67 | `CPred<"::llvm::isa<::mlir::F32>">` | 改成 `CPred<"::llvm::isa<::mlir::Float32Type>($_self)">`；`F32` 是 TD 约束名，不能当作该 C++ 类型名，且 `isa` 需要实参 | [Constraints.td:43](/opt/llvm-project/mlir/include/mlir/IR/Constraints.td:43)、[BuiltinTypes.h](/opt/llvm-project/mlir/include/mlir/IR/BuiltinTypes.h) |
| 2 / 67 | 将 successor 泛指区域、块或指令；`cppClassName` 是命名空间限制 | 改为操作的后继基本块；`cppClassName` 为相应 C++ 类型类名 | [Operation.h:704](/opt/llvm-project/mlir/include/mlir/IR/Operation.h:704)、[Constraints.td:151](/opt/llvm-project/mlir/include/mlir/IR/Constraints.td:151) |
| 3 / 68 | “完成记录类”、匿名编号固定 | 改为展开后的完整记录，保留原匿名编号作示意并注明编号取决于输入；补充 F16/F32 约束与实际具体类型的区别 | [CommonTypeConstraints.td:305](/opt/llvm-project/mlir/include/mlir/IR/CommonTypeConstraints.td:305) |
| 4 / 69，清单 4-5 | `F16:$lhs, F32:$rhs` 被展示为一个 `isF16() \|\| isF32()` 检查 | **与清单 4-4 不符的内容错误。** 改为 lhs、rhs 各自的 F16/F32 检查；F64 结果另行检查。原析取谓词只适合 `AnyTypeOf<[F16, F32]>` 一类约束 | 本地 `mlir-tblgen --gen-op-defs` 实际生成并检查，见下文验证记录 |
| 4 / 69、25 / 90 | 构建操作后自动调用完整 verifier | 改为 `mlir::verify`、解析及 Pass 验证阶段调用；普通 `Operation::create` 不保证立即验证 | [Operation.cpp:82](/opt/llvm-project/mlir/lib/IR/Operation.cpp:82)、[OpDefinition.h:2008](/opt/llvm-project/mlir/include/mlir/IR/OpDefinition.h:2008)、[Verifier.cpp:179](/opt/llvm-project/mlir/lib/IR/Verifier.cpp:179)；C++ 运行实验亦验证 |
| 5 / 70 | `SignlessIntegerLike` 表示有符号整数与 index | **语义错误。** 改为 signless 整数或 index，以及对应向量、张量容器 | [CommonTypeConstraints.td:842](/opt/llvm-project/mlir/include/mlir/IR/CommonTypeConstraints.td:842)、[CommonTypeConstraints.td:863](/opt/llvm-project/mlir/include/mlir/IR/CommonTypeConstraints.td:863) |
| 5 / 70 | 将 `UI128`、`SI128`、`F8E4M3`、`F8E3M4`、`I128Attr`、`UI128Attr`、`SI128Attr` 都列为预定义记录 | 本地未定义这些记录。保留原书列举信息并明确本地缺失；128 位约束可从 `UI<128>`、`SI<128>` 和相应属性基类定义。此项作为本地差异，不声称所有版本都没有 | [CommonTypeConstraints.td:219](/opt/llvm-project/mlir/include/mlir/IR/CommonTypeConstraints.td:219)、[CommonTypeConstraints.td:326](/opt/llvm-project/mlir/include/mlir/IR/CommonTypeConstraints.td:326)、[CommonAttrConstraints.td:228](/opt/llvm-project/mlir/include/mlir/IR/CommonAttrConstraints.td:228) |
| 5 / 70 | 直接使用 `IntArrayNthElemEq` 即可完成整数数组属性约束 | 补充需组合整数数组类型检查，`index` 从 0 开始；该约束本身用 `cast` 假定属性及元素类型已满足要求 | [CommonAttrConstraints.td:813](/opt/llvm-project/mlir/include/mlir/IR/CommonAttrConstraints.td:813) |
| 6 / 71 | `SameVariadicOperandSize`、`AttrSizedOperandSegments` 都归入内部生成特质 | 分别说明前者为 `GenInternalOpTrait`，后者为 `NativeOpTrait` + `StructuralOpTrait` | [OpBase.td:157](/opt/llvm-project/mlir/include/mlir/IR/OpBase.td:157)、[OpBase.td:171](/opt/llvm-project/mlir/include/mlir/IR/OpBase.td:171) |
| 6～7 / 71～72 | 特质必须实现 `verifyTrait`/`foldTrait`；操作必须提供 `verifyTraitImpl()` | 改为可选钩子，框架通过检测调用；`verifyTraitImpl()` 只是开发者可自定的 CRTP 模式，不是 MLIR 规定的操作方法 | [OpDefinition.h:1530](/opt/llvm-project/mlir/include/mlir/IR/OpDefinition.h:1530)、[OpDefinition.h:1602](/opt/llvm-project/mlir/include/mlir/IR/OpDefinition.h:1602) |
| 7 / 72，清单 4-6 | 用 `NativeOpTrait` 传参数字符串，且引用未定义的 `parameters` | **TD 无法成立。** 改成 `ParamNativeOpTrait<"MyParametricTrait", !cast<string>(prop)>`；已实际生成 `MyParametricTrait<10>::Impl` | [OpBase.td:36](/opt/llvm-project/mlir/include/mlir/IR/OpBase.td:36)、[OpBase.td:44](/opt/llvm-project/mlir/include/mlir/IR/OpBase.td:44) |
| 7～8 / 72～73，清单 4-7～4-9 | 原生标记特质仅写 TD 就够；将同一 `OpTrait::TraitBase` 特质直接用于属性、类型 | 说明原生特质仍需 C++ 定义；标记类可为空。属性、类型示意分别使用自己的特质名，保留原书省略存储参数的形式 | [Traits.td:37](/opt/llvm-project/mlir/include/mlir/IR/Traits.td:37)、[Attributes.h](/opt/llvm-project/mlir/include/mlir/IR/Attributes.h)、[Types.h](/opt/llvm-project/mlir/include/mlir/IR/Types.h) |
| 9 / 74 | SegmentSizes 是泛称 Array 字段，只保存 Variadic 长度 | 改为各 ODS 分组的长度；属性形式为 `DenseI32ArrayAttr`，Properties 模式可有对应生成存储 | [Operation.cpp:1239](/opt/llvm-project/mlir/lib/IR/Operation.cpp:1239)、[OpDefinition.h:1312](/opt/llvm-project/mlir/include/mlir/IR/OpDefinition.h:1312) |
| 6、9 / 71、74 | `IsolatedFromAbove` 意味着与文本“之前区域”隔离 | 改为嵌套区域不得隐式捕获外部 SSA 值，说明隔离边界及 Pass 锚点要求 | [Operation.cpp:1333](/opt/llvm-project/mlir/lib/IR/Operation.cpp:1333)、[Pass.cpp:472](/opt/llvm-project/mlir/lib/Pass/Pass.cpp:472) |
| 9 / 74 | Graph 恰好一个块；ConstantLike 仅表示定义常量 | 根据验证器写“至多一个块”；补充 ConstantLike 的无操作数、单结果和常量折叠契约 | [Verifier.cpp:193](/opt/llvm-project/mlir/lib/IR/Verifier.cpp:193)、[OpDefinition.h:1225](/opt/llvm-project/mlir/include/mlir/IR/OpDefinition.h:1225) |
| 9～10 / 74～75 | `NotSpeculatable` 表示实际产生未定义行为 | 改为不能保证安全推测执行；需要考虑未定义行为或不终止，不是断言原程序会触发它们 | [SideEffectInterfaces.h:251](/opt/llvm-project/mlir/include/mlir/Interfaces/SideEffectInterfaces.h:251) |
| 10 / 75 | `MemoryEffect` 继承内存效果接口；接口仅追踪修改内存 | 改为 `SideEffect<MemoryEffectsOpInterface, ...>`；效果包含分配、释放、读、写。区别 TD `MemoryEffectsOpInterface` 与 C++ `MemoryEffectOpInterface` 的名称 | [SideEffectInterfaces.td:26](/opt/llvm-project/mlir/include/mlir/Interfaces/SideEffectInterfaces.td:26)、[SideEffectInterfaces.td:37](/opt/llvm-project/mlir/include/mlir/Interfaces/SideEffectInterfaces.td:37) |
| 10 / 75 | `affine.func`；AutomaticAllocationScope 自身执行内存释放 | 使用实际 `func.func` 名称；说明 affine 符号作用域及自动分配的生存期契约，特质自身不执行分配/释放函数 | [FuncOps.td:227](/opt/llvm-project/mlir/include/mlir/Dialect/Func/IR/FuncOps.td:227)、[OpDefinition.h:1254](/opt/llvm-project/mlir/include/mlir/IR/OpDefinition.h:1254) |
| 10～11 / 75～76 | IsTerminator 限定区域最后一个块；NoTerminator 禁止终结符；SingleBlock 必须恰好一个块 | 分别改为当前基本块末尾、单块区域可省略终结操作、每个非空区域一个块 | [Operation.cpp:1160](/opt/llvm-project/mlir/lib/IR/Operation.cpp:1160)、[Verifier.cpp:101](/opt/llvm-project/mlir/lib/IR/Verifier.cpp:101)、[OpDefinition.h:869](/opt/llvm-project/mlir/include/mlir/IR/OpDefinition.h:869) |
| 11 / 76 | `ensureTerminator` 指定“包含 Terminator 属性”；TypesMatchWith 只检查原类型相同；HasParent 查找任意父操作 | 分别改为需要时补终结操作、对变换后类型比较、约束直接父操作的类型 | [OpDefinition.h:990](/opt/llvm-project/mlir/include/mlir/IR/OpDefinition.h:990)、[OpBase.td:560](/opt/llvm-project/mlir/include/mlir/IR/OpBase.td:560)、[OpDefinition.h:1286](/opt/llvm-project/mlir/include/mlir/IR/OpDefinition.h:1286) |
| 11 / 76 | SymbolTable 收录任意深层嵌套符号；Symbol 可插入自身符号表 | 说明直接嵌套符号与独立的嵌套作用域，以及自身符号由外层表管理 | [SymbolTable.h:24](/opt/llvm-project/mlir/include/mlir/IR/SymbolTable.h:24)、[SymbolInterfaces.td:23](/opt/llvm-project/mlir/include/mlir/IR/SymbolInterfaces.td:23) |
| 12～13 / 77～78，清单 4-10、4-11 | 内联签名缺 `wouldBeCloned`；注册展示为构造函数 | 补齐本地签名、继承构造函数声明，并使用实际 `AffineDialect::initialize()` 注册位置 | [InliningUtils.h:72](/opt/llvm-project/mlir/include/mlir/Transforms/InliningUtils.h:72)、[AffineOps.cpp:141](/opt/llvm-project/mlir/lib/Dialect/Affine/IR/AffineOps.cpp:141)、[AffineOps.cpp:217](/opt/llvm-project/mlir/lib/Dialect/Affine/IR/AffineOps.cpp:217) |
| 12～14 / 77～79 | 基类 `DialectInterfaceBase::Base`；OpInterface 同时用于三种实体 | 方言改为 `DialectInterface::Base`；区分 `OpInterface`、`AttributeInterface`、`TypeInterface`，共享 `detail::Interface` | [DialectInterface.h:48](/opt/llvm-project/mlir/include/mlir/IR/DialectInterface.h:48)、[OpDefinition.h:2042](/opt/llvm-project/mlir/include/mlir/IR/OpDefinition.h:2042)、[InterfaceSupport.h:71](/opt/llvm-project/mlir/include/mlir/Support/InterfaceSupport.h:71) |
| 15～16 / 80～81，图 4-1 | Concept 使用实心菱形表示强组合；将方言回退操作接口与方言接口本身混称 | Mermaid 保留层级但标明 `conceptImpl` 是非拥有指针；区分方言提供的操作接口回退模型与 `DialectInterface` | [InterfaceSupport.h:136](/opt/llvm-project/mlir/include/mlir/Support/InterfaceSupport.h:136)、[InterfaceSupport.h:183](/opt/llvm-project/mlir/include/mlir/Support/InterfaceSupport.h:183)、[OpDefinition.h:2059](/opt/llvm-project/mlir/include/mlir/IR/OpDefinition.h:2059) |
| 16 / 81 | “直接赋值会调用 explicit 构造函数”；dyn_cast 重新创建真实操作接口实现 | 改为显式构造轻量包装对象；保留模型对象，仅查得其指针。说明另有对具体操作的模板构造函数 | [InterfaceSupport.h:94](/opt/llvm-project/mlir/include/mlir/Support/InterfaceSupport.h:94) |
| 17 / 82，清单 4-16 | MLIR 对象一律不能有虚函数；虚表条目数必等于虚函数数，任何对象必只有一个 vptr | 标为传统虚函数类比，非生成代码；区别 MLIR 轻量包装方案与使用虚函数的方言接口。虚表说明限定常见 ABI 下的简化实现，不当作语言保证 | [DialectInterface.h:48](/opt/llvm-project/mlir/include/mlir/IR/DialectInterface.h:48)、[InliningUtils.h:59](/opt/llvm-project/mlir/include/mlir/Transforms/InliningUtils.h:59)；生成的接口实际使用函数指针 |
| 18～19 / 83～84，清单 4-17 | Model/FallbackModel 自动提供默认业务实现；FallbackModel 必须动态方言；ExternalModel 总有默认实现 | 改为模型转发机制；Fallback 不要求动态方言；ExternalModel 仅在接口定义有默认方法体时得到相应默认方法。补上特质前向声明 | [OpInterfacesGen.cpp:340](/opt/llvm-project/mlir/tools/mlir-tblgen/OpInterfacesGen.cpp:340)、[OpInterfacesGen.cpp:383](/opt/llvm-project/mlir/tools/mlir-tblgen/OpInterfacesGen.cpp:383)、[OpInterfacesGen.cpp:406](/opt/llvm-project/mlir/tools/mlir-tblgen/OpInterfacesGen.cpp:406)；本地实际生成并编译运行 |
| 20～21 / 85～86，清单 4-18 | 接口包装类被操作直接继承；混淆方法模板参数与记录字段 | 说明操作继承接口特质；区分 `methodName/name`、`methodBody/body`、`defaultImplementation/defaultBody`；展开记录中的 code/string 类型按实际输出修正 | [Interfaces.td:59](/opt/llvm-project/mlir/include/mlir/IR/Interfaces.td:59)、[Interfaces.td:103](/opt/llvm-project/mlir/include/mlir/IR/Interfaces.td:103) |
| 21 / 86 | defaultImplementation 只生成到特质 | 补充 ExternalModel 中也生成默认实现；methodBody 则用于 Model，不是禁止所有 C++ 同名成员的语法规则 | [OpInterfacesGen.cpp:406](/opt/llvm-project/mlir/tools/mlir-tblgen/OpInterfacesGen.cpp:406)、[OpInterfacesGen.cpp:457](/opt/llvm-project/mlir/tools/mlir-tblgen/OpInterfacesGen.cpp:457) |
| 21～22 / 86～87 | 每个 Operation 自身有 InterfaceMap；所有接口通过 attachInterface 注册；重复注册措辞不清 | 改为每种操作的上下文元数据持有映射，原生接口由特质列表构建，外部模型再通过 attachInterface 附加；重复接口 ID 保留首次实现并释放后注册模型 | [OperationSupport.h:160](/opt/llvm-project/mlir/include/mlir/IR/OperationSupport.h:160)、[OpDefinition.h:1864](/opt/llvm-project/mlir/include/mlir/IR/OpDefinition.h:1864)、[InterfaceSupport.cpp:21](/opt/llvm-project/mlir/lib/Support/InterfaceSupport.cpp:21)；C++ 运行实验验证 |
| 22 / 87 | declarePromisedInterface 好像是操作方法，且所有构建都会诊断 | 改为方言的模板 API；明确本地未兑现承诺的使用检查受 `#ifndef NDEBUG` 控制 | [Dialect.h:214](/opt/llvm-project/mlir/include/mlir/IR/Dialect.h:214)、[OpDefinition.h:2063](/opt/llvm-project/mlir/include/mlir/IR/OpDefinition.h:2063) |
| 22 / 87，清单 4-19 | 直接附加接口退化为普通特质；第三种传字符串且声称本例可体现默认覆盖差异 | **内容与 TD 语法错误。** 三种都注册真实模型；直接附加需自行提供方法声明，本例已补。第三种传 `["getComputationCost"]`，且本例无默认实现，与第二种生成相同声明 | [Interfaces.td:150](/opt/llvm-project/mlir/include/mlir/IR/Interfaces.td:150)、[OpDefinitionsGen.cpp:3216](/opt/llvm-project/mlir/tools/mlir-tblgen/OpDefinitionsGen.cpp:3216)；三种写法已实际生成比较 |
| 23 / 88 | OpAsm 方法将常量值显示为 true/false；ConstOp；getResultsTypes；foldCastInterfaceOp 是接口方法 | 改为 `ConstantOp` 的 SSA 结果建议名称 `%true`/`%false`；改正 `getResultTypes`；区分 cast 接口方法与实现辅助函数 | [ArithOps.cpp:155](/opt/llvm-project/mlir/lib/Dialect/Arith/IR/ArithOps.cpp:155)、[CallInterfaces.td:103](/opt/llvm-project/mlir/include/mlir/Interfaces/CallInterfaces.td:103)、[CastInterfaces.td:29](/opt/llvm-project/mlir/include/mlir/Interfaces/CastInterfaces.td:29) |
| 23～24 / 88～89 | RegionBranch 只是区域内部的分支；DPS 保证输入输出共用内存 | 改为父操作/区域间控制流；DPS 描述目标操作数与结果的绑定关系，实际原地复用仍需分析 | [ControlFlowInterfaces.td:118](/opt/llvm-project/mlir/include/mlir/Interfaces/ControlFlowInterfaces.td:118)、[DestinationStyleOpInterface.td:14](/opt/llvm-project/mlir/include/mlir/Interfaces/DestinationStyleOpInterface.td:14) |
| 24 / 89 | 整数范围溢出后为 Null | 改为保守范围；中间计算可返回空 optional，但最终接口范围是 `ConstantIntRanges`，必要时为完整范围 | [InferIntRangeInterface.td:27](/opt/llvm-project/mlir/include/mlir/Interfaces/InferIntRangeInterface.td:27)、[InferIntRangeCommon.cpp:181](/opt/llvm-project/mlir/lib/Interfaces/Utils/InferIntRangeCommon.cpp:181) |
| 24 / 89 | Mem2Reg 提升等于移动分配位置；SROA 为“线性替换”；Destructurable 是“安全析构”；array 是操作 | 改为内存槽到 SSA 值、聚合体标量替换、拆分子槽并重接访问；数组为 `LLVMArrayType` 类型 | [MemorySlotInterfaces.td:14](/opt/llvm-project/mlir/include/mlir/Interfaces/MemorySlotInterfaces.td:14)、[MemorySlotInterfaces.td:315](/opt/llvm-project/mlir/include/mlir/Interfaces/MemorySlotInterfaces.td:315)、[MemorySlotInterfaces.td:359](/opt/llvm-project/mlir/include/mlir/Interfaces/MemorySlotInterfaces.td:359)、[LLVMTypes.td:29](/opt/llvm-project/mlir/include/mlir/Dialect/LLVMIR/LLVMTypes.td:29) |
| 24 / 89 | SafeMemorySlotAccessOpInterface 无条件保证内存安全，主要方便调度 | 改为针对给定内存槽做类型与边界相关检查，并产生待进一步检查子槽，为拆分等优化提供依据 | [MemorySlotInterfaces.td:285](/opt/llvm-project/mlir/include/mlir/Interfaces/MemorySlotInterfaces.td:285) |

## 图像与文字覆盖

图 4-1 位于 PDF 第 15 页，图 4-2 位于第 19 页。两图均已实际查看原扫描内容，全部标签和继承层级可以明确辨认，已转写为 Mermaid，不需要保留扫描裁剪图片。图 4-1 的强组合符号已按源码改为非拥有模型指针关联，并在正文注明；图 4-2 保留 `Concept` → `Model`/`FallbackModel` → `ExternalModel` 的继承结构。没有因 OCR 不识别而丢弃的图。

本章没有无法辨认的正文、代码行、图中文字或脚注。原书目录范围之外的交叉引用（如第 10、12 章及另一本书附录）保持原引用，不虚构其未提供的内容。

## 实际代码验证

所有命令使用本地 LLVM 18.1.8；验证时使用临时目录 `/private/tmp/insider-ch4-check`，关键输入已保存至 [evidence/ch4](evidence/ch4/README.md)，附可重复执行的命令。未改动 LLVM 源码或构建目录。

1. **TableGen 生成操作 verifier、参数化特质和谓词特质：通过。** 补齐方言基础定义后运行 `mlir-tblgen -I /opt/llvm-project/mlir/include --gen-op-defs` 与 `--gen-op-decls`。清单 4-4 得到 3 个分别调用 `type.isF16()`、`type.isF32()`、`type.isF64()` 的局部检查；清单 4-6 得到 `::mlir::OpTrait::MyParametricTrait<10>::Impl`；`CheckNumOperands<2>` 作为 `PredOpTrait` 生成 `getNumOperands() == 2`。
2. **成本接口生成：通过。** 对清单 4-13 运行 `--gen-op-interface-decls`、`--gen-op-interface-defs`，另展开记录。清单 4-17 和 4-18 以这些输出为依据核对；保留注释及排版，补全必要的前向声明。
3. **三种接口使用方式：通过。** 对校订后的清单 4-19 运行 `--gen-op-decls`，三个操作均继承 `::mlir::ComputationCostInterface::Trait`，并各包含一个 `int64_t getComputationCost();` 声明。第一种来自手动添加的 `extraClassDeclaration`；第二、三种来自生成器，证明原书“第一种退化”和本例“第二、第三不同”的解释不成立。
4. **真实 C++ 编译、链接及运行：通过。** 使用本次生成的成本接口头文件与定义，构造一个直接实现方法并附加接口特质的操作，和一个仅通过 `ExternalModel` 附加接口的操作。链接本地 MLIR/LLVM 静态库后运行：直接模型返回 **37**；外部模型返回 **41**；重复附加返回 99 的模型后接口仍返回 **41**；自定义 verifier 计数在 `Operation::create` 后为 **0**，显式调用 `mlir::verify` 后为 **1**。程序退出码为 0，输出为：

   ```text
   PASS: direct Model=37, ExternalModel=41, duplicate ignored, explicit verify required
   ```

5. **mlir-opt 正负样例：通过。** 合法的 `i1` 常量函数被解析和验证，并打印 SSA 名称 `%true`；将 `arith.addf` 的两个操作数设置为 `f16`、`f32`，命令按预期失败，诊断为：

   ```text
   'arith.addf' op requires the same type for all operands and results
   ```

6. **覆盖检查：通过。** 来源页标记恰为 1～25；代码清单恰为 4-1～4-19；图号为 4-1、4-2；代码围栏成对闭合。未将原书带省略号的演示框架宣称为全部可独立编译的完整程序。

## 保留的限制

- 没有使用 LLVM 20 源码编译对比；涉及本地未预定义记录、API 差异的地方均按 18.1.8 明确标注。若需要严格判断某记录是否在 LLVM 20 中存在，须再用相应版本源码核验。
- “跨方言接口约 21 个”保留为原书说法，并注明统计口径和版本未明，不将其转换为本地接口总数。
- `Conv2D1`～`Conv2D3` 只是接口接入示例，没有卷积成本公式，未补写未经原书给出的算法。
