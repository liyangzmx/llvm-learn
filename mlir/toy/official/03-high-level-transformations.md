# 第 3 章：高级语言相关的分析与变换

本地原文：[Ch-3.md](/opt/llvm-project/mlir/docs/Tutorials/Toy/Ch-3.md) · [本章源码](/opt/llvm-project/mlir/examples/toy/Ch3/toyc.cpp)

基准：`release/18.x` / `3b5b5c1ec4a3`。正文按官方主线译编；原文与实现不一致处，以本地代码校正并说明。C++、TableGen 与 MLIR 代码块分别标为“逐字源码”“译编”或“示意”；只有带源码锚点的逐字摘录参与逐行核对，完整实现见源码链接。

与源语言接近的方言，使许多通常只能在 AST 上做的分析和优化也能在统一 IR 框架中完成。本章聚焦局部模式重写：命令式 C++ 模式与声明式 DRR。

## 1. 用 C++ 消除双重转置

目标恒等式：

```text
transpose(transpose(x)) → x
```

对应 IR：

> 代码性质：示意（非逐字源码；完整片段已用 LLVM 18.1.8 解析验证）。

```mlir
toy.func @transpose_transpose(%arg0: tensor<*xf64>) -> tensor<*xf64> {
  %0 = toy.transpose(%arg0 : tensor<*xf64>) to tensor<*xf64>
  %1 = toy.transpose(%0 : tensor<*xf64>) to tensor<*xf64>
  toy.return %1 : tensor<*xf64>
}
```

Toy IR 中的意图是显式的，模式只需检查当前 `TransposeOp` 的输入是否也由 `TransposeOp` 定义：

> 代码性质：示意（非逐字源码，未编译或运行验证）。

```c++
struct SimplifyRedundantTranspose
    : public mlir::OpRewritePattern<toy::TransposeOp> {
  using OpRewritePattern::OpRewritePattern;

  LogicalResult matchAndRewrite(
      toy::TransposeOp op,
      mlir::PatternRewriter &rewriter) const override {
    auto inner = op.getOperand().getDefiningOp<toy::TransposeOp>();
    if (!inner)
      return failure();
    rewriter.replaceOp(op, inner.getOperand());
    return success();
  }
};
```

所有 IR 修改必须经由 `PatternRewriter`，框架据此维护 use-def 链等不变量。模式注册给 `TransposeOp::getCanonicalizationPatterns`，再由 canonicalizer pass 贪心、迭代地应用：

> 代码性质：示意（非逐字源码，未编译或运行验证）。

```c++
void TransposeOp::getCanonicalizationPatterns(
    RewritePatternSet &patterns, MLIRContext *ctx) {
  patterns.add<SimplifyRedundantTranspose>(ctx);
}
```

PassManager 中加入规范化 pass：

> 代码性质：示意（非逐字源码，未编译或运行验证）。

```c++
pm.addNestedPass<toy::FuncOp>(mlir::createCanonicalizerPass());
```

第一次重写后，外层转置消失，内层转置已无用户。要让死代码删除安全地移除它，必须说明 `toy.transpose` 没有副作用：

> 代码性质：示意（非逐字源码，未编译或运行验证）。

```tablegen
def TransposeOp : Toy_Op<"transpose", [Pure]> { /* ... */ }
```

最终函数可简化为直接返回 `%arg0`。这说明副作用建模不仅是文档，也决定了优化是否合法。

## 2. 用 DRR 优化 reshape

DRR（Declarative Rewrite Rules）在 TableGen 中以 DAG 描述源模式、目标模式、约束与收益。嵌套 reshape 可以写成：

> 代码性质：示意（非逐字源码，未编译或运行验证）。

```tablegen
def ReshapeReshapeOptPattern :
  Pat<(ReshapeOp (ReshapeOp $arg)), (ReshapeOp $arg)>;
```

若输入与结果类型相同，reshape 可以直接替换为输入值：

> 代码性质：示意（非逐字源码，未编译或运行验证）。

```tablegen
def TypesAreIdentical :
  Constraint<CPred<"$0.getType() == $1.getType()">>;

def RedundantReshapeOptPattern : Pat<
  (ReshapeOp:$res $arg),
  (replaceWithValue $arg),
  [(TypesAreIdentical $res, $arg)]>;
```

