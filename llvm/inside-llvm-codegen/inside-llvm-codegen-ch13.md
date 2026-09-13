# 第 13 章添加一个新后端

> 校订基线：本书 LLVM 15（示例 15.0.1）；本章依据 `/opt/llvm-project` 的 LLVM 18.1.8，HEAD `3b5b5c1ec4a3095ab096dd780e84d7ab81f3d7ff` 作静态源码核查。未编译 LLVM，未执行本章 C/C++、LLVM IR、MIR 或汇编命令；具体输出与性能仍待运行确认。
> 保留原章全部章节、示例与图版。正文及文字代码按核查结果修订；原书图片和折叠页版面仅作对照，图片中的旧编号、版本结果和排印错误不代表 LLVM 18 输出。逐项记录见 [第 13 章校核记录](review/ch13.md)。

<!-- PDF page 395; printed page 382 -->

Chapter 13 第 13 章

添加一个新后端

由于 LLVM 的结构化设计和实现，当为它添加新的后端时，一般来说只需要对后端指令集、ABI○一（Application Binary Interface，程序二进制接口）进行处理即可。新后端只需要实现相关接口就可以把自己注册到 LLVM 代码生成的框架中。但现实情况是，一些后端会定义独有的数据类型、指令等，LLVM 框架通常不能处理，此时需要添加特殊处理功能，否则就会出错。此外，为了生成高质量的后端代码，LLVM 还会针对后端进行一些特有的优化。为了让读者能够更直观地理解，本章将首先介绍在 LLVM 代码生成的全过程中哪些阶段是添加新后端时必须进行适配的。随后，我们将以 BPF 后端为例介绍如何添加一个新的后端。

## 13.1 适配新后端的各个阶段

下面将根据代码生成的过程介绍哪些阶段必须进行新后端的适配，示意图如图 13-1所示。

![图 13-1 必须适配新后端的阶段](origin/assets/figures/p395-13-1.png)

**图 13-1 必须适配新后端的阶段**

○一 ABI 主要是指程序运行在后端需要遵守的运行约定，例如调用时参数传递、返回值处理等。

<!-- PDF page 396; printed page 383 -->

图 13-1 展示新后端的重要适配点；寄存器分配使用通用算法，但除了 TD 描述，还需要 TargetRegisterInfo/TargetInstrInfo/TargetFrameLowering 的保留寄存器、溢出存取、复制及栈访问钩子。目标特有 Pass 中有些检查/修补承担正确性职责，不能将所有白色框一概视为只影响代码质量的可选优化。

### 13.1.1 指令选择阶段的适配

指令选择阶段的工作是将 LLVM IR 转换成目标相关的后端 IR 表达 MachineInstr。具体步骤如图 13-2 所示。

![图 13-2 从 LLVM IR 到目标相关的后端 IR 的转换示意图](origin/assets/figures/p396-13-2.png)

**图 13-2 从 LLVM IR 到目标相关的后端 IR 的转换示意图**

从 IR 结构上来区分，指令选择包含 3 个阶段：SelectionDAG 构建、Machine SelectionDAG匹配目标相关的指令操作和 MachineInstr 生成，它们适配后端的情况分别如下。

1）SelectionDAGBuilder 框架把 LLVM IR 转为 DAG，但其中调用目标 LowerFormalArguments、LowerCall、LowerReturn 等钩子，初始构建阶段也包含目标适配；不能说全部后端无关。

2）SelectionDAG 匹配目标相关的操作指令过程是指令选择的核心部分，该过程将目标无关的 SelectionDAG 转换成具体目标支持的类型与操作。主要涉及两个类，如图 13-2 中的蓝色框所示。SelectionDAGISel 类作为一个 Pass，组织管理整个指令选择过程，其中有一些方法，需要具体后端继承该类并实现其中的方法。TargetLowering 类用来处理目标机器不支持的操作和类型、当前函数的入参和返回值，以及函数调用语句的入参准备等。其中，入参准备及函数返回值处理过程涉及调用约定（calling convention）。因此，该过程都是目标相关的，所涉及的类需要具体后端继承并实现相关方法。该步骤生成的 IR 仍然是SelectionDAG 的格式。

