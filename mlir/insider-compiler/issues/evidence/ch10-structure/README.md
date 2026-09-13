# 10.1 结构方言独立复核

范围：合订 PDF 第 81–90 页。基准为本地 LLVM 18.1.8，完整提交见 [版本记录](../../source-files.md)。本记录核查源码与两个针对性反例；逐页图像和正文由第 10 章校订者处理。

## Func

- **构造器重载不是不同的调用语义。** [FuncOps.td](/opt/llvm-project/mlir/include/mlir/Dialect/Func/IR/FuncOps.td:58) 的 `FuncOp`、`StringRef`、`StringAttr` 等 builder 最终构造相同的 `callee` 符号引用属性。直接调用由 [CallOp::verifySymbolUses](/opt/llvm-project/mlir/lib/Dialect/Func/IR/FuncOps.cpp:62) 检查符号、参数及结果。不能说用字符串创建调用就基本没有验证。
- **间接调用也验证类型。** [CallIndirectOp](/opt/llvm-project/mlir/include/mlir/Dialect/Func/IR/FuncOps.td:116) 通过两条 `TypesMatchWith` 检查被调用函数类型的输入、结果与调用一致；它接收的是函数类型 SSA 值，不必把它称为物理或虚拟寄存器。`func.constant` 还会验证目标函数是否存在且类型相同，见 [FuncOps.cpp](/opt/llvm-project/mlir/lib/Dialect/Func/IR/FuncOps.cpp:124)。
- **消除重复函数比较的不只是参数、函数体和返回值。** [DuplicateFunctionElimination.cpp](/opt/llvm-project/mlir/lib/Dialect/Func/Transforms/DuplicateFunctionElimination.cpp:51) 还比较 discardable attributes、除符号名外的 properties，并以忽略 location 的方式比较函数体 Region；它不证明两个数学上等价但结构不同的函数相等。
- **两个变换属于 Transform 方言。** 全名为 `transform.apply_conversion_patterns.func.func_to_llvm` 和 `transform.func.cast_and_call`，见 [FuncTransformOps.td](/opt/llvm-project/mlir/include/mlir/Dialect/Func/TransformOps/FuncTransformOps.td:19)。前者收集转换模式并要求 LLVMTypeConverter，不能当成独立执行完整降级的指令；后者只替换输出 uses、不会删除原操作，用户须保证所替换计算与函数调用语义相符，工具不自动证明等价。
- **`func-bufferize` 在本地仍然存在。** [Passes.td](/opt/llvm-project/mlir/include/mlir/Dialect/Func/Transforms/Passes.td:14) 是 ModuleOp pass，必须同步更新函数签名、调用及有关块参数；不能写“本地已删除”，也不能笼统等同于 One-Shot 的整体分析和缓冲区复用策略。原书关于后续版本的删除应作为版本说法，未单独核验后续提交。

## SCF 操作及控制流

- [SCFOps.td](/opt/llvm-project/mlir/include/mlir/Dialect/SCF/IR/SCFOps.td) 中本地有 12 种操作定义；`forall` 终止操作的实际名字是 **`scf.forall.in_parallel`**（624 行）。`scf.reduce` 对各次并行迭代的值进行归约，不是把循环维度降低；其终止操作为 `scf.reduce.return`。
- `scf.for` 是半开区间、正步长循环，有类型和控制流约束，不能与任意 C `for` 写法等同。`scf.forall` 表达并行、多维迭代和共享输出，不是仅把顺序 for 增加维度。
- `scf.yield` 结束并向父结构传值，不是停止整个程序；结构之后的操作仍可执行。`scf.condition` 实际携带 `i1` 条件与转发值，并没有替代布尔类型；条件决定进入 while 的 after 区域还是返回 while 结果。
- **并非所有 SCF 内部都没有多块 CFG。** `scf.execute_region` 的定义明确允许多个基本块，可容纳 CF 分支；不能从方言名推导每个嵌套区域都单块、单回边。CF 分支只能指向同一 Region 的块，不能用一条 `cf.br` 直接跳出嵌套 `scf.if` 去实现外层 break/goto。见 [SCFOps.td](/opt/llvm-project/mlir/include/mlir/Dialect/SCF/IR/SCFOps.td:79) 和 [块后继验证](/opt/llvm-project/mlir/lib/IR/Verifier.cpp)。

## SCF Pass 与 Transform 的实际可用性

本地 [SCF/Transforms/Passes.td](/opt/llvm-project/mlir/include/mlir/Dialect/SCF/Transforms/Passes.td) 定义原书所列前 8 种 Pass 及 `scf-for-to-while`，还保留 `scf-bufferize`。**没有**名为 `scf-forall-to-for`、`scf-forall-to-parallel` 的本地 Pass。`test-scf-parallel-loop-collapsing` 明确是测试包装器：它最多把任意多维源循环归并到三个输出索引组，不是源循环最多只能有三维。

