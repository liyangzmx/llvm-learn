// 定义一个函数，函数名为 my。
func.func @my() -> () {
  return
}

// 调用该函数的语法如下；实际程序中应放在调用者函数体内。
func.call @my() : () -> ()
