func.func @arm_sme_load_tile(%src: memref<?x?xf16>,
                            %mask: vector<[8]xi1>,
                            %tile_slice_index: index) {
  %c0 = arith.constant 0 : index
  %tile = arm_sme.get_tile : vector<[8]x[8]xf16>
  %tile_update = arm_sme.load_tile_slice %src[%c0], %mask, %tile, %tile_slice_index
      : memref<?x?xf16>, vector<[8]xi1>, vector<[8]x[8]xf16>
  "test.some_use"(%tile_update) : (vector<[8]x[8]xf16>) -> ()
  return
}
