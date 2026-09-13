# 第 6 章 TableGen 介绍

> 原文转写，未经技术修订。来源：[原 PDF](../pdf/inside-llvm-codegen.pdf)，PDF 第 85–99 页。书中基线为 LLVM 15（示例 15.0.1）。
> 保留原文观点、命令及排印错误；代码缩进按 PDF 坐标恢复。保留原图裁剪及页码标记，图表、公式或特殊字体可对照原 PDF 读取。

<!-- PDF page 85; printed page 72 -->

Chapter 6 第 6 章

TableGen 介绍

编译器最为基础的功能之一是将高级语言转换成可以在硬件上执行的机器码，为了支持尽可能多的硬件，通用编译器需要为每一款硬件都实现这一转换。为了更好地生成高质量的目标机器码，编译器后端开发者需要了解目标机器的指令集信息（包括具体支持哪些指令、指令有什么属性、应该使用什么寄存器、指令间存在什么样的依赖）。虽然每一款不同的硬件指令集都不相同，但都包含指令、寄存器、调用约定等信息，所以可以将这些信息进行抽象。这样编译器后端实现时就可以分为两层：具体硬件信息和与硬件无关的编译框架。不同的目标硬件都包含了丰富的指令、寄存器信息等，直接描述这些信息将会非常冗杂，并且很难做到格式统一，所以很有必要设计一种通用的后端信息描述语言，这就是目标描述语言 TableGen。

因为 TableGen 和代码生成过程密切相关，所以本章简单介绍 TableGen 的词法、语法，并且演示如何从目标描述语言转换为 C++ 代码，从而和编译器的代码生成框架结合起来。本章最后将以指令匹配为例介绍如何写 TD 文件。

## 6.1 目标描述语言

下面分别从 TableGen 的词法和语法展开介绍。

### 6.1.1 词法

TableGen 作为一门 DSL（Domain Specific Language，领域描述语言）语言，提供了关键字、标识符、特殊运算符等信息，在词法分析阶段对 TD 文件进行分析可以得到对应的token（单词符号）。

<!-- PDF page 86; printed page 73 -->

1）数值字面量：表示 TD 文件直接给出的数值，只支持整数字面量，可以定义十进制、十六进制和二进制，其文法如代码清单 6-1 所示。

**代码清单 6-1 数值字面量文法**

```text
TokInteger     ::=  DecimalInteger | HexInteger | BinInteger
DecimalInteger ::=  ["+" | "-"] ("0"..."9")+
HexInteger     ::=  "0x" ("0"..."9" | "a"..."f" | "A"..."F")+
BinInteger     ::=  "0b" ("0" | "1")+
```

上述文法含义：TokInteger 表示整数，可以是十进制整数、十六进制整数或二进制整数；其中十进制整数以“ +”或“ –”符号开头（“ +”可以省略），后面是一个或多个 0～9的数字；十六进制整数以“0x”开头，后面是一个或多个 0～9 的数字或 a～f 的字母；二进制整数以“0b”开头，后面是一个或多个数字 0 或者数字 1。

2）字符串字面量：表示 TD 文件中的字符串常量，其文法如代码清单 6-2 所示。

**代码清单 6-2 字符串字面量文法**

```text
TokString ::= '"' (non-'"' characters and escapes) '"'
TokCode ::= "[{" (shortest text not containing "}]") "}]"
```

上述文法含义：TokString 表示单行的字符串字面量，以双引号““”作为开头和结尾，中间可以是非双引号的“ "”字符和转义字符“ \”；TokCode，表示跨行的字符串字面量，以“[{”开头、以“}]”结尾，中间可以是非“}]”的字符串。

3）关键字：TableGen 定义了一些关键字，这些关键字都有特殊的含义。目前的关键字有 assert、bit、bits、class、code、dag、def、dump、else、false、foreach、defm、defset、defvar、field、if、include、int、let、list、multiclass、string、then、true。这些关键字分别描述类型、语法结构等信息，6.1.2 节将对部分重要关键字进行介绍。

4）标识符：定义了变量，其文法如代码清单 6-3 所示。

**代码清单 6-3 标识符文法**

```text
ualpha ::= "a"..."z" | "A"..."Z" | "_"
TokIdentifier ::= ("0"..."9")* ualpha (ualpha | "0"..."9")*
TokVarName ::= "$" ualpha (ualpha | "0"..."9")*
```

