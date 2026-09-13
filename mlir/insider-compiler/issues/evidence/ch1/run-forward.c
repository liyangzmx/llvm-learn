#include <stdint.h>
#include <stdio.h>
#include <string.h>

/* Expanded rank-two memref ABI emitted by LLVM18 for complete-1-6.mlir. */
extern void forward(float *, float *, int64_t, int64_t, int64_t, int64_t, int64_t,
                    float *, float *, int64_t, int64_t, int64_t, int64_t, int64_t);
int main(void) {
  float input[16], output[10];
  for (int trial = 0; trial < 40; ++trial) {
    for (int k = 0; k < 16; ++k)
      input[k] = (float)((trial * 7 + k * 3) % 31 - 15) / 4.0f;
    for (int j = 0; j < 10; ++j) output[j] = 1234.0f;
    forward(input, input, 0, 1, 16, 16, 1,
            output, output, 0, 1, 10, 10, 1);
    for (int j = 0; j < 10; ++j) {
      float expected = (float)j / 4.0f - 1.0f;
      for (int k = 0; k < 16; ++k) {
        float weight = (float)((k * 3 + j * 5) % 17 - 8) / 8.0f;
        float product = input[k] * weight;
        expected = expected + product;
      }
      if (memcmp(&expected, &output[j], sizeof(float))) {
        fprintf(stderr, "trial=%d col=%d expected=%g actual=%g\n",
                trial, j, expected, output[j]);
        return 1;
      }
    }
  }
  puts("PASS: 40 inputs x 10 outputs; generated LLVM18 scalar kernel matches bias-first f32 reference.");
  return 0;
}