3）调度和 InstrEmitter 主要由公共框架把 DAG 转为 MachineInstr，但目标调度模型、伪指令的自定义展开等仍可参与。这里说“框架通用”不等于新后端完全不必提供相关信息。

### 13.1.2 寄存器分配相关的适配

寄存器分配阶段的输入与输出 IR 都是 MachineInstr。其中，输入的 IR 寄存器类型通常为虚拟寄存器。经过寄存器分配后，虚拟寄存器被分配到具体后端支持的物理寄存器或者栈上。寄存器分配算法的具体实现可以参考第 10 章。LLVM 高度抽象了寄存器分配算法，让算法和具体后端无关。但是在寄存器分配的过程中，需要知道后端寄存器的种类、数量、别名关系以及操作约束。

<!-- PDF page 397; printed page 384 -->

TD 提供物理寄存器、寄存器类、子寄存器等静态信息；完整适配还需要 C++ 钩子，例如 `getReservedRegs`、CSR 列表、copyPhysReg、storeRegToStackSlot/loadRegFromStackSlot 及帧索引消除。图 13-3 若理解成“只写 TD 即完成寄存器分配适配”则不完整。

![图 13-3 寄存器分配阶段的适配后端示意图](origin/assets/figures/p397-13-3.png)

**图 13-3 寄存器分配阶段的适配后端示意图**

### 13.1.3 插入前言 / 后序

在函数的开始和结束位置插入前言 / 后序，以方便调整栈的位置，具体操作由TargetFrameLowering 类实现。TargetFrameLowering 类描述了基本的栈帧布局信息，包括栈的增长方向、栈帧对齐规则、栈帧布局状态等信息。TargetFrameLowering 类声明了一些接口，需要具体后端继承该类并实现相应的接口。

### 13.1.4 机器码生成相关的适配

机器码生成阶段会将 MachineInstr 输出到汇编文件或二进制文件中。文件输出涉及的相关类如图 13-4 所示。

![图 13-4 机器码生成阶段的适配示意图](origin/assets/figures/p397-13-4.png)

**图 13-4 机器码生成阶段的适配示意图**

其中，每个类的主要工作如下。

1）AsmPrinter ：AsmPrinter 是一个组织、管理文件输出过程的 Pass，不同的后端通常

<!-- PDF page 398; printed page 385 -->

需要定义该文件，一般需要适配。

2）xxxMCInstLower ：输入的 MachineInstr 经处理后先转换为 MCInst，然后依据编译选项决定输出到汇编文件还是二进制文件。该过程和后端密切相关，一般需要适配。

3）MCAsmStreamer/MCObjectStreamer：这两个类是 MCStreamer 的子类，实现了文件输出的相关方法，分别用于输出 MCInst 到汇编文件和二进制文件，这是机器码生成的框架部分，一般不需要适配。

4）MCInstPrinter ：MCStreamer 借助该类实现指令的文本格式输出，MCInstPrinter 和具体后端相关，一般需要适配。

5）MCAsmBackend：声明指令修正相关的接口，和具体后端相关，一般需要适配。

6）MCCodeEmitter：声明指令编码接口，和具体后端相关，一般需要适配。

7）MCObjectWriter 复用 ELF/COFF/Mach-O 等格式框架，但还需要目标相关的 ObjectTargetWriter 提供机器类型、重定位映射等。例如 BPFELFObjectWriter 在 `MCTargetDesc/BPFELFObjectWriter.cpp` 实现，不能说对象写出完全无须目标适配。

注意，图 13-4 中的蓝色方框的内容一般都是需要适配的。

## 13.2 添加新后端所需要的适配

添加新后端需要的步骤可以总结如下。

1）创建 TD 文件：通过 TD 文件定义指令格式、具体指令、寄存器等基础信息。