上述文法含义：TokIdentifier 表示标识符，以 0 个或多个 0～9 的数字开头，中间是字母或者下划线，后面是 0 个或多个字母、下划线或者数字；TokVarName 表示别名，以 $ 开头，中间是字母或者下划线，后面是 0 个或多个字母、下划线或者数字。其中标识符是大小写敏感的。另外，标识符也可以是数字开头，如果标识符只有数字，则 TableGen 会将它解释为整数字面量。

注 意 TokVarName 仅仅适用于 DAG 中。

<!-- PDF page 87; printed page 74 -->

5）特殊运算符：TableGen 还提供了“ !”运算符，以“ !”开头，后跟一些运算。例如，!add 表示对多个操作数进行求和计算，“ !”运算符可以认为是 TableGen 内置的处理方式。关于“!”运算符的更多介绍可以参见官网○一。

6）基本分隔符：TableGen 还提供了一些基础符号（参见 6.1.2 节），例如 –、+、[、]、{、}、(、)、<、>、:、;、.、...、 =、?、# 等，这些符号作为分界符通常要配合语法来使用，例如<> 用于定义模板参数，[] 用于定义列表数据。

7）其他词法：TableGen 提供了 include 语法，可以在本文件中引入其他的 TD 文件，并提供了预处理的功能，详细内容可以参考官网。

### 6.1.2 语法

TableGen 提供的语法比较丰富，限于篇幅无法展开介绍，本节仅介绍类型（type）、值（value）和记录（record）相关的内容，其他内容请参考官网。

1. 类型

TableGen 定义了如下数据类型。

1）bit：表示布尔类型，可以取值 0 或 1。

2）int：表示 64 位的整数。

3）string：表示任意长度的字符串。

4）dag：表示可嵌套的 DAG。DAG 的节点由一个运算符、0 个或多个参数（即操作数）组成，节点中的运算符必须是一个实例化的记录。DAG 的大小等于参数的数量。

5）bits<n>：表示大小为 n 的位数组（数组中的每个元素占用一位）。

6）list<type>：表示元素的数据类型为类型的列表。列表元素的下标从 0 开始。

注 位数组 bits<n> 中的索引值是从右往左递增的，即索引为 0 的元素位于最右侧。比

意

如 bits<2> val = {1, 0}，表示十进制整数 2。

注意，在 TableGen 中，一个无环图可以使用 dag 数据类型直接表示。DAG 节点由一个运算符和 0 个或多个参数组成，每个参数可以是任何类型，例如使用其他 DAG 节点作为参数可以构建基于 DAG 节点的任意图。

DAG 节点的语法是 (operator argument1, argument2, …, argumentn)，其中 operator 为操作数，必须显式定义，且必须是一个记录，其后可以有零个或多个参数，参数之间用逗号分隔。参数可以有 3 种格式：value（参数值类型）、value:name（参数值类型和相关名字）、name（未设置值类型的参数名字）。

2. 值

TableGen 中的值可以通过如代码清单 6-4 所示的文法进行描述。

○一 具体可参见 https://llvm.org/docs/TableGen/ProgRef.html。

<!-- PDF page 88; printed page 75 -->

**代码清单 6-4 值的文法**

```text
Value         ::=  SimpleValue ValueSuffix* | Value "#" [Value]
ValueSuffix   ::=  "{" RangeList "}" | "[" SliceElements "]" | "." TokIdentifier
RangeList     ::=  RangePiece ("," RangePiece)*
RangePiece    ::=  TokInteger | TokInteger "..." TokInteger | TokInteger "-"
                   TokInteger| TokInteger TokInteger
SliceElements ::=  (SliceElement ",")* SliceElement ","?
SliceElement  ::=  Value | Value "..." Value | Value "-" Value | Value TokInteger
```

值可以分为 3 类，分别是简单值、后缀值以及复合值。其中：

1）简单值（SimpleValue）可以是整数、字符串或者代码。例如“ int a = 1;”表示变量a 的赋值为 1。

2）后缀值（ValueSuffix*）是在简单值后面增加约束。例如“ let a{1-3} = 0b110; ”表示 a 的赋值为二进制值“0b0110”。

3）复合值（Value“ #” [Value]）表示将多个值通过连接符“ #”进行组合。例如“ let str = "12" # "ab";”表示将两个字符串连接形成一个新的值。

3. 记录

TableGen 最主要的目的之一是生成记录，然后后端基于记录进行分析得到最终结果。记录可以被看作是有名字、有类型、具有特定属性的结构体。TableGen 分别通过 def 和class 定义记录，并在此基础上提供批量定义记录的高级语法 mutliclass、defm。

