include "mlir/Dialect/Arith/IR/ArithOps.td"
include "mlir/IR/PatternBase.td"
// 对两个 extui 或两个 extsi 的结果执行 and 时，可先对原始值执行 and：
// and(extui(x), extui(y)) -> extui(and(x, y))
// and(extsi(x), extsi(y)) -> extsi(and(x, y))
def AndOfExtUI :
    Pat<(Arith_AndIOp (Arith_ExtUIOp $x), (Arith_ExtUIOp $y)),
        (Arith_ExtUIOp (Arith_AndIOp $x, $y)),
        [(Constraint<CPred<"$0.getType() == $1.getType()">> $x, $y)]>;

def AndOfExtSI :
    Pat<(Arith_AndIOp (Arith_ExtSIOp $x), (Arith_ExtSIOp $y)),
        (Arith_ExtSIOp (Arith_AndIOp $x, $y)),
        [(Constraint<CPred<"$0.getType() == $1.getType()">> $x, $y)]>;
