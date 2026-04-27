# Goal: TVB Workflow

## Scientific Question
How do I simulate and extract the BOLD fMRI signal from a TVB simulation, and how do different HRF kernels affect the result?

## Expected Output
A single runnable Jupyter notebook that:
1. Import TVB (`from tvb.simulator.lab import *`) and standard libraries.
7. Attach monitor(s): `monitors.Bold`.
8. Build and configure the `Simulator`, then run it.
10. Generate figures with matplotlib showing key results.
11. Include brief markdown comments explaining scientific rationale for parameter choices.
