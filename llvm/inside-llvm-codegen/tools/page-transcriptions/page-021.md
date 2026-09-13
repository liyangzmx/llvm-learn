3）本书主要关注代码生成，对应的命令行入口是 llc。llc 使用 LLVM IR 作为输入，如果要生成 BPF 后端代码，可以在编译选项中填入 -march=bpf，如图 1-4 所示。

![图 1-4 配置编译选项](assets/figures/p021-1-4.png)

**图 1-4 配置编译选项**

选择 Add new 视图下的 LLVM Opt Pipeline 选项（见图 1-5），可以展示 Clang 编译过程中使用的 Pass（参见附录 C）。

![图 1-5 选择 LLVM Opt Pipeline](assets/figures/p021-1-5.png)

**图 1-5 选择 LLVM Opt Pipeline**

得到的结果如图 1-6 所示，在 LLVM Opt Pipeline 视图中，第一列是所有 Pass，右侧两列是某一 Pass 的输入和输出。如果 IR 经过某个 Pass 处理后发生变化，在 LLVM Opt Pipeline 中使用高亮的绿色表示变化，右侧两列会提示变化的情况。（因印刷缘故，绿色、粉色都变成浅灰色，请读者注意。而在实际网页中，粉底色表示删除、绿色表示添加。）
