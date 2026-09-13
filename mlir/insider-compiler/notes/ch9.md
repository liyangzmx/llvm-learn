# 第 9 章精华笔记：结构化计算、向量与存储的衔接

[校订正文](../insider-compiler-ch9.md) · [读前导读](../guide/ch9.md) · [笔记目录](README.md)

## 1. 四种表示各自保留的信息

| 小节 | 表示 | 核心信息与用途 |
| --- | --- | --- |
| 9.1 | Linalg | 隐式循环、操作数访问映射、迭代类别、标量计算；利于融合、分块、向量化 |
| 9.2 | Affine | 显式循环与可分析的整数边界、访问关系；利于依赖分析和循环变换 |
| 9.3 | Vector | 多维成组计算、排列、收缩、掩码；逐步适配硬件向量能力 |
| 9.4 | Bufferization | tensor 值与 memref 存储的对应、别名及读写；决定复用、分配和复制 |

这些表示可以交错出现。Linalg 可降成循环、向量或库调用；没有唯一固定的四站流水线。操作数减少、IR 行数减少与机器性能提高也不能互相替代。

## 2. 读懂一个 Linalg 操作的四步（9.1.3）

1. 看 `iterator_types`：每个**循环维度**一个类别，本地是 `parallel` 或 `reduction`。
2. 看 `indexing_maps`：每个输入及输出操作数一个映射，从循环索引映到其元素索引。
3. 看标量区域：定义每个迭代点的计算，`linalg.yield` 给出更新值。
4. 看 `outs`：确定结果形状、初值与目标关联，判断区域是否读取旧输出元素。

矩阵乘加的典型映射为：

$$
(i,j,k)\mapsto(i,k),\qquad
(i,j,k)\mapsto(k,j),\qquad
(i,j,k)\mapsto(i,j).
$$

迭代类别为 parallel、parallel、reduction，计算为：

$$
C^{\mathrm{out}}_{ij}=C^{\mathrm{init}}_{ij}+\sum_k A_{ik}B_{kj}.
$$

**DPS 不是零初始化。** 张量语义下，结果关联一个 destination 操作数并产生新 SSA 值；缓冲区语义下，直接更新目标 memref。若标量区域不读旧输出，destination 可只提供形状；若执行累加，旧内容参与结果。纯 matmul 应先填零，最大池化应选合适的归约初值，如浮点负无穷。

转置索引不必先物理复制；广播沿某维重复使用同一输入位置。清单 9-13 的左输入长度必须是归约维度 5，而非输出行数 3。LLVM 18 的命名 matmul 不支持原书那种直接改 `indexing_maps` 的写法，校订正文使用相应命名变体或 `linalg.generic`。

卷积示例采用未翻转卷积核的深度学习惯例，严格数学上对应互相关。池化的 stride 控制窗口移动，dilation 控制窗口内采样间隔；越界不会自动补零，必须显式填充或限制输出范围。

## 3. 融合、分块与向量化不是同一件事（9.1.4）

| 变换 | 实际改变 | 主要审查点 |
| --- | --- | --- |
| 逐元素融合 | 将生产者标量计算嵌入消费者的迭代空间 | 张量语义、映射与迭代合法，其他使用所需结果仍保留 |
| 分块并融合生产者 | 在消费者循环中只计算所需生产者切片 | 切片边界、归约语义、额外重算与存储收益 |
| 分块 | 划分迭代空间，构造局部切片计算 | 尾块、块间独立性、输出拼接及目标资源 |
| 向量化 | 用 transfer、contract、outerproduct 等表达成组计算 | 形状、掩码、布局、累加初值及后续降级支持 |

块起点为 $i$、全长为 $N$、名义块长为 $T$ 时，尾块常用有效长度 $\min(T,N-i)$。固定块片段若没有这种处理，就需要整除及范围前提，不能直接推广到任意动态形状。

清单 9-20 的激进融合示例计算的是 $C+(AB+C)B$，并有指定形状及整除前提；它不等同于一条普通 matmul，也不保证融合后没有重算。清单 9-25 的 `#gpu.block` 只是映射信息，尚未生成并启动 GPU 执行。

分块通常保持局部的 Linalg 计算，方便继续向量化；promotion 还可能为子视图分配临时缓冲并复制数据。减少主存访问要与新增复制、计算和寄存器压力一起衡量。

## 4. Affine 的价值来自受约束的表达（9.2）

普通仿射表达式允许维度、符号和常量的加减、常量乘法，以及正整数常量作为除数的 floordiv、ceildiv、mod。符号乘法或符号作除数属于半仿射扩展，其可分析程度不能自动等同于普通形式。

维度与符号都可由 SSA 值绑定；区别来自使用位置及 Affine 作用域有效性规则，不是“符号才允许动态值”。循环归纳变量通常作为维度，符合不变性、支配等条件的参数可作为符号。“在循环外定义”不是完整的合法性判据。

