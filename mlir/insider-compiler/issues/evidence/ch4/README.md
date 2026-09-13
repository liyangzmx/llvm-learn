# 第 4 章验证输入

这些文件是章节校订时实际使用的验证输入，完整结论见[第 4 章校订记录](../../ch4.md)。生成结果和可执行文件放在临时目录，避免混入正文。以下命令从项目根目录执行：

```sh
mkdir -p /private/tmp/insider-ch4-reproduce
/opt/llvm-project/build/bin/mlir-tblgen \
  -I /opt/llvm-project/mlir/include --gen-op-interface-decls \
  mlir/insider-compiler/issues/evidence/ch4/CostInterface.td \
  -o /private/tmp/insider-ch4-reproduce/CostInterface.h.inc
/opt/llvm-project/build/bin/mlir-tblgen \
  -I /opt/llvm-project/mlir/include --gen-op-interface-defs \
  mlir/insider-compiler/issues/evidence/ch4/CostInterface.td \
  -o /private/tmp/insider-ch4-reproduce/CostInterface.cpp.inc
/usr/bin/clang++ -O2 -std=c++17 -fno-rtti \
  -I /private/tmp/insider-ch4-reproduce \
  -I /opt/llvm-project/mlir/include \
  -I /opt/llvm-project/build/tools/mlir/include \
  -I /opt/llvm-project/llvm/include \
  -I /opt/llvm-project/build/include \
  mlir/insider-compiler/issues/evidence/ch4/dispatch.cpp \
  -L /opt/llvm-project/build/lib \
  -lMLIRIR -lMLIRSupport -lLLVMSupport -lLLVMDemangle -lz -lcurses \
  -o /private/tmp/insider-ch4-reproduce/dispatch
/private/tmp/insider-ch4-reproduce/dispatch
```

预期输出：`PASS: direct Model=37, ExternalModel=41, duplicate ignored, explicit verify required`。

另外三类检查：

```sh
/opt/llvm-project/build/bin/mlir-tblgen \
  -I /opt/llvm-project/mlir/include --gen-op-defs \
  mlir/insider-compiler/issues/evidence/ch4/MyOperationOps.td \
  -o /private/tmp/insider-ch4-reproduce/MyOperationOps.cpp.inc
/opt/llvm-project/build/bin/mlir-tblgen \
  -I /opt/llvm-project/mlir/include \
  -I mlir/insider-compiler/issues/evidence/ch4 --gen-op-decls \
  mlir/insider-compiler/issues/evidence/ch4/UsageOps.td \
  -o /private/tmp/insider-ch4-reproduce/UsageOps.h.inc
/opt/llvm-project/build/bin/mlir-opt \
  mlir/insider-compiler/issues/evidence/ch4/valid.mlir
/opt/llvm-project/build/bin/mlir-opt \
  mlir/insider-compiler/issues/evidence/ch4/bad-add.mlir
```

最后一条是负例，应以非零退出并报告操作数及结果类型不一致。生成文件分别用于观察独立的 F16/F32/F64 检查，以及三种接口接入形式的方法声明；不能只用生成成功代替这些语义检查。
