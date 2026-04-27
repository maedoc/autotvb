---
name: tvb-navigator-scientific-validity
description: Assess whether TVB parameter choices, model selection, and analysis are scientifically appropriate for the neuroscience question. Use when evaluating model regimes, parameter sanity, or whether results address the stated goal. Triggers on scientific validity, parameters, regime, model choice, realistic, appropriate.
---

# TVB Navigator: Scientific Validity & Parameter Regimes

## Model Parameter Regimes
| Model | Key parameters | Typical regime |
|---|---|---|
| Generic2dOscillator | a, b, c, d | Stable spiral: a≈-0.5, b≈-15, d≈0.02 |
| Epileptor | x0, Ks, Kf, r | Interictal: x0≈-2.4; Ictal: x0≈-1.6 |
| ReducedWongWang | a, w, I_o | Excitatory: a≈0.27, I_o≈0.32 |
| JansenRit | A, B, a, b, nu_max, r, J, a_1..a_6 | Default values usually OK |

## Validity Checks
- Does the chosen model match the scientific question? (Epileptor for seizure, JansenRit for ERP, G2D for oscillations, RWW for resting-state)
- Is connectivity speed physiologically plausible (1–10 mm/ms)?
- Is coupling strength appropriate for the model and connectivity density?
- Does the analysis match the data type? (BOLD for resting-state FC, TemporalAverage for ERP latencies)
- Are statistical comparisons using appropriate null models or surrogates?

## Regime Verification
Do not accept regime claims from parameter tables alone. Require empirical verification in the notebook:
- Compute PSD and report the dominant peak frequency.
- Inspect the time-series amplitude envelope: sustained = limit cycle; decaying = stable spiral.
- If the driver claims "N Hz", the PSD peak must agree within ±1 Hz.

## Focal Parameterization for Seizure Models
- **Epileptor focal zone**: Do not apply a uniform or randomly distributed `x0` across all regions. The Epileptor requires a focal epileptogenic zone (a small subset of regions with elevated x0, e.g., -1.6) embedded in a surround of more negative x0 (e.g., -2.4 to -2.5). Flag any non-focal x0 parameterization as scientifically invalid.

## Windowing & Stimulus-Locked Analysis
- **Burn-in must be shorter than stimulus onset**: Flag immediately if burn-in ≥ onset (e.g., 1000 ms burn-in with 500 ms onset). The evoked response must remain in the data.
- **Align analysis windows with the scientific question**: For stimulus-propagation studies, FC and spectral analyses should target `[onset, onset + window]`, not arbitrary post-burn-in intervals.
- **Distinguish intrinsic vs. evoked FC**: ongoing oscillations produce structurally-driven FC; a post-stimulus window may show propagation. The driver must state which is being reported.
