---
name: tvb-driver-parameter-sweep
description: Systematic parameter space exploration for TVB whole-brain models. Use when a goal requires comparing simulation outcomes across a grid of parameter values (e.g., global coupling G × conduction velocity cv, G × noise amplitude, or x0 grid search). Triggers on phrases like "parameter space", "explore", "optimal working point", "heatmap", "grid search", "sweep".
---

# TVB Driver: Parameter Sweep & Grid Search

## Parameter Grid Pattern

When a goal requires exploring a parameter space, use this scaffold:

```python
import numpy
import matplotlib.pyplot as plt
from tvb.simulator.lab import *

# Define parameter grid
param1_values = numpy.linspace(start1, stop1, n1)  # e.g., G coupling
param2_values = numpy.linspace(start2, stop2, n2)    # e.g., cv speed

# Results storage: matrix shaped (n1, n2)
results = numpy.zeros((len(param1_values), len(param2_values)))

for i, p1 in enumerate(param1_values):
    for j, p2 in enumerate(param2_values):
        # --- Rebuild simulation with current parameters ---
        conn = connectivity.Connectivity.from_file()
        conn.speed = numpy.array([p2])   # example: param2 = cv
        conn.configure()

        model = models.Generic2dOscillator(...)  # or appropriate model
        coup = coupling.Linear(a=numpy.array([0.0154 * p1]))  # example: param1 = G scaling

        heun = integrators.HeunStochastic(
            dt=2**-6,
            noise=noise.Additive(nsig=numpy.array([0.015, 0.015]))
        )

        sim = simulator.Simulator(
            model=model,
            connectivity=conn,
            coupling=coup,
            integrator=heun,
            monitors=(monitors.TemporalAverage(period=5.0),)
        )
        sim.configure()

        # Run SHORT simulation for the sweep
        (t, y), = sim.run(simulation_length=3000)

        # Discard burn-in if needed
        y_post = y[100:]  # discard first 100 samples (~500ms for period=5)

        # --- Compute scalar metric ---
        # Choose ONE metric appropriate to the goal:
        #   (a) Global variance = mean variance across regions
        metric = numpy.var(y_post, axis=0).mean()
        #   (b) Mean Pearson correlation (FC mean)
        #   (c) Metastability = std of Kuramoto order parameter
        #   (d) MSE vs target (for fitting tasks)
        #   (e) MAE vs structural connectivity
        results[i, j] = metric
```

## Heatmap Visualization

Always produce a labeled heatmap so the optimal region is visible:

```python
fig, ax = plt.subplots(figsize=(6, 5))
im = ax.imshow(
    results,
    aspect='auto',
    origin='lower',
    extent=[param2_values[0], param2_values[-1], param1_values[0], param1_values[-1]]
)
ax.set_xlabel("Parameter 2 label")
ax.set_ylabel("Parameter 1 label")
plt.colorbar(im, ax=ax, label="Metric name")
ax.set_title("Parameter Space Exploration")

# Mark optimal point
opt_idx = numpy.unravel_index(numpy.argmax(results), results.shape)
# or argmin for MSE/MAE
opt_p1, opt_p2 = param1_values[opt_idx[0]], param2_values[opt_idx[1]]
ax.plot(opt_p2, opt_p1, 'w*', markersize=15, label=f"Optimum: ({opt_p2:.3f}, {opt_p1:.3f})")
ax.legend()
plt.tight_layout()
plt.show()

print(f"Optimal parameters: param1={opt_p1:.4f}, param2={opt_p2:.4f}")
```

## Metric Selection Guide

| Metric | When to use | Code snippet |
|---|---|---|
| **Global variance** | Find richest dynamics (edge-of-chaos working point) | `numpy.var(y, axis=0).mean()` |
| **Mean correlation** | Compare functional connectivity strength | `numpy.corrcoef(y.T).mean()` |
| **Metastability** | Quantify state-switching flexibility | Compute Kuramoto order parameter in sliding windows; take std |
| **MSE** | Model fitting / inversion | `numpy.mean((simulated - target)**2)` |
| **MAE** | Robust fitting vs structural connectivity | `numpy.mean(numpy.abs(sim_FC - sc_weights))` |

## Critical Rules

- **Rebuild the simulator inside the loop** — you cannot change `conn.speed` or coupling strength on an already-configured simulator. Create a fresh `Simulator(...)` each iteration.
- **Keep sweep simulations SHORT** — use `simulation_length=3000` (3 s) or `4000` for parameter exploration. Long BOLD or full-clinical runs come AFTER selecting optimal parameters.
- **Use a deterministic seed if reproducibility matters**: `numpy.random.seed(42)` before each sim run, or use `HeunDeterministic`.
- **Always print intermediate progress**: inside the loop, print `f"p1={p1:.3f}, p2={p2:.3f} → metric={metric:.4f}"` so execution logs show progress.
- **For per-region heterogeneous parameters**, create a full-length array before the loop:
  ```python
  a_map = numpy.full((76,), -0.5)  # base value for all 76 regions
  a_map[ez_regions] = -0.3         # override for EZ
  model = models.Generic2dOscillator(a=a_map)
  ```

## Common Mistakes to Avoid

| Wrong | Right |
|---|---|
| Reusing one `sim` object across parameter changes | Create new `Simulator(...)` each iteration |
| Forgetting `conn.configure()` after changing `conn.speed` | Always `conn.configure()` before building simulator |
| Sweeping with `simulation_length=10000` | Keep sweep short; run final validation long |
| `argmax` on MAE or MSE | Use `argmin` for error metrics, `argmax` for variance/metastability |
| Single simulation point with "optimal" claim | Must show full heatmap with annotated optimum |
