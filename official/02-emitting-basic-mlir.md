# 第 2 章：生成基础 MLIR

本地原文：[Ch-2.md](/opt/llvm-project/mlir/docs/Tutorials/Toy/Ch-2.md) · [本章源码](/opt/llvm-project/mlir/examples/toy/Ch2/toyc.cpp)

基准：`release/18.x` / `3b5b5c1ec4a3`。正文按官方主线译编；原文与实现不一致处，以本地代码校正并说明。C++、TableGen 与 MLIR 代码块分别标为“逐字源码”“译编”或“示意”；只有带源码锚点的逐字摘录参与逐行核对，完整实现见源码链接。

## 1. 为什么需要多层中间表示

LLVM IR 提供固定的低层类型与指令。传统前端通常先在 AST 上完成语言相关检查和变换，再一次性降到 LLVM IR。对张量语言而言，高层概念与低层指令相距很远，多个前端会重复实现类似的基础设施。

MLIR 的核心选择是“可扩展”：操作、类型、属性并非封闭集合。不同抽象层可以由不同方言表示，并逐步降级。Toy 因此不必在离开 AST 后立即丢掉 `transpose`、形状等语义。

## 2. MLIR 操作的组成

> 代码性质：示意（非逐字源码，未编译或运行验证）。

```mlir
%t = "toy.transpose"(%tensor) {inplace = true}
    : (tensor<2x3xf64>) -> tensor<3x2xf64>
    loc("example.toy":12:1)
```

逐项解释：

- `%t`：操作产生的 SSA 结果。文本名称仅帮助阅读，内存中的值不依赖它；
- `"toy.transpose"`：完整操作名，点号前是方言命名空间；
- `(%tensor)`：输入操作数，来自其他操作结果或块参数；
- `{inplace = true}`：用于演示通用语法的常量属性字典；本地 Toy TransposeOp 没有据此实现原地转置，这不是可启用的优化开关；
- 函数式类型：先写输入类型，再写结果类型；
- `loc(...)`：源位置。MLIR 要求每个操作都有位置，即使它是 `unknown`。

一般的 MLIR 操作还可以拥有零个或多个后继块与 Region。函数、模块和控制流也统一建模为操作。

## 3. 未注册操作与不透明 API

MLIR 即使不了解 Toy 方言，也能解析、保存并重新打印通用形式的 `"toy.*"` 操作。这使新方言很容易启动。但未注册操作对系统几乎是黑盒，验证器不知道它应有几个参数、结果或副作用，优化也只能保守处理。

例如下面的 IR 对 Toy 明显无效，却可能在未注册方言时通过结构性解析：

> 代码性质：示意（非逐字源码，未编译或运行验证）。

```mlir
func.func @main() {
  %0 = "toy.print"() : () -> tensor<2x3xf64>
}
```

问题包括：`print` 没有输入、错误地产生了结果，而且函数缺少终结操作。这个原文例子还混入了结构性错误，不能据此保证未知方言模式一定通过验证；研究不透明操作时应添加合法 `func.return`，把结构错误和 Toy 语义错误分开。成熟实现应注册方言和操作，使验证、构造和变换获得语义信息。

## 4. 定义 Toy 方言

方言是具有唯一命名空间的一组操作、类型、属性与接口。Toy 方言可用 C++ 定义，也可用 TableGen 声明。教程采用 ODS（Operation Definition Specification）减少样板代码：

> 代码性质：译编（含中文改写，非逐字源码；未编译或运行验证）。

```tablegen
def Toy_Dialect : Dialect {
  let name = "toy";
  let cppNamespace = "::mlir::toy";
  let summary = "用于分析和优化 Toy 语言的高层方言";
}
```

生成的方言类在 `initialize()` 中注册操作、类型与接口。使用前还要将它装入 `MLIRContext`：

> 代码性质：示意（非逐字源码，未编译或运行验证）。

