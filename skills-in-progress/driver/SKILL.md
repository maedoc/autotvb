---
name: tvb-driver
description: Implement whole-brain modeling workflows with The Virtual Brain (TVB) Python scripting interface. Use when writing TVB simulation code, configuring connectivity, models, coupling, integrators, monitors, stimuli, or analyzing output time series. Triggers on TVB code, tvb.simulator, neural-mass model simulation, region/surface simulation, BOLD/EEG/MEG/iEEG forward modeling.
---

# TVB Driver Skill

## Essential Boilerplate
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
hiss = noise.Additive(nsig=numpy.array([0.015]))
heunint = integrators.HeunStochastic(dt=2**-6, noise=hiss)

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
(t, y), = sim.run(simulation_length=1e3)
```

## Common Pitfalls
- **Forgot `configure()`**: Always call `.configure()` on connectivity, stimulus, and simulator.
- **Wrong dt**: Typical dt is 2**-4 to 2**-6. Larger dt causes instability.
- **Monitor period mismatch**: `period` must be an integer multiple of `dt`.
- **Array wrapping**: Parameters must be numpy arrays, even for scalars: `numpy.array([value])`.
- **Region numbering**: Default connectivity has 76 regions. V1/V2 are usually regions 35, 36.

## Stimulus Definition
```python
stim_weights = numpy.zeros((conn.number_of_regions, 1))
stim_weights[nodes] = numpy.array([3.5, 0.0])[:, numpy.newaxis]

eqn_t = equations.PulseTrain()
eqn_t.parameters["onset"] = 500.0  # ms
eqn_t.parameters["tau"]   = 5.0    # ms
eqn_t.parameters["T"]     = 500.   # repetition interval

stimulus = patterns.StimuliRegion(
    temporal=eqn_t,
    connectivity=conn,
    weight=stim_weights
)
stimulus.configure()
```

## Surface Simulation Extension
```python
from tvb.datatypes.cortex import Cortex
from tvb.datatypes.region_mapping import RegionMapping
from tvb.datatypes.projections import ProjectionMatrix, ProjectionSurfaceEEG
from tvb.datatypes.sensors import SensorsEEG

cortex = Cortex.from_file(region_mapping_file='regionMapping_16k_76.txt')
rm = RegionMapping.from_file('regionMapping_16k_76.txt')
sensorsEEG = SensorsEEG.from_file('eeg_unitvector_62.txt.bz2')
prEEG = ProjectionSurfaceEEG.from_file('projection_eeg_62_surface_16k.mat')
```

## Debugging
- Check `sim.model_info` for parameter names and defaults.
- Use `simulator.Simulator(..., monitors=(monitors.ProgressLogger(period=10.0), ...))` to see progress.
