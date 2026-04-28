# Paper-Grounded Goal: Schizophrenia — NRG1 Genotype Effects on E/I Balance in Whole-Brain Models

**Source:** Costa-Klein P, Ettinger U, Schirner M, et al. "Brain network simulations indicate effect of neuregulin-1 genotype on excitation-inhibition balance in cortical dynamics." *Pharmacopsychiatry*, 2020. DOI: 10.1055/s-0039-3403020

## Task
Use TVB whole-brain modeling to investigate how a schizophrenia-risk genetic variant (NRG1 rs3924999) alters the excitation-inhibition (E/I) balance, following Costa-Klein et al. 2020. Simulate three genotype groups and show differential network dynamics.

## Required Methods

### 1. Model Setup
- Use `models.Generic2dOscillator()` for all 76 regions.
- Default connectivity from `connectivity.Connectivity.from_file()`.
- Use `coupling.Linear(a=numpy.array([0.0154]))`.
- Integrator: `HeunStochastic(dt=2**-6, noise=noise.Additive(nsig=numpy.array([0.015, 0.015])))`.
- Use `monitors.TemporalAverage(period=5.0)`.
- Run `simulation_length=5000` ms, discard first 500 ms as burn-in.

### 2. Genotype-Dependent Parameter Modifications (CRITICAL)
The paper finds that NRG1 G/G-carriers (risk group) show distinct E/I parameters compared to A-allele carriers. Implement THREE genotype configurations by modifying TWO key parameters:

| Parameter | A/A carriers (low risk) | A/G carriers | G/G carriers (high risk) |
|---|---|---|---|
| Global coupling `G` (rescale factor in coupling) | 0.045 | 0.040 | 0.035 |
| Local excitatory recurrence `a` (G2D parameter) | -0.5 | -0.55 | -0.6 |

- Global coupling `G` is applied as a scaling factor to the coupling strength: `coupling.Linear(a=numpy.array([0.0154 * G]))`.
- The `a` parameter controls the local excitatory recurrence in the Generic2dOscillator; more negative = less excitatory feedback.

Run one simulation per genotype group (3 total).

### 3. Post-hoc Analysis (REQUIRED)
For each genotype, compute:
- **(a) Global mean signal**: Average activity across all 76 regions over time. Plot all three traces overlaid.
- **(b) Power spectral density**: Welch PSD of the global mean signal (fs = 1000/5 = 200 Hz). Report the dominant frequency peak.
- **(c) BOLD proxy**: Low-pass filter the global mean signal at 0.25 Hz (Butterworth, order=5) to approximate BOLD temporal dynamics. Compute the standard deviation of this BOLD proxy. The paper notes that G/G carriers show altered global dynamics.
- **(d) Functional connectivity**: Compute Pearson correlation matrix between all region pairs using the post-burn-in time series. Report:
  - Mean FC (average of upper triangle)
  - Global efficiency of the FC graph (use `networkx` or manual computation)
  - Modularity (if possible, otherwise report clustering coefficient)

### 4. Genotype Comparison (REQUIRED)
Produce a table comparing:
- Dominant frequency peak
- BOLD proxy standard deviation
- Mean FC
- Global efficiency

Explicitly test the paper's claim: "G/G-carriers exhibit lower excitatory recurrence and global coupling, and higher feedback inhibition as compared to other allele carriers." Your simulation should show that reduced `G` and more negative `a` lead to measurably different network dynamics.

### 5. Scientific Discussion
Discuss whether the simulated differences between genotypes are consistent with the schizophrenia literature on E/I imbalance. Does reduced global coupling in G/G carriers translate to less efficient information integration in your model?

## Prohibited Shortcuts
- Do NOT use identical parameters for all three genotypes.
- Do NOT skip the BOLD proxy calculation.
- Do NOT omit the global efficiency computation.
- Do NOT use a model other than Generic2dOscillator.

## Expected Output
A notebook with: (1) Genotype parameter table, (2) overlaid global mean traces, (3) overlaid PSD plots with peak frequency annotations, (4) FC matrices for all three groups, (5) quantitative comparison table, (6) discussion linking simulated dynamics to E/I balance hypothesis.
