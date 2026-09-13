# 第 1 章核查记录

基线：LLVM 18.1.8，静态阅读；未构建或运行命令。保留全章正文与历史图示，修正下列内容。

| 原文位置 | 核查依据 | 结论与处理 |
| --- | --- | --- |
| 1.1 IR 内存、表示、ABI | `llvm/include/llvm/IR/Instruction.def`；`llvm/docs/LangRef.rst`；`ThinLTO.rst` | 修正 malloc/free 指令、仅 load/store 访存、内存形式是文件、所有 LTO 都只用摘要等说法 |
| 1.2 项目术语 | `compiler-rt/README.txt`；`libunwind/docs/index.rst`；`libc/docs/index.rst` | sanitizers 不是杀毒程序；Objective-C、profiling 拼写；标准库支持和展开库关系避免过度概括 |
| 清单 1-1 | `llvm/CMakeLists.txt:69,607` | C++17、Debug/Assertions、BPF/Clang 配置仍适用；改用 shell `#` 注释和 `\` 续行，保留为未执行命令 |
| 清单 1-2 | 本地 CMake 版本 18.1.8；原书 15.0.1 | 原输出标历史，未伪造本机执行结果 |
| 清单 1-3 | `llvm/lib/CodeGen/TailDuplication.cpp:83`；`TailDuplicator.cpp:61` | 断点与参数存在；tail duplication 是尾代码重复；去掉旧地址、旧路径等日志，补明确目标和优化级别 |
| 1.4（PDF20/21） | 原页手工转写；`LegacyPassManager.cpp:52` | 恢复全部正文、4个图标题；线上界面按历史示例标记，未联网验证 |

后续：实际构建、IR 和 LLDB 调试验证均未执行。

## 独立复核补充

- 再次检查清单 1-1/1-3 的构建与调试路径，验证段改为 `build-codegen-18/bin`，与命令一致；仅核对文本，未构建。
- `libcxxabi/include/cxxabi.h:55,93` 与 `libcxxabi/src/private_typeinfo.h:68`：libcxxabi 还涉及静态初始化、RTTI/动态类型转换，不仅是异常函数。
- 图 1-1 多阶段优化是设计能力；修正成具体工具链按配置启用，不断言每个 LLVM 程序自动带运行时优化，也不把使用 IR 当成 LLVM 独有特征。