```c++
context.getOrLoadDialect<mlir::toy::ToyDialect>();
```

## 5. 定义 Toy 操作

以 `toy.constant` 为例：它没有输入，拥有名为 `value` 的稠密元素属性，通常产生有秩张量结果。ODS 实际允许 `F64Tensor`，包括无秩结果；`verify()` 只在结果有秩时检查它与属性形状一致。

> 代码性质：示意（非逐字源码，未编译或运行验证）。

```mlir
%c = "toy.constant"() {
  value = dense<1.0> : tensor<2x3xf64>
} : () -> tensor<2x3xf64>
```

### 5.1 `Operation` 与 `Op`

`mlir::Operation` 是通用、无类型的底层容器；`toy::ConstantOp` 这类 `Op` 是轻量、值语义的类型化包装器，提供生成的访问器、构造器与验证逻辑。常见用法：

> 代码性质：示意（非逐字源码，未编译或运行验证）。

```c++
Operation *raw = ...;
if (auto constant = dyn_cast<toy::ConstantOp>(raw)) {
  DenseElementsAttr value = constant.getValue();
}
```

### 5.2 用 ODS 声明操作

下方是用于说明属性、结果和 verifier 的简化定义。实际 Ch2 的结果没有 `$output` 名字，使用 `hasCustomAssemblyFormat = 1`；完整定义见 [Ops.td](/opt/llvm-project/mlir/examples/toy/Ch2/include/toy/Ops.td)。

> 代码性质：示意（非逐字源码，未编译或运行验证）。

```tablegen
def ConstantOp : Toy_Op<"constant", [Pure]> {
  let summary = "constant operation";
  let arguments = (ins F64ElementsAttr:$value);
  let results = (outs F64Tensor:$output);
  let hasVerifier = 1;
}
```

ODS 可以声明：

- 操作数、结果、属性及其类型约束；
- `Pure`、`Terminator` 等 Trait；
- 自动生成的文档；
- 自定义 verifier、builder、parser/printer；
- 自定义汇编格式。

生成声明的命令形式为：

```bash
${TOY_BUILD}/bin/mlir-tblgen -gen-op-decls \
  /opt/llvm-project/mlir/examples/toy/Ch2/include/toy/Ops.td \
  -I /opt/llvm-project/mlir/include
```

CMake 通常会自动执行 TableGen，手动命令主要用于理解和调试。

### 5.3 参数、结果和验证

约束能自动生成基本验证；语义关系仍需自定义 verifier。例如常量的 `value` 形状必须与结果张量形状一致。验证失败时应在对应操作或位置发出诊断。

> 代码性质：逐字源码（按所引路径与起始行核对；不等于独立可编译）。

[源码：Ch2/mlir/Dialect.cpp](/opt/llvm-project/mlir/examples/toy/Ch2/mlir/Dialect.cpp:145)

```c++
mlir::LogicalResult ConstantOp::verify() {
  // If the return type of the constant is not an unranked tensor, the shape
  // must match the shape of the attribute holding the data.
  auto resultType = llvm::dyn_cast<mlir::RankedTensorType>(getResult().getType());
  if (!resultType)
    return success();

  // Check that the rank of the attribute type matches the rank of the constant
  // result type.
  auto attrType = llvm::cast<mlir::RankedTensorType>(getValue().getType());
  if (attrType.getRank() != resultType.getRank()) {
    return emitOpError("return type must match the one of the attached value "
                       "attribute: ")
           << attrType.getRank() << " != " << resultType.getRank();
  }

  // Check that each of the dimensions match between the two types.
  for (int dim = 0, dimE = attrType.getRank(); dim < dimE; ++dim) {
    if (attrType.getShape()[dim] != resultType.getShape()[dim]) {
      return emitOpError(
                 "return type shape mismatches its attribute at dimension ")
             << dim << ": " << attrType.getShape()[dim]
             << " != " << resultType.getShape()[dim];
    }
  }
  return mlir::success();
}
```

