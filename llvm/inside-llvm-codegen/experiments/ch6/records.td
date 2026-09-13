def record_example {
  int a = 1;
  string b = "def example";
}
class TestInst {
  string asmname;
  bits<32> encoding;
}
def ADD : TestInst {
  let asmname = "add";
  let encoding{31...26} = 1;
}
def MUL : TestInst {
  let asmname = "mul";
  let encoding{31...26} = 2;
}
