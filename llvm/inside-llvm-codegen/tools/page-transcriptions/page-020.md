## 1.4 LLVM 在线工具

如果读者不想构建 LLVM，也可以使用在线工具 Compiler Explorer（https://godbolt.org）学习 LLVM 各种功能和代码变化。该在线工具可以直观地比较优化前后的代码变化情况，支持多种语言作为输入，也支持 LLVM IR、LLVM MIR（Machine IR）作为输入，该工具可以选择不同的编译器进行编译。

1）Compiler Explorer 初始界面如图 1-2 所示，可以选择不同的编程语言。

![图 1-2 输入代码并选择编程语言](assets/figures/p020-1-2.png)

**图 1-2 输入代码并选择编程语言**

2）选择不同的编译器，并为编译器添加不同的编译选项，例如选择 Clang 版本，添加命令行参数 -emit-llvm -S 用于生成 LLVM IR，如图 1-3 所示。

![图 1-3 选择编译器并添加编译选项](assets/figures/p020-1-3.png)

**图 1-3 选择编译器并添加编译选项**