本实现允许 unranked 结果。ODS 验证元素类型等基本约束，`verify()` 再逐维比较有秩结果和属性类型；二者共同定义合法性，而不是只靠一段自定义检查。

### 5.4 Builder

Builder 把创建操作所需的 `OperationState` 封装成易用接口。本地常量 builder 支持显式结果类型、从 `DenseElementsAttr` 推导类型、从 `double` 构造零秩 `tensor<f64>`。最后一种没有自动广播到任意形状。

> 代码性质：逐字源码（按所引路径与起始行核对；不等于独立可编译）。

[源码：Ch2/mlir/Dialect.cpp](/opt/llvm-project/mlir/examples/toy/Ch2/mlir/Dialect.cpp:110)

```c++
void ConstantOp::build(mlir::OpBuilder &builder, mlir::OperationState &state,
                       double value) {
  auto dataType = RankedTensorType::get({}, builder.getF64Type());
  auto dataAttribute = DenseElementsAttr::get(dataType, value);
  ConstantOp::build(builder, state, dataType, dataAttribute);
}
```

这里的空维度列表 `{}` 构造 **零秩** `RankedTensorType`；这是 `tensor<f64>`，与“秩未知”的 `tensor<*xf64>` 不同。

### 5.5 自定义汇编格式

通用形式对调试可靠但冗长。ODS 的 `assemblyFormat` 或手写 parser/printer 可给注册操作定义紧凑形式。下例的 ConstantOp 在本地使用手写形式：

> 代码性质：示意（非逐字源码，未编译或运行验证）。

```mlir
%c = toy.constant dense<[1.0, 2.0]> : tensor<2xf64>
```

只要 parser 与 printer 对称，紧凑形式与通用形式都能 round-trip。

本地常量采用手写 parser/printer：

> 代码性质：逐字源码（按所引路径与起始行核对；不等于独立可编译）。

[源码：Ch2/mlir/Dialect.cpp](/opt/llvm-project/mlir/examples/toy/Ch2/mlir/Dialect.cpp:124)

```c++
mlir::ParseResult ConstantOp::parse(mlir::OpAsmParser &parser,
                                    mlir::OperationState &result) {
  mlir::DenseElementsAttr value;
  if (parser.parseOptionalAttrDict(result.attributes) ||
      parser.parseAttribute(value, "value", result.attributes))
    return failure();

  result.addTypes(value.getType());
  return success();
}
```

> 代码性质：逐字源码（按所引路径与起始行核对；不等于独立可编译）。

[源码：Ch2/mlir/Dialect.cpp](/opt/llvm-project/mlir/examples/toy/Ch2/mlir/Dialect.cpp:137)

```c++
void ConstantOp::print(mlir::OpAsmPrinter &printer) {
  printer << " ";
  printer.printOptionalAttrDict((*this)->getAttrs(), /*elidedAttrs=*/{"value"});
  printer << getValue();
}
```

parser 从带类型的属性获得结果类型，printer 打印属性时自然带出类型，且从可选字典中排除 `value` 避免重复。`ParseResult` 在布尔上下文中 **true 表示失败**，所以多个 `parse*` 调用用 `||` 短路连接。

`toy.print` 则使用声明格式：`` $input attr-dict `:` type($input) ``。变量 `$input` 对应 ODS 命名操作数；`attr-dict`、`type` 是指令；反引号内的冒号是字面标点。原文先演示手写 print parser，再收敛到这个声明式实现；本地代码采用后者。

### 5.6 生成文件如何接到 C++

