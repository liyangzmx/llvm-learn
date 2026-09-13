# 附录　其他方言

> 校订依据：本地 LLVM/MLIR **18.1.8**，提交 `3b5b5c1ec4a3095ab096dd780e84d7ab81f3d7ff`。原书以 LLVM 20 时期的实现为参考；本附录涉及的 DLTI、Ptr、Polynomial、Mesh 存在明显版本差异，正文分别注明。原始 OCR 保存在 `ocr/insider-compiler-ch14-end/`，详细依据及实际核验记录见 [附录校订记录](issues/appendix.md)。

<!-- source: insider-compiler-ch14-end.pdf, PDF p. 49 -->

本书第二部分提到，MLIR 社区提供的方言接近 50 个，第 8～12 章介绍了大部分主流方言，但还存在一些辅助方言或用于特殊场景的方言，暂时不便将它们归入第 8～12 章所涉及的范畴。我们称其为其他方言，在附录中进行介绍。这里的方言数量描述的是原书所参考版本的情况。

## 1. dlti 方言

`dlti` 方言通过属性描述数据布局；支持目标系统属性的较新版本还可以描述设备配置和能力。该方言没有定义操作。本地 LLVM 18 实现了两个属性：`DataLayoutEntryAttr` 表示键值对形式的布局条目，`DataLayoutSpecAttr` 将这些条目组成数据布局说明。

使用 `dlti` 方言描述数据布局的完整示例如代码清单 A-1 所示。该输入已通过本地 LLVM 18.1.8 的解析和验证。

**代码清单 A-1　使用 dlti 方言描述的数据布局示例**

```mlir
module attributes {
  dlti.dl_spec = #dlti.dl_spec<
    #dlti.dl_entry<!llvm.ptr, dense<64> : vector<4xi64>>,
    #dlti.dl_entry<"dlti.endianness", "little">,
    #dlti.dl_entry<"dlti.stack_alignment", 128 : i64>>
} {}
```

第一条布局的键 `!llvm.ptr` 表示默认地址空间的 LLVM 不透明指针类型。`dense<64> : vector<4xi64>` 是四个 64 的压缩写法，依次描述指针大小、ABI 对齐、推荐对齐和索引位宽，布局字段以位为单位。它不提供指针所指元素的类型。后两条分别指定小端字节序和 128 位的栈对齐。

<!-- source: insider-compiler-ch14-end.pdf, PDF p. 50 -->

