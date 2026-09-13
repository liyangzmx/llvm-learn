irdl.dialect @overlap {
  irdl.operation @test {
    %t = irdl.any
    %v = irdl.base "!builtin.vector"
    %either = irdl.any_of(%t, %v)
    irdl.operands(%either)
    irdl.results(%t)
  }
}