1）用 def 定义一个具体的记录：非常类似于 C 语言中用 struct 定义的结构体，包含了名字、类型和属性，def 示例如代码清单 6-5 所示。

**代码清单 6-5 def 示例**

```text
def record_example {
    int a=1;
    string b="def example";
}
```

**代码清单 6-5 定义了一个记录，名字为 record_example，它包含了两个字段：a 和 b。**

其中，a 的类型为整型，值为 1；b 的类型为字符型，值为 def example。

2）用 class 定义一个记录类：该记录类可以被实例化为记录，它非常类似于 C++ 中的class。来看一个 calss 的应用示例，示例首先用 class 定义一个记录类，然后通过 def 来实例化记录，如代码清单 6-6 所示。

**代码清单 6-6 使用 class 定义记录类，使用 def 实例化记录示例**

```text
class TestInst {
    string asmname;
    bits<32> encoding;
}
def ADD: TestInst {
```

<!-- PDF page 89; printed page 76 -->

```text
    let asmname="add";
    let encoding{31-26}=1;
}
def MUL: TestInst {
    let asmname="mul";
    let encoding{31-26}=2;
}
```

**代码清单 6-6 首先通过 class 定义记录类 TestInst，然后通过 def 实例化两个记录—**

ADD 和 MUL。在实例化的过程中，要用 let 关键字对 class 中定义的字段进行赋值，例如class 中定义了 asmname，在 ADD 中通过 let asmname="add" 对 asmname 进行赋值。

我们还可以定义 class 层次，并通过继承的方式来使用（所以它非常类似于 C++ 中的class）。使用 class 可以大大简化记录的定义，将公共的信息通过 class 定义，然后通过 def进行实例化。

3）用 multiclass 和 defm 定义一组记录。虽然可以通过 class 对记录进行抽象，然后通过 def 实例化。但是在实际工作中会遇到这样的问题：很多记录类也比较类似，例如在后端中存在 add 指令，add 指令接收两个操作数，第一种合法的指令是两个操作数都是寄存器；第二种合法的指令是一个操作数是寄存器，另一个操作数是立即数。此时需要利用两个class 对 add 指令进行抽象。因为这两个 class 非常类似，只有一个操作数不相同而已，所以TableGen 引入 multiclass 来一次定义多个 class。multiclass 定义的多个类可以通过 defm 进行实例化，使用 multiclass 和 defm 同时定义多个记录的示例如代码清单 6-7 所示。

**代码清单 6-7 使用 multiclass 和 defm 同时定义多个记录示例**

```text
class Instr<bits<4> op, string desc> {
    bits<4> opcode = op;
    string name = desc;
}
multiclass RegInstr {
    def rr : Instr<0b1111,"rr">;
    def rm : Instr<0b0000,"rm">;
}

defm MyBackend_:RegInstr;
```

multiclass 比较抽象，上面的例子相当于使用 multiclass 定义了两个记录类，分别为 rr和 rm，伪代码如代码清单 6-8 所示。

**代码清单 6-8 用 multiclass 分别定义 rr 和 rm 的伪代码**

```text
class rr {
    bits<4> opcode = 0b1111;
    string nameDes = "rr";
}
class rm {
```

<!-- PDF page 90; printed page 77 -->

```text
    bits<4> opcode = 0b0000;
    string nameDes = "rm";
}
```

然后通过 def 进行实例化，实例化对象分别是 MyBackend_rm 和 MyBackend_rr。可以直接使用 llvm-tblgen 编译代码清单 6-7，生成的 MyBackend_rm 和 MyBackend_rr 记录如代码清单 6-9 所示。

**代码清单 6-9 生成的 MyBackend_rm 和 MyBackend_rr 记录示例**

```text
------------- Classes -----------------
class Instr<bits<4> Instr:op = { ?, ?, ?, ? }, string Instr:desc = ?> {
    bits<4> opcode = { Instr:op{3}, Instr:op{2}, Instr:op{1}, Instr:op{0} };
    string name = Instr:desc;
}
------------- Defs -----------------
def MyBackend_rm {     // RegInstr
    bits<4> opcode = { 0, 0, 0, 0 };
    string nameDes = "rm";
}
def MyBackend_rr {     // RegInstr
    bits<4> opcode = { 1, 1, 1, 1 };
    string nameDes = "rr";
}
```

注 意 llvm-tblgen 在输出记录时并没有显式地展开（即未拆分）multiclass。

