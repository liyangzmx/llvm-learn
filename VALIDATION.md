# 文档验证记录

基准：本地 LLVM `release/18.x` / `3b5b5c1ec4a3095ab096dd780e84d7ab81f3d7ff`。

## 已完成

- official 第 1～7 章、aiversion 第 0～7 章及两套目录齐全。
- 7 个扩充章节通过对应 official 正文的前缀包含检查；标题数量/字符下限仅防止明显截断，不是扩充质量或英文覆盖率证明。
- C++/TableGen/MLIR 代码块共 127 处：46 处逐字源码、8 处译编、73 处示意、未分类 0 处。
- 逐行核对只覆盖带源码锚点的 46 处逐字摘录（去重为 23 段）；其他 81 处不是逐字源码，不在逐行比对或编译/运行验证范围内。
- 186 个来源文件的 SHA-256 与记录基准一致。
- 所有文档中的本地 Markdown 链接及明确引用的 Toy 测试文件存在。
- 代码围栏闭合，实验 shell 代码块通过 bash -n 语法检查。
- 13 个 Mermaid 块具备 flowchart 声明及关系边；尚未做渲染验收。
- LLVM 许可证副本的文本与本地原件一致（忽略文件尾空白）。
- 校验器新增标签强制检查；内存变异回归测试确认它会拒绝缺少标签、逐字源码缺少锚点、逐字摘录被修改的情况，测试未改写任何教材或上游文件。
- 本任务未修改本地 LLVM 教程、示例、测试及现有 build。

## 复查

```bash
node /opt/coding/mlir-toy/scripts/validate-materials.mjs
node /opt/coding/mlir-toy/scripts/validate-materials.test.mjs
```

主检查通过时输出 PASS 与各项计数；回归测试输出正常基线及三个拒绝场景的结果。失败时列出具体文件和原因。脚本只读检查，不执行文档中的构建命令，也不会自动更新源码指纹。

本轮复核结论及未采纳意见见 [ds4.1 处理记录](issues/ds4.1-response.md)。

2026-09-13 的 GLM 后续复核见 [GLM 处理记录](issues/glm-response.md)。修订后重新运行主校验及内存变异回归测试，均通过；代码块来源分类数量不变。

## 未做及原因

现有 `/opt/llvm-project/build` 未启用 MLIR/Toy，因此没有重建 LLVM、编译 C++ 摘录、执行 MLIR 验证器、运行 Toy/JIT 或 FileCheck。相关输出为源码/测试约定和数学推导，不是运行日志。

未安装 Markdown/Mermaid 渲染依赖，没有将静态围栏检查冒充图形布局验收。读者使用支持 Mermaid 的 Markdown 阅读器即可查看图示。

这些限制不影响源码摘录与文件链接的静态核对，但意味着“命令语法正确”不等于“已经在这台机器上跑通”。构建与实验步骤见 [第 0 章](aiversion/00-preflight.md)。
