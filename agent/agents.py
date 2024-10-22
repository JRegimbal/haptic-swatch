# flake8: noqa: E501
import torch
import numpy as np
from collections import deque
from functools import reduce
from .crediters import UniformCrediter
from .networks import ReLUNet, DTAMERLoss
from .tiling import TilingDensity
import random
from typing import Optional, Union
from typing_extensions import override

PARAM_EPSILON = 0.1
PARAM_ALPHA = 0.002
PARAM_BETA = 0.1 #0.2
PARAM_C = 0.01
PARAM_AUG = 0.5
PARAM_ZONE_STEPS = 3


def and_op(x, y):
    return x and y


class BaseAgent:
    def __init__(self, ndims: int, step: float, *args):
        self._ndims = ndims
        self._step = step
        self.state = np.zeros(self._ndims)
        self.state_lows = np.zeros(self._ndims)
        self.state_highs = np.ones(self._ndims)
        a = np.eye(self._ndims) * self._step
        self._actions = np.concatenate((a, -a))
        self._actions_index = list(range(len(self._actions)))
        self._exclude_dims: set[int] = set()
        self._rng = np.random.default_rng()

# Values should be normalized to 0-1 space for each
    def set_state(self, state: Union[tuple[float, ...], np.ndarray], *, lows=None, highs=None, action=None, history=True) -> np.ndarray:
        state = np.array(state)
        # Check range and update
        if lows is not None:
            assert len(lows) == self._ndims, f"Expected lows to contain {self._ndims} elements, not {len(lows)}"
            assert reduce(and_op, [x >= 0 for x in lows], True) and reduce(and_op, [x <= 1 for x in lows], True), f"Low range not normalized: {lows}"
            self.state_lows = lows
        if highs is not None:
            assert len(highs) == self._ndims, f"Expected highs to contain {self._ndims} elements, not {len(highs)}"
            assert reduce(and_op, [x >= 0 for x in highs], True) and reduce(and_op, [x <= 1 for x in highs], True), f"High range not normalized: {highs}"
            self.state_highs = highs
        assert reduce(and_op, [x >= 0 for x in state], True) and reduce(and_op, [x <= 1 for x in state], True), f"State out of bounds {state}"
        old_state = self.state
        self.state = state
        return old_state

    def to_action(self, action: int) -> np.ndarray:
        return self._actions[action]

    def _check_bounds(self, state: np.ndarray) -> bool:
        return ((state >= 0) & (state <= 1) & (state >= np.array(self.state_lows)) & (state <= np.array(self.state_highs))).all(0)

    def apply_action(self, action: int) -> None:
        next_state = self.state + self.to_action(action)
        if self._check_bounds(next_state):
            self.set_state(next_state, action=action)
        else:
            raise Exception(f"Tried to transition to an invalid state {next_state}.")

    def update_activation(self, dimension: int, activation: bool):
        if activation:
            self._exclude_dims.discard(dimension)
        else:
            self._exclude_dims.add(dimension)

    def _included_actions(self) -> np.ndarray:
        return np.array([act for act in self._actions_index if reduce(lambda x, y: x and y, [self.to_action(act)[dim] == 0 for dim in self._exclude_dims], True)])

