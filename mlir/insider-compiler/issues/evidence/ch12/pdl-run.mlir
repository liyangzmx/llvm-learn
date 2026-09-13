module @patterns {
pdl.pattern : benefit(1) {
  %resultType = pdl.type
  %inputOperand = pdl.operand : %resultType
  %root = pdl.operation "foo.op"(%inputOperand : !pdl.value) -> (%resultType : !pdl.type)
  pdl.rewrite %root {
    pdl.replace %root with (%inputOperand : !pdl.value)
  }
}
}
module @ir {
  func.func @identity(%a: i32) -> i32 {
    %b = "foo.op"(%a) : (i32) -> i32
    return %b : i32
  }
}
