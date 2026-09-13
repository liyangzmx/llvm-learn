// 外层归纳变量 %i0 的取值为 0～99。
affine.for %i0 = 0 to 100 {
  // 内层归纳变量 %i1 的取值为 0～49。
  affine.for %i1 = 0 to 50 {
    // AccessMap 以归纳变量和符号为输入，给出两个访问坐标：
    // a00 = 2*i0 - 4*i1 + N；a01 = 3*i1 - M。
    %a00 = affine.apply affine_map<(d0, d1)[s0, s1] ->
        (d0 * 2 - d1 * 4 + s1)>(%i0, %i1)[%M, %N]
    %a01 = affine.apply affine_map<(d0, d1)[s0, s1] ->
        (d1 * 3 - s0)>(%i0, %i1)[%M, %N]
    // 向 %m 的指定坐标写入数据。
    affine.store %v0, %m[%a00, %a01] : memref<?x?xf32>
  }
}
