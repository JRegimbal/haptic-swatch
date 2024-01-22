# A simple 2-DoF force-feedback authoring tool with co-creative agents

This project includes a basic tool for designing static haptic effects for circular elements
("haptic swatches") to be displayed on the
[Haply 2DIY](https://2diy.haply.co).
In addition to setting the parameters of these effects manually, a per-element co-creative agent
can be used to explore new options by changing the value of a toggle in the interface.

* agent.ipynb - A notebook containing the logic for the co-creative agents, which are communicated with over OSC.
* haptic_param_sketching - A processing project including the UI, physics simulation, and connection to the 2DIY.
* requirements.txt - The dependencies for the Python agent.
* old.py - Old Python code for previous versions of the agent.

## Materials

* A Haply 2DIY v2, v3 or v3.1 (for versions other than 3.1, an enum will need to be changed in `haptic_param_sketching/haptic_param_sketching.pde`)
* A computer (I ran this on a 2015 Dell XPS 13 running Debian bookworm, but you should follow your heart)

## Prerequisites

* Install [Processing](https://processing.org/download) 4.3 or later and the following dependencies:
    * [ControlP5](https://www.sojamo.de/libraries/controlp5/)
    * [oscP5](https://www.sojamo.de/libraries/oscp5/)
* Install Python 3.11 or later

## Setup

To setup Python & Jupyter notebook to run the agents, create a new virtual environment and install the dependencies in `requirements.txt`.
For example:

```bash
python3 -m venv $PATH_TO_VENV/env  # Replace $PATH_TO_VENV with wherever you keep your virtual environments
source $PATH_TO_VENV/env/bin/activate
pip install -r requirements.txt
```

## Running

1. Load the virtual environment using the `source` command above, or the equivalent for your system.
2. Start Jupyter Lab (e.g., `python -m jupyter lab`) and open the `agent.ipynb` notebook.
3. Run all the cells in the file.
4. Open the Processing sketch under `haptic_param_sketching`.
5. With the 2DIY connected and its end effector in the home position for your model, start the sketch.
This will open the tool, which should automatically connect to the program running in Jupyter.

Note that if the program does not start, ensure that the sketch is selecting the correct serial port for your 2DIY (see `setup()` in `haptic_param_sketching/setup_and_draw.pde`).
