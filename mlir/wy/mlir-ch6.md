# 第 6 章 MLIR 在 IREE 框架中的应用

> 来源为 `mlir-ch6.pdf`（76 页），已完成全章逐页转写和目视核对。正文以原书为主，保留原例、代码和图示细节；明确错误就地校订，版本差异另作说明。MLIR 部分按本地源码静态核对；本仓库不含匹配版本的 IREE 实现，未执行 IREE 示例编译测试。具体依据见[复核记录](mlir-transcription-review.md)。

<!-- 原书第 224 页；PDF 第 2 页。PDF 第 1 页为章标题页。 -->

MLIR 提供了多层次表示能力，能够表示从高层次模型到低层次硬件代码的各种计算。通过 MLIR 实现的各种方言和优化 pass，开发者能够针对特定应用场景进行深度优化。MLIR 的模块化设计支持其与现有的 AI 框架无缝集成。例如，TensorFlow 已经将 MLIR 集成到其编译器栈中，以改进其图优化和硬件加速器支持。Triton 通过集成 MLIR 实现复杂张量操作和 pass 定义，并利用 MLIR 提供的优化和代码生成功能，将这些操作映射为 GPU 指令集。由此可见，将 MLIR 与其他 AI 编译框架集成，可以为 AI 模型编译带来更好的优化和性能提升、跨平台支持、一致性和可移植性。通过与不同框架集成，MLIR 可以扩展其应用范围，支持各种计算任务。

本章将围绕 MLIR 在 IREE 框架中的应用展开，主要分析在 IREE 框架中集成和应用 MLIR 的关键方法，以及针对 GPU 目标硬件的编译流程构建过程，并以 IREE 中的 CUDA 后端实现为分析对象，详细、完整地论述 IREE 通过 MLIR 支持 GPU 后端的实现方法，重点探讨矩阵乘操作相关的分块优化和代码生成过程。

本章 6.1 节介绍了 IREE 的整体编译流程、核心模块，以及 CUDA 目标后端的特点。6.2 节系统阐述了代码生成过程中的 pass 流水线配置方法，并结合缩并计算与流水线配置函数进行功能解析。6.3 节和 6.4 节深入剖析了 `TileAndDistributeToWorkgroups` 和 `LLVMGPUTileAndDistribute` 两个核心 pass 的工作流程，分别从设备级与工作组级分块的输入 IR、分块策略、循环分布方法到分块与融合的具体实现，具体说明 MLIR 在算子优化与任务映射中的作用。最后，6.5 节介绍了 MLIR 代码生成中与 GPU 后端相关的关键 pass，包括 `LLVMGPUTensorCoreVectorization` 与 `LLVMGPUVectorToGPU`，以全面展示 MLIR 在 IREE 中支持深度学习模型的编译优化路径。

## 6.1 IREE 简介

IREE（Intermediate Representation Execution Environment）是基于 MLIR 的统一编译器和运行时栈。IREE 将 MLIR 作为其核心中间表示框架，通过使用流水线结构和基于 MLIR 构建的优化 pass，IREE 可将各种深度学习模型作为输入，经过 MLIR 框架逐步将模型表示为各种 MLIR 方言，并最终递降为统一的 IR。该过程可支持深度学习模型的分析与优化，并为各种异构硬件生成可执行格式代码。IREE 的设计兼顾了模型的可移植性。一方面，IREE 可向上扩展以满足数据中心等更大部署目标的需求；另一方面，IREE 也能向下扩展以满足移动和边缘端部署的限制和特殊考虑（如最小化内存占用空间）。

### 6.1.1 IREE 编译流程及组成模块

IREE 官方定义的编译流程中，可以将 PyTorch、TensorFlow 等各种前端框架构建的模型作为输入。IREE 的入口方言（如 TOSA、MHLO 等）在张量操作级别对 AI 模型建模，IREE 遵循渐进递降方式，将较高级别表示的方言通过 Linalg 等中间方言转换为可执行二进制代码。

<!-- 原书第 225 页；PDF 第 3 页。 -->

Linalg 方言可表示完美嵌套循环计算，并实现嵌套循环的融合、分块、循环交换等转换（本章 6.4.1 节将对 Linalg 方言做进一步介绍）。Linalg 操作的分块转换可将计算分割成计算行为类似的较小数据分块。针对分块的计算可以并行执行，因此可以将其分配给不同的线程束或线程。每个分块计算封装在调度区域（dispatch region）内，以一个设备端工作负载在目标设备上执行，相互依赖的可融合算子也可合并到一个调度区域中。此时，计算被分成两部分执行，即对应分块计算的调度区域和指定调度区域执行顺序的主机端代码。其后的编译流程可以使用融合、循环交换等优化方法进一步对调度区域做转换，实现更好的缓存局部性和数据访问模式。

> 校订注：原书“以原子方式”在这里指把调度区域作为一个工作负载调度，不应理解为区域内所有内存访问构成硬件原子操作；分块间能否并行也需满足数据依赖及归约处理的要求。

Linalg 操作接下来被递降为 Vector 操作，并对模型各部分进行向量化建模。由第 4 章中 Vector 方言相关内容可知，该方言中的操作可在后续递降中映射到目标架构相关向量指令，其经过递降后的操作或指令可以使用目标架构的高效向量或张量读写指令和 DSA 指令。例如，Vector 操作 `vector.transfer_read` 可递降为 `nvgpu.ldmatrix` 操作，`vector.contract` 操作可递降为 `nvgpu.mma.sync` 操作。`nvgpu.ldmatrix` 操作和 `nvgpu.mma.sync` 操作都是针对 NVIDIA GPU 后端的矩阵操作。

> 校订注：保留原书这两条具体递降示例，但它们不是所有 `vector.transfer_read`／`vector.contract` 都适用的无条件替换；需要满足对应转换模式要求的形状、类型、布局等条件。Vector 方言本身也不等同于某一硬件指令集。

设备端编译的最后一步是将操作递降为 LLVM 方言操作，然后将其转换为对应的 LLVM IR。LLVM 编译器后端可以根据 LLVM IR 生成目标架构的二进制代码。LLVM 编译器后端的相关内容在本书介绍范围内。

经过上述编译流程输出的二进制代码中包含用于控制缓冲区设置的虚拟机（Virtual Machine，VM）命令和调度区域集合（即工作负载）。工作负载可以包含在静态或动态库中。静态工作负载库结合序列化 VM 字节码模块或 VM C/C++ 代码模块形成 IREE 模块。IREE 针对不同目标架构可生成不同的动态工作负载库，并在运行时根据实际需求选择使用合适的库。使用不同的部署策略分解 IREE 模块结构可以得到不同的 VM 命令实现格式（字节码或 C/C++ 代码）和工作负载实现格式（静态或动态库）。

IREE 运行时包括用于配置虚拟机的 IREE 运行时库、工作负载加载器和工作负载调度器。后两者被定义为设备硬件抽象层（Hardware Abstraction Layer，HAL）驱动程序。IREE 运行时使用虚拟机解释主机端程序指令。IREE 虚拟机支持加载（loads）、存储（stores）、算术运算、函数调用及控制流等通用操作。

在机器学习模型的推理过程中，密集计算（如矩阵乘、卷积等）通常由专门的 AI 硬件加速器（如 TPU）完成。各种 AI 硬件加速器虽然在并行计算方面非常强大，但依然需要由 CPU 通过运行时进行任务协调、资源管理和调度执行。IREE 运行时依赖虚拟机实现跨硬件环境的 AI 模型部署，或在单个节点上将操作分发到某个计算单元。虚拟化的主机端运行时抽象层可以统一不同 CPU 架构下的操作，同时通过严格控制和监控操作来提高安全性，并由主机虚拟指令集（virtual instruction set）实现的虚拟机命令，处理资源跟踪和管理，以及形状计算等逻辑操作。与此同时，虚拟机将密集计算工作负载转化为设备硬件抽象层命令缓冲区并分派到设备端执行。

虚拟机命令可以用 VM 方言或 EmitC 方言实现。VM 方言操作被序列化为在运行时解释的字节码模块，或被转换为 EmitC 操作后，通过 Cpp 发射器将 EmitC 操作转换为 C/C++ 代码。

<!-- 原书第 226 页；PDF 第 4 页。 -->

在计算和图形处理平台上，HAL 的作用是提供可以屏蔽底层硬件复杂性的抽象接口，使得开发者可以通过调用图形及计算 API 或指令，编写与硬件无关的代码并在不同的硬件平台上运行，而无须关心底层硬件的具体实现。HAL 负责抽象和继承这些 API 的优势，如低级别的显式控制、多平台和多供应商的本地支持等，并将 API 和指令映射到具体的硬件操作。因此，HAL 连接了跨平台高层应用和底层硬件，是系统架构中的关键角色。IREE 虚拟机与硬件抽象层的关系如图 6-1 所示。

**图 6-1 IREE 虚拟机与硬件抽象层的关系示意图。** 图中从上到下表示应用程序、主机端虚拟机、虚拟机命令以及两类执行路径。原图的全部节点关系如下：

```text
应用程序（密集计算、控制流等）
  ↓
主机端虚拟机
  ↓
虚拟机命令（虚拟指令集）
  ├─ 密集计算算子 → 设备端 HAL → CPU、GPU、…、TPU
  └─ 控制流等算子 → 主机端 HAL → CPU 0、CPU 1
```

> 图注说明：这是原书的逻辑分工示意，不表示所有主机端算术和控制流指令都必须通过 HAL 调用执行。主机 VM 执行程序控制逻辑，HAL 负责设备与可执行工作负载的交互。

IREE 功能较为复杂，由于篇幅所限，本章重点关注 IREE 设备端与张量核功能相关的部分，包括在 IREE 中如何针对张量核操作完成数据分块，如何配置和使用张量核，以及张量核相关操作的转换。通过这些内容，开发者可以理解 IREE 后端实现的基本方法，并能以 CUDA 后端实现方法作为参考，掌握大模型推理对 MLIR 技术栈的功能需求和代码生成的整体过程，从而在 IREE 框架上应用这些知识，定制开发适合特定 GPU 硬件的目标后端和相应的处理流程，并重点支持和完善 MLIR 的相关模块组件。

为了充分理解 MLIR 技术栈中与张量核相关的方言和 pass 的功能，本章以下各节将结合测试用例 `matmul_512x512_f16.mlir`，辅助分析 `linalg.matmul` 操作在 MLIR 技术栈中与张量核相关的方言及 pass 的转换代码实现和执行过程。`matmul_512x512_f16.mlir` 测试用例内容如下：

```mlir
func.func @matmul(%lhs : tensor<512x512xf16>,
                  %rhs : tensor<512x512xf16>) -> tensor<512x512xf16> {
  %c0 = arith.constant 0.0 : f16
  %empty = tensor.empty() : tensor<512x512xf16>
  %c = linalg.fill ins(%c0 : f16)
                  outs(%empty : tensor<512x512xf16>) -> tensor<512x512xf16>
  %0 = linalg.matmul
      ins(%lhs, %rhs : tensor<512x512xf16>, tensor<512x512xf16>)
      outs(%c : tensor<512x512xf16>) -> tensor<512x512xf16>
  return %0 : tensor<512x512xf16>
}
```

<!-- 原书第 227 页；PDF 第 5 页。上面的代码块跨页。 -->

上述测试用例中的 `linalg.matmul` 操作接收两个形状为 512×512 的 16 位浮点数张量作为输入，并返回一个形状为 512×512 的 16 位浮点数张量作为结果。

执行以下命令可得到本章分析所用输出日志文件 `512_after_all_cuda.log`：

```bash
iree-compile matmul_512x512_f16.mlir \
  --iree-hal-target-backends=cuda \
  --iree-hal-cuda-llvm-target-arch=sm_80 \
  -o - --mlir-print-ir-after-all &> 512_after_all_cuda.log
```

> 校订注：已修正扫描文本中 `iree-compile` 与输入文件之间缺少空格等排版问题。此命令按原书版本保留；`&>` 是 Bash/Zsh 的合并重定向语法，不是通用 POSIX `sh` 语法。`-o -` 还会把编译产物写到标准输出，因而该文件可能混有二进制内容。只希望收集文本 IR 日志时，可将 `-o -` 改为 `-o matmul.vmfb`，并用 `2> 512_after_all_cuda.log` 收集标准错误输出。这里未执行 IREE 编译，也未声称现有 IREE 安装支持这些历史选项。

### 6.1.2 IREE 中的 CUDA 目标后端

IREE 支持 CUDA、ROCm 等 GPU 硬件目标后端。CUDA 是英伟达 GPU 的并行计算平台和应用程序编程接口模型，而 ROCm（Radeon Open Compute Platform）的用途与 CUDA 类似，是由 AMD 开发并针对 AMD GPU 计算提供的平台生态系统和编程接口。在本章的 MLIR 递降路径中，NVVM 和 ROCDL 分别提供面向英伟达 GPU 和 AMD GPU 的低级方言操作表示，衔接相应的底层编译器和设备库支持，以便在这些 GPU 上执行模型，加速机器学习和深度学习工作负载。

> 校订注：原书在这里将 NVVM、ROCDL 都笼统称为“编译器基础设施和低级别组件”。本章代码直接使用的是 MLIR 中相应的方言；ROCDL 方言本身不是完整的 AMD 编译器后端。

由于 IREE 各个目标后端实现的代码结构和操作处理逻辑高度相似，本节主要以 CUDA 后端实现为例，详细分析其中涉及的关键方言，如 Linalg、SCF、Affine 等在 CUDA 后端中的作用，以及相关 pass 如何在编译过程中转换和优化代码。

在 IREE 中，`CUDASession` 结构体、`CUDATargetBackend` 类和 ConvertToNVVM pass 是本章所述 CUDA 编译路径的组成部分。三者功能和职责各不相同，但相互协同，完成 MLIR 中间表示的编译，为后续在 GPU 上执行编译结果提供支持。

`CUDASession` 是继承 IREE 插件会话类（`PluginSession`）的结构体，其核心方法 `populateHALTargetBackends()` 注册了名为 `cuda` 的目标后端（`CUDATargetBackend`）实例，并调用 `LLVMInitializeNVPTXTarget()` 等一系列初始化函数，配置 LLVM NVPTX 后端，使编译器能够将 LLVM IR 转换为 PTX 等后续 GPU 执行路径所需的目标表示。`CUDASession` 定义代码如下：

```cpp
struct CUDASession : public PluginSession<CUDASession, /* 原书省略 */ ...> {
  void populateHALTargetBackends(IREE::HAL::TargetBackendList &targets) {
    targets.add("cuda", [&]() {
      LLVMInitializeNVPTXTarget();
      // … 原书省略的其他初始化代码。
      return std::make_shared<CUDATargetBackend>(options);
    });
  }
};
```

> 校订注：这是原书的代码摘录，模板参数等省略部分使它不能独立编译。NVPTX 生成的 PTX 不等同于最终 GPU 机器码；不能把初始化 NVPTX 后端理解为它直接完成所有设备二进制生成步骤。

`CUDATargetBackend` 类是 IREE 中的具体后端实现，负责配置和管理将 MLIR 中间表示转换为 GPU 支持的低阶表示的编译流程。`CUDASession` 将 `CUDATargetBackend` 实例添加到目标列表 `targets` 中，确保 CUDA 后端功能在 IREE 编译过程中可用。

<!-- 原书第 228 页；PDF 第 6 页。上段跨页。 -->

`CUDATargetBackend` 类为生成 GPU 机器码提供了必要的可执行目标配置支持接口，如 `getDefaultExecutableTargets()`、`getExecutableTarget()`、`getDependentDialects()` 等。此外，`CUDATargetBackend` 类的两个重要接口是构建代码生成配置 pass 流水线的 `buildConfigurationPassPipeline()` 方法和构建翻译 pass 流水线的 `buildTranslationPassPipeline()` 方法。

IREE 代码生成阶段有多种不同代码生成流水线类型。代码生成配置 pass 流水线的一个重要功能是根据计算特征和硬件特性，配置代码生成流水线类型。不同的代码生成流水线类型以不同顺序执行不同 pass 集合，利用流水线类型对应的硬件特性生成高效可执行代码。

CUDA 后端的代码生成配置 pass 流水线函数调用关系如图 6-2 所示。

**图 6-2 CUDA 后端的配置 pass 流水线函数调用关系。** 图中的完整展开顺序如下；创建 pass 与 pass 执行是两个阶段，而不是创建函数立即直接调用 `runOnOperation()`：

```text
CUDATargetBackend::buildConfigurationPassPipeline()
  └─ buildLLVMGPUCodegenConfigurationPassPipeline()
       ├─ …（原图省略的其他配置步骤）
       └─ createLLVMGPUSelectLoweringStrategyPass()
            └─ [pass 执行] LLVMGPUSelectLoweringStrategyPass::runOnOperation()
                 ├─ initGPULaunchConfig()
                 │    ├─ setRootConfig()
                 │    ├─ setTranslationInfo()
                 │    ├─ propagateLoweringConfig()
                 │    └─ …
                 └─ …
```

构建代码生成配置 pass 流水线的 `buildConfigurationPassPipeline()` 方法在本书所述版本中的唯一功能是调用 `buildLLVMGPUCodegenConfigurationPassPipeline()` 函数，添加配置阶段需要指定的预处理 pass 和翻译策略选择 pass。6.2 节将详细分析该函数功能。

翻译 pass 流水线通过配置一系列 pass 将高阶计算图操作通过结构化操作路径递降到 NVVM 或 ROCDL 方言操作。构建翻译 pass 流水线的 `buildTranslationPassPipeline()` 方法的唯一功能是调用 `buildLLVMGPUCodegenPassPipeline()` 函数，该函数实现代码如下：

```cpp
void buildLLVMGPUCodegenPassPipeline(OpPassManager &pm, bool useROCM) {
  pm.addPass(createLLVMGPULowerExecutableTargetPass());
  OpPassManager &nestedModulePM = pm.nest<ModuleOp>();
  addLowerToLLVMGPUPasses(nestedModulePM, useROCM);
}
```

其中，`createLLVMGPULowerExecutableTargetPass()` 函数生成的 LLVMGPULowerExecutableTarget pass 可将高层次的 `hal.executable.variant` 内部计算先递降为标量或向量表示，然后递降为与特定 GPU 对应的 GPU 方言操作。这些 GPU 方言操作再由 `addLowerToLLVMGPUPasses()` 函数启动的 pass 递降到相应 GPU 平台的 NVVM 或 ROCDL 方言，以便将其进一步编译为 GPU 底层指令集。6.2 节中将进一步分析该函数的功能。

<!-- 原书第 229 页；PDF 第 7 页。上段跨页。 -->

上述 `buildLLVMGPUCodegenPassPipeline()` 函数调用的 `addLowerToLLVMGPUPasses()` 函数，除了添加访存模式、计算模式优化 pass 和 BF16 兼容性优化 pass 外，还根据 `useROCM` 参数确定递降目标是 NVVM 或 ROCDL，并添加将操作递降为 NVVM 或 ROCDL 的 pass。此处的 `addLowerToLLVMGPUPasses()` 函数仅支持 CUDA 和 ROCm 两种目标后端，开发者可根据需要增加新的目标后端支持。`addLowerToLLVMGPUPasses()` 函数实现代码如下：

```cpp
static void addLowerToLLVMGPUPasses(OpPassManager &pm, bool forROCDL) {
  // … 原书省略的前序 pass。
  if (forROCDL) {
    pm.addPass(createConvertToROCDLPass());
  } else {
    pm.addPass(createConvertToNVVMPass());
  }
}
```

上述 `createConvertToROCDLPass()` 函数和 `createConvertToNVVMPass()` 函数在前述 LLVMGPULowerExecutableTarget pass 转换结果的基础上，启动将 AMDGPU 方言操作和 NVGPU 方言操作转换到相应平台方言操作的核心递降 pass。其中，将 NVGPU 方言操作递降到 NVVM 方言操作的 ConvertToNVVM pass 代码定义如下：

```cpp
struct ConvertToNVVMPass : public ConvertToNVVMBase<ConvertToNVVMPass> {
  // …
  void runOnOperation() override {
    // … 原书在此省略 m、converter 等的准备代码。
    {
      RewritePatternSet llvmPatterns(&getContext());
      // …
      populateNVGPUToNVVMConversionPatterns(converter, llvmPatterns);
      // …
      LLVMConversionTarget target(getContext());
      // …
      if (failed(applyPartialConversion(m, target, std::move(llvmPatterns)))) {
        signalPassFailure();
      }
    }
    // …
  }
};
```

<!-- 原书第 230 页；PDF 第 8 页。 -->

从操作递降的层次顺序角度看，ConvertToNVVM pass 功能与前文 3.1.2 节和 4.3 节中介绍的 ConvertNVGPUToNVVM pass 类似，均通过调用 `populateNVGPUToNVVMConversionPatterns()` 函数向重写模式集合中添加 `MmaSyncOptoNVVM`、`MmaLdMatrixOpToNVVM` 等模式，目的是将 MLIR 表示中的 NVGPU 方言操作转换为 NVVM 方言操作。ConvertNVGPUToNVVM pass 功能介绍参见 4.4 节。

CUDA 后端的翻译 pass 流水线函数调用及对应方言如图 6-3 所示。

**图 6-3 CUDA 后端的翻译 pass 流水线函数与方言的对应关系。** 左侧保留以下调用／pass 创建关系：

```text
CUDATargetBackend::buildTranslationPassPipeline()
  └─ buildLLVMGPUCodegenPassPipeline()
       ├─ createLLVMGPULowerExecutableTargetPass()
       │    └─ [执行] LLVMGPULowerExecutableTargetPass::runOnOperation()
       │         ├─ addGPUMatmulTensorCoreMmaSyncPassPipeline()
       │         │    └─ …
       │         └─ addGPU*PassPipeline()（原图对其他流水线的统称）
       └─ addLowerToLLVMGPUPasses()
            └─ createConvertToNVVMPass()
                 └─ [执行] ConvertToNVVMPass::runOnOperation()
                      ├─ populateNVGPUToNVVMConversionPatterns()
                      └─ populate*()（原图对其他模式填充函数的统称）
```

右侧方言与 pass 的顺序为：

```text
TOSA 等高阶方言操作
  → TosaToLinalgNamed pass
  → Linalg
  → LLVMGPUTensorCoreVectorization pass
  → Vector
  → LLVMGPUVectorToGPU pass
  → NVGPU
  → ConvertToNVVM pass
  → NVVM
```

图中虚线框围住 `LLVMGPUTensorCoreVectorization pass → Vector → LLVMGPUVectorToGPU pass` 这一段，左侧 `addGPUMatmulTensorCoreMmaSyncPassPipeline()` 的箭头指向该框，表示这段转换属于对应张量核流水线。左侧 `populateNVGPUToNVVMConversionPatterns()` 的箭头指向右侧 ConvertToNVVM pass，表示其提供 NVGPU 到 NVVM 的转换模式。

图 6-3 左侧总结了从 `CUDATargetBackend::buildTranslationPassPipeline()` 函数启动 LLVMGPULowerExecutableTarget pass 和 ConvertToNVVM pass 涉及的函数调用流程。LLVMGPULowerExecutableTarget pass 根据不同代码生成流水线类型，调用对应的流水线配置函数，如 `addGPUMatmulTensorCorePassPipeline()` 等，再由流水线配置函数启动 Linalg 操作分块优化 pass、Linalg 操作到 Vector 操作递降 pass、Vector 操作到 NVGPU 操作递降 pass 等不同优化和递降 pass。ConvertToNVVM pass 则将 NVGPU 操作递降为 NVVM 操作。这些 pass 分别承担了操作向量化、GPU 操作优化、张量核功能使用和最终的 NVVM 操作转换任务，共同构成了从 TOSA 等高层领域相关方言到底层 NVVM 方言操作的递降过程。

图 6-3 右侧总结了由上述 `createLLVMGPULowerExecutableTargetPass()` 函数生成的 pass 根据配置选择的 LLVMGPUMatmulTensorCoreMmaSync pass 流水线（其中包括 LLVMGPUTensorCoreVectorization、LLVMGPUVectorToGPU 等 pass），以及由 `createConvertToNVVMPass()` 函数生成的 ConvertToNVVM pass 与 LLVM GPU 代码生成流水线中逐次递降路径上各方言的对应关系。

<!-- 原书第 231 页；PDF 第 9 页开头。上段跨页。 -->

LLVMGPUTensorCoreVectorization pass 和 LLVMGPUVectorToGPU pass 的工作流程将在 6.5 节中介绍。

## 6.2 代码生成配置 pass 流水线工作流程

CUDA 后端重写了 `buildTranslationPassPipeline()` 和 `buildConfigurationPassPipeline()` 函数。`buildTranslationPassPipeline()` 函数功能已在上一节中分析。

代码生成配置 pass 流水线的构建函数 `buildConfigurationPassPipeline()` 的唯一功能是调用 `buildLLVMGPUCodegenConfigurationPassPipeline()` 函数，设置预处理 pass 和翻译策略选择 pass。此处的预处理 pass 是指在目标相关的代码生成开始前应在后端执行完成的 pass。例如，从用户配置中提取递降配置和翻译信息的 MaterializeUserConfigs pass 等。此处的翻译策略选择 pass 是指针对 LLVMGPU（在 IREE 中，LLVMGPU 是指基于 LLVM 的 NVIDIA GPU 与 AMD GPU 后端的代码生成流水线体系）的递降策略选择 pass，例如，图 6-2 中的 LLVMGPUSelectLoweringStrategy pass。

LLVMGPUSelectLoweringStrategy pass 是 LLVMGPU 代码生成配置 pass 流水线的一部分，由 CUDA 后端调用 `buildLLVMGPUCodegenConfigurationPassPipeline()` 函数添加到 pass 管理器中。该 pass 在初始化 GPU 启动配置时，根据矩阵计算的数据类型、矩阵各维度大小、设备计算能力（如 `sm_75` 或 `sm_80` 等）、编译选项设置等条件，决定是否选用将 Vector 操作转换为 NVGPU 操作的路径，以及将 Vector 操作转换为何种 NVGPU 操作。

`buildLLVMGPUCodegenConfigurationPassPipeline()` 函数生成 LLVMGPUSelectLoweringStrategy pass 代码如下：

```cpp
void buildLLVMGPUCodegenConfigurationPassPipeline(OpPassManager &pm) {
  auto &nestedModulePM = pm.nest<ModuleOp>();
  // … 原书省略的其他配置 pass。
  pm.addPass(createLLVMGPUSelectLoweringStrategyPass());
}
```

### 6.2.1 缩并计算配置函数功能分析

由图 6-2 可见，LLVMGPUSelectLoweringStrategy pass 的主要功能是调用 `initGPULaunchConfig()` 函数，在为 IR 函数中的关键根操作推断合适执行配置时，调用 `setRootConfig()` 函数，为 `linalg.matmul` 操作转换为 Vector 操作尝试应用多种配置，如向量分布配置（Vector Distribution Config）、缩并流水线配置（Contraction Pipeline Configuration）、线程束归约流水线配置（Warp Reduction Pipeline Config）等。`setRootConfig()` 函数代码实现如下：

<!-- 原书第 232 页；PDF 第 10 页。上段跨页。 -->

```cpp
static LogicalResult setRootConfig(mlir::FunctionOpInterface entryPointFn,
                                   Operation *computeOp) {
  // …
  if (auto linalgOp = dyn_cast<linalg::LinalgOp>(computeOp)) {
    // … 原书在此省略 targetInfo 的准备及其他策略。
    if (succeeded(setContractConfig(entryPointFn, linalgOp, targetInfo))) {
      return success();
    }
    // …
  }
  // … 原书省略的其他分支及返回路径。
}
```

针对测试用例中的 `linalg.matmul` 计算，`setRootConfig()` 函数调用缩并计算配置函数 `setContractConfig()`，考虑运算类型、矩阵大小和目标硬件计算能力等因素，计算和选择与硬件功能和操作特征相符的矩阵乘计算配置。缩并计算配置函数中涉及的不同级别分块大小可根据操作维度的静态分析结果调整。`setContractConfig()` 函数代码实现如下：

```cpp
static LogicalResult setContractConfig(mlir::FunctionOpInterface entryPoint,
                                       linalg::LinalgOp op,
                                       const TargetInfo &targetInfo) {
  // … 原书省略 sizeM、sizeN、sizeK 以及 setMatmulConfig 的定义。
  bool isStaticSize = !ShapedType::isDynamic(sizeM) &&
                      !ShapedType::isDynamic(sizeN) &&
                      !ShapedType::isDynamic(sizeK);
  if (isStaticSize) {
    if (supportsTensorCore(entryPoint, op, targetInfo)) {
      SmallVector<TileWorkgroupSizePair> TCtileSizeConfig;
      Type elementType = llvm::cast<RankedTensorType>(
          op.getDpsInputOperand(0)->get().getType()).getElementType();
      getTensorCoreConfig(TCtileSizeConfig, elementType, sizeM, sizeN, sizeK);
      for (TileWorkgroupSizePair &config : TCtileSizeConfig) {
        if (sizeK % config.tileSize[2] == 0 &&
            sizeN % config.tileSize[1] == 0 &&
            sizeM % config.tileSize[0] == 0) {
          CodeGenPipeline codegenPipeline = getTensorCorePipeline(elementType);
          return setMatmulConfig(/* 原书省略的实参 */ ...);
        }
      }
    }
  }
  // … 原书省略的其他配置路径。
}
```

