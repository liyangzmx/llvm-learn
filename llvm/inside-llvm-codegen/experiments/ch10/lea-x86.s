.text
.globl lea_demo
lea_demo:
  leal (%rsi,%rdi), %eax
  ret
