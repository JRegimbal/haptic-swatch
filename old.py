# Misc code removed from agent.ipynb (checked in just here for quick reference)
class Crediter:
    def __init__(self, ndims, max_length = 8):
        self._history = deque(maxlen=max_length)
        self._a = 0.175
        self._b = 0.1
        self._c = 0.05
        tmp = get_features(np.zeros(ndims), np.zeros(ndims))
        for _ in range(max_length):
            self._history.append(tmp)
        
    def add_index(self, feature_vec):
        if len(self._history) >= self._history.maxlen:
            self._history.pop()
        self._history.append(feature_vec)

    def credit(self):
        return sum([w * v for w, v in zip(
            np.array([self._c, self._b, self._a, self._a, self._a, self._a, self._b, self._c]),
            self._history
        )])

class Crediter2(Crediter):
    def __init__(self, ndims):
        self._history = deque(maxlen=4)
        self._a = 0.5
        self._b = 0.25
        self._c = 0.15
        self._d = 0.05
        tmp = get_features(np.zeros(ndims), np.zeros(ndims))
        for _ in range(self._history.maxlen):
            self._history.append(tmp)

    def credit(self):
        return sum([w * v for w, v in zip(
            np.array([self._a, self._b, self._c, self._d]),
            self._history
        )])

class Crediter3(Crediter):
    def __init__(self, ndims):
        self._history = deque(maxlen=2)
        tmp = get_features(np.zeros(ndims), np.zeros(ndims))
        for _ in range(self._history.maxlen):
            self._history.append(tmp)

    def credit(self):
        return sum([w * v for w, v in zip(
            np.array([0.75, 0.25]),
            self._history
        )])


class RandomAgent:
    def __init__(self):
        self.state = np.zeros(N_DIMS)
        a = np.eye(N_DIMS) / N_STEPS
        self._actions = np.concatenate((a, -a))
        self._rng = np.random.default_rng()
        print(self.state)

    # Values should be normalized to 0-1 space for each
    def set_state(self, k, mu, al, ah):
        self.state = np.array([k, mu, al, ah])

    def select_action(self):
        # Select actions randomly until it's valid
        invalid = True
        while invalid:
            action = self._actions[self._rng.integers(len(self._actions))]
            next_state = self.state + action
            invalid = not ((next_state >= 0) & (next_state <= 1)).all(0)
        return action

    def apply_action(self, action):
        next_state = self.state + action
        if ((next_state >= 0) & (next_state <= 1)).all(0):
            self.state = next_state
        else:
            raise Exception(f"Tried to transition to invalid state {next_state}.")

class LinearSGDAgent:
    def __init__(self, ndims, step, epsilon=0.1, alpha=0.002, gamma=0.50, crediter=Crediter3):
        self._ndims = ndims
        self._step = step
        self.crediter = crediter(self._ndims)
        self.state = np.zeros(self._ndims)
        self._weights = np.zeros(len(get_features(np.zeros(self._ndims), np.zeros(self._ndims))))
        a = np.eye(self._ndims) * self._step
        self._actions = np.concatenate((a, -a))
        self._exclude_dims = set()
        self._rng = np.random.default_rng()
        self._epsilon = epsilon
        self._alpha = alpha # taken from scurto et al 2021
        self._gamma = gamma

    def set_state(self, state, action=None):
        if action is None:
            action = np.zeros(self._ndims)
        self.state = state
        self.crediter.add_index(get_features(self.state, action))

    def check_bounds(self, state):
        return ((state >= 0) & (state <= 1)).all(0)

    def get_value(self, state, action):
        return np.dot(self._weights, get_features(state, action))

    def select_action(self):
        max_actions = []
        invs = []
        max_value = np.NINF
        for action in self.included_actions():
            next_state = self.state + action
            if self.check_bounds(next_state):
                value = self.get_value(next_state, action)
                if np.isclose(max_value, value):
                    max_actions.append(action)
                elif value > max_value:
                    max_value = value
                    max_actions = [action]
            else:
                invs.append(action)
        if len(invs) > 0:
            print(f"Invalid actions {invs}")
        print(f"Maximum value of {max_value}")
        if len(max_actions) > 0:
            return max_actions[self._rng.integers(len(max_actions))]
        else:
            print("No valid actions!")
            return None

    def select_epsilon_greedy_action(self):
        if self._rng.random() < self._epsilon:   
            # Random action
            invalid = True
            actions = self.included_actions()
            if len(actions) > 0:
                while invalid:
                    action = actions[self._rng.integers(len(actions))]
                    next_state = self.state + action
                    invalid = not self.check_bounds(next_state)
                print(f"Taking random action {action}")
                return action
            else:
                print("No valid actions!")
                return None
        else:
            return self.select_action() 

    def apply_action(self, action):
        next_state = self.state + action
        if self.check_bounds(next_state):
            self.set_state(next_state, action)
        else:
            raise Exception(f"Tried to transition to an invalid state {next_state}.")

    def reward_and_bootstrap(self, reward):
        credit_features = self.crediter.credit()
        action = self.select_action()
        if action is not None:
            next_state = self.state + action
            error = reward + self._gamma * self.get_value(next_state, action) - np.dot(self._weights, credit_features)
        else:
            error = reward - np.dot(self._weights, credit_features)
        print(f"Error - {error}")
        self._weights = self._weights + self._alpha * error * credit_features

    def update_activation(self, dimension, activation):
        if activation:
            self._exclude_dims.discard(dimension)
        else:
            self._exclude_dims.add(dimension)

    def included_actions(self):
        # Set of actions that do not modify the 0-indexed dimensions in self._exclude_dims
        return np.array([act for act in self._actions if reduce(lambda x, y: x and y, [act[dim] == 0 for dim in self._exclude_dims], True)])

def features1(k, mu, al, ah):
    return np.array([
        1,
        k,
        mu,
        al,
        ah,
        k * mu,
        k * al,
        k * ah,
        mu * al,
        mu * ah,
        al * ah
    ])

def features2(k, mu, al, ah):
    return np.array([
        1,
        k,
        mu,
        al,
        ah,
#        k * mu,
#        k * al,
#        k * ah,
#        mu * al,
#        mu * ah,
#        al * ah,
        k**2,
        mu**2,
        al**2,
        ah**2
    ])

def features3(k, mu, al, ah, a1, a2, a3, a4):
    return np.array([
        1,
        k,
        mu,
        al,
        ah,
        k*a1,
        mu*a2,
        al*a3,
        ah*a4,
        k**2,
        mu**2,
        al**2,
        ah**2
    ])

#def idenfeatures(k, mu, al, ah, a1, a2, a3, a4):
#    return np.array([k, mu, al, ah, a1, a2, a3, a4])