> 校订注：上述两段仍为原书摘录，补齐了被省略部分连带省去的括号层级，但没有擅自补造策略和实参，不能直接作为独立可编译函数使用。

由于测试用例的 `linalg.matmul` 操作各矩阵操作数维度都是静态大小（即 `isStaticSize` 为真），因此，`setContractConfig()` 函数在调用 `supportsTensorCore()` 函数确认目标及操作满足所选张量核路径的条件后，首先调用 `getTensorCoreConfig()` 函数，根据矩阵运算中涉及的元素类型（FP16 或 FP32）及矩阵操作数大小，结合前期分析得到的经验值，计算执行张量核操作的工作组（workgroup）大小、工作组（或线程块）分块大小和流水线深度，以此为 FP16 和 FP32 数据类型的大矩阵乘提供初始配置。

<!-- 原书第 233 页；PDF 第 11 页。上段跨页。 -->

> 校订注：原书括号中用“计算能力 ≥ `sm_80`”概括支持情况；这里是具体编译路径的筛选要求，不能把它推广成所有 `mma.sync` 变体统一的最低硬件要求，也不意味着只检查架构编号就能支持所有数据类型与形状。基于经验值选择初始配置同样不保证全局性能最优。

此处的工作组大小是指每个工作组中的线程组织规模。计算得到的工作组配置保存在集合 `TCtileSizeConfig` 中。`TCtileSizeConfig` 集合中的每个元素类型为 `TileWorkgroupSizePair` 结构体，该结构体中包含 `tileSize`、`workgroupSize` 和 `pipelineDepth` 三个字段。其中，`tileSize` 是工作组分块大小字段，`workgroupSize` 是工作组大小字段，`pipelineDepth` 是流水线深度字段。如果 `linalg.matmul` 操作的矩阵操作数大小（即上述代码中的变量 `sizeM`、`sizeN`、`sizeK`）不及 `tileSize` 指定的相应工作组分块大小，那么这段代码不会选择该候选张量核配置，而需尝试其他配置或执行路径。

> 校订注：原书由“不足一个候选分块”推断“CUDA 核已能胜任，显然无需启动张量核”，这是过强的性能结论。代码能直接证明的是候选配置的整除检查不满足，而不是更小矩阵在硬件上不能使用张量核。

在后继的流水线配置函数，如 `addGPUMatmulTensorCorePassPipeline()` 和 `addGPUMatmulTensorCoreMmaSyncPassPipeline()` 函数中将根据流水线深度参数 `pipelineDepth`，决定是否启动 GPUMultiBuffering pass，对共享内存分配执行多缓冲（multi-buffering）优化。关于 GPUMultiBuffering pass 的详细分析见本书附带文档《GPUMultiBuffering pass 详解》。下文 6.2.2 节将详细分析流水线配置函数功能。

> 资料说明：此处保留原书对附带文档的引用；当前转写来源没有包含这份附带文档，因此这里没有补写其内容。

由于本章所述 NVIDIA GPU 代码生成路径可选择 WMMA 和 MMA 两种张量核计算方案，`setContractConfig()` 函数在获得初步的分块和工作组配置后，调用 `getTensorCorePipeline()` 函数，为 \(M,N,K\) 维度大小是工作组分块大小整数倍的 `linalg.matmul` 操作选择张量核操作类型。同时，这也意味着正的 \(M,N,K\) 维度中若有一维小于相应工作组分块大小，就不能通过这个候选配置的整除检查。`getTensorCorePipeline()` 函数代码实现如下：

```cpp
static IREE::Codegen::DispatchLoweringPassPipeline
getTensorCorePipeline(Type elementType) {
  IREE::Codegen::DispatchLoweringPassPipeline codegenPipeline =
      IREE::Codegen::DispatchLoweringPassPipeline::LLVMGPUMatmulTensorCore;
  if (elementType.isF16() || elementType.isF32()) {
    codegenPipeline = IREE::Codegen::DispatchLoweringPassPipeline::
        LLVMGPUMatmulTensorCoreMmaSync;
  }
  assert(!(clGPUUseWMMA && clGPUUseMMASync) && "incompatible options.");
  // … 原书省略的命令行选项覆盖逻辑。
  return codegenPipeline;
}
```

`getTensorCorePipeline()` 函数根据矩阵元素数据类型，以及 `iree-codegen-llvmgpu-use-mma-sync` 或 `iree-codegen-llvmgpu-use-wmma` 命令行选项，确定 GPU 代码生成流水线类型。

IREE 将代码生成过程组织成流水线的形式，以实现编译过程的模块化，从而可以进行有针对性的优化并适应不同的硬件功能。IREE 为 GPU、CPU 及 SPIR-V 目标后端分别定义了若干不同类型的代码生成流水线类型，每种代码生成流水线类型可以根据特定的操作类型、硬件功能或优化策略进行定制，从而提高性能和效率。GPU 代码生成的流水线类型有 LLVMGPUMatmulSimt、LLVMGPUMatmulTensorCore、LLVMGPUMatmulTensorCoreMmaSync 等。

<!-- 原书第 234 页；PDF 第 12 页。上段跨页。 -->

其中，LLVMGPUMatmulSimt 流水线类型专注于使用 SIMT 模型完成矩阵乘，适用于由 CUDA 核执行的通用 GPU 计算。LLVMGPUMatmulTensorCore 和 LLVMGPUMatmulTensorCoreMmaSync 则是 IREE 中针对 GPU 张量核的两种代码生成流水线。二者的主要区别在于完成矩阵乘的计算方法。前者使用 WMMA 指令族，由线程束中的所有线程协作完成数据加载和矩阵乘累加操作；后者使用 `mma.sync` 指令，同样需要由线程束中的所有线程协作完成，但对计算过程提供更精细的控制，要求在调用 `mma.sync` 指令之前显式地为线程束中的不同线程分配矩阵元素。MMA 指令族还存在支持结构化稀疏矩阵操作数的独立指令形式。

> 校订注：原书将稀疏矩阵支持直接归于 `mma.sync`；稀疏形式是 `mma.sp.sync` 等独立指令，不能把普通稠密 `mma.sync` 当作稀疏乘法指令。另应区别 GPU 方言的 WMMA 路径和 NVGPU 的 MMA 路径，不能笼统称两者都是 NVGPU 方言操作。

对于使用张量核的矩阵乘计算，函数中的初始代码生成流水线类型为 LLVMGPUMatmulTensorCore。对于元素数据类型为 FP16 或 FP32 的矩阵乘计算，`getTensorCorePipeline()` 函数将流水线类型切换为 LLVMGPUMatmulTensorCoreMmaSync。如果开发者通过命令行选项 `iree-codegen-llvmgpu-use-mma-sync` 或 `iree-codegen-llvmgpu-use-wmma` 指定了流水线类型，则 `getTensorCorePipeline()` 函数使用命令行选项指定的类型，并确保不会同时选择不兼容的选项。

`getTensorCorePipeline()` 函数确定 GPU 代码生成流水线类型后，`setContractConfig()` 函数接着调用 lambda 函数 `setMatmulConfig()`，设置 Linalg 操作的 `lowering_config` 属性和入口点操作（entry point op，如 `func.func` 操作）的 `translation_info` 属性。`lowering_config` 属性中的 `tile_sizes` 字段值用于控制后续代码生成过程中对操作进行分块的分块大小，`translation_info` 属性中则指定了 GPU 代码生成的流水线类型（如 LLVMGPUMatmulTensorCoreMmaSync）等转换信息。

综上所述，LLVMGPUSelectLoweringStrategy pass 作为 LLVMGPU 代码生成配置的一部分，将根据矩阵计算的数据类型和维度、硬件计算能力等条件，确定是否选择相应的 Vector 转换路径，以及选择将 Vector 操作转换为 NVGPU 操作的代码生成流水线类型。计算转换配置相关的函数调用流程如图 6-4 所示。

**图 6-4 缩并计算配置函数调用流程。** 原图全部命名节点及分支为：

```text
setRootConfig()
  ├─ setContractConfig()
  │    ├─ getTensorCoreConfig()
  │    ├─ getTensorCorePipeline()
  │    ├─ setMatmulConfig()
  │    └─ …
  └─ …
```

### 6.2.2 流水线配置函数分析

前述 LLVMGPUSelectLoweringStrategy pass 在确定代码生成流水线类型后，由 `CUDATargetBackend::buildTranslationPassPipeline()` 函数生成 LLVMGPULowerExecutableTarget pass，并由该 pass 根据流水线类型调用名为 `addGPUXXXPassPipeline()` 的 pass 流水线配置函数，其中的“XXX”字符串大体上对应代码生成流水线类型。例如，流水线类型 LLVMGPUDefault 对应的 pass 流水线配置函数为 `addGPUDefaultPassPipeline()`，流水线类型 LLVMGPUMatmulTensorCore 对应的 pass 流水线配置函数为 `addGPUMatmulTensorCorePassPipeline()` 等。LLVMGPU 的代码生成流水线类型及其对应的流水线配置函数如表 6-1 所示。

<!-- 原书第 235 页；PDF 第 13 页。上段跨页。 -->

**表 6-1 LLVMGPU 代码生成流水线类型与流水线配置函数**

| 代码生成流水线类型 | 流水线配置函数 |
| --- | --- |
| LLVMGPUDefault | `addGPUDefaultPassPipeline` |
| LLVMGPUBaseLowering | `addGPUBaseLoweringPassPipeline` |
| LLVMGPUDistribute | `addGPUSimpleDistributePassPipeline` |
| LLVMGPUVectorize | `addGPUVectorizationPassPipeline` |
| LLVMGPUMatmulSimt | `addGPUMatmulSimtPassPipeline` |
| LLVMGPUMatmulTensorCore | `addGPUMatmulTensorCorePassPipeline` |
| LLVMGPUTransposeSharedMem | `addGPUTransposePassPipeline` |
| LLVMGPUWarpReduction | `addGPUWarpReductionPassPipeline` |
| LLVMGPUPackUnPack | `addGPUPackUnPackPasses` |
| LLVMGPUMatmulTensorCoreMmaSync | `addGPUMatmulTensorCoreMmaSyncPassPipeline` |
| LLVMGPUVectorDistribute | `addGPUVectorDistributePassPipeline` |

上述各 pass 流水线可将高阶操作转换为更接近在 GPU 上执行的实际机器指令的较低阶表示，其中通常包括一些基础 pass，如规范化（Canonicalize）、循环分布、向量化和内存优化等。各流水线类型的流水线配置函数可根据需要，结合特定 GPU 功能特性（如张量核），以及优化的操作类型（如矩阵乘操作），在基础 pass 上进一步增加其他有针对性的优化 pass。

LLVMGPULowerExecutableTarget pass 根据流水线类型调用对应的 pass 流水线配置函数的代码实现如下：

```cpp
void LLVMGPULowerExecutableTargetPass::runOnOperation() {
  // variantOp 的取得等前序代码未包含在原书摘录中。
  std::optional<IREE::Codegen::TranslationInfoAttr> translationInfo =
      getIdenticalTranslationInfo(variantOp);
  // … 原书省略的检查。
  OpPassManager pipeline(IREE::HAL::ExecutableVariantOp::getOperationName());
  switch (translationInfo.value().getDispatchLoweringPassPipeline()) {
  case IREE::Codegen::DispatchLoweringPassPipeline::
      LLVMGPUMatmulTensorCoreMmaSync: {
    FailureOr<int64_t> maybeDepth =
        getSoftwarePipelineDepth(translationInfo.value().getConfiguration());
    // … 原书省略的错误处理。
    addGPUMatmulTensorCoreMmaSyncPassPipeline(pipeline, *maybeDepth);
    break;
  }
  // … 原书省略的其他 case。
  }
  // … 原书省略的流水线执行及错误处理。
}
```

> 校订注：扫描稿中 `case` 的大括号不配对，已补齐分支作用域，以免局部变量初始化跨越其他 `case` 标签。仍保留原书的摘录性质；不能移除省略注释后直接假定 `translationInfo.value()` 或 `*maybeDepth` 总是有效。

<!-- 原书第 236 页；PDF 第 14 页。 -->

上述 LLVMGPUMatmulTensorCoreMmaSync 流水线类型的张量核流水线配置函数 `addGPUMatmulTensorCoreMmaSyncPassPipeline()` 配置了一系列 pass，通过使用张量核相关的向量化和映射策略优化矩阵乘计算。其中除了生成各种基本 pass（如下述代码中生成的 Canonicalizer pass）外，关键是调用 `tileAndBufferize()`、`createLLVMGPUTileAndDistribute()`、`createLLVMGPUTensorCoreVectorizationPass()` 和 `createLLVMGPUVectorToGPU()` 函数，分别经相应构建过程生成 TileAndDistributeToWorkgroups、LLVMGPUTileAndDistribute、LLVMGPUTensorCoreVectorization 和 LLVMGPUVectorToGPU pass 实例，并将其添加到 pass 管理器中。

其中，TileAndDistributeToWorkgroups pass 是针对 GPU 后端的 Linalg 操作设备级分块和分布优化 pass。LLVMGPUTileAndDistribute pass 则在工作组内对 Linalg 操作进行分块，并将分块后的操作分配给不同的计算单元。LLVMGPUTensorCoreVectorization pass 实现 Linalg 操作到 Vector 操作的转换，并在将 Vector 操作转换到 GPU MMA 相关操作前进行算术折叠等预处理。在确定需要将 Vector 操作转换为 NVGPU 操作，以及采用的代码生成流水线类型后，由 LLVMGPUVectorToGPU pass 实现这种转换。

`addGPUMatmulTensorCoreMmaSyncPassPipeline()` 函数的相关代码片段如下所示：

```cpp
void addGPUMatmulTensorCoreMmaSyncPassPipeline(OpPassManager &pm,
                                             unsigned pipelineDepth) {
  tileAndBufferize(pm);
  auto &nestedModulePM = pm.nest<ModuleOp>();
  nestedModulePM.addNestedPass<func::FuncOp>(
      createLLVMGPUTileAndDistribute(/*distributeToWarp=*/true));
  // …
  if (pipelineDepth > 1)
    nestedModulePM.addNestedPass<func::FuncOp>(
        createGPUMultiBuffering(pipelineDepth));
  // …
  nestedModulePM.addPass(createCanonicalizerPass());
  // …
  nestedModulePM.addNestedPass<func::FuncOp>(
      createLLVMGPUTensorCoreVectorizationPass(GPUTensorCoreType::MMA_SYNC));
  // …
  nestedModulePM.addNestedPass<func::FuncOp>(
      createLLVMGPUVectorToGPU(GPUTensorCoreType::MMA_SYNC));
  // …
}
```

图 6-5 总结了张量核流水线配置函数 `addGPUMatmulTensorCoreMmaSyncPassPipeline()` 中与 LLVMGPUMatmulTensorCoreMmaSync 流水线相关的主要 pass 生成流程。这些 pass 共同作用，通过分块、张量核向量化和操作转换等步骤，优化 GPU 上的矩阵乘操作。

<!-- 原书第 237 页；PDF 第 15 页。 -->

**图 6-5 张量核流水线配置函数中主要 pass 生成流程。** 图中从同一个流水线配置入口展开，按顺序列出四个具名构建步骤及其他 pass：

```text
addGPUMatmulTensorCoreMmaSyncPassPipeline()
  ├─ tileAndBufferize()
  ├─ createLLVMGPUTileAndDistribute()
  ├─ createLLVMGPUTensorCoreVectorizationPass()
  ├─ createLLVMGPUVectorToGPU()
  └─ 其他 pass
```

本章接下来以 Linalg 方言操作逐次递降到 NVVM 方言操作的过程为线索，详述以上 4 个 pass 的主要功能和变换实现。

### 6.2.3 LLVMGPUMatmulTensorCoreMmaSync 流水线的分级分块

LLVMGPUMatmulTensorCoreMmaSync 流水线的分块过程分为三级，依次为设备级、工作组级和线程束级。不同级别分块过程工作在核心计算操作（如 `linalg.matmul` 操作）的不同维度上。这三个级别的分块策略在目标 GPU 上协同工作，充分利用硬件的并行性和不同层级的存储（全局内存、共享内存等）特性，获得高效的矩阵乘计算性能。

例如，下述 `linalg.matmul` 操作维度包括 \(M,N,K\) 维，各维度索引分别为 0、1、2。其中，\(M,N\) 维为并行维度，\(K\) 维为归约维度。

```mlir
linalg.matmul {
  lowering_config = #iree_codegen.lowering_config<tile_sizes = [[32, 32, 32]]>
} ins(%3, %4 : memref<512x512xf16>, memref<512x512xf16>)
  outs(%5 : memref<512x512xf16>)
```

> 校订注：原例把 `memref` 输入输出与 `-> tensor<512x512xf16>` 混写；这里保留 `memref` 形式并删去不合法的 tensor 结果。原书还省略了内存空间细节，摘录统一展示默认空间，并不表示完整日志中的空间配置被实际改为默认值。`%3`、`%4`、`%5` 的定义来自外部上下文。

设备级、工作组级和线程束级分块过程分别工作在对应的并行或归约维度上。不同级别分块过程与维度的对应关系如图 6-6 所示。

**图 6-6 不同级别分块过程与维度的对应关系。** 原操作的维度索引为 `[0, 1, 2]`，先分为并行维度 `[0, 1]` 和归约维度 `[2]`；三个阶段依次处理：

| 阶段 | 图中处理的维度索引 | 对应矩阵乘维度 |
| --- | --- | --- |
| 设备级分块 | `[0, 1]`，并行维度 | \(M,N\) |
| 工作组级分块 | `[2]`，归约维度 | \(K\) |
| 线程束级分块 | `[0, 1]`，并行维度 | 工作组内部进一步细分 \(M,N\) |

设备级分块过程会将原始大规模（如 512×512）的矩阵操作数 \(A,B,C\) 分割为更小的分块（如 32×128 等），并分配给各个工作组。这些分块通常存储在全局内存中。GPU 硬件的若干工作组并行地从全局内存中读取 \(A,B\) 分块，并负责一块子矩阵的计算，然后在计算完成后将结果写回 \(C\) 分块。

<!-- 原书第 238 页；PDF 第 16 页。 -->

在设备级分块完成后，每个工作组负责一个输出分块。工作组分块过程在工作组内部根据缓存策略将 \(C\) 操作数分块或 \(A,B,C\) 操作数分块加载到共享内存，并沿 \(K\) 维进一步将 \(A,B\) 操作数分块分解为更小的分块（如 32×32），以减少对全局内存的访问，并为多线程束协同处理共享内存中的分块做好准备。

为了适应张量核指令的形状要求，线程束级分块将之前工作组级分块过程得到的分块进一步切分为更小的分块（如 16×32）。每个线程束负责处理不同部分的数据，并在协同计算完成后，将结果按所选存储路径写回，最终写回全局内存。

> 校订注：原书此处描述了经工作组级共享内存写回的路径，但不能据此断定累加结果 \(C\) 总是必须先放入共享内存；它也可能由寄存器直接写回全局内存，具体取决于后续 pass 的实际配置和生成代码。另外，线程束负责的分块不一定只用一条张量核指令完成。

图 6-7 展示了 `linalg.matmul` 操作的 \(A,B,C\) 三个矩阵操作数在不同级别分块过程中的划分方式。

**图 6-7 不同级别分块过程中的操作数划分方式。** 原图分为三组，每组都把 \(A\) 画在左下、\(B\) 画在右上、\(C\) 画在右下，以对应 \(A_{M\times K}B_{K\times N}=C_{M\times N}\)。阴影表示当前处理部分，虚线表示分块边界：

- 设备级：\(A\) 的阴影为一条横向行带，\(B\) 的阴影为一条纵向列带，二者确定 \(C\) 中一个矩形输出块；此时归约维 \(K\) 尚未在这一层切短。图下标为“全局内存”。
- 工作组级：进一步沿 \(K\) 将 \(A\) 行带和 \(B\) 列带截成小矩形，\(C\) 仍是这个工作组负责的输出矩形。一个 \(C\) 块需要累加多个 \(K\) 分块的乘积。图下标为“全局内存／共享内存”。
- 线程束级：在上述小块上进一步沿 \(M,N\) 细分，\(A\)、\(B\)、\(C\) 中的阴影矩形相应缩小，网格更密，表示各线程束负责的子任务。图下标为“共享内存”，表示本例工作组内数据交换的层级，不表示张量核运算直接使用共享内存地址作为所有寄存器操作数。

后续各节将分析每一级分块过程的具体实现细节，主要包括分块大小的计算和分块过程的执行。

## 6.3 TileAndDistributeToWorkgroups pass 工作流程

`addGPUMatmulTensorCoreMmaSyncPassPipeline()` 函数调用的 `tileAndBufferize()` 函数实现的分块过程工作在第一级，即设备级。设备级分块过程由 `TileAndDistributeToWorkgroups` pass 实现。

### 6.3.1 设备级分块过程输入 IR 分析

`TileAndDistributeToWorkgroups` pass 是针对 GPU 后端的设备级分块和分布优化 pass。该 pass 的输入 IR 通常是以 Linalg 操作为核心的 MLIR 图，这些 Linalg 操作描述了需要在 GPU 上执行的计算任务。由前述 `512_after_all_cuda.log` 日志文件可见，该 pass 的输入 IR 如下：

<!-- 原书第 239 页；PDF 第 17 页。 -->

```text
func.func @matmul_dispatch_0_matmul_512x512x512_f16()
    attributes {translation_info = …} {
  …
  %0 = hal.interface.binding.subspan … : …<readonly:tensor<512x512xf16>>
  %1 = hal.interface.binding.subspan … : …<readonly:tensor<512x512xf16>>
  %2 = hal.interface.binding.subspan … : …<writeonly:tensor<512x512xf16>>
  %3 = flow.dispatch.tensor.load %0, offsets = [0, 0], sizes = [512, 512],
      strides = [1, 1] : …<readonly:tensor<512x512xf16>> -> tensor<512x512xf16>
  %4 = flow.dispatch.tensor.load %1, offsets = [0, 0], sizes = [512, 512],
      strides = [1, 1] : …<readonly:tensor<512x512xf16>> -> tensor<512x512xf16>
  %5 = tensor.empty() : tensor<512x512xf16>
  %6 = linalg.fill {lowering_config = #iree_codegen.lowering_config<tile_sizes = [[32, 32, 32]]>}
      ins(%cst : f16) outs(%5 : tensor<512x512xf16>) -> tensor<512x512xf16>
  %7 = linalg.matmul {lowering_config = #iree_codegen.lowering_config<tile_sizes = [[32, 32, 32]]>}
      ins(%3, %4 : tensor<512x512xf16>, tensor<512x512xf16>)
      outs(%6 : tensor<512x512xf16>) -> tensor<512x512xf16>
  flow.dispatch.tensor.store %7, %2, offsets = [0, 0], sizes = [512, 512],
      strides = [1, 1] : tensor<512x512xf16> -> …<writeonly:tensor<512x512xf16>>
  return
}
```

> 转写说明：上面省略号是原书摘录已有的省略，包括绑定参数、类型前缀、常量定义和函数属性；因此用 `text` 标明它不是可直接编译的完整 IR。保留原书 IREE 历史形式，不凭空补造接口参数。

上述输入 IR 中尚未出现分块和循环嵌套结构。其中的核心计算操作是 `linalg.matmul`。`flow.dispatch.tensor.load` 操作加载大小为 512×512 的张量 `%3`、`%4`，作为 `linalg.matmul` 操作的 A、B 操作数。`linalg.fill` 操作的作用是以给定常量值 `%cst` 填充输出张量，并以返回值 `%6` 作为 `linalg.matmul` 操作的 C 操作数。示例所携带的分块大小配置为 `tile_sizes = [[32, 32, 32]]`，对矩阵乘而言，对应 M、N、K 三个迭代维度的分块大小均为 32。如果某个维度的分块大小为 0，表示在该维度不执行分块。

> 校订注：原书直接说 `linalg.fill` 的该配置意味着将其 M、N、K 都切成 32。二维张量上的 fill 只有两个并行迭代维，没有矩阵乘的 K 归约维。三项配置的 M、N、K 解释适用于 matmul；配置附着在 fill 上不代表 fill 自身也有三个循环维度。此外，tensor 形式的 fill 产生结果张量，不能按 memref 原地写语义理解为修改已有 SSA 张量值 `%5`。

紧随其后的 `linalg.matmul` 操作执行矩阵乘计算，并由 `flow.dispatch.tensor.store` 操作将计算结果存储到大小为 512×512 的输出张量。Linalg 操作的 `lowering_config` 属性用于控制操作的递降方式，如分块大小等。该属性在后续分块过程中有重要作用。

### 6.3.2 设备级分块过程实现

`tileAndBufferize()` 函数是 LLVMGPUMatmulTensorCoreMmaSync 流水线中的重要步骤。该函数除了生成 `TileAndDistributeToWorkgroups` pass 及其他相关 pass 外，还调用 `addBufferizePasses()` 函数，添加缓冲化（bufferization）相关 pass，将张量操作转换为较低级别的内存操作。`tileAndBufferize()` 函数代码实现如下：

```cpp
static void tileAndBufferize(OpPassManager &pm) {
  tileAndDistributeToWorkgroup(pm, true);
  auto &nestedModulePM = pm.nest<ModuleOp>();
  addBufferizePasses(nestedModulePM);
}
```

<!-- 原书第 240 页；PDF 第 18 页。上述代码跨页。 -->

上述 `tileAndBufferize()` 函数首先调用 `tileAndDistributeToWorkgroup()` 函数生成 `TileAndDistributeToWorkgroups` pass 实例，其功能是将核心计算操作 `linalg.matmul` 划分为更小的分块，然后将分块后的计算任务分发给并行计算单元（如工作组）执行，并通过调整分块大小，优化计算密度和数据局部性。

由相关代码实现可知，`tileAndBufferize()` 函数除了生成该 pass 实例外，还涉及其他 pass。本节重点关注与分块相关的 pass。

`tileAndDistributeToWorkgroup()` 函数代码片段如下（省略处沿用原书）：

```cpp
static void
tileAndDistributeToWorkgroup(OpPassManager &funcPassManager, /* … */) {
  funcPassManager.addPass(createTileAndDistributeToWorkgroupsPass(
      kNumMaxParallelDims, linalg::DistributionMethod::CyclicNumProcsEqNumIters));
  // …
}
```

上述 `createTileAndDistributeToWorkgroupsPass()` 函数生成 pass 实例。该 pass 根据分块和循环分布配置决定如何进行设备级分块，因此 `TileAndDistributeToWorkgroupsPass::runOnOperation()` 函数的主要功能也与此相关，包括获取需要分块的计算操作、从根操作获取分块和循环分布配置、生成并配置设备级 Linalg 分块选项，以及执行设备级分块和融合过程 4 个部分。

`TileAndDistributeToWorkgroupsPass::runOnOperation()` 函数实现摘录如下：

```cpp
void TileAndDistributeToWorkgroupsPass::runOnOperation() {
  MLIRContext *context = &getContext();
  auto funcOp = getOperation();
  // …
  SmallVector<Operation *> computeOps = getComputeOps(funcOp);
  SmallVector<int64_t> tileSizes, staticLoopRanges, interchange;
  SmallVector<unsigned> partitionableLoops;
  Operation *dispatchRootOp = nullptr;
  if (failed(getTileAndDistributeConfig(computeOps, dispatchRootOp, tileSizes,
                                       staticLoopRanges, interchange,
                                       partitionableLoops))) {
    return signalPassFailure();
  }
  // …
  auto tileSizeFn = [&](OpBuilder &builder, Operation *op) -> SmallVector<Value> {
    return llvm::map_to_vector(tileSizes, [&](int64_t ts) -> Value {
      return builder.create<arith::ConstantIndexOp>(op->getLoc(), ts);
    });
  };
  linalg::DistributionMethod distributionMethodValue =
      (linalg::DistributionMethod)(distributionMethod.getValue());
  auto linalgTilingOptions = linalg::LinalgTilingOptions()
      .setDistributionOptions(getIREELinalgLoopDistributionOptions(
          tileSizes, distributionMethodValue, maxWorkgroupParallelDims))
      .setInterchange(llvm::map_to_vector(
          interchange, [](int64_t v) -> unsigned { return static_cast<unsigned>(v); }))
      .setLoopType(linalg::LinalgTilingLoopType::Loops)
      .setTileSizeComputationFunction(tileSizeFn);
  FailureOr<IREETileAndFuseResult> tileAndFuseResult =
      tileAndFuseDispatchUsingSCFForOp(rewriter,
          cast<TilingInterface>(computeOps.back()), linalgTilingOptions);
  // …
}
```

<!-- 原书第 241 页；PDF 第 19 页。上述代码跨页。 -->

> 转写说明：保留原书摘录及省略位置；`rewriter` 的声明和检查、收尾逻辑不在摘录中。扫描页结尾在省略号之间另有闭括号，但没有给出对应开头；这里按展示的函数层级闭合，不补造被省略的控制流。

