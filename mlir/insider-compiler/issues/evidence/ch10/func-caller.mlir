func.func @my() { return }
func.func @caller() { func.call @my() : () -> () return }
