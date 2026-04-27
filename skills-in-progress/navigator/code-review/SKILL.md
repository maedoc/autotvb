---
name: tvb-navigator-code-review
description: Review TVB code output from a coding agent. Use when checking driver-generated notebooks for correctness, syntax validity, prose/code consistency, and common TVB-specific bugs. Triggers on review, correctness, code quality, feedback, checklist, verify, inspect.
---

# TVB Navigator: Code Review Checklist

When reviewing driver output, verify:
1. Did driver call `configure()` on connectivity / stimulus / simulator?
2. Are coupling scaling values realistic (e.g. `Linear(a=0.0154)` for G2D on default conn)?
3. Is monitor period compatible with integrator dt?
4. Is stimulus onset > 0 and stimulus tau reasonable?
5. Are plots labeled and do they address the scientific question?
6. Does `noise.Additive(nsig=...)` have one element per model state variable (e.g. 2 for Generic2dOscillator, 6 for Epileptor, 1 for JansenRit, 2 for ReducedWongWang)?
7. Do parameter values in markdown prose exactly match the literal values in the corresponding code cells?
8. Before accepting completion, visually inspect every code cell for syntax validity and look for stray concatenated statements or empty-string fragments.
9. **Burn-in vs. stimulus timing**: If a stimulus is used, flag any burn-in window that reaches or exceeds the stimulus onset (e.g., 1000 ms burn-in with 500 ms onset). The evoked response must remain in the data.
10. **Analysis window alignment**: For stimulus-propagation goals, verify FC / PSD is computed on a post-stimulus window, not the full trace or an arbitrary post-burn-in interval.
11. **Regime verification**: If the driver claims a specific Hz regime or dynamical state (e.g., "stable spiral", "10 Hz limit cycle"), confirm the computed PSD or amplitude envelope supports it.

## Prose/Code Drift Guard
If markdown says "amp = 1e-3", the code must literally set `1e-3`. Flag any mismatch immediately.

## Output/Claim Drift Guard
If prose claims a 10 Hz spiral regime, the PSD summary must show a peak within 1 Hz of 10 Hz. If prose claims stimulus-evoked FC, the analysis window must start at or after stimulus onset.
