# 第3章精华笔记：元数据、句柄与存储的分工

[原章](../insider-compiler-ch3.md) · [配套读前导读](../guide/ch3.md) · [笔记目录](README.md)

以下机制以本地 LLVM18.1.8 校订正文为准；布局数值只用于理解本次实测，不能当作跨版本 ABI。

## 1. 把“一个类型”拆成四层理解（3.1、3.4.3、3.5）

| 层次 | 例子 | 作用与归属 |
| --- | --- | --- |
| 定义 | TD 的 `Builtin_Integer`、C++ 的 `IntegerType` 类 | 描述参数、接口及行为 |
| 注册元数据 | `AbstractType` | 在 context 中描述一种已注册类型 |
| 参数化存储 | `IntegerTypeStorage` | 保存某一位宽和符号语义，由 context 的唯一化设施管理 |
| 值句柄 | `IntegerType::get(context, 32)` 的返回值 | 轻量引用具体存储，供操作结果等使用 |

`i32` 与 `i64` 是同一参数化类型类的不同实例，不是两个继承 `IntegerType` 的 C++ 子类。普通类型的唯一化键可概括为“类型种类＋参数”；**context 决定唯一化范围**。同一 context 内相同键共享存储，跨 context 不能据此主张相同对象身份。

通用路径为 `IntegerType::get → StorageUserBase → TypeUniquer → StorageUniquer`，常用实例可能提前命中缓存。`TypeUniquer` 是类型侧的辅助入口，真正持有唯一化存储的是 context 内的 `StorageUniquer`。哈希用于定位候选项，参数相等性决定是否复用；不是每次调用 `get()` 都分配。

无参数类型仍有基础存储。`clone`/`cloneWith` 通常也是更换参数后重新取得类型，不保证分配新存储。通常属性使用相似机制，但 `DistinctAttr` 具有专门的身份语义；具备受控可变状态的类型也必须保持唯一化键不变，不能随意修改所有类型对象。

## 2. TableGen 生成的是哪些部分（3.1.1、3.3.1）

TD 定义先展开为记录，再由指定生成器生成 C++ 声明、定义、注册辅助或文档。记录的匿名编号与输入有关，不是稳定接口；生成文件名由构建规则决定。

| 字段或机制 | 产生的效果 | 仍须提供的内容 |
| --- | --- | --- |
| `parameters`、`builders` | 类型构造接口及参数处理 | 非默认的构造策略与存储实现 |
| `genStorageClass=0` | 不自动生成存储类 | 具体存储类、键及相关操作 |
| `genVerifyDecl` / `hasVerifier` | 声明相应验证钩子 | 类型参数或操作语义的验证实现 |
| `hasFolder` | 提供 `fold` 声明 | 折叠逻辑 |
| `hasCanonicalizer` | 提供模式收集声明 | 规范化模式 |
| `assemblyFormat` | 按声明生成解析与打印逻辑 | 该格式所依赖的语义约束 |

“生成了声明”不能读成“业务逻辑已经自动实现”。普通操作构造也不保证立即完成全部 verifier 检查。

## 3. Attribute 与 properties 是两个维度（3.2）

`IntegerType` 表达位宽和符号语义；`IntegerAttr` 表达某种类型下的具体整数值。对操作而言，**固有属性**由操作自身语义定义，例如 `arith.cmpi` 的比较谓词；**可丢弃属性**的语义来自其他机制或方言，但仍需兼容操作语义。

Properties 是具体操作拥有的专属存储机制，可以承载固有属性及其他操作数据，并不是 `Attribute` 的子类。采用该机制后，固有数据可从顶层属性字典迁往 properties；其中的 Attribute 句柄仍可指向 context 中的共享存储。属性的语义分类与存储位置必须分开理解，不能按“常用/不常用”区分固有与可丢弃。

## 4. 创建操作分成准备、分配、包装（3.3.1～3.3.2）

1. `OpBuilder::create<OpTy>` 准备 `OperationState`，记录位置、操作名称等。
2. `OpTy::build` 向已有 state 填入操作数、结果类型、属性等，返回 `void`，此时尚未创建底层 Operation。
3. `Operation::create` 依据数量与对齐计算空间，构造本体、结果、区域及操作数等存储；builder 再按插入点组织 IR。
4. 用具体操作句柄包装 `Operation*`，向调用者提供有类型的访问 API。

`AddIOp` 经 `OpState` 保存 `Operation*`，并不继承 `Operation`。`dyn_cast<AddIOp>(op)` 通过 MLIR 定制的 `CastInfo`、`classof` 等进行检查，返回 `AddIOp` 值句柄或空句柄；它既不返回 `AddIOp*`，也不复制底层操作。这与标准 C++ RTTI 向下转换不是同一实现，也与改变 IR 值类型的方言转换不是一回事。

相同参数多次 `create()` 通常得到不同的操作实例。注册的是操作种类的元数据，实例则由 IR 的包含关系管理，例如块拥有块内操作；不能把方言想成保存全部操作实例的容器。

## 5. Operation 的总分配量不等于 sizeof（3.3.2）

创建时的一次主要分配可以分为：**前置结果对象区、固定 Operation 本体、对齐后的尾部对象区**。因此 `Operation*` 指向本体，未必是整块分配的起点。`TrailingObjects` 计算尾部空间与地址，不会运行时改变 C++ 成员声明。

| 存储段 | 本地实现要点 |
| --- | --- |
| 结果对象 | 前6个用 `InlineOpResult`，更多结果用 `OutOfLineOpResult`；不是结果指针数组 |
| Operation 本体 | 保存位置、名称、计数、`orderIndex` 等；本机实测64字节 |
| `OperandStorage` | 创建时可为0或1个，管理操作数存储 |
| `OpProperties` | 是字节单位的占位类型，数量按所需字节数向8对齐计算 |
| `BlockOperand`、`Region`、`OpOperand` | 分别保存后继引用、区域与操作数对象；数量按实际需求确定 |

本机两类结果对象分别为16、24字节。六个内联结果来自执行源码；头文件概述中的“五个”是过时注释。字节尺寸受平台和版本影响，值得记住的是组织方式以及结果、后继、区域三类数量并不相同。

## 6. 注册、加载、扩展不是同一步（3.4～3.5）

`DialectRegistry::insert` 登记名称、类型标识与构造器，使方言可被加载；`MLIRContext::getOrLoadDialect` 首次加载时构造并初始化方言，之后复用该 context 的实例。`initialize()` 中的 `addTypes`、`addAttributes`、`addOperations` 把构件元数据注册到上下文，而参数化存储按请求取得。

方言扩展在所需方言均已加载等条件满足时应用，可以附加接口。普通扩展不等于任意动态定义能力；动态操作还需要对应方言基础设施。方言自身依赖和独立转换 Pass 的依赖也应分别声明。

两个常见边界：`builtin.module` 的 Graph 区域仍有 SSA 值，只是不要求 SSACFG 的文本支配顺序；`builtin.unrealized_conversion_cast` 暂时衔接类型表示，没有真正运行时转换语义，后续仍须按目标要求处理。

读本章源码时，先判断当前看到的是“定义信息、共享值还是可变 IR 实例”，多数生命周期和接口疑问便有了明确的检查方向。
