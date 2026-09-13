func.func @trivial_ops(%a: index, %b: index) {
  %0 = index.add %a, %b
  return
}
