func.func @mul(%a: !cmath.complex<f32>, %b: !cmath.complex<f64>) -> !cmath.complex<f32> {
  %r = "cmath.mul"(%a, %b) : (!cmath.complex<f32>, !cmath.complex<f64>) -> !cmath.complex<f32>
  return %r : !cmath.complex<f32>
}
