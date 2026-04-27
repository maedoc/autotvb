# Goal: Demonstrate using the simulator for a surface simulation, stohastic  integration.

## Scientific Question
How do I run a whole-brain simulation on a cortical surface mesh rather than at the region level?

## Expected Output
A single runnable Jupyter notebook that:
1. Import TVB (`from tvb.simulator.lab import *`) and standard libraries.
2. Load and configure structural connectivity (`Connectivity.from_file()`) with appropriate speed.
3. Instantiate the neural-mass model(s): `models.Generic2dOscillator`.
4. Define coupling function: `coupling.Linear`.
6. Choose integrator: `integrators.HeunStochastic`.
7. Attach monitor(s): `monitors.EEG`, `monitors.TemporalAverage`, `monitors.SpatialAverage`.
8. Build and configure the `Simulator`, then run it.
9. Perform post-hoc analysis (correlation, spectral, statistical tests, etc.).
10. Generate figures with matplotlib showing key results.
11. Include brief markdown comments explaining scientific rationale for parameter choices.
