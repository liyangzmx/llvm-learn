# 第9章校订记录

校订对象：[第9章《优化方言》](../insider-compiler-ch9.md)，扫描源 `pdf/insider-compiler-ch7-ch10.pdf` 的 PDF 第 27–80 页，印刷页 154–207。原书参考 LLVM 20，本次以本地 **LLVM 18.1.8**、提交 `3b5b5c1ec4a3095ab096dd780e84d7ab81f3d7ff` 为实现基准。本地没有的后续版本名称保留并标明差异，不直接判定为 OCR 错误；未对 LLVM 20 的全部版本历史作独立验证。

本章由两位章节校对代理分段处理：前段 PDF 27–69 共 43 页，尾段 PDF 70–80 共 11 页，均逐页调用 `view_image` 查看原扫描图。图中所有节点、数据、箭头及正文代码均按扫描复核，Apple Vision 原始 OCR 保持不变。保留清单 9-1 至 9-40、图 9-1 至 9-9、两张表及全部脚注。图用 Mermaid 重绘；公式和代码恢复为可读的数学及文本形式。

## 覆盖与校订方式

| PDF 页 | 印刷页 | 保留内容 |
| --- | --- | --- |
| 27–28 | 154–155 | 章题、linalg 由来、目标定位、表 9-1 七行 |
| 29–34 | 156–161 | 结构化原则、图 9-1/9-2、库调用与三类循环降级、向量降级，清单 9-1 至 9-8 |
| 35–38 | 162–165 | 操作分类、generic 属性、矩阵和批量矩阵乘法，清单 9-9 至 9-13，图 9-3 |
| 39–42 | 166–169 | 卷积、数据布局、池化、清单 9-14 至 9-16，图 9-4/9-5 |
| 43–46 | 170–173 | 四种逐元素加法、两类融合及前后代码，清单 9-17 至 9-21 |
| 47–52 | 174–179 | 卷积向量化、分块和其他优化，清单 9-22 至 9-26 |
| 53–56 | 180–183 | 存储优化、affine 建模、表达式语法，清单 9-27 至 9-30 |
| 57–61 | 184–188 | affine 操作/Pass/上下游、循环降级、调度树比较、vector 引入；清单 9-31/9-32，图 9-6 |
| 62–63 | 189–190 | vector 架构及类型表示，图 9-7、表 9-2 全部两行 |
| 64–67 | 191–194 | vector 九类操作、完整上下游图 9-8、优化/变换开头 |
| 68–70 | 195–197 | vector 28 个变换条目、清单 9-33/9-34、bufferization 开头 |
| 71–75 | 198–202 | bufferization 操作、接口、One-Shot、释放流程图 9-9，清单 9-35/9-36 |
| 76–79 | 203–206 | 分块与向量化应用，清单 9-37 至 9-40 |
| 79–80 | 206–207 | 清单 9-40 续文及四种方言的本章小结 |

OCR 中 `linalg`/`1inalg`、`llvm`/`1lvm`、`affine` 的拼写、SSA `%`、下标、比较号、括号、乘法号、长操作名换行、代码缩进等已统一恢复。正文页标记保留源定位，但不作为代码本身。清单使用本地真实输出时，SSA 名称变化和保留的 Transform 模块属于打印或版本差异。

<a id="ch9-background"></a>

## linalg 背景与数学描述（PDF 27–29）

- 原文以“一阶导数为常数”定义线性映射。该条件也允许非零常数偏移，正文改用可加性和齐次性，并区别 `ax` 与 `ax+b`。linalg 中卷积、矩阵乘法、非线性逐元素运算的分类也不意味着它们对全部输入联合构成线性映射。
- 表 9-1 完整保留七个项目的比较维度，但将历史设计评价与当代项目能力分开。原文对 Halide“标量”的限定不成立，不能把某种表示或算法的复杂度、性能和可配置性概括成整个项目的普遍结论。
- 结构化操作的目标是保留迭代空间、访问映射及计算语义，支持渐进变换；不能推导出所有 linalg 操作必然适合所有硬件或自动获得最优性能。

依据：[本地 Linalg 设计文档](/opt/llvm-project/mlir/docs/Dialects/Linalg/_index.md)、[结构化操作 ODS](/opt/llvm-project/mlir/include/mlir/Dialect/Linalg/IR/LinalgStructuredOps.td)。原书演示文稿的参考链接按本地同一文档中的地址核对，作为历史参考保留。

<a id="ch9-linalg-lowering"></a>

## std、库调用与转换入口（PDF 30–34）

原文称 std 不是方言而是算法库，正文改正：Standard 是历史方言名，其职责后来拆分。本地 `convert-linalg-to-std` 保留旧入口名，但生成的是 `func.call` 和外部函数声明，编译器并不会自动提供 BLAS 或用户库实现。清单 9-2 使用本地实际输出的库函数名称和签名。

源码：[LinalgToStandard.cpp](/opt/llvm-project/mlir/lib/Conversion/LinalgToStandard/LinalgToStandard.cpp:55)，其中转换创建 func::CallOp；[转换 Pass 定义](/opt/llvm-project/mlir/include/mlir/Conversion/Passes.td:659)。清单 9-1/9-2 已实际执行 [dot 输入](evidence/ch9-dot.mlir) → [库调用结果](evidence/ch9-dot-std.mlir)。

原书图中未画 arith、tensor 是其分类选择，并非否认相应变换；本地的 linalg 循环转换与后续向量改写均按具体入口说明。`test-linalg-to-vector-patterns` 是测试 Pass 的选项，完整形式是 `--test-linalg-transform-patterns=test-linalg-to-vector-patterns`，不能当作独立生产 Pass。[测试入口定义](/opt/llvm-project/mlir/test/lib/Dialect/Linalg/TestLinalgTransforms.cpp:69)。

<a id="ch9-matmul-storage"></a>

## matmul 的输出初值和缓冲区别名（PDF 31–33）

原书清单 9-3 的三个视图都从同一缓冲区同一位置开始，核心写法如下（省略不相关的常量定义）：

```mlir
%A = memref.view %arg0[%c0][%M, %K]
  : memref<?xi8> to memref<?x?xf32>
%B = memref.view %arg0[%c0][%K, %N]
  : memref<?xi8> to memref<?x?xf32>
%C = memref.view %arg0[%c0][%M, %N]
  : memref<?xi8> to memref<?x?xf32>
```

这不是三个独立矩阵的存储。写入 C 会与输入 A/B 重叠；单纯通过解析器并不代表运行时算法正确。正文使用三个独立字节缓冲区，仍保留 memref.view 示例，要求调用者保证容量、对齐、范围以及互不重叠。

