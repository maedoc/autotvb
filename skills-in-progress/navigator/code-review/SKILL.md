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

## Prose/Code Drift Guard
If markdown says "amp = 1e-3", the code must literally set `1e-3`. Flag any mismatch immediately.