根据上述代码可总结得到函数调用流程图，如图 6-8 所示。

```text
TileAndDistributeToWorkgroupsPass::runOnOperation()
├── getComputeOps()                         查找需要分块的计算操作
├── getTileAndDistributeConfig()            由根操作获取分块和循环分布配置
│   ├── getLoweringConfig()                 查找具有递降配置属性的根操作
│   ├── getPartitionableLoops()             获得根操作的可切分循环维度索引向量
│   └── getStaticLoopRanges()               获得根操作的静态循环范围向量
├── linalg::LinalgTilingOptions()            生成并配置 Linalg 分块选项对象
└── tileAndFuseDispatchUsingSCFForOp()       执行设备级分块和融合过程
    ├── getAllFusableProducers()             收集可与计算操作融合的生产者操作
    ├── tileDispatchUsingSCFForOp()          对计算操作进行隐式分块
    │   ├── generateTileLoopNest()           生成设备级分块隐式循环嵌套结构
    │   └── getTiledImplementation()         使用切片操作对计算操作分块
    └── …                                  原图省略的后续步骤
```

图 6-8　`TileAndDistributeToWorkgroupsPass::runOnOperation()` 函数调用流程图。

<!-- 原书第 242 页；PDF 第 20 页。 -->

以下各小节将按照上述调用流程分别详述各函数功能。

前述 `createTileAndDistributeToWorkgroupsPass()` 函数在生成 pass 实例时，需指定最大工作组并行维度（`maxWorkgroupParallelDims`）参数和循环分布方法（`distributionMethod`）参数。最大工作组并行维度参数的作用将在分析设备级分块和融合执行过程时详述。

分块是将循环迭代空间划分为更小的块的过程。循环分布方法决定如何将迭代任务分配给多个并行计算单元。因此，循环分布方法参数对后续的分块、并行化和数据局部性优化等过程都有重要影响，更直接决定后续生成的分块循环嵌套结构。有鉴于此，在分析设备级分块过程实现方法之前，有必要首先介绍循环分布方法参数的含义和作用。

#### 1. 循环分布方法

书中 IREE 使用的循环分布方法共有四种类型，由 `DistributionMethod` 枚举类定义如下：

```cpp
enum class DistributionMethod {
  Cyclic = 0,
  CyclicNumProcsGeNumIters = 1,
  CyclicNumProcsEqNumIters = 2,
  None = 3
};
```

`DistributionMethod` 枚举类描述循环的分布策略及其中使用的处理器数量与循环迭代次数之间的假设，每个枚举值对应一种具体策略。本地 MLIR 的 `mlir/include/mlir/Dialect/Linalg/Utils/Utils.h` 中也有这组枚举定义。

##### （1）Cyclic 循环分布策略

枚举值 `Cyclic` 对应的循环分布策略不对处理器数量与原始循环迭代次数之间的动态关系做额外假设，适用于最广泛和一般的情况。例如，有如下原始循环（此处和后面的原书混合语法例子均为示意代码）：

```text
scf.parallel (%iv) = (%lb) to (%ub) step (%step) { … }
```

假设原始循环下界 `%lb = 0`，循环上界 `%ub = 12`，步长 `%step = 1`。在分布示意中，先把原始的全部迭代列在同一条轴上，原始循环迭代空间中的每个迭代点如图 6-9 上部所示。

> 校订注：原书说“原始循环的所有迭代任务都由一个处理器执行”，这只是示意的出发点，不是 `scf.parallel` 的必然执行语义。该操作表达可并行的迭代，不能由尚未分布就推断其硬件执行一定串行。

原始循环经过 `Cyclic` 循环分布策略转换后生成的新循环为：

```text
scf.parallel (%iv) = (%lb + %procId * %step)
    to (%ub) step (%step * %nprocs) { … }
```

与原始循环相比，新循环下界和步长均发生变化。其中，`%procId` 表示执行迭代的处理器 ID，`%nprocs` 表示分布执行循环的处理器数量。经 `Cyclic` 策略转换后，新循环体中的计算任务分发到多个处理器执行，每个处理器只负责原始循环中的部分迭代。新循环下界为 `%lb + %procId * %step`，新循环上界为 `%ub`，新循环步长为 `%step * %nprocs`。假设 `%nprocs = 4`，`%procId = 0、1、2、3`。每个处理器执行以下迭代：

```text
处理器 0：%iv = %lb + 0 * %step,
               %lb + (%nprocs + 0) * %step,
               %lb + (2 * %nprocs + 0) * %step
处理器 1：%iv = %lb + 1 * %step,
               %lb + (%nprocs + 1) * %step,
               %lb + (2 * %nprocs + 1) * %step
处理器 2：%iv = %lb + 2 * %step,
               %lb + (%nprocs + 2) * %step,
               %lb + (2 * %nprocs + 2) * %step
处理器 3：%iv = %lb + 3 * %step,
               %lb + (%nprocs + 3) * %step,
               %lb + (2 * %nprocs + 3) * %step
```

<!-- 原书第 243 页；PDF 第 21 页。上述列表跨页。 -->

经 `Cyclic` 循环分布策略转换后，多处理器迭代空间中的每个迭代点如图 6-9 下部所示。

```text
索引       0  1  2  3  4  5  6  7  8  9 10 11 | 12
原始循环   ●  ●  ●  ●  ●  ●  ●  ●  ●  ●  ●  ● | ○
                     ↓ Cyclic 循环分布策略
处理器 0   ●  ○  ○  ○  ●  ○  ○  ○  ●  ○  ○  ○ | ○
处理器 1   ○  ●  ○  ○  ○  ●  ○  ○  ○  ●  ○  ○ | ○
处理器 2   ○  ○  ●  ○  ○  ○  ●  ○  ○  ○  ●  ○ | ○
处理器 3   ○  ○  ○  ●  ○  ○  ○  ●  ○  ○  ○  ● | ○
```

图 6-9　Cyclic 循环分布策略。左端 `%lb = 0`，右端为不包含的 `%ub = 12`；原始相邻点距离为 `%step = 1`，每个处理器相邻实心点距离为 `%step * %nprocs = 4`。实心圆点表示当前处理器执行的迭代点，空心圆点表示不由当前处理器执行的点，上界点不参与执行。

原始循环经过该策略转换后，12 次迭代被分配到 4 个处理器。每个新循环由对应的处理器执行，新循环的下界和步长经过调整，可确保不同处理器获得的迭代索引互不重叠。迭代之间是否存在会妨碍并行执行的内存依赖，仍需由原并行语义或合法性分析保证。

下文 6.4.3 节将要分析的线程束级分块过程，在调用 `getSubgroupIdsAndCounts()` 函数计算处理器信息向量时，采用 `Cyclic` 分布方法解释各 `ProcInfo` 结构体对象对应的处理器分配。

##### （2）CyclicNumProcsGeNumIters 循环分布策略

枚举值 `CyclicNumProcsGeNumIters` 对应的循环分布策略假设处理器数量大于或等于原始循环迭代次数。在此情况下，只需要使用条件语句（如 `scf.if`）做边界检查，而不需要具体化（materialize）整个循环。例如，有如下原始循环：

```text
scf.parallel (%iv) = (%lb) to (%ub) step (%step) { … }
```

原始循环经过该策略转换后生成如下示意代码：

```text
%iv = %lb + %procId * %step
%cond = arith.cmpi slt, %iv, %ub : index
scf.if %cond {
  // 当 %cond 条件满足时执行计算任务
}
```

<!-- 原书第 244 页；PDF 第 22 页。上述代码跨页。 -->

> 校订注：原书本小节开头写“大于”，但 `Ge` 包含相等，后文也使用“大于或等于”，这里统一。`%iv = %lb + …` 是算式示意；实际 IR 需要先生成整数乘法、加法或等价的索引计算操作。

上述循环体的计算任务分发到多个处理器执行。由于处理器数量大于或等于原始循环迭代次数，每个处理器最多只能分配到一次与自己的 `%procId` 对应的迭代。各处理器对应的迭代索引为 `%iv = %lb + %procId * %step`。由于每个处理器最多执行一次迭代，与原始循环相比，转换后生成代码中的 `%iv` 也可视为分布后循环本会使用的下界。各处理器是否执行迭代由条件变量 `%cond` 决定，即处理器对应的迭代索引是否小于上界 `%ub`。

假设 `%lb = 0`、`%ub = 3`、`%step = 1`、`%nprocs = 4`、`%procId = 0、1、2、3`。显然，处理器数量 4 大于循环迭代次数 3，每个处理器执行以下迭代和判断：

- 处理器 0：`%iv = 0 + 0 * %step = 0` 且 `0 < 3 (%ub)`，因此执行计算任务。
- 处理器 1：`%iv = 0 + 1 * %step = 1` 且 `1 < 3 (%ub)`，因此执行计算任务。
- 处理器 2：`%iv = 0 + 2 * %step = 2` 且 `2 < 3 (%ub)`，因此执行计算任务。
- 处理器 3：`%iv = 0 + 3 * %step = 3` 且 `3 = 3 (%ub)`，因此不执行计算任务。

针对上述例子，迭代范围 `[0, 3)` 被分配到前 3 个处理器，每个处理器执行一次迭代。最后一个处理器未分配计算任务。经该策略转换后，多处理器迭代空间中的每个迭代点如图 6-10 下部所示。

```text
索引       0  1  2 | 3
原始循环   ●  ●  ● | ○
              ↓ CyclicNumProcsGeNumIters 循环分布策略
处理器 0   ●  ○  ○ | ○
处理器 1   ○  ●  ○ | ○
处理器 2   ○  ○  ● | ○
处理器 3   ○  ○  ○ | ○
```

图 6-10　CyclicNumProcsGeNumIters 循环分布策略。左端 `%lb = 0`，右端排除式上界 `%ub = 3`，相邻点间距 `%step = 1`。实心点表示执行该索引；处理器 3 的索引落在上界，条件检查阻止其执行。

##### （3）CyclicNumProcsEqNumIters 循环分布策略

本节的 `TileAndDistributeToWorkgroups` pass 配置使用枚举值 `CyclicNumProcsEqNumIters`。该值对应的循环分布策略假设处理器数量等于原始循环迭代次数。在此情况下，每个处理器与一个原始循环迭代严格对应，不需要为这个分布循环做边界检查。例如，有如下原始循环：

```text
scf.parallel (%iv) = (%lb) to (%ub) step (%step) {
  A[%iv] = B[%iv] + C[%iv]
}
```

原始循环经过该策略转换后生成如下示意代码：

```text
%iv = %lb + %procId * %step
A[%iv] = B[%iv] + C[%iv]
```

<!-- 原书第 245 页；PDF 第 23 页。 -->

由于所有处理器都恰好对应一个有效的索引值 `%iv`，因此不需要检查该循环索引是否越界，每次迭代可直接映射为某个处理器上的计算任务。与原始循环相比，转换后生成代码的迭代索引 `%iv` 可视为分布后循环本会使用的下界。按照上述计算方式，每个处理器直接计算其索引值，并执行对应的计算任务。

假设 `%lb = 0`、`%ub = 3`、`%step = 1`、`%nprocs = (%ub - %lb) / %step = 3`、`%procId = 0、1、2`。此时，处理器数量 3 等于循环迭代次数 3，每个处理器执行以下迭代：

- 处理器 0：`%iv = 0 + 0 * %step = 0`，因此执行 `A[0] = B[0] + C[0]`。
- 处理器 1：`%iv = 0 + 1 * %step = 1`，因此执行 `A[1] = B[1] + C[1]`。
- 处理器 2：`%iv = 0 + 2 * %step = 2`，因此执行 `A[2] = B[2] + C[2]`。

> 校订注：原书处理器 2 的算式误写为 `C[1]`，已改为 `C[2]`。本例恰好整除；一般正步长循环的迭代次数应为 `max(0, ceil((ub - lb) / step))`，不能普遍使用向下取整的整数除法。分布循环不需要边界判断，也不等于分块内部的尾块访存无须处理边界。

经该策略转换后，多处理器迭代空间中的每个迭代点如图 6-11 下部所示。

```text
索引       0  1  2 | 3
原始循环   ●  ●  ● | ○
              ↓ CyclicNumProcsEqNumIters 循环分布策略
处理器 0   ●  ○  ○ | ○
处理器 1   ○  ●  ○ | ○
处理器 2   ○  ○  ● | ○
```

图 6-11　CyclicNumProcsEqNumIters 循环分布策略。左端 `%lb = 0`，右端排除式上界 `%ub = 3`，相邻点间距 `%step = 1`；三个处理器各恰好对应一个有效实心点，无空闲的第四个处理器。

`DistributionMethod` 枚举类中定义的枚举值 `None` 表示不进行循环分布。对这里的分布变换而言，它保留原来的迭代安排，不把迭代重新分配给这些处理器；原书将这种情况概括为所有迭代在同一个处理器上执行，但这不是对所有外围并行上下文的限制。

此处的“处理器”一词可以笼统地指代各种并行计算单元，如工作组、线程束或线程，具体含义取决于循环分布策略工作的分块过程层级。例如，在设备级分块过程中，“处理器”一般代表工作组。为了与代码变量名保持一致，本章在分析各层级分块过程时，有时仍用“处理器”指代各并行计算单元。具体是哪种并行计算单元可结合上下文确定。

由上述分析可知，如果采用 `CyclicNumProcsGeNumIters` 或 `CyclicNumProcsEqNumIters` 策略，意味着循环迭代次数小于或等于处理器数量，则每个处理器不处理迭代或恰好处理一次迭代。这时，可将这些迭代映射给不同的 GPU 并行执行单元，而不必为这一层分布在 IR 中显式生成 `scf.for` 或其他循环操作，因此书中称这种并行化机制为“隐式循环嵌套结构”。这仍需要正确的启动规模、处理器 ID 和索引映射，并非省去所有并行执行配置。

#### 2. 获取计算操作

如图 6-8 所示，`TileAndDistributeToWorkgroupsPass::runOnOperation()` 函数首先调用 `getComputeOps()` 函数，在 IR 函数中查找实现了 `TilingInterface`（或 `UKernelOpInterface`）接口的计算操作，并将其添加到计算操作集合 `computeOps` 中。后续需要对这类计算操作进行分块或其他优化。

<!-- 原书第 246 页；PDF 第 24 页。上段跨页。 -->

在 MLIR 中，不同方言操作可通过 `TilingInterface` 接口统一向分块变换提供所需能力，不同方言可以实现各自的接口模型。例如，Linalg 方言通过外部模型机制，以 `LinalgOpTilingInterface` 为操作提供 `TilingInterface` 实现，其中的 `getLoopIteratorTypes()`、`getIterationDomain()` 等成员函数可以为分块过程提供操作的循环迭代器类型和迭代域等相关信息。

> 校订注：这里是操作接口的外部模型实现，不是每个方言都派生出一个新的接口类型，也不是所有方言操作都必然支持分块。本地 `TilingInterfaceImpl.cpp` 中的 `LinalgOpTilingInterface` 继承 `TilingInterface::ExternalModel<…>`，并附加到相应操作上。

在测试用例中，`linalg.fill` 和 `linalg.matmul` 两个操作实现了 `TilingInterface` 接口，因此可以保存在计算操作集合 `computeOps` 中。`computeOps` 集合是后续的分块和融合过程需要处理的操作集合。

#### 3. 获取分块和循环分布配置

针对计算操作集合 `computeOps` 中的操作，`runOnOperation()` 函数接下来调用 `getTileAndDistributeConfig()` 函数，根据计算操作中的根操作，生成分块和循环分布配置信息，包括分块大小、循环交换顺序、可切分循环，以及静态循环范围。这些配置信息后续可用于实际执行分块过程。

`getTileAndDistributeConfig()` 函数首先遍历 `computeOps` 集合，并调用 `getLoweringConfig()` 函数，从后向前查找集合中第一个具有 `lowering_config` 属性的计算操作，并将其作为根操作。计算操作 `lowering_config` 属性中的 `tile_sizes` 字段值用于控制代码生成过程中对操作进行分块的分块大小，其值由前述 `LLVMGPUSelectLoweringStrategy` pass 设置（见 6.2.1 节）。

测试用例中的 `linalg.fill` 操作和 `linalg.matmul` 操作都具有 `lowering_config` 属性。在 `computeOps` 集合中从后向前查找到的第一个具有该属性的计算操作为 `linalg.matmul`，因此此处的根操作为 `linalg.matmul` 操作。根操作通常代表计算的核心部分，例如矩阵乘、卷积等。对根操作进行分块将影响其他相关操作的数据访问模式，因此应首先确定根操作的分块大小。

`getTileAndDistributeConfig()` 函数接下来取得根操作的 `PartitionableLoopsInterface` 接口。该接口提供一系列可切分循环（partitionable loop）相关方法。如图 6-8 所示，函数中调用了这些方法中的 `getPartitionableLoops()` 和 `getStaticLoopRanges()`。其中，`getPartitionableLoops()` 获得根操作的可切分循环维度索引向量 `partitionableLoops`。对本例所讨论的 Linalg 操作，可从并行维度中过滤掉循环范围为 1 的单位维度，选取剩余的可分布并行维度。某些维度（如批次维度）范围可能为 1，在这些维度上只有一次迭代，不需要进一步划分并行任务。这些剩余并行维度可在后续对根操作执行设备级分块和并行计算。`getStaticLoopRanges()` 获得根操作的静态循环范围向量 `staticLoopRanges`，其元素对应操作迭代域各维度的范围。

> 校订注：原书将单位范围说成“不需要进行迭代”，准确说法是只有一次迭代；它不是零次迭代。静态循环范围描述的是操作的循环维度，不是任一矩阵操作数的形状向量。可分布维度的实际选择还受到该接口实现及维度数量等限制。

测试用例的根操作 `linalg.matmul` 有三个循环维度 M、N 和 K。`getStaticLoopRanges()` 返回的静态循环范围向量为 `[512, 512, 512]`，表示操作迭代域的 M、N、K 维度大小。`getPartitionableLoops()` 返回的可切分循环维度索引向量为 `[0, 1]`，向量元素分别对应并行维度 M 和 N 的索引，即只保留符合可切分定义的并行维度 M、N，而将归约维度 K 过滤。

<!-- 原书第 247 页；PDF 第 25 页。上段跨页。 -->

分块大小向量 `tileSizes` 的计算过程如图 6-12 所示。`tileSizes` 的初始值由根操作 `lowering_config` 属性中的 `tile_sizes` 字段获得。根操作 `linalg.matmul` 的字段值为 `[[32, 32, 32]]`，表示对 M、N、K 三个维度分别分块时，对应大小为 32、32、32，因此初始值为 `[32, 32, 32]`。但因为 K 维循环索引不在可切分循环索引集合 `partitionableLoopsSet` 中，将 `tileSizes` 中对应 K 维的分块大小设置为 0，表示设备级分块过程不对该维度循环进行分块。经可切分循环维度过滤后，最终得到的 `tileSizes` 向量值为 `[32, 32, 0]`。

```text
getLoweringConfig(lowering_config)     getPartitionableLoops()
                 │                              │
                 ▼                              ▼
tileSizes = [32, 32, 32] ── 保留维度索引 [0, 1] ──► [32, 32, 0]
```

图 6-12　`linalg.matmul` 操作的设备级分块大小。初始配置的三个维度都非零；设备级过滤只把 K 维对应项置零，并未删除该项或改变索引顺序。

#### 4. 配置设备级 Linalg 分块选项

在获取根操作及其分块大小配置（也许还有其他循环分布配置）后，`runOnOperation()` 函数接下来定义设备级分块大小计算函数，并配置设备级 Linalg 分块选项结构体（`LinalgTilingOptions`）对象 `linalgTilingOptions`，该对象中指定的分块选项将应用于随后的分块和融合过程。

`runOnOperation()` 函数中定义的 lambda `tileSizeFn` 是设备级分块大小计算函数。其逻辑比后续将介绍的工作组级和线程束级分块大小计算函数简单，仅需通过生成 `arith.constant` 操作，将预先计算得到的根操作分块大小向量 `tileSizes` 中的 `int64_t` 元素物化为 IR 中的 index 常量，并返回其 `Value`。

> 校订注：原书后文称 `tileSizesFn`，这里与前面的代码变量名 `tileSizeFn` 统一。这不是普通的 C++ 数值类型强制转换，而是创建具有相应数值的 IR 常量操作。

`runOnOperation()` 调用 `LinalgTilingOptions` 结构体中的 `setDistributionOptions()`、`setLoopType()`、`setTileSizeComputationFunction()` 等方法，设置 Linalg 分块选项对象的对应字段。下文依次介绍这三种方法的功能。

##### （1）设置循环分布选项

`LinalgTilingOptions` 的 `setDistributionOptions()` 方法将分块选项对象的 `distribution` 字段（保存 `LinalgLoopDistributionOptions` 结构体）设置为分发到工作组的 Linalg 循环分布选项。该选项由 `getIREELinalgLoopDistributionOptions()` 函数计算得到，可用于将生成的分块循环分发给各处理器（即工作组）并行执行。

> 校订注：原书此处称“工作组级循环分布选项”，指的是分发目标为工作组；它仍属于本节的设备级分块，不是下一节沿 K 维进行的工作组内部归约分块。

`LinalgLoopDistributionOptions` 结构体包含处理器信息函数字段 `procInfo`（类型为 `ProcInfoCallBackFn` 函数对象），在设备级分块过程中可根据并行循环范围等参数返回工作组的分布信息。

`ProcInfoCallBackFn` 的重要参数是 Range 对象数组 `parallelLoopRanges`。该参数描述需要分发的并行循环范围，每个循环范围用一个 `Range` 结构体对象表示，其中包括 `offset`、`size`、`stride` 三个字段。

<!-- 原书第 248 页；PDF 第 26 页。上段跨页。 -->

后续设备级分块过程实现函数 `tileDispatchUsingSCFForOp()` 通过回调函数字段 `procInfo` 调用处理器信息函数时，将以并行循环范围向量 `parallelLoopRanges` 作为参数。该向量在 `tileDispatchUsingSCFForOp()` 中计算得到，相关功能将在下文“生成设备级分块循环并进行分块”部分介绍。

`ProcInfoCallBackFn` 函数对象的返回向量元素类型为 `ProcInfo` 结构体，该结构体包括 `procId`、`nprocs` 和 `distributionMethod` 三个字段。其中，`procId` 为执行迭代的处理器 ID，`nprocs` 为分布执行并行循环的处理器数量，`distributionMethod` 为 `DistributionMethod` 枚举值。在设备级分块上下文中，“处理器”指代工作组。各枚举值对应的分布策略已在本节“循环分布方法”部分详细介绍。

生成循环分布选项的 `getIREELinalgLoopDistributionOptions()` 函数代码实现摘录如下：

```cpp
linalg::LinalgLoopDistributionOptions getIREELinalgLoopDistributionOptions(
    const SmallVector<int64_t> &tileSizes,
    linalg::DistributionMethod distributionMethod,
    int32_t maxWorkgroupParallelDims) {
  return {[&tileSizes, distributionMethod, maxWorkgroupParallelDims](
              /* … */, ArrayRef<Range> parallelLoopRanges) {
    SmallVector<int64_t> nonZeroTileSizes;
    for (int64_t size : tileSizes) {
      if (size != 0)
        nonZeroTileSizes.push_back(size);
    }
    auto numParallelDims = parallelLoopRanges.size();
    SmallVector<linalg::ProcInfo, 3> procInfo(numParallelDims);
    Value splitDim;
    for (size_t dim = 0; dim < numParallelDims; ++dim) {
      if (numParallelDims > maxWorkgroupParallelDims &&
          dim >= maxWorkgroupParallelDims - 1) {
        // …
        procInfo[numParallelDims - dim - 1] =
            {dimValue, numTiles, distributionMethod};
        continue;
      }
      procInfo[numParallelDims - dim - 1] = {
          buildHALWorkgroupInfoOp<HAL::InterfaceWorkgroupIDOp>(builder, dim),
          buildHALWorkgroupInfoOp<HAL::InterfaceWorkgroupCountOp>(builder, dim),
          distributionMethod};
    }
    return procInfo;
  }};
}
```

> 转写说明：lambda 的构造器等参数，以及维度折叠分支中 `dimValue`、`numTiles` 的计算，都是原书已有的省略；本摘录不作为完整可编译函数。返回的回调按引用捕获 `tileSizes`，因此调用回调时该向量必须仍然存活；本节中它来自 pass 方法内的局部配置，不能把该选项任意保存到其生命周期之外。

<!-- 原书第 249 页；PDF 第 27 页。 -->

`getIREELinalgLoopDistributionOptions()` 函数将处理器信息函数字段 `procInfo` 设置为上述匿名 lambda 函数对象。下述 `tileDispatchUsingSCFForOp()` 函数在实际执行分块过程和循环分发时，将取得在该函数中设置的 Linalg 分块选项的 `distribution` 字段，并根据实际的循环结构和设备级分块结果，调用 `procInfo` 指向的 lambda，将生成的分块循环分发到各工作组。lambda 的功能将在下文介绍 `tileDispatchUsingSCFForOp()` 时一并说明。在后续线程束级分块过程中，将以类似方式设置分块选项对象的 `distribution` 字段及其 `procInfo` 回调函数，用于将分块循环分发到各线程束。

##### （2）设置循环分块类型

`LinalgTilingOptions` 的 `setLoopType()` 方法用于设置结构体中的分块循环类型（`LinalgTilingLoopType`）字段 `loopType`。`LinalgTilingLoopType` 是 MLIR 中 Linalg 方言定义的枚举类，用于指定分块过程中生成的循环类型。枚举值 `Loops` 表示分块过程可能生成 `scf.for` 循环，该类型具有明确的循环边界及顺序迭代语义；`AffineLoops` 表示可能生成 `affine.for` 循环，该类型已在 5.2.1 节介绍；`ParallelLoops` 表示可能生成 `scf.parallel` 循环，其迭代之间不规定串行先后顺序，可以并行执行。

本节选用的设备级分布路径使用隐式分块循环嵌套，而不是显式 `scf.for` 循环嵌套。因此，虽然此处将 `loopType` 设置为 `Loops`，但后续调用的设备级分块循环生成函数 `generateTileLoopNest()` 不会为这些已经一一映射到工作组的维度生成 `scf.for` 操作。在后续线程束级分块过程中，将针对分块选项中的不同 `LinalgTilingLoopType` 值，生成相应循环操作。`generateTileLoopNest()` 的功能将在下文分析设备级分块隐式循环嵌套结构生成过程时说明。

> 校订注：原书称“设备级分块只支持……隐式分块循环嵌套”，这里限定为本节讨论的 IREE 路径及其配置，不把它推广成所有设备级分块算法或 MLIR 的一般限制。

##### （3）设置分块大小计算函数

`LinalgTilingOptions` 的 `setTileSizeComputationFunction()` 方法用于设置结构体中的分块大小计算函数字段 `tileSizeComputationFunction`。

其参数类型 `TileSizeComputationFunction` 是函数包装类型的别名，可以保存符合指定签名和包装要求的可调用对象。`runOnOperation()` 中定义的设备级分块大小计算 lambda `tileSizeFn` 符合要求，因此可以通过 `tileSizeComputationFunction` 将这个回调传递给其他函数，以便在需要时计算分块大小。下述 `tileDispatchUsingSCFForOp()` 将调用该函数对象，为 Linalg 操作计算各维度的设备级分块大小。

本章测试用例不涉及交换（interchange）功能，为简化描述，本章对该功能不展开论述。

#### 5. 执行设备级分块和融合过程

在调用 `LinalgTilingOptions` 结构体各方法完成设备级 Linalg 分块选项配置后，`runOnOperation()` 函数接下来调用设备级分块和融合过程实现函数 `tileAndFuseDispatchUsingSCFForOp()`，对函数参数 `op` 给定的计算操作执行设备级分块和循环分发过程，并将给定计算操作与其可能的生产者操作融合，以提高并行执行的效率。

<!-- 原书第 250 页；PDF 第 28 页。上段跨页。 -->

由 `tileAndFuseDispatchUsingSCFForOp()` 函数代码实现可总结得到该函数调用流程，如图 6-13 所示。

```text
tileAndFuseDispatchUsingSCFForOp()
├── getAllFusableProducers()                收集可以与计算操作融合的生产者操作
├── tileDispatchUsingSCFForOp()             对计算操作进行显式或隐式分块
│   ├── generateTileLoopNest()              生成设备级分块隐式循环嵌套结构
│   ├── getTiledImplementation()            使用切片操作对计算操作分块
│   └── …                                  原图省略的步骤
├── getAllFusableProducerUses()             收集对未分块操作结果做切片的
│                                          tensor.extract_slice 操作
├── replaceExtractSliceWithTiledProducer()  替换切片操作结果
└── …                                      原图省略的后续步骤
```

图 6-13　`tileAndFuseDispatchUsingSCFForOp()` 函数调用流程图。

该函数是 `TileAndDistributeToWorkgroups` pass 实现分块和融合优化的关键部分。如图 6-13 所示，其功能主要分为收集可融合生产者操作、生成设备级分块循环并进行分块、收集切片操作和替换切片操作结果 4 个部分。以下各小节将按照上述调用流程分别详述各部分功能。