matmul/dot 都把乘积累加到输出初值，纯乘法需将 C 置零。tensor 形式的 outs 同样不能一概视为“只提供形状”；是否读取原值由操作区域决定。原书后续卷积、池化也有相同的初值前提。

依据：[matmul 定义](/opt/llvm-project/mlir/python/mlir/dialects/linalg/opdsl/ops/core_named_ops.py:243)、[dot 定义](/opt/llvm-project/mlir/python/mlir/dialects/linalg/opdsl/ops/core_named_ops.py:539)、[memref.view](/opt/llvm-project/mlir/include/mlir/Dialect/MemRef/IR/MemRefOps.td)。修订输入 [ch9-matmul.mlir](evidence/ch9-matmul.mlir) 已分别转为 [affine](evidence/ch9-matmul-affine.mlir)、[scf.for](evidence/ch9-matmul-scf.mlir)、[scf.parallel](evidence/ch9-matmul-parallel.mlir)。这验证 IR 转换，没有执行数值计算。

<a id="ch9-structured-ops"></a>

## generic、迭代器与非结构化辅助操作（PDF 35–36）

原文将 iterator_types 解释为“每个输入输出操作数的类型”，正文改为每个循环维度一个类型。索引映射则为各输入和输出关联迭代维度。本地 `IteratorType` 实际只有 parallel、reduction；尽管 GenericOp 的历史说明仍提到 window，不能据过时文字增加实际不存在的枚举。

原书列 index、yield 两种辅助操作，正文保留但不将其说成整个方言中全部非 LinalgOp 操作的穷举，例如 LinalgOps.td 还定义 softmax。

依据：[实际 IteratorType 枚举](/opt/llvm-project/mlir/include/mlir/Dialect/Utils/StructuredOpsUtils.td:15)、[GenericOp](/opt/llvm-project/mlir/include/mlir/Dialect/Linalg/IR/LinalgStructuredOps.td:53)、[LinalgOps.td](/opt/llvm-project/mlir/include/mlir/Dialect/Linalg/IR/LinalgOps.td)。

<a id="ch9-matmul-maps"></a>

## 可配置命名 matmul 的版本差异及广播尺寸（PDF 36–38）

清单 9-12 的原书片段完整保留于 [原语法测试输入](evidence/ch9-matmul-custom-maps-original.mlir)，仅为测试补了函数参数与 return。本地解析在 `linalg.matmul indexing_maps = ...` 处失败，诊断为 `ods-gen generated region expects 3 args, got 0`，见[原始诊断](evidence/ch9-matmul-custom-maps-original-out.log)。本地命名 matmul 的映射由 DSL 定义固定；正文改为 `linalg.matmul_transpose_a`，以相同输入/输出形状表达原意。[修订输入](evidence/ch9-matmul-transpose.mlir) 与[通过验证的输出](evidence/ch9-matmul-transpose-checked.mlir)。

清单 9-13 原书核心片段如下，保留其原有错误尺寸：

```mlir
linalg.matmul indexing_maps = [
  affine_map<(d0, d1, d2) -> (d2)>,
  affine_map<(d0, d1, d2) -> (d2, d1)>,
  affine_map<(d0, d1, d2) -> (d0, d1)>]
  ins(%arg0, %arg1 : memref<3xf32>, memref<5x7xf32>)
  outs(%arg2 : memref<3x7xf32>)
```

这里除了上述语法版本差异，还有真正的尺寸错误：d2 的归约范围由右矩阵确定为 5，左向量不能只有 3 个元素。正文改成 memref<5xf32>，并用 linalg.generic 保留相同访问映射，见[修订输入](evidence/ch9-matmul-broadcast.mlir)和[验证输出](evidence/ch9-matmul-broadcast-checked.mlir)。索引映射转置/广播表达逻辑访问，不必先物理搬运整块数据。

依据：[命名操作解析器](/opt/llvm-project/mlir/lib/Dialect/Linalg/IR/LinalgOps.cpp:297)、[matmul/转置/batch 族定义](/opt/llvm-project/mlir/python/mlir/dialects/linalg/opdsl/ops/core_named_ops.py:243)。正文还限定 batch_matmul 的性能评价，修正 batch_mmt4d 为分块布局及 batch_reduce_matmul 的归约含义。

<a id="ch9-pooling"></a>

## 卷积、布局与池化（PDF 38–42）

- 恢复扫描中丢失的连续/离散卷积公式。机器学习命名卷积通常计算不翻转核的互相关，与数学卷积定义区分；图 9-4 的全部输入、核及输出数据按扫描恢复。
- NCHW/NHWC 取舍按具体硬件与访问模式说明，不宣称其中一种对所有目标更快。通道按 4 打包时，非整除情形需要向上取整及填充，不能只写 C/4。
- 原文称 linalg 池化越界会自动补零，这是内容错误。图 9-5 的右侧和底部补零必须在调用前显式进行；若不补齐，不能产生全部四个图示窗口。对于负输入的最大池化，零也不是普遍正确的填充值，常应使用负无穷。
- 池化 outs 是累加初值。窗口参数作为形状描述，不是被相乘的权重值。清单 9-16 中每个输出对应两个采样点，“四个不同输出位置”不等于只执行四次 load/store。

依据：[卷积与池化 DSL](/opt/llvm-project/mlir/python/mlir/dialects/linalg/opdsl/ops/core_named_ops.py:550)，pooling_nwc_max 位于约 1427 行；[Linalg loops 生成](/opt/llvm-project/mlir/lib/Dialect/Linalg/Transforms/Loops.cpp)。[池化输入](evidence/ch9-pooling.mlir) 已经 generalize、One-Shot bufferize、转循环，见[实际结果](evidence/ch9-pooling-loops.mlir)。输出的访问公式为 `d0 * 4 + d1 * 2`，直接验证步长 4、膨胀 2 的下标解释。

<a id="ch9-operation-catalog"></a>

## linalg 目录与四种加法写法（PDF 42–43）

原书所有名称均在正文保留，但以下同名独立操作在本地不存在：erf、reciprocal、round、rsqrt、sqrt、square、tanh、contract、powf、select，以及原书列出的 winograd 变换族。exp 是指数函数，不是一般幂运算。pack/unpack 在本地属于 tensor 方言；elementwise 的本地对应入口为 elemwise_unary/elemwise_binary。reduce 及量化计算的实际操作数数量也不能按“一元/二元”分类直接推断。

清单 9-17 原书第三种写法为：

```mlir
%add = linalg.elementwise kind=#linalg.elementwise_kind<add>
  ins(%A : tensor<?x?xf32>, %B : tensor<?x?xf32>)
  outs(%C : tensor<?x?xf32>) -> tensor<?x?xf32>
```

