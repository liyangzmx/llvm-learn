# 第 13.4 节历史与性能说法独立核对

对应新合订 PDF 第128～130页。以下是对原书引用的原始资料及既有源码的核对，未运行任何 GPU 基准，也不把原书的“未来趋势”更新为当下产品报道。

## AMD 后端时间

原书称“2024年9月，Triton 社区正式加入对 AMD GPU 官方后端的支持”。AMD 于 **2024-03-14** 发布的[官方博客](https://www.amd.com/en/blogs/2024/unleashing-the-open-source-power-of-ai-through-amd.html)已经说明 AMD GPU 支持合入 Triton 上游并可供用户使用，完整发布计划随 Triton 3.0。因此不能把2024年9月写成首次加入日期；正文宜写“最迟2024年3月，AMD已公开披露相关支持合入上游”。这没有把博客发布日期冒充最初合并日期。

## PyTorch 的“约80%”

[原脚注文章 CUDA-Free Inference for LLMs](https://pytorch.org/blog/cuda-free-inference-for-llms/)于2024年发布，讨论 Llama3-8B、Granite-8B 的 FP16 推理。摘要报告 H100 为 CUDA 工作流的0.76～0.78倍，A100为0.62～0.82倍；这是指定实验的模型推理表现，不是所有 Triton 单算子的固定性能比。图1/图7条件为 batch size 2、输入512、输出256；CUDA配置使用 cuBLAS GEMM 与 cuDNN SDPA，Triton配置使用 SplitK GEMM 与 AMD Triton Flash Attention。

正文可以保留原书“约80%”的历史归属，并限定模型、设备和端到端口径。网页表7中位延迟直接相除与摘要比例并不完全一致，本次没有获得原始测量数据或复测，不能把不同统计强行合并成一个精确比例。网页另有“矩阵乘和注意力占80%端到端延迟”的句子，其分母不同，不要与性能比混淆。

## ML-Triton 的“95%”

[论文 v1（2025-03-19）](https://arxiv.org/html/2503.14985v1)的摘要报告相对专家内核的性能几何均值超过95%；第4节明确环境为 Intel PVC Max1550、oneAPI 2024.1，以 SYCL profiling event 的 GPU 执行时间比较 XeTLA，双方采用相同 tile 等配置。

第4.1节分别给出 compute-bound GEMM 几何均值96%、memory-bound GEMM 94%；其余小节讨论 FlashAttention-2 与 Paged Attention。正文应限定为该研究、这些样本与统计口径，不能改写为每个算子都达到95%，也不能据此断言现有手工库已可全面替代。论文主张 workgroup → warp → intrinsic 的分层降级，属于特定扩展方案。

## MTIA 与原长链接

PDF129扫描正文印作 `MITA`，应为 **MTIA**。固定 Triton 源码中的[2023开发者会议议程](https://github.com/triton-lang/triton/blob/47fc046ff29c9ea2ee90e987c39628a540603c8f/docs/meetups/dev-meetup-2023.md)已有 Meta 作者的 Triton for MTIA 议题，支持项目名称及已有相关工作的表述。

原 Google Slides 脚注已单独渲染[页底区域](footnotes-129.png)目视，最佳转写为 `https://docs.google.com/presentation/d/1Cd-X30A7c4sdjoK20GdEsDV3qHm9jglD/edit#slide=id.p13`。其中 `s`、`9` 修正了原 OCR 的大小写和字形混淆，但长标识符仍可能含 `0`/`O` 等易混字符；本次访问仍未取得内容。不要声称已阅读该幻灯或据其确认具体实现细节；正文保留扫描转写链接并标待核实即可。

原 AMD 编译流程脚注[Unlock Peak Performance on AMD GPUs with Triton Kernel Optimizations](https://rocm.blogs.amd.com/software-tools-optimization/kernel-development-optimizations-with-triton-on-/README.html)可访问，已确认原 OCR 中 `tocm`、`oplimizations`、`.btml` 等为链接识别错误。流程实现仍以固定 Triton 提交中的 `third_party/amd/backend/compiler.py` 为准。
