---
name: tvb-navigator
description: Guide a TVB workflow implementation by a coding agent. Use when the task involves planning, quality assurance, scientific review, or step-by-step decomposition of whole-brain modeling tasks in The Virtual Brain (TVB). Triggers on neuroimaging, neural-mass models, connectivity, stimulation, resting-state networks, epilepsy modeling, evoked responses, and BOLD/fMRI/EEG forward modeling.
---

# TVB Navigator Skill

## Core Vocabulary
- **Model**: `Generic2dOscillator`, `Epileptor`, `JansenRit`, `ReducedWongWang`, `Kuramoto`
- **Connectivity**: 76-region Hagmann (default), surface meshes, custom matrices
- **Coupling**: `Linear`, `Difference`
- **Integrator**: `HeunDeterministic`, `HeunStochastic`, `EulerDeterministic`
- **Monitor**: `TemporalAverage`, `Bold`, `EEG`, `MEG`, `iEEG`
- **Stimulus**: `StimuliRegion`, `StimuliSurface`, `PulseTrain`, `Gaussian`

## Parameter Sanity Checks
| Model | Key parameters | Typical regime |
|---|---|---|
| Generic2dOscillator | a, b, c, d | Stable spiral: a≈-0.5, b≈-15, d≈0.02 |
| Epileptor | x0, Ks, Kf, r | Interictal: x0≈-2.4; Ictal: x0≈-1.6 |
| ReducedWongWang | a, w, I_o | Excitatory: a≈0.27, I_o≈0.32 |
| JansenRit | A, B, a, b, nu_max, r, J, a_1..a_6 | Default values usually OK |

## Review Checklist
When reviewing driver output, verify:
1. Did driver call `configure()` on connectivity / stimulus / simulator?
2. Are coupling scaling values realistic (e.g. `Linear(a=0.0154)` for G2D on default conn)?
3. Is monitor period compatible with integrator dt?
4. Is stimulus onset > 0 and stimulus tau reasonable?
5. Are plots labeled and do they address the scientific question?
6. Does `noise.Additive(nsig=...)` have one element per model state variable (e.g. 2 for Generic2dOscillator)?
7. Do parameter values in markdown prose exactly match the literal values in the corresponding code cells?

## Planning Template
For any scientific question, produce:
1. **Model choice**: Which neural-mass model and why
2. **Connectivity**: Default 76 or custom; speed value
3. **Coupling**: Type and scaling
4. **Stimulation** (if any): Region IDs, temporal equation, parameters
5. **Integration**: Deterministic vs stochastic; dt; noise level
6. **Monitors**: What to record and at what sampling rate
7. **Analysis / plots**: Expected visualizations
8. **Termination criteria**: How to know the simulation succeeded