2）在目标 TargetLowering 中声明类型/操作合法性并实现必要的 custom lowering，在 xxxISelDAGToDAG 中结合生成的匹配器完成 DAG 指令选择。类型合法化、操作合法化和模式匹配是不同职责。

3）添加目标调用约定的目标特例化处理（TargetLowering）：每个后端都有自己的 ABI 约定，需要根据 ABI 约定实现调用、参数传递、返回值、寄存器保存等功能。

4）添加栈帧的目标特例化处理（TargetFrameLowering）：栈空间是基于栈帧基址的中间代码，需要根据 ABI 约定转化为基于寄存器的中间代码。

5）添加后端的汇编输出（AsmPrinter）：处理后端相关的指令，将机器指令转化为 MC。

6）机器码编码由 MCCodeEmitter 处理，修正由 MCAsmBackend 处理，对象格式与目标重定位由 streamer/ObjectWriter 协作处理。汇编解析和反汇编分别需要 MCTargetAsmParser、MCDisassembler，并非 CodeEmitter 自动提供。

7）添加后端特殊处理：如果后端对生成的机器码有特殊的要求，则需要进行实现。

8）添加后端特有优化：对机器码还可以进一步优化，例如窥孔优化，进一步提高生成的机器码指令质量。

9）添加新的目标后端结构，并将目标后端注册到 LLVM 后端框架中，添加成功后可以通过 -target 参数使用新后端；为目标后端添加 TargetMachine 类，通过 TargetMachine 类添加 SubTarget、后端自定义优化 Pass、后端指令选择处理功能等。

LLVM 18 的 BPF 同样体现第 7、8 步：如 `BPFMIPreEmitChecking` 的正确性检查以及 `BPFMIPeephole`、`BPFMIPreEmitPeephole` 的目标优化。下文按 TD、指令选择、栈帧、机器码和注册五个方面归纳。

<!-- PDF page 399; printed page 386 -->

五个方面都需要结合目标能力完成，而不是简单机械填入同名文件。

### 13.2.1 定义 TD 文件

以 BPF 后端为例，需要实现的 TD 文件如下。

1）BPF.td 是目标描述入口，包含指令/寄存器等描述，并定义 feature、处理器模型、AsmWriter、AsmParser 与目标记录；并非仅用于 include 其他 TD。

2）`BPFInstrFormats.td` 描述编码格式，`BPFInstrInfo.td` 描述指令、操作数、汇编文本和匹配模式。TableGen 的 `InstrInfo` 记录与 C++ `TargetInstrInfo` 子类不是同一概念；手写 C++ `BPFInstrInfo` 位于 BPFInstrInfo.h/.cpp，并继承生成的 BPFGenInstrInfo。

3）`BPFRegisterInfo.td` 定义寄存器、编码、寄存器类和子寄存器关系；CSR 集在 `BPFCallingConv.td` 中定义，保留寄存器由 `BPFRegisterInfo::getReservedRegs` 决定，其中 R/W10 为帧指针，R/W11 为伪栈指针。

4）BPFCallingConv.td ：为了充分利用有限的寄存器，函数调用过程需要协调好 caller和 callee 所使用的寄存器资源。使两者之间形成一种规则，即调用约定。即 BPF 调用约定，通常包含如下几个方面。

> 下列条目是 ABI 设计关注项，不代表 BPF 都通过同一种方式实现。LLVM 18 HEAD 的普通 BPF C 调用使用 R1～R5，返回值用 R0；启用 ALU32 时还使用与 R 寄存器重叠的 W 寄存器规则。TD 中虽有 `CCAssignToStack<8,8>` 后备规则，LowerFormalArguments/LowerCall 遇到栈参数仍报不支持。

① 传参寄存器：明确哪些寄存器是用于在函数调用过程中传递参数的，比如整型寄存器和浮点型寄存器。

