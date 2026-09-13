# 全书脚注与参考资料汇总

本书扫描件的 OCR 包含页底脚注。校订时已恢复引用标记、链接和说明，现有逐章 Markdown 共保留 **88 条原书脚注**；其中 **58 条包含外部资料引用，30 条为术语、实现或背景说明**。脚注数不等于独立参考文献数：一条脚注可能列出多项资料，同一项目也可能在不同章节再次出现。

本文件按校订稿汇集全部脚注，资料类与说明类分别按章节排列。题名、作者及版本信息采用已有校订结果；访问年月均保留原书记载。每项附原脚注标识和章节链接，便于回到正文；重复项目保留各章语境。同一脚注中的多项参考资料完整收录。

出处依据为逐章 Markdown、本地 Apple Vision TXT／JSON 与各章 `issues/` 校订记录。本次另查了第1章首页、第12章 Transform 引文页和第15章末两页的原始 OCR，可见链接、作者及文献标题确实参与识别；原 OCR 的断行、上标和拼写错误仍留在本地存档。以下条目中提及的核验工作与待核标记均引用已有章节校订记录；原书访问日期也不作为本次汇总时的逐链接访问日期。

## 章节索引

| 章节 | 资料类脚注 | 说明性脚注 | 合计 |
| --- | ---: | ---: | ---: |
| [第1章 绪论](insider-compiler-ch1.md) | 9 | 3 | 12 |
| [第2章 MLIR 概述](insider-compiler-ch2.md) | 4 | 3 | 7 |
| [第3章 类型、属性、操作和方言详解](insider-compiler-ch3.md) | 1 | 2 | 3 |
| [第4章 谓词、特质和接口](insider-compiler-ch4.md) | 1 | 2 | 3 |
| [第5章 Pass 系统的工作流程](insider-compiler-ch5.md) | 0 | 4 | 4 |
| [第6章 操作匹配与重写机制](insider-compiler-ch6.md) | 2 | 2 | 4 |
| [第7章 MLIR 中常见的通用优化技术](insider-compiler-ch7.md) | 4 | 1 | 5 |
| [第二部分 MLIR 方言详解](insider-compiler-part2.md) | 0 | 0 | 0 |
| [第8章 业务接入方言](insider-compiler-ch8.md) | 3 | 0 | 3 |
| [第9章 优化方言](insider-compiler-ch9.md) | 6 | 0 | 6 |
| [第10章 结构方言与数据方言](insider-compiler-ch10.md) | 5 | 3 | 8 |
| [第11章 目标输出方言](insider-compiler-ch11.md) | 2 | 1 | 3 |
| [第12章 元编程方言](insider-compiler-ch12.md) | 7 | 0 | 7 |
| [第三部分 MLIR 实战项目剖析](insider-compiler-part3.md) | 1 | 0 | 1 |
| [第13章 Triton DSL 的设计与编译优化](insider-compiler-ch13.md) | 7 | 2 | 9 |
| [第四部分 MLIR 中的数学知识与应用](insider-compiler-part4.md) | 0 | 0 | 0 |
| [第14章 多面体编译理论概述](insider-compiler-ch14.md) | 0 | 5 | 5 |
| [第15章 整数规划求解方法](insider-compiler-ch15.md) | 5 | 2 | 7 |
| [附录 其他方言](insider-compiler-appendix.md) | 1 | 0 | 1 |
| **合计** | **58** | **30** | **88** |

## 参考资料

这里的 R 编号对应一条原书资料类脚注。带有“待核”“版本差异”等说明的条目，按其注明的范围使用。

### 第1章 绪论

<a id="fn-ch1-aie"></a>
<!-- footnote-source: insider-compiler-ch1.md; id: ch1-aie -->

