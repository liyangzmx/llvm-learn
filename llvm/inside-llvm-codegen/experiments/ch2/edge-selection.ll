define i32 @choose_edge(i1 %c) {
entry:
  %v = select i1 %c, i32 1, i32 2
  br label %join
join:
  %x = phi i32 [ %v, %entry ]
  ret i32 %x
}
define i32 @main() {
  %a = call i32 @choose_edge(i1 true)
  %b = call i32 @choose_edge(i1 false)
  %aok = icmp eq i32 %a, 1
  %bok = icmp eq i32 %b, 2
  %ok = and i1 %aok, %bok
  %exit = select i1 %ok, i32 0, i32 1
  ret i32 %exit
}
