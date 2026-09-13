# 验证证据

第 4 章的接口分派、验证器和 TableGen 输入及复现命令见 [ch4/](ch4/README.md)。

下列记录区分实际工具运行、源码对照与官方硬件资料核对。LLVM/MLIR 实测使用本地 18.1.8；Triton 使用书中固定提交作源码依据，不代表所有原书片段都能独立编译。

## 校订读本的后续修正

[本次差异与检查](reading-edition/README.md)记录第1章偏置顺序、第10章范围折叠正确规则、第15章量词消除完整推导和附录A-1主示例调整。它保存当前验证和修正前快照；以下各扫描处理批次的原始运行产物仍按历史结果保留。

## 第 14 章至书末新增证据

- 第 14 章：[章节校订](../ch14.md)、[数学基础独立复核](ch14/math-foundations-review.md)、[循环分块语义缺陷的原生执行反例](ch14/tiling-review.md)。
- 第 15 章：[章节校订](../ch15.md)、[单纯形与分支定界独立复核](ch15/independent-math-review.md)。
- [第四部分导读](../part4.md)及[附录校订](../appendix.md)，分别说明数学模型与七个补充方言。
- [已有正文和 OCR 哈希基线](ch14-end/preexisting-content-sha256.json)、[保留检查](ch14-end/preservation-check.json)、[新增前 manifest](ch14-end/manifest-before-ch14-end.json)。这些记录确认在第14章至书末扫描处理批次中，此前章节正文和原始 OCR 未被改写；不用于声称后续授权校订没有修改正文。

该扫描处理批次新增图与公式的实际渲染结果见[2幅Mermaid](ch14-end/mermaid-validation.json)、[540个公式](ch14-end/math-validation.json)及[几何图目视](ch14-end/geometry-visual-review.json)。[全书Mermaid记录](mermaid-validation.json)合并各批次，并通过哈希确认旧图未变。数学公式预览可用 [build_math_preview.py](../../tools/build_math_preview.py)生成，浏览器加载KaTeX后逐式记录实际结果；语法渲染不代替数学证明。

## 第 1 章补录证据

- [第 1 章校订与复现记录](../ch1.md)：TOSA、Linalg、Affine、LLVM 示例与实际降级结果。
- [背景与 Presburger 表述复核](ch1/context-review.md)、[偏置加入顺序的浮点反例](ch1/bias-order.py)及[运行结果](ch1/bias-order.json)。
- [本轮开始前的正文和 OCR 哈希](ch1/preexisting-content-sha256.json)、[最终保留检查](ch1/preservation-check.json)，证明已有章节正文与原始 OCR 未改动。
- [源文件替换前的 manifest](ch1/manifest-before-ch1.json)，保留此前同名 PDF 重复包含第 2～3 章的来源映射。

## 第 11–13 章新增证据

- 第 11 章：[校订与复现记录](../ch11.md)、[共享内存 XOR 改写与 bank 算术反例](ch11/bank-review.md)。
- 第 12 章：[校订与复现记录](../ch12.md)、[三种扩展机制独立对照](ch12-extension-review.md)。
- 第 13 章：[校订与复现记录](../ch13.md)、[固定 Triton 源码和 LLVM 依赖提交](triton-source.md)、[软件流水线阶段与收尾边界核验](ch13-pipeline-review.md)、[章末历史及性能资料核对](ch13-tail/future-review.md)。
- 第 11、13 章共用：[Arm SME／NVIDIA 硬件说明核对](hardware-review.md)，未作 GPU 性能实测。
- 第三部分：[扉页、提交号与页码说明](../part3.md)。

## 第 7–10 章新增证据

