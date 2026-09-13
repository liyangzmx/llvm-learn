// Teaching example: the inner transpose has another live user.
// Inspect with toyc-ch3 -emit=mlir, then with -emit=mlir -opt.
// Expected from source semantics: remove the outer transpose only.
// This example has not been executed in this documentation task.
module {
  toy.func @main() {
    %a = toy.constant dense<[[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]]> : tensor<2x3xf64>
    %inner = toy.transpose(%a : tensor<2x3xf64>) to tensor<3x2xf64>
    %outer = toy.transpose(%inner : tensor<3x2xf64>) to tensor<2x3xf64>
    toy.print %inner : tensor<3x2xf64>
    toy.print %outer : tensor<2x3xf64>
    toy.return
  }
}
