# Paper-Grounded Goal: Systematic Parameter Space Exploration for Optimal Brain Dynamics

**Source:** Falcon MI, et al. (2016, eNeuro); Triebkorn P, et al. (2020, bioRxiv); Deco G, et al. (multiple papers)

## Task
Implement a generic parameter space exploration pipeline in TVB to identify optimal working points for whole-brain dynamics, following the methodology used across multiple TVB clinical papers. Use the Generic2dOscillator model and explore the global coupling vs conduction velocity plane.

## Required Methods

### 1. Model Setup
- Use `models.Generic2dOscillator()` with default parameters (`a=-0.5, b=-15.0, c=0.0, d=0.02`).
- Default connectivity from `connectivity.Connectivity.from_file()` with `conn.speed` varied.
- Integrator: `HeunStochastic(dt=2**-6, noise=noise.Additive(nsig=numpy.array([0.015, 0.015])))`.
- Use `monitors.TemporalAverage(period=5.0)`.

### 2. Parameter Space Definition
Define a 2D grid:
- **Global coupling strength** `G`:
  - The coupling scaling factor applied to `coupling.Linear(a=numpy.array([0.0154 * G]))`
  - Range: `[0.005, 0.01, 0.015, 0.02, 0.025, 0.03, 0.04, 0.05, 0.06, 0.08, 0.10]`
- **Conduction velocity** `cv`:
  - Set via `conn.speed = numpy.array([cv])` before `conn.configure()`
  - Range: `[1.0, 2.0, 3.0, 4.0, 6.0, 8.0, 10.0, 15.0, 20.0]` mm/ms

Total grid points: 11 × 9 = 99 simulations.

### 3. Short Simulation per Grid Point
For each `(G, cv)` pair:
- Run `simulation_length=3000` ms
- Discard first 500 ms as burn-in
- From the remaining 2500 ms, compute:
  - **Global variance** = mean variance of the time series across all 76 regions
  - **Mean correlation** = mean Pearson correlation between all region pairs (post-burn-in)
  - **Metastability index** = standard deviation of the Kuramoto order parameter computed in sliding windows of 100 ms with 50% overlap
  - **Dominant frequency** = peak frequency from Welch PSD of the global mean signal

### 4. Heatmap Visualization (REQUIRED)
Produce FOUR heatmaps, each showing the parameter value as a function of `G` (x-axis) and `cv` (y-axis):
- (a) Global variance
- (b) Mean correlation
- (c) Metastability index
- (d) Dominant frequency

Use `matplotlib.imshow` or `pcolormesh` with a colorbar for each.

### 5. Optimal Working Point Identification (REQUIRED)
Following the papers:
- Identify the region of parameter space with **high global variance** AND **high metastability**. This corresponds to rich, flexible dynamics (the "edge of chaos" or working point).
- Mark this region on the heatmaps with a white circle or annotation.
- Report the `(G, cv)` coordinates of this optimal point.
- Run a FINAL longer simulation (`simulation_length=10000` ms) at this optimal point and produce:
  - A sample time series plot (4 representative regions)
  - The FC matrix
  - The PSD of the global mean signal

### 6. Scientific Discussion
The paper by Triebkorn et al. (2020) argues that different empirical measures (fMRI BOLD, EEG alpha, MEG beta) converge on similar optimal working points. Discuss whether your exploration shows a clear optimal region or whether the dynamics vary smoothly across the parameter space.

## Prohibited Shortcuts
- Do NOT use a single `(G, cv)` pair without exploration.
- Do NOT compute global variance on the burn-in period.
- Do NOT skip any of the four heatmaps.
- Do NOT skip the final validation simulation at the optimal point.

## Expected Output
A notebook with: (1) parameter grid definition, (2) short simulation loop (may take time — at minimum show the algorithm), (3) four labeled heatmaps, (4) annotated optimal point, (5) final long simulation with time series, FC, and PSD.
