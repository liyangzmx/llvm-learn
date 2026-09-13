# 第 12 章三种扩展机制独立源码核对

核对合订 PDF 第 40–42 页清单 12-4～12-6。本地 LLVM 18.1.8，提交 `3b5b5c1ec4a3095ab096dd780e84d7ab81f3d7ff`。这是源码对照记录；该独立核对没有编译这三个截取的 C++ 清单，章节其他实测另记。

| 清单 | 实际源码与结论 |
| --- | --- |
| 12-4 | 本地没有 `Transform/IRDLExtension` 目录或 `registerIRDLExtension`，不能声称该片段是本地现有实现。通用扩展机制存在：[TransformDialect.h](/opt/llvm-project/mlir/include/mlir/Dialect/Transform/IR/TransformDialect.h:192) 的 `registerTransformOps`，以及 [LoopExtension.cpp](/opt/llvm-project/mlir/lib/Dialect/Transform/LoopExtension/LoopExtension.cpp:21) 的完整本地例子。扩展注入的是 transform 操作，不是直接给 IRDL 加操作。 |
| 12-5 | [ArithToLLVM.cpp](/opt/llvm-project/mlir/lib/Conversion/ArithToLLVM/ArithToLLVM.cpp:464) 的 `ArithToLLVMDialectInterface` 实际仅调用 `populateArithToLLVMConversionPatterns`；原书前置 `populateCeilFloorDivExpandOpsPatterns` 不在此处。后一个 helper 在 [Passes.h](/opt/llvm-project/mlir/include/mlir/Dialect/Arith/Transforms/Passes.h:58) 存在，应区分“函数不存在”与“此版本此位置不调用”。 |
| 12-6 | 与 [BufferDeallocationOpInterfaceImpl.cpp](/opt/llvm-project/mlir/lib/Dialect/Arith/Transforms/BufferDeallocationOpInterfaceImpl.cpp:48) 的 `SelectOpInterface` 对照。`process` 原样返回操作；所有权物化时，两分支均 unique 则额外 select 对应 indicator，否则调用默认物化路径。这是 `BufferDeallocationOpInterface`，不可与 `BufferizableOpInterface` 混同。 |

`declareDependentDialect` 用于扩展操作创建／规范化依赖的类型属性等；若变换执行可能生成另一方言的 payload 操作，应理解 `declareGeneratedDialect` 的不同用途，见同一 [TransformDialect.h](/opt/llvm-project/mlir/include/mlir/Dialect/Transform/IR/TransformDialect.h:210)。不能把两者概括成无差别的“运行时动态加操作”。
