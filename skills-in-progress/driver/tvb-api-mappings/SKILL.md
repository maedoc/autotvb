---
name: tvb-driver-tvb-api-mappings
description: Paper parameter names often differ from actual TVB API trait names. This skill prevents runtime TraitTypeError. Use BEFORE setting any model parameter. Triggers on model names Epileptor, JansenRit, WilsonCowan.
---

# Paper Names → TVB Trait Names

## JansenRit
Paper notation → TVB trait:
- `C1` → `a_1` (pyramidal→pyramidal)
- `C2` → `a_2` (excitatory interneuron→pyramidal)
- `C3` → `a_3` (pyramidal→excitatory interneuron)
- `C4` → `a_4` (inhibitory interneuron→pyramidal)

```python
# WRONG — will raise TraitTypeError
model = models.JansenRit(C1=135.0, C2=108.0, C3=33.75, C4=33.75)

# CORRECT
model = models.JansenRit(a_1=135.0, a_2=108.0, a_3=33.75, a_4=33.75)
```

## Epileptor
Paper notation → TVB trait:
- `tau0` (paper default 2857) → `tau` (TVB trait name)
- `gamma` → `bb`
- `Ks`, `Kf`, `r` — same names in TVB

```python
# WRONG
model = models.Epileptor(tau0=2857.0, gamma=0.01)

# CORRECT
model = models.Epileptor(tau=2857.0, bb=0.01)
```

## WilsonCowan
Paper notation → TVB trait:
- External inputs `P`, `Q` — same names in TVB
- Synaptic constants `c_ee`, `c_ei`, `c_ie`, `c_ii` — same
- Tau constants `tau_e`, `tau_i` — same

## ReducedSetHindmarshRose
Paper SJ3D → TVB: `models.ReducedSetHindmarshRose()`
- `a`, `b`, `c`, `d`, `r`, `s` — same names

## Monitors
- Paper `SEEG` → TVB `monitors.iEEG` (not `SEEG`)
- `monitors.Bold(period=2000.0)` for TR=2s
