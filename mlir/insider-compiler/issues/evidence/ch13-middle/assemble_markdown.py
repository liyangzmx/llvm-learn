#!/usr/bin/env python3
from pathlib import Path
R=Path(__file__).resolve().parent
out=[]
def text(s):out.append(s.strip()+'\n\n')
def page(n):text(f'<!-- source: insider-compiler-ch11-ch13.pdf, PDF p. {n} -->')
def listing(n,title,boundaries=()):
 ext='txt' if n in (37,38,40,43,44) else 'mlir'
 code=(R/f'listing-13-{n}.{ext}').read_text().rstrip()
 for num,needle in boundaries:
  assert code.count(needle)==1,(n,num,needle,code.count(needle))
  code=code.replace(needle,f'@@PAGE:{num}@@\n'+needle)
 text(f'**代码清单 13-{n}** {title}')
 lang='text' if ext=='txt' else 'mlir'
 for i,part in enumerate(__import__('re').split(r'@@PAGE:(\d+)@@\n',code)):
  if i%2:page(int(part))
  elif part.strip():text('```'+lang+'\n'+part.rstrip()+'\n```')
text('''#### 7. Pipeline 优化

Pipeline 优化通过调度和重组循环体内的指令，使计算与内存操作尽可能重叠，提高指令并行度与硬件利用率。具体过程如下。

1）为循环体中的指令制定调度计划：

①扫描并识别 `tt.dot`，查找其操作数直接或间接由 `tt.load` 定义的情形，为点积和加载安排调度阶段。

②为符合条件的 `tt.load` 创建 `triton_gpu.local_alloc`，在共享内存中分配具有 shared 布局的多缓冲区，供预取使用。缓冲区数量由生产与使用之间的阶段距离等因素确定，并不恒等于总调度阶段数；后例三个阶段使用两个缓冲槽。

③将相应的 `tt.load` 改写为异步拷贝及预取相关操作，包括 `triton_gpu.async_copy_global_to_local`、`triton_gpu.async_commit_group`、`triton_gpu.async_wait`、`triton_gpu.memdesc_subview` 等，并为新操作安排阶段。此转换还受目标硬件、数据宽度、布局等合法性条件约束，并非所有加载都无条件异步化。

④为与已调度操作存在 Use-Def 依赖的其他操作安排阶段。

⑤为循环中尚未调度的剩余操作安排阶段。

⑥为前述 `triton_gpu.local_alloc` 配置相应的 `triton_gpu.local_dealloc`，并保证释放前需要等待的异步工作已经完成。

2）生成前言（Prologue）代码：按调度计划复制早期阶段的操作到循环外，处理启动阶段，并在需要时加上迭代范围谓词。

3）根据调度计划重新组织循环体，调整操作顺序、跨迭代的值传递和循环携带参数。

4）处理流水线排空阶段。通用的软件流水线可以生成后序（Epilogue）；也可以保留原循环范围，依靠谓词关闭越界的预取等操作。后者是下文所参考 Triton 实现的配置，不能把它简单说成“处理后继基本块中的指令”。

先看一个三个调度阶段的教学模型。阶段编号为 0、1、2，最大阶段编号 `maxStage` 为 2。代码清单 13-37 中，`S0(I)` 表示原循环第 I 次迭代中调度阶段为 0 的指令集，`S1`、`S2` 类似。为了明确半开边界，下面用伪代码表达步长为 1 的 `0 <= I < N` 循环。''')
page(93)
listing(37,'Pipeline 优化前的代码（伪代码）')
text('经过 Pipeline 优化，教学模型可重组为前言、Pipelined Kernel 和后序三部分，如代码清单 13-38。这里假定 N ≥ 2；少于两次迭代时可回退执行原循环，或使用额外的谓词保护。')
listing(38,'Pipeline 优化后的代码（剥离后序的教学模型）')
text('''校订注：原书后序写成 `S1(N) S2(N-1) S2(N)`，与 `scf.for` 的半开上界不一致。这里改为 `S1(N-1) S2(N-2) S2(N-1)`，使每个阶段的每次原迭代恰好执行一次。后续 Triton 示例配置为 `peelEpilogue = false`，采用谓词处理排空阶段，不必产生这份教学模型中的显式后序。

下面以代码清单 13-39 为例，分步展示 Pipeline 优化。原书使用命令 `triton-opt 13-39.mlir -split-input-file -tritongpu-pipeline`。所参考 Triton 快照的 `num-stages` 默认值是 3，也可以显式写成 `-tritongpu-pipeline=num-stages=3`。下列中间打印不是仅运行一次普通命令就会依次输出的完整日志，观察内部步骤通常还需调试打印或插桩。

本机 `/opt/llvm-project` 为 LLVM 18.1.8，未包含 Triton 方言或可用的 `triton-opt`。本节按扫描恢复完整代码，并对照 Triton 源码解释，未将这些长清单冒称为本机重跑产生的结果。原例只演示调度，矩阵结果没有返回或写回，指针也每轮仅偏移 4 个元素；它不是完整可用的矩阵乘内核。''')
listing(39,'Pipeline 优化示例代码',[(94,'    %b_ptr_init =')])
text('第 1 步：扫描循环体内符合条件的加载与点积。原书加粗的是 `%a_ = tt.load %a_ptr`、`%b_ = tt.load %b_ptr, %b_mask, %b_other` 和 `%c = tt.dot %a, %b, %prev_c`；正文清单用合法注释标出这些调度对象。为它们安排阶段后，结果如代码清单 13-40：两个 `tt.load` 位于阶段 0，`tt.dot` 位于阶段 2，阶段 1 此时为空。')
listing(40,'为 tt.dot 和 tt.load 设置调度阶段',[(95,'---- Ops in stage 1')])
text('第 2 步：为第 1 步中的加载创建 `triton_gpu.local_alloc`，为预取准备 shared 布局缓冲区，见代码清单 13-41。两个 memdesc 的最外层大小都是 2，分别保存 A 与 B 的两个缓冲槽。')
listing(41,'为 tt.load 创建 triton_gpu.local_alloc 后的代码',[(96,'    %8 ='),(97,'      %15 =')])
text('第 3 步：将第 1 步中的 `tt.load` 替换为 `triton_gpu.async_copy_global_to_local` 及数据预取相关操作，结果如代码清单 13-42。提交操作产生组令牌；等待操作和令牌关联表达异步完成要求，随后从共享内存装载并转换到点积操作数布局。')
listing(42,'用异步拷贝和预取相关操作替换 tt.load 后的代码',[(98,'    %3 ='),(99,'    %10 ='),(100,'      %26 ='),(101,'    tt.return')])
text('接着为循环体中的新操作安排阶段，得到代码清单 13-43。这里是调度表的打印，表内列举顺序不等同于最终可执行 IR 的先后顺序，所以可以看到提交操作列在其拷贝定义之前。')
listing(43,'为循环体中新操作设置调度阶段后的结果')
page(102)
text('第 4 步：为与已调度操作存在 Use-Def 依赖的相关操作安排阶段，结果如代码清单 13-44。原书称“至此循环中所有指令都已被设置了合适的调度阶段”，但下面的打印尚未列出两个 `tt.addptr` 以及终止操作；最终调度还需处理剩余操作与循环携带依赖，不能仅凭这份部分表断言全部覆盖。')
listing(44,'为存在 Use-Def 依赖的相关操作设置调度阶段',[(103,'cluster: 3:\n%16 =')])
page(104)
text('第 5 步：为前面第 2 步创建的 `triton_gpu.local_alloc` 补上对应的 `triton_gpu.local_dealloc`，结果如代码清单 13-45。原书此处误指为“第 3 步”创建；释放前插入 `async_wait {num = 0}`，等待未完成的异步组。')
listing(45,'创建对应 triton_gpu.local_dealloc 后的结果',[(105,'    %cst ='),(106,'      %21 ='),(107,'      %34 =')])
text('第 6 步：生成前言代码，把阶段小于 `maxStage` 的相应指令实例复制到循环外。此例 `maxStage = 2`：先生成阶段 0 的第一批操作，再生成阶段 0 的下一批及阶段 1 的相应操作，见代码清单 13-46。原书加粗的前言范围对应 `%c0`、`%12` 至 `%54` 以及其中的常量定义，清单中已用注释标出。该清单是仅生成前言、尚未完成原循环重接的内部快照；不能单独运行它来验证与原程序等价。')
listing(46,'生成前言后的代码（编译器内部中间快照）',[(108,'    %3 ='),(109,'    %10 ='),(110,'    %28 ='),(111,'    %48 ='),(112,'      %69 ='),(113,'    %56 =')])
text('第 7 步：根据阶段重建循环体和跨迭代值传递，再进行归一化，原书展示的最终结果如代码清单 13-47。变化不限于调整指令顺序：循环携带参数从 5 个变为 11 个，包括预取的共享内存视图和令牌；循环保留原上界，`%40` 控制提前两次迭代的拷贝是否仍在合法范围内；等待组数量改为 2 以允许较新的组继续在途。原书称结果经过 `canonicalize`，但没有给出生成该快照的确切版本和全部选项，本次仅恢复其打印并核对结构，未声称可逐字复现该输出。')
listing(47,'重建循环并进行归一化后的代码',[(114,'    %3 ='),(115,'    %18 ='),(116,'    %34 ='),(117,'      %46 ='),(118,'      scf.yield')])
Path('/private/tmp/insider-ch13-middle.md').write_text(''.join(out))
print('wrote',len(''.join(out).encode()),'bytes')
