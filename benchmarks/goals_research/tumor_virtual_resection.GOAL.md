# Paper-Grounded Goal: Tumor Resection — Virtual Neurosurgery and Post-surgical FC Prediction

**Source:** Aerts H, Schirner M, Dhollander T, et al. "Modeling brain dynamics after tumor resection using The Virtual Brain." *NeuroImage*, 221:116738, 2020. DOI: 10.1016/j.neuroimage.2020.116738

## Task
Implement a virtual neurosurgery pipeline in TVB: optimize a pre-surgical whole-brain model, simulate tumor resection by removing a region and its connections, then predict post-surgical functional connectivity (FC). Compare virtual surgery FC to pre-surgical FC.

## Required Methods

### 1. Pre-surgical Model Optimization
- Use `models.Generic2dOscillator()` with default connectivity.
- Integrator: `HeunStochastic(dt=2**-6, noise=noise.Additive(nsig=numpy.array([0.015, 0.015])))`.
- The paper optimizes TWO parameters per individual: **global coupling** `G` and **local noise amplitude** `sigma`.
- Implement a simple parameter sweep:
  - `G` range: `[0.01, 0.02, 0.03, 0.04, 0.05, 0.06, 0.07, 0.08]`
  - `noise nsig` range: `[0.005, 0.01, 0.015, 0.02, 0.025]`
- For each `(G, nsig)` pair:
  - Run `simulation_length=3000` ms
  - Compute FC matrix from `TemporalAverage(period=5.0)` monitor
  - Compute **mean absolute error (MAE)** between simulated FC and the empirical structural connectivity matrix (use `numpy.abs(simulated_FC - struct_conn_weights).mean()` as a proxy for the paper's fitting criterion)
- Select the parameter pair with the **lowest MAE**.

### 2. Define Tumor and Resection Zone
- Select a single "tumor" region (e.g., region 30 — left superior frontal gyrus) as the resection target.
- Document which region was chosen and justify based on clinical plausibility (e.g., non-eloquent area).

### 3. Virtual Resection Surgery
- Modify the optimized pre-surgical model:
  - **Set all incoming and outgoing weights for the tumor region to ZERO** in the connectivity matrix. This is the "virtual resection" — removing all white matter fibers connected to the resected region.
  - Do NOT remove the region itself from the simulation; it remains as a node but is structurally disconnected.
  - Re-normalize the connectivity matrix if necessary (or note if weights sum to zero for that region).
- Keep the same optimized `G` and `nsig` parameters from step 1.

### 4. Post-surgical Simulation
- Run `simulation_length=3000` ms with the resected connectivity.
- Compute the post-surgical FC matrix.

### 5. Comparison Analysis (REQUIRED)
Compare pre-surgical vs post-surgical states:
- **(a) FC matrix difference**: Compute `delta_FC = post_FC - pre_FC`. Visualize as a heatmap.
- **(b) Regional degree changes**: For each region, compute the change in mean FC (average row value). Identify regions most affected by the resection.
- **(c) Global network metrics**: Compare pre vs post on:
  - Mean FC (all pairs)
  - Global efficiency
  - Clustering coefficient (average over all nodes)
- **(d) Resected region analysis**: Specifically examine how the FC of the disconnected tumor region changes — it should show near-zero correlation with all other regions post-resection.

### 6. Scientific Discussion
Discuss whether virtual neurosurgery in TVB can predict functional consequences of tumor resection. The paper found that virtual resection improved the fit with postsurgical brain dynamics in 3/4 patients. Does your simulation produce plausible post-surgical changes?

## Prohibited Shortcuts
- Do NOT skip the parameter optimization (using default G without fitting is insufficient).
- Do NOT physically remove the region from the simulation (it must remain as a disconnected node).
- Do NOT omit the global network metrics comparison.
- Do NOT re-optimize parameters after resection (the paper uses the same fitted parameters pre/post).

## Expected Output
A notebook with: (1) parameter optimization heatmap/MAE plot, (2) pre-surgical FC matrix, (3) post-surgical FC matrix, (4) delta_FC heatmap, (5) bar chart of regional degree changes, (6) global metrics comparison table, (7) discussion of virtual neurosurgery utility.