[include/toy/CMakeLists.txt](/opt/llvm-project/mlir/examples/toy/Ch2/include/toy/CMakeLists.txt) 从同一 `Ops.td` 生成 `Ops.h.inc`、`Ops.cpp.inc`、`Dialect.h.inc`、`Dialect.cpp.inc`。`Dialect.h` 在 `GET_OP_CLASSES` 控制下包含类声明；`Dialect.cpp` 用 `GET_OP_LIST` 展开注册列表，再包含生成的方法定义。构建目录中的 `.inc` 是产物，修改源定义应编辑 `.td`。

手写继承 `mlir::Op<ConcreteOp, Traits...>` 也能定义操作：第一个模板参数是自身，这是 CRTP；Trait 可注入操作数数量检查和访问器。ODS 把相同信息生成成 C++，无需为每个操作手写重复框架。`Operation*` 和类型化 `Op` 指向同一底层操作；拷贝 Op 包装器不会克隆 IR。

### 5.7 ODS 基类、文档与 builder 的连接

原文还展示了所有 Toy 操作共用的 TableGen 基类。本地定义是：

> 代码性质：逐字源码（按所引路径与起始行核对；不等于独立可编译）。

[源码：Ch2/include/toy/Ops.td](/opt/llvm-project/mlir/examples/toy/Ch2/include/toy/Ops.td:33)

```tablegen
class Toy_Op<string mnemonic, list<Trait> traits = []> :
    Op<Toy_Dialect, mnemonic, traits>;
```

`Toy_Op<"constant", [Pure]>` 把方言、助记名和 traits 传给通用 `Op`。这与 C++ 的 CRTP 基类不是同一个语法层：前者由 TableGen 处理，后者是生成/手写 C++ 类的实现机制。

ODS 的 `summary` 是简短摘要，`description` 是可包含 Markdown 的完整语义说明。它们能生成方言文档，但**说明文字不会变成 verifier**。例如“输入形状应相同”若只写在 description 中，并不自动产生比较两输入 shape 的代码；必须由类型约束、trait 或手写 verifier 实施。

下面是围绕 ConstantOp 文档字段的中文译编示例，不替换实际 Ops.td 定义：

> 代码性质：译编（含中文改写，非逐字源码；未编译或运行验证）。

```tablegen
let summary = "常量操作";
let description = [{
  将字面量转换为 SSA 值；数据保存在 value 属性中。
}];
```

本地 ConstantOp 的自定义 builders 列表如下：

> 代码性质：逐字源码（按所引路径与起始行核对；不等于独立可编译）。

[源码：Ch2/include/toy/Ops.td](/opt/llvm-project/mlir/examples/toy/Ch2/include/toy/Ops.td:74)

```tablegen
  let builders = [
    // Build a constant with a given constant tensor value.
    OpBuilder<(ins "DenseElementsAttr":$value), [{
      build($_builder, $_state, value.getType(), value);
    }]>,

    // Build a constant with a given constant floating-point value.
    OpBuilder<(ins "double":$value)>
  ];
```

第一个 builder 的函数体直接在 ODS 中定义，复用属性的 Type；第二个只声明 double 重载，由前面的 Dialect.cpp 摘录实现。两者都是向 OperationState 填入信息，不是“调用 builder 就自动验证任意 IR”。自动约束检查与 `hasVerifier = 1` 对应的手写检查仍是另一条职责。

除了前面的 `-gen-op-decls`，可以只打印生成结果来理解各层产物：

```bash
"${TOY_BUILD}/bin/mlir-tblgen" -gen-dialect-decls /opt/llvm-project/mlir/examples/toy/Ch2/include/toy/Ops.td -I /opt/llvm-project/mlir/include
"${TOY_BUILD}/bin/mlir-tblgen" -gen-op-defs /opt/llvm-project/mlir/examples/toy/Ch2/include/toy/Ops.td -I /opt/llvm-project/mlir/include
"${TOY_BUILD}/bin/mlir-tblgen" -gen-op-doc /opt/llvm-project/mlir/examples/toy/Ch2/include/toy/Ops.td -I /opt/llvm-project/mlir/include
```

