import torch
from _typeshed import Incomplete

class ReLUNet(torch.nn.Module):
    fc1: Incomplete
    fc2: Incomplete
    fc3: Incomplete
    action_size: Incomplete
    def __init__(self, ndim: int) -> None: ...
    def forward(self, x: torch.Tensor) -> torch.Tensor: ...

class DTAMERLoss(torch.nn.Module):
    actionsize: Incomplete
    def __init__(self, actionsize: int) -> None: ...
    one_hot: Incomplete
    q: Incomplete
    error: Incomplete
    def forward(self, result: torch.Tensor, target: torch.Tensor, action: torch.Tensor, weights: Incomplete | None = None): ...

class BasicNN(torch.nn.Module):
    fc1: Incomplete
    fc2: Incomplete
    fc3: Incomplete
    def __init__(self, ndim: int) -> None: ...
    def forward(self, x: torch.Tensor) -> torch.Tensor: ...
