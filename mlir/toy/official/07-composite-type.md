# 第 7 章：为 Toy 添加复合类型

本地原文：[Ch-7.md](/opt/llvm-project/mlir/docs/Tutorials/Toy/Ch-7.md) · [本章源码](/opt/llvm-project/mlir/examples/toy/Ch7/toyc.cpp)

基准：`release/18.x` / `3b5b5c1ec4a3`。正文按官方主线译编；原文与实现不一致处，以本地代码校正并说明。C++、TableGen 与 MLIR 代码块分别标为“逐字源码”“译编”或“示意”；只有带源码锚点的逐字摘录参与逐行核对，完整实现见源码链接。

本章为 Toy 增加 `struct`，展示自定义参数化类型的存储、唯一化、ODS 暴露、文本解析/打印、操作支持与常量折叠。

## 1. Toy 源语言中的 struct

```toy
struct Pair {
  var a;
  var b;
}

def multiply_transpose(Pair value) {
  return transpose(value.a) * transpose(value.b);
}

def main() {
  Pair value = {
    [[1, 2, 3], [4, 5, 6]],
    [[1, 2, 3], [4, 5, 6]]
  };
  print(multiply_transpose(value));
}
```

结构体声明包含无初始化器、无形状的字段；字段也可以是先前声明的结构体。用 `{...}` 构造复合值，用 `.` 访问成员。

## 2. MLIR 中的 `StructType`

Toy 的 MLIR 表示不保留源语言结构体名和字段名，只保留按顺序排列的元素类型：

> 代码性质：示意（非逐字源码，未编译或运行验证）。

```mlir
!toy.struct<tensor<*xf64>, tensor<*xf64>>
```

### 2.1 类型存储与唯一化

MLIR `Type` 是轻量值对象，实际参数数据保存在 `TypeStorage` 中，并在同一 `MLIRContext` 内唯一化。参数化类型需定义存储类：

> 代码性质：逐字源码（按所引路径与起始行核对；不等于独立可编译）。

[源码：Ch7/mlir/Dialect.cpp](/opt/llvm-project/mlir/examples/toy/Ch7/mlir/Dialect.cpp:509)

```c++
struct StructTypeStorage : public mlir::TypeStorage {
  /// The `KeyTy` is a required type that provides an interface for the storage
  /// instance. This type will be used when uniquing an instance of the type
  /// storage. For our struct type, we will unique each instance structurally on
  /// the elements that it contains.
  using KeyTy = llvm::ArrayRef<mlir::Type>;

  /// A constructor for the type storage instance.
  StructTypeStorage(llvm::ArrayRef<mlir::Type> elementTypes)
      : elementTypes(elementTypes) {}

  /// Define the comparison function for the key type with the current storage
  /// instance. This is used when constructing a new instance to ensure that we
  /// haven't already uniqued an instance of the given key.
  bool operator==(const KeyTy &key) const { return key == elementTypes; }

  /// Define a hash function for the key type. This is used when uniquing
  /// instances of the storage, see the `StructType::get` method.
  /// Note: This method isn't necessary as both llvm::ArrayRef and mlir::Type
  /// have hash functions available, so we could just omit this entirely.
  static llvm::hash_code hashKey(const KeyTy &key) {
    return llvm::hash_value(key);
  }

  /// Define a construction function for the key type from a set of parameters.
  /// These parameters will be provided when constructing the storage instance
  /// itself.
  /// Note: This method isn't necessary because KeyTy can be directly
  /// constructed with the given parameters.
  static KeyTy getKey(llvm::ArrayRef<mlir::Type> elementTypes) {
    return KeyTy(elementTypes);
  }

  /// Define a construction method for creating a new instance of this storage.
  /// This method takes an instance of a storage allocator, and an instance of a
  /// `KeyTy`. The given allocator must be used for *all* necessary dynamic
  /// allocations used to create the type storage and its internal.
  static StructTypeStorage *construct(mlir::TypeStorageAllocator &allocator,
                                      const KeyTy &key) {
    // Copy the elements from the provided `KeyTy` into the allocator.
    llvm::ArrayRef<mlir::Type> elementTypes = allocator.copyInto(key);

    // Allocate the storage instance and construct it.
    return new (allocator.allocate<StructTypeStorage>())
        StructTypeStorage(elementTypes);
  }

  /// The following field contains the element types of the struct.
  llvm::ArrayRef<mlir::Type> elementTypes;
};
```

