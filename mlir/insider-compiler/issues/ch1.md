# 第1章校订记录

对应[第1章正文](../insider-compiler-ch1.md)。本次使用用户更新的 `pdf/insider-compiler-ch1.pdf`，SHA256 为 `40e24cbf10d5f9303bdcfe8ca43dd7305105900c04a844e3dfd3baf1c7ff227c`，共14页。PDF2–14对应印刷书页3–15；PDF1章首页未印页码，按连续页序推定为书页2。它已替换原先与第2、3章合订文件重复的旧占位来源，不对旧错误文件编造第1章。

本章保留 **14个来源页标、8份代码清单、4幅图、12条脚注、1个注意框**，无表。实际目视PDF1、3、5–14，共12页，涵盖全部图页、全部代码页和数学/脚注异常；PDF2、4以OCR正文核对，不声称已目视。4图按扫描结构用Mermaid重绘，根代理浏览器渲染4/4通过。原始 Apple Vision OCR 未修改。

本地实现基准为 `/opt/llvm-project`，LLVM **18.1.8**、提交 `3b5b5c1ec4a3095ab096dd780e84d7ab81f3d7ff`。这是实际检验版本，并非笼统的“18.0”，也不是书中其他章节所称LLVM20。外部框架和项目的历史介绍按原书约2024–2025年资料归属，不将本地缺少torch-mlir误当成该项目不支持相应功能。

**当前阅读版**已把清单1-4～7统一改为零初始化矩阵乘归约、归约完成后加偏置。原版错误只作历史差异记录，不再以加注限制的方式留在主示例中。新版验证入口是 [reading-edition/ch1/README.md](evidence/reading-edition/ch1/README.md)；旧 `evidence/ch1/` 中的 bias-first 清单、降级输出和数值测试保留为历史批次，不能用于证明当前代码。

<a id="ch1-context"></a>
## 项目背景、历史表述与数学概念

独立复核的本地源码与外部官方资料见[context-review.md](evidence/ch1/context-review.md)。本次没有扩大为项目活跃度排名或穷尽性的历史调查。

| 原文位置或说法 | 校订及范围 |
| --- | --- |
| MLIR是“最新的一个顶级子项目”、历经近6年 | 保留2019开源与成书时间下的近6年背景，去掉无法长期成立的“最新”；不将作者写作时的现在当作当前日期。 |
| MLIR“为新硬件赋予特定功能”、例子必然“大幅提升效率” | 编译器表达、映射并利用已有硬件能力；具体性能仍需测量。保留mlir-aie与tpu-mlir实例，区分Sophgo处理器与Google TPU。 |
| TensorFlow 2.0把图转换成StableHLO再经XLA | TF2.0正式版2019-09-30默认eager，图/编译是可选路径；StableHLO是相关生态的互通操作集，不是所有TF2.0执行必经阶段。保留原StableHLO脚注，补版本与配置边界。 |
| Flang编译器“已采用MLIR来实现” | 新Flang使用FIR等MLIR表示，不等于全部编译器代码都以MLIR实现。依据本地 [Flang编译流程说明](/opt/llvm-project/flang/docs/Overview.md:24)。 |
| HPC=High Performance Compute；TPU=Tensor Processor Unit | 改为High-Performance Computing、Tensor Processing Unit。Chris Lattner、Swift、IREE、Firefly、LLVM等字形误识别恢复正确名称。 |
| Verona在2021年因MLIR不稳定而放弃 | 已有项目资料确认2020年采用/规划MLIR，但本次未直接核到精确停止时间和负责人原话。正文明确是原书叙述及待核，不能把可能的适配原因改写成已证因果。 |
| MLIR约70万行代码 | 无版本、是否含测试/生成代码等统计口径；保留为作者估计，不能当作本地或当前代码量。 |
| 加入mod/div后Presburger仍可计算，“目前尚无相关论文” | 常数正除数可经局部整数变量编码为线性约束；semi-affine符号乘除的范围不同。删除“无论文”这一不实断言。见 [IntegerRelation.h:441](/opt/llvm-project/mlir/include/mlir/Analysis/Presburger/IntegerRelation.h:441)、[实际实现](/opt/llvm-project/mlir/lib/Analysis/Presburger/IntegerRelation.cpp:1510)。 |
| 多面体脚注将循环索引统称“循环归约变量” | 改为归纳变量，区别归约累加值；只有满足相应边界、条件、访存限制的循环才适用相应多面体模型。 |
| 单纯形处理多面体空间约束 | 补明有理与整数可行性有区别，并非所有整数问题只需普通LP单纯形。 |
| 必须高度依赖TD，生成代码耦合“对推广极为不利” | 保留作者关于学习成本的评价，但不把TableGen当成唯一机制。MLIR还可手写C++或动态扩展；TD也用于减少样板代码和集中约束。 |
| 2024年起各大公司贡献减少，原因是绩效与产出压力 | 原文没有数据、公司范围、指标、时间窗口；本地单个快照也不能证明趋势。正文保留其担忧，明确未核实，不推断企业动机或将下游增多直接等同于上游减少。 |
| 1.5说本章“未探讨……可能产生的问题” | 与1.4五类不足直接矛盾，改为已概述问题、尚未深入实现原因。 |

