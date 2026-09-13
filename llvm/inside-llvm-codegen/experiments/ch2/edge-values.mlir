module {
  func.func @choose(%c: i1, %a: i32, %b: i32) -> i32 {
    cf.cond_br %c, ^join(%a : i32), ^join(%b : i32)
  ^join(%value: i32):
    return %value : i32
  }

  func.func @main() -> i32 {
    %true = arith.constant true
    %false = arith.constant false
    %one = arith.constant 1 : i32
    %two = arith.constant 2 : i32
    %zero = arith.constant 0 : i32
    %left = func.call @choose(%true, %one, %two) : (i1, i32, i32) -> i32
    %right = func.call @choose(%false, %one, %two) : (i1, i32, i32) -> i32
    %left_wrong = arith.cmpi ne, %left, %one : i32
    %right_wrong = arith.cmpi ne, %right, %two : i32
    %wrong = arith.ori %left_wrong, %right_wrong : i1
    %status = arith.select %wrong, %one, %zero : i32
    return %status : i32
  }
}
