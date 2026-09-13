define i32 @graph7(i1 %a, i1 %b) {
n1:
  br i1 %a, label %n2, label %n5
n2:
  br i1 %b, label %n3, label %n4
n3:
  br label %n6
n4:
  br label %n6
n5:
  br label %n7
n6:
  br label %n7
n7:
  ret i32 0
}
