int branch(void) { int t = 10, x; if (t*t >= 0) x=0; else x=1; return x; }
int loop(void) { int i=1, flag=0; while (i>0 && !flag) { if(i==1) flag=1; else ++i; } return i*10+flag; }
int relational(int c) { int x,y; if(c) { x=2; y=3; } else { x=3; y=2; } return x+y; }
int main(void) { return branch()!=0 || loop()!=11 || relational(0)!=5 || relational(1)!=5; }