正文替换为本地 `linalg.elemwise_binary {fun = #linalg.binary_fn<add>}`。原书四段代码还存在缺少 generic 索引映射/迭代器/结果类型、相同 SSA 名重复定义、目标动态/静态类型不一致、map 改用不相关一维操作数等问题。正文统一为同一个函数的四种实现及四个独立结果，补齐必要属性，并保持二阶张量类型一致。[完整修订输入](evidence/ch9-add-forms.mlir)和[解析验证结果](evidence/ch9-add-forms-checked.mlir)。

依据：[命名操作 DSL](/opt/llvm-project/mlir/python/mlir/dialects/linalg/opdsl/ops/core_named_ops.py:112)、[Linalg 函数枚举](/opt/llvm-project/mlir/include/mlir/Dialect/Linalg/IR/LinalgEnums.td:19)、[generic/map/reduce 定义](/opt/llvm-project/mlir/include/mlir/Dialect/Linalg/IR/LinalgStructuredOps.td)、[tensor.pack/unpack](/opt/llvm-project/mlir/include/mlir/Dialect/Tensor/IR/TensorOps.td)。

<a id="ch9-fusion"></a>

## 融合、向量化、分块与成本（PDF 43–53）

逐元素融合的六个步骤按本地实现校订，区分操作数列表、索引映射与 IR 值映射。原书有关该 Pass 将被废弃的文字是展望，本地仍注册并可执行 `linalg-fuse-elementwise-ops`。[定义](/opt/llvm-project/mlir/include/mlir/Dialect/Linalg/Passes.td:40)、[ElementwiseOpFusion.cpp](/opt/llvm-project/mlir/lib/Dialect/Linalg/Transforms/ElementwiseOpFusion.cpp:296)。

清单 9-20/9-21 来自动态形状的上游结构变换测试。该测试省略了通用尾块处理，不能据此视为任意形状都可运行。原例 tile 大小为行 2、列 3、归约 4；按其两次使用同一 B 的方式，需要 A=M×K、B=K×K、C=M×K，并在未补尾块逻辑时要求 M 整除 2、K 整除 12。计算为 `C + (AB + C)B`。融合后可能针对不同消费者块重算生产者，不保证总指令或运行时间必然下降。

证据：[输入](evidence/ch9-greedy-fusion.mlir)、[实际融合输出](evidence/ch9-greedy-fusion-out.mlir)、[测试驱动](/opt/llvm-project/mlir/test/lib/Dialect/Linalg/TestLinalgFusionTransforms.cpp)、[上游输入](/opt/llvm-project/mlir/test/Dialect/Linalg/tile-and-fuse-tensors.mlir:3)。逐元素例也已运行，见[输入](evidence/ch9-elementwise-fusion.mlir)与[输出](evidence/ch9-elementwise-fusion-out.mlir)。

清单 9-22 至 9-24 的一维卷积保留输入 11、核 4、输出 8。向量化后取输入偏移 0、1、2、3 的四个 8 元素切片，与四个核标量逐一 outerproduct 累加。原文把 IR 动态操作计数直接称作机器指令数，并从“192 条”推导固定“16 条”的性能结论，缺少目标后端依据。正文保留运算分解和次数分析，但注明实际机器指令、寄存器和性能还需后端测量；输出初值也不能未经条件直接替换为零。[循环输出](evidence/ch9-conv1d-tensor-loops.mlir)、[向量输出](evidence/ch9-conv1d-tensor-vector.mlir)。

清单 9-25 的原书语法 `mapping = [#gpu.block<y>, #gpu.block<x>]` 在本地测试 transform 操作中不能解析，正确为 `mapping [...]`；计算 IR 中 scf.forall 的属性字典仍然使用等号。原始输入及诊断保留为 [ch9-tile-forall-original.mlir](evidence/ch9-tile-forall-original.mlir)、[原始诊断](evidence/ch9-tile-forall-original.log)。[修订输入](evidence/ch9-tile-forall.mlir) 已由 `--transform-interpreter` 执行，见[完整输出](evidence/ch9-tile-forall-out.mlir)。正文保留本地输出中未删除的 Transform 模块，并注明 affine.min 处理尾块，所以块不总是 10×20。

依据：[TestTileUsingForall 语法](/opt/llvm-project/mlir/test/lib/Interfaces/TilingInterface/TestTilingInterfaceTransformOps.td:50)、[生产版 tile_using_forall](/opt/llvm-project/mlir/include/mlir/Dialect/Linalg/TransformOps/LinalgTransformOps.td:1906)。TilingInterface 是变换所查询的接口，不是执行变换后才创建的接口；GPU 映射属性也不等于已经生成 GPU 执行代码。

原书“50 多个优化 Pass”混合了 Pass、模式、辅助 API 和 Transform 操作。Hoisting、InlineScalarOperands、EraseUnusedOperandsAndResults 可在源码找到，但不是因此就有同名独立 Pass；本地不存在独立注册的 BlockPackMatmul。正文保留这组优化策略，并修正无条件提升 load/store、padding 任意动态维度等过度表述。相关文件：[Hoisting.cpp](/opt/llvm-project/mlir/lib/Dialect/Linalg/Transforms/Hoisting.cpp)、[InlineScalarOperands.cpp](/opt/llvm-project/mlir/lib/Dialect/Linalg/Transforms/InlineScalarOperands.cpp)、[EraseUnusedOperandsAndResults.cpp](/opt/llvm-project/mlir/lib/Dialect/Linalg/Transforms/EraseUnusedOperandsAndResults.cpp)。

<a id="ch9-affine-model"></a>

## affine 依赖建模（PDF 53–54）

原文反复把 i、j 称为归约变量，把 `temp` 称为数组，并将目标写为“是否存在 i、j 使得 S3、S4、S5 对数组 temp 不存在访问依赖”。这不能证明可并行化：`temp` 是迭代内标量，必须检查不同迭代之间的潜在冲突访问。正文引入 `(i,j)` 与 `(i',j')`，保留原上下界及偶数约束，补访问同址、至少一次写入、顺序及数组别名条件。

“存在一个无依赖访问对”不等于“所有迭代之间没有依赖”。依赖判断通常是整数约束的可行性问题，不必设置优化目标。两个变量相乘是非线性项，不能简单把整个问题称为标准二次规划；常量整除/余数可通过辅助整数约束表达，但不是普通线性组合。

代码清单 9-27 原书 `X[i,j]` 是说明性伪代码风格，正文使用 C 的 `X[i][j]`，并注明省略参数与有效范围前提。局部 `temp` 保留在内层迭代作用域。

依据：[简化多面体模型原始示例与取舍](/opt/llvm-project/mlir/docs/Rationale/RationaleSimplifiedPolyhedralForm.md:55)、[Affine 维度、符号和表达式规则](/opt/llvm-project/mlir/docs/Dialects/Affine.md:65)。

<a id="ch9-affine-expr"></a>

