# Paper-Grounded Goal: Depression rTMS — Wilson-Cowan Alpha Asymmetry Simulation

**Source:** Iliaens C. "Simulating depression-like abnormal brain activity and stimulation treatment with The Virtual Brain." Master's thesis, Ghent University, 2021. (Based on Wilson-Cowan model + rTMS protocols)

## Task
Use the Wilson-Cowan model in TVB to simulate healthy, depressed, and post-treatment brain states by manipulating local inhibition and applying virtual high-frequency (HF) and low-frequency (LF) rTMS. Quantify frontal alpha power, frontal alpha asymmetry, and inter-regional coherence.

## Required Methods

### 1. Model Setup
- Use `models.WilsonCowan()` for all 76 regions.
- Default connectivity from `connectivity.Connectivity.from_file()`.
- Use `coupling.Linear(a=numpy.array([0.0154]))`.
- Integrator: `HeunStochastic(dt=2**-6, noise=noise.Additive(nsig=numpy.array([0.01, 0.01])))`.
- Base Wilson-Cowan parameters for "healthy" brain:
  - `c_ee=14.05, c_ei=12.44, c_ie=16.76, c_ii=2.0`
  - `tau_e=16.07, tau_i=33.71`
  - `a_e=1.3, b_e=4.0, c_e=1.0`
  - `a_i=1.95, b_i=14.76, c_i=1.0`
  - `P=2.22, Q=1.0` (external inputs to excitatory and inhibitory populations)

### 2. Depression Simulation
- Reduce local inhibition in three bilateral frontal/occipital regions by setting `Q=0` in:
  - Dorsolateral prefrontal cortex (DLPFC, regions ~47, ~48)
  - Orbitofrontal cortex (OFC, regions ~51, ~52)
  - Primary visual cortex (V1, regions ~57, ~58)
- All other regions maintain `Q=1.0`.
- Run `simulation_length=3000` ms, discard first 500 ms as burn-in.
- Use `monitors.TemporalAverage(period=5.0)`.

### 3. Virtual rTMS Protocols
Create TWO additional simulations starting from the depressed brain state:
- **(a) HF-rTMS**: Apply a `PulseTrain` stimulus to the **left DLPFC** (region ~47):
  - Frequency = 10 Hz (onset=1000ms, tau=1ms, T=100ms)
  - Amplitude scaling factor = 5.0
  - Duration = 3000 ms total simulation
- **(b) LF-rTMS**: Apply a `PulseTrain` stimulus to the **right DLPFC** (region ~48):
  - Frequency = 1 Hz (onset=1000ms, tau=1ms, T=1000ms)
  - Amplitude scaling factor = 5.0
  - Duration = 3000 ms total simulation

### 4. Spectral Analysis (REQUIRED)
For each condition (Healthy, Depressed, HF-rTMS, LF-rTMS), compute:
- **(a) Frontal alpha power (8-12 Hz)**:
  - Extract the time series for left DLPFC and right DLPFC
  - Apply Welch's PSD (`nperseg=256`)
  - Compute absolute alpha power by integrating PSD over 8-12 Hz
- **(b) Frontal alpha asymmetry**:
  - Asymmetry index = `log10(left_alpha_power / right_alpha_power)`
  - Positive values = left > right (hypoactive left, as in depression literature)
- **(c) Peak alpha frequency (IAF)**:
  - Find the frequency with maximum power in the 7-13 Hz range for each DLPFC
- **(d) Coherence**:
  - Compute magnitude-squared coherence between left DLPFC and right DLPFC in the alpha band using `scipy.signal.coherence`

### 5. Comparison Table (REQUIRED)
Produce a markdown table comparing all 4 conditions on:
  - Left DLPFC alpha power
  - Right DLPFC alpha power
  - Frontal alpha asymmetry
  - Peak alpha frequency (left DLPFC)
  - DLPFC inter-hemispheric coherence

Explicitly state whether the depressed condition shows altered alpha metrics vs healthy, and whether either rTMS protocol shifts metrics toward healthy values.

## Prohibited Shortcuts
- Do NOT modify Q in all regions (must be focal, as in the thesis).
- Do NOT skip the HF/LF rTMS comparison.
- Do NOT use a model other than Wilson-Cowan.

## Expected Output
A notebook with: (1) Wilson-Cowan phase plane showing healthy vs depressed parameters, (2) 4 simulation traces, (3) overlaid PSD plots for all conditions, (4) comparison table with all 5 metrics, (5) discussion of whether virtual rTMS normalizes alpha asymmetry.