- 第 7 章：[校订与复现记录](../ch7.md)、[证据目录](ch7/)，含操作数排序、CSE、内联、SCCP、运行时验证以及正文清单解析与 TableGen 生成检查。
- 第 8 章：[校订与复现记录](../ch8.md)、[证据目录](ch8/)，含原书错误诊断、实际 TOSA 矩阵乘法降级、量化零点与 f16/f32 结果类型检查。
- 第 9 章：[缓冲化独立核验](ch9-bufferization/README.md)，含原地复用/写后读冲突、自动释放流水线和实际 API。章节其他证据见 [第 9 章记录](../ch9.md)。
- 第 10 章：[结构方言独立核验](ch10-structure/README.md)，含间接调用验证与非零下界范围折叠的真实缺陷反例。章节其他证据见 [第 10 章记录](../ch10.md)。
- 第二部分导读：[原图渲染与校订记录](../part2.md)，保留复杂关系图及实际注册方言列表。

## 第 3 章：Operation 内存布局及句柄

- [输入 C++](ch3-operation-layout.cpp)：编译期确认 `dyn_cast<arith::AddIOp>(Operation *)` 的返回类型是 `AddIOp` 值句柄；运行时输出大小、对齐与内联结果上限。
- [运行输出](ch3-operation-sizes.txt)：本机 macOS arm64 下，`Operation` 为 64 字节、8 字节对齐，`AddIOp` 句柄为 8 字节，最多 6 个内联结果。数值依赖版本及 ABI，不是可移植保证。
- [Clang 布局输出](ch3-operation-record-layout.txt)：包含 `orderIndex` 及其余字段的真实偏移、23 位 `numRegions` 等。原图部分偏移和字段缺漏据此修正。

在项目根目录运行：

```sh
/usr/bin/clang++ -O2 -std=c++17 \
  -I /opt/llvm-project/mlir/include \
  -I /opt/llvm-project/build/tools/mlir/include \
  -I /opt/llvm-project/llvm/include \
  -I /opt/llvm-project/build/include \
  mlir/insider-compiler/issues/evidence/ch3-operation-layout.cpp \
  -L /opt/llvm-project/build/lib \
  -lMLIRIR -lMLIRSupport -lLLVMSupport -lLLVMDemangle -lz -lcurses \
  -o /private/tmp/insider-ch3-layout
/private/tmp/insider-ch3-layout
```

将编译选项增加 `-Xclang -fdump-record-layouts` 可查看 Clang 的完整布局输出；所保存 TXT 只提取其中 `mlir::Operation` 的记录。

## 第 6 章：模式接口与贪婪重写

[模式 API 声明](ch6-pattern-api.cpp)修复任意操作模式构造器和 `const override` 签名，已通过以下语法检查。这里没有函数定义，不进行链接或执行。

```sh
/usr/bin/clang++ -std=c++17 -fsyntax-only \
  -I /opt/llvm-project/mlir/include \
  -I /opt/llvm-project/build/tools/mlir/include \
  -I /opt/llvm-project/llvm/include \
  -I /opt/llvm-project/build/include \
  mlir/insider-compiler/issues/evidence/ch6-pattern-api.cpp
```

[贪婪重写输入](ch6-greedy.mlir)对应代码清单 6-5。两种遍历顺序均实际运行成功，最终得到仅含 `return` 的函数：

- 自顶向下：[输出 IR](ch6-greedy-top-down.mlir)、[完整调试日志](ch6-greedy-top-down.log)。
- 自底向上：[输出 IR](ch6-greedy-bottom-up.mlir)、[完整调试日志](ch6-greedy-bottom-up.log)。

```sh
/opt/llvm-project/build/bin/mlir-opt \
  '-test-patterns=top-down=true' -debug-only=greedy-rewriter \
  mlir/insider-compiler/issues/evidence/ch6-greedy.mlir
/opt/llvm-project/build/bin/mlir-opt \
  '-test-patterns=top-down=false' -debug-only=greedy-rewriter \
  mlir/insider-compiler/issues/evidence/ch6-greedy.mlir
```

这些命令依赖包含测试 Pass 的 debug 工具构建。调试日志里的地址随执行变化，原书添加的解释性日志前缀并非本地上游工具原样输出。各章其他 TableGen、IR 解析和语法检查见相应 `issues/chN.md`。
