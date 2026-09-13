// Appended to the chapter's sum and two sorting implementations by runner.py.
void swap(int *a, int *b) { int t=*a; *a=*b; *b=t; }
int main(void) {
    int a[8]={7,-2,7,0,-9,1,3,1};
    int b[8]={7,-2,7,0,-9,1,3,1};
    int expected[8]={-9,-2,0,1,1,3,7,7};
    if (sum()!=45) return 1;
    bubbleSort(a,8); bubbleSortInline(b,8);
    for (int i=0;i<8;i++) if(a[i]!=expected[i] || b[i]!=expected[i]) return 2;
    bubbleSort(a,0); bubbleSort(a,1);
    bubbleSortInline(b,0); bubbleSortInline(b,1);
    for (int i=0;i<8;i++) if(a[i]!=expected[i] || b[i]!=expected[i]) return 3;
    return 0;
}
