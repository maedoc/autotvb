# Paper-Grounded Goal: Bayesian Virtual Epileptic Patient — Inferring Excitability from SEEG Data

**Source:** Jirsa VK, Proix T, Perdikis D, et al. "The Virtual Epileptic Patient: Individualized whole-brain models of epilepsy spread." *NeuroImage*, 145:377-388, 2017. DOI: 10.1016/j.neuroimage.2016.04.049 (Methods: Data fitting section)

## Task
Implement a simplified Bayesian inference pipeline to estimate the spatial distribution of epileptogenicity (x0 values) from simulated SEEG data, following the data-fitting approach in Jirsa et al. 2017. This is a model inversion task: given observed seizure activity, infer which regions have elevated excitability.

## Required Methods

### 1. Forward Model (Data Generation)
- Use the VEP setup from the permittivity-coupling goal (Epileptor, Difference coupling, Ks=-0.2, Kf=0.1).
- Choose 4 "ground-truth" EZ regions with elevated x0:
  - Region A: x0 = -1.6
  - Region B: x0 = -1.6
  - Region C: x0 = -1.8 (PZ)
  - All others: x0 = -2.4
- Run `simulation_length=10000` ms with `HeunStochastic(dt=0.05, noise=...)`, using `monitors.TemporalAverage(period=1.0)`.
- Compute the simulated **LFP** for each region as `(x2 - x1)` from the Epileptor state variables.
- Add observation noise to the LFP: `LFP_noisy = LFP + 0.1 * numpy.random.randn(*LFP.shape)`.
- This noisy LFP serves as your "empirical SEEG data."

### 2. Model Inversion Strategy (Simplified Bayesian)
The full paper uses Stan/Hamiltonian Monte Carlo; we will use a **grid-search Bayesian approach**:
- Define a grid of x0 values: `[-2.5, -2.4, -2.3, -2.2, -2.1, -2.0, -1.9, -1.8, -1.7, -1.6, -1.5]`
- Consider only a subset of 10 candidate regions (including the 4 ground-truth regions plus 6 decoys).
- For each candidate region, test each x0 value from the grid while keeping all other regions at x0 = -2.4.
- For each configuration:
  - Run a SHORT forward simulation of `simulation_length=3000` ms (to save time)
  - Compute the LFP
  - Compute the **mean squared error (MSE)** between simulated LFP and the "empirical" LFP from step 1
- The "posterior" for each region is proportional to `exp(-MSE / (2 * sigma^2))` where `sigma = 0.5`.

### 3. Posterior Distribution (REQUIRED)
For each of the 10 candidate regions, produce:
- A bar plot showing the posterior probability across the x0 grid
- Report the **maximum a posteriori (MAP)** estimate: the x0 value with highest posterior probability

### 4. Inference Accuracy (REQUIRED)
- Compare the MAP-estimated x0 values against the ground-truth values for all 10 regions.
- Produce a scatter plot: ground-truth x0 (x-axis) vs inferred x0 (y-axis).
- Report the **Pearson correlation** between ground-truth and inferred x0 values.
- Report the **number of true positives** (regions correctly identified as having elevated excitability, i.e., inferred x0 > -2.1) and **false positives** (non-epileptogenic regions incorrectly inferred as elevated).

### 5. Scientific Discussion
Discuss the identifiability problem: can you uniquely determine which regions are epileptogenic from network-wide LFP data alone? The paper notes that data fitting can generate informative estimates for EZ but uninformative (high-variance) estimates for some distant regions. Does your simplified grid search show the same pattern?

## Prohibited Shortcuts
- Do NOT use the ground-truth x0 values directly (you must infer them).
- Do NOT test all 76 regions individually on the full grid (that would be 76×11 simulations = too many).
- Do NOT use a single forward simulation for all configurations (each configuration needs its own simulation).
- Do NOT skip the posterior probability normalization.

## Expected Output
A notebook with: (1) ground-truth VEP simulation and noisy LFP, (2) grid-search results table, (3) 10 posterior bar plots, (4) MAP estimate table, (5) ground-truth vs inferred scatter plot with correlation, (6) true/false positive report, (7) discussion of identifiability.
