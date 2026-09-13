.text
.globl encoding
encoding:
  r0 = r1
  *(u32 *)(r10 - 8) = r2
  *(u32 *)(r10 - 4) = r0
  r2 <<= 32
  r3 = 0x1122334455667788 ll
  exit
