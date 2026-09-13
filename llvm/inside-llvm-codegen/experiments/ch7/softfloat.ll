; Variable divisor avoids folding division by a constant into multiplication.
define double @divide(double %x, double %y) {
entry:
  %r = fdiv double %x, %y
  ret double %r
}
