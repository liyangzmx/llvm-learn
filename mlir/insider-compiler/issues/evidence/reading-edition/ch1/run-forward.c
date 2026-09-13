#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include "validation-data.h"

/* Expanded rank-two memref ABI of the current listing 1-6. */
extern void forward(float *, float *, int64_t, int64_t, int64_t, int64_t, int64_t,
                    float *, float *, int64_t, int64_t, int64_t, int64_t, int64_t);

int main(void) {
  float input[16], output[10];
  int orderDifferences = 0;
  for (int trial = 0; trial < 80; ++trial) {
    /* First 40 retain the old input set. The next 40 amplify cancellation and
       rounding so this test distinguishes bias-last from bias-first. */
    float scale = trial < 40 ? 1.0f : 16777216.0f;
    for (int k = 0; k < 16; ++k)
      input[k] = (float)(((trial % 40) * 7 + k * 3) % 31 - 15) / 4.0f * scale;
    for (int j = 0; j < 10; ++j)
      output[j] = 1234.0f;
    forward(input, input, 0, 1, 16, 16, 1,
            output, output, 0, 1, 10, 10, 1);
    for (int j = 0; j < 10; ++j) {
      float expected = 0.0f;
      float biasFirst = validationBias[j];
      for (int k = 0; k < 16; ++k) {
        float product = input[k] * validationWeights[k][j];
        expected = expected + product;
        biasFirst = biasFirst + product;
      }
      expected = expected + validationBias[j];
      orderDifferences += memcmp(&expected, &biasFirst, sizeof(float)) != 0;
      if (memcmp(&expected, &output[j], sizeof(float))) {
        fprintf(stderr, "trial=%d col=%d expected=%a actual=%a\n",
                trial, j, (double)expected, (double)output[j]);
        return 1;
      }
    }
  }
  if (!orderDifferences) {
    fputs("FAIL: inputs did not distinguish bias order\n", stderr);
    return 1;
  }
  printf("PASS: 80 inputs x 10 outputs match zero-initialized, bias-last f32 reference; %d outputs distinguish the historical bias-first reference.\n",
         orderDifferences);
  return 0;
}
