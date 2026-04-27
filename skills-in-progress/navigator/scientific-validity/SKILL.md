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
