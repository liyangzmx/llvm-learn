import torch
from torch import nn
import torch_mlir

class Linear(nn.Module):
    def __init__(self):
        super(Linear, self).__init__()
        self.linear = nn.Linear(16, 10)

    def forward(self, x):
        return self.linear(x)

linear = Linear()
mlir_module = torch_mlir.compile(
    linear, torch.ones(1, 16), output_type=torch_mlir.OutputType.TOSA
)