较新版本还提供 `MapAttr`、`TargetDeviceSpecAttr` 和 `TargetSystemSpecAttr`。`MapAttr` 表示多个键值对或布局条目构成的映射，`TargetDeviceSpecAttr` 描述一个目标设备，`TargetSystemSpecAttr` 组合系统中的多个设备。这些属性可记录 CPU 缓存配置、GPU/XPU 最大向量操作宽度等设备能力，不仅限于类型的内存布局。它们不属于本地 LLVM 18 的实现；对应的 CPU/GPU/XPU 完整原示例和版本差异保存在 [DLTI 原稿差异](issues/appendix.md#appendix-dlti-original)。

`dlti` 属性通常附着在 `builtin.module` 上。编译器开发者可查询布局或设备信息，并据此开展优化。其他实现数据布局接口的操作也可以提供布局作用域；附加元数据本身不会自动执行优化。

## 2. ptr 方言

`ptr` 方言在本书所分析的版本中并未定义操作，仅定义了指针相关的类型和属性。这些属性用于描述指针的布局信息。例如，属性 `#ptr.spec<size = 64, abi = 64, preferred = 128, index = 64>` 描述了指针的大小、ABI 对齐方式、推荐对齐方式以及索引位宽。此外，原书参考实现中的 `ptr` 指针类型能够降级为 `llvm` 方言中的指针类型。

> **版本校订：**本地 LLVM 18 源码中没有 `Ptr` 方言，以上内容保留为原书较新版本的介绍。它不表示本地已经支持 `#ptr.spec`，也不表示所有后续版本都没有 `ptr` 操作。本地的 LLVM 指针布局可参照上一节的 `!llvm.ptr` 与 DLTI 条目。

## 3. ub 方言

`ub` 方言定义了 `poison` 操作和 `poison` 属性，用于表示编译过程中需要表达的毒值及其相关未定义行为语义。准确地说，`ub.poison` 产生表示**延迟未定义行为**的毒值，产生这个值本身并不等于立即触发未定义行为；毒值如何传播，以及何时因具体使用而触发未定义行为，取决于相关操作的语义。若读者希望进一步了解相关信息，可参考相关文献。[^appendix-1]

## 4. polynomial 方言

`polynomial` 方言定义了针对未知变量的多项式类型及相关运算。例如，在抽象代数的环论框架下，假设有两个多项式 $p(x)$、$q(x)$，若它们除以多项式 $f(x)$ 的余数相同，则有

$$
p(x) \equiv q(x) \pmod{f(x)}.
$$

也就是说，它们在模 $f(x)$ 的商环中代表同一个元素，而不是说两个原始多项式本身相等。该方言主要围绕多项式定义相关操作。鉴于它属于数学领域的特殊方言，本书不再展开阐述。

> **版本校订：**本地 LLVM 18 没有 `Polynomial` 方言，本段保留其概念介绍并修正“余数相同即多项式相等”的表述；未把较新方言的实现或降级路径视作已在本地得到验证。

## 5. async 方言

`async` 方言用于定义异步执行相关的类型和操作。`async` 的实现除了需要编译方面的支持外，通常还依赖一个额外的运行时系统。MLIR 提供的本地 Async Runtime 实现借助线程池来调度异步操作。线程池是这个运行时的实现方式，并非 `async` 方言语义对所有后端的强制要求。

## 6. mesh 方言

`mesh` 方言在 AI 编译器中颇具实用价值，主要用于助力分布式并行计算。此方言涵盖一组操作、属性、接口及转换，用于表达与优化设备网格上的计算。

原书参考版本介绍了 3 个基础操作，分别为 `mesh`、`sharding` 与 `shard`，它们是理解该版本 `mesh` 方言的基石：

- `mesh`：描述一个设备或进程网格。

<!-- source: insider-compiler-ch14-end.pdf, PDF p. 51 -->

- `sharding`：用于定义张量的分片规则。
- `shard`：用于标注张量在网格上的分片方式。

> **版本校订：**本地 LLVM 18 的对应表示是：`mesh.cluster` 操作定义网格；`MeshShardingAttr`（文本形式为 `#mesh.shard<...>`）表示分片规则；`mesh.shard` 操作标注张量。因此，本地不能把上述三者照搬成 `mesh.mesh`、`mesh.sharding`、`mesh.shard` 三个操作；尤其要区分 `#mesh.shard` 属性与 `mesh.shard` 操作。

`mesh` 方言还提供了诸多通信操作，如 `all_reduce`（在选定网格轴形成的通信组内归约，并使组内参与者获得结果）、`all_gather`、`all_slice`、`all_to_all`、`broadcast`、`gather`、`reduce`、`reduce_scatter`、`scatter`、`recv`、`send` 等操作。除此之外，`mesh` 方言也提供用于查询网格或分片相关信息的辅助操作。

这里保留了原书完整的通信操作名单；其中 `all_slice` 在本地 LLVM 18 中尚不存在。`all_reduce` 的通信范围也不必是整个设备网格，不能把原文的“全局归约并同步分发”理解为任何情况下都要求整个网格参与一次全局屏障。

### （1）接口

`mesh` 方言提供了一组接口，主要用于操作查询与信息提取，以便使用 `mesh` 方言。原书列出了以下接口方法：

- `getLoopIteratorTypes`：返回操作在可迭代维度上的迭代类型，结果类型为 `SmallVector<mesh::IteratorType>`。
- `getReductionLoopIteratorKinds`：获取操作在归约维度上的归约类型，如 `ReductionKind::Sum`、`ReductionKind::Max` 等。这个单独的方法不在本地 LLVM 18 的 `ShardingInterface` 中；本地 `IteratorType` 枚举直接区分 `ReductionSum`、`ReductionMax`、`ReductionMin` 等归约迭代类型。
- `getIndexingMaps`：定义**迭代空间到操作数、结果索引空间**的映射关系，返回类型为 `SmallVector<AffineMap>`。数组长度等于操作数与结果的总数；本地接口验证要求这些值均为有秩张量。每个 `AffineMap` 的输入对应 `getLoopIteratorTypes` 所描述的迭代维度，结果对应该张量的索引维度。原文后半句把映射方向写反，此处已改正。
- `getShardingOption`：某些操作的操作数和返回值可能已带有分片注解，此方法利用这些信息推断操作应当如何进行分片。
- `getShardingAnnotations`：通过操作的分片选项和索引映射，为每个操作数和结果生成分片注解。这是原书所述较新接口的方法，本地 LLVM 18 的 `ShardingInterface` 中没有此方法。
- `addShardingAnnotations`：基于给定的分片选项，为尚未标注分片注解的操作数和返回值添加 `mesh.shard` 操作。
- `spmdize`：将操作转换为 SPMD 并行形式，主要步骤包括提取分片信息、转换分片计算、插入通信操作以及生成分片结果。这同样是原书所述较新接口的方法，本地 LLVM 18 的 `ShardingInterface` 中没有此方法。

因此，原书上述 7 项中，本地 `ShardingInterface` 实际声明的是 `getLoopIteratorTypes`、`getIndexingMaps`、`getShardingOption`、`addShardingAnnotations` 4 个方法。较新接口的名称和功能予以保留，编写本地扩展时应以这 4 个方法及其实际签名为准。

### （2）优化

原书介绍了两个转换 Pass，具体如下。

- **`sharding-propagation`**：该转换旨在在计算图中传播分片信息。输入代码已有部分分片标注时，转换可以根据操作的分片接口推导缺失信息，并为相应操作的操作数和结果补充 `mesh.shard` 标注。本地 LLVM 18 提供此 Pass，但其实现要求函数体只有一个基本块，处理范围还受到操作接口和可推导信息的约束。因此，不能笼统保证任意计算图中的每个操作最终都会得到完整标注；没有分片信息时，本地实现可以保持操作不变，并不总是报错。
- **`mesh-spmdization`**：原书所述转换用于把 `func` 方言中的函数操作转换为可并行执行的 SPMD 形式。它要求输入操作完全标注，因此可以在 `sharding-propagation` 完成标注之后运行；关键条件是标注完整，而不是必须在 Pass 管线中紧挨着前者。这里所说的完全标注，是指操作所涉及的张量输入、输出以及基本块参数都使用 `mesh.shard` 操作标注。此外，原书要求函数内部的操作实现 `ShardingInterface` 接口，或者其所有张量操作数和结果具有“完全复制”分片。若函数存在多个终止块，那么为函数添加分片信息的开发人员有责任确保所有返回位置的分片情况一致，即各返回路径上对应结果具有相同的分片。

<!-- source: insider-compiler-ch14-end.pdf, PDF p. 52 -->

> **版本校订：**前一段关于多个终止块的说明在原书跨第 51～52 页，此处已连成完整句子。LLVM 18 本地没有正式的 `mesh-spmdization` Pass；本地有 `shardShapedType`、`reshard` 等 SPMD 化辅助函数，以及名为 `test-mesh-resharding-spmdization` 的测试 Pass。它们不等于原书描述的完整函数 SPMD 化管线，以上较新版本的前置条件也没有被当作本地已经实现的功能。

## 7. quant 方言

`quant` 方言提供了一个用于定义和操作量化值的框架。此框架中的 `uniform` 数据类型专门用于表示均匀量化值。该方言还配备了一套操作，用于处理量化值，并表达这些值在原始浮点表示与量化后的较低位宽整数表示之间的转换。

`uniform` 类型在量化过程中构建了两种表示之间的关系：表达值与存储值。前者指原始机器学习模型中采用的浮点表示；后者是量化后用于存储的整数表示。浮点表示本身也具有有限精度，不能把它等同于精确实数。`uniform` 数据类型对这两种表示之间通常有损的往返转换所需的信息进行编码。

`uniform` 类型存在两种变体：**逐张量量化**（原书称“逐层量化”）与逐通道或逐轴量化。在逐张量量化中，一组量化参数统一作用于整个张量；在逐通道量化中，数据类型会编码用作通道的特定张量轴，以及张量内每个通道的量化信息。这里按张量共享参数，并不意味着模型中的整个网络层必然只使用一组量化参数。

本地 LLVM 18 的 `quant` 方言有 3 个操作，与原书列举的数量一致：

- `dcast`：反量化操作，把量化表示转换回相应的表达类型。反量化不能恢复量化时已经损失的信息。
- `qcast`：量化操作，表达从可量化的表达类型到量化类型的转换。
- `scast`：在量化类型与对应的底层存储类型之间进行**双向**转换，维持使用量化值与直接使用存储值的代码之间的类型一致性。它既可以从量化类型转到存储类型，也可以反向转换；它本身不是内存分配操作，也不承担 `qcast`、`dcast` 的数值量化和反量化职责。

`quant` 方言的使用依赖于外部输入的量化要求，或者编译过程中主动进行的量化分析。原书提醒，早期版本与其所参考版本存在显著差异，并将这种演进与谷歌在将 TensorFlow 接入 MLIR 时不断调整方案和实现的应用背景联系起来。使用该方言时，需要格外关注目标版本的实际类型、操作及转换接口。

这些方言通常应用于特殊场景，这里仅对其概念进行简略介绍。若读者欲了解更多详细内容，可参考官方文档。

[^appendix-1]: Juneyoung Lee，[*Undef and Poison: Present and Future*](https://llvm.org/devmtg/2020-09/slides/Lee-UndefPoison.pdf)。原书标注“2025 年 3 月访问”；这里保留原书访问时间，不将其当作本次校订的访问日期。