`KeyTy` 决定相等性和唯一化键；所有动态数据必须复制到 MLIR 提供的 allocator，不能引用临时容器。

### 2.2 类型类

下方是简化示意，省略了源码的命名空间分层；真实类的存储类型为 `detail::StructTypeStorage`，还声明 `static constexpr StringLiteral name = "toy.struct"`，且 `get()`、`getElementTypes()` 在 `.cpp` 中定义，详见 [Dialect.h](/opt/llvm-project/mlir/examples/toy/Ch7/include/toy/Dialect.h)。

> 代码性质：示意（非逐字源码，未编译或运行验证）。

```c++
class StructType : public Type::TypeBase<
    StructType, Type, StructTypeStorage> {
public:
  using Base::Base;

  static StructType get(ArrayRef<Type> elementTypes) {
    assert(!elementTypes.empty());
    return Base::get(elementTypes.front().getContext(), elementTypes);
  }

  ArrayRef<Type> getElementTypes() const {
    return getImpl()->elementTypes;
  }
};
```

在 `ToyDialect::initialize()` 中调用 `addTypes<StructType>()` 注册。注册时存储类定义必须可见。

## 3. 暴露给 ODS

> 代码性质：示意（非逐字源码，未编译或运行验证）。

```tablegen
def Toy_StructType : DialectType<
    Toy_Dialect,
    CPred<"::llvm::isa<StructType>($_self)">,
    "Toy struct type">;

def Toy_Type : AnyTypeOf<[F64Tensor, Toy_StructType]>;
```

这样操作定义就能像引用 Tensor 约束一样引用 StructType。

## 4. 自定义解析与打印

方言类型的一般形式为 `!方言<类型数据>`。Toy 选择：

```text
struct-type ::= `struct` `<` type (`,` type)* `>`
```

`ToyDialect::parseType` 依次解析 `struct<`、一个或多个元素类型、逗号与 `>`，并验证元素只能是 Tensor 或嵌套 Struct。`printType` 输出相同语法。二者必须 round-trip：

```text
文本 → parseType → StructType → printType → 等价文本
```

### 4.1 本地解析与打印的实际实现

下面保留完整函数，便于观察失败返回、递归类型解析和错误位置；不是将递归语法说明误认为已展示了实现。

> 代码性质：逐字源码（按所引路径与起始行核对；不等于独立可编译）。

[源码：Ch7/mlir/Dialect.cpp](/opt/llvm-project/mlir/examples/toy/Ch7/mlir/Dialect.cpp:582)

```c++
mlir::Type ToyDialect::parseType(mlir::DialectAsmParser &parser) const {
  // Parse a struct type in the following form:
  //   struct-type ::= `struct` `<` type (`,` type)* `>`

  // NOTE: All MLIR parser function return a ParseResult. This is a
  // specialization of LogicalResult that auto-converts to a `true` boolean
  // value on failure to allow for chaining, but may be used with explicit
  // `mlir::failed/mlir::succeeded` as desired.

  // Parse: `struct` `<`
  if (parser.parseKeyword("struct") || parser.parseLess())
    return Type();

  // Parse the element types of the struct.
  SmallVector<mlir::Type, 1> elementTypes;
  do {
    // Parse the current element type.
    SMLoc typeLoc = parser.getCurrentLocation();
    mlir::Type elementType;
    if (parser.parseType(elementType))
      return nullptr;

    // Check that the type is either a TensorType or another StructType.
    if (!llvm::isa<mlir::TensorType, StructType>(elementType)) {
      parser.emitError(typeLoc, "element type for a struct must either "
                                "be a TensorType or a StructType, got: ")
          << elementType;
      return Type();
    }
    elementTypes.push_back(elementType);

    // Parse the optional: `,`
  } while (succeeded(parser.parseOptionalComma()));

  // Parse: `>`
  if (parser.parseGreater())
    return Type();
  return StructType::get(elementTypes);
}
```

