int dot4(const int *x, const int *y) {
  int a = x[0] * y[0];
  int b = x[1] * y[1];
  int c = x[2] * y[2];
  int d = x[3] * y[3];
  return a + b + c + d;
}