本节仅简单示范了 def、class、multiclass、defm 的使用，并未介绍更高级的语法的应用。希望通过本节的介绍，读者能够读懂 TD 文件，知道如何从 TD 文件生成对应的记录。关于 TableGen 还有很多内容，限于篇幅无法在本书中展开介绍，如文法的定义、使用方式等，以及一些高级功能（如 foreach、defvar、defset、assert 等语法），读者可参考官网深入了解 TableGen。

## 6.2 TableGen 工具链

LLVM 提供的工具 llvm-tblgen 可将 TD 文件转换成和 LLVM 框架配合的 C++ 代码，整个转换过程实际分成两步。

1）将 TD 文件转换成记录，llvm-tblgen 处理该过程的部分也称为工具链前端。

2）对记录中的信息进行抓取、分析和组合以生成 inc 头文件，通常和 LLVM 框架配合使用。llvm-tblgen 处理该过程的部分也称为工具链后端。需要注意的是，后端的选型完全是领域相关的，用什么后端完全由开发者定义。目前常见的后端可以分为以下 3 种。

<!-- PDF page 91; printed page 78 -->

① LLVM 后端：解析记录以生成与架构相关的一些信息，如描述架构寄存器和指令信息的头文件，或用于指导代码生成、指令选择的代码片段。

② Clang 后端：解析记录以生成与架构无关的一些信息，如语法树的信息、诊断信息、类属性等。

③ 通用后端：该后端对记录进行简单的处理，而不对记录中的具体内容进行解析，比如打印条目信息、可搜索表信息（如 AArch64 架构生成的系统寄存器表）。

llvm-tblgen 工具链工作流程示意图如图 6-1 所示。

![图 6-1 llvm-tblgen 工具链工作流程示意图](assets/figures/p091-6-1.png)

**图 6-1 llvm-tblgen 工具链工作流程示意图**

实际上现在 TD 的使用场景已经不局限于上面介绍的 3 种后端，其适用范围越来越广，比如 MLIR 也是基于 TD 文件设计方言（dialect）、算子（operator）等关键信息，当然 MLIR也需要实现自己的后端，以生成自己所需要的内容。

下面以 BPF 后端为例介绍如何通过 TD 文件生成和 LLVM 框架匹配的代码。

### 6.2.1 从 TD 定义到记录

如前所述，TableGen 前端解析 TD 文件后就可以得到记录。因为 LLVM 支持多种后端，所以在设计 TD 文件的记录类时又进行了抽象，将记录类分成：适用于所有后端的基类记录类、适用于某一后端的派生记录类。下面以加法指令 add 的定义为例进行介绍。首先定义

<!-- PDF page 92; printed page 79 -->

指令基类，然后定义指令的派生类，最后定义具体的指令，如代码清单 6-10 所示。

**代码清单 6-10 BPF 中 add 指令相关的 TD 描述**

```text
//基类记录类，适用于所有后端。该类的目的是设计指令的编码方式，比如指令占用多少位
class InstructionEncoding {
    int Size;

    ……
}
//指令派生类，适用于所有后端。该记录类定义了指令公共属性，比如对应的操作数、操作码、对应的汇编信息等
//该基类还有一些扩展信息，主要用于和编译器后端配合，比如说明指令是否属于“伪指令”、是否可以交换
//操作数（用于优化）、是否允许使用快速指令选择算法等信息
class Instruction : InstructionEncoding {
    string Namespace = "";
    string AsmString = "";

    ……
}
// BPF后端指令基类，该记录类定义了BPF后端指令的公共信息，比如指令为64位，64位指令的划分等
class InstBPF<dag outs, dag ins, string asmstr, list<dag> pattern>
    : Instruction {
    field bits<64> Inst;

    .……
}
// BPFALU、JMP指令基类在BPF后端的指令为64位，而64位的最低8位可以标记指令的类型，
//按照BPF后端约定，ALU和JMP指令同属于一个类型，具体参考附录B
class TYPE_ALU_JMP<bits<4> op, bits<1> srctype,
                   dag outs, dag ins, string asmstr, list<dag> pattern>
    : InstBPF<outs, ins, asmstr, pattern> {

    let Inst{63-60} = op;
    let Inst{59} = srctype;
}
//定义ALU操作基类：一个操作数为寄存器（R），另一个操作数为立即数（I）
class ALU_RI<BPFOpClass Class, BPFArithOp Opc,
             dag outs, dag ins, string asmstr, list<dag> pattern>
    : TYPE_ALU_JMP<Opc.Value, BPF_K.Value, outs, ins, asmstr, pattern> {
    bits<4> dst;
    bits<32> imm;

    let Inst{51-48} = dst;
    let Inst{31-0} = imm;
    let BPFClass = Class;
}
//定义ALU操作基类：一个操作数为寄存器（R），另一个操作数为立即数（R）
class ALU_RR<BPFOpClass Class, BPFArithOp Opc,
             dag outs, dag ins, string asmstr, list<dag> pattern>
    : TYPE_ALU_JMP<Opc.Value, BPF_X.Value, outs, ins, asmstr, pattern> {
    ……
```