# Scurto used alpha = 0.002
class NeuralSGDAgent(BaseAgent):
    def __init__(self, ndims: int, step: float, epsilon=PARAM_EPSILON, alpha=PARAM_ALPHA, crediter=UniformCrediter, replay=True):
        BaseAgent.__init__(self, ndims, step)
        self.crediter = crediter(self._ndims)
        self._net = ReLUNet(self._ndims)
        #self._criterion = torch.nn.MSELoss()
        self._criterion = DTAMERLoss(2 * self._ndims)
        self._optimizer = torch.optim.Adam(self._net.parameters(), lr=alpha)
        self._epsilon = epsilon
        self._alpha = alpha
        self._beta = PARAM_BETA
        self._c = PARAM_C
        n_tiles = int(2 + np.ceil(np.log2(self._ndims)))
        k_tile = int(np.ceil(1 / (4 * self._step)))
        #n_tiles = int(2 + np.ceil(np.log2(self._ndims)))
        #k_tile = int(np.ceil(1/(2 * self._step)))
        self.tiling = TilingDensity(self._ndims, n_tiles, k_tile)
        self.replay = replay
        self._replay_batch = 32
        self._history: deque[Union[tuple[np.ndarray, np.ndarray, int], tuple[np.ndarray, np.ndarray, int, int]]] = deque(maxlen=700)    # state weight action modality

    def set_state(self, state: Union[tuple[float, ...], np.ndarray], *, lows=None, highs=None, action=None, history=True):
        # Check range and update
        old_state = BaseAgent.set_state(self, state, lows=lows, highs=highs, action=action, history=history)
        if history:
            self.tiling.count(old_state)
        if (history and (action is not None)) or ((not history) and (action is None)):
            # For manual, allow multi-action splitting
            to_add = []
            if action is not None:
                to_add.append((old_state, action))
            else:
                state_diff = state - old_state
                max_ind = np.argmax(np.abs(state_diff))
                was_negative = (state_diff[max_ind] < 0.)
                num_actions = int(np.floor(np.abs(state_diff[max_ind]) / self._step))
                sel_action = int(max_ind + self._ndims * (1 if was_negative else 0))
                to_add = [(old_state + i * self.to_action(sel_action), sel_action) for i in range(num_actions)]
            for tup in to_add:
                self.crediter.add_index(tup)

    def _select_action(self) -> Optional[int]:
        max_actions: list[int] = []
        max_value = np.NINF
        valid_actions = [action for action in self._included_actions() if self._check_bounds(self.state + self.to_action(action))]
        if len(valid_actions) > 0:
            action_values = self._net(torch.from_numpy(self.state)).detach().numpy()[valid_actions]
            explore_values = np.array([self._beta * np.power(
                self.tiling.density(self.state + self.to_action(action)) * self.tiling.total_count + self._c,
                -0.5
            ) for action in valid_actions])
            valid_values = action_values + explore_values
            #print(f"Action values ({len(action_values)}): {action_values}")
            #print(f"Explore values ({len(explore_values)}): {explore_values}")
            max_ind = np.argmax(valid_values)
            #print(f"Selected {max_ind} of {len(valid_values)} values")
            print(f"Reward: [{np.min(action_values)}, {np.max(action_values)}], Explore: [{np.min(explore_values)}, {np.max(explore_values)}]")
            return valid_actions[max_ind]
        else:
            print("No valid actions!")
            return None

    def select_epsilon_greedy_action(self) -> Optional[int]:
        if self._rng.random() < self._epsilon:
            # Exploration-only action
            valid_actions = [action for action in self._included_actions() if self._check_bounds(self.state + self.to_action(action))]
            if len(valid_actions) > 0:
                feature_explore_values = np.array([self._beta * np.power(self.tiling.density(self.state + self.to_action(act)) * self.tiling.total_count + self._c, -0.5) for act in valid_actions])
                max_ind = np.argmax(feature_explore_values)
                #max_ind = self._rng.integers(len(valid_actions))
                return valid_actions[max_ind]
            else:
                print("No valid actions!")
                return None
        else:
            return self._select_action()

    def replay_from_history(self) -> None:
        if len(self._history) >= 2 * self._replay_batch:
            sample = random.sample(self._history, self._replay_batch)
            states = np.array([x[0] for x in sample])
            weights = np.array([x[1] for x in sample])
            actions = np.array([x[2] for x in sample])
            self._optimizer.zero_grad()
            error = self._criterion(self._net(torch.from_numpy(states)), torch.from_numpy(weights), torch.from_numpy(actions))
            error.backward()
            self._optimizer.step()
            print("Replayed from history")

    def process_guiding_reward(self, reward: float, _: Optional[int]):
        try:
            states, credit_weight, actions = self.crediter.credit3()
            print(states.shape)
            credit_weight = credit_weight * reward
            # credit_x := credit_x + gamma * q(snext, anext, weights)
        except Exception as e:
            print(f"ERROR: {e}")
            print("Not applying reward...")
            return

        if states.size == 0:
            print("No recent history! Applying zone reward...")
            states = []
            actions = []
            for j in range(PARAM_ZONE_STEPS):
                for i in range(2 * self._ndims):
                    new_state = self.state + (j + 1) * self.to_action(i)
                    if ((new_state >= 0.) & (new_state <= 1.)).all(0):
                        states.append(new_state)
                        actions.append(i)
            states = np.array(states).reshape(-1, self._ndims)
            actions = np.array(actions).reshape(-1, 1)
            credit_weight = reward * np.ones(actions.shape)

        # Give positive reward in opposite direction for next action
        # Note that states and actions are in per-modality format
        if reward < 0:
            aug_states = []
            aug_actions = []
            aug_weights = -PARAM_AUG * credit_weight
            for s, a in zip(states, actions):
                aug_states.append(s + self.to_action(a[0]))
                aug_actions.append((a[0] + self._ndims) % (self._ndims * 2))
            states = np.concatenate((states, np.array(aug_states)), axis=0)
            actions = np.concatenate((actions, np.array(aug_actions).reshape(-1, 1)), axis=0)
            credit_weight = np.concatenate((credit_weight, aug_weights), axis=0)

        print("determined guidance")
        self._optimizer.zero_grad()
        error = self._criterion(self._net(torch.from_numpy(states)), torch.from_numpy(credit_weight), torch.from_numpy(actions))
        print(f"Error: {error}")
        error.backward()
        self._optimizer.step()

        print("updated model")
        if self.replay:
            history_buf = list(zip(states, credit_weight, actions))
            self._history.extend(history_buf)

    def select_less_explored(self, n_points=50) -> np.ndarray:
        # Generate samples within limits
        # Override locked parameters
        samples_by_dim = [
            (
                np.random.uniform(
                    low=self.state_lows[i],
                    high=self.state_highs[i],
                    size=(n_points,1)
                )
                if i not in self._exclude_dims
                else np.ones((n_points,1)) * self.state[i]
            )
            for i in range(self._ndims)
        ]

        # Make full array
        state_sample = np.concatenate(samples_by_dim, axis=1)
        sample_explore_bonus = np.array([self.tiling.density(samp) for samp in state_sample])
        new_state = state_sample[np.argmax(sample_explore_bonus)]
        return new_state