`parseType(elementType)` 委托通用解析器处理字段类型；`parseOptionalComma()` 的成功表示继续下一字段。失败分支返回空 Type，避免用未完成的元素列表构造 StructType。注意检查允许 TensorType 或 StructType，并不在此单独要求所有 Tensor 元素为 f64。

> 代码性质：逐字源码（按所引路径与起始行核对；不等于独立可编译）。

[源码：Ch7/mlir/Dialect.cpp](/opt/llvm-project/mlir/examples/toy/Ch7/mlir/Dialect.cpp:623)

```c++
void ToyDialect::printType(mlir::Type type,
                           mlir::DialectAsmPrinter &printer) const {
  // Currently the only toy type is a struct type.
  StructType structType = llvm::cast<StructType>(type);

  // Print the struct type according to the parser format.
  printer << "struct<";
  llvm::interleaveComma(structType.getElementTypes(), printer);
  printer << '>';
}
```

打印器递归打印每个元素类型，并在相邻元素之间插入逗号；它不保存源文件空白。与前面的类型唯一化结合，目标是解析—打印—再解析得到相同语义的类型，不是文本逐字不变。

## 5. 让操作支持 StructType

### 5.1 更新现有操作

例如 `toy.return` 的输入从仅接收张量改为接收 `Toy_Type`：

> 代码性质：示意（非逐字源码，未编译或运行验证）。

```tablegen
let arguments = (ins Variadic<Toy_Type>:$input);
```

### 5.2 新操作

`toy.struct_constant` 用 `ArrayAttr` 保存各字段的常量属性：

> 代码性质：示意（非逐字源码，未编译或运行验证）。

```mlir
%s = toy.struct_constant [
  dense<[[1.0, 2.0], [3.0, 4.0]]> : tensor<2x2xf64>,
  dense<[[5.0, 6.0], [7.0, 8.0]]> : tensor<2x2xf64>
] : !toy.struct<tensor<*xf64>, tensor<*xf64>>
```

`toy.struct_access` 按索引取得第 N 个元素：

> 代码性质：示意（非逐字源码，未编译或运行验证）。

```mlir
%a = toy.struct_access %s[0]
  : !toy.struct<tensor<*xf64>, tensor<*xf64>> -> tensor<*xf64>
```

## 6. 常量折叠

内联后常见模式是从 `struct_constant` 立即取字段。为相关操作启用 `hasFolder` 并实现 `fold`：

> 代码性质：示意（非逐字源码，未编译或运行验证）。

```c++
OpFoldResult StructConstantOp::fold(FoldAdaptor adaptor) {
  return getValue();
}

OpFoldResult StructAccessOp::fold(FoldAdaptor adaptor) {
  auto values = llvm::dyn_cast_if_present<ArrayAttr>(adaptor.getInput());
  if (!values)
    return nullptr;
  return values[getIndex()];
}
```

方言还实现 `materializeConstant`：Tensor 常量物化为 `toy.constant`，Struct 常量物化为 `toy.struct_constant`。这使通用折叠框架能把属性重新变为正确的 Toy 操作。

常量结构体被完全折叠后，后续流水线只看到普通张量常量、转置、乘法和打印，因此第 5、6 章的 lowering 不必因 struct 而修改。

## 7. 运行

```bash
${TOY_BUILD}/bin/toyc-ch7 \
  /opt/llvm-project/mlir/test/Examples/Toy/Ch7/struct-codegen.toy \
  -emit=mlir
```

这一章说明，扩展语言通常贯穿多层：语法与 AST、MLIR 类型、文本格式、ODS 约束、操作、验证、优化与 lowering。良好的折叠规则能让新高层概念在进入旧后端前被消去，从而复用既有流水线。

## 8. 代码补充：从字段名到类型检查

[MLIRGen.cpp](/opt/llvm-project/mlir/examples/toy/Ch7/mlir/MLIRGen.cpp) 新增 `structMap`，将结构体名字映射到 `(mlir::Type, StructAST*)`；局部符号表也从单独的 Value 改为 `(Value, VarDeclExprAST*)`。这是为了在生成字段访问时，从源语言声明找回字段名字及顺序，再生成数字索引。

