# Paper-Grounded Goal: tDCS Modulation of Resting-State Functional Connectivity

**Source:** Kunze T, Hunold A, Haueisen J, Jirsa V, Spiegler A. "Transcranial direct current stimulation changes resting state functional connectivity: A large-scale brain network modeling study." *NeuroImage*, 140:174-187, 2016. DOI: 10.1016/j.neuroimage.2016.02.015

## Task
Use TVB to simulate how transcranial direct current stimulation (tDCS) applied to the motor cortex modulates resting-state functional connectivity, following Kunze et al. 2016. Compare anodal vs cathodal tDCS and quantify changes in FC, synchronization, and power spectra.

## Required Methods

### 1. Model Setup
- Use `models.Generic2dOscillator()` for all 76 regions.
- Default connectivity from `connectivity.Connectivity.from_file()`.
- Use `coupling.Linear(a=numpy.array([0.0154]))`.
- Integrator: `HeunStochastic(dt=2**-6, noise=noise.Additive(nsig=numpy.array([0.015, 0.015])))`.
- Use `monitors.TemporalAverage(period=5.0)` for FC computation.

### 2. Baseline Simulation (Sham)
- Run `simulation_length=10000` ms with NO external stimulus.
- Discard first 1000 ms as burn-in.
- Compute baseline FC and power spectrum.

### 3. tDCS Protocol Implementation
Implement THREE conditions:
- **(a) Sham**: No stimulation (baseline)
- **(b) Anodal tDCS**: Constant depolarizing current applied to the left motor cortex (region ~45 in default parcellation) throughout the entire simulation
  - Model as an additional constant input to the excitatory variable of the target region.
  - In TVB, this can be implemented via `stimulus` with a `patterns.StimuliRegion` using a very long `PulseTrain` or by adding a constant offset to the model's input current.
  - If direct current injection is not straightforward in TVB, apply a sustained regional input by setting an elevated `P` parameter (external excitatory input) for the target region only: increase the target region's effective input by 20% relative to baseline.
- **(c) Cathodal tDCS**: Hyperpolarizing current to the SAME left motor cortex region
  - Decrease the target region's effective input by 20% relative to baseline.

Apply the stimulation for the FULL `simulation_length=10000` ms (sustained tDCS, as in the paper's long-duration protocol).

### 4. Quantification (REQUIRED)
For each of the 3 conditions, compute:
- **(a) Functional connectivity matrix**: Pearson correlation of `TemporalAverage` time series between all region pairs, using the post-burn-in data.
- **(b) Mean FC change**: For anodal and cathodal conditions, compute `delta_FC = FC_stim - FC_sham`. Report:
  - Number of region pairs showing increased FC (> 0.05 change)
  - Number showing decreased FC (< -0.05 change)
- **(c) Target region connectivity**: Specifically examine how the left motor cortex FC with the rest of the brain changes under anodal vs cathodal tDCS. Report the 5 regions most strongly affected in each direction.
- **(d) Global synchronization**: Compute the Kuramoto order parameter or mean phase coherence across all regions in the alpha band (8-12 Hz). Report whether anodal/cathodal tDCS increases or decreases global synchronization relative to sham.
- **(e) Power spectrum**: Welch PSD of the left motor cortex signal. Report whether tDCS shifts the dominant frequency or changes total power.

### 5. Comparison to Paper's Findings
The paper reports that anodal tDCS generally **increases** FC and synchronization, while cathodal tDCS **decreases** it. Your notebook must explicitly state whether your simulation reproduces this directionality.

## Prohibited Shortcuts
- Do NOT apply stimulation to all regions (must be focal, to motor cortex only).
- Do NOT simulate for less than 10 seconds.
- Do NOT skip the cathodal condition.
- Do NOT omit the delta_FC quantification.

## Expected Output
A notebook with: (1) sham FC matrix, (2) anodal and cathodal FC matrices, (3) two delta_FC heatmaps, (4) bar charts of mean FC change, (5) list of top-5 affected regions per condition, (6) overlaid PSD plots, (7) explicit statement about directionality match to Kunze et al.
