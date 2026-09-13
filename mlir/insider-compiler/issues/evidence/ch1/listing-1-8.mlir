// 节选：函数签名、入口块和其他值的定义在原书中省略。
^bb1(%20: i64):  // 前驱：入口块和 ^bb4
  %21 = llvm.icmp "slt" %20, %5 : i64
  llvm.cond_br %21, ^bb2(%4 : i64), ^bb5
^bb2(%22: i64):  // 前驱：^bb1、^bb3
  %23 = llvm.icmp "slt" %22, %7 : i64
  llvm.cond_br %23, ^bb3, ^bb4
^bb3:  // 前驱：^bb2
  // 原书在此省略地址、掩码和向量操作数的准备过程。
  %46 = llvm.intr.masked.load %45, %36, %0 {alignment = 4 : i32} : (!llvm.ptr, vector<2xi1>, vector<2xf32>) -> vector<2xf32>
  %47 = llvm.fmul %30, %41 : vector<2xf32>
  %48 = llvm.fadd %46, %47 : vector<2xf32>
  llvm.intr.masked.store %48, %45, %36 {alignment = 4 : i32} : vector<2xf32>, vector<2xi1> into !llvm.ptr
  %49 = llvm.add %22, %8 : i64
  llvm.br ^bb2(%49 : i64)
^bb4:  // 前驱：^bb2
  %50 = llvm.add %20, %6 : i64
  llvm.br ^bb1(%50 : i64)
^bb5:  // 前驱：^bb1
  llvm.return
