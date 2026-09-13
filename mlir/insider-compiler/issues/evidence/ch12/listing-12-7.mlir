// pdl.pattern 对应一份匹配与重写模式。
pdl.pattern : benefit(1) {
  // 用 pdl.type 描述结果类型，并约束输入值也具有同一类型。
  %resultType = pdl.type
  %inputOperand = pdl.operand : %resultType
  %root = pdl.operation "foo.op"(%inputOperand : !pdl.value)
    -> (%resultType : !pdl.type)
  pdl.rewrite %root {
    pdl.replace %root with (%inputOperand : !pdl.value)
  }
}
