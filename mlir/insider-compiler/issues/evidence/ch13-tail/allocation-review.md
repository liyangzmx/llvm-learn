# 清单 13-58／13-59 的 128 字节推导复核

主校对独立对照固定 Triton 提交 `47fc046ff29c9ea2ee90e987c39628a540603c8f`。这是源码与算术核验，没有运行 `triton-opt`。

本例为 `tensor<16x1xf32, #mma>` 到 `#blocked` 的布局转换。源 MMA v2 使用 `warpsPerCTA=[4,1]`；目标 blocked 使用 `sizePerThread=[1,2]`、`threadsPerWarp=[4,8]`、`warpsPerCTA=[4,1]`、`order=[1,0]`。

1. [`NvidiaMmaEncodingAttr::getShapePerCTATile`](https://github.com/triton-lang/triton/blob/47fc046ff29c9ea2ee90e987c39628a540603c8f/lib/Dialect/TritonGPU/IR/Dialect.cpp#L1864) 给出源 tile `[4×16,1×8]=[64,8]`；[blocked 实现](https://github.com/triton-lang/triton/blob/47fc046ff29c9ea2ee90e987c39628a540603c8f/lib/Dialect/TritonGPU/IR/Dialect.cpp#L649) 给出 `[1×4×4,2×8×1]=[16,16]`。
2. [`getRepShapeForCvtLayout`](https://github.com/triton-lang/triton/blob/47fc046ff29c9ea2ee90e987c39628a540603c8f/lib/Analysis/Allocation.cpp#L59) 对每维计算 `max(min(shapePerCTA, srcTile), min(shapePerCTA, dstTile))`。两种布局在形状 `[16,1]` 上均截为 `[16,1]`，故有效重复形状是 `[16,1]`。
3. [`getUniqueContigPerThread`](https://github.com/triton-lang/triton/blob/47fc046ff29c9ea2ee90e987c39628a540603c8f/lib/Dialect/TritonGPU/IR/Dialect.cpp#L176) 按实际维度长度截断连续元素数。转换的输入、输出顺序均取目标 blocked 的 `[1,0]`；第二维长度只有1，故 `inVec=outVec=1`。
4. [`getScratchConfigForCvtLayout`](https://github.com/triton-lang/triton/blob/47fc046ff29c9ea2ee90e987c39628a540603c8f/lib/Analysis/Allocation.cpp#L93) 选择目标 blocked 的连续维1，并增加 `max(inVec,outVec)=1` 个元素，得到临时形状 `[16,2]`。
5. [分配字节计算](https://github.com/triton-lang/triton/blob/47fc046ff29c9ea2ee90e987c39628a540603c8f/lib/Analysis/Allocation.cpp#L254) 对普通元素使用实际位宽，指针另用 `kPtrBitWidth=64`。本例 f32 为32位，因此 `16×2×32/8=128` 字节。

原书 `16×64/8=128` 恰得同数，却误把元素位宽当64，并漏掉 padding。正文修正为上述推导。同名输入见固定源码的[divide-by-0.mlir](https://github.com/triton-lang/triton/blob/47fc046ff29c9ea2ee90e987c39628a540603c8f/test/Conversion/divide-by-0.mlir)。该测试的检查目标是避免生成除零，并非对 `128` 输出作断言；不把测试文件的存在冒充本次执行结果。