- `scf-for-loop-canonicalization` 是跨方言化简集合，不是把所有 for/forall/parallel 循环范围一律规范化为固定起点。`dim` 折叠必须证明形状保持，见 [LoopCanonicalization.cpp](/opt/llvm-project/mlir/lib/Dialect/SCF/Transforms/LoopCanonicalization.cpp:70)。
- 上界 peeling 划分的是 `(ub - lb)` 可被 step 整除的主范围和尾部，不能把“迭代次数能被步长整除”当成公式；本地也有 peel-front 选项。
- `scf-for-to-while` 定义明确说明区域和循环携带值的转换，没有普遍“while 对 CPU 流水线更友好”的性能保证。
- `scf-for-loop-range-folding` 把 induction variable 的加法、乘法吸收到范围中，并非通常意义的归约变量上下界计算外提。**本地乘法分支确实遗漏非零下界的更新**，见 [LoopRangeFolding.cpp](/opt/llvm-project/mlir/lib/Dialect/SCF/Transforms/LoopRangeFolding.cpp:74)，实测见下文。原书提示实现有缺陷，在这个检出中有实际依据。

本地 [SCFTransformOps.td](/opt/llvm-project/mlir/include/mlir/Dialect/SCF/TransformOps/SCFTransformOps.td) 有 `transform.loop.forall_to_for`、`loop.outline`、`loop.peel`、`loop.pipeline`、`loop.promote_if_one_iteration`、`loop.unroll`、`loop.coalesce`、`scf.take_assumed_branch`、`loop.fuse_sibling`（后八项同样带 `transform.` 前缀），**没有** `transform.loop.forall_to_parallel`、`transform.loop.unroll_and_jam` 这两个操作。

- `forall_to_for` 当前不支持 shared outputs；不能只讨论 mapping 而忽略这条限制。
- `loop.outline` 转发外部使用值为函数参数，实际实现不要求目标一定是 loop（TD 96 行的注释），不能说它会把所有循环自动做函数外提。
- `loop.unroll` 对句柄选择的 scf.for 或 affine.for 按指定 factor 展开，[SCFTransformOps.cpp](/opt/llvm-project/mlir/lib/Dialect/SCF/TransformOps/SCFTransformOps.cpp:306) 不递归地把每个内层循环也独立完全展开。复制外层循环体当然会复制其中嵌套结构，不能把这两件事混为一谈。
- `loop.coalesce` 合并满足条件的完美循环嵌套，由最外层句柄指定；原书担忧性能只能作为调优提醒，不能据此写成算法不合理或必然出错。
- `scf.take_assumed_branch` 信任使用者提供的前提，不插入 assume/assert 来验证前提；前提错误会改变程序语义。
- `loop.fuse_sibling` 本地仅支持 `scf.forall`，要求 bounds 和 mapping 一致，**使用者负责保证两个循环独立**，变换不做完整依赖合法性证明。不能泛化为任意兄弟 for 循环的自动安全融合。
- 原书“直接接入 SCF 就失去循环优化可能”不成立，前面已经列举其多种优化；提升到 Affine 是为了获得仿射约束所支持的进一步优化。

## CF 与转换

`cf.assert` 的本地默认 LLVM 降级会生成条件分支、打印消息的 `puts` 调用及 `abort`，不是直接调用 C 的 `assert` 函数（C assert 通常是宏）。见 [ControlFlowToLLVM.cpp](/opt/llvm-project/mlir/lib/Conversion/ControlFlowToLLVM/ControlFlowToLLVM.cpp:41)。

`cpp` 不是一个本地方言名。本地 C++ 输出设施与 EmitC 有关，但不能凭图中 `cpp` 箭头宣称存在一条通用 `convert-cf-to-emitc` Pass。图示可标为原书的目标方向或版本范围。`builtin.unrealized_conversion_cast` 是部分转换时的桥接操作；`reconcile-unrealized-casts` 只能清理可调和的转换链，不能自行完成缺失的类型和方言降级。

## 两项实际验证

执行 `python3 mlir/insider-compiler/issues/evidence/ch10-structure/run.py`，命令和退出码见 [results.json](results.json)。

1. [错误间接调用](invalid-indirect-call.mlir) 通过通用操作语法刻意传入不匹配的参数类型，实际失败于 `callee input types match argument types`，见 [诊断](invalid-indirect-call.stderr.txt)。这证实不是只有直接符号调用才会验证。
2. [非零下界反例](range-folding.mlir) 原来在 `i = 1,2,3` 时写 `2*i`，即索引 `2,4,6`；[真实优化输出](range-folding.output.mlir) 却变成下界 1、上界 8、步长 2，在 `1,3,5,7` 写入。这是根据实际输出和 scf.for 语义计算的行为差异，没有声称执行了 JIT。工具正常退出只能证明该 Pass 跑完，**不代表它生成的程序语义正确**；本记录保留缺陷，不修改 `/opt/llvm-project`。