# In[ ]:


class SplitNeuralSGDAgent(NeuralSGDAgent):
    def __init__(self, ndims1: int, ndims2: int, step: float, epsilon=PARAM_EPSILON, alpha=PARAM_ALPHA, crediter=UniformCrediter, replay=True):
        NeuralSGDAgent.__init__(self, ndims1 + ndims2, step, epsilon, alpha, crediter, replay)
        self._split_index = ndims1
        self.crediter = None
        self.crediter1 = crediter(ndims1)
        self.crediter2 = crediter(ndims2)
        del self._net
        self._net1 = ReLUNet(ndims1)
        self._net2 = ReLUNet(ndims2)
        del self._criterion
        self._criterion1 = DTAMERLoss(ndims1 * 2)
        self._criterion2 = DTAMERLoss(ndims2 * 2)
        del self._optimizer
        #self._optimizer1 = torch.optim.SGD(self._net1.parameters(), lr=alpha)
        #self._optimizer2 = torch.optim.SGD(self._net2.parameters(), lr=alpha)
        self._optimizer1 = torch.optim.Adam(self._net1.parameters(), lr=alpha)
        self._optimizer2 = torch.optim.Adam(self._net2.parameters(), lr=alpha)

    def split(self, value: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
        """
        Splits by audio and haptic components.
        """
        assert len(value) == self._ndims, f"Expected vector of size {self._ndims}, received {len(value)}"
        return (value[:self._split_index], value[self._split_index:])

    def _is_haptic_action(self, action_index: int) -> bool:
        """
        If the specified action impacts a haptic parameter.
        """
        return (action_index >= 0 and action_index < self._split_index) or \
            (action_index >= self._ndims and action_index < self._ndims + self._split_index)

    def _to_model_idx(self, action_idx: int, isAudio: bool) -> int:
        """
        Converts a 0-indexed haptic or audio parameter to the global, audio-haptic index.
        """
        if isAudio:
            action_idx = action_idx - self._split_index
            if action_idx >= self._ndims:
                action_idx = action_idx - self._split_index
        elif action_idx >= self._ndims:
            # Negative value step for haptics
            action_idx = action_idx - self._ndims + self._split_index
        return action_idx

    def _from_model_idx(self, action_idx: int, isAudio: bool) -> int:
        if isAudio:
            action_idx = action_idx + self._split_index
            if action_idx >= self._ndims:
                action_idx = action_idx + self._split_index
        elif action_idx >= self._split_index:
            action_idx = action_idx + self._ndims - self._split_index
        return action_idx

    def set_state(self, state: Union[tuple[float, ...], np.ndarray], *, lows=None, highs=None, action=None, history=True):
        old_state = BaseAgent.set_state(self, state, lows=lows, highs=highs, action=action, history=history)
        if history:
            self.tiling.count(old_state)
        if (history and (action is not None)) or ((not history) and (action is None)):
            # If no action we need to determine it
            # May need to split into multiple actions
            to_add = []
            if action is not None:
                to_add.append((old_state, action))
            else:
                state_diff = state - old_state
                max_ind = np.argmax(np.abs(state_diff))
                was_negative = (state_diff[max_ind] < 0.)
                num_actions = int(np.floor(np.abs(state_diff[max_ind]) / self._step))
                sel_action = int(max_ind + self._ndims * (1 if was_negative else 0))
                to_add = [(old_state + i * self.to_action(sel_action), sel_action) for i in range(num_actions)]
            for s, a in to_add:
                state1, state2 = self.split(s)
                if self._is_haptic_action(a):
                    self.crediter1.add_index((state1, self._to_model_idx(a, False)))
                else:
                    self.crediter2.add_index((state2, self._to_model_idx(a, True)))

    def _select_action(self) -> Optional[int]:
        valid_actions = [action for action in self._included_actions() if self._check_bounds(self.state + self.to_action(action))]
        valid_1 = [a for a in valid_actions if a < self._split_index]
        valid_2 = [a - self._split_index for a in valid_actions if a >= self._split_index]
        if len(valid_actions) > 0:
            state1, state2 = self.split(self.state)
            action_values1 = self._net1(torch.from_numpy(state1)).detach().numpy()
            av1pos, av1neg = np.split(action_values1, 2)
            action_values2 = self._net2(torch.from_numpy(state2)).detach().numpy()
            av2pos, av2neg = np.split(action_values2, 2)
            feature_reward_values = np.concatenate((av1pos, av2pos, av1neg, av2neg))[valid_actions]
            feature_explore_values = np.array([self._beta * np.power(self.tiling.density(self.state + self.to_action(action)) * self.tiling.total_count + self._c, -0.5) for action in valid_actions])
            explore_values = np.array([self._beta * np.power(
                self.tiling.density(self.state + self.to_action(action)) * self.tiling.total_count + self._c,
                -0.5
            ) for action in valid_actions])
            feature_values = feature_reward_values + feature_explore_values
            max_ind = np.argmax(feature_values)
            #print(f"Max s1: {np.max(action_values1)} s2 {np.max(action_values2)}")
            print(f"Contribution: model {feature_reward_values[max_ind]}, explore {feature_explore_values[max_ind]}")
            return valid_actions[max_ind]
        else:
            print("No valid actions!")
            return None

    def replay_from_history(self):
        if len(self._history) >= 2 * self._replay_batch:
            sample = random.sample(self._history, self._replay_batch)
            states1 = []
            states2 = []
            actions1 = []
            actions2 = []
            weights1 = []
            weights2 = []
            for x in sample:
                if x[3] == 1:
                    states1.append(x[0])
                    weights1.append(x[1])
                    actions1.append(x[2])
                elif x[3] == 2:
                    states2.append(x[0])
                    weights2.append(x[1])
                    actions2.append(x[2]) # already corrected!
                else:
                    print("OH NO")

            states1 = np.array(states1)
            weights1 = np.array(weights1)
            actions1 = np.array(actions1)
            states2 = np.array(states2)
            weights2 = np.array(weights2)
            actions2 = np.array(actions2)

            if len(states1) > 0:
                self._optimizer1.zero_grad()
                error = self._criterion1(self._net1(torch.from_numpy(states1)), torch.from_numpy(weights1), torch.from_numpy(actions1))
                error.backward()
                self._optimizer1.step()
            if len(states2) > 0:
                self._optimizer2.zero_grad()
                error = self._criterion2(self._net2(torch.from_numpy(states2)), torch.from_numpy(weights2), torch.from_numpy(actions2))
                error.backward()
                self._optimizer2.step()
            print("Replayed from history")

    def process_guiding_reward(self, reward: float, modality: Optional[int]):
        assert modality is not None, "No modality specified"
        try:
            states, credit_weight, actions = self.crediter1.credit3() if modality == 1 else self.crediter2.credit3()
            credit_weight = credit_weight * reward

        except Exception as e:
            print(f"ERROR: {e}")
            print("Not applying reward...")
            return

        if states.size == 0:
            print("No history for this modality! Applying zone reward...")
            state_part = self.split(self.state)[0 if modality == 1 else 1]
            def from_model_action_idx(action: int) -> np.ndarray:
                act = np.zeros(len(state_part))
                act[action % len(state_part)] = self._step * (-1 if action >= len(state_part) else 1)
                return act
            states = []
            actions = []
            for j in range(PARAM_ZONE_STEPS):
                for i in range(2 * len(state_part)):
                    new_state = state_part + (j + 1) * from_model_action_idx(i)
                    if ((new_state >= 0.) & (new_state <= 1.)).all(0):
                        states.append(new_state)
                        actions.append(i)
            states = np.array(states).reshape(-1, len(state_part))
            actions = np.array(actions).reshape(-1, 1)
            credit_weight = reward * np.ones(actions.shape)
        elif reward < 0:
            # Give positive reward in opposite direction for next action
            # Note that states and actions are in per-modality format
            aug_states = []
            aug_actions = []
            aug_weights = -PARAM_AUG * credit_weight
            for s, a in zip(states, actions):
                action_part = self.split(self.to_action(self._from_model_idx(a[0], modality == 2)))[0 if modality == 1 else 1]
                dim_size = self._split_index if modality == 1 else (self._ndims - self._split_index)
                aug_states.append(s + action_part)
                aug_actions.append((a[0] + dim_size) % (dim_size * 2))
            states = np.concatenate((states, np.array(aug_states)), axis=0)
            actions = np.concatenate((actions, np.array(aug_actions).reshape(-1, 1)), axis=0)
            credit_weight = np.concatenate((credit_weight, aug_weights), axis=0)

        if modality == 1:
            self._optimizer1.zero_grad()
            error = self._criterion1(self._net1(torch.from_numpy(states)), torch.from_numpy(credit_weight), torch.from_numpy(actions))
            print(f"Error: {error}")
            error.backward()
            self._optimizer1.step()
        else:
            self._optimizer2.zero_grad()
            error = self._criterion2(self._net2(torch.from_numpy(states)), torch.from_numpy(credit_weight), torch.from_numpy(actions))
            print(f"Error: {error}")
            error.backward()
            self._optimizer2.step()

        if self.replay:
            history_buf = list(zip(states, credit_weight, actions, np.ones(credit_weight.shape) * modality))
            self._history.extend(history_buf)
