#include <math.h>
#include <stdio.h>
int main(void) {
  volatile float x = 1.0e-8f;
  float accurate = log1pf(x);
  float expanded = logf(1.0f + x);
  printf("x=%.9g log1pf(x)=%.9g logf(1+x)=%.9g\n", x, accurate, expanded);
  return !(accurate != 0.0f && expanded == 0.0f);
}