**R01**　[Xilinx/AMD mlir-aie](https://github.com/Xilinx/mlir-aie)，原书注明2025年4月访问。

来源：[第1章 绪论](insider-compiler-ch1.md)，脚注标识 `ch1-aie`。

<a id="fn-ch1-tpu"></a>
<!-- footnote-source: insider-compiler-ch1.md; id: ch1-tpu -->

**R02**　[Sophgo tpu-mlir](https://github.com/sophgo/tpu-mlir)，原书注明2025年4月访问。这里的项目面向相应厂商的处理器，不应与 Google TPU 产品直接等同。

来源：[第1章 绪论](insider-compiler-ch1.md)，脚注标识 `ch1-tpu`。

<a id="fn-ch1-stablehlo"></a>
<!-- footnote-source: insider-compiler-ch1.md; id: ch1-stablehlo -->

**R03**　[OpenXLA StableHLO](https://github.com/openxla/stablehlo)，原书注明2025年4月访问。StableHLO与TensorFlow 2.0的时间和流程不能混为一谈，详见[背景校订](issues/ch1.md#ch1-context)。

来源：[第1章 绪论](insider-compiler-ch1.md)，脚注标识 `ch1-stablehlo`。

<a id="fn-ch1-iree"></a>
<!-- footnote-source: insider-compiler-ch1.md; id: ch1-iree -->

**R04**　[IREE](https://github.com/iree-org/iree)，原书注明2025年4月访问。

来源：[第1章 绪论](insider-compiler-ch1.md)，脚注标识 `ch1-iree`。

<a id="fn-ch1-firefly"></a>
<!-- footnote-source: insider-compiler-ch1.md; id: ch1-firefly -->

**R05**　[Firefly](https://github.com/GetFirefly/firefly)，原书注明2025年4月访问；本章保留其作为历史应用例子，不据此推断项目当前维护状态。

来源：[第1章 绪论](insider-compiler-ch1.md)，脚注标识 `ch1-firefly`。

<a id="fn-ch1-earth"></a>
<!-- footnote-source: insider-compiler-ch1.md; id: ch1-earth -->

**R06**　[Open Earth Compiler](https://github.com/spcl/open-earth-compiler)，原书注明2025年4月访问。

来源：[第1章 绪论](insider-compiler-ch1.md)，脚注标识 `ch1-earth`。

<a id="fn-ch1-triton"></a>
<!-- footnote-source: insider-compiler-ch1.md; id: ch1-triton -->

**R07**　[Triton](https://github.com/triton-lang/triton)，原书注明2025年4月访问。

来源：[第1章 绪论](insider-compiler-ch1.md)，脚注标识 `ch1-triton`。

<a id="fn-ch1-pytorch-rtl"></a>
<!-- footnote-source: insider-compiler-ch1.md; id: ch1-pytorch-rtl -->

**R08**　原书给出的[《从PyTorch到RTL：基于MLIR的高层次综合技术》](https://file.elecfans.com/web2/M00/7E/0E/poYBAGOC6bKAZAQyADt7O8jLZCE607.pdf)，叶汉辰，2022年11月27日；原书注明2024年7月访问。本次链接已打开并核到标题和日期，未把其中较早版本的代码直接当作LLVM18/20的当前接口。

来源：[第1章 绪论](insider-compiler-ch1.md)，脚注标识 `ch1-pytorch-rtl`。

<a id="fn-ch1-verona"></a>
<!-- footnote-source: insider-compiler-ch1.md; id: ch1-verona -->

**R09**　[Microsoft Verona](https://github.com/microsoft/verona)，原书注明2024年7月访问。关于其采用和停止采用MLIR的具体历史及原因，见[校订记录](issues/ch1.md#ch1-context)。

来源：[第1章 绪论](insider-compiler-ch1.md)，脚注标识 `ch1-verona`。

### 第2章 MLIR 概述

<a id="fn-ch2-langref"></a>
<!-- footnote-source: insider-compiler-ch2.md; id: ch2-langref -->

**R10**　参见 [MLIR Language Reference](https://mlir.llvm.org/docs/LangRef/)，原书标注 2024 年 7 月访问。本次核对采用本地同版本 `mlir/docs/LangRef.md`。

来源：[第2章 MLIR 概述](insider-compiler-ch2.md)，脚注标识 `ch2-langref`。

<a id="fn-ch2-region-rfc"></a>
<!-- footnote-source: insider-compiler-ch2.md; id: ch2-region-rfc -->

**R11**　原书附注：MLIR 中引入区域后导致了一些问题，社区正在讨论引入一种新的区域，但尚未形成最后结论。具体可参见 [[RFC] Region-based control flow with early exits in MLIR](https://discourse.llvm.org/t/rfc-region-based-control-flow-with-early-exits-in-mlir/76998)，2024 年 7 月访问。此处保留原书的历史性注释，不将其中“正在讨论”视为当前社区状态。

来源：[第2章 MLIR 概述](insider-compiler-ch2.md)，脚注标识 `ch2-region-rfc`。

<a id="fn-ch2-structure"></a>
<!-- footnote-source: insider-compiler-ch2.md; id: ch2-structure -->

**R12**　参见 [Understanding the IR Structure](https://mlir.llvm.org/docs/Tutorials/UnderstandingTheIRStructure/)，原书标注 2024 年 7 月访问。本次核对采用本地同版本文档。

来源：[第2章 MLIR 概述](insider-compiler-ch2.md)，脚注标识 `ch2-structure`。

<a id="fn-ch2-performance"></a>
<!-- footnote-source: insider-compiler-ch2.md; id: ch2-performance -->

**R13**　参见 [How Slow Is MLIR?](https://llvm.org/devmtg/2024-04/slides/Keynote/Amini-Niu-HowSlowIsMLIR.pdf)，原书标注 2024 年 7 月访问。此处保留原书的参考资料；正文不据此推断当前版本的具体性能。

来源：[第2章 MLIR 概述](insider-compiler-ch2.md)，脚注标识 `ch2-performance`。

### 第3章 类型、属性、操作和方言详解

<a id="fn-ch3-trailing"></a>
<!-- footnote-source: insider-compiler-ch3.md; id: ch3-trailing -->

**R14**　参见原书提供的 [C++ Insights 示例](https://cppinsights.io/s/789b1c66)，原书标注 2025 年 4 月访问。本次校订依据本地 `llvm/include/llvm/Support/TrailingObjects.h`，不假定外链示例与本地版本相同。

来源：[第3章 类型、属性、操作和方言详解](insider-compiler-ch3.md)，脚注标识 `ch3-trailing`。

### 第4章 谓词、特质和接口

<a id="fn-ch4-interfaces-doc"></a>
<!-- footnote-source: insider-compiler-ch4.md; id: ch4-interfaces-doc -->

**R15**　接口使用介绍可参考官网 [MLIR Interfaces](https://mlir.llvm.org/docs/Interfaces/)，原书标注 2024 年 8 月访问。本次以本地 `mlir/docs/Interfaces.md` 及生成器源码核对。

来源：[第4章 谓词、特质和接口](insider-compiler-ch4.md)，脚注标识 `ch4-interfaces-doc`。

### 第6章 操作匹配与重写机制

<a id="fn-ch6-toy"></a>
<!-- footnote-source: insider-compiler-ch6.md; id: ch6-toy -->

**R16**　具体代码可以参考原书所引 [mlir-tutorial 历史版本](https://github.com/KEKE046/mlir-tutorial/tree/833cd57278d92ba1bb0b627db7cf4ebacc669144)。原书注明“2024 年 9 月访问”。本次核对的是本地 LLVM API，不保证该外部项目可直接在本地版本构建。

来源：[第6章 操作匹配与重写机制](insider-compiler-ch6.md)，脚注标识 `ch6-toy`。

<a id="fn-ch6-springer"></a>
<!-- footnote-source: insider-compiler-ch6.md; id: ch6-springer -->

**R17**　参见 [Pattern-Based IR Rewriting in MLIR](https://llvm.org/devmtg/2024-10/slides/techtalk/Springer-Pattern-Based-IR-Rewriting-in-MLIR.pdf)。原书注明“2025 年 4 月访问”。

来源：[第6章 操作匹配与重写机制](insider-compiler-ch6.md)，脚注标识 `ch6-springer`。

### 第7章 MLIR 中常见的通用优化技术

<a id="fn-ch7-polygeist"></a>
<!-- footnote-source: insider-compiler-ch7.md; id: ch7-polygeist -->

**R18**　[Polygeist 项目](https://github.com/llvm/Polygeist)，原书记载访问时间为 2025 年 5 月。

来源：[第7章 MLIR 中常见的通用优化技术](insider-compiler-ch7.md)，脚注标识 `ch7-polygeist`。

<a id="fn-ch7-rfc"></a>
<!-- footnote-source: insider-compiler-ch7.md; id: ch7-rfc -->

**R19**　[RFC: A Dataflow Analysis Framework](https://discourse.llvm.org/t/rfc-a-dataflow-analysis-framework/63340)，原书记载访问时间为 2024 年 5 月。

来源：[第7章 MLIR 中常见的通用优化技术](insider-compiler-ch7.md)，脚注标识 `ch7-rfc`。

<a id="fn-ch7-dataflow-talk"></a>
<!-- footnote-source: insider-compiler-ch7.md; id: ch7-dataflow-talk -->

**R20**　[Tom Eccles、Jeff Niu：MLIR Dataflow Analysis](https://llvm.org/devmtg/2023-05/slides/TechnicalTalks-May10/07-TomEccles-JeffNiu-MLIRDataflowAnalysis.pdf)，原书记载访问时间为 2024 年 5 月。

来源：[第7章 MLIR 中常见的通用优化技术](insider-compiler-ch7.md)，脚注标识 `ch7-dataflow-talk`。

<a id="fn-ch7-multiexit"></a>
<!-- footnote-source: insider-compiler-ch7.md; id: ch7-multiexit -->

**R21**　[Multiple-Exit MLIR Blocks，EuroLLVM 2023](https://llvm.org/devmtg/2023-05/slides/QuickTalks-May10/01%20-Multiple-Exit%20MLIR%20Blocks-EuroLLVM%202023.pdf)，原书记载访问时间为 2024 年 5 月。

来源：[第7章 MLIR 中常见的通用优化技术](insider-compiler-ch7.md)，脚注标识 `ch7-multiexit`。

### 第8章 业务接入方言

<a id="fn-ch8-1"></a>
<!-- footnote-source: insider-compiler-ch8.md; id: ch8-1 -->

**R22**　若将 AI 模型接入 `ml_program` 方言，仍需为目标执行环境补齐或集成后续降级实现。对该方言感兴趣的读者可参考 [IREE 项目](https://github.com/iree-org/iree)。原书指出该项目提供 `ml_program` 降级示例，标注“2025 年 3 月访问”；本次未具备该历史版本的完整本地源码，不将该外部示例记为已编译验证。

来源：[第8章 业务接入方言](insider-compiler-ch8.md)，脚注标识 `ch8-1`。

同一 IREE 项目另见[第1章引用](#fn-ch1-iree)；此处保留 `ml_program` 降级示例的特定语境。

<a id="fn-ch8-2"></a>
<!-- footnote-source: insider-compiler-ch8.md; id: ch8-2 -->

**R23**　参见 [TOSA 规范入口](https://www.mlplatform.org/tosa/tosa_spec.html)，原书标注“2025 年 3 月访问”。规范独立版本化，使用时应匹配所用 MLIR 实现，而不是直接套用当前最新规范。

来源：[第8章 业务接入方言](insider-compiler-ch8.md)，脚注标识 `ch8-2`。

<a id="fn-ch8-3"></a>
<!-- footnote-source: insider-compiler-ch8.md; id: ch8-3 -->

**R24**　原书链接为 [TensorFlow TOSA legalization 文档的 Fossies 镜像](https://fossies.org/linux/tensorflow/tensorflow/compiler/mlir/tosa/g3doc/legalization.md)，标注“2025 年 3 月访问”。该历史文档仅作为原书参考保留；本次未复现外部 TensorFlow 工程的接入流程。

来源：[第8章 业务接入方言](insider-compiler-ch8.md)，脚注标识 `ch8-3`。

### 第9章 优化方言

<a id="fn-ch9-design-slides"></a>
<!-- footnote-source: insider-compiler-ch9.md; id: ch9-design-slides -->

**R25**　原书所引[结构化操作设计演示文稿](https://docs.google.com/presentation/d/1P-j1GrH6Q5gLBjao0afQ-GfvcAeF-QU4GXXeSy0eJ9I/edit#slide=id.g75bf83a268_3_225)，原书注明“2025 年 6 月访问”。文稿 ID 根据本地 Linalg 文档中的同一设计文稿链接核对；这里保留历史参考，不据此推断 LLVM 18 的全部现状。

来源：[第9章 优化方言](insider-compiler-ch9.md)，脚注标识 `ch9-design-slides`。

<a id="fn-ch9-affine-rationale"></a>
<!-- footnote-source: insider-compiler-ch9.md; id: ch9-affine-rationale -->

**R26**　原书参考：[Rationale: Simplified Polyhedral Form](https://mlir.llvm.org/docs/Rationale/RationaleSimplifiedPolyhedralForm/)，原书标注 2025 年 3 月访问。本地对应 `mlir/docs/Rationale/RationaleSimplifiedPolyhedralForm.md`。

来源：[第9章 优化方言](insider-compiler-ch9.md)，脚注标识 `ch9-affine-rationale`。

<a id="fn-ch9-dps"></a>
<!-- footnote-source: insider-compiler-ch9.md; id: ch9-dps -->

**R27**　原书引用 Shaikhha 等人在 ACM SIGPLAN FHPC 2017 发表的 *Destination-passing style for efficient memory management*，并给出 [DPS 稿件链接](https://www.microsoft.com/en-us/research/wp-content/uploads/2016/11/dps-submitted.pdf)，记载访问时间为 2025 年 3 月。该链接所载稿件的标题为 *Using Destination-Passing Style to Compile a Functional Language into Efficient Low-Level Code*；书目标题与链接版本不同，见校订记录。

来源：[第9章 优化方言](insider-compiler-ch9.md)，脚注标识 `ch9-dps`。

<a id="fn-ch9-bufferization-doc"></a>
<!-- footnote-source: insider-compiler-ch9.md; id: ch9-bufferization-doc -->

**R28**　[Bufferization 官方文档](https://mlir.llvm.org/docs/Bufferization/)，原书记载访问时间为 2025 年 3 月；本章 API 以本地 LLVM 18.1.8 源码为准。

来源：[第9章 优化方言](insider-compiler-ch9.md)，脚注标识 `ch9-bufferization-doc`。

<a id="fn-ch9-ownership-doc"></a>
<!-- footnote-source: insider-compiler-ch9.md; id: ch9-ownership-doc -->

**R29**　[Ownership-based Buffer Deallocation 官方文档](https://mlir.llvm.org/docs/OwnershipBasedBufferDeallocation/)，原书记载访问时间为 2025 年 3 月。

来源：[第9章 优化方言](insider-compiler-ch9.md)，脚注标识 `ch9-ownership-doc`。

<a id="fn-ch9-bufferization-talk"></a>
<!-- footnote-source: insider-compiler-ch9.md; id: ch9-bufferization-talk -->

**R30**　[Matthias Springer、Martin Erhart：LLVM Dev Meeting Bufferization](https://m-sp.org/downloads/llvm_dev_2023.pdf)，原书记载访问时间为 2025 年 3 月。

来源：[第9章 优化方言](insider-compiler-ch9.md)，脚注标识 `ch9-bufferization-talk`。

### 第10章 结构方言与数据方言

<a id="fn-ch10-4"></a>
<!-- footnote-source: insider-compiler-ch10.md; id: ch10-4 -->

**R31**　原书提示 LLVM 后端还有许多针对分支指令的窥孔优化，可参考《深入理解 LLVM：代码生成》第11章。

来源：[第10章 结构方言与数据方言](insider-compiler-ch10.md)，脚注标识 `ch10-4`。

<a id="fn-ch10-5"></a>
<!-- footnote-source: insider-compiler-ch10.md; id: ch10-5 -->

**R32**　原书参考链接：[相关控制流结构化论文](https://static.googleusercontent.com/media/research.google.com/zh-CN//pubs/archive/43246.pdf)，原书访问时间为2025年4月。

来源：[第10章 结构方言与数据方言](insider-compiler-ch10.md)，脚注标识 `ch10-5`。

<a id="fn-ch10-6"></a>
<!-- footnote-source: insider-compiler-ch10.md; id: ch10-6 -->

**R33**　原书参考链接：[Lifting CFGs，2024年 LLVM 峰会幻灯片](https://llvm.org/devmtg/2024-04/slides/TechnicalTalks/Bock-LiftingCFGs.pdf)，原书访问时间为2025年4月。

来源：[第10章 结构方言与数据方言](insider-compiler-ch10.md)，脚注标识 `ch10-6`。

<a id="fn-ch10-7"></a>
<!-- footnote-source: insider-compiler-ch10.md; id: ch10-7 -->

**R34**　原书参考链接：[TACO 项目](http://tensor-compiler.org)，原书访问时间为2025年3月。

来源：[第10章 结构方言与数据方言](insider-compiler-ch10.md)，脚注标识 `ch10-7`。

<a id="fn-ch10-8"></a>
<!-- footnote-source: insider-compiler-ch10.md; id: ch10-8 -->

**R35**　原书引用 Fredrik Berg Kjolstad 于2020年发表的博士论文 [Sparse Tensor Algebra Compilation](https://tensor-compiler.org/files/kjolstad-phd-thesis-taco-compiler.pdf)，原书访问时间为2025年3月。

来源：[第10章 结构方言与数据方言](insider-compiler-ch10.md)，脚注标识 `ch10-8`。

### 第11章 目标输出方言

<a id="fn-ch11-mojo"></a>
<!-- footnote-source: insider-compiler-ch11.md; id: ch11-mojo -->

**R36**　原书参考资料：[What We Learned Building the Mojo Optimization Pipeline](https://llvm.org/devmtg/2024-10/slides/techtalk/Weiwei-What-We-Learned-Building-Mojo-OptimizationPipeline.pdf)，原书记载 2026 年 1 月访问。

来源：[第11章 目标输出方言](insider-compiler-ch11.md)，脚注标识 `ch11-mojo`。

<a id="fn-ch11-sme"></a>
<!-- footnote-source: insider-compiler-ch11.md; id: ch11-sme -->

**R37**　原书参考资料：[Arm Scalable Matrix Extension introduction](https://community.arm.com/arm-community-blogs/b/architectures-and-processors-blog/posts/arm-scalable-matrix-extension-introduction) 及[第二部分](https://community.arm.com/arm-community-blogs/b/architectures-and-processors-blog/posts/arm-scalable-matrix-extension-introduction-p2)，原书记载 2025 年 7 月访问。

来源：[第11章 目标输出方言](insider-compiler-ch11.md)，脚注标识 `ch11-sme`。

### 第12章 元编程方言

<a id="fn-ch12-1"></a>
<!-- footnote-source: insider-compiler-ch12.md; id: ch12-1 -->

**R38**　原书参考：[Transform 教程](https://mlir.llvm.org/docs/Tutorials/transform/)，2025 年 3 月访问。

来源：[第12章 元编程方言](insider-compiler-ch12.md)，脚注标识 `ch12-1`。

<a id="fn-ch12-2"></a>
<!-- footnote-source: insider-compiler-ch12.md; id: ch12-2 -->

**R39**　[ACM 文献（DOI：10.1145/3696443.3708922）](https://dl.acm.org/doi/pdf/10.1145/3696443.3708922)。原书仅给出 DOI 链接，标注2025年3月访问；现有脚注与校订记录未提供可确认的作者、题名，故保留 DOI 作为检索入口。

来源：[第12章 元编程方言](insider-compiler-ch12.md)，脚注标识 `ch12-2`。

<a id="fn-ch12-3"></a>
<!-- footnote-source: insider-compiler-ch12.md; id: ch12-3 -->

**R40**　原书说明：该算法由两位中国学者于 1965 年最早提出；参考 [Edmonds 算法](https://en.wikipedia.org/wiki/Edmonds%27_algorithm)，2025 年 3 月访问。这里保留原书的算法背景引用，本地源码将其用于多根模式的根顺序规划。

来源：[第12章 元编程方言](insider-compiler-ch12.md)，脚注标识 `ch12-3`。

<a id="fn-ch12-4"></a>
<!-- footnote-source: insider-compiler-ch12.md; id: ch12-4 -->

**R41**　原书参考：[MLIR 字节码格式](https://mlir.llvm.org/docs/BytecodeFormat/)，2025 年 3 月访问。

来源：[第12章 元编程方言](insider-compiler-ch12.md)，脚注标识 `ch12-4`。

<a id="fn-ch12-5"></a>
<!-- footnote-source: insider-compiler-ch12.md; id: ch12-5 -->

**R42**　原书参考：[Google Slides 演示文稿](https://docs.google.com/presentation/d/1U3AHtvn_ONR2D4-ENbghYjqsgocu0VPw_2LLYj_A7Sc/edit#slide=id.g7bb0231ec8_1_105)，2025 年 3 月访问。链接按扫描件重建，本次访问未取得内容；长标识中 `0`/`O` 等字符及资料可访问性仍待核实，见校订记录。

来源：[第12章 元编程方言](insider-compiler-ch12.md)，脚注标识 `ch12-5`。

<a id="fn-ch12-6"></a>
<!-- footnote-source: insider-compiler-ch12.md; id: ch12-6 -->

**R43**　原书参考：[PDLL 文档](https://mlir.llvm.org/docs/PDLL/)，2025 年 3 月访问。

来源：[第12章 元编程方言](insider-compiler-ch12.md)，脚注标识 `ch12-6`。

<a id="fn-ch12-7"></a>
<!-- footnote-source: insider-compiler-ch12.md; id: ch12-7 -->

**R44**　原书参考：[IRDL: A Dialect for Dialects](https://llvm.org/devmtg/2022-11/slides/TechTalk17-IRDL-ADialectForDialects.pdf)，2025 年 3 月访问。

来源：[第12章 元编程方言](insider-compiler-ch12.md)，脚注标识 `ch12-7`。

### 第三部分 MLIR 实战项目剖析

<a id="fn-part3-triton"></a>
<!-- footnote-source: insider-compiler-part3.md; id: part3-triton -->

**R45**　原书分析版本对应的提交为 [`47fc046ff29c9ea2ee90e987c39628a540603c8f`](https://github.com/triton-lang/triton/commit/47fc046ff29c9ea2ee90e987c39628a540603c8f)。本次已取得该提交的官方源码，用于[第 13 章](insider-compiler-ch13.md)校订；其 LLVM 依赖由源码中的 `cmake/llvm-hash.txt` 单独锁定，不能直接视为本地 LLVM 18.1.8。

来源：[第三部分 MLIR 实战项目剖析](insider-compiler-part3.md)，脚注标识 `part3-triton`。

### 第13章 Triton DSL 的设计与编译优化

<a id="fn-ch13-tail-performance"></a>
<!-- footnote-source: insider-compiler-ch13.md; id: ch13-tail-performance -->

**R46**　原书引用 PyTorch 博客 [CUDA-free inference for LLMs](https://pytorch.org/blog/cuda-free-inference-for-llms/)，2025 年 5 月访问。约 80% 指文中 Llama 3 8B、Granite 8B 在 H100/A100 上特定配置的历史端到端推理实验，不能当作所有 Triton 单算子相对 CUDA 手工算子的固定性能比。具体口径见[脚注核验](issues/evidence/ch13-tail/future-review.md)。

来源：[第13章 Triton DSL 的设计与编译优化](insider-compiler-ch13.md)，脚注标识 `ch13-tail-performance`。

<a id="fn-ch13-tail-intel"></a>
<!-- footnote-source: insider-compiler-ch13.md; id: ch13-tail-intel -->

**R47**　[Intel XPU Backend for Triton](https://github.com/intel/intel-xpu-backend-for-triton)，原书注明 2025 年 5 月访问。

来源：[第13章 Triton DSL 的设计与编译优化](insider-compiler-ch13.md)，脚注标识 `ch13-tail-intel`。

<a id="fn-ch13-tail-shared"></a>
<!-- footnote-source: insider-compiler-ch13.md; id: ch13-tail-shared -->

**R48**　[Microsoft triton-shared](https://github.com/microsoft/triton-shared)，原书注明 2025 年 5 月访问。

来源：[第13章 Triton DSL 的设计与编译优化](insider-compiler-ch13.md)，脚注标识 `ch13-tail-shared`。

<a id="fn-ch13-tail-cambricon"></a>
<!-- footnote-source: insider-compiler-ch13.md; id: ch13-tail-cambricon -->

**R49**　[Cambricon triton-linalg](https://github.com/Cambricon/triton-linalg)，原书注明 2025 年 5 月访问。

来源：[第13章 Triton DSL 的设计与编译优化](insider-compiler-ch13.md)，脚注标识 `ch13-tail-cambricon`。

<a id="fn-ch13-tail-mtia"></a>
<!-- footnote-source: insider-compiler-ch13.md; id: ch13-tail-mtia -->

**R50**　原书引用 [Google Slides 幻灯片](https://docs.google.com/presentation/d/1Cd-X30A7c4sdjoK20GdEsDV3qHm9jglD/edit#slide=id.p13)，注明 2025 年 5 月访问。链接按扫描最佳目视结果转写，长标识仍可能有易混字符，本次未能取得其内容。已核到固定提交的 [2023 年开发者会议议程](https://github.com/triton-lang/triton/blob/47fc046ff29c9ea2ee90e987c39628a540603c8f/docs/meetups/dev-meetup-2023.md) 包含 Meta 作者的 MTIA 议题，可佐证名称和已有工作，但不能替代对原幻灯片全文的核对。原链接候选与未确认范围保留在[校订记录](issues/ch13.md#ch13-tail-future)。

来源：[第13章 Triton DSL 的设计与编译优化](insider-compiler-ch13.md)，脚注标识 `ch13-tail-mtia`。

<a id="fn-ch13-tail-amd"></a>
<!-- footnote-source: insider-compiler-ch13.md; id: ch13-tail-amd -->

**R51**　原书引用 AMD 博客 [Unlock Peak Performance on AMD GPUs with Triton Kernel Optimizations](https://rocm.blogs.amd.com/software-tools-optimization/kernel-development-optimizations-with-triton-on-/README.html)，注明 2025 年 5 月访问。其关于 AMD 编译流程的介绍与本节相关；2024 年 3 月已合入上游的时间依据来自正文另引的 AMD 官方公告。

来源：[第13章 Triton DSL 的设计与编译优化](insider-compiler-ch13.md)，脚注标识 `ch13-tail-amd`。

<a id="fn-ch13-tail-paper"></a>
<!-- footnote-source: insider-compiler-ch13.md; id: ch13-tail-paper -->

**R52**　[ML-Triton, A Multi-Level Compilation and Language Extension to Triton GPU Programming](https://arxiv.org/abs/2503.14985v1)，原书注明 2025 年 5 月访问；本次按 2025 年 3 月的论文版本核对。硬件、软件、几何平均及具体类别的结果边界见[脚注核验](issues/evidence/ch13-tail/future-review.md)。

来源：[第13章 Triton DSL 的设计与编译优化](insider-compiler-ch13.md)，脚注标识 `ch13-tail-paper`。

### 第15章 整数规划求解方法

<a id="fn-ch15-simplex-tool"></a>
<!-- footnote-source: insider-compiler-ch15.md; id: ch15-simplex-tool -->

**R53**　原书实践参考：[在线单纯形计算工具](https://cbom.atozmath.com/CBOM/Simplex.aspx?q=sm)，作者于2024年11月访问。本次校订使用本地精确分数计算复核，不以该在线工具的当前行为作为验证依据。

来源：[第15章 整数规划求解方法](insider-compiler-ch15.md)，脚注标识 `ch15-simplex-tool`。

<a id="fn-ch15-coalesce"></a>
<!-- footnote-source: insider-compiler-ch15.md; id: ch15-coalesce -->

**R54**　Sven Verdoolaege，[*Integer Set Coalescing*](https://www.impact-workshop.org/impact2015/papers/impact2015-verdoolaege.pdf)，IMPACT 2015。原书将会议名称拼入论文标题，现分开。

来源：[第15章 整数规划求解方法](insider-compiler-ch15.md)，脚注标识 `ch15-coalesce`。

<a id="fn-ch15-gbr"></a>
<!-- footnote-source: insider-compiler-ch15.md; id: ch15-gbr -->

**R55**　William Cook、Thomas Rutherford、Herbert E. Scarf、David Shallcross，*An Implementation of the Generalized Basis Reduction Algorithm for Integer Programming*，*ORSA Journal on Computing*，1993。原书漏列 Shallcross；[作者所在机构保存的1991年讨论稿](https://elischolar.library.yale.edu/cowles-discussion-paper-series/1233/)给出完整作者名单。

来源：[第15章 整数规划求解方法](insider-compiler-ch15.md)，脚注标识 `ch15-gbr`。

<a id="fn-ch15-feautrier"></a>
<!-- footnote-source: insider-compiler-ch15.md; id: ch15-feautrier -->

**R56**　Paul Feautrier，[*Parametric Integer Programming*](https://www.numdam.org/item/RO_1988__22_3_243_0/)，*RAIRO. Operations Research*，22(3)，1988，243–268。修复原书标题结尾漏字。

来源：[第15章 整数规划求解方法](insider-compiler-ch15.md)，脚注标识 `ch15-feautrier`。

<a id="fn-ch15-further"></a>
<!-- footnote-source: insider-compiler-ch15.md; id: ch15-further -->

**R57**　原书在一条脚注中合列以下三项，按现有校订记录展开：

- Sven Verdoolaege，*barvinok: User Guide*。原书标为2024年版本，具体版号仍待核实。
- Alexander Barvinok、James E. Pommersheim，*An Algorithmic Theory of Lattice Points in Polyhedra*，1999，收于 *New Perspectives in Algebraic Combinatorics*，卷38，91–147页。原书将书名误写为 *New Perspectives in Geometric Combinatorics*，且误称为期刊。
- Rui-Juan Jing、Marc Moreno Maza，*Computing the Integer Points of a Polyhedron, I: Algorithm*，CASC 2017，LNCS 10490，225–241页，DOI：`10.1007/978-3-319-66320-3_17`。

原书第三项所配“2019、ACM Communications in Computer Algebra”对应另一篇题名不带“I: Algorithm”的 *Computing the Integer Points of a Polyhedron*，DOI：`10.1145/3338637.3338642`，卷52(4)，126–129页；卷年与上线年不同。两项出版信息应分开使用。详细依据见[参考资料的对应关系](issues/ch15.md#ch15-references)。

来源：[第15章 整数规划求解方法](insider-compiler-ch15.md)，脚注标识 `ch15-further`。

### 附录 其他方言

<a id="fn-appendix-1"></a>
<!-- footnote-source: insider-compiler-appendix.md; id: appendix-1 -->

**R58**　Juneyoung Lee，[*Undef and Poison: Present and Future*](https://llvm.org/devmtg/2020-09/slides/Lee-UndefPoison.pdf)。原书标注“2025 年 3 月访问”；这里保留原书访问时间，不将其当作本次校订的访问日期。

来源：[附录 其他方言](insider-compiler-appendix.md)，脚注标识 `appendix-1`。

## 说明性脚注

以下保留校订后的完整说明。这些脚注同样属于原书内容，按 N 编号汇总。

### 第1章 绪论

<a id="fn-ch1-tf-history"></a>
<!-- footnote-source: insider-compiler-ch1.md; id: ch1-tf-history -->

**N01**　原书注：这是截至作者写作时概括的流程，TensorFlow社区正在向MLIR方向改进。本次保留其历史归属；不同项目的集成和接口各有版本范围，图不作为当前完整部署指南。

来源：[第1章 绪论](insider-compiler-ch1.md)，脚注标识 `ch1-tf-history`。

<a id="fn-ch1-hlo"></a>
<!-- footnote-source: insider-compiler-ch1.md; id: ch1-hlo -->

**N02**　XLA（Accelerated Linear Algebra，加速线性代数）是OpenXLA生态中的机器学习编译器；HLO（High Level Operations，高层操作）是其高层计算表示。HLO与StableHLO相关，但不是可以不分版本直接互换的同一名称。

来源：[第1章 绪论](insider-compiler-ch1.md)，脚注标识 `ch1-hlo`。

<a id="fn-ch1-polyhedral"></a>
<!-- footnote-source: insider-compiler-ch1.md; id: ch1-polyhedral -->

**N03**　原书关于多面体编译的说明应以**循环归纳变量**为主，而非把所有循环索引称为归约变量。在适当的仿射循环边界和条件限制下，多重循环的整数迭代点可用多面体/整数集建模，并用于分析与变换。并非所有循环都满足该模型。原书将在第14章展开讨论。

来源：[第1章 绪论](insider-compiler-ch1.md)，脚注标识 `ch1-polyhedral`。

### 第2章 MLIR 概述

<a id="fn-ch2-block"></a>
<!-- footnote-source: insider-compiler-ch2.md; id: ch2-block -->

**N04**　MLIR 中统一使用“块”，而不是“基本块”。本书为了方便读者理解使用“基本块”这一术语，只有在特别语境下才会使用“块”这一术语，请读者注意区分。

来源：[第2章 MLIR 概述](insider-compiler-ch2.md)，脚注标识 `ch2-block`。

<a id="fn-ch2-graph-block"></a>
<!-- footnote-source: insider-compiler-ch2.md; id: ch2-graph-block -->

**N05**　特别提示：这里是说块而非基本块，原因是块里面的操作执行顺序和传统意义上基本块内的执行顺序不一致。

来源：[第2章 MLIR 概述](insider-compiler-ch2.md)，脚注标识 `ch2-graph-block`。

<a id="fn-ch2-reduce"></a>
<!-- footnote-source: insider-compiler-ch2.md; id: ch2-reduce -->

**N06**　开发者也可以定义自己的 reduce 工具，以便进行问题定位，如 IREE 项目中的 `iree-reduce` 工具。

来源：[第2章 MLIR 概述](insider-compiler-ch2.md)，脚注标识 `ch2-reduce`。

### 第3章 类型、属性、操作和方言详解

<a id="fn-ch3-type-name"></a>
<!-- footnote-source: insider-compiler-ch3.md; id: ch3-type-name -->

**N07**　原书说明：这里所有的类型都使用小写字母开头，主要是为了和 MLIR 代码保持一致。它们在对应的 C++ 代码中通常以大写字母开头。校订补充：概念名不一定就是汇编拼写，例如 `bfloat16` 对应 `bf16`，整数类型使用 `i32`、`si32`、`ui32` 等形式。

来源：[第3章 类型、属性、操作和方言详解](insider-compiler-ch3.md)，脚注标识 `ch3-type-name`。

<a id="fn-ch3-record-comments"></a>
<!-- footnote-source: insider-compiler-ch3.md; id: ch3-record-comments -->

**N08**　记录首行的继承信息是 `mlir-tblgen` 输出中的原有内容，后续解释性注释为笔者添加。后面章节还会出现类似情况，不再赘述。

来源：[第3章 类型、属性、操作和方言详解](insider-compiler-ch3.md)，脚注标识 `ch3-record-comments`。

### 第4章 谓词、特质和接口

<a id="fn-ch4-float"></a>
<!-- footnote-source: insider-compiler-ch4.md; id: ch4-float -->

**N09**　`F16` 和 `F32` 是 MLIR 社区定义的浮点数类型约束，其记录中的 `cppClassName` 为 `::mlir::FloatType`，位宽分别为 16 位和 32 位；具体 C++ 类型分别为 `Float16Type` 和 `Float32Type`。

来源：[第4章 谓词、特质和接口](insider-compiler-ch4.md)，脚注标识 `ch4-float`。

<a id="fn-ch4-verification"></a>
<!-- footnote-source: insider-compiler-ch4.md; id: ch4-verification -->

**N10**　验证内容不仅涵盖输入、输出类型，还涉及区域个数、后继基本块信息、属性以及谓词特质信息。

来源：[第4章 谓词、特质和接口](insider-compiler-ch4.md)，脚注标识 `ch4-verification`。

### 第5章 Pass 系统的工作流程

<a id="fn-ch5-dialects"></a>
<!-- footnote-source: insider-compiler-ch5.md; id: ch5-dialects -->

**N11**　毕竟，MLIR 框架提供的 `mlir-opt`、`mlir-translate` 等工具在开始执行前都会初始化 MLIRContext 并注册相应的方言，主要原因有两个：其一，这些工具在解析 IR 时依赖对应的方言，若缺少相应方言且未允许未注册方言，便无法识别操作，进而报错；其二，在进行变换或方言降级操作时同样常常依赖其他方言，这是由于在变换和降级过程中会生成其他方言中的操作。注册到 DialectRegistry 与实际加载到 MLIRContext 是不同的步骤。

来源：[第5章 Pass 系统的工作流程](insider-compiler-ch5.md)，脚注标识 `ch5-dialects`。

<a id="fn-ch5-order"></a>
<!-- footnote-source: insider-compiler-ch5.md; id: ch5-order -->

**N12**　最常见的问题出现在方言降级过程中，这部分内容将在第6章介绍。方言降级同样基于 Pass 框架实现，这一过程需要考虑类型因素，而不同的 Pass 执行顺序可能导致类型或操作未被转换为后续 Pass 所要求的形式，进而导致降级失败。类型本身不会仅因 Pass 的排序而从 MLIRContext 中消失。

来源：[第5章 Pass 系统的工作流程](insider-compiler-ch5.md)，脚注标识 `ch5-order`。

<a id="fn-ch5-locality"></a>
<!-- footnote-source: insider-compiler-ch5.md; id: ch5-locality -->

**N13**　这种设计有利于同一操作在不同 Pass 之间实现数据复用。当然，另一种可能的方案是按 Pass 遍历操作，即依次对每个 Pass 执行所有适用操作。此方案虽可行，但可能对缓存不太友好。

来源：[第5章 Pass 系统的工作流程](insider-compiler-ch5.md)，脚注标识 `ch5-locality`。

<a id="fn-ch5-isolated"></a>
<!-- footnote-source: insider-compiler-ch5.md; id: ch5-isolated -->

**N14**　若违反此要求，将会出现类似 `trying to schedule a pass on an operation not marked as IsolatedFromAbove` 的错误。该约束避免嵌套变换意外修改或遍历上层 SSA 值的使用链。它并不表示“Pass Pipeline 中的 Pass 不能实现跨 Pass 优化”；多个 Pass 可以通过 IR 变换及正确保留的分析结果协作，需要更大修改范围的优化应选择合适的上层锚点。读者需要知晓 Pass 的要求，并非任意操作都能作为 Pass 的锚点。[校订依据](issues/ch5.md#ch5-constraints)

来源：[第5章 Pass 系统的工作流程](insider-compiler-ch5.md)，脚注标识 `ch5-isolated`。

### 第6章 操作匹配与重写机制

<a id="fn-ch6-regions"></a>
<!-- footnote-source: insider-compiler-ch6.md; id: ch6-regions -->

**N15**　虽然 MLIR 中的区域可分为 CFG（控制流图，亦称 SSACFG）和图两种类型，但许多常见区域属于 CFG 区域。图区域适用于对操作执行顺序无严格要求的场景，例如顶级模块（module）操作。在该模块中，所包含的 global（全局定义）和 func（函数）等子操作之间并无由文本先后次序确定的执行依赖关系，因此 builtin.module 使用 Graph 类型的区域。符号引用等联系仍然可以存在。

来源：[第6章 操作匹配与重写机制](insider-compiler-ch6.md)，脚注标识 `ch6-regions`。

<a id="fn-ch6-traversal"></a>
<!-- footnote-source: insider-compiler-ch6.md; id: ch6-traversal -->

**N16**　默认采用自底向上的初始遍历方式，因为这种方式可能匹配到更大的模式；自顶向下的遍历通常有利于降低编译开销。具体结果和速度取决于 IR、模式集合及驱动配置，不能保证某一种方式总是更好。

来源：[第6章 操作匹配与重写机制](insider-compiler-ch6.md)，脚注标识 `ch6-traversal`。

### 第7章 MLIR 中常见的通用优化技术

<a id="fn-ch7-passnames"></a>
<!-- footnote-source: insider-compiler-ch7.md; id: ch7-passnames -->

**N17**　原书说明本章所提优化方法名为小写的 Pass 控制选项名。本稿按本地 `Passes.td` 修正了选项名，算法简称与版本差异另作标注。

来源：[第7章 MLIR 中常见的通用优化技术](insider-compiler-ch7.md)，脚注标识 `ch7-passnames`。

### 第10章 结构方言与数据方言

<a id="fn-ch10-1"></a>
<!-- footnote-source: insider-compiler-ch10.md; id: ch10-1 -->

**N18**　原书说明结构化编程与非结构化编程可以相互转化，包含 goto 的代码可通过相应方法消除 goto。转换可能需要增加状态变量或更复杂的结构，但代码复杂度并非在每个例子中都必然很高。

来源：[第10章 结构方言与数据方言](insider-compiler-ch10.md)，脚注标识 `ch10-1`。

<a id="fn-ch10-2"></a>
<!-- footnote-source: insider-compiler-ch10.md; id: ch10-2 -->

**N19**　例如，两个循环即使上下界相同，若其中一个包含提前退出的 break，而另一个不包含，也通常不能直接合并；否则，合并后的提前退出可能改变原本没有 break 的循环的语义。

来源：[第10章 结构方言与数据方言](insider-compiler-ch10.md)，脚注标识 `ch10-2`。

<a id="fn-ch10-3"></a>
<!-- footnote-source: insider-compiler-ch10.md; id: ch10-3 -->

**N20**　原书用此例区分优化和变换：优化通常自动选择满足条件的机会，Transform 则允许根据目标 IR 上下文进行定制。两者都必须遵守语义前提；不能把“优化可用于任意场景”理解为无需合法性检查。

来源：[第10章 结构方言与数据方言](insider-compiler-ch10.md)，脚注标识 `ch10-3`。

### 第11章 目标输出方言

<a id="fn-ch11-pointer"></a>
<!-- footnote-source: insider-compiler-ch11.md; id: ch11-pointer -->

**N21**　原书脚注把这些操作数概括为“指向一块内存地址的虚拟寄存器”。更准确地说，地址操作数是指针值，可指向堆、栈、全局存储等；`store` 的待存值并不一定是指针，LLVM IR 中的指针值也不必来自虚拟寄存器，例如可直接使用全局符号。描述符的 `allocatedPtr` 同样不限定来自 `malloc()`。

来源：[第11章 目标输出方言](insider-compiler-ch11.md)，脚注标识 `ch11-pointer`。

### 第13章 Triton DSL 的设计与编译优化

<a id="fn-ch13-bank"></a>
<!-- footnote-source: insider-compiler-ch13.md; id: ch13-bank -->

**N22**　原书关于共享内存 bank 冲突的注释：共享内存按 bank 组织，线程束内对同一 bank 不同字的访问可能需要分多次处理，降低有效带宽。原注把“4 字节 bank 宽度”仅限定为 Ampere 之前不准确；现代 NVIDIA 架构也需按其实际 bank 数、字宽和访问事务分析。多个线程读取同一字可使用广播等机制，不能把它与访问同一 bank 的不同字混淆。[硬件依据](issues/ch13.md#ch13-programming-model)。

来源：[第13章 Triton DSL 的设计与编译优化](insider-compiler-ch13.md)，脚注标识 `ch13-bank`。

<a id="fn-ch13-swizzle"></a>
<!-- footnote-source: insider-compiler-ch13.md; id: ch13-swizzle -->

**N23**　原书注：这里介绍的是 shared 布局的一种带参数实现形式。

来源：[第13章 Triton DSL 的设计与编译优化](insider-compiler-ch13.md)，脚注标识 `ch13-swizzle`。

### 第14章 多面体编译理论概述

<a id="fn-ch14-1"></a>
<!-- footnote-source: insider-compiler-ch14.md; id: ch14-1 -->

**N24**　此处讨论普通内存依赖：相关访问命中同一内存位置，且至少一次访问为写，并符合所分析的执行顺序。只有读—读关系通常不阻止并行，单纯“数组名相同”也不足以判断依赖。

来源：[第14章 多面体编译理论概述](insider-compiler-ch14.md)，脚注标识 `ch14-1`。

<a id="fn-ch14-2"></a>
<!-- footnote-source: insider-compiler-ch14.md; id: ch14-2 -->

**N25**　可把两个访问分别看作整数迭代到数组坐标的映射 `y₁=a*i+b`、`y₂=c*j+d`。要求 `y₁=y₂` 得到 `a*i−c*j=d−b`，其中 `i`、`j` 是独立变量。原脚注把它们误写为同一个 `i`，再用两条直线相交解释 GCD 条件；这是两个不同问题。整除保证的是无界二元整数方程存在解，还需另行检查循环边界与顺序。

来源：[第14章 多面体编译理论概述](insider-compiler-ch14.md)，脚注标识 `ch14-2`。

<a id="fn-ch14-3"></a>
<!-- footnote-source: insider-compiler-ch14.md; id: ch14-3 -->

**N26**　若 `f` 为凹函数，与仿射映射复合得到的 `g` 也为凹函数。凹函数定义为：在凸域 `C` 上，对任意 `x,y∈C`、`α∈[0,1]`，有 `f(αx+(1−α)y)≥αf(x)+(1−α)f(y)`。但原书“非凸非凹函数复合后仍非凸非凹”的结论不成立，例如 `f(x,y)=x²−y²` 限制到 `(t,0)` 后成为凸函数 `t²`。

来源：[第14章 多面体编译理论概述](insider-compiler-ch14.md)，脚注标识 `ch14-3`。

<a id="fn-ch14-4"></a>
<!-- footnote-source: insider-compiler-ch14.md; id: ch14-4 -->

**N27**　实现会检查归约使用链，识别支持的单一组合操作以及相应归约类型，并要求没有不允许的副作用等。归约结果通过循环终结操作传入下一次迭代。不能仅因代码中有一个加法，就认定任意 `iter_args` 都可以并行化。

来源：[第14章 多面体编译理论概述](insider-compiler-ch14.md)，脚注标识 `ch14-4`。

<a id="fn-ch14-5"></a>
<!-- footnote-source: insider-compiler-ch14.md; id: ch14-5 -->

**N28**　本地选项名为 `fusion-compute-tolerance`，成员为 `computeToleranceThreshold`，默认值 `0.30f`。通常候选选择使用的是 `additionalComputeFraction < computeToleranceThreshold`，因此准确说是额外计算比例**低于**默认约30%的阈值；它衡量动态操作成本估计，并非源码文本体积，最大化融合等模式还可能采用不同的选择策略。

来源：[第14章 多面体编译理论概述](insider-compiler-ch14.md)，脚注标识 `ch14-5`。

### 第15章 整数规划求解方法

<a id="fn-ch15-upper"></a>
<!-- footnote-source: insider-compiler-ch15.md; id: ch15-upper -->

**N29**　“上三角形式”指本例的系数矩阵经变换后，主对角线以下的系数都为零；更一般的非方阵或秩不足情形用行阶梯形描述。

来源：[第15章 整数规划求解方法](insider-compiler-ch15.md)，脚注标识 `ch15-upper`。

<a id="fn-ch15-symbols"></a>
<!-- footnote-source: insider-compiler-ch15.md; id: ch15-symbols -->

**N30**　参数的不同取值对应参数化集合或关系的不同实例（截面、纤维）；原书称为不同“切平面”，易与整数规划中排除分数解的割平面混淆。

来源：[第15章 整数规划求解方法](insider-compiler-ch15.md)，脚注标识 `ch15-symbols`。
