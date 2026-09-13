pdl.pattern : benefit(1) {
  %resultType = pdl.type
  %inputOperand = pdl.operand : %resultType
  %root = pdl.operation "foo.op"(%inputOperand : !pdl.value) -> (%resultType : !pdl.type)
  pdl.rewrite %root {
    pdl.replace %root with (%inputOperand : !pdl.value)
  }
}
