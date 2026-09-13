# 附录笔记：七类补充语义及其接口边界

[笔记目录](README.md) · [附录正文](../insider-compiler-appendix.md) · [读前导读](../guide/appendix.md)

本地实现基准为 LLVM/MLIR18.1.8。附录的共同主题是：给程序补充足够明确的布局、数值、并行或领域语义，供后续分析和转换使用。

## 七个方言的职责

| 方言 | 主要描述对象 | 应保留的区别 |
| --- | --- | --- |
| `dlti` | 布局条目与布局说明属性 | 描述信息与消费这些信息的优化是两件事 |
| `ptr` | 原书较新版本的指针类型和布局属性 | 本地18没有该方言；本地可使用 LLVM 指针与 DLTI |
| `ub` | 毒值及延迟未定义行为语义 | 产生毒值、传播毒值、触发 UB 的使用不同 |
| `polynomial` | 多项式及商环上的计算 | 模多项式同余不等于原多项式相等；本地18无此方言 |
| `async` | 异步执行、依赖和结果可用性 | 语义不固定所有后端的调度实现 |
| `mesh` | 设备网格、张量分片及通信 | 分片标注、标注传播、实际 SPMD 转换不同 |
| `quant` | 数值与低位宽存储之间的映射 | 数值转换与底层存储类型转换不同 |

## DLTI：把布局写成可查询的属性（第1～2节）

本地 `DataLayoutEntryAttr` 表达布局键值条目，`DataLayoutSpecAttr` 聚合这些条目。附录清单 A-1 的指针布局为：

```mlir
#dlti.dl_entry<!llvm.ptr, dense<64> : vector<4xi64>>
```

这是一条属性片段。四个位置依次是指针大小、ABI 对齐、推荐对齐和索引位宽，均写为64，单位为位。`!llvm.ptr` 是默认地址空间的不透明指针类型；条目没有给出所指元素类型。栈对齐 `128 : i64` 表示128位。

布局属性常附着在 `builtin.module`，实现相应接口的其他操作也能提供布局作用域。实际查询 ABI／推荐对齐的接口返回字节，与属性中的位单位要区分。`MapAttr`、`TargetDeviceSpecAttr`、`TargetSystemSpecAttr` 属于正文介绍的较新能力，不是本地18的三个额外已注册属性。

## UB、Polynomial、Async：先辨认语义层次（第3～5节）

`ub.poison` 产生毒值。仅执行这一产生操作并不等于立即发生 UB，必须结合后续操作对毒值的传播和使用规则判断。通用优化若移动或删除相关操作，应同时满足该操作的数值与执行语义，不能把“有一个结果值”理解成可以任意重排。

固定同一系数环和模多项式 $f$ 时，多项式同余可记为：

$$p\equiv q\pmod f\quad\Longleftrightarrow\quad p-q\in(f).$$

这里 $(f)$ 是由 $f$ 生成的理想；例如 $x$ 与 $x+f$ 在商环中表示同一元素，但原多项式一般不同。这是理解相应方言数值语义的背景，不表示本地已有 Polynomial 降级实现。

Async 的执行和等待围绕依赖与完成状态组织；本地类型、操作入口可从 `async.execute`、`async.await` 及其结果类型开始阅读。本地提供的 Async Runtime 使用线程池调度；线程池属于这一运行时的实现，方言本身没有要求每种目标都采用线程池。

## Mesh：从张量索引关系推导设备分片（第6节）

本地有三种容易混写的表示：

| 本地表示 | 身份 | 用途 |
| --- | --- | --- |
| `mesh.cluster` | 操作 | 定义设备网格 |
| `#mesh.shard<...>` | `MeshShardingAttr` 属性 | 表示分片规则 |
| `mesh.shard` | 操作 | 给张量添加分片标注 |

`ShardingInterface` 在本地声明四个方法：

1. `getLoopIteratorTypes` 描述迭代维种类，本地枚举也包含不同归约类型。
2. `getIndexingMaps` 给出**迭代空间 → 各操作数和结果索引空间**的映射；映射数等于操作数与结果数之和，本地要求这些值为有秩张量。
3. `getShardingOption` 利用已有标注推导分片选项。
4. `addShardingAnnotations` 根据选项补充标注。

`sharding-propagation` 在已有信息和接口支持允许时补全分片；本地实现要求函数体只有一个块，完全没有已知信息时可以保持原样。原书较新的 `mesh-spmdization` 要求完整标注，但本地没有同名正式 Pass。已有 `reshard` 等辅助函数不等于完整 SPMD 管线。

`all_reduce` 在选定网格轴组成的通信组内归约并使参与者取得结果。通信组可能是整个网格的一部分；操作的名称本身不能推出全网格屏障。

## Quant：把存储整数解释为数值（第7节）

均匀量化用正尺度 $s$ 和整数零点 $z$ 解释存储整数 $q$。根据本地量化文档，便于记忆的数值关系为：

$$\hat{x}=s(q-z).$$

量化时需要把表达类型的值映射到有限整数范围，通常涉及舍入和饱和；反量化得到的是 $\hat{x}$，不能保证等于量化前的值。具体舍入、溢出处理应以实际转换或执行实现为准。

| 类型或操作 | 保存／执行的内容 |
| --- | --- |
| `UniformQuantizedType` | 整个张量共享 scale、zero point，可查询 `getScale()`、`getZeroPoint()` |
| `UniformQuantizedPerAxisType` | 指定轴及各通道参数，可查询 `getQuantizedDimension()`、`getScales()`、`getZeroPoints()` |
| `quant.qcast` | 从表达类型转换为量化类型，承担数值量化语义 |
| `quant.dcast` | 从量化类型转换回表达类型，承担反量化语义 |
| `quant.scast` | 量化类型与底层存储类型之间的双向类型转换 |

`scast` 本身不负责分配存储，也不能代替 `qcast`／`dcast` 的数值映射。逐张量量化的参数作用域是一个张量，不应自动扩大为整个神经网络层。

## 回到前面章节

第3章解释这些类型、属性和操作怎样被定义与注册；第4章解释接口怎样让外部算法查询语义；第8章提醒前端保留量化约定；第9～11章解释数据表示怎样落实为缓冲区和目标代码。完整代码与版本对应见[附录正文](../insider-compiler-appendix.md)。

补充背景与接口核对入口：[本地量化文档](/opt/llvm-project/mlir/docs/Quantization.md)、[Quant 类型接口](/opt/llvm-project/mlir/include/mlir/Dialect/Quant/QuantTypes.h)、[Async 操作定义](/opt/llvm-project/mlir/include/mlir/Dialect/Async/IR/AsyncOps.td)。这些是源码阅读入口，不是本次新增的运行测试。
