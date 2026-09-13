int test(int n) { int a=1; for(int i=0;i<n;++i) a+=a*i; return a; }
int main(void) { return test(-1)!=1 || test(0)!=1 || test(1)!=1 || test(5)!=120 || test(8)!=40320 || test(12)!=479001600; }