三者分别生成方言声明、操作实现和操作文档。生产构建仍由 CMake 管理依赖，不能因为这些命令能输出 C++ 就跳过生成头文件与链接步骤。

原文手写 ConstantOp 全类和手写 PrintOp parser/printer 是逐步引入 ODS 的教学替代方案；本地分别采用 ODS 生成类和 Print 的声明式格式。本文保留职责解释与实际实现，不把原文的历史替代类/旧访问器当作当前源码再复制一遍。若需逐段对照，参阅 [Ch-2.md](/opt/llvm-project/mlir/docs/Tutorials/Toy/Ch-2.md)。

## 6. 从 AST 生成完整 Toy IR

MLIR 生成器递归访问 AST：

- Module AST → `module`；
- Function AST → `toy.func` 与 Region；
- 函数参数 → Block arguments；
- 字面量 → `toy.constant`；
- 变量引用 → 符号表中保存的 `Value`；
- 二元乘法 → `toy.mul`；
- 内建调用 → `toy.transpose`、`toy.print`；
- 用户调用 → `toy.generic_call`；
- 返回 → `toy.return`。

以下是便于观察的示意 IR。注意第 2 章真正的 `TransposeOp::build` 总是先给结果 `tensor<*xf64>`，此时还没有第 4 章的形状推断：

> 代码性质：示意（非逐字源码，未编译或运行验证）。

```mlir
module {
  toy.func @main() {
    %0 = toy.constant dense<[[1.0, 2.0], [3.0, 4.0]]>
         : tensor<2x2xf64>
    %1 = toy.transpose(%0 : tensor<2x2xf64>) to tensor<*xf64>
    toy.print %1 : tensor<*xf64>
    toy.return
  }
}
```

运行示例：

```bash
${TOY_BUILD}/bin/toyc-ch2 /opt/llvm-project/mlir/test/Examples/Toy/Ch2/codegen.toy -emit=mlir
```

本章建立了第一层 IR：它比 AST 统一，又仍保留 Toy 的高层含义。下一章利用这些语义做局部优化。

## 7. 生成器的具体行为与 round-trip

[MLIRGen.cpp](/opt/llvm-project/mlir/examples/toy/Ch2/mlir/MLIRGen.cpp) 用 `ScopedHashTable<StringRef, Value>` 维护局部变量，函数入口参数直接映射到 entry block arguments。变量引用复用已存在 Value，不生成一次内存 load；显式形状的变量声明总会插入 `ReshapeOp`，即使两边形状相同，也交给后续规范化去除。

张量字面量经 `collectData()` 展平成 `std::vector<double>`，再配上 `RankedTensorType` 构造 `DenseElementsAttr`。`+` 与 `*` 分别生成 AddOp 和 MulOp，都是逐元素运算。GenericCallOp 用 `FlatSymbolRefAttr` 存 callee，初始结果无秩；返回表达式会使函数签名带一个无秩张量结果，没有显式 return 则补 `toy.return`。

最终调用 `mlir::verify(theModule)`。本地生成器仍有教学实现中的错误传播缺口，例如 Ch2 的模块循环未逐个检查 `mlirGen(f)` 返回值，语句列表的 print 失败分支返回 success。应把这些看成源码审读练习，不能据注释声称所有错误路径都已完善。

```bash
${TOY_BUILD}/bin/toyc-ch2 /opt/llvm-project/mlir/test/Examples/Toy/Ch2/codegen.toy -emit=mlir -mlir-print-debuginfo 2> codegen.mlir
${TOY_BUILD}/bin/toyc-ch2 codegen.mlir -emit=mlir 2> roundtrip.mlir
```

本地 [invalid.mlir](/opt/llvm-project/mlir/test/Examples/Toy/Ch2/invalid.mlir) 给出 verifier 的负例。用测试中的 RUN 行和 CHECK 断言理解失败契约，比仅凭“支持某操作”的描述更准确。
