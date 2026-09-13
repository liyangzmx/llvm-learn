# 附录 C 核查记录

LLVM 18.1.8 静态核查；未构建、未运行示例。

| 清单/位置 | 核查依据 | 结论与修正 |
| --- | --- | --- |
| C-1 | llvm/include/llvm/IR/PassManager.h；llvm/docs/WritingAnLLVMNewPMPass.rst | 原mixin不是CRTP，替换为真实PassInfoMixin形式示例；标注未编译/不完整程序 |
| C.1与脚注 | llc.cpp；LLVMTargetMachine.cpp；LoopPass.h:76 | no选项不能解释成启用；LLVM18后端仍legacy；Loop/SCC等含义修正 |
| C.2 | WritingAnLLVMPass.rst:757；LegacyPassManagers.h:219,457 | RequiredTransitive生命周期说明；真实MP/CG/FP/LP/RG继承；activeStack角色修正 |
| C.3 | NewPassManager.rst；PassManager.h:649 | AnalysisManager命名；PreservedAnalyses、缓存、跨层代理；CRTP并非全部动机 |

待后续：实际 IR/工具命令输出；C++ 片段的包含文件、调用上下文与构建验证尚未执行。

## 独立复核补充

| 检查点 | 依据与结论 |
|---|---|
| ModulePass/SCC契约 | `WritingAnLLVMPass.rst:340,374`：模块未必是全程序；不能优化的是执行调度空间，不是不能变换IR。SCC Pass可访问当前SCC及直接caller/callee，并需维护CallGraph。 |
| Module获取函数分析 | `PassAnalysisSupport.h:260`：`getAnalysis<Wrapper>(Function&)`形式正确；补依赖声明和有效函数定义前提。 |
| PHI分析依赖 | `PHIElimination.cpp:137`：LiveVariables为addUsedIfAvailable；SlotIndexes/LiveIntervals被保留，不等于强制addRequired。修正正文误述。 |
| Preserved语义 | `PassAnalysisSupport.h:130,142`、`MachineFunctionPass.cpp:168`：保留表示结果有效，可增量维护，并非字段不变；机器CFG同受preservesCFG约束。 |
| CRTP与运行分派 | `PassManager.h:391`、`PassManagerInternal.h:70`：清单C-1确为PassInfoMixin的CRTP形式；运行采用模板/类型擦除，继承关系表保持正确。 |
| 懒分析与流水线 | `PassManager.h:649`：变换Pass顺序仍由流水线安排；分析依赖、invalidate和跨层代理继续存在，不能概括为新PM取消依赖。 |

示例 C-1 仅静态核对 API，尚未补插件注册或构建运行。
