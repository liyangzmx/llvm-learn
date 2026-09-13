// Analysis fixture. Caller must provide symbols and dimensions making every
// access in bounds; no numerical execution is performed by this verification.
func.func @access(%m: memref<?x?xf32>, %v0: f32, %M: index, %N: index, %K: index) {
  affine.for %i0 = 0 to 100 {
    affine.for %i1 = 0 to 50 {
      %a00 = affine.apply affine_map<(d0, d1)[s0, s1] -> (d0 * 2 - d1 * 4 + s1)>(%i0, %i1)[%M, %N]
      %a01 = affine.apply affine_map<(d0, d1)[s0, s1] -> (d1 * 3 - s0)>(%i0, %i1)[%M, %N]
      affine.store %v0, %m[%a00, %a01] : memref<?x?xf32>
    }
  }
  affine.for %i2 = 0 to 100 {
    affine.for %i3 = 0 to 50 {
      %a10 = affine.apply affine_map<(d0, d1)[s0, s1] -> (d0 * 7 + d1 * 9 - s1)>(%i2, %i3)[%K, %M]
      %a11 = affine.apply affine_map<(d0, d1)[s0, s1] -> (d1 * 11 + s0)>(%i2, %i3)[%K, %M]
      %v1 = affine.load %m[%a10, %a11] : memref<?x?xf32>
    }
  }
  return
}
