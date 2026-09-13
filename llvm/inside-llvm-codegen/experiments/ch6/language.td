class Instr<bits<4> op, string desc> {
  bits<4> opcode = op;
  string name = desc;
}
multiclass RegInstr {
  def rr : Instr<0b1111, "rr">;
  def rm : Instr<0b0000, "rm">;
}
defm MyBackend_ : RegInstr;

def op;
def leaf;
def Values {
  int negative = -42;
  int hexadecimal = 0x2A;
  int binary = 0b101010;
  bits<4> a = 0;
  let a{1...3} = 0b110;
  dag tree = (op leaf:$a, (op 1, 2):$b);
  int direct_arguments = !size(tree);
  list<int> xs = [10, 20, 30];
  list<int> slice = xs[2, 0];
  string joined = "12" # "ab";
  code body = [{
    return 1;
  }];
}