`affine.for` 是下界包含、上界不包含，步长为正整数常量；多结果下界取 max，上界取 min。`affine_map` 是属性，`affine.apply` 才把映射应用到值并产生 index 结果。

循环并行化需排除相关的循环携带依赖：取两次迭代，加入各自迭代域、可能别名访问的同址条件、至少一次写入及顺序条件，判断是否存在冲突。排除全部相关冲突后才得到相应合法性结论；找到一对互不冲突的迭代没有这种证明力。整数变量不能仅靠实数松弛的可行解判断。

Affine 将执行顺序保存在循环和块语句顺序中，没有另存完整调度树，不等于没有调度。`--lower-affine` 将控制结构交给 scf、索引计算交给 arith、访存交给 memref/vector；分析信息降低后可能更难恢复。

## 5. Vector 是虚拟向量层（9.3）

`vector<2x3x4xf32>` 不承诺占一个寄存器。本地 LLVM 类型转换通常采用数组嵌套一维向量：`[2 x [3 x <4 x float>]]`。外层聚合的动态索引需要额外处理；也可在更高层先改写或展平形状。

`vector<[16]xf32>` 的长度为 $16\times\mathrm{vscale}$。它不是 `tensor<?xf32>` 那种任意动态长度，类型及所用操作、目标降级各有可伸缩维度的限制。

- `transfer_read/write` 连接 tensor 或 memref 与向量，可表达受限制的排列、边界和掩码；普通 vector load/store 不自动提供同等的边界填充能力。
- `in_bounds = true` 是相应维度已在界内的承诺；false 不表示必然越界，而是没有该保证。
- maskedload 的 false 元素来自 pass_thru；maskedstore 的 false 元素不写内存。
- `contract` 按映射和迭代类别收缩并累加；归约维不出现在结果中，但结果不必比所有输入秩低。
- 多维 transfer、contract 等可能先分解，再转 LLVM；一个转换 Pass 不保证覆盖所有 Vector 操作。

## 6. One-Shot 决定复用，接口提供语义（9.4.1～9.4.2）

tensor 更新产生新值；若新值与旧值共享底层缓冲区，后续读取旧值可能被新写入改变，这就是需要检查的缓冲化 RaW 冲突。读取更新后的新值本身并不是冲突。若不能安全原地执行，则新建存储；是否复制旧内容还取决于操作是否读取 destination。

One-Shot 先分析，再按结果改写。它跨方言依赖 `BufferizableOpInterface`：

| 能力 | LLVM 18.1.8 的接口信息 |
| --- | --- |
| 读写判断 | `bufferizesToMemoryRead`、`bufferizesToMemoryWrite` |
| 潜在别名 | `getAliasingValues`、`getAliasingOpOperands` |
| 别名强度 | 条目的 `relation`、`isDefinite`；没有独立 `bufferRelation` 钩子 |
| 实际转换 | `bufferize` |

`Equivalent` 比可能别名更强，涉及相应尺寸、偏移和步长；`Unknown` 不是“不别名”。接口可保守多报潜在别名，不能漏报。函数边界缓冲化需要相应配置，本地模块分析不支持递归调用图。

## 7. 分配之后还有所有权与释放（9.4.2～9.4.3）

**One-Shot 不插入释放。** 默认所有权约定中，函数输入 memref 是借用，返回 memref 把所有权交给调用者，返回分配不能与输入分配别名。私有函数的动态所有权选项可采用额外参数及结果传递信息。

所有权状态 `unique` 表示可用一个 SSA `i1` 表达释放责任，并不是“没有别名”。控制流汇合与别名决定如何生成 `bufferization.dealloc`，后者再降低到实际释放和必要检查。

本地 `buffer-deallocation-pipeline` 的八步依次为：expand-realloc（不在此步释放）→ canonicalize → ownership-based-buffer-deallocation → canonicalize → buffer-deallocation-simplification → bufferization-lower-deallocations → cse → canonicalize。输入不应已有其他显式释放操作，realloc 的专门处理除外。

`bufferization.clone` 的契约允许别名或分配复制；克隆后修改源或结果是未定义行为。不能因为本地一个降级生成 alloc/copy，就给上层程序增加“必然独立可写”的假设。

## 8. 用 9.5 的例子串起来

清单 9-38 先按 `[8, [16], 1]` 分块，步长为 8、$16\times\mathrm{vscale}$、1；在长度 2000 的第二维用 $\min(2000-j,16\times\mathrm{vscale})$ 处理尾块。向量化再生成 `vector<8x[16]x1xf32>` 等值，通过有效尺寸构造 mask，执行乘法与归约并写回切片。

这里已经验证的是 IR 变换。完整的运行还需要缓冲化、所有权处理、目标支持的向量降级、函数边界转换和代码生成；实际调度顺序按目标选择，不能由这份中间结果直接宣称加速比。
