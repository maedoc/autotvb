---
name: tvb-driver-noise-integrator
description: Configure numerical integrators and noise in TVB. Use when choosing between deterministic/stochastic integration, setting dt, or defining noise covariance. Triggers on `integrators.`, `noise.Additive`, `noise.Multiplicative`, `nsig`, `dt`, `HeunStochastic`, `EulerDeterministic`.
---

# TVB Driver: Noise & Integrator Configuration

## Standard Stochastic Setup
```python
# Generic2dOscillator has 2 state variables → nsig must have length 2
hiss = noise.Additive(nsig=numpy.array([0.015, 0.015]))
heunint = integrators.HeunStochastic(dt=2**-6, noise=hiss)
```

## Common Pitfalls
- **Wrong dt**: Typical dt is 2**-4 to 2**-6. Larger dt causes instability.
- **Monitor period mismatch**: `period` must be an integer multiple of `dt`.
- **Noise `nsig` shape**: `noise.Additive(nsig=...)` needs one element per model state variable. Generic2dOscillator requires `numpy.array([σ, σ])`, not a scalar or length-1 array.
- Epileptor has 6 state variables → `nsig` needs length 6.
- JansenRit has 1 state variable → `nsig` needs length 1.
- ReducedWongWang has 2 state variables → `nsig` needs length 2.

## Debugging
- Use `simulator.Simulator(..., monitors=(monitors.ProgressLogger(period=10.0), ...))` to see progress.