## affine/半仿射语法与循环边界（PDF 54–56）

普通 affine 表达式已经允许符号参与加减，半仿射扩展的是符号乘法及符号作为除数等形式。原书示例 `(d0,d1)[s0] -> (d0,d1+s0,d1-s0-1,4*d0+d1)` 没有展示新增能力，正文保留并说明它本来就是普通符号仿射映射，另以 `d0*s0` 展示区别。

符号的合法性由 AffineScope、支配关系、常量/维度查询/affine.apply 等规则判断，不能只说“在循环外定义”。代码清单 9-28 保留原语法要素，同时改正属性别名定义必须包含 `affine_map<...>` 的写法；这部分本地文档中的旧伪语法也不能直接当作可解析文本。

affine.for 的下界 max、上界 min 组合映射结果，不是三元表达式。循环体使用花括号，步长为正整数常量，下界包含、上界不包含；清单明确为省略 iter_args 等可选部分的语法片段。

依据：[Affine.md](/opt/llvm-project/mlir/docs/Dialects/Affine.md:83)、[AffineForOp](/opt/llvm-project/mlir/include/mlir/Dialect/Affine/IR/AffineOps.td:116)。[仿射映射输入](evidence/ch9-affine-maps.mlir) 已解析并执行 lower-affine；[输出](evidence/ch9-affine-maps-out.mlir) 同时展示 affine.min 转为 arith 比较和选择。

<a id="ch9-affine-ops"></a>

## affine 操作、Pass 与降级（PDF 56–60）

原书列出 16 个操作和 15 个 Pass；本地缺少 `affine.linearize_index` 和 `affine-expand-index-ops-as-affine`。正文保留原用途并标明不能本地直接使用。`affine-expand-index-ops` 的本地实现仅注册 delinearize_index 的展开模式。

原文称 scf 的比较操作可降级 affine.min/max；本地使用 arith 比较与选择，scf 并没有通用比较操作。`affine.delinearize_index` 返回索引值，不返回映射属性。prefetch 提供提示，不产生 load 的元素结果。独立变换完整名称为 `transform.affine.simplify_bounded_affine_ops`。

依据：[AffineOps.td](/opt/llvm-project/mlir/include/mlir/Dialect/Affine/IR/AffineOps.td)、[Passes.td](/opt/llvm-project/mlir/include/mlir/Dialect/Affine/Passes.td)、[AffineExpandIndexOps.cpp](/opt/llvm-project/mlir/lib/Dialect/Affine/Transforms/AffineExpandIndexOps.cpp:69)、[AffineToStandard.cpp](/opt/llvm-project/mlir/lib/Conversion/AffineToStandard/AffineToStandard.cpp:55)、[AffineTransformOps.td](/opt/llvm-project/mlir/include/mlir/Dialect/Affine/TransformOps/AffineTransformOps.td:21)。清单 9-31/9-32 的 [simple_loop 输入](evidence/ch9-affine-loop.mlir) 经 `--lower-affine` 生成[实际 scf 输出](evidence/ch9-affine-loop-out.mlir)。

<a id="ch9-affine-schedule"></a>

## 调度树与执行顺序（PDF 60–61）

原书称调度树根“必定是 domain”、band 描述“父节点的全序或偏序”、set 表示“乱序执行”，且 affine “不存在对调度顺序的表达”。这些概括不准确。正文解释调度树是树结构，完整 ISL 模型根也可为 extension；band 是字典序的部分调度维度，set 不规定子节点之间顺序，不等于处理器乱序。affine 的循环及块顺序明确承载执行顺序，只是不另设调度树。