<!-- PDF page 93; printed page 80 -->

```text
}
//使用multiclass定义一组ALU操作记录类，该类包含了32位和64位的记录以及两个操作数
//（分别使用寄存器、立即数），即共定义了4个记录类_rr、_ri_32、_ri、_32_ri
multiclass ALU<BPFArithOp Opc, string OpcodeStr, SDNode OpNode> {
    def _rr : ALU_RR<BPF_ALU64, Opc,
                       (outs GPR:$dst),
                       (ins GPR:$src2, GPR:$src),
                       "$dst "#OpcodeStr#" $src",
                       [(set GPR:$dst, (OpNode i64:$src2, i64:$src))]>;
      def _ri : ALU_RI<BPF_ALU64, Opc,
                       (outs GPR:$dst),
                       (ins GPR:$src2, i64imm:$imm),
                       "$dst "#OpcodeStr#" $imm",
                       [(set GPR:$dst, (OpNode GPR:$src2, i64immSExt32:$imm))]>;
    def _rr_32 : ALU_RR<BPF_ALU, Opc,
                       (outs GPR32:$dst),
                       (ins GPR32:$src2, GPR32:$src),
                       "$dst "#OpcodeStr#" $src",
                       [(set GPR32:$dst, (OpNode i32:$src2, i32:$src))]>;
    def _ri_32 : ALU_RI<BPF_ALU, Opc,
                       (outs GPR32:$dst),
                       (ins GPR32:$src2, i32imm:$imm),
                       "$dst "#OpcodeStr#" $imm",
                       [(set GPR32:$dst, (OpNode GPR32:$src2, i32immSExt32:$imm))]>;
}
//使用defm实例化ALU操作，例如实例化ADD操作，相当于生成了4个记录
//这里使用了let操作符，Constraints表示ADD指令允许交换两个操作数，IsAsCheapAsAMove表示
//指令成本比Move指令低。这两个属性用于后端代码优化，例如第10章会使用Constraints属性
let Constraints = "$dst = $src2" in {
let isAsCheapAsAMove = 1 in {
    defm ADD : ALU<BPF_ADD, "+=", add>;
    …
}
```

使用 llvm-tblgen 命令可以将上述相关 TD 文件转换成记录，BPF 相关信息定义在 BPF. td 文件中，相关命令如代码清单 6-11 所示（其中，your_dir 需要替换为你自己的目录名）。

**代码清单 6-11 使用 llvm-tblgen 命令将 TD 文件转换为记录**

```text
llvm-tblgen -I your_dir/llvm-project/llvm/include/ -I your_dir/llvm-project/llvm/
lib/Target/BPF --print-records your_dir/llvm-project/llvm/lib/Target/BPF/BPF.td
```

下面以 ADD_rr 为例展示生成的记录的部分片段，如代码清单 6-12 所示。

**代码清单 6-12 生成 ADD_rr 记录的代码片段**

```text
def ADD_rr {
    field bits<64> Inst = ...;
    int Size = 8;
    string DecoderNamespace = "BPF";
    list<Predicate> Predicates = [];
```

<!-- PDF page 94; printed page 81 -->

```text
    string DecoderMethod = "";
    bit hasCompleteDecoder = 1;
    string Namespace = "BPF";
    dag OutOperandList = (outs GPR:$dst);
    dag InOperandList = (ins GPR:$src2, GPR:$src);
    string AsmString = "$dst += $src";
    EncodingByHwMode EncodingInfos = ?;
    list<dag> Pattern = [(set GPR:$dst, (add i64:$src2, i64:$src))];
    list<Register> Uses = [];
    list<Register> Defs = [];
    int CodeSize = 0;
    int AddedComplexity = 0;
    ……
}

def ADD_rr_32 {
    ……
}

def ADD_ri {
    ……
}

def ADD_ri_32 {
    ……
}
```

