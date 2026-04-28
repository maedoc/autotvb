# Paper-Grounded Goal: Alzheimer's Disease — Amyloid-Beta Modulation of E/I Balance

**Source:** Stefanovski L, Triebkorn P, Spiegler A, et al. "Linking molecular pathways and large-scale computational modeling to assess candidate disease mechanisms and pharmacodynamics in Alzheimer's disease." *Frontiers in Computational Neuroscience*, 13:54, 2019. DOI: 10.3389/fncom.2019.00054

## Task
Implement a TVB whole-brain model of Alzheimer's disease (AD) where amyloid-beta (Aβ) burden modulates local excitation-inhibition (E/I) balance, following Stefanovski et al. 2019. Show that heterogeneous Aβ distribution is necessary to reproduce the EEG slowing observed in AD patients, and simulate the therapeutic effect of memantine.

## Required Methods

### 1. Model Setup
- Use `models.Generic2dOscillator()` as the local neural mass model.
- Load default connectivity from `connectivity.Connectivity.from_file()`.
- Use `coupling.Linear(a=numpy.array([0.0154]))`.
- Integrator: `HeunStochastic(dt=2**-6, noise=noise.Additive(nsig=numpy.array([0.015, 0.015])))`.

### 2. Aβ Burden Implementation (CRITICAL)
The core innovation of Stefanovski et al. is that Aβ load modulates local excitability. Implement this as follows:
- Define a spatial map of Aβ burden across the 76 regions. Since we do not have patient PET data, create a **synthetic but heterogeneous** Aβ map:
  - Select 6 "hub" regions (e.g., precuneus, posterior cingulate, medial frontal, lateral temporal, hippocampus, parietal) and assign them high Aβ load = `0.8`
  - Assign 10 adjacent regions medium load = `0.4`
  - Assign all remaining 60 regions low load = `0.1`
- The Aβ load modifies the Generic2dOscillator parameter `a` (which controls excitability):
  - Base value: `a = -0.5`
  - For each region: `a_effective = a_base + 0.3 * Aβ_load`
  - This implements the paper's hypothesis that Aβ causes local hyperexcitation by shifting the E/I balance toward excitation.
- Report the exact Aβ map in a markdown table.

### 3. Simulation Protocol
Run THREE simulations with identical random seed but different Aβ configurations:
- **(a) Control**: All regions have Aβ_load = `0.0` (uniform healthy brain)
- **(b) AD homogeneous**: All regions have Aβ_load = `0.5` (uniform burden)
- **(c) AD heterogeneous**: The heterogeneous map from section 2

For each simulation:
- Run `simulation_length=10000` ms
- Use `monitors.TemporalAverage(period=5.0)`
- Use `monitors.EEG(period=5.0)` with default sensors

### 4. Post-hoc Analysis (REQUIRED)
For each of the three conditions, compute:
- **(a) Peak EEG frequency**: Extract the dominant frequency from the EEG signal using Welch's method (`scipy.signal.welch`). The paper finds that heterogeneous Aβ produces a **slowing** of the dominant EEG frequency (shift toward lower alpha/theta). Report the peak frequency for each condition.
- **(b) Spectral shift**: Quantify the spectral shift as the difference in peak frequency between (a) Control and (c) AD heterogeneous. The paper reports typical slowing in AD; your result should show a negative shift (lower frequency in AD).
- **(c) Memantine simulation**: Simulate the effect of the NMDA antagonist memantine by **reducing** the Aβ-induced excitability shift by 50% (i.e., `a_effective = a_base + 0.15 * Aβ_load` instead of `0.3`). Run one additional simulation with the heterogeneous Aβ map but with "memantine" and report whether the peak frequency shifts back toward the control value.

### 5. Key Scientific Claim to Validate
The paper's central claim is: "The measured heterogeneous Aβ loads were crucial for simulations to produce the typical slowing of EEG observed in AD patients as it was absent in control models with homogeneous Aβ distributions."
Your notebook must explicitly test and report whether:
- The homogeneous AD model (b) shows LESS slowing than the heterogeneous AD model (c)
- The memantine simulation partially reverses the slowing

## Prohibited Shortcuts
- Do NOT use a single Aβ value for all regions.
- Do NOT skip the three-condition comparison.
- Do NOT omit the memantine simulation.
- Do NOT use FFT without Welch windowing (the paper uses spectral density estimates).

## Expected Output
A notebook comparing 4 simulations (Control, AD homogeneous, AD heterogeneous, AD heterogeneous + memantine) with: (1) Aβ map table, (2) EEG power spectra with peak frequency annotations, (3) quantitative summary table of peak frequencies, (4) explicit discussion of whether heterogeneous Aβ is necessary for EEG slowing.