##### （1）收集可融合生产者操作

`tileAndFuseDispatchUsingSCFForOp()` 在对参数 `op` 给定的 Linalg 计算操作执行分块和循环分发前，首先调用 `getAllFusableProducers()` 函数，通过广度优先搜索沿操作数的定义关系遍历，收集可以与 Linalg 计算操作 `op` 融合的生产者操作，为接下来的融合优化做准备。融合优化的目标是把相关计算组织到同一分块计算区域中，减少中间内存访问；在涉及不同内核的融合场景中，还可能减少内核启动开销。

> 校订注：原书将融合概括为“将多个操作合并成一个操作”。本节变换并不要求把 fill 和 matmul 改为一个 MLIR 操作；它们可以仍是不同操作，只是在同一分块中计算。这里已经位于同一个 dispatch 内，也不能仅凭此次分块融合就声称减少了内核启动次数。

`getAllFusableProducers()` 从参数 `op` 给定的 Linalg 计算操作开始，遍历该操作的所有操作数，并对每个操作数调用 `getDefiningOp()` 接口，得到该操作数的定值操作 `definingOp`。

`TilingInterface` 中定义了这种融合和分块所需的方法，因此本路径以是否实现该接口作为生产者候选的条件之一。如果 `definingOp` 实现了 `TilingInterface`，则可将其视为潜在的可融合生产者操作，添加到集合 `producers` 中。这不是说 MLIR 中其他融合机制也一律要求这一接口。

测试用例中的计算操作 `linalg.matmul` 有输入操作数 `%3`、`%4`，二者的定值操作均为 `flow.dispatch.tensor.load`。按书中版本，该操作未实现 `TilingInterface`，不符合本路径的融合条件，不能作为可融合生产者添加到 `producers` 集合中。

<!-- 原书第 251 页；PDF 第 29 页。 -->

`linalg.matmul` 的输出初始化操作数 `%6` 的定值操作为 `linalg.fill`，后者实现了 `TilingInterface`，可以作为可融合生产者添加到 `producers` 集合中。`linalg.fill` 的输入操作数 `%cst` 为常量，输出初始化操作数 `%5` 的定值操作为 `tensor.empty`，均不符合这里的融合条件，不能添加到集合。因此，`getAllFusableProducers()` 返回的 `producers` 集合中仅有 `linalg.fill`。可融合生产者操作与计算操作之间的生产者—消费者关系如图 6-14 所示。

```text
compute op: %7 = linalg.matmul ins(%3, %4) outs(%6)
├── %3 的 producer: %3 = flow.dispatch.tensor.load %0
├── %4 的 producer: %4 = flow.dispatch.tensor.load %1
└── %6 的 fusable producer: %6 = linalg.fill ins(%cst) outs(%5)
                           └── 此操作进入 producers 集合
```

图 6-14　可融合生产者操作与计算操作。原图上方并列两个 load 与一个 fill，下方为 matmul；从 matmul 向上追溯三条操作数定义关系，只有右侧 fill 标在 `producers / fusable producer` 下。这里 `%6` 虽写在 `outs` 中，仍是 matmul 使用的初始化操作数，不是 matmul 产生的 SSA 结果。

##### （2）生成设备级分块循环并进行分块

`tileAndFuseDispatchUsingSCFForOp()` 功能的重点是调用 `tileDispatchUsingSCFForOp()`，根据前述 `LinalgTilingOptions` 结构体对象设置，为计算操作生成显式或隐式分块循环嵌套，从而实现设备级分块循环的分发和并行执行。

`tileDispatchUsingSCFForOp()` 的主要功能分为 4 个部分，相关代码注释标示了每部分的功能说明，以下分别介绍。

###### 1）获取计算操作迭代域

为了便于计算设备级分块大小和生成分块循环结构，`tileDispatchUsingSCFForOp()` 首先调用 `getIterationDomain()` 接口获取计算操作的迭代域，即该操作执行的循环范围。迭代域向量 `iterationDomain` 中的每个元素是一个循环范围，由 `Range` 对象表示。

对于本章测试用例，`linalg.matmul` 的 `iterationDomain` 向量值为 `[[0, 512, 1], [0, 512, 1], [0, 512, 1]]`，其中三个元素分别对应 M、N 和内积维度 K 的 `Range` 对象；设备级分块不切分 K 维，但它仍存在于原操作迭代域中，因此向量长度为 3。

###### 2）计算工作组处理器信息

前文“配置设备级 Linalg 分块选项”部分已提到，`runOnOperation()` 将设备级 Linalg 分块选项对象 `linalgTilingOptions` 的分块大小计算函数设置为 lambda `tileSizeFn`。`tileDispatchUsingSCFForOp()` 使用的分块选项 `options` 中，`tileSizeComputationFunction` 字段指向这个回调。调用它可以获得计算操作 M、N 维的设备级分块大小，并将结果保存在向量 `tileSizes` 中。

对于本章测试用例，计算得到的 `tileSizes` 向量值为 `[32, 32, 0]`。如果 M 或 N 维的设备级分块大小不为 0，则说明后续需要调用 `getTiledImplementation()` 在该维度执行分块。

<!-- 原书第 252 页；PDF 第 30 页。上段跨页。 -->

如果 Linalg 分块选项中指定了 `distribution` 字段，`tileDispatchUsingSCFForOp()` 接下来通过分布选项的回调函数字段 `procInfo`，调用其指向的处理器信息函数，得到处理器信息向量 `procInfo`。为了区分同名对象，后文将函数成员称为“回调函数 `procInfo`”，将返回结果称为“向量 `procInfo`”。向量中的处理器信息可在执行设备级分块时协助建立计算任务到工作组的映射，将生成的分块循环分发到各工作组。

前文在分析配置设备级 Linalg 分块选项时已经提到，分布选项对象的 `procInfo` 字段指向 `getIREELinalgLoopDistributionOptions()` 返回对象中保存的匿名 lambda。因此，通过回调函数 `procInfo` 调用的正是该 lambda（下文称为处理器信息 lambda），即向量 `procInfo` 由调用处理器信息 lambda 得到。

处理器信息 lambda 的主要参数为并行循环范围向量 `parallelLoopRanges`。为了构造这个向量，必须先确定计算操作哪些维度是并行维度。为此，`tileDispatchUsingSCFForOp()` 通过 `op.getLoopIteratorTypes()` 接口，获得计算操作所有维度的迭代器类型数组（记为 `iteratorTypes`），每个数组位置对应一个循环维度索引。迭代器类型通常包括并行（parallel）和归约（reduction）两类。测试用例中，`linalg.matmul` 的迭代器类型依次为 `[parallel, parallel, reduction]`；带索引写为 `[{0, parallel}, {1, parallel}, {2, reduction}]`，即只有索引 2 对应归约维度，其他维度均为并行维度。

`tileDispatchUsingSCFForOp()` 只对真正需要并行分发的循环维度进行处理，避免分发非并行循环、不需要分块或只有单个分块的循环。因此，`parallelLoopRanges` 中只保留迭代器类型为并行、分块大小不为 0、且不是已知仅有一个分块的维度的循环范围。

已知计算操作的循环范围和分块大小，便可以计算分块数量。原书这段代码使用的表达式为：

```text
numTiles = ceil((iterationDomain.size - iterationDomain.offset)
                / (iterationDomain.stride * tileSize))
numTilesExprs: ()[s0, s1, s2, s3] -> ((s1 - s0) ceildiv (s2 * s3))
```

> 校订注：原书正文只写除法，映射却使用 `ceildiv`，已补明向上取整。本例的 `offset = 0`、`stride = 1`，没有歧义；不能将这段历史代码中对 `Range.size` 的使用泛化为所有接口下“size 就是绝对上界”。此外，含符号乘积和符号除数的表达式属于半仿射形式，不是第 5 章普通仿射约束允许的常量乘除；本例代入常量后可折叠。

测试用例中，`iterationDomain = [[0, 512, 1], [0, 512, 1], [0, 512, 1]]`，迭代器类型及索引为 `[{0, parallel}, {1, parallel}, {2, reduction}]`，`tileSizes = [32, 32, 0]`。将循环范围和分块大小绑定到 `numTilesExprs` 的各符号，可计算得到 M、N 维分块数量均为 16（= (512 − 0) / (1 × 32)）。K 维分块大小为 0，表示不分块，不对它计算除以零的分块数量。

迭代域向量经过迭代器类型、分块大小和分块数量条件过滤后，得到 `parallelLoopRanges = [{0, 512, 1}, {0, 512, 1}]`，其中仅保留并行维度 M 和 N 的循环范围。图 6-15 总结了上述计算过程。

<!-- 原书第 253 页；PDF 第 31 页。 -->

| 检查项目 | M（索引 0） | N（索引 1） | K（索引 2） |
| --- | --- | --- | --- |
| 迭代域向量元素 | `[0, 512, 1]` | `[0, 512, 1]` | `[0, 512, 1]` |
| 迭代器类型 | parallel | parallel | reduction |
| 分块大小 | 32 | 32 | 0 |
| 分块数量 | 16 | 16 | 不计算 |
| `parallelLoopRanges` | 保留为第 0 项 | 保留为第 1 项 | 过滤 |

```text
parallelLoopRanges = [[0, 512, 1], [0, 512, 1]]
                         ↓
options.distribution->procInfo(rewriter, loc, parallelLoopRanges)
```

图 6-15　设备级分块 `parallelLoopRanges` 向量计算过程。原图自上而下排列迭代域、三个筛选条件、保留的两个 Range，以及使用该向量的回调调用。

在获得 `parallelLoopRanges` 向量后，`tileDispatchUsingSCFForOp()` 通过调用分布选项的 `procInfo` 回调所指向的处理器信息 lambda，计算处理器向量 `procInfo` 中的各元素，调用参数包括 `parallelLoopRanges`。

`getIREELinalgLoopDistributionOptions()` 中定义的处理器信息 lambda 首先过滤分块大小向量 `tileSizes`，仅保留其中非零元素。通过遍历需要分布的并行维度，该 lambda 为每个维度上的工作组生成 `ProcInfo` 结构体对象。

测试用例中 `linalg.matmul` 的待分布并行维度数量为 2，小于 `maxWorkgroupParallelDims` 默认值 3，因此只需为 M、N 维计算对应的 `procInfo` 数组元素。M 维对应 `procInfo[0]`，N 维对应 `procInfo[1]`。每个维度都有对应的 `hal.interface.workgroup.id` 和 `hal.interface.workgroup.count` 操作，分别用于获取工作组 ID 和数量，其结果保存为相应元素的 `procId` 和 `nprocs` 字段。

图 6-16 总结了当 `parallelLoopRanges = [{0, 512, 1}, {0, 512, 1}]` 时，生成处理器向量的过程。

| 原循环范围与向量元素 | `ProcInfo` 字段 | 字段内容 |
| --- | --- | --- |
| M：`{0, 512, 1}` → `procInfo[0]` | `procId` | `%workgroup_id_y = hal.interface.workgroup.id[1] : index` |
| 同上 | `nprocs` | `%workgroup_count_y = hal.interface.workgroup.count[1] : index` |
| 同上 | `distributionMethod` | `CyclicNumProcsEqNumIters` |
| N：`{0, 512, 1}` → `procInfo[1]` | `procId` | `%workgroup_id_x = hal.interface.workgroup.id[0] : index` |
| 同上 | `nprocs` | `%workgroup_count_x = hal.interface.workgroup.count[0] : index` |
| 同上 | `distributionMethod` | `CyclicNumProcsEqNumIters` |

图 6-16　`linalg.matmul` 操作的处理器（工作组）信息向量生成过程。原图左侧的两条 Range 经 `procInfo()` 回调分别形成两个向量元素，右侧逐字段展开。注意循环维度与硬件维度的顺序相反：M 映射到 y（维度 1），N 映射到 x（维度 0），对应代码中的 `procInfo[numParallelDims - dim - 1]`。

<!-- 原书第 254 页；PDF 第 32 页。 -->

处理器信息 lambda 生成的 `procInfo` 向量，将在下述生成设备级分块循环嵌套结构的过程中，用于计算工作组分块下界和分块步长。

###### 3）生成设备级分块隐式循环嵌套结构

前文在介绍循环分布方法时已经提到，`createTileAndDistributeToWorkgroupsPass()` 在生成 pass 实例时，指定循环分布方法参数为 `CyclicNumProcsEqNumIters`。在该策略下，对每个分布维度，工作组数量等于分块循环迭代次数，每个工作组与一次迭代严格对应，因此书中将这种情况理解为借助 GPU 并行执行实现的隐式循环嵌套结构。此时不需要为这些分块维度生成显式 `scf.for` 循环。如果在其他场景下指定 `Cyclic` 策略，则可能需要生成显式 `scf.for` 循环嵌套，初始循环体尚无计算逻辑，由后续代码填充。

本小节重点讨论 `tileDispatchUsingSCFForOp()` 为设备级分块生成隐式循环嵌套结构的过程。

该函数在获得处理器信息向量 `procInfo`、循环范围等必要参数后，调用 `generateTileLoopNest()`，根据不同循环分布方法，生成隐式的分块索引映射或显式 `scf.for` 循环嵌套结构。

为避免矩阵维度大小不是分块大小整数倍时，尾块访问超出范围，`generateTileLoopNest()` 定义了 lambda `createBoundedTileSize`，用于计算有界分块大小（bounded tile size），计算方式为 `min(tileSize, ub - iv)`，即在 `tileSize` 与循环上界 `ub` 减去当前索引 `iv` 之间取最小值。对应的 AffineMap 对象 `minMap` 为 `(d0)[s0, s1] -> (s0, s1 - d0)`，配合 `affine.min` 取两个结果中的最小值。

`generateTileLoopNest()` 接下来遍历函数参数 `loopRanges`（即迭代域向量 `iterationDomain`），并将循环范围变量 `loopRange` 与向量元素绑定。在其后计算分发工作组数量、有界分块大小和生成 `scf.for` 循环操作的过程中，都要用到 Linalg 操作的循环范围，以确定设备级分块的范围。

`loopRange` 提供循环范围相关信息。在本节这段代码的用法中，将 `loopRange.offset` 作为循环下界 `lb`，将 `loopRange.size` 作为循环上界 `ub`，将 `tileSizeVals` 向量元素值作为步长 `step`，后续用于计算有界分块大小等信息。测试用例中，`loopRanges = [[0, 512, 1], [0, 512, 1], [0, 512, 1]]`，`tileSizeVals = [32, 32, 0]`。由此可得，M、N 维的分块循环下界均为 0，上界均为 512，步长均为 32。

由 `loopRange` 确定分块循环范围后，`generateTileLoopNest()` 还需要确定按 `tileSizeVals` 指定的分块大小切分后，各维需要的工作组数量（记为 `numWorkgroups`）。本例单位步长下的计算方式及映射为：

```text
numWorkgroups = ceil((loopRange.size - loopRange.offset) / tileSize)
numIterationsMap: ()[s0, s1, s2] -> ((s1 - s0) ceildiv s2)
```

对于本章测试用例，M、N 两维的 `numWorkgroups` 均为 16（= (512 − 0) / 32）。K 维分块大小为 0，因此不需要计算 K 维的分发工作组数量。

<!-- 原书第 255 页；PDF 第 33 页。上段跨页。 -->

前文在介绍循环分布方法时已经提到，经过 `CyclicNumProcsGeNumIters` 或 `CyclicNumProcsEqNumIters` 策略转换得到的新循环下界（也是其至多一次迭代的索引），是各工作组负责的分块在原始 M、N 维上的偏移量，称为工作组分块下界。其计算方式为 `lb + procId * step`，对应的 `offsetMap` 为 `()[s0, s1, s2] -> (s0 + s1 * s2)`。

经过 `Cyclic` 策略转换得到的新循环步长，是同一工作组相邻两次处理的块起点之间的距离，称为工作组分块步长。计算方式为 `step * nprocs`，对应的 `stepMap` 为 `()[s0, s1] -> (s0 * s1)`。

分块下界和分块步长的计算由 `getDistributeLBAndStep()` 实现。对于本章测试用例，在每个分布维度上可生成两类 `affine.apply` 操作。第一类将工作组的 y、x 维度 ID 乘以分块大小 32，得到该工作组在 M、N 维上的分块下界 `distributeLB`，分别为：

```mlir
affine.apply affine_map<()[s0] -> (s0 * 32)>()[%workgroup_id_y]
affine.apply affine_map<()[s0] -> (s0 * 32)>()[%workgroup_id_x]
```

`%workgroup_id_y`、`%workgroup_id_x` 由上述处理器信息 lambda 通过 `hal.interface.workgroup.id` 操作得到。

第二类 `affine.apply` 将 y、x 维度的工作组数量 `%workgroup_count_y`、`%workgroup_count_x` 乘以分块大小 32，得到工作组在 M、N 维上的分块步长 `distributeStep`，分别为：

```mlir
affine.apply affine_map<()[s0] -> (s0 * 32)>()[%workgroup_count_y]
affine.apply affine_map<()[s0] -> (s0 * 32)>()[%workgroup_count_x]
```

`%workgroup_count_y`、`%workgroup_count_x` 由上述 lambda 通过 `hal.interface.workgroup.count` 操作得到。

由于本 pass 配置的分布策略为 `CyclicNumProcsEqNumIters`，`generateTileLoopNest()` 不需要在输出 IR 中显式生成 `scf.for` 操作，只需将当前维度的 `offsets` 元素设置为分布后的下界 `distributeLB`，并确保 `sizes` 元素为不越界的分块大小。因此，该函数最终返回的 `scf.for` 循环集合 `loops` 为空。

> 校订注：原书此处写“原始循环下界 lb”，但本例不能把各工作组的偏移都设为原始下界 0；应是更新为 `lb + procId * step` 后的下界。`EqNumIters` 路径没有后续循环迭代，其计算出来的分布步长不需要用于实际循环，未使用的计算可被清理。前述含符号乘法的通用模板应按半仿射表达式理解，本例代入常量 32 后为普通仿射形式。

如前所述，`createBoundedTileSize` 生成 `affine.min`，用于计算 `min(tileSize, ub - iv)`。本例的 `tileSize` 为 32，循环上界 `ub` 为 M 或 N 维大小 512，迭代索引 `iv` 为各工作组在对应维度上的分块下界，即 `%workgroup_id_y * 32` 或 `%workgroup_id_x * 32`。因此，计算有界分块大小的操作分别为：

<!-- 原书第 256 页；PDF 第 34 页。上段跨页。 -->

```mlir
affine.min affine_map<()[s0] -> (32, s0 * -32 + 512)>()[%workgroup_id_y]
affine.min affine_map<()[s0] -> (32, s0 * -32 + 512)>()[%workgroup_id_x]
```

值得注意的是，如果分析及规范化将 `affine.min` 的结果确定为常量并折叠，最终输出 IR 中便不再需要该操作。

对于测试用例，M、N 维上的分块大小为 32×32，输出矩阵大小为 512×512，正确启动配置下 `%workgroup_id_y`、`%workgroup_id_x` 均在 0～15 范围内，于是 `512 - %workgroup_id_x/y * 32 >= 32`。因此，这两个 `affine.min` 的结果恒为 32，利用相应范围信息进行化简后可以用常量 32 替换。

> 校订注：原书重复写了两个 `%workgroup_id_x`，已区分 x、y。这里需要工作组 ID 的有效范围知识，不是仅凭操作数均为字面常量进行的普通常量折叠。原书下一页仍展示未化简的动态切片，属于不同中间阶段，不应认为两种 IR 同时就是同一个瞬时状态。

根据以上分析，可总结得到 `generateTileLoopNest()` 的执行流程，如图 6-17 所示。

```text
开始
  ↓
遍历 loopRanges，将 loopRange 与当前元素绑定
  ↓
tileSizeVals 对应元素是否为 0？
  ├── 是：跳过该维的分块，继续遍历
  └── 否：计算分发工作组数量
           ↓
         计算工作组分块下界和分块步长
           ↓
         分发策略是否为 CyclicNumProcsEqNumIters？
           ├── 是：计算有界分块大小
           └── 否：生成 scf.for 循环操作，保存在 loops
                     （原图针对需要显式循环的分支作此简化）
           ↓
         遍历 loopRanges 是否结束？
           ├── 否：回到遍历步骤
           └── 是：返回 scf.for 循环集合 loops → 结束
```

图 6-17　`generateTileLoopNest()` 函数执行流程图。原图左右分别为生成显式循环和计算隐式分块大小的分支，各有“遍历是否结束”判断并汇合到返回节点；零分块维的箭头直接回到遍历节点。

> 校订注：这张原图是本节调用路径的简化图，不能把“不是 Eq 就生成 for”泛化到前文全部分布策略；`GeNumIters` 的语义是至多一次计算加边界检查，具体是否支持该策略以及如何生成 IR 取决于调用实现。

###### 4）对计算操作进行分块

如前所述，本节设备级分布不生成显式分块循环嵌套，但 `tileDispatchUsingSCFForOp()` 仍需根据 `generateTileLoopNest()` 计算得到的分块偏移量向量 `offsets` 和分块大小向量 `sizes`，调用 `TilingInterface` 的 `getTiledImplementation()`，对 Linalg 计算操作的操作数进行分块。

<!-- 原书第 257 页；PDF 第 35 页。 -->

在执行设备级分块前，测试用例中 `linalg.matmul` 的输入、输出初始化操作数保存在向量 `valuesToTile` 中，它们的定义分别为：

```text
%3 = flow.dispatch.tensor.load %0, offsets = [0, 0], sizes = [512, 512],
    strides = [1, 1] : …<readonly:tensor<512x512xf16>> -> tensor<512x512xf16>
%4 = flow.dispatch.tensor.load %1, offsets = [0, 0], sizes = [512, 512],
    strides = [1, 1] : …<readonly:tensor<512x512xf16>> -> tensor<512x512xf16>
%6 = linalg.fill {lowering_config = #iree_codegen.lowering_config<tile_sizes = [[32, 32, 32]]>}
    ins(%cst : f16) outs(%5 : tensor<512x512xf16>) -> tensor<512x512xf16>
```

`getTiledImplementation()` 在对 `valuesToTile` 中的操作数 `%3`、`%4`、`%6` 进行分块时，调用 Linalg 方言工具函数 `makeTiledShapes()`，根据操作数类型选择不同操作完成分块。如果操作数为张量，则使用 `tensor.extract_slice`；如果操作数为 memref，则使用 `memref.subview`。`memref.subview` 的详细用法见原书附带文档《memref.subview 操作用法解析》。本例 `linalg.matmul` 的操作数类型为张量，因此使用 `tensor.extract_slice` 完成分块。

> 资料说明：保留原书附带文档的交叉引用；该附带文档未包含在当前提供的章节 PDF 中，不能视为已经转入本文。

分块后的操作数分别为：

```mlir
%extracted_slice = tensor.extract_slice %3[%16, 0] [%10, 512] [1, 1]
    : tensor<512x512xf16> to tensor<?x512xf16>
%extracted_slice_3 = tensor.extract_slice %4[0, %18] [512, %13] [1, 1]
    : tensor<512x512xf16> to tensor<512x?xf16>
%extracted_slice_4 = tensor.extract_slice %6[%20, %22] [%10, %13] [1, 1]
    : tensor<512x512xf16> to tensor<?x?xf16>
```

上述切片偏移量和大小先由 `affine.apply` 和 `affine.min` 等操作计算，因此在尚未完成相关化简时，结果张量类型中可能出现 `?`，表示动态大小。针对本例，后续可确定这些动态大小均为 32，但偏移量仍由工作组 ID 决定，不是全局固定常量。切片操作生成的 `%extracted_slice`、`%extracted_slice_3`、`%extracted_slice_4` 分别是 `%3`、`%4`、`%6` 的一部分，切片位置和大小由偏移量、切片大小参数决定。

> 校订注：原书说“后续优化中可以确定切片偏移量和大小为常量”，混淆了两者。本例只有分块大小可静态确定为 32；动态偏移量本身不要求结果张量的大小也动态。

其中，这三个已分块操作数在 `%3`、`%4`、`%6` 的 M 或 N 维上的切片偏移量 `%16`、`%18`、`%20` 和 `%22` 均为 `affine.apply` 结果：

```mlir
%16 = affine.apply affine_map<()[s0] -> (s0 * 32)>()[%workgroup_id_y]
%18 = affine.apply affine_map<()[s0] -> (s0 * 32)>()[%workgroup_id_x]
%20 = affine.apply affine_map<()[s0] -> (s0 * 32)>()[%workgroup_id_y]
%22 = affine.apply affine_map<()[s0] -> (s0 * 32)>()[%workgroup_id_x]
```

上述切片偏移量均来自 `generateTileLoopNest()` 计算的分块偏移量向量 `offsets`。

已分块操作数 `%extracted_slice`、`%extracted_slice_3`、`%extracted_slice_4` 在 `%3`、`%4`、`%6` 的 M 或 N 维上的切片大小 `%10`、`%13` 均为 `affine.min` 操作结果：

<!-- 原书第 258 页；PDF 第 36 页。上段跨页。 -->

```mlir
%10 = affine.min affine_map<()[s0] -> (32, s0 * -32 + 512)>()[%workgroup_id_y]
%13 = affine.min affine_map<()[s0] -> (32, s0 * -32 + 512)>()[%workgroup_id_x]
```

上述切片大小均来自 `generateTileLoopNest()` 计算的分块大小向量 `sizes`。

`getTiledImplementation()` 根据工作组 ID 及上述偏移量、大小，使用切片操作取得原始操作数的较小分块，并构造以这些切片为操作数的新计算操作，保存在已分块操作集合 `tiledOps` 中。`affine.apply`、`affine.min` 提供索引和大小，不是它们自身执行张量切片。对 `linalg.matmul` 分块的结果如下：

```mlir
linalg.matmul {lowering_config = #iree_codegen.lowering_config<tile_sizes = [[32, 32, 32]]>}
    ins(%extracted_slice, %extracted_slice_3 : tensor<?x512xf16>, tensor<512x?xf16>)
    outs(%extracted_slice_4 : tensor<?x?xf16>) -> tensor<?x?xf16>
```

由分块结果可见，执行设备级分块后的 `linalg.matmul` 相比之前，矩阵操作数 A 的大小由 512×512 变为 32×512，矩阵操作数 B 的大小由 512×512 变为 512×32，结果矩阵块的大小由 512×512 变为 32×32，完成了操作的设备级分块及分块计算在各个工作组上的分布。

##### （3）收集切片操作

在对计算操作进行设备级分块后，为了通过融合优化进一步提高性能，还需要在对计算操作和可融合生产者操作进行分块的基础上，将可融合生产者操作按消费切片所需的范围重新计算，从而减少中间内存访问等开销。生产者操作的定义见前述“收集可融合生产者操作”部分。

`tileAndFuseDispatchUsingSCFForOp()` 调用 `getAllFusableProducerUses()`，收集连接生产者和消费者的 `tensor.extract_slice` 切片操作，为后续融合优化做准备。具体来说，该函数负责收集对参数 `untiledOp` 指定的未分块操作（即可融合生产者）的结果做切片的 `tensor.extract_slice`；这些切片结果作为操作数被传递给参数 `tiledOps` 指定的已分块计算操作。

`getAllFusableProducerUses()` 遍历已分块计算操作的所有操作数，并由 `getDefiningOp()` 得到生成这些操作数的定值操作。如果定值操作是 `tensor.extract_slice`，并且其源操作数的定值操作正是未分块操作 `untiledOp`，则将该切片操作添加到集合 `sliceOps` 中，最后返回集合。此处的 `untiledOp` 就是前述可融合生产者操作。

针对本章测试用例，已分块操作如下。注意，三个矩阵操作数经过分块后的实际大小分别为 32×512、512×32、32×32。

```text
%24 = linalg.matmul {…}
    ins(%extracted_slice, %extracted_slice_3 : tensor<?x512xf16>, tensor<512x?xf16>)
    outs(%extracted_slice_4 : tensor<?x?xf16>) -> tensor<?x?xf16>
```

`linalg.matmul` 的操作数 `%extracted_slice`、`%extracted_slice_3`、`%extracted_slice_4` 的定值操作均为 `tensor.extract_slice`，各定义已在上一小节描述。其中只有切片源 `%6` 的定值操作 `linalg.fill` 是本次选中的未分块可融合生产者。这个 fill 的张量初始化操作数及结果尚未分块，大小均为 512×512；它的填充值 `%cst` 则是 f16 标量。其他两个切片的源操作数 `%3`、`%4` 的定值操作 `flow.dispatch.tensor.load` 不是本次的可融合生产者。因此，只有生成 `%extracted_slice_4` 的切片满足条件，并被保存在 `sliceOps` 中返回。

<!-- 原书第 259 页；PDF 第 37 页。上段跨页。 -->

综上，图 6-18 总结了 `sliceOps` 中的 `tensor.extract_slice` 与已分块、未分块操作的关系：该切片必须是已分块操作某个操作数的定值操作，而切片源操作数的定值操作必须是当前未分块的可融合生产者。满足这些条件的切片才被添加到集合。

