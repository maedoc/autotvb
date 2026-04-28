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

# 7. Run — sim() returns a GENERATOR. NEVER try to unpack it directly.
# Single monitor: iterate the 1-tuple
for (t, y), in sim(simulation_length=1e3):
    pass

# Multiple monitors with SAME period
for (t1, y1), (t2, y2) in sim(simulation_length=1e3):
    pass

# Multiple monitors with DIFFERENT periods — some yields contain None
raw_data = []
avg_data = []
for monitor_tuple in sim(simulation_length=1e3):
    if monitor_tuple[0] is not None:
        raw_data.append(monitor_tuple[0])
    if monitor_tuple[1] is not None:
        avg_data.append(monitor_tuple[1])

# Convert collected (t, y) tuples back to arrays
# Each element is (scalar_time, narray_state_vars) — use numpy.array, not concatenate
t_raw = numpy.array([r[0] for r in raw_data])
y_raw = numpy.array([r[1] for r in raw_data])
t_avg = numpy.array([a[0] for a in avg_data])
y_avg = numpy.array([a[1] for a in avg_data])
```

## Critical Rules
- **Always `configure()`** connectivity, stimulus, and simulator before running.
- **Array wrapping**: Parameters must be numpy arrays, even scalars: `numpy.array([value])`.
- **Region numbering**: Default connectivity has 76 regions. V1/V2 are usually regions 35, 36.
- **Prose/code drift**: If markdown says "amp = 1e-3", the code block must literally set `amp` to `1e-3`, not `0.5`.

## Common API Mistakes to Avoid
| Wrong | Why | Right |
|---|---|---|
| `(t, y), = sim.run(...)` | `sim.run()` returns a generator, not a tuple | `for (t, y), in sim(...):` |
| `for (t1, y1), (t2, y2) in sim(...)` when monitors have different periods | One monitor may yield `None`, causing unpack error | Check `is not None` per monitor |
| `conduction_speed=4.0` passed to `Simulator()` | Must be set on `Connectivity`, not `Simulator` | `conn.speed = numpy.array([4.0]); conn.configure()` |
| `simulation_length=1e3` passed to `Simulator()` | Must be passed to `sim(...)` call, not constructor | `sim(simulation_length=1e3)` |
| `numpy.concatenate([a[0] for a in data])` on scalar times | `concatenate` needs arrays, not 0-d scalars | `numpy.array([a[0] for a in data])` |