原文重大数学片段保留：

> “需先理解在引入mod、div等操作后，Presburger空间为何仍能保证可计算性。这一部分知识目前尚无相关论文。”

正文采用有明确实现依据的限定：若 `c` 是正整数常量，`q=floor(a/c)` 等价于 `c*q<=a<=c*q+c-1`，余数为 `a-c*q`。这里乘数固定，因此仍为线性整数约束；任意变量乘法或变量除法不能据此一并纳入。完整证明边界与semi-affine实现限制见独立复核文档。

<a id="ch1-figures"></a>
## 图1-1～1-4与MLIR分层

图1-1逐条保留Java、C/C++/OpenCL/Objective-C/CUDA、Swift、Rust、Julia的分支，以及字节码、Clang AST、Swift AST/SIL、Rust AST/MIR、Julia AST/IR与LLVM IR节点。补明它是简化图，Java仅指采用LLVM后端的实现；Rust还存在HIR等中间步骤，不能把图当成每种语言的完整pipeline。

“LLVM IR单层”指该IR的抽象层次，并不意味着LLVM后端没有其他表示。本地 [Machine IR结构](/opt/llvm-project/llvm/include/llvm/CodeGen/MachineInstr.h)即反例。原文称LLVM IR缺少向量单元/矩阵单元指令过于绝对，LLVM已有 [vector类型与运算](/opt/llvm-project/llvm/docs/LangRef.rst)、目标intrinsic；问题是某些高层结构过早丢失后难以恢复。

目视图1-2确认原箭头为：

```text
TensorFlow计算图 -> XLA HLO -> LLVM IR / TPU IR / 其他
TensorFlow计算图 -> TensorRT
TensorFlow计算图 -> nGraph
TensorFlow计算图 -> Core ML
TensorFlow计算图 -> TensorFlow Lite -> NNAPI / 其他
```

特别是TPU IR来自XLA HLO分支，不能因OCR行序把它接在TensorRT后。正文保留全部节点及历史归属；Executor路径在随后的正文中，原图未单列，本次不凭空把它当成漏识别节点。

图1-3的“接入、公共、优化、目标输出”是本书教学分类，不是MLIR强制层级；同一类方言也可能互相转换。原图目标输出层写“LLVM IR”混淆MLIR方言与外部IR，改为LLVM方言；代码生成保留LLVM编译器主路径并注明其他后端。各领域关键信息进入接入层、硬件差异信息用于目标输出层的两项边注已保留。箭头表示可能的转换关系，并不声称原图未画出的每个箭头都是固定pass。

原文“语义变化幅度大就增添中层IR”应为抽象差距较大；降低抽象层次不许可任意改变可观察行为。图1-4保留linalg与affine两个“变换”自环，以及linalg到affine/scf/其他、再到LLVM方言、最后翻译LLVM IR的结构；实际可经过多步转换，不要求直接跨越所有中间方言。

<a id="ch1-bindings"></a>
## 清单1-1～3：参数、属性和函数操作

