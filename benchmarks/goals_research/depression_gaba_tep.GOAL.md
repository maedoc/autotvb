# Paper-Grounded Goal: Major Depressive Disorder — GABAergic Deficit and TMS-Evoked Potentials

**Source:** Hofsähs T, Pille M, Kern L, et al. "The Virtual Brain links transcranial magnetic stimulation evoked potentials and inhibitory neurotransmitter changes in major depressive disorder." *Imaging Neuroscience*, 4:IMAG.a.1147, 2026. DOI: 10.1162/IMAG.a.1147

## Task
Use the Jansen-Rit neural mass model in TVB to simulate transcranial magnetic stimulation evoked potentials (TEPs), then introduce GABAergic deficits by altering local inhibitory parameters, and quantify the resulting increase in TEP amplitude—mimicking the empirical finding that MDD patients show larger TEP amplitudes despite lower GABA levels.

## Required Methods

### 1. Model Setup
- Use `models.JansenRit()` as the neural mass model for all 76 regions.
- Use default TVB connectivity: `connectivity.Connectivity.from_file()`.
- Use `coupling.Linear(a=numpy.array([0.0154]))`.
- Integrator: `HeunDeterministic(dt=2**-6)` (deterministic, as in the paper's main analysis).
- Add a stimulus to the left primary motor cortex (M1) region to mimic TMS:
  - `patterns.StimuliRegion` with `equations.PulseTrain()`
  - Onset = 500 ms, Tau = 1 ms (sharp impulse), T = 1000 ms (single pulse, not repetitive)
  - Apply to a single region corresponding to left M1 (region ~53 in default parcellation).

### 2. Baseline Simulation (Healthy Control)
- Run with default Jansen-Rit parameters:
  - `A = 3.25` (maximum amplitude of excitatory PSP)
  - `B = 22.0` (maximum amplitude of inhibitory PSP)
  - `a = 100.0` (excitatory synaptic decay rate, ms⁻¹)
  - `b = 50.0` (inhibitory synaptic decay rate, ms⁻¹)
  - `C1 = 135.0, C2 = 108.0, C3 = 33.75, C4 = 33.75` (synaptic coupling constants)
- Record `simulation_length=1500` ms to capture pre- and post-stimulus activity.
- Use `monitors.EEG(period=1.0)` with default sensor configuration.

### 3. TEP Extraction
- Extract the TEP from the EEG time series:
  - For each EEG channel, extract the window `[stimulus_onset-100, stimulus_onset+400]` ms
  - Baseline correct by subtracting the mean amplitude in `[-100, 0]` ms
- Compute the **Global Mean Field Amplitude (GMFA)**:
  - At each time point, compute the standard deviation across ALL EEG channels
  - This yields a single GMFA time series representing the global TEP envelope

### 4. GABAergic Deficit Simulations (MDD Mimicry)
Run TWO additional simulations, each modifying ONE inhibitory parameter while keeping all others at defaults:
- **(a) Reduced inhibitory decay rate**: Set `b = 25.0` (50% reduction from 50.0)
- **(b) Reduced inhibitory synapses**: Set `C4 = 19.575` (42% reduction from 33.75)

For each simulation, extract the GMFA and compare to baseline.

### 5. Quantification (REQUIRED)
For each of the 3 conditions (Baseline, Reduced b, Reduced C4), compute:
- **(a) Peak GMFA**: Maximum GMFA value in the post-stimulus window `[0, 400]` ms
- **(b) Relative GMFA**: Express peak GMFA as percentage of the baseline peak GMFA
- **(c) TEP components**: Report the latency and amplitude of the first positive peak (P60 equivalent) and first negative peak (N100 equivalent) if clearly identifiable

The paper reports that lowering b from 50→26 gives ~125.7% GMFA, and lowering C4 from 33.75→19.575 gives ~131.3% GMFA. Your results should show comparable trends (increased TEP amplitude with reduced inhibition), though exact values may vary.

### 6. Scientific Discussion
Explicitly discuss which of the two GABAergic mechanisms (slower inhibitory decay vs fewer inhibitory synapses) produces a larger TEP amplitude increase in your simulation, and what this implies for the "GABA hypothesis of depression."

## Prohibited Shortcuts
- Do NOT modify excitatory parameters (A, C1, C2) when testing GABA deficits.
- Do NOT use a model other than Jansen-Rit.
- Do NOT skip the GMFA calculation.
- Do NOT simulate without the TMS-like stimulus.

## Expected Output
A notebook with: (1) Jansen-Rit model setup, (2) TMS stimulus configuration, (3) baseline TEP with GMFA plot, (4) two GABA-deficit TEPs with GMFA plots overlaid, (5) quantitative table of peak GMFA and relative change, (6) discussion of mechanism.
