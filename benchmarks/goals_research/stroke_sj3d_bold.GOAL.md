# Paper-Grounded Goal: Stroke Recovery Modeling with SJ3D and BOLD Simulation

**Source:** Falcon MI, Riley JD, Jirsa VK, McIntosh AR, Chen EE, Solodkin A. "Functional mechanisms of recovery after chronic stroke: Modeling with The Virtual Brain." *eNeuro*, 3(2):ENEURO.0158-15.2016, 2016. DOI: 10.1523/ENEURO.0158-15.2016

## Task
Implement a personalized whole-brain model of stroke recovery using the Stefanescu-Jirsa 3D (SJ3D) neural mass model and simulate BOLD signals, following the TVB stroke pipeline from Falcon et al. 2016.

## Required Methods

### 1. Structural Connectivity Modification (Lesion)
- Load default connectivity via `connectivity.Connectivity.from_file()`.
- Simulate a focal lesion in the left precentral gyrus (motor cortex) by **zeroing out** all rows AND columns corresponding to the lesioned region(s) in the connectivity matrix. This mimics the structural disconnection seen in stroke.
- Set `conn.speed = numpy.array([4.0])` and call `conn.configure()`.

### 2. Local Model
- Use `models.ReducedSetHindmarshRose()` (this is the TVB 2.x equivalent of the Stefanescu-Jirsa 3D model used in Falcon et al. 2016).
- The model parameters are:
  - `a=1.0, b=3.0, c=1.0, d=5.0` (fast ion channel constants)
  - `r=0.006` (slower ion channel constant)
  - `s=4.0` (bursting strength)
  - Default coupling parameters within the local model: `K11`, `K12`, `K21` (to be explored)
- If `ReducedSetHindmarshRose` is unavailable in the installed TVB version, use `models.Generic2dOscillator()` as a placeholder but explicitly note this limitation in the notebook and justify why G2D approximates the SJ3D behavior.

### 3. Parameter Space Exploration (REQUIRED)
Systematically explore TWO global parameters and identify their optimal values:
  - **Global coupling** `G`: range `[0.001, 0.1]` (scale factor for incoming long-range activity)
  - **Conduction velocity** `cv`: range `[1.0, 100.0]` mm/ms
- For each `(G, cv)` pair:
  - Run a short simulation of `simulation_length=4000` ms
  - Compute the **global variance** = mean variance of the time series across all regions
  - Store the result in a 2D heatmap
- From the heatmap, select the parameter pair with the **highest global variance** flanked by bifurcation points (i.e., the region of parameter space with the richest dynamics, as in Figure 3 of Falcon et al.).

### 4. BOLD Simulation
- Using the **optimal** `G` and `cv` from the exploration:
  - Set `simulation_length = 240000` ms (4 minutes at TR=2s, matching empirical fMRI duration)
  - Use `monitors.Bold(period=2000.0)` with a `Bold` hemodynamic response function
  - Use stochastic Heun integration with `dt=0.0122` ms (as per paper)
  - Add white Gaussian noise (mean=0, std=1) to each node

### 5. Validation Metrics (REQUIRED)
Compare simulated BOLD to realistic BOLD properties and report:
- **(a) Amplitude range**: min and max BOLD amplitude across all regions. Should be within realistic fMRI range (~0.17 to ~87 in arbitrary units, as reported in Falcon et al.).
- **(b) Frequency spectrum**: FFT of the BOLD signal. Report the peak frequency. Should be ~0.05 Hz (typical BOLD frequency). Plot the spectrum.
- **(c) Functional connectivity**: Compute Pearson correlation between all region pairs using the BOLD time series. Produce a 76x76 FC matrix. Report the mean off-diagonal correlation.
- **(d) Phase comparison**: Compare the simulated FC matrix structure to the default structural connectivity matrix using Pearson correlation between their upper triangles. Report this "structure-function correlation."

### 6. Scientific Question
Explicitly discuss: Does the simulated BOLD signal show plausible resting-state dynamics? What does the structure-function correlation tell you about how well the lesioned connectome predicts functional connectivity?

## Prohibited Shortcuts
- Do NOT skip the parameter space exploration (single simulated point is insufficient).
- Do NOT use less than 4 minutes of BOLD simulation.
- Do NOT omit the frequency validation.
- Do NOT use a model other than ReducedSetHindmarshRose without justification.

## Expected Output
A notebook with: (1) lesion-modified connectivity setup, (2) parameter exploration heatmap, (3) optimal parameter selection, (4) 4-minute BOLD simulation, (5) amplitude/frequency/FC validation plots, (6) discussion of structure-function correlation.
