# flake8: noqa: E501
import torch
import torch.nn.functional as F


class ReLUNet(torch.nn.Module):
    def __init__(self, ndim: int):
        super(ReLUNet, self).__init__()
        hls = ndim * 10
        self.fc1 = torch.nn.Linear(ndim, hls)
        self.fc2 = torch.nn.Linear(hls, hls)
        self.fc3 = torch.nn.Linear(hls, 2 * ndim)
        self.action_size = 2 * ndim

        # torch.nn.init.trunc_normal_(self.fc1.weight, std=0.3, a=-0.6, b=0.6)
        # torch.nn.init.trunc_normal_(self.fc2.weight, std=0.3, a=-0.6, b=0.6)
        # torch.nn.init.trunc_normal_(self.fc3.weight, std=0.3, a=-0.6, b=0.6)
        stdval = 0.125
        bias = 0.
        torch.nn.init.normal_(self.fc1.weight, std=stdval)
        torch.nn.init.normal_(self.fc2.weight, std=stdval)
        torch.nn.init.normal_(self.fc3.weight, std=stdval)
        torch.nn.init.constant_(self.fc1.bias, bias)
        torch.nn.init.constant_(self.fc2.bias, bias)
        torch.nn.init.constant_(self.fc3.bias, bias)

        self.double()

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        x = torch.sub(x, 0.5)  # TODO does this help/hurt?
        x = F.relu(self.fc1(x))
        x = F.relu(self.fc2(x))
        x = self.fc3(x)
        return x

class DTAMERLoss(torch.nn.Module):
    def __init__(self, actionsize: int):
        super(DTAMERLoss, self).__init__()
        self.actionsize = actionsize

    def forward(self, result: torch.Tensor, target: torch.Tensor, action: torch.Tensor, weights=None):
        self.one_hot = F.one_hot(action, num_classes=self.actionsize).to(torch.float64)
        self.q = torch.mul(self.one_hot, result).sum(dim=1)
        if weights is not None:
            self.error = (weights * torch.square(target - self.q)).mean()
        else:
            self.error = ((target - self.q) ** 2).mean()
        return self.error

class BasicNN(torch.nn.Module):
    def __init__(self, ndim: int):
        super(BasicNN, self).__init__()
        hls = round(8*ndim / 3) # chosen by vibes
        self.fc1 = torch.nn.Linear(2*ndim, hls)
        self.fc2 = torch.nn.Linear(hls, hls)
        self.fc3 = torch.nn.Linear(hls, 1)

        torch.nn.init.normal_(self.fc1.weight, std=0.1)
        torch.nn.init.normal_(self.fc1.weight, std=0.1)
        torch.nn.init.normal_(self.fc3.weight, std=0.1)

        self.double()

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        x = F.tanh(self.fc1(x))
        x = F.tanh(self.fc2(x))
        x = F.tanh(self.fc3(x))
        return x