可以看到 ADD_rr 定义了加法指令，它包含指令匹配模式（InOperandList）、指令匹配后的输出序列（OutOperandList）、指令匹配规则模板（Pattern）、对应的汇编代码（AsmString）等信息。

### 6.2.2 从记录到 C++ 代码

接下来需要对记录进一步处理，根据后端功能需要提取不同的信息。图 6-1 所示的后端功能非常多，不同功能需要的信息有所不同，这里以指令匹配为例介绍如何从记录提取指令匹配所需要的信息。

仍然以 BPF 后端为例，在使用 llvm-tblgen 工具时传入 -gen-dag-isel 参数，就可以生成指令选择相关信息。一般会生成专门的头文件来保存相关信息，例如 BPF 指令选择对应的头文件为 BPFGenDAGISel.inc。BPFGenDAGISel.inc 文件中最为重要的一部分内容是指令匹配表（MatcherTable），它描述了将 LLVM IR 匹配到特定后端架构指令的过程。指令匹配表中 ADD_rr 指令对应的指令匹配片段如代码清单 6-13 所示。

**代码清单 6-13 ADD_rr 指令对应的匹配片段**

```text
2449*/ /*SwitchOpcode*/ 83, TARGET_VAL(ISD::ADD),// ->2535
……
```

<!-- PDF page 95; printed page 82 -->

```text
/*  2473*/    OPC_MoveChild1,
/*  2474*/    OPC_CheckOpcode, TARGET_VAL(ISD::Constant),
……
/*  2481*/    OPC_MoveParent,
/*  2482*/    OPC_CheckType, MVT::i64,
……
/*  2497*/    OPC_MoveParent,
/*  2498*/    OPC_CheckType, MVT::i32,
……
```

第 7 章会介绍如何使用指令匹配表，这里暂不展开。我们先简单看一下如何从记录中

提取指令匹配信息。实际上这个过程的逻辑并不复杂，可以简单地总结为先从 ADD_rr 的记录中提取 Pattern 字段（list<dag> Pattern = [(set GPR:$dst, (add i64:$src2, i64:$src))];），然后对 Pattern 字段进行解析。根据该字段内容生成对应的匹配信息。例如，以上述 Pattern 字段中的 (add i64:$src2, i64:$src) 作为源模板，表示待匹配的中间表达式需要带有两个 64 位寄存器作为操作数的 ISD::ADD 节点（ISD::ADD 节点包含在 add 指令的定义中）。如果待匹配的中间表达式为 i64:$temp = (add i64:$src2, i64:$src)，则 (set GPR:$dst, i64:$temp) 为相应的匹配结果，表示将 i64 类型的 $temp 结果存放到 GPR 类型的寄存器中。相应地，该待匹配中间表达式可以被映射为 ADD_rr 指令，其输出为 $dst，输入为 $src2 和 $src。匹配过程示意图如图 6-2 所示。

![图 6-2 ADD_rr 记录匹配过程示意图](assets/figures/p095-6-2.png)

**图 6-2 ADD_rr 记录匹配过程示意图**

TableGen 工具链根据对上述 Pattern 的解释来生成对应的匹配规则信息，在生成匹配信息时还需要对操作符、操作数的类型进行约束，只有类型相同才能匹配（如 OPC_ CheckType, MVT::i64 描述的就是类型的约束），最后得到如代码清单 6-13 所示的匹配表。

虽然生成指令匹配表的逻辑比较简单，但是匹配表的细节非常多，不仅需要考虑匹配能否成功，还需要考虑匹配性能（如何布局不同匹配路径的顺序、当前匹配失败后如何快速

<!-- PDF page 96; printed page 83 -->

跳转到下一条匹配路径等），这个过程非常琐碎，我们不再介绍。如果读者感兴趣，可以参考相关源码。这里读者只需要了解从记录的相关字段生成匹配表的过程即可。

## 6.3 扩展阅读：如何在 TD 文件中定义匹配

6.2 节通过 ADD_rr 指令演示了在定义记录时指定指令的匹配规则，进而生成匹配表的过程。但是实际情况往往会更为复杂。例如在需要了解输入参数情况才能进行指令匹配的场景，就无法使用上述方案。在 LLVM 的 TD 文件中也可以看到有很多关于匹配的实现，比如 Pat、ComplexPattern、PatLeaf、PatFrag 等定义记录类，这些匹配记录类和指令中的直接匹配规则一起构成了指令选择中的匹配规则。在这 4 个记录类中，Pat 和 ComplexPattern会直接生成匹配规则，而 PatLeaf 和 PatFrag 主要用于在 TD 文件中快速写匹配规则。下面简单介绍通过 Pat 实现的隐式定义匹配模块，通过 ComplexPattern 定义的复杂匹配模板以及匹配规则支撑类。

