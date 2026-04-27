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
12. **Notebook serialization**: Verify `.ipynb` code cell sources are arrays of strings with real line breaks, not a single string containing literal `\n` characters that Python would interpret as line continuations.
13. **Python string hygiene**: Flag any code cell containing a multi-line string literal formed by an actual newline inside double quotes.
14. **Scope discipline**: Flag analyses or plots not directly required by the current goal; reject gratuitous supplementary statistics.
15. **API existence check**: Verify that every TVB class used actually exists (e.g., `monitors.iEEG` does not exist; forward intracranial recordings use `monitors.SEEG`). Flag references to nonexistent API symbols immediately.
16. **Multi-monitor unpacking**: If the simulator is initialized with a tuple of `len(monitors) > 1`, ensure `sim.run()` is unpacked into that many `(time, data)` pairs. `(t, y), = sim.run(...)` is only valid for a single monitor.
17. **Stimulus weight shape safety**: Verify `weight` array assignments use explicit indexing that matches the declared shape (e.g., `stim_weights[[35, 36], 0] = values`), not fragile broadcasts like `stim_weights[nodes] = values[:, numpy.newaxis]`.
18. **Epileptor focality**: For any Epileptor simulation, confirm `x0` defines a focal epileptogenic zone (a subset of regions with elevated x0) rather than a uniform or random distribution across all regions.

## Prose/Code Drift Guard
If markdown says "amp = 1e-3", the code must literally set `1e-3`. Flag any mismatch immediately.

## Output/Claim Drift Guard
If prose claims a 10 Hz spiral regime, the PSD summary must show a peak within 1 Hz of 10 Hz. If prose claims stimulus-evoked FC, the analysis window must start at or after stimulus onset.