```text
tiledOp:
%24 = linalg.matmul ins(%extracted_slice, %extracted_slice_3)
                   outs(%extracted_slice_4)
├── %extracted_slice = tensor.extract_slice %3
│   └── producer: %3 = flow.dispatch.tensor.load %0
├── %extracted_slice_3 = tensor.extract_slice %4
│   └── producer: %4 = flow.dispatch.tensor.load %1
└── %extracted_slice_4 = tensor.extract_slice %6   ← 纳入 sliceOps
    └── fusable producer / untiledOp:
        %6 = linalg.fill ins(%cst) outs(%5)
```

图 6-18　已分块操作、未分块操作与切片操作的关系。原图以三列展示上方的两个 load、一个 fill，中间为各自的切片，下方为 matmul；右侧切片单独标为 `sliceOps`，右上方 fill 单独标为 `fusable producer / untiledOp`。

##### （4）替换切片操作结果

切片操作结果替换的目的是将已分块计算操作 `tiledOp` 的操作数，替换为分块后的可融合生产者操作的结果，由此完成部分操作融合。为此，`tileAndFuseDispatchUsingSCFForOp()` 首先调用 `replaceExtractSliceWithTiledProducer()`，根据参数 `sliceOp` 指定切片的偏移量和大小，对尚未分块的可融合生产者进行分块，得到分块结果；随后通过重写器的 `replaceOp()` 接口，将该切片的结果替换为分块生产者的结果。

对本章测试用例中未分块的 `linalg.fill` 分块，可表示为：

```mlir
%fill_init_slice = tensor.extract_slice %5[%20, %22] [%10, %13] [1, 1]
    : tensor<512x512xf16> to tensor<?x?xf16>
%30 = linalg.fill {lowering_config = #iree_codegen.lowering_config<tile_sizes = [[32, 32, 32]]>}
    ins(%cst : f16) outs(%fill_init_slice : tensor<?x?xf16>) -> tensor<?x?xf16>
```

> 校订注：原书这里将分块 fill 的 `outs` 仍写成前面的 `%extracted_slice_4`，但该值已经定义为从 fill 结果 `%6` 上取切片。随后又要求用 `%30` 替换它，会使读者得到自依赖或重复填充的错误数据流。这里补明：分块 fill 的初始化张量来自原 fill 的初始化操作数 `%5` 的切片，另命名为 `%fill_init_slice`，与被替换的 `%6` 结果切片区分。新增的第一行用于明确这一定义关系；原书后面提到的 `SwapExtractSliceWithTensorEmpty` 可以进一步简化它。

分块前，`linalg.fill` 的输出初始化操作数为 `%5`，大小为 512×512；分块后为 `%fill_init_slice`，实际大小为 32×32。

如前所述，切片结果替换前，`linalg.matmul` 的输出初始化操作数为 `%extracted_slice_4`。经过替换后的操作如下：

<!-- 原书第 260 页；PDF 第 38 页。上段跨页。 -->

```text
%31 = linalg.matmul {…}
    ins(%extracted_slice, %extracted_slice_3 : tensor<?x512xf16>, tensor<512x?xf16>)
    outs(%30 : tensor<?x?xf16>) -> tensor<?x?xf16>
```

经过替换，已分块计算操作的操作数大小保持不变，但输出初始化操作数不再是原切片结果 `%extracted_slice_4`，而是已分块可融合生产者 `linalg.fill` 的结果 `%30`，由此实现部分操作融合。融合后的计算操作及其操作数如图 6-19 所示。

```text
%31 = linalg.matmul ins(%extracted_slice, %extracted_slice_3) outs(%30)
├── %extracted_slice = …
├── %extracted_slice_3 = …
└── %30 = linalg.fill ins(%cst) outs(%fill_init_slice)
```

图 6-19　融合后的已分块计算操作及其操作数。原图上方三个框对应两项输入切片和新 fill，下方为 matmul；图中的 matmul 结果仍编号 `%24`，本文按紧邻正文 `%31` 统一。fill 初始化操作数按上述定义关系区分，不与被替换切片同名。

上述替换只是融合过程的中间状态，其中涉及已分块计算操作输出初始化操作数的替换；其他输入操作数的处理，需由 `runOnOperation()` 随后应用的 `SwapExtractSliceWithDispatchTensorLoad`、`SwapExtractSliceWithTensorEmpty` 重写模式及其他优化完成。原书由于篇幅限制，不对详细过程展开描述。

在能够以分块生产者结果或直接的分块加载替代中间切片时，可以消除不再需要的切片结果，从而减少不必要的中间张量构造及其潜在存储、加载开销。这并不要求所有操作数都来自前述 `producers` 集合，也不意味着将全部计算压成一个 MLIR 操作；最终示例仍分别含有 load、fill 和 matmul。

`runOnOperation()` 在完成计算操作分块并分发到工作组后，还需应用一系列规范化和优化模式，对分块、分发过程引入的冗余或非规范化代码进行清理和简化，这对获得良好的运行时性能很有必要。

经过 `TileAndDistributeToWorkgroups` pass 处理后，原书给出的最终输出 IR 摘录如下：

```text
func.func @matmul_dispatch_0_matmul_512x512x512_f16()
    attributes {translation_info = …} {
  …
  %0 = hal.interface.binding.subspan … : …<readonly:tensor<512x512xf16>>
  %1 = hal.interface.binding.subspan … : …<readonly:tensor<512x512xf16>>
  %2 = hal.interface.binding.subspan … : …<writeonly:tensor<512x512xf16>>
  %workgroup_id_x = hal.interface.workgroup.id[0] : index
  %workgroup_id_y = hal.interface.workgroup.id[1] : index
  %3 = affine.apply affine_map<()[s0] -> (s0 * 32)>()[%workgroup_id_y]
  %4 = flow.dispatch.tensor.load %0, offsets = [%3, 0], sizes = [%c32, 512],
      strides = [1, 1] : …<readonly:tensor<512x512xf16>> -> tensor<?x512xf16>
  %5 = affine.apply affine_map<()[s0] -> (s0 * 32)>()[%workgroup_id_x]
  %6 = flow.dispatch.tensor.load %1, offsets = [0, %5], sizes = [512, %c32],
      strides = [1, 1] : …<readonly:tensor<512x512xf16>> -> tensor<512x?xf16>
  %7 = tensor.empty() : tensor<32x32xf16>
  %8 = linalg.fill {lowering_config = #iree_codegen.lowering_config<tile_sizes = [[32, 32, 32]]>}
      ins(%cst : f16) outs(%7 : tensor<32x32xf16>) -> tensor<32x32xf16>
  %cast = tensor.cast %6 : tensor<512x?xf16> to tensor<512x32xf16>
  %cast_0 = tensor.cast %4 : tensor<?x512xf16> to tensor<32x512xf16>
  %9 = linalg.matmul {lowering_config = #iree_codegen.lowering_config<tile_sizes = [[32, 32, 32]]>}
      ins(%cast_0, %cast : tensor<32x512xf16>, tensor<512x32xf16>)
      outs(%8 : tensor<32x32xf16>) -> tensor<32x32xf16>
  %cast_1 = tensor.cast %9 : tensor<32x32xf16> to tensor<?x?xf16>
  %10 = affine.apply affine_map<()[s0] -> (s0 * 32)>()[%workgroup_id_y]
  %11 = affine.apply affine_map<()[s0] -> (s0 * 32)>()[%workgroup_id_x]
  flow.dispatch.tensor.store %cast_1, %2, offsets = [%10, %11],
      sizes = [%c32, %c32], strides = [1, 1]
      : tensor<?x?xf16> -> …<writeonly:tensor<512x512xf16>>
  return
}
```

<!-- 原书第 261 页；PDF 第 39 页。上述代码跨页。 -->

设备级分块将原始大矩阵操作数分解成多个小块，分块配置来自 `linalg.matmul` 的 `lowering_config` 属性中 `tile_sizes = [[32, 32, 32]]` 的相应层级。经过可切分循环维度过滤后的分块大小向量为 `[32, 32, 0]`，表示 M、N 并行维度上的大小为 32，K 维不分块。这意味着大小为 512×512 的 A、B 分别具有 16（= 512 / 32）条大小为 32×512 的行带或 512×32 的列带；每一对行带、列带确定一个输出块，由一个工作组计算。设备级分块在 A、B、C 上的分布如图 6-20 所示。

图 6-20　设备级分块的矩阵分布。原图左下是 A，右上是 B，右下是 C。A 的纵轴标 `M = 512`，按高度 32 画水平分界线，左侧红点表示各行带起点；B 的横轴标 `N = 512`、纵轴标 `K = 512`，按宽度 32 画垂直分界线，顶端红点表示各列带起点。C 同时沿两个方向划分成 32×32 网格，红点表示输出块起点。虚线和省略号表示其余重复分块，而不是只存在图中画出的几块。图中的两组索引标注为：

```mlir
%3 = affine.apply affine_map<()[s0] -> (s0 * 32)>()[%workgroup_id_y]
%5 = affine.apply affine_map<()[s0] -> (s0 * 32)>()[%workgroup_id_x]
```

其中 `%3` 决定 A 行带及 C 行块的起点，`%5` 决定 B 列带及 C 列块的起点。总共有 16×16 = 256 个输出块和对应工作组；同一条 A 行带供同一 y 下的 16 个工作组使用，同一条 B 列带供同一 x 下的 16 个工作组使用。不能将 A 或 B 各有 16 条带误读成总共只启动 16 个工作组。

<!-- 原书第 262 页；PDF 第 40 页。 -->

上述 IR 中没有显式 `scf.for` 循环。`TileAndDistributeToWorkgroups` pass 通过 `hal.interface.workgroup.id` 获取工作组在 x、y 维度上的 ID，并用 `affine.apply` 计算每个工作组需要加载、存储的块在全局张量中的偏移量，对应图 6-20 中标记的块起点。原图仅标出工作组 ID 与 A、B 分块偏移量 `%3`、`%5` 的关系，即 `%3 = %workgroup_id_y * 32`、`%5 = %workgroup_id_x * 32`，未另外标出 C 的偏移计算。但由上述 IR 可见，C 在 M、N 维上的偏移量 `(%10, %11)` 分别由 y、x 工作组 ID 计算。

这些分块偏移量用于后续 `flow.dispatch.tensor.load` 和 `flow.dispatch.tensor.store`，分别加载和存储每个工作组负责的数据范围。GPU 执行启动网格中的各工作组实例，各实例利用自己的 ID 执行相应数据范围内的矩阵乘计算；可并行调度不表示所有工作组必须同时驻留。

综上，该 pass 通过设备级并行维度分块、工作组分配、分块大小和偏移量计算、分块加载和存储等步骤，将原 512×512 矩阵乘分解成 256 个输出大小为 32×32 的分块矩阵乘任务，每个任务由一个工作组执行，从而实现并行计算。

> 校订注：原书称“256 个较小的 32×32 矩阵乘操作”，准确形状是 `(32×512) × (512×32) → (32×32)`，K 维仍为 512，不能误读成两个 32×32 矩阵相乘。

## 6.4 LLVMGPUTileAndDistribute pass 工作流程

前述 `addGPUMatmulTensorCoreMmaSyncPassPipeline()` 生成的 `LLVMGPUTileAndDistribute` pass，是针对 GPU 后端的工作组级和线程束级分块、分发 pass。该 pass 在设备级分块的基础上，继续将各工作组已经负责的计算分解成更小的块，以便在工作组内部沿归约维组织计算，并分发给不同线程束处理。在分块和分发过程中，还进行内存访问优化，如操作数提升等。

> 校订注：原书这里说进一步分发给“不同工作组或线程束”，本节分析的是设备级划分之后的工作组内部处理，不应理解为重新划分前一阶段的输出块所属工作组。

### 6.4.1 Linalg 方言的基本结构与变换机制

`LLVMGPUTileAndDistribute` pass 执行分块的对象主要是 Linalg 操作，因此了解 Linalg 方言是理解这些操作分块和向量化的基础。

高层计算图中的操作（如 TOSA 操作）通常可转换为更通用的 Linalg 操作，以此进入结构化代码生成流程。在本章的 IREE 编译路径中，Linalg 可视为连接神经网络图与后续 MLIR 代码生成的重要方言；原书称其为“核心前端方言”，这里指相对于低层代码生成的位置，并非用户模型只能经此唯一入口导入。

Linalg 通过高层次的算子表示和相关属性（如迭代器类型、索引映射）尽可能保留计算的高层结构。这些结构使编译器在后续优化和转换中能更好地理解操作数访问模式和计算语义，从而进行更有效的优化和代码生成。

<!-- 原书第 263 页；PDF 第 41 页。 -->

#### 1. Linalg 操作定义

根据 MLIR 文档，Linalg 定义了携带计算负载（payload carrying）的结构化操作，可在张量或缓冲区上实现 structured op 抽象。这里“结构化”指结构化数据（如 tensor 或 memref）与结构化迭代器的组合。结构化操作具有明确的计算模式和数据访问模式，`linalg.matmul`、`linalg.conv_1d`、`linalg.conv_2d`、`linalg.conv_3d`、`linalg.generic` 等均属于此类。

其中，`linalg.generic` 是 Linalg 的基本组成部件及通用结构化表示。matmul、conv 等具有明确名称的常用操作称为命名操作（named op），其名称体现相应语义。可泛化的命名结构化操作能转换为 `linalg.generic`，因此可以把 generic 看作这些操作的一种公共显式表示。

> 校订注：原书说“其他操作都只是语法糖”且“随后会被递降为 generic”，过于绝对。Linalg 还含非此类计算操作，命名操作也可保留名称接受专门优化，或直接通过公共接口分块、递降；转换为 generic 不是所有流水线的必经步骤。

结构化操作隐含一个完美嵌套循环（perfectly nested loop）的计算抽象。完美嵌套是多重循环结构，其中除最内层计算体外，各外层循环体只包围下一层循环，没有夹杂其他计算语句。这样的结构使循环展开（loop unrolling）、循环交换（loop interchange）等变换更容易组织，但具体变换仍须检查依赖及语义。以下代码是一个完美嵌套循环：

```cpp
for (int i = 0; i < N; i++)
  for (int j = 0; j < M; j++)
    for (int k = 0; k < L; k++) {
      // 最内层循环中的计算
    }
```

上述例子的各层边界与其他循环变量无关，迭代空间是一个矩形整数格点域，每层循环对应一个坐标轴，归纳变量的值确定相应轴上的坐标。空间中的每个格点代表一次最内层计算。原书称为“正交空间”；并非所有完美嵌套循环都具有矩形域，例如内层上界依赖外层索引时不一定如此。

结构化操作在更低层可进一步递降为循环及其循环体中的计算、索引表达式；也可经向量化等路径继续降低抽象。`linalg.generic` 的用法示例如下：

```mlir
%result = linalg.generic {
  indexing_maps = [affine_map<(d0, d1, d2, d3) -> (d0, d1, d2, d3)>,
                   affine_map<(d0, d1, d2, d3) -> (d3)>,
                   affine_map<(d0, d1, d2, d3) -> (d0, d1, d2, d3)>],
  iterator_types = ["parallel", "parallel", "parallel", "parallel"]
} ins(%conv, %bias : tensor<1x112x112x16xf32>, tensor<16xf32>)
  outs(%init : tensor<1x112x112x16xf32>) {
^bb0(%arg0: f32, %arg1: f32, %arg2: f32):
  %0 = arith.addf %arg0, %arg1 : f32
  linalg.yield %0 : f32
} -> tensor<1x112x112x16xf32>
```

<!-- 原书第 264 页；PDF 第 42 页。 -->

`linalg.generic` 主要由 5 个部分构成：索引映射（`indexing_maps`）、迭代器类型（`iterator_types`）、输入操作数（`ins`）、输出初始化操作数（`outs`）和计算负载。其中索引映射和迭代器类型在 4.3.4 节中已做详细解释。

上述示例定义了四维的隐式迭代空间。由操作数张量形状和索引映射可知，四个循环维度的范围依次为 1、112、112、16，索引从 0 开始。对这组恒等映射，`%conv` 和 `%init` 采用一致的 `1×112×112×16` 形状，`%bias` 的长度对应最后一维，以确保索引空间兼容。

原书将 `outs` 中张量与操作结果的关系按用途区分为仅提供形状的 shape-only 张量，以及参与迭代更新（destructive update）的初始张量。

在上述代码中，迭代器类型全为 parallel，输出初始化张量 `%init` 对应的元素 `%arg2` 不参与计算。因此计算不依赖该张量已有的元素值，也不对它执行依赖原值的读—改—写；其作用是提供结果形状和目标张量信息，元素是否已有初始数值不影响本例计算结果。这种用途称为 shape-only。计算负载不读取其元素，仅将形状信息传递到较低抽象级别，用于决定结果形状及迭代边界。操作通过自身操作数及映射具备所需形状信息，不需要另附一套独立的循环域描述；若形状动态，相关维度值仍需由运行时操作数提供。

当计算负载读取 `outs` 对应元素时，初始张量的数值就会参与计算。文档所说的“destructive update”描述结果由更新目标元素构建的模式；tensor SSA 语义仍产生新的结果值，不直接修改旧 SSA 张量。缓冲化在合法时可以将其实现为原地内存更新，而不是要求每次标量迭代都实际分配一个新张量。将上例计算负载中的 `%arg0` 改为 `%arg2`，原书给出的片段如下（其余映射和迭代器类型不变）：

```text
…
ins(%conv, %bias : tensor<1x112x112x16xf32>, tensor<16xf32>)
outs(%init : tensor<1x112x112x16xf32>) {
^bb0(%arg0: f32, %arg1: f32, %arg2: f32):
  %0 = arith.addf %arg2, %arg1 : f32
  linalg.yield %0 : f32
} -> tensor<1x112x112x16xf32>
…
```

在这个修改后的例子中，`%arg2` 是当前索引位置的 `%init` 元素，计算结果为 `result[d0,d1,d2,d3] = init[d0,d1,d2,d3] + bias[d3]`。各个迭代点仍写不同输出位置，迭代器仍全部为 parallel。`linalg.yield` 为当前位置提供计算结果，并不把该标量自动传给下一个不同索引的迭代点。因此，本例没有由这次改写引入跨迭代的归约依赖，不能据此判定分块间循环（inter-tile loop）的并行信息丢失。这里初始值确实影响结果，所以 `%init` 必须具有符合计算要求的初始数值。

> 校订注：原书把上例解释为“当前 `%arg2` 来自前次循环，yield 到下次迭代，直到最后一次”，并据此断言产生依赖、失去并行性。这与其恒等输出映射及全 parallel 迭代器不符。真正的归约中，多个迭代点映射到同一输出元素，才需累积前面的部分结果；例如 matmul 的 K 维。读取输出初值、SSA 张量更新、循环携带累加依赖是不同概念，不能画等号。原书“每次迭代生成新张量”的说法，也应区分抽象值语义与实际内存分配。

计算负载是 `linalg.generic` 核心功能的表示，描述隐含最内层计算体在每个迭代点执行的计算。`linalg.generic` 使用区域（region）表示通用计算负载，由花括号内的操作序列构成。

<!-- 原书第 265 页；PDF 第 43 页。上段跨页。 -->

本例结构化运算的区域含有一个基本块 `^bb0`，块参数对应输入、输出初始化张量或缓冲区按索引映射取到的元素。例如，`%arg0`、`%arg1`、`%arg2` 分别对应 `%conv[d0,d1,d2,d3]`、`%bias[d3]`、`%init[d0,d1,d2,d3]`，这些索引来自 `indexing_maps`。块参数数量必须与此类操作的输入、输出初始化操作数数量之和相符。计算负载在这些元素上计算，`linalg.yield` 的操作数（如 `%0`）对应当前迭代点产生的输出元素。本例元素类型为 f32；不要把“标量元素”泛化成所有 Linalg 操作都只能使用标量元素类型。

#### 2. Linalg 分块变换

Linalg 方言提供支持分块变换的接口。分块可从迭代空间分块和数据空间分块两个角度理解。迭代空间分块也称循环分块，是将计算迭代空间分解成较小迭代块，并通过重排合法的循环迭代缩短对邻近数据的访问时间间隔。例如，在矩阵乘中，可将循环分成较小迭代块，每个块执行部分计算。这样一方面有利于数据重用和局部性，另一方面可将块粒度与硬件并行处理特性匹配，提高硬件利用率。多面体方法（如 Affine 方言相关变换）主要采用迭代空间分块。计算循环嵌套及边界条件时可能引入额外控制流，计算各块起止位置时也可能产生复杂索引表达式。如果块大小在变换时未知，即参数化分块，某些表达式会超出普通仿射形式，使相应分析和变换更加困难。

> 校订注：原书补充说这种情况“需要指数复杂度的算法来处理”，但没有限定算法和问题规模，不能把它作为参数化分块本身必然具有的复杂度结论。这里保留其所强调的表达能力与分析难度限制。

数据空间分块是把数据空间（数组或缓冲区范围）分成较小的块。Linalg 常通过张量切片或数据视图表示这种分块；在缓冲区层面，可利用 MLIR 的带步长（strided）memref 抽象保留清晰的访问模式，服务于高效代码生成。例如，矩阵乘的数据空间分块会生成子矩阵视图，并在这些视图上执行计算。视图描述原存储的一部分，不必为每个子矩阵复制数据。数据空间与迭代空间分块并非互斥，本章就是先从迭代域计算块，再映射到各操作数切片。

MLIR 的 `TilingInterface` 定义了可由具体操作实现的分块方法，如 `getLoopIteratorTypes()`、`getIterationDomain()` 等。使用该接口的可分块操作通过接口模型提供迭代空间等信息，分块 pass（如 6.4.3 节将介绍的 pass）调用这些接口实施分块。例如，原书用以下简写表示一维逐元素操作：

```text
%0 = linalg.generic ins(%in) outs(%out)
    {indexing_maps = [affine_map<(d0) -> (d0)>], iterator_types = ["parallel"]}
    : tensor<?xf32> -> tensor<?xf32>
```

> 校订注：这是原书的示意简写，不是完整合法的 generic：一个输入、一个输出需要两个索引映射，并需提供各操作数类型及计算区域。为保留原例的未指定计算语义，下面用 `…原计算负载…` 标明，而不擅自发明计算操作。

分块后转换为以下操作组合。原书块长固定为 `%c4`，这里同时补明尾块处理，并补齐 insert_slice 参数和类型：

```text
%1 = scf.for %iv = %c0 to %dim_0 step %c4
    iter_args(%arg3 = %out) -> (tensor<?xf32>) {
  %tile_size = affine.min affine_map<(d0)[s0] -> (4, s0 - d0)>(%iv)[%dim_0]
  %2 = tensor.extract_slice %in[%iv] [%tile_size] [1]
      : tensor<?xf32> to tensor<?xf32>
  %3 = tensor.extract_slice %arg3[%iv] [%tile_size] [1]
      : tensor<?xf32> to tensor<?xf32>
  %4 = linalg.generic {
    indexing_maps = [affine_map<(d0) -> (d0)>, affine_map<(d0) -> (d0)>],
    iterator_types = ["parallel"]
  } ins(%2 : tensor<?xf32>) outs(%3 : tensor<?xf32>) {
    …原计算负载…
  } -> tensor<?xf32>
  %5 = tensor.insert_slice %4 into %arg3[%iv] [%tile_size] [1]
      : tensor<?xf32> into tensor<?xf32>
  scf.yield %5 : tensor<?xf32>
}
```

<!-- 原书第 266 页；PDF 第 44 页。上述代码跨页。 -->

> 校订注：假设 `%c0 = 0`、`%c4 = 4`，输入输出长度均为 `%dim_0`。原书固定使用长度 4 的切片，只有总长度为 4 的倍数时才覆盖尾块而不越界；修正版用 `min(4, dim - iv)`。原书输出切片取自 `%out`，这里取循环携带的 `%arg3` 以明确当前目标状态；对独立、不重叠的一维块，两者当前块的旧值一致。`tensor.insert_slice` 原文遗漏 `into`、偏移、大小、步长等，已补齐，未删去任何原有步骤。

上述 `scf.for` 循环体先从输入张量和当前输出张量提取切片，偏移为 `%iv`，通常长度为 4，尾块长度按剩余范围裁剪；然后在切片上调用 `linalg.generic` 做局部处理；最后用 `tensor.insert_slice` 将结果插入循环携带的输出张量，并由 `scf.yield` 返回更新后的整体张量。这种“提取切片—执行已分块计算—插入切片”的组合，是识别张量分块的一种常见结构，但不是所有分块实现唯一的匹配形式。

### 6.4.2 工作组级分块过程输入 IR 分析

`LLVMGPUTileAndDistribute` pass 输入 IR（见 `512_after_all_cuda.log` 日志文件）如下。保留原书对绑定参数、布局和存储空间属性前缀的省略：

```text
func.func @matmul_dispatch_0_matmul_512x512x512_f16()
    attributes {translation_info = …} {
  …
  %0 = hal.interface.binding.subspan … : memref<512x512xf16, …<storage_buffer>>
  memref.assume_alignment %0, 64 : memref<512x512xf16, …<storage_buffer>>
  %1 = hal.interface.binding.subspan … : memref<512x512xf16, …<storage_buffer>>
  memref.assume_alignment %1, 64 : memref<512x512xf16, …<storage_buffer>>
  %2 = hal.interface.binding.subspan … : memref<512x512xf16, …<storage_buffer>>
  memref.assume_alignment %2, 64 : memref<512x512xf16, …<storage_buffer>>
  %workgroup_id_y = hal.interface.workgroup.id[1] : index
  %3 = affine.apply affine_map<()[s0] -> (s0 * 32)>()[%workgroup_id_y]
  %workgroup_id_x = hal.interface.workgroup.id[0] : index
  %4 = affine.apply affine_map<()[s0] -> (s0 * 32)>()[%workgroup_id_x]
  %subview = memref.subview %2[%3, %4] [32, 32] [1, 1]
      : memref<512x512xf16, …<storage_buffer>>
        to memref<32x32xf16, …, …<storage_buffer>>
  %subview_0 = memref.subview %0[%3, 0] [32, 512] [1, 1]
      : memref<512x512xf16, …<storage_buffer>>
        to memref<32x512xf16, …, …<storage_buffer>>
  %subview_1 = memref.subview %1[0, %4] [512, 32] [1, 1]
      : memref<512x512xf16, …<storage_buffer>>
        to memref<512x32xf16, …, …<storage_buffer>>
  linalg.fill {lowering_config = #iree_codegen.lowering_config<tile_sizes = [[32, 32, 32]]>}
      ins(%cst : f16) outs(%subview : memref<32x32xf16, …, …<storage_buffer>>)
  linalg.matmul {lowering_config = #iree_codegen.lowering_config<tile_sizes = [[32, 32, 32]]>}
      ins(%subview_0, %subview_1 : memref<32x512xf16, …, …<storage_buffer>>,
                                 memref<512x32xf16, …, …<storage_buffer>>)
      outs(%subview : memref<32x32xf16, …, …<storage_buffer>>)
  return
}
```

<!-- 原书第 267 页；PDF 第 45 页。上述代码跨页。 -->

将上述 IR 与 6.3.2 节最后展示的输出对比，可以发现设备级 `TileAndDistributeToWorkgroups` pass 处于较高抽象层次，可以用张量操作管理数据分块和计算分发。该 pass 通过高层张量操作引入分块策略，把较大规模计算分成较小计算，由各工作组并行处理。这一阶段主要关注任务如何分配给不同工作组，并通过仿射映射计算各块的位置。

经过后续 pass（书中主要为 `IREEComprehensiveBufferize`）处理，在保持分块策略、大小及相关索引映射的基础上，示例中的张量表示被转换为较低层的 memref，用子视图表达分块，供后续优化和后端转换使用。例如，`LLVMGPUTileAndDistribute` 的输入使用 `memref.subview` 表达原始矩阵的分块，而不再使用 `flow.dispatch.tensor.load`。因此本节该 pass 在基于 memref 的 IR 上针对 GPU 执行模式进行优化，使其适合 LLVM GPU 后端的并行执行。

### 6.4.3 LLVMGPUTileAndDistribute pass 分块过程

经过设备级分块后，计算任务规模仍然较大。`LLVMGPUTileAndDistribute` 通过多层次分块操作和一系列优化处理 Linalg 操作，进一步将任务分解为适合 GPU 并行执行的更小计算。

概言之，该 pass 的功能分为三个部分：操作数内存提升、工作组级分块、线程束级分块。`runOnOperation()` 代码实现摘录如下：

