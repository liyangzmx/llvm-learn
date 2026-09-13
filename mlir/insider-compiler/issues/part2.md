# 第二部分导读校订记录

来源：`insider-compiler-ch7-ch10.pdf` 第 18–20 页。三页均实际打开渲染图目视，包括第 19 页未编号的大幅关系图。正文见 [insider-compiler-part2.md](../insider-compiler-part2.md)。第 18 页扉页未印页码，“145”仅由相邻页序推定。

## 完整性与图示

保留扉页说明、未编号全景图、六类方言介绍、最后的第二种分类与作者观点。没有编号代码清单或脚注。原图直接从 PDF 第 19 页图框区域渲染为 [diagram-original.png](evidence/part2/diagram-original.png)，保留所有箭头；未用 OCR 猜测相互交叉的线。另以 Mermaid 表达本地已核对的主要路径，并用表格保留原图全部标签及不同命名。

复现原图渲染：在仓库根目录执行以下命令，需要 macOS PDFKit。

```sh
swiftc -module-cache-path /private/tmp/insider-swift-cache \
  mlir/insider-compiler/issues/evidence/part2/render_diagram.swift \
  -o /private/tmp/insider-render-diagram
/private/tmp/insider-render-diagram
```

生成的是源图矩形的 288 dpi 渲染，不是 AI 重绘。完整的逐页图像仍在 OCR 渲染缓存中。

## 修正与依据

| 页 | 原文问题 | 校订与实际依据 |
| --- | --- | --- |
| 18 | “仅需”接入高级方言便可构建编译器，容易理解为所有后端路径自动齐备 | 保留复用框架的意思，补足配置 pipeline、类型转换及运行时的条件；数量“接近 50”标为成书时概数，不当作固定本地数量 |
| 19 | 图中 `pdl-interp`、`neno`，正文与图中的部分方言不在本地版本 | 命名空间校正为 `pdl_interp`、`arm_neon`；原图标签保留。实际注册列表来自 `mlir-opt --show-dialects`，见 [dialects.txt](evidence/part2/dialects.txt)，定义由 [InitAllDialects.h](/opt/llvm-project/mlir/include/mlir/InitAllDialects.h) 交叉核对 |
| 19–20 | 将 MPI、Ptr、Polynomial、XeGPU、独立 AVX/AVX512 方言视为本地现有项 | 明确本地没有对应独立方言，不删去原书提及；不据此断言 LLVM 20 一定不存在。外部 StableHLO、Torch、XLA 也不冒充本地源码内容 |
| 19 | 把 `vector` 仅当数据分块，把 `linalg` 仅当“线性算法” | 改为向量计算及结构化线性代数，保留分块优化的用途，参见 [VectorOps.td](/opt/llvm-project/mlir/include/mlir/Dialect/Vector/IR/VectorOps.td)、[LinalgStructuredOps.td](/opt/llvm-project/mlir/include/mlir/Dialect/Linalg/IR/LinalgStructuredOps.td) |
| 19 | bufferization 实现“缓存优化” | 改为 tensor 到 memref 的缓冲化及存储复用，见 [Bufferization.md](/opt/llvm-project/mlir/docs/Bufferization.md:8) 和 [独立源码与实测记录](evidence/ch9-bufferization/README.md) |
| 20 | scf 为“标准控制流”，`spare_tensor` | 改为“结构化控制流”、`sparse_tensor`，见 [SCFOps.td](/opt/llvm-project/mlir/include/mlir/Dialect/SCF/IR/SCFOps.td:26)、[SparseTensorBase.td](/opt/llvm-project/mlir/include/mlir/Dialect/SparseTensor/IR/SparseTensorBase.td) |
| 20 | 所有目标输出都描述为 LLVM IR；MLIR llvm 方言与 LLVM IR 混同 | 分清 MLIR 方言转换与最终翻译，补回原图已有的 SPIR-V 路径。见 [LLVM IR 翻译](/opt/llvm-project/mlir/lib/Target/LLVMIR/ModuleTranslation.cpp)、[SPIR-V 序列化](/opt/llvm-project/mlir/lib/Target/SPIRV/Serialization/Serializer.cpp) |
| 20 | `pdll` 列为方言 | PDLL 是模式前端语言，PDL 才是相关 IR 方言，见 [PDLL.md](/opt/llvm-project/mlir/docs/PDLL.md:1) |
| 20 | transform 被解释为基于动态方言扩展已有方言的模式匹配 | 以 transform IR、payload IR、句柄及扩展操作解释实际机制，见 [Transform.md](/opt/llvm-project/mlir/docs/Dialects/Transform.md:5) 及其 142 行开始的扩展机制 |

Mermaid 中的主要转换边分别对应 [Conversion/Passes.td](/opt/llvm-project/mlir/include/mlir/Conversion/Passes.td) 内 TOSA、Affine、SCF、ControlFlow、Func、GPU、Arith、Vector、MemRef 转换；Linalg 循环化见 [Linalg/Passes.td](/opt/llvm-project/mlir/include/mlir/Dialect/Linalg/Passes.td:62)；NVVM、ROCDL 翻译见 [NVVMToLLVMIRTranslation.cpp](/opt/llvm-project/mlir/lib/Target/LLVMIR/Dialect/NVVM/NVVMToLLVMIRTranslation.cpp)、[ROCDLToLLVMIRTranslation.cpp](/opt/llvm-project/mlir/lib/Target/LLVMIR/Dialect/ROCDL/ROCDLToLLVMIRTranslation.cpp)。这些源码证明转换设施存在，不保证任意输入可沿图中路径完整降级。

## 较大的原文观点差异

原文最后认为 MLIR 基础框架“不应包含业务领域方言”，并说“所幸 LLVM 社区近期已意识到这个问题的严重性，现已成立专门的组织来管理和维护 MLIR 社区的发展”。前半属于作者观点，后半包含历史事件及因果判断。本地源码实际仍包括 TOSA 和 MLProgram，不能把作者观点写成当前排除这些方言的社区规则；本次源码核验也不能证明组织变化由这一原因引发。正文保留并归属作者的架构观点，把无法支持的历史因果说法移至本记录，未编造替代历史。

TensorFlow 2.0 的例子同样作为原书举例保留，本次没有构建 TensorFlow 或外部方言项目。第 11、12 章及附录是导读原有前向引用；第 11、12 章后来随 `insider-compiler-ch11-ch13.pdf` 补入，附录尚未提供。
