---
name: simulation-duration
description: Choose appropriate simulation_length for TVB monitors and scientific goals. Use BEFORE setting simulation_length. Prevents too-short simulations that produce rank-deficient FC matrices or insufficient BOLD volumes. Triggers on simulation_length, Bold, TemporalAverage, monitor period, duration, simulation time.
---

# Simulation Duration Guide

## Monitor-specific minimums

| Monitor | Period | Min duration | Why |
|---------|--------|-------------|-----|
| `TemporalAverage` | 0.1–10 ms | 500–2000 ms | Needs hundreds of samples for PSD; ERP needs pre/post stimulus window |
| `Bold` | 2000 ms | 60_000 ms (1 min) | BOLD TR=2s; need ≥30 volumes for stable FC, 60+ for rank-sufficient 76-region matrices |
| `EEG/MEG/iEEG` | 1–5 ms | 500–2000 ms | Sensor-level signals at ms resolution |
| `ProgressArray` | none | varies | Only for per-step callbacks, not standard use |

## Scientific-goal duration rules

- **FC estimation** (correlation, coherence): ≥60s real-time. For 76-region FC with BOLD: ≥4 min (`240_000 ms`). 30 volumes (1 min) gives rank-deficient 76×76 matrices — statistically unreliable.
- **ERP/evoked response**: 500–2000 ms with pre-stimulus baseline. Burn-in ≤100 ms; never exceed stimulus onset.
- **PSD/spectral analysis**: ≥2s for 0–50 Hz at 1000 Hz sampling; ≥4s for sub-10 Hz resolution.
- **Parameter sweep**: Shorter per-condition (1–2s) acceptable IF each condition is independent and the sweep ranges over many points. Total simulation time scales with conditions × duration.
- **Epilepsy/seizure transition**: ≥5–10s to capture transition dynamics.

## BOLD monitor specifics

- Default `period=2000` → one volume every 2 s
- 1 min simulation → 30 volumes → 76×76 FC matrix has rank ≤30 (rank-deficient!)
- 4 min → 120 volumes → sufficient rank for 76 regions
- `simulation_length` must be in **milliseconds**: `sim.simulation_length = 240_000` for 4 min

## Anti-patterns to avoid

- ❌ `simulation_length = 60_000` with `monitors.Bold(period=2000)` for FC analysis → only 30 volumes, unreliable FC
- ❌ Setting `simulation_length` shorter than the goal explicitly requires
- ❌ Short BOLD sweep (1–2 min) when the goal asks for "stable" or "reliable" FC
- ✅ When in doubt, simulate longer; truncate in analysis rather than simulate too short