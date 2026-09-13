# Triton 固定提交源码

2026-09-13 从官方仓库取得书中第三部分导读指定的提交，用于第 13 章实际源码核对。

| 项目 | 记录 |
| --- | --- |
| 提交 | [`47fc046ff29c9ea2ee90e987c39628a540603c8f`](https://github.com/triton-lang/triton/commit/47fc046ff29c9ea2ee90e987c39628a540603c8f) |
| 官方归档 | [固定提交源码 tar.gz](https://codeload.github.com/triton-lang/triton/tar.gz/47fc046ff29c9ea2ee90e987c39628a540603c8f) |
| 本次归档 SHA-256 | `65db3e74bae4b5212c18b6d8b5125bb7f953550c4100d5a54188398935fc363b` |
| 本次解包位置 | `/private/tmp/triton-47fc046ff29c9ea2ee90e987c39628a540603c8f`（临时参考源码，不属于本仓库交付文件） |
| 锁定 LLVM 提交 | `657ec7320d8a28171755ba0dd5afc570a5a16791`，取自该提交的 [`cmake/llvm-hash.txt`](https://github.com/triton-lang/triton/blob/47fc046ff29c9ea2ee90e987c39628a540603c8f/cmake/llvm-hash.txt) |

该 LLVM 提交与本地 `3b5b5c1ec4a3095ab096dd780e84d7ab81f3d7ff` 不同。Triton 自定义方言没有被注册到本地 `mlir-opt`，不能以本地工具不识别这些方言作为原书语法错误的证据。具体源码与示例核验范围见 [第 13 章记录](../ch13.md)。固定提交链接使临时源码清理后仍可重建核验环境。
