---
name: tvb-driver-boilerplate
description: Essential TVB simulation boilerplate and core building blocks. Use when starting any TVB workflow, importing libraries, configuring connectivity, models, coupling, monitors, and the simulator. Triggers on `tvb.simulator.lab`, `connectivity.Connectivity`, `simulator.Simulator`, `configure()`.
---

# TVB Driver: Boilerplate & Core Simulation

## Essential Imports
```python
from tvb.simulator.lab import *
import numpy
import matplotlib.pyplot as plt
```

## Building a Simulation
Every TVB simulation follows this pattern. Fill in the blanks:
```python
# 1. Connectivity
conn = connectivity.Connectivity.from_file()  # or from_file("custom.zip")
conn.speed = numpy.array([4.0])
conn.configure()

# 2. Model
model = models.Generic2dOscillator(a=numpy.array([-0.5]), b=numpy.array([-15.0]))

# 3. Coupling
coup = coupling.Linear(a=numpy.array([0.0154]))

# 4. Integrator
# (see noise-and-integrator skill for noise/integrator details)

# 5. Monitors
mon = (monitors.TemporalAverage(period=5.0),)

# 6. Simulator
sim = simulator.Simulator(
    model=model,
    connectivity=conn,
    coupling=coup,
    integrator=heunint,
    monitors=mon
)
sim.configure()

# 7. Run
# Single monitor
(t, y), = sim.run(simulation_length=1e3)

# Multiple monitors — unpack one (time, data) tuple per monitor
# (t_raw, y_raw), (t_eeg, y_eeg) = sim.run(simulation_length=1e3)
```

## Critical Rules
- **Always `configure()`** connectivity, stimulus, and simulator before running.
- **Array wrapping**: Parameters must be numpy arrays, even scalars: `numpy.array([value])`.
- **Region numbering**: Default connectivity has 76 regions. V1/V2 are usually regions 35, 36.
- **Prose/code drift**: If markdown says "amp = 1e-3", the code block must literally set `amp` to `1e-3`, not `0.5`.
