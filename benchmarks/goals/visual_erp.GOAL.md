# Goal: Model Visual Evoked Response in TVB

## Scientific Question
A researcher asks: "How would a visual stimulus (e.g. a flash) presented to primary visual cortex
propagate through a large-scale brain network? Can I simulate the evoked response at V1/V2 and at
distant regions, and see how stimulation timing and coupling strength affect the ERP?"

## Expected Output
A single runnable Python Jupyter notebook that:
1. Imports TVB (`from tvb.simulator.lab import *`)
2. Loads default connectivity (76-region Hagmann)
3. Configures a `Generic2dOscillator` model in a regime that supports evoked responses
   (stable spiral near 10 Hz)
4. Defines a region-level stimulus targeting V1 (region 35) and optionally V2 (region 36)
   using a `PulseTrain` temporal profile
5. Uses a stochastic Heun integrator with low noise
6. Runs a ~10 second simulation with a stimulus onset around 500 ms
7. Monitors temporal average and optionally EEG/SEEG
8. Plots the time series and highlights the evoked response
9. Briefly comments on why certain parameters were chosen