```cpp
void runOnOperation() override {
  // …
  {
    RewritePatternSet promotionPatterns(&getContext());
    populateContractPromotionPatterns(promotionPatterns, {2});
    if (failed(applyPatternsAndFoldGreedily(funcOp, std::move(promotionPatterns))))
      return signalPassFailure();
    propagateSharedMemoryCopy(funcOp);
  }
  if (failed(tileToSerialLoops(funcOp))) {
    return signalPassFailure();
  }
  std::optional<SmallVector<int64_t>> maybeWorkgroupSize = getWorkgroupSize(funcOp);
  SmallVector<int64_t> workgroupSize = maybeWorkgroupSize.value();
  int64_t flatWorkgroupSize =
      workgroupSize[0] * workgroupSize[1] * workgroupSize[2];
  if (flatWorkgroupSize > kWarpSize) {
    RewritePatternSet promotionPatterns(&getContext());
    populateContractPromotionPatterns(promotionPatterns, {0, 1});
    if (failed(applyPatternsAndFoldGreedily(funcOp, std::move(promotionPatterns))))
      return signalPassFailure();
    insertBarriersAroundSharedMemoryCopy(funcOp);
  }
  // …
  if (distributeToWarp) {
    if (failed(tileToWarp(funcOp, workgroupSize))) {
      return signalPassFailure();
    }
  } else {
    if (failed(tileToInvocation(funcOp, workgroupSize))) {
      return signalPassFailure();
    }
  }
  // …
}
```

<!-- 原书第 268 页；PDF 第 46 页。上述代码跨页。 -->

> 转写说明：省略号是原书已有的省略。该摘录直接对 optional 调用 `.value()` 并读取工作组大小的三个元素，依赖前置配置有效且向量至少三项的保证；不能把它复制到任意输入路径而不检查。未取得匹配 IREE 版本，暂不推断其省略部分是否已有完整验证。

为优化 GPU 内存访问效率和计算性能，上述代码两次调用 `populateContractPromotionPatterns()`，分别向 `promotionPatterns` 添加模式，并应用这些模式。两次调用指定的 `operandsToPromote` 分别为 `{2}` 和 `{0, 1}`，可将相应的 C 及 A、B 矩阵块从全局内存提升到共享内存中。第二次调用的条件是工作组的总线程数 `flatWorkgroupSize` 超过线程束大小常量 `kWarpSize`。书中由 `getTensorCoreConfig()` 设置的工作组大小为 `{64, 2, 1}`（见 6.2.1 节），总线程数为 128，超过 32，因此进入该分支。

> 校订注：比较的是三个维度的乘积，不是向量与标量直接比较。原书说单线程束时共享内存“得不偿失、无须提升”，这里应理解为这段实现对 A、B 提升的策略，不是所有单线程束算法的普遍性能结论；前面的 C 提升也不在这个条件分支内。

另外两个重要功能是先调用 `tileToSerialLoops()` 进行工作组级分块，再调用 `tileToWarp()` 进行线程束级分块，或调用 `tileToInvocation()` 在线程级别分块。由于后两者的主要程序结构高度相似，本节仅分析 `tileToSerialLoops()` 和 `tileToWarp()`。

图 6-21 总结了该 pass 的主要函数调用流程。

```text
LLVMGPUTileAndDistribute::runOnOperation()
├── populateContractPromotionPatterns(..., {2})    将 C 矩阵块提升到共享内存
├── tileToSerialLoops()                           工作组级分块
├── populateContractPromotionPatterns(..., {0,1})  将 A、B 矩阵块提升到共享内存
│                                                （总线程数 > kWarpSize 时）
└── tileToWarp()                                  线程束级分块
```

图 6-21　`LLVMGPUTileAndDistribute` pass 主要函数调用流程。原图展示 `distributeToWarp` 路径，未画替代的 `tileToInvocation` 分支；模式的实际应用和同步步骤见上方完整摘录。

<!-- 原书第 269 页；PDF 第 47 页。 -->

以下各小节将按照上述执行流程分析各函数功能。

#### 1. 操作数的内存提升

在此前 pass（如 `IREEComprehensiveBufferize`）输出的 IR 中，Linalg 矩阵乘的输入操作数以 memref 子视图形式引用全局内存。为优化访存模式、减少全局内存访问延迟、提高数据复用率，`LLVMGPUTileAndDistribute` 调用 `populateContractPromotionPatterns()`，为满足条件的 Linalg 操作（主要是矩阵乘相关操作）添加模式。应用模式时，根据操作数的 `memref.subview` 生成对应复制操作及共享内存分配，结合后续同步处理，将操作数提升到共享内存。

`populateContractPromotionPatterns()` 为 `linalg.matmul`、`linalg.batch_matmul`、`linalg.generic` 三类操作生成和添加模式，同时构造 `LinalgPromotionOptions` 提升选项对象及 Linalg 转换过滤器，应用特定转换策略。这种选项与过滤器组合在书中 IREE pass 中较为常见，稍后的工作组级、线程束级分块也采用类似方式。其目的是增加对转换过程的控制和灵活性，便于针对特定场景定制处理，并只对符合条件的操作应用变换。

`LinalgPromotionOptions` 控制提升的具体行为。例如，通过分配、释放函数选项，可以指定管理共享内存的回调；通过复制函数选项，可以指定生成复制操作的函数；通过操作数提升选项，可以选择哪些操作数需要提升。这些配置使内存管理和优化更灵活，可以适应不同硬件架构及应用场景。

Linalg 转换过滤器用于限定某些变换只应用于特定操作。该机制使用 `LinalgTransformationFilter` 中的 `matchDisjunction`、`replacement` 标记（marker）及过滤函数，筛选需要优化的操作，并安排其后续状态。过滤器通过标记属性和过滤函数两种方式控制模式应用。

##### （1）kLinalgTransformMarker 属性

操作上的转换标记可以用于决定是否应用某种变换或优化。书中以 C++ 常量名 `kLinalgTransformMarker` 指代相应属性名；IR 中其属性键写作 `__internal_linalg_transform__`，值是字符串。示例状态包括 `"copy_to_workgroup_memory"`、`"workgroup_k_tiled"`、`"workgroup_memory"`、`"vectorize"`。不同操作可具有不同标记，例如复制操作或其后生成的 `linalg.generic` 可标为 `"copy_to_workgroup_memory"`，matmul 可标为 `"workgroup_k_tiled"`，以区分各自处理阶段。

在执行变换时，可以匹配这些标记值、有条件地选择下一种变换，并在成功后更新标记，形成一套状态推进机制。标记匹配项和更新值通常分别来自过滤器的 `matchDisjunction` 和 `replacement`。

<!-- 原书第 270 页；PDF 第 48 页。上段跨页。 -->

操作数内存提升阶段构造过滤器时，将匹配项设置为 `"workgroup_k_tiled"`，将替换标记设置为 `"workgroup_memory"`。原书所示路径还允许初始未标记操作参与第一次提升，因此可处理已经 K 分块的操作，也可处理最初尚无标记的 C 提升候选。

> 校订注：原书将“标记为空”直接视为匹配成功。缺失标记、空字符串标记并不天然等价，带非空匹配列表的过滤器也不必然接受未标记操作；还要看默认匹配配置。此处按原书流程保留“第一次允许未标记操作”的行为，不将其推广为 `checkAndNotify()` 的通用规则。本地版本已无这组历史过滤器实现，不能把该行为标为本地逐行验证通过。

实施提升的 `LinalgPromotionPattern` 继承 `LinalgBasePromotionPattern`，相关操作数的内存提升由后者模式中的 `matchAndRewrite()` 完成。

`LinalgBasePromotionPattern::matchAndRewrite()` 调用过滤器的 `checkAndNotify()`，检查操作标记是否满足 `matchDisjunction` 及其他过滤条件。如果满足该阶段配置，则根据这次调用指定的操作数集合提升 C 或 A、B：分配共享存储、从原子视图复制相应数据，并改写计算操作的使用。生成的复制操作可以带 `"copy_to_workgroup_memory"` 标记，如下：

```text
memref.copy %subview_4, %alloc_0
    {__internal_linalg_transform__ = "copy_to_workgroup_memory"}
    : memref<…, …<storage_buffer>> to memref<…, …<workgroup>>
```

该操作将全局内存中 `%subview_4` 所引用的数据复制到共享内存 `%alloc_0` 中。完成提升后，相关 Linalg 计算操作的标记更新为 `replacement` 值 `"workgroup_memory"`，表示它已完成本次提升阶段。

> 校订注：原书说“memref.subview 转换为 memref.copy”，二者语义不同：subview 描述视图，copy 复制数据。提升通常需要两者配合，而非单纯将同一个操作换个名称。注册模式也不等于已经执行提升，实际变换发生在重写驱动应用模式时。

图 6-22 以 matmul 为例，展示在过滤器协助下，调用 `checkAndNotify()` 检查状态、调用 `replaceLinalgTransformationFilter()` 更新状态，经过两次内存提升及两次分块的过程。

<!-- 原书第 271 页；PDF 第 49 页。 -->

| 阶段 | 变换前操作标记 | `matchDisjunction` | `replacement`／成功后标记 |
| --- | --- | --- | --- |
| 1. C 操作数内存提升 | 未标记 | `workgroup_k_tiled`，并按初始匹配配置接受未标记操作 | `workgroup_memory` |
| 2. 工作组级分块 | `workgroup_memory` | `workgroup_memory` | `workgroup_k_tiled` |
| 3. A、B 操作数内存提升 | `workgroup_k_tiled` | `workgroup_k_tiled` | `workgroup_memory` |
| 4. 线程束级分块 | `workgroup_memory`；未提升 A、B 的路径可为 `workgroup_k_tiled` | `workgroup_memory` 或 `workgroup_k_tiled` | `vectorize` |

图 6-22　Linalg 转换过滤器参与内存提升及分块的处理过程。原图分四格，每格上方为变换前后操作及箭头，下方虚框为 `LinalgTransformationFilter`；变换前通过 `checkAndNotify()` 连接匹配项，变换后通过 `replaceLinalgTransformationFilter()` 连接替换项。原图第 2 格左侧写成 `linalg.batch_matmul`、右侧却是 `linalg.matmul`，本例应始终追踪同一 matmul，分块不应据此被理解为把 batch_matmul 无条件变成 matmul。

由图可知，变换前标记应通过配置的匹配规则，变换成功后更新成替换标记。第一次 C 提升时，操作尚未标记，虽不等于字面值 `"workgroup_k_tiled"`，仍需由专门的初始匹配配置使其进入流程。并非每一次成功都意味着此前标记与匹配字符串字面相等。

图 6-23 汇总了本例两次提升、两次分块中标记从初始未设置到 `"vectorize"` 的完整状态变化，以及各阶段调用的函数。

```text
LLVMGPUTileAndDistribute::runOnOperation()
├── populateContractPromotionPatterns()          配置 C 提升过滤器
│   └── LinalgBasePromotionPattern::matchAndRewrite()
│       ├── checkAndNotify()                    检查初始候选
│       └── replaceLinalgTransformationFilter()  未标记 → workgroup_memory
├── tileToSerialLoops()
│   └── tileReductionLoops()                    配置工作组分块过滤器
│       └── tileLinalgOpsWithFilter()
│           ├── checkAndNotify()
│           └── replaceLinalgTransformationFilter()
│                                               workgroup_memory → workgroup_k_tiled
├── populateContractPromotionPatterns()          配置 A、B 提升过滤器
│   └── LinalgBasePromotionPattern::matchAndRewrite()
│       ├── checkAndNotify()
│       └── replaceLinalgTransformationFilter()  workgroup_k_tiled → workgroup_memory
└── tileToWarp()                                 配置线程束分块过滤器
    └── distributeLinalgOpsWithFilter()
        ├── checkAndNotify()                    接受 workgroup_memory 或 workgroup_k_tiled
        └── replaceLinalgTransformationFilter()  → vectorize
```

图 6-23　驱动操作 `kLinalgTransformMarker` 属性值更新的函数。四个过滤器的匹配项、替换项与图 6-22 表格一致；图中右侧状态箭头依次连接 `linalg.matmul{}`、`linalg.matmul{workgroup_memory}`、`linalg.matmul{workgroup_k_tiled}`、`linalg.matmul{workgroup_memory}`、`linalg.matmul{vectorize}`，花括号内为标记示意，不是完整 IR 属性语法。

<!-- 原书第 272 页；PDF 第 50 页。 -->

由图 6-23 可知，在内存提升阶段，驱动标记更新的是 `LinalgBasePromotionPattern::matchAndRewrite()`；在分块阶段，驱动标记更新的是各分块过程的实现函数。因此，原图 6-22 标题将四步全部归入 `LinalgPromotionPattern` 并不准确。

##### （2）过滤函数

在标记属性的基础上，过滤函数还可检查 Linalg 操作的属性、类型或其他条件是否满足变换要求，为模式应用提供更细粒度的控制。例如，书中的 `contractOpFilter()` 只允许并行循环数量为 2 或 3 的缩并操作（contract op）进入相应内存提升模式。

后续工作组级、线程束级分块都使用 Linalg 转换过滤器，但配合的选项不同：工作组级使用 `SCFTilingOptions`，线程束级使用 `LinalgTilingOptions`；后者与设备级分块使用的选项类型相同。

#### 2. 工作组级分块过程实现

`LLVMGPUTileAndDistribute` 完成第一轮相关操作数提升后，调用 `tileToSerialLoops()` 执行工作组级分块。如前所述，设备级已经切分并行维度；`tileToSerialLoops()` 主要通过调用 `tileReductionLoops()`，实现操作归约维度的分块。

`tileReductionLoops()` 的主要逻辑是定义工作组级分块大小计算函数，配置 SCF 分块选项对象和 Linalg 转换过滤器，最后调用 `tileLinalgOpsWithFilter()`，应用这些配置执行分块。图 6-24 根据代码总结函数调用流程。

```text
tileReductionLoops()
├── tileSizesFn                           定义工作组级分块大小计算函数
├── scf::SCFTilingOptions()                生成并配置 SCF 分块选项对象
├── LinalgTransformationFilter filter      生成并配置 Linalg 转换过滤器对象
└── tileLinalgOpsWithFilter()              实现工作组级分块过程
    ├── scf::tileUsingSCF()
    └── replaceLinalgTransformationFilter()
```

图 6-24　`tileReductionLoops()` 函数调用流程图。

图中的 lambda `tileSizesFn` 是工作组级分块大小计算函数，其功能将在下文分析 `scf::tileUsingSCF()` 时详述。

`tileReductionLoops()` 生成 SCF 分块选项对象时，将 `scf::SCFTilingOptions` 的分块大小计算回调设置为 `tileSizesFn`；随后 `scf::tileUsingSCF()` 调用该回调，为 Linalg 操作计算各维分块大小。

<!-- 原书第 273 页；PDF 第 51 页。上段跨页。 -->

由于工作组级分块在第一轮内存提升之后执行，成功提升的相关操作（matmul、batch_matmul 或符合条件的 generic）已经被标为 `"workgroup_memory"`。

如图 6-22 所示，`tileReductionLoops()` 定义过滤器时，将匹配项设置为 `"workgroup_memory"`，替换标记设置为 `"workgroup_k_tiled"`。因此接下来通过检查标记和其他过滤条件，选择要在 K 维进行工作组级分块的操作。原书还提到未标记操作可被接受，这取决于该过滤器的默认匹配设置，不能从替换标记本身推出。

定义回调及配置选项后，函数调用 `tileLinalgOpsWithFilter()` 执行分块，并在成功后调用 `replaceLinalgTransformationFilter()`，将分块后操作标记从 `"workgroup_memory"` 更新为 `"workgroup_k_tiled"`。

`tileLinalgOpsWithFilter()` 首先遍历输入 IR 中的 Linalg 操作，通过过滤器的 `checkAndNotify()` 检查标记与条件，将满足工作组级分块筛选要求的操作保存到候选集合 `candidates`。

然后遍历候选集合，对实现 `TilingInterface` 的操作调用 `scf::tileUsingSCF()`，使用显式 `scf.for` 作为分块循环结构。原 IR 中有 fill、matmul 等操作，但并非仅因属于 Linalg 就都进入候选；fill 没有 K 归约维，也不能据此断言它会产生 K 分块循环。

`scf::tileUsingSCF()` 的功能在书中分为七部分，本节仅分析与工作组级分块有关的五部分。

> 版本说明：本地 MLIR 已有 `tileUsingSCFForOp` 等接口形式，与书中 IREE 使用的 `tileUsingSCF` 命名及配置字段可能不同；这里保留原书调用关系，不将历史名称直接替换成未经验证的当前 API。

##### （1）获取 Linalg 操作迭代域

与设备级分块类似，为便于计算工作组级分块大小，首先通过 `getIterationDomain()` 获得 Linalg 操作的迭代域，即操作表示的循环范围。向量 `iterationDomain` 中的每个循环范围用 `Range` 对象表示，含 `offset`、`size`、`stride` 三个字段。

操作迭代域与其在张量或缓冲区上执行的计算、访问模式有关。不同操作有不同迭代域。本例设备级分块后，`linalg.matmul` 的 `iterationDomain = [[0, 32, 1], [0, 32, 1], [0, 512, 1]]`，三个元素依次对应 M、N、K，因此向量长度为 3。

<!-- 原书第 274 页；PDF 第 52 页。 -->

##### （2）计算工作组级分块大小

如图 6-24 所述，`tileReductionLoops()` 将 SCF 分块选项对象 `tilingOptions` 的大小计算回调设置为 lambda `tileSizesFn`。`scf::tileUsingSCF()` 调用它，为每个目标 Linalg 操作计算工作组级分块大小，并将结果保存在向量 `tileSizes` 中。

在 IREE 多级分块策略中，设备级已经对计算操作的并行维度分块；工作组级通过将对应并行维度的分块大小置为 0，跳过这些维度，仅对归约维度分块。

为了获得相关并行维度信息，`tileSizesFn` 取得目标操作的 `PartitionableLoopsInterface`，调用 `getPartitionableLoops()`，将结果保存在此处名为 `partitionedLoops` 的局部向量中。本例结果为 `[0, 1]`，对应 M、N 维；在这条流水线上，它们恰好也是设备级已处理的维度，因此工作组级仅需处理 K。

> 校订注：原书说同一 `getPartitionableLoops()` 接口在这里“变成返回已分块历史”。变量名 `partitionedLoops` 不能改变接口含义；它仍查询可分布维度，本例结合流水线先后顺序才把这些维度当作之前已处理的并行维度，不是在接口中记录了变换历史。

设备级分块后，`linalg.matmul` 的配置层级仍给出 `[32, 32, 32]`，因此由 `getTileSizes()` 获得的初始 `tileSizes` 为 `[32, 32, 32]`。`partitionedLoops` 对应的并行维度不需要在本阶段再次分块，将索引 `[0, 1]` 对应项置 0 后，向量变为 `[0, 0, 32]`。

Linalg 操作隐含的各循环维都有相应并行或归约迭代器类型。其外部模型 `LinalgOpTilingInterface` 提供 `getLoopIteratorTypes()`；调用后得到 matmul 的类型向量 `["parallel", "parallel", "reduction"]`，长度为 3。分块向量长度与之相同，因此不需调整，最终值仍为 `[0, 0, 32]`。

图 6-25 总结了从配置初始值，经并行维度排除及迭代器长度校准，得到工作组级分块大小的过程。

```text
getTileSizes(lowering_config)       getPartitionableLoops()       getLoopIteratorTypes()
            │                              │                    [parallel, parallel, reduction]
            ▼                              ▼                              │
tileSizes [32, 32, 32] ── 将索引 [0, 1] 置零 ──► [0, 0, 32] ── 长度为 3 ──► [0, 0, 32]
```

图 6-25　工作组级分块大小向量计算过程。

<!-- 原书第 275 页；PDF 第 53 页。 -->

##### （3）定义工作组级分块参数计算函数

`scf::tileUsingSCF()` 中定义的回调 `innerYieldTiledValuesFn` 主要负责计算分块偏移量向量 `offsets`、分块大小向量 `sizes`，并生成分块循环的循环体计算。

后续调用的循环嵌套生成函数 `generateLoopNest()` 根据选项中的循环类型，调用不同生成函数，如 `generateLoopNestUsingForallOp()` 或 `generateLoopNestUsingForOp()`。如果 `tileSizes` 全为 0，意味着不需要分块循环，可直接调用 `innerYieldTiledValuesFn` 处理无循环情况。调用关系如图 6-26 所示。

```text
scf::tileUsingSCF()
└── generateLoopNest()
    ├── ForallOp → generateLoopNestUsingForallOp() ─┐
    ├── no loop ───────────────────────────────────┼→ innerYieldTiledValuesFn()
    └── ForOp → generateLoopNestUsingForOp() ──────┘
```

图 6-26　分块参数计算函数与分块循环嵌套生成函数调用关系。

本例 matmul 的分块向量只有 K 对应项非零，因此只在 K 维分块。K 维偏移由所生成 `scf.for` 的归纳变量获得，大小由 `getBoundedTileSize()` 根据迭代域计算；该函数与设备级使用的 `createBoundedTileSize` 类似，处理尾块边界。将各维偏移与大小加入向量后，本例得到 `offsets = [0, 0, %arg]`、`sizes = [32, 32, 32]`，其中 `%arg` 是 K 分块循环的归纳变量。这里 M、N 的 `sizes` 为完整保留的 32，不与“不再分块”的 `tileSizes` 中两个 0 矛盾。

##### （4）生成工作组级分块循环体逻辑

根据上面计算的 `offsets`、`sizes`，回调 `innerYieldTiledValuesFn` 为符合条件的操作生成循环体计算。如果 `tileSizes` 全为 0（如在这套配置下的 fill），则按不分块路径处理，不为它产生分块循环；如果不全为 0（如 matmul），则调用 `getTiledImplementation()` 对操作数和计算进行分块。

`getTiledImplementation()` 针对设备级分块后的操作，调用 `makeTiledShapes()` 取得各操作数切片，再用 `getTensorOutputTypes()` 等工具取得需要的结果类型，以新的操作数构造分块操作。对本例的纯 memref 形式，操作没有张量 SSA 结果，结果类型列表为空，不是凭该工具调用就生成张量结果。

<!-- 原书第 276 页；PDF 第 54 页。上段跨页。 -->

以 matmul 为例，工作组级分块前 `valuesToTile` 中的操作数定义为（保留原书 generic 打印形式及其省略）：

```text
%12 = "memref.subview"(…) <{…}>
    : (memref<512x512xf16, …<storage_buffer>>, index)
      -> memref<32x512xf16, …, …<storage_buffer>>
%13 = "memref.subview"(…) <{…}>
    : (memref<512x512xf16, …<storage_buffer>>, index)
      -> memref<512x32xf16, …, …<storage_buffer>>
%14 = "memref.subview"(…) <{…}>
    : (memref<32x32xf16, …<workgroup>>, index, index)
      -> memref<?x?xf16, strided<[32, 1]>, …<workgroup>>
```

上述 `%12`、`%13` 来自已缓冲化的设备级分块视图，`%14` 引用 C 提升后的共享存储。原书将三者都称为 `IREEComprehensiveBufferize` 的结果，但共享内存 C 还涉及当前 pass 先执行的内存提升，不能忽略这一阶段。工作组级分块前的 matmul 为：

```text
"linalg.matmul"(%12, %13, %14) <{
  indexing_maps = [affine_map<(d0, d1, d2) -> (d0, d2)>,
                   affine_map<(d0, d1, d2) -> (d2, d1)>,
                   affine_map<(d0, d1, d2) -> (d0, d1)>], …
}> ({
^bb0(%arg1: f16, %arg2: f16, %arg3: f16):
  %22 = "arith.mulf"(%arg1, %arg2) <{…}> : (f16, f16) -> f16
  %23 = "arith.addf"(%arg3, %22) <{…}> : (f16, f16) -> f16
  "linalg.yield"(%23) : (f16) -> ()
}) {…} : (memref<32x512xf16, …, …<storage_buffer>>,
          memref<512x32xf16, …, …<storage_buffer>>,
          memref<?x?xf16, strided<[32, 1]>, …<workgroup>>) -> ()
```

与设备级分块实现类似，`getTiledImplementation()` 调用 `makeTiledShapes()` 对 `%12`、`%13`、`%14` 分块，并按操作数类型选择切片操作。本例操作数为 memref，所以使用 `memref.subview`。分块后的操作数为：

```text
%22 = "memref.subview"(%12, %arg5) <{…}>
    : (memref<32x512xf16, …, …<storage_buffer>>, index)
      -> memref<32x32xf16, …, …<storage_buffer>>
%23 = "memref.subview"(%13, %arg5) <{…}>
    : (memref<512x32xf16, …, …<storage_buffer>>, index)
      -> memref<32x32xf16, …, …<storage_buffer>>
%24 = "memref.subview"(%14) <{…}>
    : (memref<?x?xf16, …, …<workgroup>>)
      -> memref<32x32xf16, …, …<workgroup>>
```

生成的 `%22`、`%23`、`%24` 分别是原操作数的子视图，裁剪范围由偏移、大小和步长决定。这里 `%arg5` 表示 K 分块循环索引；不同日志摘录的 SSA 编号不要求全篇相同。A 沿第二维 K 切片，B 沿第一维 K 切片，C 仍覆盖本工作组的整个 32×32 输出块。分块后的 matmul 如下：

```text
"linalg.matmul"(%22, %23, %24) <{…}> ({
^bb0(%arg1: f16, %arg2: f16, %arg3: f16):
  %25 = "arith.mulf"(%arg1, %arg2) <{…}> : (f16, f16) -> f16
  %26 = "arith.addf"(%arg3, %25) <{…}> : (f16, f16) -> f16
  "linalg.yield"(%26) : (f16) -> ()
}) {__internal_linalg_transform__ = "workgroup_memory", …}
    : (memref<32x32xf16, …, …<storage_buffer>>,
       memref<32x32xf16, …, …<storage_buffer>>,
       memref<32x32xf16, strided<[32, 1]>, …<workgroup>>) -> ()
```

<!-- 原书第 277 页；PDF 第 55 页。上述代码跨页。 -->

上述 matmul 使用子视图 `%22`、`%23`、`%24`，A、B 大小由 32×512 或 512×32 变为 32×32，C 大小保持 32×32。此处摘录还处于更新转换标记之前，故仍显示 `"workgroup_memory"`。

到这里，原书已经介绍了循环体中分块操作及其操作数的构造，下一部分解释包围它们的 `scf.for` 如何生成。实际调用次序是先建立循环及归纳变量，再调用回调构造其中的计算，不能将讲解先后误读为先构造使用尚未存在变量的 IR。

##### （5）生成工作组级分块循环嵌套

工作组级分块的重要步骤是调用 `generateLoopNest()`，根据分块大小、迭代域等生成循环结构。对于 `tileSizes` 全为 0 的操作，直接调用 `innerYieldTiledValuesFn` 处理无分块循环的情况；否则，根据 `tileReductionLoops()` 创建的选项 `options.loopType`，选择循环生成函数。

书中的 `SCFTilingOptions` 将 `loopType` 默认初始化为 `LoopType::ForOp`，因此这里调用 `generateLoopNestUsingForOp()`。

本例 matmul 的 `loopRanges = [[0, 32, 1], [0, 32, 1], [0, 512, 1]]`，`tileSizes = [0, 0, 32]`。对于非零项所对应的 K 维，以 `loopRange.offset` 为下界、`loopRange.size` 为这里的上界、分块大小为步长，调用 `builder.create<scf::ForOp>()` 创建循环。生成的 K 分块循环框架为：

```mlir
scf.for %arg0 = %c0_6 to %c512 step %c32_7 {
  // 分块计算稍后由回调插入；无结果 scf.for 的 scf.yield 可隐式省略。
}
```

> 校订注：原书混用了 `scf.for %arg0 = …` 自定义打印语法和 `^bb0(%arg0: index)`、函数类型等 generic 打印语法，已统一为合法的自定义形式，保留全部边界和变量。归纳变量本质上就是循环体块参数，不需要在自定义语法里重复声明。

下界、上界和步长常量 `%c0_6`、`%c512`、`%c32_7` 分别根据循环范围及 tileSize 生成，值为 0、512、32。

`builder.create<scf::ForOp>()` 创建循环时，也创建代表循环体的区域及块参数；归纳变量 `%arg0` 即其中的块参数。初始没有计算操作，循环体逻辑由 `generateLoopNestUsingForOp()` 的回调参数 `yieldTiledValuesFn` 所指向的 `innerYieldTiledValuesFn` 填入，相关分析见前述第（3）、（4）部分。

归纳变量可通过 `loop.getInductionVar()` 获得，并在回调中作为 K 维分块偏移量。

由 `generateLoopNestUsingForOp()` 调用 `innerYieldTiledValuesFn`，最终生成的工作组级分块循环如下：

```text
scf.for %arg0 = %c0_6 to %c512 step %c32_7 {
  %subview_8 = memref.subview %subview_0[0, %arg0] [32, 32] [1, 1]
      : memref<32x512xf16, …, …<storage_buffer>>
        to memref<32x32xf16, …, …<storage_buffer>>
  %subview_9 = memref.subview %subview_1[%arg0, 0] [32, 32] [1, 1]
      : memref<512x32xf16, …, …<storage_buffer>>
        to memref<32x32xf16, …, …<storage_buffer>>
  %subview_10 = memref.subview %subview_2[0, 0] [32, 32] [1, 1]
      : memref<?x?xf16, strided<[32, 1]>, …<workgroup>>
        to memref<32x32xf16, strided<[32, 1]>, …<workgroup>>
  linalg.matmul {…}
      ins(%subview_8, %subview_9 : memref<32x32xf16, …, …<storage_buffer>>,
                                 memref<32x32xf16, …, …<storage_buffer>>)
      outs(%subview_10 : memref<32x32xf16, strided<[32, 1]>, …<workgroup>>)
}
```

