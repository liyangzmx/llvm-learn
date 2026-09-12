# 第 1 章：Toy 语言与 AST

本地原文：[Ch-1.md](/opt/llvm-project/mlir/docs/Tutorials/Toy/Ch-1.md) · [本章源码](/opt/llvm-project/mlir/examples/toy/Ch1/toyc.cpp)

基准：`release/18.x` / `3b5b5c1ec4a3`。正文按官方主线译编；原文与实现不一致处，以本地代码校正并说明。C++、TableGen 与 MLIR 代码块分别标为“逐字源码”“译编”或“示意”；只有带源码锚点的逐字摘录参与逐行核对，完整实现见源码链接。

本章先定义教程要编译的语言，再观察词法分析器和递归下降解析器产生的抽象语法树（AST）。下一章才会进入 MLIR。

## 1. Toy 语言

Toy 是一门基于张量的小型语言，可以定义函数、执行简单数学运算并打印结果。为了聚焦 MLIR，语言有意受到限制：

- 官方把教学代码生成目标限定为秩不超过 2 的张量；源码中的递归字面量解析与部分循环生成更一般，并非每层都检查这个上限；
- 唯一的数据元素类型是 64 位浮点数，即 C/C++ 的 `double`；
- 所有值都不可变，每个操作产生一个新值；
- 源程序不显式释放内存；第 5 章由编译器插入 `memref.alloc/dealloc`，第 6 章继续降低到分配/释放调用；
- 内建函数只有 `transpose` 和 `print`。

下面是第一个 Toy 程序：

```toy
def main() {
  # a 的形状由字面量推断为 <2, 3>
  var a = [[1, 2, 3], [4, 5, 6]];

  # 显式声明形状；元素总数相同时，字面量会被重塑
  var b<2, 3> = [1, 2, 3, 4, 5, 6];

  # 先转置，再逐元素相乘，最后打印
  print(transpose(a) * transpose(b));
}
```

Toy 通过类型推断执行静态类型检查。只有在需要说明张量形状时才写类型信息。函数是泛型的：形参最初只知道是张量，并不知道具体维度。原文用“按调用签名专门化”描述期望行为，但本地第 4 章实际采用内联加函数内形状传播，没有实现缓存专门化版本的机制。下例关于专门化的注释描述原文的语言设想，不能当作 Ch1 已具备的功能。

```toy
def multiply_transpose(a, b) {
  return transpose(a) * transpose(b);
}

def main() {
  var a = [[1, 2, 3], [4, 5, 6]];
  var b<2, 3> = [1, 2, 3, 4, 5, 6];

  # 第一次以 <2,3>、<2,3> 调用，结果为 <3,2>
  var c = multiply_transpose(a, b);
  # 签名相同，复用已有专门化版本
  var d = multiply_transpose(b, a);
  # 以新的 <3,2>、<3,2> 签名调用，产生新专门化版本
  var e = multiply_transpose(c, d);
  # 原文设想：不兼容 shape 应报错；本地实现未完整检查这一情形
  var f = multiply_transpose(a, c);
}
```

这里最重要的事实是：源程序不仅包含“加、乘、转置”这些计算，还包含函数、变量声明、返回语句、形状与源码位置。前端首先要把这些结构保存为 AST。

## 2. AST

AST 忽略括号、分号等语法表面细节，只保留程序的结构与语义关系。上例的 AST 可概括为：

```text
Module
├── Function multiply_transpose(a, b)
│   └── Return
│       └── Binary *
│           ├── Call transpose → Variable a
│           └── Call transpose → Variable b
└── Function main()
    ├── VarDecl a → TensorLiteral <2,3>
    ├── VarDecl b<2,3> → TensorLiteral <6>
    ├── VarDecl c → Call multiply_transpose(a,b)
    ├── VarDecl d → Call multiply_transpose(b,a)
    ├── VarDecl e → Call multiply_transpose(c,d)
    └── VarDecl f → Call multiply_transpose(a,c)
```

真实 AST dump 还会在节点后记录类似 `file.toy:5:25` 的源码位置。诊断信息和后续 MLIR 的 `Location` 都会依赖这些位置。

## 3. 运行本章示例

构建 LLVM/MLIR 与 Toy 示例后，先按 [环境准备](/opt/coding/mlir-toy/aiversion/00-preflight.md) 设置 `TOY_BUILD`，然后运行：

```bash
${TOY_BUILD}/bin/toyc-ch1 \
  /opt/llvm-project/mlir/test/Examples/Toy/Ch1/ast.toy \
  -emit=ast
```

路径会随构建布局不同而变化。官方源码中的关键文件是：

- `mlir/examples/toy/Ch1/include/toy/Lexer.h`：词法分析器；
- `mlir/examples/toy/Ch1/include/toy/Parser.h`：递归下降解析器；
- `mlir/examples/toy/Ch1/include/toy/AST.h`：AST 数据结构；
- `mlir/examples/toy/Ch1/toyc.cpp`：驱动程序。

解析器与 LLVM Kaleidoscope 教程前两章采用相近的方法。Toy 教程不把重点放在解析器实现，而把 AST 作为进入 MLIR 的输入。

## 4. 本章结论

编译器前端完成了这条路径：

```text
Toy 源码 → Token → AST
```

下一章将把 AST 映射为一种保留 Toy 高层语义的 MLIR 方言。

## 5. 对照本地解析器理解语言边界

[Lexer.h](/opt/llvm-project/mlir/examples/toy/Ch1/include/toy/Lexer.h) 用负数枚举表示 `def`、`var`、`return`、标识符和数字，单字符标点直接返回字符值。`print` 与 `transpose` 都不是词法关键字：`print` 在 Parser 中识别成 `PrintExprAST`，`transpose` 保持 `CallExprAST`，到 MLIRGen 才分派为专门的操作。

[Parser.h](/opt/llvm-project/mlir/examples/toy/Ch1/include/toy/Parser.h) 的 `parseTensorLiteralExpr()` 递归收集元素，当前维长度取列表大小，再附加子字面量维度，并尝试检查子数组形状一致。`parseBinOpRHS()` 处理操作符优先级：`+`、`-` 为 20，`*` 为 40。然而 Ch2 的 MLIRGen 只实现 `+` 和 `*`；Parser 接受 `-` 不等于完整编译链支持减法。

[AST.h](/opt/llvm-project/mlir/examples/toy/Ch1/include/toy/AST.h) 的所有表达式继承 ExprAST，保存 kind 与 Location；子节点由 `std::unique_ptr` 拥有。PrototypeAST 保存函数名、参数名和位置，FunctionAST 拥有 prototype 与 body，ModuleAST 保存函数列表。节点的 `classof` 提供 LLVM 风格 RTTI，供 `isa/dyn_cast/cast` 使用。

本章命令仅做语法分析和 AST dump，不解析未声明变量，也不对函数做专门化。原文最后的错误形状示例表达了语言期望；本地 Add/Mul 的形状推断只是复制左输入类型，所以不能把“给出不同形状一定在此阶段得到友好诊断”当作代码保证。

`var b<2,3>` 的 `<2,3>` 是变量声明的重塑要求；AST 中初始化器 `[1,2,3,4,5,6]` 仍是形状 `<6>` 的 Literal。两者并存，正好为第 2 章显式插入 `toy.reshape` 提供依据。
