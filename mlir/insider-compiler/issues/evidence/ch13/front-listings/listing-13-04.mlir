tt.func public @asm_in_loop(%arg0: !tt.ptr<bf16> {tt.divisibility = 16 : i32})
    attributes {noinline = false} {
  %c0_i32 = arith.constant 0 : i32
  %c1_i32 = arith.constant 1 : i32
  %c0_i64 = arith.constant 0 : i64
  %c128_i64 = arith.constant 128 : i64
  // 生成 0 至 15 的 i32 元素，start 包含在内，end 不包含在内。
  %0 = tt.make_range {end = 16 : i32, start = 0 : i32} : tensor<16xi32>
  // 基址、父张量形状、步长、偏移，以及 order 属性。
  // 此例第二维步长为 0，两个偏移也都为 0，不是通常的稠密二维存储。
  %1 = tt.make_tensor_ptr %arg0, [%c128_i64, %c128_i64],
      [%c128_i64, %c0_i64], [%c0_i32, %c0_i32] {order = array<i32: 0, 1>}
      : <tensor<128x128xbf16>>
  %2:1 = scf.for %arg1 = %c0_i32 to %c1_i32 step %c1_i32
      iter_args(%arg2 = %1) -> (!tt.ptr<tensor<128x128xbf16>>) : i32 {
    // 汇编文本是测试占位符，不是可交给 PTX 汇编器执行的真实指令。
    %3:2 = tt.elementwise_inline_asm "asm_multiple_results"
        {constraints = "=r,=r,r", packed_element = 1 : i32, pure = true}
        %0 : tensor<16xi32> -> tensor<16xi16>, tensor<16xi16>
    // 以各维偏移更新张量指针；本例两个增量都是 0。
    %4 = tt.advance %arg2, [%c0_i32, %c0_i32] : <tensor<128x128xbf16>>
    scf.yield %4 : !tt.ptr<tensor<128x128xbf16>>
  }

  tt.return
}
