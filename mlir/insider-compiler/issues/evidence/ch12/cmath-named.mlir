irdl.dialect @cmath {
  irdl.type @complex {
    %0 = irdl.is f32
    %1 = irdl.is f64
    %2 = irdl.any_of(%0, %1)
    irdl.parameters(elem: %2)
  }
  irdl.operation @mul {
    %0 = irdl.is f32
    %1 = irdl.is f64
    %2 = irdl.any_of(%0, %1)
    %3 = irdl.parametric @cmath::@complex<%2>
    irdl.operands(args: %3, elem: %3)
    irdl.results(re: %3)
  }
}
