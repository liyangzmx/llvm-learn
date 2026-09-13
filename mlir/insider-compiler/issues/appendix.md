# 附录校订记录

对应 [附录《其他方言》正文](../insider-compiler-appendix.md)。扫描源为 `pdf/insider-compiler-ch14-end.pdf`，PDF 第 **49–52 页**，共 **4 页**；书页为 415–418，其中附录首页未印页码，415 由后续连续页码确定。源文件 SHA-256 为 `fc51b66bce20a574106efca042b7e1a15b816e3ad75a0db875bcd4fe1e309faa`。

技术依据为本地 `/opt/llvm-project` 的 **LLVM 18.1.8**，提交 `3b5b5c1ec4a3095ab096dd780e84d7ab81f3d7ff`。原书参考 LLVM 20 时期的实现，下面将明确的概念错误与版本差异分别记录；本地缺少较新方言，并不证明原书虚构了这些方言。

## 覆盖与原样保留

- 7 个原编号条目：`dlti`、`ptr`、`ub`、`polynomial`、`async`、`mesh`、`quant`；保留 Mesh 下“接口”“优化”两个子节，以及全部操作、接口方法和转换名称。
- 原编号代码清单 **1** 份（A-1，跨 PDF 49–50），原图 **0**、原表 **0**、原脚注 **1**、原注意框 **0**。正文中的版本校订引文块均为此次添加，不计为原注意框。
- 正文清单 A-1 使用已验证的 LLVM 18 完整基础布局输入；原清单中的 CPU/GPU/XPU 较新设备配置完整保存在本记录中，正文继续解释相关属性的概念和版本范围。
- 本附录 4 张原始 PNG（49、50、51、52）均实际使用 `view_image` 查看，重点核对清单、属性标点、多项式变量、七项接口名称和唯一脚注。无示意图需要重建或裁剪。
- 每页均有 `source` 注释。原跨页清单 A-1 保存在本记录中，正文保留页标并使用本地可运行的对应清单；跨页的函数返回分片约束连成完整句子，后置续页标记，避免把中文拆成半句或半个词。
- 原始 Apple Vision TXT/JSON/PNG 未修改。

## OCR 与排版修复

恢复 `dlti`、`DataLayoutEntryAttr`、`DataLayoutSpecAttr`、`!llvm.ptr`、`vector<4xi64>`、`little`、`size_in_bytes`、`i32`、`ui32`、`max_vector_op_width`、`XPU`、`uniform` 等误识别，以及 `< >`、`=`、逗号、引号和注释符号。清单缓存键保留扫描中的 `"L1"` 和 `"L1d"`，没有擅自把前者改成 `"L1i"`。

Ptr 属性扫描为 `#ptr.spec<...>`，OCR 错为 `#ptr:spec<...>`，已修复。原句“指令类型相关”按语义更正为“指针相关”。多项式中的 `q(x)`、`f(x)` 按扫描恢复，不沿用 OCR 的 `9(x)` 和乱码。

