---
name: tvb-driver-stimulus
description: Define and configure stimuli in TVB. Use when applying external input to specific regions or surfaces, including PulseTrain, Gaussian, or custom temporal equations. Triggers on `patterns.StimuliRegion`, `patterns.StimuliSurface`, `equations.PulseTrain`, `stimulus`, `weight`, `onset`, `tau`.
---

# TVB Driver: Stimulus Definition

## Region Stimulus Pattern
```python
stim_weights = numpy.zeros((conn.number_of_regions, 1))
stim_weights[nodes] = numpy.array([3.5, 0.0])[:, numpy.newaxis]  # shape must match

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

## Rules
- `onset` must be > 0.
- `tau` should be small (1–20 ms for impulses).
- Weight array shape must be `(n_regions, 1)` or `(n_regions,)` — verify before passing.
- If using multiple stimuli, each needs its own `StimuliRegion` configured separately, then passed to the simulator as a tuple: `sim.stimulus = (stim1, stim2)`.
