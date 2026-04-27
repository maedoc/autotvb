# Goal: Modeling Epilepsy

## Scientific Question
How can I model seizure propagation and interictal-ictal transitions in a patient-specific brain network using the Epileptor model?

## Expected Output
A single runnable Jupyter notebook that:
1. Import TVB (`from tvb.simulator.lab import *`) and standard libraries.
2. Load and configure structural connectivity (`Connectivity.from_file()`) with appropriate speed.
3. Instantiate the neural-mass model(s): `models.Epileptor`.
4. Define coupling function: `coupling.Difference`.
5. Configure stimulus: `patterns.StimuliRegion`.
6. Choose integrator: `integrators.HeunDeterministic`, `integrators.HeunStochastic`.
7. Attach monitor(s): `monitors.EEG`, `monitors.TemporalAverage`, `monitors.iEEG`.
8. Build and configure the `Simulator`, then run it.
9. Perform post-hoc analysis (correlation, spectral, statistical tests, etc.).
10. Generate figures with matplotlib showing key results.
11. Include brief markdown comments explaining scientific rationale for parameter choices.
