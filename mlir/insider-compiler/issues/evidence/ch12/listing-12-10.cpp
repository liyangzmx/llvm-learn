namespace {
struct ReplaceTenWithEleven : ::mlir::PDLPatternModule {
  template <typename... ConfigsT>
  ReplaceTenWithEleven(::mlir::MLIRContext *context, ConfigsT &&...configs)
      : ::mlir::PDLPatternModule(
            ::mlir::parseSourceString<::mlir::ModuleOp>(
R"mlir(pdl.pattern @ReplaceTenWithEleven : benefit(0) {
  %0 = operands loc("replace.pdll":3:18)
  %1 = attribute = 10 : i32 loc("replace.pdll":3:46)
  %2 = types loc("replace.pdll":3:18)
  %3 = operation "arith.constant"(%0 : !pdl.range<value>) {"value" = %1}
    -> (%2 : !pdl.range<type>) loc("replace.pdll":3:18)
  rewrite %3 {
    %4 = attribute = 11 : i32 loc("replace.pdll":7:48)
    %5 = operation "arith.constant" {"value" = %4} loc("replace.pdll":7:20)
    replace %3 with %5 loc("replace.pdll":8:5)
  } loc("replace.pdll":6:3)
} loc("replace.pdll":1:1)
)mlir", context), std::forward<ConfigsT>(configs)...) {}
};
} // end namespace
