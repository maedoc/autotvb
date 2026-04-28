---
name: tvb-driver-heterogeneous-params
description: Region-specific parameter assignment for focal pathologies, genotype groups, or drug effects in TVB whole-brain models. Use when a goal requires different parameter values in different brain regions (e.g., epileptogenic zone vs propagation zone, sham vs drug conditions, genotype-specific excitability). Triggers on phrases like "region-specific", "focal", "EZ", "PZ", "heterogeneous", "spatial map", "tiers", "genotype".
---

# TVB Driver: Heterogeneous & Region-Specific Parameters

## Core Pattern

TVB models accept numpy arrays for most parameters, where array length equals the number of regions (76 for default connectivity). This allows spatial heterogeneity:

```python
import numpy
from tvb.simulator.lab import *

n_regions = connectivity.Connectivity.from_file().weights.shape[0]  # 76 for default

# Base value for all regions
base_value = -0.5
param_array = numpy.full((n_regions,), base_value)

# Override subsets
param_array[ez_regions] = -1.6    # Epileptogenic Zone
param_array[pz_regions] = -1.8    # Propagation Zone
param_array[healthy_regions] = -2.4

model = models.Generic2dOscillator(a=param_array)
```

## Common Heterogeneity Patterns

### 1. Epileptor x0 Tiers (EZ / PZ / Healthy)

Used in VEP and Bayesian epilepsy goals.

```python
# Region indices (default Desikan-Killiany ordering; VERIFY these indices)
rHC = 46   # right hippocampus  (~47 in 0-indexed)
rPHC = 61  # right parahippocampus
rAMYG = 39 # right amygdala
rTCI = 68  # right inferior temporal
rTCV = 71  # right ventral temporal

x0 = numpy.full((76,), -2.4)
x0[[rHC, rPHC, rAMYG]] = -1.6   # EZ
x0[[rTCI, rTCV]] = -1.8          # PZ

model = models.Epileptor(x0=x0)
```

**Region index warning**: Paper descriptions often use 1-indexed region numbers. TVB arrays are 0-indexed. Always subtract 1 from paper region numbers, or use region labels:

```python
# Safer: lookup by label
conn = connectivity.Connectivity.from_file()
labels = conn.region_labels.tolist()
rHC = labels.index('rHippocampus')   # verify exact label spelling
```

### 2. Aβ Burden → Parameter Modulation

Used in Alzheimer's goals. A spatial map modulates a model parameter.

```python
# Synthetic Aβ map (replace with empirical PET data when available)
abeta = numpy.full((76,), 0.1)   # low baseline
hub_regions = [precuneus_idx, postcing_idx, medfront_idx, ...]
adjacent = [...]  # regions adjacent to hubs
abeta[hub_regions] = 0.8
abeta[adjacent] = 0.4

# Modulate excitability parameter `a`
a_base = -0.5
a_effective = a_base + 0.3 * abeta  # paper-defined sensitivity

# Report the map in a markdown table for reproducibility
```

**Best practice**: Always print the exact heterogeneous map so the evaluator can verify it:

```python
import pandas as pd
map_df = pd.DataFrame({
    'region': conn.region_labels,
    'param_value': param_array
})
print(map_df.to_markdown())
```

### 3. Genotype-Dependent Parameters

Used in schizophrenia and similar multi-group comparisons.

```python
# Define parameter sets per group
genotype_configs = {
    'A/A': {'G': 0.045, 'a': -0.5},
    'A/G': {'G': 0.040, 'a': -0.55},
    'G/G': {'G': 0.035, 'a': -0.6},
}

# Run one simulation per config
results = {}
for genotype, cfg in genotype_configs.items():
    coup = coupling.Linear(a=numpy.array([0.0154 * cfg['G']]))
    model = models.Generic2dOscillator(a=numpy.array([cfg['a']]))
    # ... build sim, run, store metric
    results[genotype] = metric
```

### 4. Focal Stimulation / Drug Targets

Used in tDCS and rTMS goals: alter input to specific regions only.

```python
# For Wilson-Cowan: reduce inhibitory input Q in target regions
Q = numpy.full((76,), 1.0)
Q[[dlpfc_left, dlpfc_right, ofc_left, ofc_right, v1_left, v1_right]] = 0.0
model = models.WilsonCowan(Q=Q)
```

## Multi-Condition Comparison Scaffold

When a goal requires running N configurations (e.g., sham, drug, heterogeneous, homogeneous):

```python
conditions = {
    'Control': {'param': numpy.full((76,), base_value)},
    'Condition_A': {'param': param_A},
    'Condition_B': {'param': param_B},
}

all_time_series = {}
all_fcs = {}

for name, cfg in conditions.items():
    model = models.Generic2dOscillator(param=cfg['param'])
    # ... build sim, run
    (t, y), = sim.run(simulation_length=10000)
    all_time_series[name] = y
    # Compute FC
    fc = numpy.corrcoef(y[100:].T)
    all_fcs[name] = fc
    print(f"{name}: mean FC = {fc.mean():.4f}")

# Produce comparison table
print("| Condition | Metric1 | Metric2 |")
print("|---|---|---|")
for name in conditions:
    print(f"| {name} | {m1:.3f} | {m2:.3f} |")
```

## Critical Rules

- **Never use a single scalar** when the goal specifies heterogeneous values across regions.
- **Verify region count**: default is 76, but custom connectivities may differ. Use `conn.weights.shape[0]`.
- **Document the map**: print or plot the parameter distribution so the evaluator can verify your heterogeneity matches the goal.
- **Array dtype**: TVB expects `numpy.array([...])` of floats; boolean or integer indexing is fine for assignment.
- **Keep base parameter in model defaults**: only override the specific parameter that varies (e.g., `x0` or `a`). Leave others at TVB defaults.

## Common Mistakes to Avoid

| Wrong | Right |
|---|---|
| `model.x0 = -1.6` (scalar) | `model = models.Epileptor(x0=x0_array)` with 76-element array |
| `x0[47] = -1.6` (paper says region 47 = rHC) | `x0[46] = -1.6` (0-indexed) or use `labels.index()` |
| Modifying all 76 parameters when only one varies | Keep base value, only override target regions |
| Hard-coding 76 without checking | `n_regions = conn.weights.shape[0]` |
