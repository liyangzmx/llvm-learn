import triton
import triton.language as tl


@triton.jit
def add_kernel(
    x_ptr,                     # 第一个输入向量的指针
    y_ptr,                     # 第二个输入向量的指针
    output_ptr,                # 输出向量的指针
    n_elements,                # 向量元素总数
    BLOCK_SIZE: tl.constexpr,  # 每个 program 实例处理的元素数
                              # constexpr 表示编译期已知的值，也可表达形状参数
):
    pid = tl.program_id(axis=0)  # 本例使用一维启动网格
    block_start = pid * BLOCK_SIZE
    offsets = block_start + tl.arange(0, BLOCK_SIZE)
    mask = offsets < n_elements
    x = tl.load(x_ptr + offsets, mask=mask)
    y = tl.load(y_ptr + offsets, mask=mask)
    output = x + y
    tl.store(output_ptr + offsets, output, mask=mask)
