**图 7-26 callee 指令匹配后的 DAG（图中文字转写）**

> 本页没有普通正文。以下转写原图标签；原图 `EntryToken` 标注 ch、glue，保持原样。

| 节点 | 操作或标签 | 输出类型 |
|---|---|---|
| t0 | EntryToken | ch, glue |
| t1 | Register %0 | i64 |
| t2 | CopyFromReg | i64, ch |
| t3 | Register %1 | i64 |
| t4 | CopyFromReg | i64, ch |
| t8 | STD<Mem:(store (s64) into %ir.a.addr)> | ch |
| t10 | STD<Mem:(store (s64) into %ir.b.addr)> | ch |
| t11 | LDD<Mem:(dereferenceable load (s64) from %ir.a.addr)> | i64, ch |
| t12 | LDD<Mem:(dereferenceable load (s64) from %ir.b.addr)> | i64, ch |
| t13 | ADD_rr nsw | i64 |
| t15 | TokenFactor | ch |
| t16 | STD<Mem:(store (s64) into %ir.c)> | ch |
| t17 | LDD<Mem:(dereferenceable load (s64) from %ir.c)> | i64, ch |
| t18 | Register $r0 | i64 |
| t19 | CopyToReg | ch, glue |
| t20 | RET | ch |
| t21 | TargetFrameIndex <2> | i64 |
| t22 | TargetConstant <0> | i64 |
| t23 | TargetFrameIndex <0> | i64 |
| t24 | TargetFrameIndex <1> | i64 |
| — | GraphRoot | — |

相对图 7-15，store / load / add / 返回节点分别选成 STD / LDD / ADD_rr / RET，FrameIndex 选成 TargetFrameIndex，地址偏移使用 TargetConstant <0>。图中其余 CopyFromReg、CopyToReg、TokenFactor 和相关 chain / glue 边仍然保留。机器 store 的输入顺序为值、地址、偏移、chain；机器 load 的输入顺序为地址、偏移、chain；图中的 RET 输入顺序为返回寄存器、chain、glue。
