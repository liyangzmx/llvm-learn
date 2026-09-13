define void @nested(i1 %outer, i1 %inner) {
entry:
  br label %outer.header
outer.header:
  br i1 %outer, label %inner.header, label %exit
inner.header:
  br i1 %inner, label %inner.latch, label %outer.latch
inner.latch:
  br label %inner.header
outer.latch:
  br label %outer.header
exit:
  ret void
}
