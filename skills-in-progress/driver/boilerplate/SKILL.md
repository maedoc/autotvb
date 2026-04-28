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
Every TVB simulation follows this pattern:
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
heunint = integrators.HeunDeterministic(dt=2**-4)

# 5. Monitors
mon_raw = monitors.Raw(period=0.5)
mon_avg = monitors.TemporalAverage(period=5.0)

# 6. Simulator
sim = simulator.Simulator(
    model=model,
    connectivity=conn,
    coupling=coup,
    integrator=heunint,
    monitors=(mon_raw, mon_avg)
)
sim.configure()

# 7. Run
# Option A: sim.run() returns a LIST of monitor result tuples.
# Best for: standard post-hoc analysis after the full simulation.
(t_raw, y_raw), (t_avg, y_avg) = sim.run(simulation_length=1e3)

# Option B: sim() is a generator yielding per-step monitor tuples.
# Best for: custom per-step logic, streaming, or when monitors have different periods.
raw_data = []
avg_data = []
for monitor_tuple in sim(simulation_length=1e3):
    if monitor_tuple[0] is not None:
        raw_data.append(monitor_tuple[0])
    if monitor_tuple[1] is not None:
        avg_data.append(monitor_tuple[1])
# Convert collected tuples to arrays
if raw_data:
    t_raw = numpy.array([r[0] for r in raw_data])
    y_raw = numpy.array([r[1] for r in raw_data])
if avg_data:
    t_avg = numpy.array([a[0] for a in avg_data])
    y_avg = numpy.array([a[1] for a in avg_data])
```

## Critical Rules
- **Always `configure()`** connectivity before running.
- **Array wrapping**: Parameters must be numpy arrays, even scalars: `numpy.array([value])`.
- **Region numbering**: Default connectivity has 76 regions. V1/V2 are usually regions 35, 36.
- **Prose/code drift**: If markdown says "amp = 1e-3", the code must literally set `amp` to `1e-3`.
- **Conduction speed** belongs on `Connectivity`, NOT `Simulator()`: `conn.speed = numpy.array([4.0]); conn.configure()`.
- **simulation_length** belongs on `sim(...)` or `sim.run(...)`, NOT in the `Simulator()` constructor.

## Common API Mistakes to Avoid
| Wrong | Why | Right |
|---|---|---|
| `conduction_speed=4.0` in `Simulator(...)` | Must be set on `Connectivity` | `conn.speed = numpy.array([4.0]); conn.configure()` |
| `simulation_length=1e3` in `Simulator(...)` | Must be in `sim(...)` or `sim.run(...)` | `sim.run(simulation_length=1e3)` |
| `numpy.concatenate([a[0] for a in data])` on scalar times | `concatenate` fails for 0-d scalars | `numpy.array([a[0] for a in data])` |
| `for (t1, y1), (t2, y2) in sim(...)` when periods differ | A monitor may yield `None`, cannot unpack | Use None-safe check per index |