`getMemberIndex()` 查询字段名在声明中的位置。生成 `.` 操作时只把左侧生成为运行时值，右侧作为字段名解析；不能把右侧当成普通变量查询。结构体字面量通过 `getConstantAttr(StructLiteralExprAST&)` 递归生成 `ArrayAttr`，张量字段类型有意先记为无秩，精确形状保存在字段属性中。

### 8.1 递归常量验证

`verifyConstantForType` 同时被 ConstantOp 与 StructConstantOp 使用。Tensor 分支要求 `DenseFPElementsAttr`，结果有秩时比较形状；Struct 分支要求 `ArrayAttr`、字段数量相等，再逐字段递归检查。它处理了嵌套结构体，避免只验证最外层长度。

### 8.2 字段访问 builder 与 verifier

> 代码性质：逐字源码（按所引路径与起始行核对；不等于独立可编译）。

[源码：Ch7/mlir/Dialect.cpp](/opt/llvm-project/mlir/examples/toy/Ch7/mlir/Dialect.cpp:446)

```c++
void StructAccessOp::build(mlir::OpBuilder &b, mlir::OperationState &state,
                           mlir::Value input, size_t index) {
  // Extract the result type from the input type.
  StructType structTy = llvm::cast<StructType>(input.getType());
  assert(index < structTy.getNumElementTypes());
  mlir::Type resultType = structTy.getElementTypes()[index];

  // Call into the auto-generated build method.
  build(b, state, resultType, input, b.getI64IntegerAttr(index));
}
```

> 代码性质：逐字源码（按所引路径与起始行核对；不等于独立可编译）。

[源码：Ch7/mlir/Dialect.cpp](/opt/llvm-project/mlir/examples/toy/Ch7/mlir/Dialect.cpp:457)

```c++
mlir::LogicalResult StructAccessOp::verify() {
  StructType structTy = llvm::cast<StructType>(getInput().getType());
  size_t indexValue = getIndex();
  if (indexValue >= structTy.getNumElementTypes())
    return emitOpError()
           << "index should be within the range of the input struct type";
  mlir::Type resultType = getResult().getType();
  if (resultType != structTy.getElementTypes()[indexValue])
    return emitOpError() << "must have the same result type as the struct "
                            "element referred to by the index";
  return mlir::success();
}
```

本地生成访问器 `getIndex()` 已返回可用的整数，不要再调用旧式 `getZExtValue()`。builder 从字段类型推导结果；verifier 则确保通过文本解析或显式构造得到的操作也遵守索引范围和结果类型约束。

### 8.3 常量物化与形状恢复

> 代码性质：逐字源码（按所引路径与起始行核对；不等于独立可编译）。

[源码：Ch7/mlir/Dialect.cpp](/opt/llvm-project/mlir/examples/toy/Ch7/mlir/Dialect.cpp:656)

```c++
mlir::Operation *ToyDialect::materializeConstant(mlir::OpBuilder &builder,
                                                 mlir::Attribute value,
                                                 mlir::Type type,
                                                 mlir::Location loc) {
  if (llvm::isa<StructType>(type))
    return builder.create<StructConstantOp>(loc, type,
                                            llvm::cast<mlir::ArrayAttr>(value));
  return builder.create<ConstantOp>(loc, type,
                                    llvm::cast<mlir::DenseElementsAttr>(value));
}
```

物化得到的 Tensor 常量可能仍以无秩结果出现。因此 Ch7 还给 ConstantOp 添加 `ShapeInferenceOpInterface`，`ConstantOp::inferShapes()` 从稠密属性恢复结果的精确张量类型。只讲 struct_access 折叠而忽略这一步，会漏掉它如何进入旧 Affine lowering 的关键连接。

本地 [struct-opt.mlir](/opt/llvm-project/mlir/test/Examples/Toy/Ch7/struct-opt.mlir) 通过两层嵌套 struct_access 验证最后只剩 tensor 常量和 print。可运行：

```bash
${TOY_BUILD}/bin/toyc-ch7 /opt/llvm-project/mlir/test/Examples/Toy/Ch7/struct-opt.mlir -emit=mlir -opt
```

这是通过消除高层结构体来复用后端，不是已经定义了运行时结构体布局和 ABI。Ch7 的 `functionMap` 也按源码顺序记录已生成函数，调用处理要求 callee 已在映射中；函数前向引用和递归不能当作已实现功能。
