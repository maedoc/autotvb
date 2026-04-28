---
name: tvb-driver-heterogeneous-params
description: Region-specific parameters for EZ/PZ, genotype groups, or drug effects. Use when goal mentions "region-specific", "EZ", "PZ", "heterogeneous", "genotype", "focal". Triggers on spatial map, tiers.
---

# Region-Specific Parameter Patterns

## Base Pattern

```python
import numpy
from tvb.simulator.lab import *

conn = connectivity.Connectivity.from_file()
n_regions = conn.weights.shape[0]
```

## Epileptor x0 Tiers

```python
x0 = numpy.full((n_regions,), -2.4)
# Use region labels for safety (0-indexed)
labels = conn.region_labels.tolist()
rHC = labels.index('rHippocampus')   # verify label spelling
rPHC = labels.index('rParahippocampal')
rAMYG = labels.index('rAmygdala')
rTCI = labels.index('rTempInf')
rTCV = labels.index('rTempVentral')

x0[[rHC, rPHC, rAMYG]] = -1.6   # EZ
x0[[rTCI, rTCV]] = -1.8          # PZ
model = models.Epileptor(x0=x0)
```

## Aβ → Parameter Modulation

```python
abeta = numpy.full((n_regions,), 0.1)
hub_regions = [labels.index('Precuneus'), labels.index('PostCingulate'), ...]
adjacent = [...]
abeta[hub_regions] = 0.8
abeta[adjacent] = 0.4

a_base = -0.5
a_effective = a_base + 0.3 * abeta
# Print the map for verification
for i in range(n_regions):
    print(f"{labels[i]:20s}: {a_effective[i]:.3f}")
model = models.Generic2dOscillator(a=a_effective)
```

## Genotype Configs

```python
configs = {
    'A/A': {'G': 0.045, 'a': -0.5},
    'A/G': {'G': 0.040, 'a': -0.55},
    'G/G': {'G': 0.035, 'a': -0.6},
}
for genotype, cfg in configs.items():
    coup = coupling.Linear(a=numpy.array([0.0154 * cfg['G']]))
    model = models.Generic2dOscillator(a=numpy.array([cfg['a']]))
    # ... build sim, run, store metrics
```

## Focal Input Override

```python
# WilsonCowan: set Q=0 in target regions only
Q = numpy.full((n_regions,), 1.0)
Q[[dlpfc_left, dlpfc_right]] = 0.0
model = models.WilsonCowan(Q=Q)
```

## Multi-Condition Scaffold

```python
conditions = {
    'Control': {'param': numpy.full((n_regions,), base)},
    'Cond_A': {'param': param_A},
}
all_fcs = {}
for name, cfg in conditions.items():
    model = models.Generic2dOscillator(param=cfg['param'])
    # ... sim, run
    (t, y), = sim.run(simulation_length=10000)
    fc = numpy.corrcoef(y[100:].T)
    all_fcs[name] = fc
    print(f"{name}: mean FC = {fc.mean():.4f}")

print("| Condition | Mean FC |")
print("|---|---|")
for name in all_fcs:
    print(f"| {name} | {all_fcs[name].mean():.3f} |")
```

## Critical Rules
- Never use a scalar when heterogeneity is required.
- Region labels are 0-indexed; paper region numbers may be 1-indexed.
- Only override the specific varying parameter; keep others at defaults.