<!-- 原书第 278 页；PDF 第 56 页。上述代码跨页。 -->

经过设备级分块后，A、B、C 的大小分别为 32×512、512×32、32×32。工作组级在此基础上继续切分 K。A、B 的 K 维偏移由上述 `scf.for` 归纳变量 `%arg0` 决定；循环下界 0、上界 512、步长 32，故有 16 次迭代。每次迭代用 `%arg0` 作为子视图相应维度的偏移，从而访问不同的 A、B 分块。

由于工作组级不再切分 M、N，C 大小保持 32×32。每次 K 分块的乘积累加到同一个 C 块，初始化应在 K 循环之前完成，不能每轮重新清零。工作组级分块在 A、B、C 上的分布如图 6-27 所示。

图 6-27　工作组级分块的矩阵分布。原图左下为 A、右上为 B、右下为 C，整体 M、N、K 范围均标为 512。A 原先的 32 行带现在沿水平方向 K 再切成宽 32 的块；B 原先的 32 列带沿垂直方向 K 再切成高 32 的块。两组新增块起点的虚线都连到 `%arg0`，表示它同时控制 A 的列偏移和 B 的行偏移。C 保留设备级形成的 32×32 网格，不因 K 分块新增空间划分。图中红点为块起点，横纵标注的 32 为块边长，省略号表示其余重复块。对固定工作组，`%arg0 = 0, 32, …, 480` 的 16 轮共同完成一个 C 块，而不是生成 16 个独立 C 结果。

<!-- 原书第 279 页；PDF 第 57 页。 -->

#### 3. 线程束级分块过程实现

虽然 `tileToSerialLoops()` 已完成归约维度的工作组级分块，GPU 的细粒度并行计算仍需在线程束或线程层组织。因此 `LLVMGPUTileAndDistribute` 还要对操作的并行维度进行线程束级或线程级分块。该 pass 支持将计算负载分配到线程束和线程两种模式，分别由 `tileToWarp()`、`tileToInvocation()` 实现。

这两个函数的主要代码逻辑相似，区别主要在于：`tileToWarp()` 基于工作组中线程束布局数组 `warpPerWorkgroup` 计算块大小；`tileToInvocation()` 基于线程布局数组 `workgroupSize` 计算块大小。此外二者的处理器信息计算函数也不同。本节仅详细分析前者，并据此理解后者。

线程束级分块在前述分块基础上，根据线程束块大小进一步切分 Linalg 操作的并行维度。各并行输出位置的计算互相独立，因此可将这些块分给不同线程束。后续递降时，各线程束沿 K 迭代，将其需要的 A、B 数据从所选共享内存路径加载到寄存器，并执行矩阵乘计算；本阶段的 memref 分块本身还没有生成全部寄存器加载和张量核指令。

`tileToWarp()` 的主要逻辑是定义线程束分块大小计算函数与处理器信息函数（此时“处理器”指线程束），配置 Linalg 循环分布选项、分块选项及转换过滤器，最后调用 `distributeLinalgOpsWithFilter()`，应用这些配置执行线程束级分块。

其参数 `workgroupSize` 由输入 IR 中函数属性内的 `workgroup_size = [64, 2, 1]` 获得：

```text
func.func @matmul_dispatch_0_matmul_512x512x512_f16() attributes {
  translation_info = #iree_codegen.translation_info<
    LLVMGPUMatmulTensorCoreMmaSync workgroup_size = [64, 2, 1]
    subgroup_size = 32, {pipeline_depth = 4 : i64, store_stage = 1 : i64}>
} {
  …
}
```

获得 `workgroupSize` 后，`tileToWarp()` 将其第 0 项除以常量 `kWarpSize`（每个线程束的线程数），保留其他维度，构成线程束布局数组 `warpPerWorkgroup`。本例从 `[64, 2, 1]` 得到 `[2, 2, 1]`；该数组随后用于计算线程束块大小与处理器信息。

> 校订注：`64 / 32 = 2` 是 x 方向的线程束数，不是整个工作组的线程束总数；总数为 `2 × 2 × 1 = 4`。这种按第 0 维除以线程束大小的布局依赖 x 维按完整线程束组织的配置前提，不能套到任意线程布局。

图 6-28 根据代码总结调用流程。

<!-- 原书第 280 页；PDF 第 58 页。 -->

```text
tileToWarp()
├── getInnerTileSizeFn                     定义线程束级分块大小计算函数
│   └── calculateDistributedTileSize()
├── getWarpProcInfoFn                      定义线程束处理器信息函数
│   └── getSubgroupIdsAndCounts()
├── linalg::LinalgLoopDistributionOptions() 生成并配置 Linalg 循环分布选项对象
├── linalg::LinalgTilingOptions()           生成并配置 Linalg 分块选项对象
├── LinalgTransformationFilter filter      生成并配置 Linalg 转换过滤器对象
└── distributeLinalgOpsWithFilter()        实现线程束级分块过程
    └── linalg::tileLinalgOp()
```

图 6-28　`tileToWarp()` 函数调用流程图。

下面按照流程分别详述各部分功能。

图中的 `getInnerTileSizeFn` 是线程束级分块大小回调，使用捕获的 `warpPerWorkgroup` 数组作为参数，调用 `calculateDistributedTileSize()` 为 Linalg 操作计算线程束块大小，其具体功能将在随后分析。

`getWarpProcInfoFn` 是线程束处理器信息回调，调用 `getSubgroupIdsAndCounts()`，传入线程束大小、并行循环范围向量 `parallelLoopRanges` 及 `warpPerWorkgroup`，得到包含处理器 ID（`procId`）与处理器数量（`nprocs`）的信息。该回调将在后续线程束分块实现 `tileLinalgOpImpl()` 中使用。

`tileToWarp()` 定义线程束级循环分布选项对象 `warpDistributionOptions`，用于将分块计算分发给不同线程束。`LinalgLoopDistributionOptions` 中的 `procInfo` 回调根据并行循环范围返回分布信息，此处将它设置为 `getWarpProcInfoFn`。

线程束级 Linalg 分块选项的配置与 6.3.2 节设备级配置类似，使用 `LinalgTilingOptions` 的 `setLoopType()`、`setTileSizeComputationFunction()`、`setDistributionOptions()`。

具体来说，`setLoopType()` 将 `loopType` 设置为 `LinalgTilingLoopType::Loops`；`setTileSizeComputationFunction()` 将大小回调设置为 `getInnerTileSizeFn`；`setDistributionOptions()` 将 `distribution` 设置为 `warpDistributionOptions`。

<!-- 原书第 281 页；PDF 第 59 页。 -->

与工作组级分块类似，线程束级也使用 Linalg 转换过滤器。`tileToWarp()` 将 `matchDisjunction` 设置为 `{"workgroup_k_tiled", "workgroup_memory"}`，将 `replacement` 设置为 `"vectorize"`，据此筛选将要在并行维度上线程束分块的操作。原书也提到空标记，仍应按前述默认匹配配置理解，不能仅由非空匹配列表推断。

在本例流水线上，`"workgroup_k_tiled"` 表示完成工作组级分块，`"workgroup_memory"` 表示随后完成 A、B 提升。两种路径均可进入线程束级分块。标记只是转换协议中的状态，并非脱离流水线即可独立证明全部内存和形状条件。

定义回调和配置选项后，`tileToWarp()` 调用 `distributeLinalgOpsWithFilter()` 执行分块，并在成功后用 `replaceLinalgTransformationFilter()` 将标记由 `"workgroup_memory"` 或 `"workgroup_k_tiled"` 更新为 `"vectorize"`，更新过程见图 6-22。此时表示准备进入后续向量化，不是标记字符串本身已经完成向量化。

`distributeLinalgOpsWithFilter()` 首先遍历相关 Linalg 操作，通过过滤器 `checkAndNotify()` 检查标记和条件，将候选保存到 `candidates` 中；然后逐个调用 `linalg::tileLinalgOp()` 进行线程束级分块转换。

`linalg::tileLinalgOp()` 在线程束级的作用类似于 `scf::tileUsingSCF()` 在工作组级的作用：依据分块选项中的循环类型生成相应循环结构，并对计算进行分块。具体实现以不同模板参数调用 `tileLinalgOpImpl()`。

（1）计算线程束级分块大小

`tileLinalgOpImpl()` 函数的重要功能之一是调用分块选项的分块大小计算函数字段 `tileSizeComputationFunction`，为每个 Linalg 操作计算各并行维度的分块大小，并将结果存储在 `tileSizeVector` 中。此处该字段指向 `tileToWarp()` 函数中定义的 lambda 函数 `getInnerTileSizeFn()`。该函数通过调用 `calculateDistributedTileSize()` 计算线程束级分块大小。

线程束级分块大小表示每个线程束在并行维度上处理的分块大小。本例采用均匀切分，计算方式为：

\[
\text{线程束级分块大小}=\frac{\text{设备级分块大小}}{\text{线程束数量}}。
\]

即在并行维度上的设备级分块大小除以该维度上的线程束数量。与工作组级分块过程类似，`calculateDistributedTileSize()` 也会根据可切分循环维度索引向量，按照上述计算方式生成线程束级分块大小向量，记为 `tileSizesVal`。这里的均分公式针对本例可整除且已验证的配置，不能不加条件地推广到任意分块配置。

<!-- 原书第 282 页；PDF 第 60 页。 -->

例如，针对测试用例中的 `linalg.matmul` 操作，调用 `getTileSizes()` 接口返回的设备级分块大小向量 `blockTileSize` 初始值为 `[32, 32, 32]`；调用 `getPartitionableLoops()` 接口返回的可分配并行循环维度索引向量 `partitionedLoops` 为 `[0, 1]`。在本例流水线中，这些并行维度已经完成设备级分块，但仍需继续执行线程束级分块。因此应保留这些维度上的设备级分块大小，由后续线程束级分块过程按照各维度的线程束数量，在设备级块的基础上做均匀切分。

计算线程束级分块大小所需的线程束数量由前述 `warpPerWorkgroup` 数组给定。本例数组为 `[2, 2, 1]`，对应硬件 `x、y、z` 方向上的线程束分布。分配到矩阵 M、N 两个并行维度上的线程束数量均为 2。

> 校订：原书将该数组三个元素直接称作 M、N、K 维的线程束数量。这里应区分硬件坐标与计算维度：本例 M 映射到 `y`，N 映射到 `x`，未使用的 `z` 方向数量为 1，并不表示将 K 归约维分配给一个线程束。前两个元素恰好相等，掩盖了轴次序的区别。`getPartitionableLoops()` 的语义也不是查询分块历史。

线程束级分块过程只对并行维度分块，因此只需保留对应并行维度的线程束数量。`partitionedLoops` 中包含随后需要分块的并行维度索引；本例值为 `[0, 1]`，只需保留 M、N 对应的线程束数量，数量向量由 `[2, 2, 1]` 缩减为 `[2, 2]`，并按循环维度顺序使用。设备级分块大小 `[32, 32, 32]` 在 M、N 维均匀分给线程束后，线程束级分块大小向量最终为 `[16, 16, 0]`。末尾的 0 表示这一级不再切分 K 维。

图 6-29 总结了计算过程（将原图的硬件轴与计算维度关系说明补全）：

| 项目 | M | N | K |
| --- | --- | --- | --- |
| 设备级分块大小 | 32 | 32 | 32 |
| 分配到该并行维度的线程束数 | 2（来自 y） | 2（来自 x） | 不参与；原数组剩余的 z 数量为 1 |
| `partitionedLoops` | 0 | 1 | — |
| 线程束级分块大小 | 16 | 16 | 0 |

图 6-29　线程束级分块大小向量计算过程。

计算得到线程束级分块大小向量后，由另一个 `tileLinalgOpImpl()` 重载接受该向量 `tileSizeVector` 和分块选项对象 `options` 作为参数，完成真正的线程束级分块功能。该重载的主要功能分为 5 个部分，源码注释标示了各部分功能。本节只分析其中与线程束级分块相关的部分。

（2）获取 Linalg 操作已分块循环范围与处理器信息

与工作组级分块调用的 `scf::tileUsingSCF()` 类似，`tileLinalgOpImpl()` 在初始阶段也需要获取循环范围。调用 `makeTiledLoopRanges()`，可以计算得到待生成分块循环的范围向量 `loopRanges`，以及原循环维度索引到范围向量索引的映射 `loopIndexToRangeIndex`。后续处理可以根据原循环维度索引，从该映射中找到相应循环范围。

<!-- 原书第 283 页；PDF 第 61 页。 -->

针对本例中的 `linalg.matmul`，`makeTiledLoopRanges()` 返回的 `loopRanges` 为 `[{0, 32, 16}, {0, 32, 16}]`。每个 `Range` 的 `size` 均为 32，表示当前对应维度的范围大小；`stride` 为 16，表示将要生成的线程束分块循环的步长。映射为 `{{key: 0, value: 0}, {key: 1, value: 1}}`，即 M、N 维的原循环索引 0、1 分别对应 `loopRanges` 的索引 0、1。

> 校订：原书由 `size` 为 32 而不为 0，推断该维已经完成设备级分块。`size` 本身并不记录分块历史；这里的 32 是本例此前转换产生的当前迭代域大小，必须结合流水线才能说明其来源。

接下来，`tileLinalgOpImpl()` 通过 `getIteratorTypesArray()` 获取 Linalg 操作所有维度的迭代器类型数组。每个数组位置对应一个循环维度索引。如果该索引出现在 `loopIndexToRangeIndex` 中，就将对应类型保存在迭代器类型向量 `iteratorTypes` 中。本例的线程束级分块在其中保留的并行维度上执行。

`linalg.matmul` 的迭代器类型依次为 `[parallel, parallel, reduction]`。为突出下标与维度的关系，原书将它写作 `[{0, parallel}, {1, parallel}, {2, reduction}]`；这只是带下标的示意表示，并非接口实际返回键值对。只有索引 2 对应归约维度，另外两维都是并行维度。

本例 `loopIndexToRangeIndex` 包含键 0、1，因此只保留原迭代器数组中索引 0、1 对应的类型，过滤掉此处不需要处理的维度。过滤后 `iteratorTypes` 为 `[parallel, parallel]`，带原下标表示为 `[{0, parallel}, {1, parallel}]`。后续只对保留的这些并行维度分块或做进一步处理。

图 6-30 展示上述过滤过程：

| 原循环维度 | 原数组中的类型 | `loopIndexToRangeIndex` | 过滤后的 `iteratorTypes` |
| --- | --- | --- | --- |
| M，索引 0 | `parallel` | `key: 0, value: 0` | 第 0 项，`parallel` |
| N，索引 1 | `parallel` | `key: 1, value: 1` | 第 1 项，`parallel` |
| K，索引 2 | `reduction` | 无 | 不保留 |

图 6-30　`iteratorTypes` 向量计算过程。原图将 K 维索引误写为 3，已修正为 2。

前文分析 `tileToWarp()` 时已经提到，该函数将 Linalg 分块选项的 `distribution` 字段设置为线程束循环分布选项 `warpDistributionOptions`，用于计算把将生成的分块循环分发到各线程束所需的信息。

`tileLinalgOpImpl()` 接下来构造处理器信息向量 `procInfo`。向量与同名回调函数字段的区别见 6.3.2 节“计算工作组处理器信息”部分。向量中的处理器信息用于在线程束级分块时分配计算资源，每个元素对应一个需要分布的并行循环。

<!-- 原书第 284 页；PDF 第 62 页。 -->

本例 `iteratorTypes` 保留 M、N 两个并行维度，长度为 2，处理器向量 `procInfo` 的长度也为 2。对应循环范围 `loopRanges` 为 `[{0, 32, 16}, {0, 32, 16}]`，其中两个 `Range` 都描述并行循环范围。因此，从中进一步过滤得到的并行循环范围向量 `parallelLoopRanges` 仍为 `[{0, 32, 16}, {0, 32, 16}]`。

图 6-31 总结了这一过程：

| 项目 | M | N | K |
| --- | --- | --- | --- |
| `shapeSize` | 32 | 32 | 32 |
| `tileSize` | 16 | 16 | 0 |
| `loopRanges` | `{0, 32, 16}` | `{0, 32, 16}` | — |
| `iteratorTypes`（附原维度索引） | `{0, parallel}` | `{1, parallel}` | — |
| `parallelLoopRanges` | `{0, 32, 16}` | `{0, 32, 16}` | — |

图 6-31　线程束级分块 `parallelLoopRanges` 向量计算过程。

获取 `parallelLoopRanges` 后，`tileLinalgOpImpl()` 调用 `warpDistributionOptions` 的回调函数字段 `procInfo`，即线程束处理器信息函数 `getWarpProcInfoFn()`，计算处理器向量 `procInfo` 的各元素。该函数进一步调用 `getSubgroupIdsAndCounts()`，为每个并行循环维度计算线程对应的线程束（subgroup）ID，并返回包含各维度线程束信息的处理器向量。

测试用例中，`parallelLoopRanges` 为 `[{0, 32, 16}, {0, 32, 16}]`，因此 `getSubgroupIdsAndCounts()` 需要为 `linalg.matmul` 的 M、N 维生成线程束 ID（`subgroupId`）和 `ProcInfo` 结构体对象，并将对象保存在 `procInfo` 向量中。

按 M、N 顺序，各维线程束 ID 的计算方式为：

```text
subgroupId = {threadId.y, threadId.x / warpSize}
```

其中整数除法计算 N 维线程束 ID；本例 `warpSize = 32`，可以使用以下仿射表达式：

```mlir
%subgroup_id_n = affine.apply affine_map<()[s0] -> (s0 floordiv 32)>()[%thread_id_x]
```

各 `ProcInfo` 的 `procId` 字段设置为对应的 `subgroupId`；`nprocs` 设置为 `warpPerWorkgroup` 中对应硬件方向的线程束数量，本例均为 2；`distributionMethod` 设置为 `Cyclic`。

<!-- 原书第 285 页；PDF 第 63 页。 -->

综上，图 6-32 展示当 `loopRanges` 为 `[{0, 32, 16}, {0, 32, 16}]` 时处理器信息向量的生成过程：

| 输入并行范围 | 回调返回的向量元素 | `procId` | `nprocs` 的来源 | `distributionMethod` |
| --- | --- | --- | --- | --- |
| M：`{0, 32, 16}` | `procInfo[0]` | `gpu.thread_id y` | `warpPerWorkgroup[1] = 2` | `Cyclic` |
| N：`{0, 32, 16}` | `procInfo[1]` | `thread_id_x floordiv 32` | `warpPerWorkgroup[0] = 2` | `Cyclic` |

图 6-32　`linalg.matmul` 操作的处理器（线程束）信息向量生成过程。原图右侧完整数组为 `warpPerWorkgroup = [2, 2, 1]`，第三项未被这两个并行范围使用；图中 N 维 `procId` 的仿射形式见上面的 `affine.apply`。

图中的 `procInfo()` 表示回调函数字段，实际指向处理器信息函数 `getWarpProcInfoFn()`；`procInfo` 表示返回的处理器向量。该向量将在下述生成线程束分块循环嵌套结构的过程中用于计算分块偏移量和大小。

（3）生成线程束级分块循环体逻辑

获取 Linalg 操作循环范围等信息后，`tileLinalgOpImpl()` 定义的 lambda 函数 `tiledLoopBodyBuilder()` 可根据给定迭代变量和操作数，生成线程束级分块循环体逻辑。以 `linalg.matmul` 为例，分块前的操作数分别为以下共享内存分配结果（沿用原书省略的地址空间属性前缀，属于 IR 摘录）：

```text
%15 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> :
    () -> memref<32x32xf16, …<workgroup>>
%16 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> :
    () -> memref<32x32xf16, …<workgroup>>
%17 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> :
    () -> memref<32x32xf16, …<workgroup>>
```

执行线程束级分块前的 `linalg.matmul` 如下：

```text
"linalg.matmul"(%16, %15, %17) <{
  indexing_maps = [affine_map<(d0, d1, d2) -> (d0, d2)>,
                   affine_map<(d0, d1, d2) -> (d2, d1)>,
                   affine_map<(d0, d1, d2) -> (d0, d1)>],
  operandSegmentSizes = array<i32: 2, 1>
}> ({
^bb0(%arg1: f16, %arg2: f16, %arg3: f16):
  %50 = "arith.mulf"(%arg1, %arg2) <{fastmath = #arith.fastmath<none>}> :
      (f16, f16) -> f16
  %51 = "arith.addf"(%arg3, %50) <{fastmath = #arith.fastmath<none>}> :
      (f16, f16) -> f16
  "linalg.yield"(%51) : (f16) -> ()
}) {…} : (memref<32x32xf16, …<workgroup>>,
          memref<32x32xf16, …<workgroup>>,
          memref<32x32xf16, …<workgroup>>) -> ()
```

> 上面的摘录省略了此前的数据复制、初始化等周边操作；`memref.alloc` 自身不初始化数据，不能把这段摘录当作从未初始化缓冲区直接执行矩阵乘法的完整程序。

<!-- 原书第 286 页；PDF 第 64 页。 -->

与 6.3.2 节设备级分块和 6.4.3 节工作组级分块的实现类似，`tiledLoopBodyBuilder()` 调用 Linalg 工具函数 `makeTiledShapes()`，使用 `memref.subview` 对 `%15`、`%16`、`%17` 分块。分块后的操作数如下：

```text
%63 = "memref.subview"(%16, %arg9) <{…}> :
    (memref<32x32xf16, …<workgroup>>, index) ->
    memref<16x32xf16, …, …<workgroup>>
%64 = "memref.subview"(%15, %arg10) <{…}> :
    (memref<32x32xf16, …<workgroup>>, index) ->
    memref<32x16xf16, …, …<workgroup>>
%65 = "memref.subview"(%17, %arg9, %arg10) <{…}> :
    (memref<32x32xf16, …<workgroup>>, index, index) ->
    memref<16x16xf16, …, …<workgroup>>
```

`memref.subview` 生成的 `%63`、`%64`、`%65` 分别是 `%16`、`%15`、`%17` 的子视图。相对源 memref 裁剪的范围由偏移量、子视图大小及跨度参数决定。分块后的 `linalg.matmul` 如下：

```text
"linalg.matmul"(%63, %64, %65) <{
  indexing_maps = [affine_map<(d0, d1, d2) -> (d0, d2)>,
                   affine_map<(d0, d1, d2) -> (d2, d1)>,
                   affine_map<(d0, d1, d2) -> (d0, d1)>], …
}> ({
^bb0(%arg6: f16, %arg7: f16, %arg8: f16):
  %55 = "arith.mulf"(%arg6, %arg7) <{…}> : (f16, f16) -> f16
  %56 = "arith.addf"(%arg8, %55) <{…}> : (f16, f16) -> f16
  "linalg.yield"(%56) : (f16) -> ()
}) {…} : (memref<16x32xf16, strided<[32, 1], offset: ?>, …<workgroup>>,
          memref<32x16xf16, strided<[32, 1], offset: ?>, …<workgroup>>,
          memref<16x16xf16, strided<[32, 1], offset: ?>, …<workgroup>>) -> ()
```

分块后的矩阵乘法以子视图 `%63`、`%64`、`%65` 为操作数。A、B 的大小由 `32×32` 分别变为 `16×32`、`32×16`，C 则变为 `16×16`。

> 校订：原书上一个代码框将 B 的 `%64` 返回类型误写为 `16×32`；后面的矩阵乘法类型写作 `32×16` 才正确。这也可由 B 的索引映射 `(d2, d1)` 以及 `[16, 16, 0]` 的分块配置直接确定。

（4）生成线程束级分块循环嵌套

前述 `tileToWarp()` 生成 Linalg 分块选项对象时，已经将 `loopType` 字段设为枚举值 `Loops`，表示使用 `scf.for` 循环。根据 `linalg.matmul` 的 `loopRanges = [{0, 32, 16}, {0, 32, 16}]`，可得到 M、N 维的分块循环嵌套以及下界、上界、步长如下。此处先展示尚未引入线程束分布的结构，并补全原书内层空循环缺少的终结操作：

```mlir
"scf.for"(%44, %45, %46) ({
^bb0(%arg4: index):
  "scf.for"(%47, %48, %49) ({
  ^bb0(%arg5: index):
    "scf.yield"() : () -> ()
  }) : (index, index, index) -> ()
  "scf.yield"() : () -> ()
}) : (index, index, index) -> ()
```

<!-- 原书第 287 页；PDF 第 65 页。 -->

上述结构由两个 `scf.for` 构成，循环下界、上界和步长来自 `loopRanges`。外层下界 `%44` 和内层下界 `%47` 均为常量 0；上界 `%45`、`%48` 均为 32；步长 `%46`、`%49` 均为 16。内外层迭代值都是 0、16，因此共同构成的迭代空间有四个点：`{(0, 0), (0, 16), (16, 0), (16, 16)}`。

将循环结构与前述 `tiledLoopBodyBuilder()` 生成的循环体结合，就得到矩阵乘法的线程束级分块循环嵌套。但上述未分布结构只描述各块范围，尚未关联处理器信息（线程束 ID、线程束数量），也就尚未把块分发到线程束。这里按概念分解生成过程；实际构建器可以在生成循环时即计算分布后的边界，并在已有归纳变量的上下文中调用循环体回调。

为实现分发，`tileLinalgOpImpl()` 从 `procInfo` 中获得线程束 ID（由线程 ID 计算出的 `procId`）和处理器数量 `nprocs`，将前者关联到循环下界，将后者关联到步长，使每个线程束执行并行迭代域的一个子集。对于 `Cyclic` 分布，新的下界为原下界加 `procId × 原步长`，新步长为 `nprocs × 原步长`。最终生成的循环嵌套如下，保留原书布局、地址空间等省略项：

```text
%6 = affine.apply affine_map<()[s0] -> (s0 * 16)>()[%thread_id_y]
scf.for %arg1 = %6 to %c32 step %c32 {
  %7 = affine.apply affine_map<(d0) -> ((d0 floordiv 32) * 16)>(%thread_id_x)
  scf.for %arg2 = %7 to %c32 step %c32 {
    %subview_8 = memref.subview %alloc_0[%arg1, 0] [16, 32] [1, 1] :
        memref<32x32xf16, …<workgroup>> to memref<16x32xf16, …, …<workgroup>>
    %subview_9 = memref.subview %alloc[0, %arg2] [32, 16] [1, 1] :
        memref<32x32xf16, …<workgroup>> to memref<32x16xf16, …, …<workgroup>>
    %subview_10 = memref.subview %alloc_1[%arg1, %arg2] [16, 16] [1, 1] :
        memref<32x32xf16, …<workgroup>> to memref<16x16xf16, …, …<workgroup>>
    linalg.matmul {…}
        ins(%subview_8, %subview_9 :
            memref<16x32xf16, …, …<workgroup>>,
            memref<32x16xf16, …, …<workgroup>>)
        outs(%subview_10 : memref<16x16xf16, …, …<workgroup>>)
  }
}
```

矩阵操作数 A、B 的 M、N 维分块偏移量分别由循环归纳变量 `%arg1`、`%arg2` 决定。它们的下界结合线程 ID 计算的线程束 ID，步长结合线程束数量，从而实现并行分布。本例每维两个线程束坐标各自只执行一个块；同一线程束内的线程在这个阶段仍共享线程束级计算描述，后续转换再分配到线程与硬件指令。

线程束级分块在 A、B、C 上的分布如图 6-33 所示。

<!-- 原书第 288 页；PDF 第 66 页。 -->

图 6-33 的三个矩阵仍以完整 `M = N = K = 512` 为背景：A 位于左下，横向为 K、纵向为 M；B 位于右上，横向为 N、纵向为 K；C 位于右下，横向为 N、纵向为 M。原有实线块界保留了设备级、工作组级的 32 大小划分，新增虚线表示线程束级细分，红点标出块界交点。图中的省略号表示各行列继续以相同方式重复。

具体来说，A 的每个 `32×32` 块沿 M 再分成两个 `16×32` 子块，图上标出横向 32、纵向 16；B 的每个 `32×32` 块沿 N 再分成两个 `32×16` 子块，图上标出横向 16、纵向 32；C 的每个 `32×32` 块沿 M、N 各分为两份，得到四个 `16×16` 子块。指向 A 的箭头标注 `%6 = thread_id_y × 16`，指向 B 的箭头标注 `%7 = (thread_id_x floordiv 32) × 16`，对应上述代码中的两个 `affine.apply`。这些是当前工作组块内部的偏移，并非完整 512 大矩阵的全部全局偏移。

图 6-33　线程束级分块的矩阵分布。

设备级、工作组级和线程束级分块在计算分块大小、生成循环体方面的逻辑设计高度相似。图 6-34 对照了三者通过不同函数完成这些步骤的调用关系，分别以 `tileDispatchUsingSCFForOp()`、`tileReductionLoops()`、`tileToWarp()` 为对应分块入口：