对常量的 reshape 可以在编译期改写常量属性。`NativeCodeCall` 允许 DRR 调用 C++ 辅助逻辑：

> 代码性质：示意（非逐字源码，未编译或运行验证）。

```tablegen
def ReshapeConstant :
  NativeCodeCall<"$0.reshape(::llvm::cast<ShapedType>($1.getType()))">;

def FoldConstantReshapeOptPattern : Pat<
  (ReshapeOp:$res (ConstantOp $arg)),
  (ConstantOp (ReshapeConstant $arg, $res))>;
```

对于：

```toy
def main() {
  var a<2,1> = [1, 2];
  var b<2,1> = a;
  var c<2,1> = b;
  print(c);
}
```

规范化会把连续 reshape 和常量 reshape 折叠为单个目标形状的常量。

## 3. 运行与观察

```bash
${TOY_BUILD}/bin/toyc-ch3 \
  /opt/llvm-project/mlir/test/Examples/Toy/Ch3/transpose_transpose.toy \
  -emit=mlir -opt

${TOY_BUILD}/bin/toyc-ch3 \
  /opt/llvm-project/mlir/test/Examples/Toy/Ch3/trivial_reshape.toy \
  -emit=mlir -opt
```

构建目录中的 `ToyCombine.inc` 展示了 DRR 自动生成的 C++，适合调试规则展开结果。

## 4. 本章结论

- C++ `OpRewritePattern` 适合复杂控制逻辑；
- DRR 适合结构清晰、可声明的 DAG 改写；
- canonicalizer 会重复应用规则并清理可证明无副作用的死操作；
- 高层 IR 保留语义，能让“看似聪明”的优化变成简单可靠的局部规则。

下一章用接口把方言特有知识提供给通用变换，避免每个方言重复实现算法。

## 5. 规则如何真正进入可执行程序

本地 [Ch3/CMakeLists.txt](/opt/llvm-project/mlir/examples/toy/Ch3/CMakeLists.txt) 对 `mlir/ToyCombine.td` 执行 `-gen-rewriters`，生成构建树中的 `ToyCombine.inc`。`ToyCombine.cpp` 在匿名命名空间包含它；随后 `ReshapeOp::getCanonicalizationPatterns()` 把 `ReshapeReshapeOptPattern`、`RedundantReshapeOptPattern`、`FoldConstantReshapeOptPattern` 三个生成类加入集合。定义规则、生成代码、注册规则、运行 pass 四步缺一不可。

实际 DRR 常量重塑表达式为 `$0.reshape(::llvm::cast<ShapedType>($1.getType()))`。`$arg` 在 ConstantOp 模式里绑定的是稠密属性，不是运行时 Tensor Value；目标 ConstantOp builder 依据这个新属性的类型产生目标形状。

Ch3 的 `toyc.cpp` 只在 `-opt` 下建立 PassManager，并只显式加入嵌套在 `mlir::toy::FuncOp` 上的 Canonicalizer。这里没有第 4 章才增加的 Inliner、ShapeInference 或单独 CSE pass。`TransposeOp` 和 `ReshapeOp` 的 `hasCanonicalizer = 1` 生成相应方法声明；`Pure` 则允许无用结果被安全清理。

规范化采用启发式贪心驱动。模式的 benefit 是规则排序用的收益指标，不是运行时间减少比例，也不保证全局最优。双重转置示例的正确性建立在 Toy 不可变值语义上；若某种转置会影响外部可见状态，不能原样套用该规则。

### 本地测试对应的结果

[transpose_transpose.toy](/opt/llvm-project/mlir/test/Examples/Toy/Ch3/transpose_transpose.toy) 检查两个转置被删除并直接返回函数实参；[trivial_reshape.toy](/opt/llvm-project/mlir/test/Examples/Toy/Ch3/trivial_reshape.toy) 检查结果常量已具有 2×1 形状，连续 reshape 消失。SSA 编号可以变化，应按操作和类型关系理解 CHECK，而不是背诵 `%0`。
