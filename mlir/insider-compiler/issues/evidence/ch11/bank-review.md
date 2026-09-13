# 清单 11-9／11-10 的共享内存优化独立核验

本地 LLVM 18.1.8，合订 PDF 第 24–25 页。实际输入 [bank-before.mlir](bank-before.mlir)，实际输出 [bank-after.mlir](bank-after.mlir)。执行命令：

```sh
/opt/llvm-project/build/bin/mlir-opt \
  mlir/insider-compiler/issues/evidence/ch11/bank-before.mlir \
  --pass-pipeline='builtin.module(func.func(nvgpu-optimize-shared-memory))' \
  -o /private/tmp/insider-bank-after.mlir
diff -u mlir/insider-compiler/issues/evidence/ch11/bank-after.mlir /private/tmp/insider-bank-after.mlir
python3 mlir/insider-compiler/issues/evidence/ch11/bank-arithmetic.py
```

本次 Pass 执行退出码 0。示例用于观察索引改写，假定输入行列均在 `[0, 128)` 内；没有在 GPU 上执行，也没有测量 bank 冲突、吞吐或计时。

## 实际算法

[OptimizeSharedMemory.cpp](/opt/llvm-project/mlir/lib/Dialect/NVGPU/Transforms/OptimizeSharedMemory.cpp:43) 使用 XOR swizzle，并保持 memref 形状。对本例 `128×128×f32`，实际改写为：

```text
newCol = col XOR ((row AND 31) << 2)
```

读、写索引同步使用该置换。最低两位保留，对同一行是列空间内的一一置换。Pass 以 128-bit 访问为优化假设，入口收集共享内存 `memref.alloc`；原书的 `gpu.dynamic_shared_memory` 伪代码不对应这一入口，而且仅有读操作也不满足该算法要求至少一读一写的条件。

原书称第二维从 128 扩到 136，同时将列乘 8，便可使 32 线程落入不同 bank。即便先忽略其非合法 MLIR 写法，这个算术结论也不成立。按原书假设：32 个 bank、每个 f32 占一个 4-byte 字、同一 warp 的 x 连续而 y 固定，修改后的 bank 为：

```text
(136*x + 8*y) mod 32 = 8*(x+y) mod 32
```

它只有 4 种取值，32 个不同地址平均每 bank 8 个；不能得到 32 个不同 bank。并且当原列 y ≥ 17 时，`8*y ≥ 136`，第二维索引越界。原文还在推导中混淆了“x 连续、y 固定”与“y 变化”的前提。

[bank-arithmetic.py](bank-arithmetic.py) 枚举并断言这些结果，输出保存在 [bank-arithmetic.json](bank-arithmetic.json)。同样需要限定真实 Pass 的效果：对 32 线程各读一个 f32 的固定列场景，此处 XOR 仅分到 8 个 bank，并不消除全部冲突；对模型中的 8 个对齐 128-bit 向量访问，其 32 个组成字可分散到全部 32 个 bank。后一算术模型对应源码的访问宽度假设，不等于已验证任意 GPU 上的实际事务划分或性能。

更一般的支持限制见源码：读端支持 `memref.load`、`vector.load`、`nvgpu.ldmatrix`；写端支持 `memref.store`、`vector.store`、`nvgpu.device_async_copy`，要求至少二维，且遇到父操作范围内 subview 时退出。因此不能将本 Pass 描述为对任意共享内存程序自动修复所有 bank 冲突。
