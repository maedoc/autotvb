# Goal: TVB Workflow

## Scientific Question
How do I apply an external stimulus to specific brain regions in TVB and observe the evoked response propagate through the network?

## Expected Output
A single runnable Jupyter notebook that:
1. Import TVB (`from tvb.simulator.lab import *`) and standard libraries.
2. Load and configure structural connectivity (`Connectivity.from_file()`) with appropriate speed.
5. Configure stimulus: `patterns.StimuliRegion`.
8. Build and configure the `Simulator`, then run it.
9. Perform post-hoc analysis (correlation, spectral, statistical tests, etc.).
10. Generate figures with matplotlib showing key results.
11. Include brief markdown comments explaining scientific rationale for parameter choices.