脚注 URL 恢复为 [Juneyoung Lee 的 Undef and Poison: Present and Future](https://llvm.org/devmtg/2020-09/slides/Lee-UndefPoison.pdf)，已打开该官方 PDF 确认标题和作者；保留原书“2025 年 3 月访问”，没有将历史访问时间改写为此次访问日期。

## DLTI：属性范围、单位与清单边界

<a id="appendix-dlti-original"></a>

正文以已验证的 LLVM 18 基础布局作为代码清单 A-1。原扫描 PDF 49–50 的较新清单保存在下方，继续保留所有 CPU/GPU/XPU 配置值，但不再作为本地阅读和实践时的主示例。

原书写道：

> dlti 方言定义的属性有 5 个，分别是 DataLayoutEntryAttr、DataLayoutSpecAttr、MapAttr、TargetDeviceSpecAttr 和 TargetSystemSpecAttr。

这是版本边界。本地 [DLTI.h](/opt/llvm-project/mlir/include/mlir/Dialect/DLTI/DLTI.h:33) 声明两种布局属性，[DLTIDialect 构造函数](/opt/llvm-project/mlir/lib/Dialect/DLTI/DLTI.cpp:374) 实际只注册 `DataLayoutEntryAttr` 和 `DataLayoutSpecAttr`，没有另三种属性。正文保留较新三种属性的概念与版本范围，不因 LLVM 18 缺项删除相关功能介绍。

### 原扫描代码清单 A-1

以下保留原清单的属性赋值片段和原注释含义，仅恢复代码排版。它不是完整的 MLIR 模块输入；其中“描述 llvm.ptr 的具体类型”的原注释也不准确。

```mlir
// 定义数据、类型布局信息
dlti.dl_spec = #dlti.dl_spec<
  // 描述 llvm.ptr 的具体类型：键是 llvm.ptr，值为 dense<64>
  #dlti.dl_entry<!llvm.ptr, dense<64> : vector<4xi64>>,
  #dlti.dl_entry<"dlti.endianness", "little">, // 字节序是小端
  // 描述栈对齐的方式，按 128 位对齐
  #dlti.dl_entry<"dlti.stack_alignment", 128 : i64>>

// 定义目标系统的布局信息，包括 CPU、GPU 和 XPU 三个设备
dlti.target_system_spec = #dlti.target_system_spec<
  // CPU 设备的缓存配置
  "CPU" = #dlti.target_device_spec<
    "cache" = #dlti.map<"L1" = #dlti.map<"size_in_bytes" = 65536 : i32>,
                        "L1d" = #dlti.map<"size_in_bytes" = 32768 : i32>>>,
  // GPU 设备支持的最大向量操作宽度
  "GPU" = #dlti.target_device_spec<
    "max_vector_op_width" = 64 : ui32>,
  // XPU 设备支持的最大向量操作宽度
  "XPU" = #dlti.target_device_spec<
    "max_vector_op_width" = 4096 : ui32>>
```

原清单由两个独立属性赋值组成，没有外围操作或属性字典分隔逗号。证据 [dlti-newer.mlir](evidence/appendix/dlti-newer.mlir) 将全片段放入 `module attributes { ... } {}` 并补齐分隔符后，LLVM 18 仍明确报 `unknown attrribute type: target_system_spec`。因此缺项不是由外围语法错误误判的；诊断拼写是本地源码原样。

正文 A-1 使用 [dlti-18.mlir](evidence/appendix/dlti-18.mlir) 的已验证完整输入，保留指针布局、小端序与栈对齐三条有效配置。`!llvm.ptr` 是默认地址空间的不透明指针类型，布局条目不描述指针所指元素；[LLVMTypes.h](/opt/llvm-project/mlir/include/mlir/Dialect/LLVMIR/LLVMTypes.h:287) 给出四个位置 `Size`、`Abi`、`Preferred`、`Index`，`dense<64> : vector<4xi64>` 因而将四项都设为 64。

布局条目中的对齐单位为位，实际 DataLayout ABI/推荐对齐查询返回字节；[LLVMTypes.cpp](/opt/llvm-project/mlir/lib/Dialect/LLVMIR/IR/LLVMTypes.cpp:289) 对相应条目除以 `kBitsInByte`。栈对齐字段仍为位，见 [DataLayoutInterfaces.td](/opt/llvm-project/mlir/include/mlir/Interfaces/DataLayoutInterfaces.td:318)。正文保留 `128 : i64` 的 128 位含义。

布局属性常附着 `builtin.module`，但并非只能由 Module 提供作用域；数据布局接口可由其他操作实现。设备缓存、能力键也不全部属于类型内存布局。正文直接说明这些准确含义，原文差异集中记录于此。

## Ptr、Polynomial：保留原书版本介绍

本地 `mlir/include/mlir/Dialect/`、`mlir/lib/Dialect/` 中均不存在 `Ptr`、`Polynomial` 目录；对应注册方言也不在本地 `mlir-opt --help` 清单中。源码检索未找到 `PtrDialect`、`PolynomialDialect`。因此不把原书对它们的介绍写成 LLVM 18 已实现功能，也没有假称验证了较新版本的指针转换或多项式降级。相关声明的首次引入版本与 LLVM 20 的全部签名未另建环境核验。

Polynomial 原句：

> 若它们除以多项式 f(x) 的余数相同，那么这两个多项式可被视为相等。

改为模 `f(x)` 同余、在相应商环中代表同一元素。原始多项式不必相等，例如 `x` 与 `x + f(x)` 通常不同，但属于同一剩余类。正文未把这个数学澄清说成来自本地不存在的 Polynomial 方言实现。

## UB 与 Async：语义和运行时实现分开

- 原书把 `poison` 笼统称作未定义行为的表示。依据 [UBOps.td](/opt/llvm-project/mlir/include/mlir/Dialect/UB/IR/UBOps.td:44)，准确概念是表示 **deferred undefined behavior** 的毒值；产生毒值本身不等于立即触发 UB。保留原文唯一参考脚注；官方讲义第 16 张也作此区分。
- 原书“在运行时，它借助线程池来实现异步操作”对应本地提供的运行时实现，但不是每种 Async 后端必须采用的方案。[AsyncRuntime.cpp](/opt/llvm-project/mlir/lib/ExecutionEngine/AsyncRuntime.cpp:75) 持有 `llvm::ThreadPool`，[任务调度位置](/opt/llvm-project/mlir/lib/ExecutionEngine/AsyncRuntime.cpp:397) 使用该线程池。正文限定为本地提供的 Async Runtime，未声称实际执行了多线程程序。

## Mesh：名称、接口和转换管线的版本差异

### 基础表示与通信操作

原书的“三个基础操作 mesh、sharding、shard”保留为原版本介绍。本地对应的实际表示是：

- [MeshOps.td](/opt/llvm-project/mlir/include/mlir/Dialect/Mesh/IR/MeshOps.td:29) 的 `mesh.cluster` 定义设备网格。
- [MeshBase.td](/opt/llvm-project/mlir/include/mlir/Dialect/Mesh/IR/MeshBase.td:85) 的 `MeshShardingAttr`，文本名 `#mesh.shard`，表达分片规则。它是属性。
- [MeshOps.td](/opt/llvm-project/mlir/include/mlir/Dialect/Mesh/IR/MeshOps.td:107) 的 `mesh.shard` 是张量标注操作。

原通信名单全部保留；`all_slice` 本地没有。`all_reduce` 的作用域由网格轴选择，见 [AllReduceOp](/opt/llvm-project/mlir/include/mlir/Dialect/Mesh/IR/MeshOps.td:314)，不能从“全局归约并同步分发”推出每次都对整个网格执行屏障。

### ShardingInterface 的七项原文与四项本地方法

原书七项方法名全部保留，差异明确标注：本地 [ShardingInterface.td](/opt/llvm-project/mlir/include/mlir/Dialect/Mesh/Interfaces/ShardingInterface.td:21) 的 `methods` 中实际只有 `getLoopIteratorTypes`、`getIndexingMaps`、`getShardingOption`、`addShardingAnnotations`。没有 `getReductionLoopIteratorKinds`、`getShardingAnnotations`、`spmdize` 三个接口方法。

本地归约迭代类型直接编码在 [IteratorType 枚举](/opt/llvm-project/mlir/include/mlir/Dialect/Mesh/IR/MeshBase.td:68) 中，包括 `ReductionSum`、`ReductionMax`、`ReductionMin` 等，不应照搬较新 `ReductionKind` 接口。

原书对 `getIndexingMaps` 先说“迭代空间到张量索引”，随后又说“该张量的维度如何映射到接口 getLoopIteratorTypes 所描述的维度”，前后方向矛盾。按 [接口说明](/opt/llvm-project/mlir/include/mlir/Dialect/Mesh/Interfaces/ShardingInterface.td:45) 更正为迭代空间 → 张量索引。其 [本地验证](/opt/llvm-project/mlir/lib/Dialect/Mesh/Interfaces/ShardingInterface.cpp:152) 还要求操作数和结果均为 RankedTensor，映射数量等于二者数量之和。

### 传播与 SPMD 化

原书的较强断言保留于此：

> 经过此优化后，每个操作的操作数和结果都会使用 mesh.shard 操作进行标注。
>
> 它要求输入操作必须完全标注，因此，该优化需紧跟在 sharding-propagation 优化之后。

本地 [ShardingPropagation.cpp](/opt/llvm-project/mlir/lib/Dialect/Mesh/Transforms/ShardingPropagation.cpp:157) 在推导出的分片信息为空时直接成功返回，操作可能不添加标注；[同文件](/opt/llvm-project/mlir/lib/Dialect/Mesh/Transforms/ShardingPropagation.cpp:180) 要求函数只有一个基本块。正文将“每个操作都会”改为在接口和已知信息允许时补齐；无初始分片信息的对照函数实际保持不变。

完整标注是后续 SPMD 化的前提，不能据此推出两个 Pass 在管线中必须紧邻：输入可以事先已有完整标注，也可以由其他步骤提供。正文保留原书所有前置条件，包括张量输入/输出/基本块参数、接口或完全复制的要求，以及多返回块相应结果分片一致的责任。

不过，本地 [Mesh Passes.td](/opt/llvm-project/mlir/include/mlir/Dialect/Mesh/Transforms/Passes.td:19) 只定义 `sharding-propagation`，无正式 `mesh-spmdization`。本地 [Spmdization.h](/opt/llvm-project/mlir/include/mlir/Dialect/Mesh/Transforms/Spmdization.h:20) 有 `shardShapedType`、`reshard`，另有 [测试用 resharding Pass](/opt/llvm-project/mlir/test/lib/Dialect/Mesh/TestReshardingSpmdization.cpp:108)。辅助函数与测试 Pass 不等同于原书完整函数转换，没有拿它们作为已实现书中管线的证据。

## Quant：精度、量化粒度与存储转换

- 原书称浮点表示能够捕获“精确数值特征”，正文限定为模型的浮点表达类型，指出浮点本身也有有限精度；量化后再反量化并不恢复已损失的信息。
- 原书“逐层量化”描述的实际粒度是整个张量共享量化参数，因此改称“逐张量（原书称逐层）”，与“逐通道/逐轴”对照。依据为 [UniformQuantizedType](/opt/llvm-project/mlir/include/mlir/Dialect/Quant/QuantTypes.h:255) 与 [UniformQuantizedPerAxisType](/opt/llvm-project/mlir/include/mlir/Dialect/Quant/QuantTypes.h:315)。后者编码特定轴以及按轴切片的 scale/zero-point 数组。
- 原书 `scast` 仅写“将量化类型转换为真正的内存存储类型”，遗漏反向转换。根据 [QuantOps.td](/opt/llvm-project/mlir/include/mlir/Dialect/Quant/QuantOps.td:77)，它支持量化类型 ↔ 存储类型两个方向。它维护类型一致性，不负责分配内存，也不取代 `qcast`/`dcast` 的数值语义。
- 原书与本地一致，均列出 `dcast`、`qcast`、`scast` 三个操作。原书将历史接口变化归因于谷歌/ TensorFlow 接入时方案演进，正文作为原书的历史说明保留，没有进行作者归属或版本演进的独立历史审计。

## 实际验证与复跑

证据目录：[evidence/appendix](evidence/appendix/)。直接执行：

```sh
python3 mlir/insider-compiler/issues/evidence/appendix/run_checks.py
```

所有工具命令均使用 `/opt/llvm-project/build/bin/mlir-opt`，输入和逐次 stdout/stderr 均已永久保存；[results.json](evidence/appendix/results.json) 保存完整命令参数、工作目录、版本和预期返回码。实际结果为 **7 次调用全部满足预期**：

| 输入/命令 | 实际结果 | 能证明的范围 |
| --- | --- | --- |
| `--version` | LLVM 18.1.8，Debug，启用断言；提交匹配 | 明确验证工具版本 |
| `dlti-18.mlir` | 返回 0，布局属性正常打印 | A-1 基础布局的本地解析与验证 |
| `dlti-newer.mlir` | 预期返回 1：`unknown attrribute type: target_system_spec` | 即使补齐 Module 语法，LLVM 18 仍不接受较新属性；诊断中的 `attrribute` 是本地源码原拼写 |
| `ub.mlir --convert-ub-to-llvm` | `ub.poison` 转成 `llvm.mlir.poison` | 此标量毒值的局部方言转换；函数本身仍是 `func.func` |
| `quant.mlir --canonicalize` | 两个方向的相邻 `scast` 消除，`qcast`/`dcast` 保留；逐轴类型正常解析 | 双向存储转换可折叠，以及逐张量/逐轴类型语法；不声称完成数值量化执行 |
| `mesh.mlir --sharding-propagation` | 已标注的 sigmoid 输出反向补出输入注解；无注解函数保持不变 | 实际标注传播与空信息路径，不是分布式执行 |
| `--help` | 有 `sharding-propagation`、`test-mesh-resharding-spmdization`，无正式 `mesh-spmdization`；无 ptr/polynomial 注册 | 构建中的可用方言/Pass 与源码核对一致 |

这些是有界的解析、验证、折叠与转换检查。没有安装或构建较新 LLVM，没有执行 Async 线程池、分布式通信、SPMD 程序或量化数值内核，也没有把它们称作已通过的测试。本附录没有图，不需要 Mermaid 渲染。保留的未验证范围主要是原书较新方言/接口的完整实现，正文均有明确版本说明。