② 返回值寄存器：用来存放函数返回值的寄存器，如指定返回放置浮点类型和整数类型的寄存器。

③ callee-saved 约定保证调用前后寄存器的值保持。一般目标可能由生成的函数前言/后序保存恢复，但 BPF 的 FrameLowering 会从待保存集合移除 R6～R9，且 emitPrologue/emitEpilogue 为空；eBPF 调用环境负责其 ABI 保持，不能照搬普通 CPU 的 CSR 入栈/出栈描述。

④ 参数类型晋升规则：硬件寄存器是有位数的，通常支持 32 位或 64 位的操作，这意味着小于寄存器位数的参数，需要明确其晋升规则，比如 8 位或 16 的参数需要晋升到32 位。

⑤ 栈和参数对齐属于 ABI，但通常由 FrameLowering、DataLayout 和调用 lowering 共同决定。LLVM 18 BPF 尚不支持通过栈传递超出寄存器容量的参数，TD 中后备分配记录不等于完整实现。

### 13.2.2 指令选择处理

LLVM 在指令选择阶段用 SelectionDAG 表达 LLVM IR 指令。 指令选择的实现在BPFISelDAGToDAG.cpp 中，主要完成模式匹配和指令选择，具体步骤如图 13-5 所示。

<!-- PDF page 400; printed page 387 -->

![图 13-5 指令选择适配](origin/assets/figures/p400-13-5.png)

**图 13-5 指令选择适配**

不同目标支持的类型和操作不同，`BPFTargetLowering` 构造函数在 `BPFISelLowering.cpp` 通过 `addRegisterClass`、`setOperationAction` 等配置；针对标为 Custom 的操作实现 `LowerOperation` 等相应 lowering 钩子。ISD 节点 opcode 用 `ISD::NodeType` 枚举表示。ARM32 的某些 i64 操作需要拆分/展开，不应绝对说完全不能做 64 位整数操作。配置后由公共类型/操作合法化与目标选择器共同完成过程。

合法化后，对 SelectionDAG 进行模式匹配。模式匹配的核心逻辑体现在指令描述文件中。比如 BPF 后端，需要编写 BPFInstrInfo.td 文件。

### 13.2.3 栈帧处理

栈通常用两个指针来描述：一个帧指针用于指向栈底，另一个栈指针指向栈顶。LLVM使用 MachineFrameInfo 描述一个抽象的栈帧。TargetFrameLowering 用于处理栈帧布局，包括描述栈增长方向、栈帧对齐方式、局部变量在栈帧中的偏移等。

一般目标的抽象栈帧可含 CSR、局部对象、溢出槽、调用参数等区域，但图 13-6 若按普通 CPU 分区套到 BPF 并不准确。LLVM 18 的 BPF 使用只读帧指针 R10 访问局部对象/溢出槽，不生成普通 CPU 式的 SP 调整前言/后序，也不通过栈传递超出 R1～R5 的参数。这里不能据书中描述断言 BPF 规范已经承诺栈传参。

寄存器分配完成后，PEI 才具有最终溢出槽和保存寄存器等信息并计算帧对象偏移，再调用目标 `eliminateFrameIndex` 把抽象索引改为基址与偏移。并非寄存器分配结束的一刻所有偏移就已经确定。BPF 的具体保存规则参见前文，不采用原图示意中的通用 CSR 保存序列。

新后端通常实现继承 `TargetFrameLowering` 的类；BPF 中正确名称是 `BPFFrameLowering`，并和 `BPFRegisterInfo` 中的帧索引消除协作。

**图 13-6 eBPF 栈帧布局示意图（原图见下页版面；BPF 的实际限制以上述校订为准）**

<!-- PDF page 401; printed page 388 -->

### 13.2.4 机器码生成处理

文件输出所涉及的类在图 13-4 中已经做了一些说明。其中，有些类是需要目标后端继承并实现的，对应到 BPF 后端分别如下。

1）BPFAsmPrinter：实现指令输出函数 emitInstruction 和获取 Pass 名称函数 getPassName。

