---
name: concise-code
description: Write lean, non-redundant TVB notebooks. Use when the driver creates plots or analysis sections to prevent verbose/redundant output that wastes tokens. Triggers on figure, plot, subplot, print, display, verbose, redundant, duplicate analysis.
---

# Concise Code for TVB Notebooks

## Rules

1. **One figure per scientific claim.** If the goal asks for "PSD and FC", make exactly two figure blocks — not five.
2. **No diagnostic prints.** Remove `print(x.shape)`, `print(type(y))`, `print('Step done')` from final notebooks. These are debugging artifacts.
3. **No redundant plots.** If raw and annotated heatmaps show the same data, keep only the annotated one.
4. **Consolidate subplots.** Use `fig, axes = plt.subplots(1, N, ...)` for side-by-side comparisons instead of N separate `plt.figure()` blocks.
5. **No summary cells that repeat earlier output.** A final markdown cell with 2–3 sentence takeaway is fine; do not re-print arrays or re-plot data.
6. **Avoid boilerplate re-configuration.** If `Connectivity.from_file()` + `.speed = 4.0` + `configure()` appears once, don't repeat it in a later cell. Store the object and reuse.

## Code patterns

**Redundant (bad):**
```python
plt.figure(); plt.imshow(fc); plt.colorbar(); plt.title("FC")
plt.figure(); plt.imshow(sc); plt.colorbar(); plt.title("SC")  
plt.figure(); plt.imshow(fc - sc); plt.colorbar(); plt.title("Diff")
```

**Concise (good):**
```python
fig, axes = plt.subplots(1, 3, figsize=(15, 4))
for ax, mat, title in zip(axes, [fc, sc, fc-sc], ["FC", "SC", "FC−SC"]):
    im = ax.imshow(mat, cmap="viridis"); ax.set_title(title)
    plt.colorbar(im, ax=ax)
```

## Token budget

Every code cell costs tokens in the prompt. A 20-cell notebook with 3 redundant sections costs ~20% more tokens for zero scientific gain. Target ≤12 code cells for standard goals, ≤16 for complex multi-requirement goals.