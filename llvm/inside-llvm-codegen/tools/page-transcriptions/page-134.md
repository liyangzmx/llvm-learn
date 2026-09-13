**图 7-25 ADD 指令匹配过程对应的 DFA 示意图（图中文字转写）**

> 本页没有普通正文，原图为横排流程图。以下转写原图的路径与标签，不在原文中纠正匹配次序或 `rr` / `ri` 标签。

1. 开始 → ISD::ADD → `/*2452*/ OPC_Scope` → `OPC_RecordNode` → `OPC_CheckType` → `OPC_CheckComplexPat` → 成功：BPF::FI_ri。
2. 上述匹配失败 → `/*2468*/ OPC_Scope` → `OPC_RecordChild0` → `OPC_RecordChild1` → 匹配 ri。
3. 匹配 ri 失败 → 匹配 ADD_rr → 成功：BPF::ADD_rr；失败 → 匹配 ADD_rr_32 → 成功：BPF::ADD_rr_32；失败 → 匹配失败。
4. 匹配 ri 成功 → 匹配 ADD_ri → 原图成功终点标签为 BPF::ADD_rr；失败 → 匹配 ADD_ri_32 → 成功：BPF::ADD_ri_32；失败 → 匹配失败。
5. 图中 OPC_RecordChild0 / OPC_RecordChild1 附近还画有通向“匹配失败”的失败路径。
