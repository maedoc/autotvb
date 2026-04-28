---
name: tvb-driver-parameter-sweep
description: Parameter grid search for TVB. Use when goal mentions "explore", "grid", "sweep", "heatmap", or "optimal working point". Triggers on heatmap, parameter space.
---

# Grid Search Scaffold

```python
import numpy
import matplotlib.pyplot as plt
from tvb.simulator.lab import *

p1_vals = numpy.linspace(min1, max1, n1)  # e.g., G coupling
p2_vals = numpy.linspace(min2, max2, n2)  # e.g., cv speed
results = numpy.zeros((len(p1_vals), len(p2_vals)))

for i, p1 in enumerate(p1_vals):
    for j, p2 in enumerate(p2_vals):
        conn = connectivity.Connectivity.from_file()
        conn.speed = numpy.array([p2])
        conn.configure()

        model = models.Generic2dOscillator(...)  # set needed params
        coup = coupling.Linear(a=numpy.array([0.0154 * p1]))
        heun = integrators.HeunStochastic(dt=2**-6,
            noise=noise.Additive(nsig=numpy.array([0.015, 0.015])))
        sim = simulator.Simulator(
            model=model, connectivity=conn, coupling=coup,
            integrator=heun, monitors=(monitors.TemporalAverage(period=5.0),))
        sim.configure()

        (t, y), = sim.run(simulation_length=3000)
        y_post = y[100:]  # discard burn-in
        metric = numpy.var(y_post, axis=0).mean()  # or other metric
        results[i, j] = metric
        print(f"p1={p1:.3f}, p2={p2:.3f} → metric={metric:.4f}")
```

## Heatmap

```python
fig, ax = plt.subplots(figsize=(6, 5))
im = ax.imshow(results, aspect='auto', origin='lower',
    extent=[p2_vals[0], p2_vals[-1], p1_vals[0], p1_vals[-1]])
ax.set_xlabel("param2"); ax.set_ylabel("param1")
plt.colorbar(im, ax=ax, label="metric")

opt_idx = numpy.unravel_index(numpy.argmax(results), results.shape)
opt_p1, opt_p2 = p1_vals[opt_idx[0]], p2_vals[opt_idx[1]]
ax.plot(opt_p2, opt_p1, 'w*', markersize=15,
        label=f"Opt: ({opt_p2:.3f}, {opt_p1:.3f})")
ax.legend(); plt.tight_layout(); plt.show()
print(f"Optimal: p1={opt_p1:.4f}, p2={opt_p2:.4f}")
```

## Metric Selection

| Task | Metric | Code |
|---|---|---|
| Richest dynamics | Global variance | `numpy.var(y, axis=0).mean()` |
| FC strength | Mean correlation | `numpy.corrcoef(y.T).mean()` |
| Model fitting | MSE vs target | `numpy.mean((sim - target)**2)` |
| Structural fit | MAE vs SC | `numpy.mean(numpy.abs(sim_FC - sc_weights))` |

## Rules
- Rebuild `Simulator(...)` each iteration (can't modify configured sim).
- Keep sweep simulations SHORT (3–4 s). Run final validation LONG after selecting optimum.
- `argmax` for variance/metastability; `argmin` for MSE/MAE.
- Always `conn.configure()` after changing `conn.speed`.
