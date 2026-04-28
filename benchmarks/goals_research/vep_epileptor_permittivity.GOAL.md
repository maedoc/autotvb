# Paper-Grounded Goal: Virtual Epileptic Patient with Permittivity Coupling

**Source:** Jirsa VK, Proix T, Perdikis D, et al. "The Virtual Epileptic Patient: Individualized whole-brain models of epilepsy spread." *NeuroImage*, 145:377-388, 2017. DOI: 10.1016/j.neuroimage.2016.04.049

## Task
Implement the Virtual Epileptic Patient (VEP) model for temporal-lobe epilepsy using TVB's Epileptor neural mass model with permittivity coupling, exactly as described in Jirsa et al. 2017.

## Required Methods

### 1. Model Setup
- Use `models.Epileptor()` with the following parameters:
  - `Ks = numpy.array([-0.2])` (permittivity coupling scale)
  - `Kf = numpy.array([0.1])` (fast coupling scale)
  - `r = numpy.array([0.00015])` (slow-down factor)
  - All other parameters at TVB defaults: `Iext=3.1`, `Iext2=0.45`, `slope=0.0`, `tau0=2857.0`, `tau2=10.0`, `gamma=0.01`
- The excitability parameter `x0` must be spatially heterogeneous:
  - **Epileptogenic Zone (EZ)**: right hippocampus (rHC, region ~47), right parahippocampus (rPHC, region ~62), right amygdala (rAMYG, region ~40) → `x0 = -1.6`
  - **Propagation Zone (PZ)**: right inferior temporal cortex (rTCI, region ~69), right ventral temporal cortex (rTCV, region ~72) → `x0 = -1.8`
  - **All other regions** → `x0 = -2.4`
- Use `coupling.Difference(a=numpy.array([1.0]))` as the long-range coupling function.

### 2. Integration
- Use `integrators.HeunStochastic(dt=0.05, noise=noise.Additive(nsig=numpy.array([0., 0., 0., 0.0003, 0.0003, 0.])))`
- The noise should be applied ONLY to the two variables of the second population (y3, y4), matching the paper.

### 3. Monitors
- Configure three monitors with `period=1.0` ms:
  - `monitors.TemporalAverage(period=1.0)`
  - `monitors.EEG` (with default sensors and region mapping)
  - `monitors.SEEG` (with default sensors and region mapping)
- Set state variables to track as `variables_of_interest = [0, 2]` (LFP = x2-x1, and slow permittivity y2).

### 4. Simulation
- Run `simulation_length=10000` ms (10 seconds).
- Execute with `sim.run(simulation_length=10000)`.

### 5. Post-hoc Analysis (REQUIRED)
After simulation, compute and plot:
- **(a) Time series plot**: Plot the LFP (x2-x1) for all 76 regions, normalized per region, with region index on the y-axis. Seizure propagation should be visible as high-amplitude epochs.
- **(b) Seizure detection**: Automatically detect seizure-like events by thresholding the LFP amplitude. Report:
  - Total number of seizures in the 10-second window
  - For each detected seizure: onset time, offset time, duration, number of regions recruited
- **(c) Recruitment latency map**: Compute the time delay from seizure onset to each region's first threshold crossing. Plot as a bar chart per region.
- **(d) EZ vs PZ distinction**: Verify that regions with `x0 = -1.6` (EZ) have shorter recruitment latencies and higher seizure counts than regions with `x0 = -1.8` (PZ). Report the mean latency for EZ vs PZ.

### 6. Validation
- The notebook must explicitly state whether the EZ regions initiate seizures before PZ regions.
- If no seizures are detected in 10 seconds, report this as a methodological failure and suggest parameter adjustments.

## Prohibited Shortcuts
- Do NOT use a uniform `x0` across all regions.
- Do NOT use `coupling.Linear` instead of `coupling.Difference`.
- Do NOT simulate for less than 10 seconds.
- Do NOT omit the seizure-detection analysis.
- Do NOT apply noise to all 6 state variables.

## Expected Output
A complete, executable Jupyter notebook implementing the above, with figures for (a), (b), (c), and quantitative results for (d), all clearly labeled and reproducible.
