# 第三部分 MLIR 实战项目剖析

> 来源：`insider-compiler-ch11-ch13.pdf` 第 49 页，原书第三部分扉页及导读。此页未印页码，按后续页序推定为第 285 页，详见[校订记录](issues/part3.md)。

<!-- source: insider-compiler-ch11-ch13.pdf, PDF p. 49 -->

第 1 章介绍了 MLIR 在四大场景（即 AI 场景应用、新硬件支持、新语言支持和领域优化助力）中的广泛使用。本部分旨在通过一个具体项目直观展示 MLIR 的工作流程，以便读者有更直观的理解。

在 MLIR 广泛应用的 AI 领域中，XLA、IREE 和 Triton 是三个具有代表性的项目。其中，XLA 功能强大，支持多种机器学习框架，但实现复杂；原书估计其代码量约 150 万行，本书不便于详细剖析。IREE 是基于 MLIR 的编译器与运行时，适用于端侧设备，也面向数据中心等部署环境；原书估计其代码量约 40 万行，认为复杂性在三者中居中。Triton 专注于 GPU 算子的编译，基于 MLIR 实现，具备完整的前端解析、中端优化和代码生成流程；原书估计其代码量约 20 万行，相对较小，结构清晰，便于分析。

因此，本部分选取 Triton 作为示例，并基于其官方源码[^part3-triton]展开后续讨论。另外两个项目，读者可自行了解。

> 校订：以上代码行数是原书用于说明选材理由的概数，未交代统计时点、语言范围或是否计入依赖，本次不将其作为当前项目规模的测量结果。IREE 的定位依据[项目官方说明](https://github.com/iree-org/iree#readme)补全为编译器与运行时。

[^part3-triton]: 原书分析版本对应的提交为 [`47fc046ff29c9ea2ee90e987c39628a540603c8f`](https://github.com/triton-lang/triton/commit/47fc046ff29c9ea2ee90e987c39628a540603c8f)。本次已取得该提交的官方源码，用于[第 13 章](insider-compiler-ch13.md)校订；其 LLVM 依赖由源码中的 `cmake/llvm-hash.txt` 单独锁定，不能直接视为本地 LLVM 18.1.8。