2）BPFMCInstLower：实现从 MachineInstr 到 MCInst 转换的相关接口。

3）BPFInstPrinter：实现输出 MCInst 到汇编文件的接口。

4）BPFAsmBackend：实现 BPF 指令修正的接口。在输出 MCInst 到二进制文件的过程中，用于对存在符号引用的指令进行修复。相关说明请参考第 12 章 12.2.2 节。

5）BPFMCCodeEmitter：实现指令编码接口，用于在输出 MCInst 到二进制文件的过程中获取指令编码。

### 13.2.5 添加新后端到 LLVM 框架中

LLVM 18 的 BPF 注册与构建映射如下；这里只读源码，不执行配置或编译。

| 项目 | 文件 / 接口 |
|---|---|
| 构建目标清单 | `llvm/CMakeLists.txt` 中 LLVM_ALL_TARGETS；实验目标也可经 LLVM_EXPERIMENTAL_TARGETS_TO_BUILD 选择 |
| TableGen 与子目录 | `llvm/lib/Target/BPF/CMakeLists.txt`，生成 BPFGen*.inc，加入 AsmParser、Disassembler、MCTargetDesc、TargetInfo |
| 目标身份 | `TargetInfo/BPFTargetInfo.cpp`：LLVMInitializeBPFTargetInfo 注册 bpf/bpfel/bpfeb |
| TargetMachine / Pass | `BPFTargetMachine.cpp`：LLVMInitializeBPFTarget、createPassConfig |
| MC 工厂 | `MCTargetDesc/BPFMCTargetDesc.cpp`：LLVMInitializeBPFTargetMC，含自定义 ELF streamer、encoder、backend 等 |
| MIR 输出 | `BPFAsmPrinter.cpp`：LLVMInitializeBPFAsmPrinter |
| 汇编解析 | `AsmParser/BPFAsmParser.cpp`：LLVMInitializeBPFAsmParser |
| 反汇编 | `Disassembler/BPFDisassembler.cpp`：LLVMInitializeBPFDisassembler |

`Targets.def` 等文件由构建配置生成，不应作为手工扩展目标的唯一入口。clang 使用 `--target=<triple>`，llc 使用 `-mtriple=<triple>` 或适当的 `-march`；完整新架构还需 Triple/前端 TargetInfo 等识别支持。BPF 在 LLVM 18 也包含 GISel 目录与 GlobalISel 钩子，书中 SelectionDAG 路线不能覆盖它们。

在 llvm/lib/Target 目录下，每个后端有一个对应的文件夹。添加一个新的后端需要新建一个文件夹，并将上述实现的目标相关类所在的文件添加到该文件夹中。接下来需要修改一些配置文件，以实现目标后端的注册。

此外，llvm/include/llvm-c/Target.h 定义了目标后端中一些与初始化相关的必要接口，如代码清单 13-1 所示。可参考已经实现的后端，将这些函数实现在相应的文件中。

**代码清单 13-1 在 Target.h 中定义的目标后端初始化接口**

```text
// 声明所有有效的后端初始化函数
#define LLVM_TARGET(TargetName) \
    void LLVMInitialize##TargetName##TargetInfo(void); // 注册新后端，指定新后端的名称
#include "llvm/Config/Targets.def"
#undef LLVM_TARGET

#define LLVM_TARGET(TargetName) void LLVMInitialize##TargetName##Target(void);
    //注册后端优化Pass
#include "llvm/Config/Targets.def"
#undef LLVM_TARGET

#define LLVM_TARGET(TargetName) \
    void LLVMInitialize##TargetName##TargetMC(void);
    // 注册MC层依赖信息，如指令打印入口、输出流等信息
#include "llvm/Config/Targets.def"
#undef LLVM_TARGET
……
```

<!-- PDF page 402; printed page 389 -->

## 13.3 本章小结

