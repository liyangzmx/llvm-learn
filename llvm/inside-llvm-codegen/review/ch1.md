# 第 1 章核查与实验记录

本章已从原书导读改写为 LLVM 18.1.8 环境和证据方法说明。初版静态校订保存在提交 `c5924c6`；本次正文以源码、构建配置及实际实验为准。

| 清单 / 主题 | 依据与检查 |
| --- | --- |
| 1-1 CMake | 沿用 `/opt/llvm-project/build`，实际重配置只传入新增目标列表及非空默认 triple；正文给出当前配置的完整展开。工具目标按需增量构建，未执行 install。完整缓存与工具 SHA-256 见 `environment.json` |
| 1-2 版本与注册目标 | 实际调用 clang/llc/opt/llvm-config；检查 LLVM 18.1.8 及 BPF/AArch64/X86/RISCV/Hexagon/PowerPC/ARM。缓存与旧二进制不一致的问题已在正文解释 |
| 1-3 分阶段编译 | 完整 sum.c；Clang O0 禁用 optnone，mem2reg 后检查 PHI 和局部 alloca 消除，bitcode 往返后 verifier，O2 使用 verify-each，BPF 使用 MachineVerifier |
| 输出与执行 | readobj 检查 EM_BPF，objdump 检查函数及 exit；纯 IR 解释器检查给定输入优化前后返回 0；宿主 IR 另由普通 lli JIT 执行 |
| IR 与程序表示 | LangRef.rst、Instruction.def；SSA 值与可写内存、目标数据布局、bitcode 与目标文件边界分别解释 |
| 编译、链接、运行时 | Clang ThinLTO.rst 与工具源码；不把对象写出等同链接完成，不把解释器结果等同 BPF 内核执行 |

唯一必要的 LLVM 源码修复为 `BPFMIChecking.cpp` 中 `XOR5W32` → `XORW32`，已保存 [补丁](build-source-fix.patch)。这不是修改目标语义的实验，而是修复不存在的枚举名以允许当前工作树编译；其他用户源码改动保留。

运行记录由 [runner.py](../experiments/ch1/runner.py) 生成，见 [experiments-ch1.json](experiments-ch1.json)。本章没有测量性能、验证所有整数输入、运行 BPF 内核装载或复现交互式 LLDB 会话。