传统和结构化表示各有取舍，不能宣称所有传统代码生成都是指数复杂度，或所有 affine 变换均更优。依据：[MLIR 简化多面体设计](/opt/llvm-project/mlir/docs/Rationale/RationaleSimplifiedPolyhedralForm.md)、[ISL 官方手册的 Schedule Trees](https://libisl.sourceforge.io/user.html)。原书的流程四阶段、节点说明、四项共性及四项优点全部保留并校订。

<a id="ch9-vector-types"></a>

## vector 类型表示、动态索引与可伸缩维度（PDF 61–63、69）

原文泛称“嵌套向量”，实际 LLVM 类型转换使用外层数组与最内层一维向量。正文将失效的 `!llvm<"...">`/星号类型写法改为现有数组语法，并给出 `vector<2x3x4xf32>` 的具体嵌套/平铺对应。

表 9-2 原文把 shufflevector 也列为动态索引支持者，应改为静态掩码；insertvalue/extractvalue 的索引静态，但不意味着所有动态外层索引只能通过内存复制实现。嵌套表示仍依赖 LLVM 后端优化，也不能保证比平铺更快。寄存器的 register file 是寄存器组，而非磁盘文件。

vector 不允许任意 `?` 动态维度，但允许 `[4]` 这类可伸缩基本大小，实际长度由 vscale 确定。本地 LLVM 类型转换器只接受最内层维度可伸缩；vector 类型本身可以表示更一般的可伸缩维度组合，不能把后端限制直接说成类型系统不支持。

依据：[LLVMTypeConverter::convertVectorType](/opt/llvm-project/mlir/lib/Conversion/LLVMCommon/TypeConverter.cpp:487)、[Vector 类型验证](/opt/llvm-project/mlir/lib/IR/BuiltinTypes.cpp:229)、[Vector 设计文档](/opt/llvm-project/mlir/docs/Dialects/Vector.md)、[LLVM aggregate/vector 操作](/opt/llvm-project/llvm/docs/LangRef.rst)。

<a id="ch9-vector-ops"></a>

## vector 操作目录的内容与版本错误（PDF 63–67）

| 原书条目/说法 | 按本地定义的校订 |
| --- | --- |
| create_mask 输入可为“符号和多维向量” | 输入为各维范围的 index 类型 SSA 值，输出布尔向量 |
| contract 是降维、并行时必递归执行 | 由映射、迭代器和组合类型定义收缩；结果不一定更低秩，递归展开只是实现策略之一 |
| llvm 方言 matrix.multiply | 文本操作名为 llvm.intr.matrix.multiply，内建函数名与之区分 |
| scalable_extract/scalable_insert | 本地实际名称为 vector.scalable.extract / vector.scalable.insert |
| strided_slice 可任意 stride | 本地相关插入/抽取要求单位步长 |
| insert 可能返回标量 | 返回目标向量；被插入的值才可能是标量 |
| compressstore 往向量中写元素 | 按掩码紧凑写入 memref |
| maskedstore 有 pass_through，false 时写备用值 | 没有 pass_thru；false 时不写内存 |
| vector.load/store 可读写标量 | 操作对应 vector 值，零维 vector 与标量不同 |
| expandload 的 base 是向量，按同一索引选择 | base 为 memref，仅 true 位置读取并推进内存位置；false 使用 pass_thru |
| gather 提供两个基础向量 | base 为 memref 或 ranked tensor，另有 index_vec、mask、pass_thru |
| multi_reduction 总是返回新向量 | 全部维度归约时可为标量 |
| scan 只返回新向量 | 同时返回扫描结果与最后累积值 |
| step 展开原向量 | 原书名称意指索引序列，本地不存在同名操作 |

本地还没有 `vector.deinterleave`、`vector.interleave`、`vector.from_elements`。正文保留原书对应功能说明并标明版本缺失。不能把 tensor.from_elements 当作 vector 的同名实现。

依据：[VectorOps.td](/opt/llvm-project/mlir/include/mlir/Dialect/Vector/IR/VectorOps.td)：contract 33、scalable.insert 743、scalable.extract 800、extract_strided_slice 1110、load 1564、store 1649、maskedstore 1797、gather 1857、expandload 1991、compressstore 2055、create_mask 2301、matrix_multiply 2598、scan 2770；[LLVM 内建操作命名规则](/opt/llvm-project/mlir/include/mlir/Dialect/LLVMIR/LLVMIntrinsicOps.td:11)。

原文“所有 vector 操作都能直接降级到 llvm/spirv”不成立。本地 VectorToSPIRV 只注册特定模式，受目标类型和能力限制；VectorToLLVM 也明确要求部分高秩 transfer 先走 VectorToSCF。图 9-8 全部节点保留，但 xegpu 边标为原书路径，本地没有对应转换目录。依据：[VectorToSPIRV 注册模式](/opt/llvm-project/mlir/lib/Conversion/VectorToSPIRV/VectorToSPIRV.cpp:812)、[VectorToLLVM Pass](/opt/llvm-project/mlir/lib/Conversion/VectorToLLVM/ConvertVectorToLLVMPass.cpp:61)、[VectorToArmSME](/opt/llvm-project/mlir/lib/Conversion/VectorToArmSME/VectorToArmSME.cpp:663)、[VectorToGPU](/opt/llvm-project/mlir/lib/Conversion/VectorToGPU/VectorToGPU.cpp:1222)。

<a id="ch9-vector-transforms"></a>

## vector 的 28 个变换名称及范围（PDF 67–69）

原书将这些条目都简称为“变换操作”，正文补完整层次：通常为 `transform.apply_patterns.vector.<name>`，最后 vector_to_llvm 为 `transform.apply_conversion_patterns.vector.vector_to_llvm`。本地缺少六个同名描述操作：

- drop_unit_dims_with_shape_cast；
- elementwise_to_vector；
- interleave_to_shuffle；
- lower_bitcast；
- lower_interleave；
- sink_ops。

正文逐项保留原书功能说明，标明不可按同名调用，并避免把同名缺失误写成对应算法能力完全不存在。本地也没有原书所列 `lower-vector-multi-reduction` Pass；有 lower_multi_reduction 模式描述。本地 Vector Pass 定义另有 vector-bufferize。

行为修订：fold_arith_extension 实际只匹配两侧 extf；rewrite_narrow_types 的实际集合是 bitcast/trunci、extui/extsi 相关模式，并有小端目标限制；masked_transfer_read 等是对带 mask 的模式称呼，不是操作名；materialize_masks 实现掩码的算术计算；split_transfer_full_partial 可生成运行时边界判断，不能把 in_bounds=false 当作必然越界。各 lower_* 表达更细粒度实现，不能全都机械解释为“输出秩降低”。

依据：[VectorTransformOps.td 全部定义](/opt/llvm-project/mlir/include/mlir/Dialect/Vector/TransformOps/VectorTransformOps.td)、[Vector Passes.td](/opt/llvm-project/mlir/include/mlir/Dialect/Vector/Transforms/Passes.td)、[FoldArithExtIntoContractionOp](/opt/llvm-project/mlir/lib/Dialect/Vector/Transforms/VectorTransforms.cpp:1489)、[窄类型模式集合](/opt/llvm-project/mlir/lib/Dialect/Vector/Transforms/VectorEmulateNarrowType.cpp:942)、[完整/部分 transfer 分离](/opt/llvm-project/mlir/lib/Dialect/Vector/Transforms/VectorTransferSplitRewritePatterns.cpp:521)。

## 实测入口与范围

前段所有执行命令、输入和输出的对应关系见 [linalg/affine 复现命令](evidence/ch9-linalg-affine-commands.md)。测试已运行，覆盖库调用、三种循环降级、卷积向量化、两种融合、池化、四种加法、Transform 分块和 affine 降级；两个保留的原书错例产生预期解析失败。

交付后还从正式 Markdown 提取了前段 25 份完整 MLIR 清单，自动拼合跨页围栏，全部通过本地解析与 verifier。脚本为 [ch9-verify-front.py](evidence/ch9-verify-front.py)，输入及结果为 [ch9-front-verified/results.json](evidence/ch9-front-verified/results.json)。加上尾段 7 份，正文共 **32 份完整 MLIR 清单验证通过**；另 8 份是 C 示例、语法轮廓或显式依赖外部 SSA 值的操作片段（9、10、11、14、27、28、29、30），不冒充完整可执行输入。

这些测试验证了本地 IR 的解析、验证器及变换输出，没有运行数值内核，也没有证明性能提升。需外部实现的库函数、缺少尾块处理的示意代码、测试专用 Transform 扩展及目标硬件假设均已在对应正文说明。后续版本缺失条目保持可追踪，不虚构本地不存在的操作或通过结果。

## 第 9 章尾部补充校订：PDF 第 70–80 页

以下内容对应书页 197–207，由第 7 章校对代理协助完成。**11/11 页均实际查看扫描 PNG**，不只依据 OCR。交稿拆成 PDF 70 前半（完整清单 9-34 及其说明）和从 9.4 开始的尾稿两部分；合并后保留唯一的 PDF 70 页标，PDF 71–80 的页标位于尾稿中。

本段共 **7 份清单（9-34 至 9-40）、1 幅图（9-9）、0 张表、4 条脚注**。其中清单 9-40 跨 PDF 78–79，拆为两个连续代码块呈现，但验证时合并成同一个完整输入。原书最终清单编号是 **9-40**，不是 9-41。所有段落、7 种缓冲化操作、12 项原书 Pass、4 种 Transform 操作、One-Shot 特点、接口项目、所有权约束、图示全部节点及 9.6 小结均已保留并校訂。

| PDF 页 | 书页 | 目视与覆盖 |
| --- | --- | --- |
| 70 | 197 | 清单 9-34、部分转换说明、9.4/9.4.1/DPS 导语及论文脚注 |
| 71 | 198 | DPS 示例与三类依赖、7 种操作、9.4.2 导语 |
| 72 | 199 | Pass 列表前十项及跨页内容 |
| 73 | 200 | Pass 列表续、4 种变换、One-Shot 背景与特性 |
| 74 | 201 | One-Shot 特性续、接口方法、所有权约束与三状态、三条脚注 |
| 75 | 202 | 图 9-9、9.4.3、清单 9-35/36 |
| 76 | 203 | 降级说明续、9.5、清单 9-37/38、分块导语 |
| 77 | 204 | 分块说明、完整清单 9-39、仿射最小值说明开头 |
| 78 | 205 | 边界说明续、向量化导语、清单 9-40 前半 |
| 79 | 206 | 清单 9-40 后半及解释、9.6 开头 |
| 80 | 207 | 小结余下两段及原书博客说明 |

基准同本章：本地 LLVM 18.1.8，提交 `3b5b5c1ec4a3095ab096dd780e84d7ab81f3d7ff`。主校对代理另行完成了缓冲化源码审计和四项关键行为测试，详见 [缓冲化独立复核](evidence/ch9-bufferization/README.md)。本段复用了这些已完成的证据，并独立核对其他 API 和执行完整的向量化示例，没有重复运行其已保存的崩溃反例。

<a id="tail-vector-lowering"></a>
### A. 部分 Vector 降级与 unrealized casts

**PDF 70，清单 9-34。** 原书说插入 `builtin.unrealized_conversion_cast`“意味着在降级时存在类型处理方面的问题”。这种解释过强：部分转换可以合法保留这些桥接操作，等待后续转换统一类型。只运行 `--convert-vector-to-llvm` 后，本例仍有 `func.func`、Arith 常量以及未转换的函数返回类型，不能声称已经得到完整 LLVM 方言模块。

已用 [清单 9-33 对应输入](evidence/ch9-tail/vector-broadcast.mlir) 真实运行 `--convert-vector-to-llvm`，得到 [部分转换输出](evidence/ch9-tail/vector-broadcast.out.mlir)，与清单 9-34 一致。继续依次运行 `--convert-to-llvm --reconcile-unrealized-casts` 后得到 [完整转换输出](evidence/ch9-tail/vector-broadcast-full.out.mlir)，其中为 `llvm.func`、`llvm.mlir.constant`、`llvm.insertvalue`、`llvm.return`，没有残留 unrealized casts。原书这组具体选项在本地能够工作，正文保留。

<a id="tail-bufferization-semantics"></a>
### B. 缓冲化、DPS、RaW 与方言操作

**PDF 70–71。** 原文将 Bufferization 称为“缓存机制”，并说其核心是“通过缓存优化提升类型转换的效率”。正文统一改为**缓冲化**：优化的是 tensor 值映射到可变内存表示时的分配、复制和存储复用，不是 CPU cache，也不只是加速编译器里的类型转换函数。

原书把函数调用者分配结果的 DPS 定义直接套到所有 MLIR 操作。正文保留函数式 DPS 的背景，并区别 MLIR 的操作级 destination：结果与一个 destination 操作数关联，作为存储复用候选。这不强迫每个函数先转换成 out-param ABI。相关本地说明见 [Bufferization.md](/opt/llvm-project/mlir/docs/Bufferization.md:8) 和 [DestinationStyleOpInterface.td](/opt/llvm-project/mlir/include/mlir/Interfaces/DestinationStyleOpInterface.td:14)。

原扫描为：

> 读后写（Read after Write，RaW）、写后写（Write after Write，WaW）、写后读（Write after Read，WaR）。由于 MLIR 代码遵循 SSA 格式……写后写、写后读这两种情况都不会导致内存使用冲突……只需考虑读后写这一种情形。

RaW 的中文应为**写后读**，WaR 应为**读后写**。更重要的是，原地缓冲化要防止对新值的写入破坏后来对旧 tensor 值的读取，不能说只要出现一般意义的写后读就禁止复用；也不能从 tensor 的 SSA 性质推出所有别名缓冲区均无其他内存依赖。正文补上目标缓冲区可写等条件，并解释新分配及复制取决于操作语义。[本地接口可写性说明](/opt/llvm-project/mlir/include/mlir/Dialect/Bufferization/IR/BufferizableOpInterface.td:369) 和 [主校对的冲突输入](evidence/ch9-bufferization/analysis.mlir)、[实际输出](evidence/ch9-bufferization/one-shot.mlir) 提供依据。

原书 7 种操作逐项保留，关键修正如下。

- `alloc_tensor` 在 tensor 层面标记新分配；实际 [定义](/opt/llvm-project/mlir/include/mlir/Dialect/Bufferization/IR/BufferizationOps.td:28) 明确没有 copy 时内容未初始化，不能把 tensor 结果误作已立即返回的 memref。
- 原文“clone……仅创建输入和输出的别名关系”错误。[CloneOp 契约](/opt/llvm-project/mlir/include/mlir/Dialect/Bufferization/IR/BufferizationOps.td:182) 允许别名或实际复制，并明确克隆后修改源或结果为未定义行为；正文恢复完整边界。
- `dealloc` 由条件和 retained memrefs 的别名关系决定释放及所有权传递，不等同于检查 SSA 对象是否还有引用。[DeallocOp](/opt/llvm-project/mlir/include/mlir/Dialect/Bufferization/IR/BufferizationOps.td:560)。
- 原文误称 `ownership-based-buffer-deallocation` 插入 `dealloc_tensor`；实际 [所有权实现](/opt/llvm-project/mlir/lib/Dialect/Bufferization/Transforms/OwnershipBasedBufferDeallocation.cpp:1) 插入的是 `bufferization.dealloc`。`dealloc_tensor` 仍是可手动使用的 tensor 存储释放操作。[其 TD 注释](/opt/llvm-project/mlir/include/mlir/Dialect/Bufferization/IR/BufferizationOps.td:329) 自身残留了 One-Shot 负责释放的旧说法，正文以实际 Pass 与测试为准。
- `materialize_in_destination` 的目标不是必须新分配；`to_memref`、`to_tensor` 是语义边界操作，不能从“创建对象”推断无条件复制内存。

<a id="tail-bufferization-api"></a>
### C. Pass、Transform 扩展和 One-Shot API

**PDF 72–74。** 原书列出的 12 项 Pass 全部保留，同时修正其前提及本地版本差异。

1. `buffer-deallocation-simplification` 简化运行时检查，不是只有执行它才避免重复释放；`dealloc` 本身就必须具有正确的别名和条件语义。
2. `buffer-hoisting` 优化合法 IR 的分配位置，不负责修复原文所说“使用者超出 alloc 作用域”的无效 IR。移动必须保持支配和生命周期合法。[BufferOptimizations.cpp](/opt/llvm-project/mlir/lib/Dialect/Bufferization/Transforms/BufferOptimizations.cpp:1)。
3. `buffer-results-to-out-params` 必须原子地更新函数及调用点。本地 [实现](/opt/llvm-project/mlir/lib/Dialect/Bufferization/Transforms/BufferResultsToOutParams.cpp:46) 将结果属性迁移到新增参数，不是原文所说必须“添加额外属性表示”；[调用点分配](/opt/llvm-project/mlir/lib/Dialect/Bufferization/Transforms/BufferResultsToOutParams.cpp:148) 要求静态形状，布局也有限制。转换本身可能引入复制，不能保证自动减少全部内存分配。
4. `bufferization-lower-deallocations` 可能生成 memref 之外的条件控制流、算术及辅助函数，且后面还有 CSE、canonicalize，不是固定的最后一个 Pass。[Passes.td](/opt/llvm-project/mlir/include/mlir/Dialect/Bufferization/Transforms/Passes.td:255)。
5. 原书对 `drop-equivalent-buffer-results` 的“不严格限定 memref”观察符合本地 [比较循环](/opt/llvm-project/mlir/lib/Dialect/Bufferization/Transforms/DropEquivalentBufferResults.cpp:82)：剥离 memref.cast 后会直接比较 SSA 值与形参。保留这一观察，并注明它不代表可删除任意不同的返回值。
6. `eliminate-empty-tensors` 需要具体可匹配的 destination 使用链，不能把任意 `tensor.empty` 都换成 `extract_slice`。[Pass 描述和例子](/opt/llvm-project/mlir/include/mlir/Dialect/Bufferization/Transforms/Passes.td:535)。
7. **`optimize-allocation-liveness` 在本地 LLVM 18.1.8 未定义。** 对 `mlir/include`、`mlir/lib`、`mlir/docs` 的名称搜索均无结果，`mlir-opt --help` 也没有该选项。正文保留原书功能描述并加本地不可用说明，图 9-9 的最终步骤作同样标注。没有用其他名称冒充兼容替代。
8. `promote-buffers-to-stack` 的规模、显式释放及自动作用域条件对照 [BufferOptimizations.cpp](/opt/llvm-project/mlir/lib/Dialect/Bufferization/Transforms/BufferOptimizations.cpp:370) 修订。

原书把四种 Bufferization Transform 操作的提供者写成“vector 方言”，这是串节错误。实际是 **Transform 方言的 Bufferization 扩展**，完整名为 `transform.bufferization.buffer_loop_hoisting`、`transform.bufferization.eliminate_empty_tensors`、`transform.bufferization.empty_tensor_to_alloc_tensor`、`transform.bufferization.one_shot_bufferize`。[BufferizationTransformOps.td](/opt/llvm-project/mlir/include/mlir/Dialect/Bufferization/TransformOps/BufferizationTransformOps.td:26)。

原书说 LLVM 19 移除了旧缓冲化 Pass，本地 18.1.8 的 [Passes.td](/opt/llvm-project/mlir/include/mlir/Dialect/Bufferization/Transforms/Passes.td:323) 仍定义 `finalizing-bufferize`、`bufferization-bufferize` 等旧入口。正文明确这是一条原书关于后续版本的历史记载，没有将其冒充为本地现状；未独立审核 LLVM 19 每个旧 Pass 的全部移除提交。

One-Shot 的分析顺序在本地 [OneShotAnalysis.h](/opt/llvm-project/mlir/include/mlir/Dialect/Bufferization/Transforms/OneShotAnalysis.h:27) 只有 `BottomUp`、`TopDown` 两种，测试随机化使用 fuzzer seed。原书的 `bottom-up-from-terminators` 不可用；主校对已经保存 [预期失败记录](evidence/ch9-bufferization/unsupported-order.stderr.txt)，Debug 构建会触发不可达断言。正文没有把该配置放进可执行命令。

原书接口列表的 `getAliasingOpResult()`、`bufferRelation` 与本地定义不同。[BufferizableOpInterface.td](/opt/llvm-project/mlir/include/mlir/Dialect/Bufferization/IR/BufferizableOpInterface.td:229) 实际提供 `getAliasingValues()`、`getAliasingOpOperands()`，别名项包含 `relation` 与 `isDefinite`。`Equivalent` 说明同一缓冲区、大小、偏移和步长对应；`Unknown` 只是不具备更强的等价关系信息，**不是不别名**。原书“不重叠或部分重叠”的解释不准确。本地 `Bufferization.md` 也有旧 API 残留，因此接口名以 TD 为准，不能凭文档恢复成错误名称。

<a id="tail-deallocation"></a>
### D. 所有权与图 9-9

**PDF 74–75。** 默认函数约定为参数借用、返回值转移所有权、返回分配不得与输入底层分配别名。正文修正原文“释放返回参数”的措辞，并补充 `private-function-dynamic-ownership` 可以显式传递私有函数动态所有权，避免把默认 ABI 描述成毫无例外的模型。[本地配置说明](/opt/llvm-project/mlir/include/mlir/Dialect/Bufferization/Transforms/Passes.td:193)。

三种所有权状态确实存在，但 `unique` 不是说没有内存别名，而是拥有一个可表示运行时所有权的 SSA 指示值。[Ownership](/opt/llvm-project/mlir/include/mlir/Dialect/Bufferization/IR/BufferDeallocationOpInterface.h:28) 明确给出格和 indicator 的含义，正文补上这层解释。

图 9-9 完整保留左侧 10 个步骤和右侧内部 8 个步骤。内部顺序确认为：

```text
expand-realloc (emit-deallocs=false)
canonicalize
ownership-based-buffer-deallocation
canonicalize
buffer-deallocation-simplification
bufferization-lower-deallocations
cse
canonicalize
```

依据为 [BufferizationPipelines.cpp](/opt/llvm-project/mlir/lib/Dialect/Bufferization/Pipelines/BufferizationPipelines.cpp:21) 和 [实际打印的 pipeline](evidence/ch9-bufferization/pipeline.stderr.txt)。原图这部分正确，本地概要文档漏了第一个 canonicalize，未据此错误删图。图用连接两组的虚线表示内部流程的展开说明，避免把展开与返回画成执行循环。外围 Pass 是示例安排，`optimize-allocation-liveness` 标明本地未提供。整条 pipeline 不接受已经随意插入的显式释放操作；原图不能作为将任何现有 memref 程序不加检查直接串联所有 Pass 的保证。

One-Shot 本身不插入完整的释放处理，主校对的 [one-shot.mlir](evidence/ch9-bufferization/one-shot.mlir) 与 [接入释放 pipeline 后的结果](evidence/ch9-bufferization/deallocated.mlir) 明确区分两阶段。

清单 9-35 主动释放 `%arg0`，正文声明它需要调用方转交释放责任；不能同时套用“参数只借用”的默认规则，也不能将已含显式 dealloc 的示例直接送入所有权 pipeline。实际 [clone 输入](evidence/ch9-tail/clone.mlir) 经 `--convert-bufferization-to-memref` 得到 [输出](evidence/ch9-tail/clone.out.mlir)，本次转换采用新分配并复制。该结果不改变 `clone` 可有不同合法实现的抽象契约。

<a id="tail-matmul"></a>
### E. 完整分块与可伸缩向量化示例

**PDF 76–79，清单 9-37 至 9-40。** 全部原始输入、Transform 规则、完整分块输出和完整向量化输出均保留；没有把两页向量化代码缩成摘要。

原文称从 Linalg 到 Affine 再到 Vector。实际 `tile_using_for` 生成的是 `scf.for`，其中用 Affine 操作计算边界，不能说整个中间程序都降成了 Affine 方言。三重循环步长 `8`、`16 * vscale`、`1` 与原书一致。原 `linalg.matmul` 还会读取并累加 `%arg2`，因此正文说明它计算 `C + A×B`，若要单纯乘法，输出初始值应为零。

原清单 9-38 写成：

```text
transform.structured.tile_using_for %0 tile_sizes [8, [16], 1]
```

本地语法在目标后直接写尺寸列表：

```text
transform.structured.tile_using_for %0 [8, [16], 1]
```

原语法的 [输入](evidence/ch9-tail/transform-original-syntax.mlir) 实际解析失败，报 `expected '[' in dynamic index list`，见 [错误日志](evidence/ch9-tail/transform-original-syntax.stderr.txt)。修订语法来自 [LinalgTransformOps.td](/opt/llvm-project/mlir/include/mlir/Dialect/Linalg/TransformOps/LinalgTransformOps.td:1817) 与 [本地可伸缩分块及向量化测试](/opt/llvm-project/mlir/test/Dialect/Linalg/transform-op-peel-and-vectorize.mlir:60)。未在没有对照具体提交的情况下认定原书语法在所有 LLVM 20 版本中都错误。

实际把 [payload](evidence/ch9-tail/payload.mlir) 与 [Transform 规则](evidence/ch9-tail/transform.mlir) 组合后运行 `--transform-interpreter`：

- [tiled.mlir](evidence/ch9-tail/tiled.mlir) 只执行第一步，得到 [tiled.out.mlir](evidence/ch9-tail/tiled.out.mlir)。
- [vectorized.mlir](evidence/ch9-tail/vectorized.mlir) 执行两步，得到 [vectorized.out.mlir](evidence/ch9-tail/vectorized.out.mlir)。

两者均 exit 0，并真实产生可伸缩步长、tensor 切片、掩码向量读取、乘法、归约和写回。后者仍有三重 `scf.for`，没有暗示向量化消除了所有外层循环。

**本地输出和书中输出有可见但较小的排布差异。** 本地常量按相应循环层生成，计算第二维有效宽度的 `affine.min` 位于中层而非最内层；最小值映射的两个结果顺序与扫描相反；SSA 命名也不同。这些差异没有改变此处循环不变量和 `min(2000-j,16*vscale)` 的含义。正文清单 9-39/40 保留原书可通过本地 verifier 的完整排布，明确它不是本地打印器逐字输出；真实输出另存文件便于对照。未删除原书中无使用的若干 `affine.apply`，也未私自叠加 canonicalize 改成更短结果。

本例只验证 IR 变换和合法性，没有运行完整 1024×512×2000 的矩阵乘法或测硬件性能。一个高维 Vector IR 值未必对应单条机器指令，性能还取决于目标指令支持和后续降级。因此原书“从而实现性能提升”改为提供性能优化机会，并明确测量边界。

### F. 文献与 OCR

本段修复 `int` → `into`、`tran​​​​sform`、`tensor.dim` 被误读为 `tensor,dim`、`%c16_vscale` 丢前缀、`%5` 丢失、`%15` 误读 `%1.5`、`[8, %3]` 丢失、`vector<8x[16]x1xf32>` 中括号与类型混乱等 OCR 问题，均依据扫描图恢复。没有将 OCR 丢掉的 module/循环花括号当作原书的省略。

保留四条原书脚注与访问年月。DPS 脚注引用 FHPC 2017 的 *Destination-passing style for efficient memory management*，但给出的 [Microsoft Research PDF](https://www.microsoft.com/en-us/research/wp-content/uploads/2016/11/dps-submitted.pdf) 所载稿件标题是 *Using Destination-Passing Style to Compile a Functional Language into Efficient Low-Level Code*。正文保留原书书目和链接，并标明链接版本的标题不同，没有擅自推断这两个标题是完全相同的出版版本。

另外两条官方文档和 [2023 年演讲资料](https://m-sp.org/downloads/llvm_dev_2023.pdf) 保留；正文的具体版本 API 仍依据本地源码。末页说完整案例将放在作者技术博客中，但没有提供地址，本稿不虚构博客链接或声称这些内容已经发布。

### G. 复现命令与最终验证

永久证据目录为 [evidence/ch9-tail](evidence/ch9-tail/)，补充复用 [evidence/ch9-bufferization](evidence/ch9-bufferization/) 的独立审计与运行结果。合并正文后可从仓库根目录执行：

```sh
python3 mlir/insider-compiler/issues/evidence/ch9-tail/run.py
python3 mlir/insider-compiler/issues/evidence/ch9-tail/verify_markdown.py
/opt/llvm-project/build/bin/mlir-opt \
  mlir/insider-compiler/issues/evidence/ch9-tail/vector-broadcast.mlir \
  --convert-vector-to-llvm --convert-to-llvm --reconcile-unrealized-casts \
  -o mlir/insider-compiler/issues/evidence/ch9-tail/vector-broadcast-full.out.mlir
```

`run.py` 的四个场景均返回 0，命令记录于 [results.json](evidence/ch9-tail/results.json)。完整 LLVM 转换与预期失败的原 Transform 语法另见 [additional-results.json](evidence/ch9-tail/additional-results.json)。`verify_markdown.py` 从 Markdown 提取清单 9-34 至 9-40，自动合并清单 9-40 的跨页代码；7 份清单均单独通过本地解析与 verifier，见 [verify-markdown.json](evidence/ch9-tail/verify-markdown.json)。这一区分保证完整示例真的运行过，同时所有交付代码也单独通过检查。

剩余范围明确为：未审核 LLVM 19 全部历史移除提交；未确认原书书目与链接稿件的最终出版版本对应关系；未做矩阵乘法性能测试。本地不存在的配置和 Pass 均已标注，正文没有把它们列成已经通过的 LLVM 18 命令。