本章主要介绍如何为 LLVM 添加一个新后端。本章以 BPF 为例介绍在添加新后端时有哪些工作是必需的。此过程通常需要定义一些基本信息，例如指令信息、寄存器信息、调用约定信息，还需要实现指令选择的适配工作，如根据调用约定生成对应的 SelectionDAG、完成 SelectionDAG 的合法化工作。另外，需要根据后端约定处理栈帧，生成相应的 MC 和机器码，并将新后端注册到 LLVM 框架中。

## LLVM 18 静态校核依据

以下定位以本章所列 HEAD 为准；未运行验证的样例和历史性能比较不作为 LLVM 18 的复现实验结论。

- [llvm/lib/Target/BPF/CMakeLists.txt:1](/opt/llvm-project/llvm/lib/Target/BPF/CMakeLists.txt:1)：`TableGen generators / subdirectories`。
- [llvm/CMakeLists.txt:450](/opt/llvm-project/llvm/CMakeLists.txt:450)：`LLVM_ALL_TARGETS`。
- [llvm/lib/Target/BPF/TargetInfo/BPFTargetInfo.cpp:27](/opt/llvm-project/llvm/lib/Target/BPF/TargetInfo/BPFTargetInfo.cpp:27)：`LLVMInitializeBPFTargetInfo`。
- [llvm/lib/Target/BPF/BPFTargetMachine.cpp:41](/opt/llvm-project/llvm/lib/Target/BPF/BPFTargetMachine.cpp:41)：`LLVMInitializeBPFTarget / BPFPassConfig`。
- [llvm/lib/Target/BPF/BPFISelLowering.cpp:52](/opt/llvm-project/llvm/lib/Target/BPF/BPFISelLowering.cpp:52)：`BPFTargetLowering / LowerOperation / LowerFormalArguments / LowerCall`。
- [llvm/lib/Target/BPF/BPFISelDAGToDAG.cpp:40](/opt/llvm-project/llvm/lib/Target/BPF/BPFISelDAGToDAG.cpp:40)：`BPFDAGToDAGISel`。
- [llvm/lib/Target/BPF/BPFRegisterInfo.cpp:39](/opt/llvm-project/llvm/lib/Target/BPF/BPFRegisterInfo.cpp:39)：`getCalleeSavedRegs / getReservedRegs / eliminateFrameIndex`。
- [llvm/lib/Target/BPF/BPFFrameLowering.cpp:23](/opt/llvm-project/llvm/lib/Target/BPF/BPFFrameLowering.cpp:23)：`emitPrologue / emitEpilogue / determineCalleeSaves`。
- [llvm/lib/Target/BPF/MCTargetDesc/BPFMCTargetDesc.cpp:104](/opt/llvm-project/llvm/lib/Target/BPF/MCTargetDesc/BPFMCTargetDesc.cpp:104)：`LLVMInitializeBPFTargetMC`。
- [llvm/lib/Target/BPF/MCTargetDesc/BPFELFObjectWriter.cpp:38](/opt/llvm-project/llvm/lib/Target/BPF/MCTargetDesc/BPFELFObjectWriter.cpp:38)：`getRelocType`。
- [llvm/include/llvm-c/Target.h:41](/opt/llvm-project/llvm/include/llvm-c/Target.h:41)：`target initialization declarations`。
- [llvm/lib/Target/BPF/AsmParser/BPFAsmParser.cpp:532](/opt/llvm-project/llvm/lib/Target/BPF/AsmParser/BPFAsmParser.cpp:532)：`LLVMInitializeBPFAsmParser`。
- [llvm/lib/Target/BPF/Disassembler/BPFDisassembler.cpp:86](/opt/llvm-project/llvm/lib/Target/BPF/Disassembler/BPFDisassembler.cpp:86)：`LLVMInitializeBPFDisassembler`。

待后续验证：使用该版本构建产物逐项解析/编译示例，检查目标、优化级别与 Pass 开关，比较 Pass 前后 IR/MIR、汇编和目标文件。此阶段仅完成文档与源码静态校对。
