int sum(int n) {
  int total = 0;
  for (int i = 0; i < n; ++i)
    total += i;
  return total;
}

int main(void) {
  return sum(10) == 45 ? 0 : 1;
}
