# flake8: noqa: E501
import time
import numpy as np
from scipy.stats import gamma


class LinearGammaCrediter:
    def __init__(self, ndims):
        self._history = []
        # From TAMER
        self.k = 2.0
        self.theta = 0.28
        self.delay = 0.20 # seconds

    def add_index(self, feature_vec):
        self._history.append((feature_vec, time.time()))

    def credit(self):
        # Prune old times
        self._history = [x for x in self._history if time.time() - x[1] < gamma.ppf(0.999, self.k, self.delay, self.theta)]
        self._history.sort(key=lambda x: x[1], reverse=True)
        if len(self._history) == 0:
            raise Exception("Empty history array - cannot assign credit")
        # Calculate from remaining
        return sum([
            (gamma.cdf(x[1], self.k, self.delay, self.theta) - \
             (0 if idx == 0 else gamma.cdf(self._history[idx-1][1], self.k, self.delay, self.theta))) * \
            x[0] for idx, x in enumerate(self._history)
        ])

class GammaCrediter:
    """
    Unlike the above/older version of the crediter, this version
    does not combine the history into one feature vector. Instead,
    each vector is returned alongside a weight. Weights sum to 1.
    """
    def __init__(self, ndims):
        self._history = []
        self.k = 2.0
        self.theta = 0.28
        self.delay = 0.20

    def add_index(self, feature_vec):
        self._history.append((feature_vec, time.time()))

    def credit(self):
        # Prune old times
        self._history = [x for x in self._history if time.time() - x[1] < gamma.ppf(0.999, self.k, self.delay, self.theta)]
        self._history.sort(key=lambda x: x[1], reverse=True)
        if len(self._history) == 0:
            raise Exception("Empty history array - cannot assign credit")
        current_time = time.time()
        weights = np.array([gamma.cdf(current_time - x[1], self.k, self.delay, self.theta) - \
                  (0 if idx == 0 else gamma.cdf(current_time - self._history[idx-1][1], self.k, self.delay, self.theta)) \
                  for idx, x in enumerate(self._history)]).reshape((len(self._history), 1))
        return (np.array([x[0] for x in self._history]), weights)

    def credit2(self):
        # Prune old times
        next = []
        self._history = [x for x in self._history if time.time() - x[1] < gamma.ppf(0.999, self.k, self.delay, self.theta)]
        self._history.sort(key=lambda x: x[1], reverse=True)
        if len(self._history) == 0:
            raise Exception("Empty history array - cannot assign credit")
        current_time = time.time()
        weights = np.array([gamma.cdf(current_time - x[1], self.k, self.delay, self.theta) - \
                  (0 if idx == 0 else gamma.cdf(current_time - self._history[idx-1][1], self.k, self.delay, self.theta)) \
                  for idx, x in enumerate(self._history)]).reshape((len(self._history), 1))
        return (np.array([x[0] for x in self._history]), weights, np.zeros(len(weights)))

class UniformCrediter:
    """
    Equally splits reward over interval of t-0.2 to t-4. Weights sum to 1
    """
    def __init__(self, ndims: int):
        self._history: list[tuple[np.ndarray, float]] = []
        self._low = 0.2
        self._high = 4.0

    def add_index(self, feature_vec: np.ndarray):
        self._history.append((feature_vec, time.time()))

    def credit(self) -> tuple[np.ndarray, np.ndarray]:
        # Prune old times
        call_time = time.time()
        self._history = [x for x in self._history if call_time - x[1] <= self._high]
        tmp = [x for x in self._history if call_time - x[1] >= self._low]
        if len(tmp) == 0:
            raise Exception("No eligible history - cannot assign credit")
        return (np.array([x[0] for x in tmp]), np.ones((len(tmp), 1)) / len(tmp))

    def credit2(self) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
        call_time = time.time()
        self._history = [x for x in self._history if call_time - x[1] <= self._high] # Limit to those eligible to receive credit
        values = []
        next = []
        for i in range(len(self._history)):
            if call_time - self._history[i][1] >= self._low:
                values.append(self._history[i][0])
                if i < len(self._history) - 1:
                    next.append(self._history[i + 1][0])
                else:
                    # This case shouldn't happen
                    print("Entire history eligible for credit, this shouldn't typically happen!")
                    next.append(self._history[i][0]) # Can't give dummy value, assuming that the person wants a no-op as much as possible
            else:
                break
        assert len(values) == len(next), f"{len(values)} values eligible, but {len(next)} next state-actions found"
        if len(values) == 0:
            raise Exception("No eligible history - cannot assign credit")
        weights = np.ones((len(values), 1)) # / len(values)
        return (np.array(values), weights, np.array(next))

    def credit3(self) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
        call_time = time.time()
        self._history = [x for x in self._history if call_time - x[1] <= self._high]
        values = [i[0] for i in self._history if call_time - i[1] > self._low]
        states = np.array([i[0] for i in values])
        actions = np.array([[i[1]] for i in values])
        return (states, np.ones(actions.shape), actions)
