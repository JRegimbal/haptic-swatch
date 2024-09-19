# flake8: noqa: E501
import numpy as np
import sys
import torch
from typing import Union, Optional
from agent import NeuralSGDAgent, SplitNeuralSGDAgent


print("===VERSIONS===")
print(f"Python: {sys.version}")
print(f"numpy: {np.__version__}")
print(f"PyTorch: {torch.__version__}")

from pythonosc.dispatcher import Dispatcher
from pythonosc.osc_server import BlockingOSCUDPServer
from pythonosc.udp_client import SimpleUDPClient
from threading import Event, Thread
import time

manualMode = True
agents: dict[int, Union[NeuralSGDAgent, SplitNeuralSGDAgent]] = {}

agentType = "joint"
haptic_dims = 6

ip = "127.0.0.1" # localhost
port = 8080
destPort = 8081

client = SimpleUDPClient(ip, destPort)
timings = []

def default_handler(address, *args):
    print(f"DEFAULT {address}: {args}")

def auto_switch_handler(_, state: bool, *args):
    start_time = time.time()
    print(f"Is Manual {state}")
    manualMode = state
    end_time = time.time()
    timings.append({"key": "switch", "start": start_time, "end": end_time})

def manual_set(_, element: int, *args: float):
    start_time = time.time()
    state = args[::3]
    low = args[1::3]
    high = args[2::3]
    agents[element].set_state(state=state, lows=low, highs=high, history=True)
    end_time = time.time()
    timings.append({"key": "manual_set", "start": start_time, "end": end_time})
    #print(f"{element}: {agents[element].state}")

def manual_update(_, element: int, *args: float):
    start_time = time.time()
    state = args[::3]
    low = args[1::3]
    high = args[2::3]
    agents[element].set_state(state=state, lows=low, highs=high, history=False)
    end_time = time.time()
    timings.append({"key": "manual_update", "start": start_time, "end": end_time})

def jump_unexplored(address: Union[str, int], element: int):
    start_time = time.time()
    new_state = agents[element].select_less_explored()
    agents[element].set_state(state=new_state, history=True)
    # auto jump
    step(address, element)

def step(_, element: int):
    start_time = time.time()
    old_state = agents[element].state
    action = agents[element].select_epsilon_greedy_action()
    if action is not None:
        #print(f"{element}: Taking action {action}")
        agents[element].apply_action(action)
        #print(f"Transitioned from {old_state} to {agent.state}")
        client.send_message("/controller/agentSet", [element, *agents[element].state])
        agents[element].replay_from_history()
    else:
        print(f"{element}: All actions excluded! Doing nothing.")
    end_time = time.time()
    timings.append({"key": "step", "start": start_time, "end": end_time})

def reward(_, element: int, reward: float, modality: Optional[int] = None):
    start_time = time.time()
    if modality:
        agents[element].process_guiding_reward(reward, modality)
    else:
        agents[element].process_guiding_reward(reward, None)
    end_time = time.time()
    timings.append({"key": "guidance", "start": start_time, "end": end_time})
    # print(f"Weights updated from {old_weights} to {agent._weights}"

# def zone_reward(_, element: int, reward: float):
#     # Calculate length N_STEPS away on each axis, store in agent
#     start_time = time.time()
#     agents[element].process_zone_reward(reward)
#     end_time = time.time()
#     timings.append({"key": "zone", "start": start_time, "end": end_time})

def activate(_, element: int, dimension: int, activation: bool):
    print(f"{element}: Setting dimension {dimension} to {activation}")
    agents[element].update_activation(dimension, activation)
    print(f"{agents[element]._exclude_dims}")

def init(_, element: int, ndims: int, step: float):
    if element in agents:
        print(f"Replacing agent {element} with fresh. {ndims} dimensions, initial step {step} (norm)")
    else:
        print(f"New agent {element} with {ndims} dimensions, initial step {step} (norm)")
    #agents[element] = LinearSGDAgent(ndims, step)
    if agentType == "joint":
        agents[element] = NeuralSGDAgent(ndims, step)
    elif agentType == "split":
        agents[element] = SplitNeuralSGDAgent(haptic_dims, ndims - haptic_dims, step)
    # elif agentType == "random":
    #     agents[element] = RandomAgent(ndims, step)

def delete(_, element: int):
    if element in agents:
        print(f"Deleting agent {element} ({agents[element]._ndims} dimensions)")
        del agents[element]
    else:
        print(f"No agent with identifier {element}!")

dispatcher = Dispatcher()
dispatcher.set_default_handler(default_handler)
dispatcher.map("/uistate/setAutonomous", auto_switch_handler)
dispatcher.map("/controller/manualSet", manual_set)
dispatcher.map("/controller/updateManual", manual_update)
dispatcher.map("/controller/jump", jump_unexplored)
dispatcher.map("/controller/step", step)
dispatcher.map("/controller/reward", reward)
dispatcher.map("/controller/activate", activate)
dispatcher.map("/controller/init", init)
# dispatcher.map("/controller/zone_reward", zone_reward)

ip = "127.0.0.1" # localhost
port = 8080

SERVER_CLOSE = Event()

with BlockingOSCUDPServer((ip, port), dispatcher) as server:
    def quit_func(address, *args):
        print("Quit!")
        SERVER_CLOSE.set()
    dispatcher.map("/quit", quit_func)
    thread = Thread(target=server.serve_forever)
    thread.start()
    SERVER_CLOSE.wait()
    server.shutdown()
    thread.join()
print("And we're out!")