1. Python清单恢复 `__init__`、缩进、`super(...).__init__()`、`mlir_module` 等，并补 `torch`、`nn`、`torch_mlir` 导入。保留原书 `torch_mlir.compile(..., output_type=OutputType.TOSA)` 接口，未把它改写成无来源的新版本接口。本次验证所用的Python环境无torch、torch-mlir，只通过Python AST/compile语法检查，未导入或执行。
2. `nn.Linear(16,10)` 权重形状为 `(10,16)`，偏置参数为 `(10,)`，而不是原文的 `(1,10)`；后者是本例广播后的形状。依据 [PyTorch Linear官方文档](https://docs.pytorch.org/docs/2.14/generated/torch.nn.Linear.html)。构造层只会初始化参数，并不证明已经训练；原书未给完整权重。
3. Python逐行解释执行是过度简化；CPython通常执行字节码，PyTorch也可调用本地已编译kernel。正文保留采用编译优化的动机，不将eager运行描述成全部Python标量代码。
4. `forward` 是符号名，`func.func` 是操作名。函数形参是入口块参数，函数返回类型位于FunctionType，`func.return`操作负责返回。原书“参数和返回值一般统称操作数”错误；本地 [FuncOps.td:226–274](/opt/llvm-project/mlir/include/mlir/Dialect/Func/IR/FuncOps.td:226) 的函数操作定义只有属性参数和区域，不把函数形参建成FuncOp的SSA operands。
5. `%0`等是SSA值名，不是可反复赋值的普通变量。`dense` 对应常量元素属性，不是运行时tensor类型。属性值是元素内容，属性携带的tensor类型也不同于“值等于tensor类型”的说法。依据 [BuiltinAttributes.td:222](/opt/llvm-project/mlir/include/mlir/IR/BuiltinAttributes.td:222) 与 [DenseElementsAttr](/opt/llvm-project/mlir/include/mlir/IR/BuiltinAttributes.h:82)。该属性的内部存储形式不能直接规定运行时张量内存布局。
6. `tosa.reshape` 改变形状并保留元素数/元素类型，不是任意类型转换。原书 `new_shape=[...]` 属于旧属性写法；本地 [TosaOps.td:1559–1574](/opt/llvm-project/mlir/include/mlir/Dialect/Tosa/IR/TosaOps.td:1559) 要求DenseI64ArrayAttr，正文使用 `array<i64: ...>`，补全参数后解析验证通过。此处归类为对LLVM18的API适配，不据本地直接断言所有LLVM20文本相同。

<a id="ch1-constants"></a>
## 六份IR中的截断常量不能伪造恢复

清单1-2～7的权重、偏置在原扫描中就是 `dense<"0xC44B...">`、`dense<"0xA270...">`，并非OCR遗漏数百个字节。正文保留原标记并在第一次出现前声明不可直接解析运行；没有用全零或任意权重冒充训练参数。

为实际核验结构和降级，初次校订在[validation-data.json](evidence/ch1/validation-data.json)明确定义一组独立参数：转置后的权重 `W[k][j]=((3*k+5*j)%17-8)/8`，偏置 `b[j]=j/4-1`。当前验证沿用这些数据的[逐字副本](evidence/reading-edition/ch1/validation-data.json)，从正式 Markdown 提取新版清单1-4～7，再仅替换两种截断常量，生成新目录内的 `complete-1-4.mlir`～`complete-1-7.mlir`。旧目录同名文件对应旧版结构，不覆盖、不混用；清单1-2/3此次没有改动。

<a id="ch1-numerics"></a>
## 清单1-4～7：归约初值与浮点求值顺序

原书无条件称清单1-4/5与Python和tosa例子“功能一致”，但它把bias放在 `linalg.generic outs` 中作为归约初值。清单1-6/7同样在循环前把bias复制到输出，再逐项累加乘积。

这在实数代数中对应同一公式，但不能保证IEEE binary32逐位等价。对输入全1、每列权重前两项为 `2^24,-2^24`、其余0、bias为1的指定顺序归约，先从0求和再加bias得到1；从bias开始累加得到0。反例脚本和结果见[bias-order.py](evidence/ch1/bias-order.py)、[bias-order.json](evidence/ch1/bias-order.json)。它说明不能无条件交换求值次序，并不声称所有PyTorch/TOSA实现都固定采用一种归约顺序。

本地 [TosaToLinalgNamed.cpp:548–592](/opt/llvm-project/mlir/lib/Conversion/TosaToLinalg/TosaToLinalgNamed.cpp:548) 的MatMulConverter明确创建零常量、`linalg.fill`、以零初始化结果的 `linalg.batch_matmul`。初次校订时实际运行得到的 [tosa-to-linalg-explicit.mlir](evidence/ch1/tosa-to-linalg-explicit.mlir)保留这一结构，后续加bias是独立generic。

初版 Markdown 虽指出这个差异，仍写“本次保留这个教学实现”，把错误的 bias-first 结构留在逐步降级主线上。现已直接修正清单1-4/5：第一个 generic 从零张量归约，第二个只有 parallel 迭代的 generic 把偏置加到完成的矩阵乘积上；清单1-6/7在每列的内层归约循环前写零、内层结束后只加一次偏置。注释版和前后说明已同步。二维 generic 和输出参数 ABI 仍是便于教学的表示，不声称本地 TOSA Pass 会逐字生成它们。

原1.3.3～1.3.4完整片段、四份旧清单及“保留这个教学实现”等原说明已存入[历史差异原文](evidence/reading-edition/ch1/before-bias-first.md.txt)。因此可追溯修正前的内容，但当前正文只讲解校正后的顺序。

其他注释修复：

- linalg是“线性代数”，不是“线性算法”；`affine_map`把迭代坐标映射到访问下标，不仅仅定义“定义域和值域”。其取值范围还依赖形状等信息。
- 原 `outs(%cst)` 提供偏置初值，并不表示就地改写只读常量。当前第一个 generic 使用 `outs(%zero)`，第二个使用已完成的乘积 `%0` 作为目标初值；两者在张量语义下均返回新的结果值。
- 基本块参数仍然是SSA表示的一种形式，不是原注释所说“和一般SSA不同”就不属于SSA。
- `linalg.yield`将单次区域计算结果交回父操作，不是任意“返回上层控制流”的函数返回。
- 原书建议“一个基本块乘法、另一个基本块加法”容易误导为任意扩展generic区域；改为两个结构化操作。generic的区域结构与验证见 [LinalgStructuredOps.td](/opt/llvm-project/mlir/include/mlir/Dialect/Linalg/IR/LinalgStructuredOps.td) 及 [LinalgInterfaces.cpp](/opt/llvm-project/mlir/lib/Dialect/Linalg/IR/LinalgInterfaces.cpp)。
- tensor→memref需要缓冲化，输出参数形式还涉及函数边界转换；原文省略了这一前提。新版实际bufferize+affine输出保存在 [linalg-to-affine.mlir](evidence/reading-edition/ch1/linalg-to-affine.mlir)，其缓冲区分配、返回值等细节不与手工简化后的清单1-6逐字相同。正文还明确输入与输出缓冲区互不重叠的使用前提，避免输出写入破坏仍待读取的输入。
- affine循环是下界包含、上界不含、默认step1，不是遍历到10/16也包含端点；它比张量操作低层，但仍不是汇编。

<a id="ch1-llvm"></a>
## 清单1-8：指针版本与省略上下文

原清单的关键旧写法为：

```text
%46 = llvm.intr.masked.load %45, %36, %0 {alignment = 4 : i32}
  : (!llvm.ptr<vector<2xf32>>, vector<2xi1>, vector<2xf32>) -> vector<2xf32>
%47 = llvm.fmul %30, %41 : vector<2xf32>
%48 = llvm.fadd %46, %47 : vector<2xf32>
llvm.intr.masked.store %48, %45, %36 {alignment = 4 : i32}
  : vector<2xf32>, vector<2xi1> into !llvm.ptr<vector<2xf32>>
```

旧typed pointer在本地LLVM18改为不透明 `!llvm.ptr`，被加载/存储的类型由操作的其他类型信息表达。依据 [LLVMIntrinsicOps.td:752–798](/opt/llvm-project/mlir/include/mlir/Dialect/LLVMIR/LLVMIntrinsicOps.td:752) 和本次parser/export验证。

原书确实用省略号删除了入口和中间计算，不是OCR全部漏读。正文恢复正确分行：第一条cond_br的false目标为 `^bb5`；接下来是独立的 `^bb2` 定义；内层cond_br的false目标目视为 `^bb4`，原OCR误成 `^bb9`；`llvm.add`与`llvm.br`拆回两行。保留全部原低层操作与控制流，但不伪造未给出的地址、mask和vector计算。

[snippet-fixture.mlir](evidence/ch1/snippet-fixture.mlir)只为该节选补齐参数、常量和入口块，确认masked操作、分支及导出接口在LLVM18合法；它没有重建原线性层的向量化算法，也未作为正确向量化kernel运行。原书未给相关pass命令，不能仅从出现vector就宣称affine自动生成向量代码。

旧 [affine-to-llvm.mlir](evidence/ch1/affine-to-llvm.mlir)、[affine.ll](evidence/ch1/affine.ll)及[run-forward.c](evidence/ch1/run-forward.c)验证的是修正前的 bias-first 标量实现：旧40组输入、400个输出与同一求值顺序的参考逐位一致。这条历史结论不适用于当前清单，也不能证明其与 TOSA 计算阶段一致。

当前清单1-6的完整参数版本已重新生成 [LLVM方言输出](evidence/reading-edition/ch1/affine-to-llvm.mlir)和 [LLVM IR](evidence/reading-edition/ch1/affine.ll)，并执行新的零初值、偏置后加参考对照。清单1-8仍是原书缺少上下文的向量循环节选，并未列出新版加偏置步骤；正文明确它不能作为新版完整函数的等价输出，没有凭空补造原书的向量化过程。

LLVM方言与LLVM IR语法不同，需要翻译接口，不是删除 `llvm.` 前缀。原书脚注链接已确认可读，为2022年的《从PyTorch到RTL》65页报告；只据其核到标题、日期和出处，不把其旧接口当LLVM18/20验证依据。

<a id="ch1-validation"></a>
## 实际验证、默认TOSA管线失败与复现记录

当前验证见[阅读版验证说明](evidence/reading-edition/ch1/README.md)、[脚本](evidence/reading-edition/ch1/verify.py)和[执行记录](evidence/reading-edition/ch1/verification-results.json)。13条命令全部退出0：新版1-4～7的完整化 IR 通过 verifier，1-4真实缓冲化及affine降级，1-6真实降为LLVM方言，两份输出再次解析，导出LLVM IR、llvm-as检查，最后由系统Clang编译并执行。脚本还确认1-4/5、1-6/7去掉注释后的代码一致，14页、8清单、4图、12脚注结构保留。

数值对照保留旧参数与前40组输入，并另加40组放大输入以区分舍入顺序。**80组输入、800个输出**与独立的“零初值归约完成后再加偏置”f32参考逐位一致；其中**39个输出**与旧bias-first参考不同，确保测试能检出本次改正的错误。没有启用浮点收缩或重关联，也不把这些有限样例声称为所有输入的等价证明。

初次校订的[历史验证说明](evidence/ch1/README.md)、[历史执行记录](evidence/ch1/verification-results.json)仍保留。其22条命令包含未修改清单1-2/3的TOSA验证、原1-4～7的bias-first结构和清单1-8的独立夹具；与新版有关的结果以上述新记录为准。旧数据、输入、输出、脚本等34项产物的SHA256仍与[校订前快照](evidence/reading-edition/ch1/old-evidence-sha256.json)一致，旧README只允许增加指向当前批次的说明。

其中一次**预期失败**是直接使用 `--tosa-to-linalg-pipeline`：本地 [TosaToLinalgPass.cpp:105–118](/opt/llvm-project/mlir/lib/Conversion/TosaToLinalg/TosaToLinalgPass.cpp:105)为该快捷pipeline硬编码BaseInference，随后 [TosaValidation.cpp:510–512](/opt/llvm-project/mlir/lib/Dialect/Tosa/Transforms/TosaValidation.cpp:510)遇到浮点operand直接signalPassFailure，未打印诊断。本例f32因此退出1。单独 `--tosa-validate='profile=mi'` 成功，随后显式选择浮点示例所需的lowering passes也成功。这是本地快捷pipeline的profile配置限制，不是“所有TOSA不支持f32”，也不是悄悄忽略验证或编造失败理由。

未执行的范围：torch/torch-mlir导入与Python模型编译、原书缺失参数的数值复现、未给出的向量化pipeline、任何GPU/TPU/NPU端到端执行或性能对比。没有为本章重建LLVM或安装大型外部框架。
