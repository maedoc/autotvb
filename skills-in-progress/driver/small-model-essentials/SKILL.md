---
name: small-model-essentials
description: Critical TVB API facts and rules for 8B models with limited (32K) context. Load this INSTEAD of the full skill set. Contains only must-know facts that prevent catastrophic failures.
---

# TVB Essentials for Small Models

## Critical API Facts — GET THESE RIGHT OR CRASH

1. **`sim.run()` returns a LIST**, not a generator. Always unpack as:
   ```python
   (t1, d1), (t2, d2) = sim.run(simulation_length=T)
   ```

2. **Conduction speed** goes on Connectivity, NOT Simulator:
   ```python
   conn.speed = numpy.array([4.0])
   conn.configure()
   ```
   Never pass `conduction_speed` to `Simulator()`.

3. **Always `configure()`** objects before using them:
   ```python
   conn.configure()
   model = models.Generic2dOscillator()
   sim.configure()
   ```

4. **Multi-monitor unpacking**: one (time, data) pair per monitor:
   ```python
   mon_raw = monitors.Raw()
   mon_tavg = monitors.TemporalAverage()
   (t_raw, d_raw), (t_tavg, d_tavg) = sim.run(...)
   ```

## Minimum Simulation Durations

| Goal type | Absolute minimum | Recommended |
|-----------|-----------------|-------------|
| ERP / stimulus response | 2000 ms | 4000 ms |
| PSD / spectral analysis | 4000 ms | 8000 ms |
| BOLD FC (76 regions) | 240,000 ms (4 min) | 480,000 ms |
| Parameter sweep | 2000 ms per point | varies |
| Stochastic / noise | 4000 ms | 8000 ms |

## Notebook Serialization

In `.ipynb` JSON, code cell sources use array format with real newlines:
```json
"source": ["x = 1\n", "y = 2\n"]
```
Never use literal `\n` in a single string: `"x = 1\ny = 2"` — this causes `SyntaxError`.

## Additional Rules

- Use deterministic integrators (`HeunDeterministic`) unless noise requested
- `nsig` shape must match model's state variables: `numpy.array([v, v])` for 2-variable models
- Stimulus weights: use explicit indexing `stim_weights[[35, 36], 0] = numpy.array([v1, v2])`
- Burn-in must not swallow stimulus: max 100 ms pre-stimulus discard
- Focused analysis: only plots/data the goal explicitly asks for
