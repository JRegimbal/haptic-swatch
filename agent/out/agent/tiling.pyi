import numpy as np
from _typeshed import Incomplete

class NormalizedTiling:
    ndim: Incomplete
    k: Incomplete
    offset: Incomplete
    counts: Incomplete
    def __init__(self, ndim: int, ksteps: int, offset: float) -> None: ...
    def tile_index(self, state: np.ndarray) -> int: ...

class TilingDensity:
    tiles: Incomplete
    total_count: int
    def __init__(self, ndim: int, ntiles: int, ksteps: int) -> None: ...
    def count(self, x: np.ndarray): ...
    def density(self, x: np.ndarray) -> float: ...
