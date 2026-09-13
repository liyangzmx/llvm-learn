**图 7-15 callee 对应的 DAG 图（图中文字转写）**

> 本页没有普通正文。以下忠实转写图中节点文字，保留原图的 `EntryToken` 输出 glue、`RET_FLAG` 和 `%ir.c.addr` 等写法；这些写法是否正确在校订稿处理。

| 节点 | 操作或标签 | 输出类型 |
|---|---|---|
| t0 | EntryToken | ch, glue |
| t1 | Register %0 | i64 |
| t2 | CopyFromReg | i64, ch |
| t3 | Register %1 | i64 |
| t4 | CopyFromReg | i64, ch |
| t5 | FrameIndex <0> | i64 |
| t7 | undef | i64 |
| t8 | store<(store(s64) into %ir.a.addr)> | ch |
| t9 | FrameIndex <1> | i64 |
| t10 | store<(store (s64) into %ir.b.addr)> | ch |
| t11 | load<(dereferenceable load (s64) from %ir.a.addr)> | i64, ch |
| t12 | load<(dereferenceable load (s64) from %ir.b.addr)> | i64, ch |
| t13 | add nsw | i64 |
| t14 | FrameIndex <2> | i64 |
| t15 | TokenFactor | ch |
| t16 | store<(store (s64) into %ir.c)> | ch |
| t17 | load<(dereferenceable load (s64) from %ir.c.addr)> | i64, ch |
| t18 | Register $r0 | i64 |
| t19 | CopyToReg | ch, glue |
| t20 | BPFISD::RET_FLAG | ch |
| — | GraphRoot | — |

图中黑实线表示数据输入，蓝虚线表示 chain，蓝实线表示 glue。输入索引从 0 开始：t2=[t0,t1]；t4=[t0,t3]；t8=[t0,t2,t5,t7]；t10=[t8,t4,t9,t7]；t11=[t10,t5,t7]；t12=[t10,t9,t7]；t13=[t11,t12]；t15=[t11:ch,t12:ch]；t16=[t15,t13,t14,t7]；t17=[t16,t14,t7]；t19=[t16,t18,t17]；t20=[t19:ch,t18,t19:glue]。GraphRoot 指向 t20。