### 6.3.1 隐式定义匹配模板

在 BPF 后端的指令选择阶段，LLVM IR 中的 call 指令首先被转换为 BPFcall 节点（BPFcall 是一个特殊的 SNDode，转换细节参见第 7 章）。指令选择就是指从 BPFcall 节点转换到 JAX 和 JAXL 的过程，该过程通常是通过匹配规则实现的。鉴于 call 指令需要转换为两条不同的后端指令，常见的做法是定义两条匹配规则，分别生成相应的后端指令。匹配规则中只有参数类型不同，其他信息都是一致的。为此 LLVM 社区提供了可以提取公共的匹配规则（即将要介绍的 Pat 记录类）的方法，以将存在差异的部分抽象出来，从而简化了指令的匹配定义的过程。BPFcall 节点匹配模板定义如代码清单 6-14 所示。

**代码清单 6-14 BPFcall 节点匹配模板定义**

```text
def : Pat<(BPFcall imm:$dst), (JAL imm:$dst)>;
def : Pat<(BPFcall GPR:$dst), (JALX GPR:$dst)>;
```

**代码清单 6-14 定义了针对 BPFcall 节点的匹配规则，当 BPFcall 的目的地址为立即数**

时，将其匹配为 JAL 指令；当 BPFcall 的目的地址为通用寄存器类型（GPR）时，将其匹配为 JALX 指令。其中，Pat 是匹配记录，它的定义非常简单，如代码清单 6-15 所示。

**代码清单 6-15 Pat 定义**

```text
class Pattern<dag patternToMatch, list<dag> resultInstrs> {
    dag PatternToMatch = patternToMatch;
    list<dag> ResultInstrs = resultInstrs;
    list<Predicate> Predicates = [];
    int AddedComplexity = 0;
}
```

<!-- PDF page 97; printed page 84 -->

```text
class Pat<dag pattern, dag result> : Pattern<pattern, [result]>;
```

从 Pat 的定义来看，它接收两个参数：第一个参数（输入）表示待匹配的形式；第二个参数（输出）表示匹配后的指令形式。

那如何生成匹配表？实际上也非常简单，TableGen 工具链在遇到使用 def : Pat 定义的记录时，会生成一个匿名的记录，其中 PatternToMatch 字段是待匹配信息，ResultInstrs 是输出信息，然后工具链后端从记录中抓取相关信息，从而生成匹配信息。例如在代码清单 6-14中，两个 def : Pat 定义的记录实际会生成两个匿名类。隐式模板如代码清单 6-16 所示。

**代码清单 6-16 隐式模板**

```text
def anonymous_3928 {
    dag PatternToMatch = (BPFcall imm:$dst);
    list<dag> ResultInstrs = [(JAL imm:$dst)];
    list<Predicate> Predicates = [];
    int AddedComplexity = 0;
}
def anonymous_3929 {
    dag PatternToMatch = (BPFcall GPR:$dst);
    list<dag> ResultInstrs = [(JALX GPR:$dst)];
    list<Predicate> Predicates = [];
    int AddedComplexity = 0;
}
```

它们都有一个字段 PatternTomatch 用于匹配信息的生成（imm 表示立即数，GPR 表示通用寄存器），而 TableGen 后端处理则和 6.2.2 节内容相同。

### 6.3.2 复杂匹配模板

TableGen 的语言描述能力不是万能的，比如它无法区分数值和地址。当遇到一些访存相关的 LLVM IR 时，就无法正确进行指令匹配，所以 TableGen 提供了一种方法，允许开发者在 TD 文件中编写 C++ 代码，直接和 LLVM 框架配合，按照这种方式实现的匹配规则称为复杂模式（ComplexPattern）匹配。

以 LLVM IR 中的 load 指令为例，它的语义非常丰富，支持从各种源（例如栈、全局地址等）加载数据。后端无法通过简单的指令描述或者隐式匹配来实现指令匹配，一种合适的方式是在 load 指令中对不同的源进行特殊处理，所以 LLVM 提供了 SelectAddr 函数（C++编写）来处理不同的源。SelectAddr 函数的定义如代码清单 6-17 所示。

**代码清单 6-17 SelectAddr 函数的定义**

