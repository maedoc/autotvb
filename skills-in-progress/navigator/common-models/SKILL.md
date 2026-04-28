---
name: tvb-navigator-common-models
description: Quick-reference vocabulary for TVB neural-mass models, connectivity types, coupling functions, integrators, monitors, and stimuli. Use when naming or selecting TVB components. Triggers on model names, monitor types, integrator names, coupling types.
---

# TVB Navigator: Component Vocabulary

## Models
- `Generic2dOscillator` — 2D limit-cycle oscillator (alpha/beta rhythms). Parameters: `a, b, c, d`.
- `Epileptor` — 6D seizure model (interictal ↔ ictal transitions). Parameters: `x0, Iext, Iext2, slope, tau, Ks, Kf, r, aa, bb`. **Note**: `tau0` and `tau2` from Jirsa papers map to TVB's `tau`.
- `JansenRit` — 3D canonical neural mass (ERP/ERF). **TVB trait names differ from paper notation**: paper `C1, C2, C3, C4` → TVB `a_1, a_2, a_3, a_4`. Parameters: `A, B, a, b, v0, nu_max, r, J, a_1, a_2, a_3, a_4, p_min, p_max, mu`.
- `WilsonCowan` — 2-population excitatory/inhibitory. Parameters: `c_ee, c_ei, c_ie, c_ii, tau_e, tau_i, a_e, b_e, c_e, a_i, b_i, c_i, P, Q, theta_e, theta_i`. **Note**: `Q` sets inhibitory population external input.
- `ReducedSetHindmarshRose` — TVB 2.x equivalent of Stefanescu-Jirsa 3D (SJ3D). Parameters: `a, b, c, d, r, s`.
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
- `Bold` — BOLD/fMRI HRF convolution. **Constructor**: `monitors.Bold(period=2000.0)` for TR=2s.
- `EEG`, `MEG` — forward-modeled scalp sensors
- `iEEG` — intracranial / stereo-EEG forward solution. **Not** `SEEG`. Default sensors: `seeg_588.txt`.

## Stimuli
- `StimuliRegion` — point stimulation on regions
- `StimuliSurface` — distributed stimulation on surface
- `PulseTrain` — repetitive pulse temporal profile
- `Gaussian` — Gaussian-shaped temporal profile
