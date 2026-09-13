int add(int a, int b) { return a + b; }
int factor(int n) { int ret = 1; while (n > 1) { ret *= n; --n; } return ret; }
int choose(int x) { int y = 0; if (x > 42) y = 1; else y = x + 2; return y; }
int sum10(void) { int x = 0, y = 0; do { y += x; ++x; } while (x < 10); return y; }
int lost_copy(void) { int i = 0, t; do { t = i; ++i; } while (i < 10); return t + 1; }
int swap_problem(int n) {
  int x = 1, y = 2;
  for (int i = 0; i < n; ++i) { int temp = x; x = y; y = temp; }
  return x / y;
}
int pruned(int x) { int dead; if (x) dead = 1; else dead = 2; return 7; }
int main(void) {
  if (add(5, 7) != 12) return 1;
  if (factor(0) != 1 || factor(1) != 1 || factor(5) != 120) return 2;
  if (choose(42) != 44 || choose(43) != 1 || choose(-2) != 0) return 3;
  if (sum10() != 45 || lost_copy() != 10) return 4;
  if (swap_problem(0) != 0 || swap_problem(1) != 2 || swap_problem(2) != 0 || swap_problem(9) != 2) return 5;
  if (pruned(0) != 7 || pruned(1) != 7) return 6;
  return 0;
}