```text
bool BPFDAGToDAGISel::SelectAddr(SDValue Addr, SDValue &Base, SDValue &Offset)
    {
    ……
    }
```

<!-- PDF page 98; printed page 85 -->

接下来的问题是如何把这个函数和指令匹配过程结合起来，这个时候就用到了ComplexPattern。例如，BPF 后端中定义了一个特殊的记录 ADDRri，将所有和源相关的工作都委托到 SelectAddr 函数中实现。ADDRri 的定义如代码清单 6-18 所示。

**代码清单 6-18 ADDRri 的定义**

```text
def ADDRri : ComplexPattern<i64, 2, "SelectAddr", [], []>;
```

ADDRri 经过 TableGen 工具解析后得到的记录如代码清单 6-19 所示。

**代码清单 6-19 ADDRri 经过 TableGen 工具解析后得到的记录**

```text
def ADDRri {
    ValueType Ty = i64;
    int NumOperands = 2;
    string SelectFunc = "SelectAddr";
    list<SDNode> RootNodes = [];
    list<SDNodeProperty> Properties = [];
    int Complexity = -1;
}
```

可以看到 ADDRri 记录中有一个字段为 SelectFunc（它的值本质上是一个函数指针），只要在匹配表生成的过程中提取该字段，并且保留相关信息，最后在匹配时就可以使用了。

接下来就是如何使用 ADDRri 这个记录，因为它可以被视为 dag 类型，所以可以直接出现在其他的记录中。例如 BPF 后端定义的 LDW 记录就可以使用 ADDRri 作为其模板中的源操作数，如代码清单 6-20 所示。

**代码清单 6-20 BPF 后端定义的 LDW 记录**

```text
class LOADi64<BPFWidthModifer SizeOp, string OpcodeStr, PatFrag OpNode>
: LOAD<SizeOp, OpcodeStr, [(set i64:$dst, (OpNode ADDRri:$addr))]>;
def LDW : LOADi64<BPF_W, "u32", zextloadi32>;
```

可以看到 LDW 使用了 ADDRri 记录，经过 TableGen 工具链的解析，最终得到的 LDW记录如代码清单 6-21 所示。

**代码清单 6-21 解析后得到的 LDW 记录**

```text
def LDW {
    string Namespace = "BPF";
    dag OutOperandList = (outs GPR:$dst);
    dag InOperandList = (ins MEMri:$addr);
    string AsmString = "$dst = *(u32 *)($addr)";
    list<dag> Pattern = [(set i64:$dst, (zextloadi32 ADDRri:$addr))];
}
```

可以看到，LDW 记录本身的匹配模式（字段 Pattern）包含了 ADDRri 记录，而 ADDRri又使用了字段 SelectFunc 将其工作委托到对应的 C++ 函数中，在匹配表生成时需要把这些

<!-- PDF page 99; printed page 86 -->

信息提取出来，然后在对应框架中调用函数指针 SelectAddr 即可。

### 6.3.3 匹配规则支撑类

LLVM 提供了 PatLeaf 和 PatFrag 支撑类的实现，开发者可以利用它们快速编写匹配规则。例如前面的 LOADi64 记录使用了 PatFrag（dag 的操作码）匹配过程中需要用到一些公共的匹配能力的抽象，定义为 PatFrag 后可以在多个记录中使用，例如在多条记录中都可以使用 ADDRri。

而 PatLeaf 描述的是特殊匹配节点（叶子节点），它没有操作数。这样的节点只能被其他匹配记录使用，而不能使用其他的记录。

注 LLVM 中的 TableGen 和 GCC 的 MD（Machine Description，机器描述）都是目标

意

描述语言，它们有非常多的相似之处。例如，它们都包含指令选择相关的模板、都

包含目标指令对应的汇编、都包含了调度相关的指令延迟等信息。它们区别在于，

MD 文件中不包含寄存器和指令编码等信息，这意味着如果使用 MD 文件来定义一

个编译器后端信息，GCC 只能将源码文件编译、生成文本汇编格式，开发者需要自

行开发一套汇编器，再根据自定义的编码表将文本汇编文件转换成二进制文件。

## 6.4 本章小结

本章对目标描述语言进行了简单的介绍，涵盖从目标描述语言到记录，再到 C++ 代码的生成过程。通过本章介绍希望读者可以了解目标描述语言和 LLVM 框架如何配合工作的。

本章最后对 LLVM 通过目标描述语言定义的模式匹配进行了总结，它们决定了如何生成匹配表，而匹配表是指令选择的基础。
