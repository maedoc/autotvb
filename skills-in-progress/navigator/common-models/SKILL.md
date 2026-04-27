---
name: tvb-navigator-common-models
description: Quick-reference vocabulary for TVB neural-mass models, connectivity types, coupling functions, integrators, monitors, and stimuli. Use when naming or selecting TVB components. Triggers on model names, monitor types, integrator names, coupling types.
---

# TVB Navigator: Component Vocabulary

## Models
- `Generic2dOscillator` — 2D limit-cycle oscillator (alpha/beta rhythms)
- `Epileptor` — 6D seizure model (interictal ↔ ictal transitions)
- `JansenRit` — 3D canonical neural mass (ERP/ERF)
- `ReducedWongWang` — 2D mean-field excitatory/inhibitory (resting-state)
- `Kuramoto` — phase oscillator (synchrony studies)

## Connectivity
- `connectivity.Connectivity.from_file()` — 76-region Hagmann (default)
- Custom: load from `.zip` or NumPy matrix

## Coupling
- `Linear` — standard linear coupling
- `Difference` — difference-based coupling

## Integrators
- `HeunDeterministic` — 2nd-order deterministic
- `HeunStochastic` — 2nd-order stochastic (needs noise)
- `EulerDeterministic` — 1st-order deterministic

## Monitors
- `TemporalAverage` — raw state-variable average
- `Bold` — BOLD/fMRI HRF convolution
- `EEG`, `MEG`, `iEEG` — forward-modeled sensor signals

## Stimuli
- `StimuliRegion` — point stimulation on regions
- `StimuliSurface` — distributed stimulation on surface
- `PulseTrain` — repetitive pulse temporal profile
- `Gaussian` — Gaussian-shaped temporal profile
