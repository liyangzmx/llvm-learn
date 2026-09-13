// The original A-1 attribute fragments placed in a module for parsing.
// Target system/device/map attributes are absent from the checked LLVM 18 tree.
module attributes {
  dlti.dl_spec = #dlti.dl_spec<
    #dlti.dl_entry<!llvm.ptr, dense<64> : vector<4xi64>>,
    #dlti.dl_entry<"dlti.endianness", "little">,
    #dlti.dl_entry<"dlti.stack_alignment", 128 : i64>>,
  dlti.target_system_spec = #dlti.target_system_spec<
    "CPU" = #dlti.target_device_spec<
      "cache" = #dlti.map<"L1" = #dlti.map<"size_in_bytes" = 65536 : i32>,
                          "L1d" = #dlti.map<"size_in_bytes" = 32768 : i32>>>,
    "GPU" = #dlti.target_device_spec<"max_vector_op_width" = 64 : ui32>,
    "XPU" = #dlti.target_device_spec<"max_vector_op_width" = 4096 : ui32>>
} {}
