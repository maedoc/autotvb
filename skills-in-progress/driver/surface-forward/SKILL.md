---
name: tvb-driver-surface-forward
description: Surface simulations and forward modeling for EEG, MEG, and sEEG in TVB. Use when the task involves cortical surface meshes, region mappings, or generating sensor-level signals. Triggers on `Cortex`, `RegionMapping`, `SensorsEEG`, `ProjectionSurfaceEEG`, `SensorsMEG`, `SensorsInternal`.
---

# TVB Driver: Surface Simulation & Forward Modeling

## Surface Simulation Setup
```python
from tvb.datatypes.cortex import Cortex
from tvb.datatypes.region_mapping import RegionMapping
from tvb.datatypes.projections import ProjectionMatrix, ProjectionSurfaceEEG
from tvb.datatypes.sensors import SensorsEEG

cortex = Cortex.from_file(region_mapping_file='regionMapping_16k_76.txt')
rm = RegionMapping.from_file('regionMapping_16k_76.txt')

# Build surface simulator replacing conn with cortex
sim = simulator.Simulator(
    model=model,
    surface=cortex,
    coupling=coup,
    integrator=heunint,
    monitors=mon
)
sim.configure()
```

## EEG Forward Model
```python
sensorsEEG = SensorsEEG.from_file('eeg_unitvector_62.txt.bz2')
prEEG = ProjectionSurfaceEEG.from_file('projection_eeg_62_surface_16k.mat')

mon_eeg = monitors.EEG(
    sensors=sensorsEEG,
    projection=prEEG,
    region_mapping=rm,
    period=5.0
)
```

## Key Points
- Surface simulations are slower than region simulations; keep `simulation_length` moderate when testing.
- Make sure `region_mapping` file matches the connectivity region count.
- Forward monitors (`EEG`, `MEG`, `iEEG`) require both sensors and projection matrix files.