```text
设备级分块
TileAndDistributeToWorkgroupsPass::runOnOperation()
└── tileAndFuseDispatchUsingSCFForOp()
    └── tileDispatchUsingSCFForOp()
        └── generateTileLoopNest()

工作组级分块与线程束级分块
LLVMGPUTileAndDistributePass::runOnOperation()
└── tileToSerialLoops()
    ├── tileReductionLoops()                  工作组级分块
    │   └── tileLinalgOpsWithFilter()
    │       └── scf::tileUsingSCF()
    │           └── generateLoopNest()
    │               └── generateLoopNestUsingForOp()
    │                   └── innerYieldTiledValuesFn()
    └── tileToWarp()                          线程束级分块
        └── distributeLinalgOpsWithFilter()
            └── linalg::tileLinalgOp()
                └── tileLinalgOpImpl()
                    └── GenerateLoopNest::doit()
                        └── tiledLoopBodyBuilder()
```

图 6-34　设备级、工作组级和线程束级分块函数调用对照关系。沿用原书版本的函数名；其中设备级入口原图有 `For` 误排为 `Fop` 的笔误，已统一修正。

<!-- 原书第 289 页；PDF 第 67 页。 -->

## 6.5 MLIR 代码生成 pass 在 IREE 中的应用

IREE 的 GPU 代码生成过程使用 MLIR 提供的一系列优化和转换能力，使 MLIR 中间代码能够高效映射到 GPU 硬件指令。其中，`LLVMGPUTensorCoreVectorization` 和 `LLVMGPUVectorToGPU` 是两个关键 pass，分别实现 Linalg 操作的向量化，以及 Vector 操作到 GPU 张量核相关操作的递降，为后续 LLVM IR 和目标可执行文件的生成奠定基础。本节介绍这两个 pass 在 IREE 代码生成中的作用及工作流程；本例选择 NVGPU 的 MMA 路径。

### 6.5.1 LLVMGPUTensorCoreVectorization pass 工作流程

`LLVMGPUTensorCoreVectorization` 通过生成针对 GPU 张量核的向量化操作，将 Linalg 操作转换为适合利用张量核计算能力的 Vector 操作，供后续进一步递降为张量核指令。原书讨论英伟达 GPU 的 `wmma` 和 `mma.sync` 两类指令路径。枚举类 `GPUTensorCoreType` 定义了 `WMMA`、`MMA_SYNC`，分别用于选择相应路径；两者的用法及区别，原书引导读者参见《AI 编译器开发指南》第 5 章。

本例的张量核流水线配置函数 `addGPUMatmulTensorCoreMmaSyncPassPipeline()` 在生成 `LLVMGPUTensorCoreVectorization`、`LLVMGPUVectorToGPU` 实例时，将参数 `tensorCoreType` 指定为 `MMA_SYNC`。因此后续将相关 Vector 操作转换为 NVGPU 方言的 MMA 操作，而不是选择 GPU 方言中用于 WMMA 路径的矩阵操作。应区分 pass 的枚举配置接口与本例固定传入的枚举值，不能把两个配置分支都当成本次流水线实际执行的分支。

`LLVMGPUTensorCoreVectorizationPass::runOnOperation()` 主要分 4 步完成 GPU MMA 相关操作转换前的预处理，函数代码如下。原书省略的变量定义、模式应用等部分仍以注释保留：

```cpp
void runOnOperation() override {
  MLIRContext *context = &getContext();
  {
    vectorizeLinalgOps(funcOp);
    // …
    vector::populateVectorReductionToContractPatterns(contractionPatterns);
    if (failed(applyPatternsAndFoldGreedily(
            funcOp, std::move(contractionPatterns))))
      return signalPassFailure();
    // …
    vector::populateFoldArithExtensionPatterns(foldArithExtPatterns);
    if (failed(applyPatternsAndFoldGreedily(
            funcOp, std::move(foldArithExtPatterns))))
      return signalPassFailure();
    // …
    if (tensorCoreType == GPUTensorCoreType::MMA_SYNC) {
      // …
      mlir::populatePrepareVectorToMMAPatterns(vectorContractPatterns, true);
      // …
    }
    // …
    populateVectorUnrollPatterns(vectorUnrollPatterns, useMmaSyncShape);
    // …
  }
}
```

<!-- 原书第 290 页；PDF 第 68 页。 -->

#### 1. Linalg 操作的向量化

`runOnOperation()` 的第一步调用 `vectorizeLinalgOps()`，完成 Linalg 到向量形式操作的转换。该函数遍历 IR 函数中的操作，调用 Linalg 转换过滤器的 `checkAndNotify()`，判断相关 Linalg 操作的转换标记是否匹配 `matchDisjunction` 中的 `"vectorize"`。这些操作包括 `linalg.fill`、`linalg.generic`，以及实现 `linalg::ContractionOpInterface` 的 Linalg 操作。

在本例流水线中，匹配标记意味着相关操作已进入线程束分块后的向量化阶段；实际能否向量化还取决于向量化实现对操作、形状等条件的检查。随后调用 `linalg::vectorize()`，根据操作类型执行相应处理，得到向量形式的 Vector、Arith 等操作。

例如，对于实现 `ConvolutionOpInterface` 的卷积操作，向量化函数为 `vectorizeConvolution()`；对于其他 Linalg 操作，如 `linalg.matmul`，则调用 `convertAffineApply()` 和 `vectorizeAsLinalgGeneric()`，对操作区域中的计算做向量化。这说明底层向量化接口的分支，不表示前述过滤器会无条件选中所有卷积操作。

下面的 `linalg.matmul` 执行区域包含 `arith.mulf` 和 `arith.addf`：

```text
"linalg.matmul"(…) <{…}> ({
^bb0(%arg1: f16, %arg2: f16, %arg3: f16):
  %12 = arith.mulf %arg1, %arg2 : f16
  %13 = arith.addf %arg3, %12 : f16
  linalg.yield %13 : f16
}) {…} : …
```

参数 `%arg1`、`%arg2`、`%arg3` 表示分别来自矩阵 A、B、C 的元素。将区域参数和 Arith 操作向量化后，生成下面的 `arith.mulf` 与 `vector.multi_reduction`：

```mlir
%12 = arith.mulf %9, %10 : vector<16x16x32xf16>
%13 = vector.multi_reduction <add>, %12, %11 [2] :
    vector<16x16x32xf16> to vector<16x16xf16>
```

其中 `%9`、`%10`、`%11` 是区域参数的向量化结果，数据来自对 A、B、C 的 `vector.transfer_read`，并结合所需广播、转置等映射得到上述向量形状。不能只凭这段摘录认为三个读操作都直接产生相同形状。

`arith.mulf` 向量化后仍为 `arith.mulf`，完成向量操作数的逐元素浮点乘法，但类型变为 `vector<16x16x32xf16>`。`vector.multi_reduction` 沿 K 维对 `%12` 做加法归约，以 `%11` 为初始累加值，得到 `16×16` 的结果。

<!-- 原书第 291 页；PDF 第 69 页。 -->

区域内操作完成向量化后，`runOnOperation()` 调用 `populateVectorReductionToContractPatterns()`，将 `MultiReduceToContract`、`CombineContractBroadcast`、`CombineContractABTranspose` 等模式加入重写模式集合，将符合条件的乘法与归约组合改写为 `vector.contract`，并进一步规范化。

其中核心模式 `MultiReduceToContract` 匹配上述 `arith.mulf + vector.multi_reduction` 组合，生成以下操作：

```mlir
%13 = vector.contract {
  indexing_maps = [affine_map<(d0, d1, d2) -> (d0, d1, d2)>,
                   affine_map<(d0, d1, d2) -> (d0, d1, d2)>,
                   affine_map<(d0, d1, d2) -> (d0, d1)>],
  iterator_types = ["parallel", "parallel", "reduction"],
  kind = #vector.kind<add>
} %9, %10, %11 : vector<16x16x32xf16>, vector<16x16x32xf16>
    into vector<16x16xf16>
```

操作数 `%9`、`%10` 来自原乘法的两个输入，`%11` 来自原 `vector.multi_reduction` 的初始值向量。并非任意归约都可以变成 contraction：本地 `MultiReduceToContract` 明确检查加法归约以及乘法定义者。

其他模式（如 `CombineContractBroadcast`、`CombineContractABTranspose`）围绕 contraction 做进一步优化，例如将其输入的广播、转置吸收到索引映射中，消除不再需要显式物化的维度或操作。经过这些模式处理后的 `vector.contract` 如下，各段 SSA 编号仍分别沿用原书对应 IR 快照：

```mlir
%11 = vector.contract {
  indexing_maps = [affine_map<(d0, d1, d2) -> (d0, d2)>,
                   affine_map<(d0, d1, d2) -> (d1, d2)>,
                   affine_map<(d0, d1, d2) -> (d0, d1)>],
  iterator_types = ["parallel", "parallel", "reduction"],
  kind = #vector.kind<add>
} %8, %10, %9 : vector<16x32xf16>, vector<16x32xf16>
    into vector<16x16xf16>
```

此处右输入使用 `(N, K)` 排列，而非原 memref B 的 `(K, N)` 排列，因此两个输入向量都为 `16×32`；这是索引映射及转置处理的结果，不是前文 `%64` 子视图形状笔误的延续。

#### 2. 转置操作与 vector.transfer_read 操作的融合

`ldmatrix` PTX 指令在从共享内存读取矩阵时，可在支持的形状与数据类型条件下执行硬件支持的转置。原书对该指令的详细说明引用《AI 编译器开发指南》5.3.2 节。为利用此类硬件能力，向量转换会尽量将适用的转置并入 transfer read 的索引映射，为后续选择 `ldmatrix` 做准备。

原书在这里介绍 `runOnOperation()` 调用 `populateCombineVectorTransferReadBroadcastPatterns()`，向集合加入 `CombineTransferReadOpBroadcast`，将 `vector.broadcast` 与 `vector.transfer_read` 融合，减少显式广播。这一广播折叠与转置折叠都能简化后续转换，但属于不同变换。

> 校订：原书从“融合 broadcast 与 transfer read”直接推出“利用 ldmatrix 的转置能力、避免 transpose，并减少内存访问次数”，论证不成立。广播不等于转置，删除显式向量操作也不必然减少内存访问次数。本地 `VectorToGPU.cpp` 单独实现了将转置折叠进 transfer read 的处理，并在生成 `ldmatrix` 前检查形状、布局等条件。这里保留原书介绍的历史模式名，但不将其作用夸大为无条件生成硬件转置。

#### 3. Vector 操作递降前的其他预备工作

在将 Vector 操作递降到张量核相关操作前，还需要围绕数据传输带宽和操作数形状做进一步优化，使向量操作更适合后续转换。

<!-- 原书第 292 页；PDF 第 70 页。 -->

创建 `LLVMGPUTensorCoreVectorization` pass 时，如果参数 `tensorCoreType` 选择 `WMMA`，`runOnOperation()` 将 `CopyVectorizationPattern` 加入模式集合。该模式将具有静态形状的 `memref.copy` 改写为 `vector.transfer_read + vector.transfer_write` 组合，实现 copy 的向量化。这是另一配置分支；本例的 `addGPUMatmulTensorCoreMmaSyncPassPipeline()` 已固定选择 `MMA_SYNC`。

若选择 `MMA_SYNC`，则调用 `populatePrepareVectorToMMAPatterns()`，加入 `PrepareContractToGPUMMA` 等模式，把 Vector 操作转换为适合 MMA 递降的规范形式。该函数的详细描述见 4.3.1 节。

#### 4. Vector 操作展开过程

为将大尺寸 Vector 操作分解为一系列小尺寸操作，以适应目标硬件架构，`runOnOperation()` 调用 `populateVectorUnrollPatterns()`，加入 `UnrollTransferReadPattern`、`UnrollTransferWritePattern`、`UnrollContractionPattern` 等模式。它们使用向量展开（Vector Unrolling）技术，将 `vector.contract`、`vector.transfer_read`、`vector.transfer_write` 等操作展开为尺寸较小的 Vector 操作，并根据 contraction 的源元素类型选择适合 `mma.sync` 的形状。

`populateVectorUnrollPatterns()` 的实现如下：

```cpp
static void populateVectorUnrollPatterns(RewritePatternSet &patterns,
                                        bool useMmaSyncShape) {
  auto unrollOrder = [](Operation *op)
      -> std::optional<SmallVector<int64_t>> {
    auto contract = dyn_cast<vector::ContractionOp>(op);
    if (!contract)
      return std::nullopt;
    return gpuMmaUnrollOrder(contract);
  };
  auto getNativeShape = [useMmaSyncShape](Operation *op) {
    if (useMmaSyncShape)
      return getMmaNativeVectorSize(op);
    return getWmmaNativeVectorSize(op);
  };
  vector::populateVectorUnrollPatterns(
      patterns, vector::UnrollVectorOptions()
                    .setNativeShapeFn(getNativeShape)
                    .setUnrollTraversalOrderFn(unrollOrder));
}
```

其中 lambda `unrollOrder()` 是展开顺序计算函数。它调用 `gpuMmaUnrollOrder()`，以提高张量核计算性能为目标，为 `vector.contract` 选择向量展开的维度顺序。这里采用的是促进数据复用的策略，不是已证明对所有硬件和输入均最优的顺序。

<!-- 原书第 293 页；PDF 第 71 页。 -->

计算所得顺序数组 `loopOrder` 中的元素依次为：归约维度索引、左操作数中出现的并行维度索引、其他并行维度索引。将归约维放在展开顺序最外层，利用类似外积计算的数据局部性，使加载到寄存器的操作数尽可能复用。将左矩阵的并行维度放在中间层，使更内层遍历其他并行维度时能够复用左矩阵数据，减少重新加载的需求，从而有利于性能。

针对前述 contraction，`gpuMmaUnrollOrder()` 返回 `[2, 0, 1]`，依次对应 K、M、N 维。

lambda `getNativeShape()` 是原生形状计算回调。这里的“原生形状”是满足目标张量核指令形状要求的展开块形状。若选择 `MMA_SYNC`，调用 `getMmaNativeVectorSize()`，针对 `mma.sync`、`ldmatrix` 等目标操作的要求，为 contraction、transfer write、transfer read 计算相应展开形状。

在原书讨论的实现及其支持的源类型范围内（该处不支持 1 位和 f64 源类型），MMA 形状采用 `m16n8k*`：M 为 16，N 为 8。因而该函数为 contraction 计算原生形状时，将 `mmaShapeM`、`mmaShapeN` 分别固定为 16、8，而 `mmaShapeK` 由源类型决定。例如，4 位整数对应 K 为 64，8 位整数对应 K 为 32。这里描述的是该转换实现选用的形状，不能推广为所有 `mma.sync` 指令都只有这一族形状。

transfer write 写出矩阵乘法结果，其形状只有 M、N 两维，因此计算出的原生形状只包含 `mmaShapeM`、`mmaShapeN`。

transfer read 的情况更复杂，需要区分读取的是 A、B 还是 C。读取 C 时，形状只有 M、N，得到的原生形状也只包含这两个大小；读取 A 或 B 时，则根据数据类型返回相应固定形状，或从使用者推断形状。

定义上述两个回调后，外层 `populateVectorUnrollPatterns()` 调用 MLIR Vector 方言提供的同名函数 `vector::populateVectorUnrollPatterns()`，将三类展开模式加入集合，并配置 `UnrollVectorOptions`：通过 `setNativeShapeFn()` 指定 `getNativeShape`，通过 `setUnrollTraversalOrderFn()` 指定 `unrollOrder`。

模式展开较大的 transfer read、transfer write、contraction 时，调用这些回调获取形状、顺序，将硬件特性和优化策略应用于展开过程，为生成针对特定 GPU 架构（例如 `sm_80`）的高效张量核代码做准备。开发者也可根据自定义硬件架构特性修改这些模式，实现硬件感知的向量展开优化；展开本身尚未完成最终硬件指令生成。

<!-- 原书第 294 页；PDF 第 72 页。 -->

`UnrollContractionPattern` 对前述由 `linalg.matmul` 向量化得到的 contraction（结果为 `%11`）展开时，首先根据原生形状和展开顺序，使用 `StaticTileOffsetRange` 计算、遍历展开偏移量，然后按指定维度顺序逐块生成计算。

例如，原始张量形状为 `[10, 20, 30]`，展开块大小为 `[5, 10, 15]`，展开顺序为 `[2, 0, 1]` 时，得到的偏移量依次为：

```text
[0,  0,  0], [0, 10,  0], [5,  0,  0], [5, 10,  0],
[0,  0, 15], [0, 10, 15], [5,  0, 15], [5, 10, 15]
```

图 6-35 展示各块在原始三维张量中的布局。d0 轴取值范围为 `[0, 10)`，以 5 分界；d1 为 `[0, 20)`，以 10 分界；d2 为 `[0, 30)`，以 15 分界。每个方向均分为两块，总共八块，原图圆圈序号对应以下遍历顺序：

| 顺序 | 偏移量 `(d0, d1, d2)` | d0 区间 | d1 区间 | d2 区间 |
| --- | --- | --- | --- | --- |
| ① | `(0, 0, 0)` | `[0, 5)` | `[0, 10)` | `[0, 15)` |
| ② | `(0, 10, 0)` | `[0, 5)` | `[10, 20)` | `[0, 15)` |
| ③ | `(5, 0, 0)` | `[5, 10)` | `[0, 10)` | `[0, 15)` |
| ④ | `(5, 10, 0)` | `[5, 10)` | `[10, 20)` | `[0, 15)` |
| ⑤ | `(0, 0, 15)` | `[0, 5)` | `[0, 10)` | `[15, 30)` |
| ⑥ | `(0, 10, 15)` | `[0, 5)` | `[10, 20)` | `[15, 30)` |
| ⑦ | `(5, 0, 15)` | `[5, 10)` | `[0, 10)` | `[15, 30)` |
| ⑧ | `(5, 10, 15)` | `[5, 10)` | `[10, 20)` | `[15, 30)` |

图 6-35　展开块布局。d1 最快变化，其次 d0，最后 d2；这与顺序数组 `[2, 0, 1]` 表示由外到内的嵌套顺序相符。

得到偏移量后，通过 `vector.extract_strided_slice` 从各操作数的相应位置提取切片，在切片上执行局部 contraction，最后通过 `vector.insert_strided_slice` 将输出子矩阵拼接为最终向量。若多个块沿归约维对应同一个输出切片，必须串接累加结果，而不是把这些部分积当作互不相关的输出块直接拼接；本地实现使用累加器缓存保存这一关系。

本例源矩阵元素类型为 f16，`getNativeShape()` 得到展开块形状 `targetShape = [16, 8, 16]`，原始 contraction 的迭代形状为 `originalSize = [16, 16, 32]`，顺序为 `loopOrder = [2, 0, 1]`。以这三者构造 `StaticTileOffsetRange`，得到偏移量 `offsets`：

```text
[0, 0, 0], [0, 8, 0], [0, 0, 16], [0, 8, 16]
```

`UnrollContractionPattern` 根据每个偏移量、contraction 的索引映射和 `targetShape`，生成 `vector.extract_strided_slice`，计算其 `offsets`、`sizes` 属性，从原始 A、B、C 向量中提取较小切片。

<!-- 原书第 295 页；PDF 第 73 页。 -->

`UnrollContractionPattern` 生成的小尺寸 contraction，以上述 `vector.extract_strided_slice` 提取的切片为操作数，执行局部计算。

当展开偏移量为 `[0, 0, 0]` 时，生成如下操作。以下四段的 contraction 属性沿用原书省略写法，其映射与展开前一致：A 为 `(d0, d2)`，转置形式的 B 为 `(d1, d2)`，C 为 `(d0, d1)`，迭代类型为两个 parallel 和一个 reduction。

```text
%11 = vector.extract_strided_slice %8 {
    offsets = [0, 0], sizes = [16, 16], strides = [1, 1]
} : vector<16x32xf16> to vector<16x16xf16>
%12 = vector.extract_strided_slice %10 {
    offsets = [0, 0], sizes = [8, 16], strides = [1, 1]
} : vector<16x32xf16> to vector<8x16xf16>
%13 = vector.extract_strided_slice %9 {
    offsets = [0, 0], sizes = [16, 8], strides = [1, 1]
} : vector<16x16xf16> to vector<16x8xf16>
%14 = vector.contract {…} %11, %12, %13 :
    vector<16x16xf16>, vector<8x16xf16> into vector<16x8xf16>
```

当展开偏移量为 `[0, 8, 0]` 时，生成如下操作：

```text
%15 = vector.extract_strided_slice %8 {
    offsets = [0, 0], sizes = [16, 16], strides = [1, 1]
} : vector<16x32xf16> to vector<16x16xf16>
%16 = vector.extract_strided_slice %10 {
    offsets = [8, 0], sizes = [8, 16], strides = [1, 1]
} : vector<16x32xf16> to vector<8x16xf16>
%17 = vector.extract_strided_slice %9 {
    offsets = [0, 8], sizes = [16, 8], strides = [1, 1]
} : vector<16x16xf16> to vector<16x8xf16>
%18 = vector.contract {…} %15, %16, %17 :
    vector<16x16xf16>, vector<8x16xf16> into vector<16x8xf16>
```

当展开偏移量为 `[0, 0, 16]` 时，生成如下操作。此时继续使用第一次计算所得 `%14` 作为累加器，不再重新读取原始 C 切片：

```text
%19 = vector.extract_strided_slice %8 {
    offsets = [0, 16], sizes = [16, 16], strides = [1, 1]
} : vector<16x32xf16> to vector<16x16xf16>
%20 = vector.extract_strided_slice %10 {
    offsets = [0, 16], sizes = [8, 16], strides = [1, 1]
} : vector<16x32xf16> to vector<8x16xf16>
%21 = vector.contract {…} %19, %20, %14 :
    vector<16x16xf16>, vector<8x16xf16> into vector<16x8xf16>
```

当展开偏移量为 `[0, 8, 16]` 时，生成如下操作，同样接续第二次计算所得 `%18`：

<!-- 原书第 296 页；PDF 第 74 页。 -->

```text
%22 = vector.extract_strided_slice %8 {
    offsets = [0, 16], sizes = [16, 16], strides = [1, 1]
} : vector<16x32xf16> to vector<16x16xf16>
%23 = vector.extract_strided_slice %10 {
    offsets = [8, 16], sizes = [8, 16], strides = [1, 1]
} : vector<16x32xf16> to vector<8x16xf16>
%24 = vector.contract {…} %22, %23, %18 :
    vector<16x16xf16>, vector<8x16xf16> into vector<16x8xf16>
```

图 6-36 显示各切片在原始矩阵操作数 A、B、C 中的位置。四个圆圈序号表示不同展开偏移量对应的遍历顺序：先沿 N 方向，再沿 K 方向，符合由外到内的 `loopOrder = [2, 0, 1]`。本例 M 没有进一步切分，因为原操作与目标块在 M 上的大小均为 16。

原图由四组 A、B、C 矩阵组成，依次放在左上、右上、左下、右下，着色部分为当前参与计算的切片。图上 A 的当前向量块为 16 行、32 列，再沿 K 分成两个 16 列块；B 按数学矩阵方向画为 K 行、N 列，沿 K 分为两个 16 行块、沿 N 分为两个 8 列块；C 分为两个 `16×8` 输出块。注意，代码中 B 向量以 `(N, K)` 存放，图中为便于展示矩阵乘法，采用的是数学矩阵 B 的 `(K, N)` 朝向，两者的行列含义不要混淆。

| 图中步骤 | 展开偏移 | A 切片（源 `%8`） | B 切片（源 `%10`，代码按 N、K） | C 输入或已有累加器 | 本次结果 |
| --- | --- | --- | --- | --- | --- |
| ① | `[0, 0, 0]` | `%11`，K 的前 16 项 | `%12`，N 前 8 项、K 前 16 项 | `%13`，源 `%9` 左半块 | `%14` |
| ② | `[0, 8, 0]` | `%15`，与 `%11` 同一范围 | `%16`，N 后 8 项、K 前 16 项 | `%17`，源 `%9` 右半块 | `%18` |
| ③ | `[0, 0, 16]` | `%19`，K 的后 16 项 | `%20`，N 前 8 项、K 后 16 项 | `%14`，步骤 ① 的左半累加结果 | `%21` |
| ④ | `[0, 8, 16]` | `%22`，与 `%19` 同一范围 | `%23`，N 后 8 项、K 后 16 项 | `%18`，步骤 ② 的右半累加结果 | `%24` |

图 6-36　`vector.contract` 操作向量展开。原图后两步在 C 的对应位置分别标 `%14`、`%18`，表示更新后的累加器，而不是再次提取原始 `%9`。

<!-- 原书第 297 页；PDF 第 75 页。 -->

将原始 contraction 按 `targetShape` 拆分后，共生成四个较小的 contraction，随后生成 `vector.insert_strided_slice`，将完成 K 维累加的两个输出切片拼接为完整结果：

```mlir
%25 = vector.insert_strided_slice %21, %cst_12 {
    offsets = [0, 0], strides = [1, 1]
} : vector<16x8xf16> into vector<16x16xf16>
%26 = vector.insert_strided_slice %24, %25 {
    offsets = [0, 8], strides = [1, 1]
} : vector<16x8xf16> into vector<16x16xf16>
```

其中 `%21`、`%24` 是图 6-36 第 ③、④ 步得到的两个输出块结果，最终组合为 `%26`。`%cst_12` 是原 IR 中的目标初始向量，此处摘录未列定义；两次插入共同覆盖完整 `16×16` 输出。

图 6-37 总结了线程束级分块输出的 `linalg.matmul`，经过 `LLVMGPUTensorCoreVectorization` 转为 contraction，再展开为四个较小 contraction 的过程。原图从左到右为三组 A、B、C 矩阵，箭头分别标为 `Vectorize` 和 `Unroll`：

1. 左组为线程束级 `linalg.matmul`：A 的 `%subview_8` 为 `16×32`，B 的 `%subview_9` 为 `32×16`，C 的输出块为 `16×16`。图下代码为 `linalg.matmul ins(%subview_8, %subview_9) outs(…)`。
2. 中组为向量化后的 contraction：A 向量 `%8` 对应 `16×32`，B 向量 `%10` 对应代码中转置排列的 `16×32`，在图中仍画成数学 B 的 `32×16`；输出 `%11` 为 `16×16`。图下代码为 `%11 = vector.contract %8, %10, %9`，属性、类型由前文给出。
3. 右组为展开后：A 沿 K 分成两个 `16×16` 块，B 沿 N、K 分成四个块，图上宽度为 8、8，高度为 16、16；C 形成两个 `16×8` 的最终输出块。

图 6-37 右组使用另一套独立 SSA 编号，并复用相同的 A 切片，原图标注完整列出如下，不能与前面四段代码的编号直接混用：

```text
A 的两个块：%10、%11
B 的四个块：%16、%18（K 前半），%20、%22（K 后半）
C 的两个初始块：%12、%13
C 的两个最终块：%21、%23

%17 = vector.contract %10, %16, %12
%19 = vector.contract %10, %18, %13
%21 = vector.contract %11, %20, %17
%23 = vector.contract %11, %22, %19
```

图 6-37　`linalg.matmul` 操作的向量化和展开过程。

### 6.5.2 LLVMGPUVectorToGPU pass 工作流程

`LLVMGPUTensorCoreVectorization` 完成 Linalg 向量化后，`LLVMGPUVectorToGPU` 针对 `vector.transfer_read`、`vector.contract`、`vector.transfer_write` 等操作，调用 `convertVectorToNVVMCompatibleMMASync()`，实现本例 Vector 操作到 NVGPU MMA 相关操作的转换。

该 pass 的主要功能与 4.3.1 节所述 `ConvertVectorToGPU` pass 类似，两者的 MMA sync 路径都调用上述函数；函数功能已在 4.3.2 节详述。

若参数 `tensorCoreType` 指定 `mma.sync` 路径，`LLVMGPUVectorToGPUPass::runOnOperation()` 调用 `convertVectorToNVVMCompatibleMMASync()`，将相关 Vector 操作转为 NVGPU 路径的操作；否则调用 `convertVectorToMMAOps()`，转换为 GPU 方言的矩阵操作。这与 4.3 节的实现逻辑基本一致。

<!-- 原书第 298 页；PDF 第 76 页。 -->

至此，本例通过 `LLVMGPUVectorToGPU` 将适用的 Vector 计算、访问操作递降为 NVGPU 张量核及相关操作，并与流水线中的内存访问、同步等操作共同构成后续代码生成的输入。另一 WMMA 路径则使用 GPU 方言的矩阵操作。原书末段先称“GPU 方言”后称“递降到 NVGPU”，此处按前文选择的路径分别表述，避免混淆两个方言，也不将所有同步操作都归因于这一个转换函数。

IREE 编译流程前述各阶段——设备级分块、工作组级分块、线程束级分块和张量核向量化——生成的 MLIR 表示，由此衔接到 LLVM GPU 后端的底层代码生成逻辑。

<!-- 第 6 章原书结束：已转写并逐页核对 PDF 第 1—76 页（正文印刷页 224—298）。MLIR 相关代码按本地源码静态校对；书中 IREE 特定版本的完整实现不在本仓库，未声称全部 IREE 示例已实际编译运行。 -->
