# 循环分块合法性：理论条件与本地漏检

第 14 章 14.5.4 原书把数组下标差当成循环迭代距离，并要求距离向量每个分量“严格为正”。二者都需修正。下文采用 `目标迭代−源迭代` 的距离方向，要求依赖分析覆盖需要保持的真实依赖。

## 合法性条件

原循环按字典序执行时，跨迭代依赖距离必须字典序为正；一个充分的、适用于任意正块大小的矩形分块条件是所有距离分量**非负**。零分量完全允许，例如 `(1,0)`；若只因有零分量就拒绝，会错失合法分块。

这个充分条件不是对每一个具体块大小的必要条件。含负分量的距离也可能在特定域或特定块大小下不被倒置，例如块大小全为 1 时，扫描顺序没有改变。因此须区分便于判定的保守充分条件、具体调度合法性，以及实际实现所检查的条件。

本地 [AffineAnalysis.h](/opt/llvm-project/mlir/include/mlir/Dialect/Affine/Analysis/AffineAnalysis.h:134)明确规定 `lb==ub` 表示固定距离，`lb<ub` 表示距离范围。[AffineAnalysis.cpp](/opt/llvm-project/mlir/lib/Dialect/Affine/Analysis/AffineAnalysis.cpp:432)以目标迭代减源迭代建立距离约束。

## 本地 LLVM 18.1.8 的实现问题

[LoopTiling.cpp:140](/opt/llvm-project/mlir/lib/Dialect/Affine/Transforms/LoopTiling.cpp:140)实际只在 `lb`、`ub` 都存在且 `lb<ub && ub<0` 时拒绝。它与附近“任何负方向都拒绝”的注释并不等价：固定负距离 `lb==ub<0` 会漏过，包含负数而上界非负的区间也不满足此拒绝条件。

这是对本地具体提交的记录，未检查其他版本是否已经修复，也没有修改 LLVM 源码。

## 实际 Pass 与原生执行反例

[输入](tiling-negative-distance.mlir)执行

```text
for i = 1,2,3,4:
  for j = 0,1,2,3:
    A[i,j] = A[i-1,j+1] + 1
```

它存在源 `(1,2)` 到目标 `(2,1)` 的真依赖，距离 `(1,−1)`。本地 `affine-loop-tile` 使用 2×2 分块仍成功产生[四层循环](tiling-negative-distance.after.mlir)，[调试日志](tiling-negative-distance.log)显示确实检查过该 store→load 依赖，却没有拒绝。

原顺序中 `(1,2)` 先执行；分块顺序 `(i_tile,j_tile,i,j)` 中，`(2,1)` 属于第一个 j 块，`(1,2)` 属于第二个 j 块，因此目标先于源执行。

不仅比较顺序，还实际执行了[带全零初始化的完整输入](tiling-negative-distance.runtime.mlir)。分别不运行／运行该分块 Pass，再用本地 MLIR 降为 LLVM 方言；复用第 11 章[LLVM 导出程序](../ch11/translate.cpp)生成 LLVM IR 并运行 verifier，最后由宿主 Clang 编译并原生执行。[C 调用者](tiling-negative-distance.runtime.c)读取计算结果：

| 读取位置 | 原程序 | 分块后 |
| --- | --- | --- |
| `A[2,1]` | 2 | 1 |

全部数组访问均位于分配的 5×5 范围内，所有元素已初始化；此例没有越界或有符号溢出。因此，该值差异证明本例变换不保持语义。[运行记录](tiling-runtime-check.json)保存命令、退出状态和结果。LLVM IR 为 [原始](tiling-original.ll)与[分块后](tiling-transformed.ll)两份。

复现（第 11 章导出工具的构建方式见其 [CMakeLists.txt](../ch11/CMakeLists.txt)）：

```sh
python3 mlir/insider-compiler/issues/evidence/ch14/run-tiling-check.py \
  /private/tmp/insider-ch11-build/ch11-translate
```

宿主 Clang 提示将未指定的目标 triple 替换为本机 arm64，是本次原生执行使用的目标选择；没有使用只支持 BPF 的本地 `llc`。
