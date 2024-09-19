# flake8: noqa: E501
import numpy as np


class NormalizedTiling:
    def __init__(self, ndim: int, ksteps: int, offset: float):
        self.ndim = ndim
        self.k = ksteps
        self.offset = offset
        assert self.offset < 0, "Offset must be less than 0"
        assert self.offset >= -1 / self.k, f"Offset cannot be above {-1/self.k}"
        self.counts = np.zeros(np.power(self.k + 1, self.ndim))

    def tile_index(self, state: np.ndarray) -> int:
        assert len(state) == self.ndim, f"Expected state of dimension {self.ndim}, received {len(state)}"
        shift = (state - self.offset * np.ones(self.ndim)) * self.k
        return sum([int(np.power(self.k + 1, j) * (np.floor(shift[j]) if shift[j] < self.k else self.k)) for j in range(self.ndim)])


class TilingDensity:
    def __init__(self, ndim: int, ntiles: int, ksteps: int):
        self.tiles = [NormalizedTiling(ndim, ksteps, -(i + 1)/(ksteps * ntiles)) for i in range(ntiles)]
        self.total_count = 0

    def count(self, x: np.ndarray):
        for tiling in self.tiles:
            idx = tiling.tile_index(x)
            tiling.counts[idx] += 1
        self.total_count += 1

    def density(self, x: np.ndarray) -> float:
        if self.total_count > 0:
            return sum([tiling.counts[tiling.tile_index(x)] for tiling in self.tiles]) / self.total_count
        else:
            return 0
