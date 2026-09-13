func.func @poison() -> i32 {
  %value = ub.poison : i32
  return %value : i32
}
