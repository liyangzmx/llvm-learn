module {
  tt.func public @asm_in_loop(%arg0: !tt.ptr<bf16> {tt.divisibility = 16 : i32})
      attributes {noinline = false} {
    %c0_i32 = arith.constant 0 : i32
    %c1_i32 = arith.constant 1 : i32
    %c0_i64 = arith.constant 0 : i64
    %c128_i64 = arith.constant 128 : i64
    %0 = tt.make_range {end = 16 : i32, start = 0 : i32} : tensor<16xi32>
    %1 = arith.extsi %c0_i32 : i32 to i64
    %2 = arith.extsi %c0_i32 : i32 to i64
    %3:2 = scf.for %arg1 = %c0_i32 to %c1_i32 step %c1_i32
        iter_args(%arg2 = %1, %arg3 = %2) -> (i64, i64) : i32 {
      %4:2 = tt.elementwise_inline_asm "asm_multiple_results"
          {constraints = "=r,=r,r", packed_element = 1 : i32, pure = true}
          %0 : tensor<16xi32> -> tensor<16xi16>, tensor<16xi16>
      %5 = arith.extsi %c0_i32 : i32 to i64
      %6 = arith.addi %arg2, %5 : i64

      %7 = arith.extsi %c0_i32 : i32 to i64
      %8 = arith.addi %arg3, %7 : i64
      scf.yield %6, %8 : i64, i64
    }
    tt.return
  }
}
