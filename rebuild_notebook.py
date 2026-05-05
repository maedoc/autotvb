import json

path = 'sandbox/ablation_20260504_120703/qwen36-35b/without_skills/visual_erp/workflow.ipynb'

cells = []

def md_cell(text):
    return {"cell_type": "markdown", "metadata": {}, "source": [text + "\n"]}

def code_cell(lines):
    # lines is a list of strings without trailing newlines
    return {"cell_type": "code", "execution_count": None, "metadata": {}, "outputs": [], "source": [line + "\n" for line in lines]}

cells.append(md_cell("""# Visual Evoked Response Simulation in TVB

This notebook simulates how a brief visual stimulus to primary visual cortex (V1, region 35)
and secondary visual cortex (V2, region 36) propagates through a 76-region whole-brain network.

**Key question:** How does stimulus timing and coupling strength affect the evoked response
at local and distant regions?"""))

cells.append(code_cell([
    "import numpy as np",
    "from tvb.simulator.lab import *",
    "import matplotlib.pyplot as plt",
    "import warnings",
    "warnings.filterwarnings('ignore')",
]))

cells.append(md_cell("""## 1. Load default connectivity (Hagmann 76-region)

We use the default 76-region anatomical connectivity. Region indices 35 and 36 correspond
to V1 and V2 in the TVB Hagmann parcellation. The connectivity matrix determines how
activity spreads from the stimulated regions to the rest of the brain."""))

cells.append(code_cell([
    "conn = connectivity.Connectivity.from_file()",
    "conn.configure()",
    "print('Regions:', conn.region_labels[:5], '...')",
    "print('V1:', conn.region_labels[35])",
    "print('V2:', conn.region_labels[36])",
    "print('Number of regions:', conn.number_of_regions)",
]))

cells.append(md_cell("""## 2. Configure the neural mass model

We use the `Generic2dOscillator` tuned to a stable spiral regime near **~10 Hz** (alpha band).

**Parameter rationale:**
- `a = 1.05`, `b = -1.0`, `c = 0.0`, `d = 0.1`: places the system just below the supercritical
  Hopf bifurcation, yielding damped oscillations that can be amplified by coupling or stimulus.
- `tau = 1.0`: intrinsic time-constant compatible with ~10 Hz resonance when coupled.
- `I = 0.0`: no external current baseline; the network is driven entirely by coupling and stimulus.
- `e = 0.0`, `f = 1.0`, `g = 1.0`, `beta = 1.0`, `gamma = 1.0`: standard defaults for the
  second variable (W / adaptation) dynamics.

This regime is chosen because evoked responses are transient perturbations of a stable resting state;
a strongly self-oscillating (limit-cycle) network would produce continuous waves masking the ERP."""))

cells.append(code_cell([
    "model = models.Generic2dOscillator(",
    "    a=np.array([1.05]),",
    "    b=np.array([-1.0]),",
    "    c=np.array([0.0]),",
    "    d=np.array([0.1]),",
    "    I=np.array([0.0]),",
    "    tau=np.array([1.0]),",
    "    e=np.array([0.0]),",
    "    f=np.array([1.0]),",
    "    g=np.array([1.0]),",
    "    alpha=np.array([1.0]),",
    "    beta=np.array([1.0]),",
    "    gamma=np.array([1.0]),",
    ")",
]))

cells.append(md_cell("""## 3. Coupling

A `Linear` coupling with `a = 0.015` provides moderate long-range interaction. This value is
small enough to avoid network-wide synchronization, yet strong enough to let the stimulus
evoke a measurable response at connected regions within a few hundred milliseconds."""))

cells.append(code_cell([
    "coupling = coupling.Linear(a=np.array([0.015]))",
]))

cells.append(md_cell("""## 4. Define the stimulus

A `PulseTrain` models a brief visual flash:
- **Onset:** 500 ms
- **Pulse width:** 20 ms (single flash)
- **Amplitude:** 1e-3 (small perturbation to stay in linear regime)
- **Target regions:** V1 (region 35) and V2 (region 36)

The stimulus weight is applied only to these two regions, leaving the rest of the cortex unstimulated."""))

cells.append(code_cell([
    "stimulus = equations.PulseTrain(",
    "    parameters={'onset': 500.0, 'T': 10000.0, 'tau': 20.0, 'amp': 1e-3}",
    ")",
    "",
    "stim_weights = np.zeros((conn.number_of_regions, 1))",
    "stim_weights[[35, 36], 0] = np.array([1.0, 1.0])",
    "",
    "stimulus_pattern = patterns.StimuliRegion(",
    "    temporal=stimulus,",
    "    connectivity=conn,",
    "    weight=stim_weights,",
    ")",
    "stimulus_pattern.configure()",
    "print('Stimulus max weight:', stim_weights.max())",
    "print('Stimulus regions:', np.where(stim_weights[:, 0] > 0)[0])",
]))

cells.append(md_cell("""## 5. Integrator

`HeunStochastic` with a small time step (`dt = 0.1 ms`) provides a good balance of stability
and accuracy. We add weak additive noise (`nsig = [1e-5, 1e-5]`) shaped to the two state
variables of `Generic2dOscillator` (V, W). The noise is deliberately small so the evoked
response dominates the trace rather than ongoing fluctuation."""))

cells.append(code_cell([
    "integrator = integrators.HeunStochastic(",
    "    dt=0.1,",
    "    noise=noise.Additive(",
    "        nsig=np.array([1e-5, 1e-5])",
    "    )",
    ")",
]))

cells.append(md_cell("""## 6. Monitors

- `TemporalAverage` (period = 1.0 ms): captures the mean neural activity, which is our primary read-out.
No projection monitors (EEG/SEEG) are included here to keep the analysis focused on the source-level ERP."""))

cells.append(code_cell([
    "monitors = (",
    "    monitors.TemporalAverage(period=1.0),",
    ")",
]))

cells.append(md_cell("""## 7. Assemble and run the simulator

Simulation length: **10 000 ms** (10 s). The stimulus arrives at 500 ms, leaving a long
post-stimulus window to observe propagation and decay. We skip only a very brief pre-stimulus
burn-in (0 ms here, because 500 ms is already enough baseline)."""))

cells.append(code_cell([
    "sim = simulator.Simulator(",
    "    model=model,",
    "    connectivity=conn,",
    "    coupling=coupling,",
    "    integrator=integrator,",
    "    monitors=monitors,",
    "    stimulus=stimulus_pattern,",
    "    simulation_length=10000.0,",
    ")",
    "sim.configure()",
    "",
    "(t, y), = sim.run()",
    "",
    "print('Time shape:', t.shape)",
    "print('Data shape:', y.shape)",
]))

cells.append(md_cell("""## 8. Plot the evoked response

We plot:
1. The V1 (region 35) and V2 (region 36) time series, with the stimulus interval highlighted.
2. A selection of distant regions to show propagation.
3. A difference (post-minus-pre) to highlight the evoked response amplitude."""))

cells.append(code_cell([
    "# Extract V and W variables; shape is (time, state_vars, regions, modes)",
    "v_trace = y[:, 0, :, 0]  # first state variable = V",
    "",
    "# Define a zoom window around the stimulus",
    "zoom_start = 0",
    "zoom_end = 2000  # ms",
    "mask_zoom = (t >= zoom_start) & (t <= zoom_end)",
    "t_zoom = t[mask_zoom]",
    "v_zoom = v_trace[mask_zoom, :]",
    "",
    "# Regions to highlight",
    "v1_idx, v2_idx = 35, 36",
    "distant = [0, 10, 20, 30, 40, 50, 60, 70]  # sample spread across cortex",
    "",
    "fig, axes = plt.subplots(3, 1, figsize=(12, 10))",
    "",
    "# --- Panel 1: V1 and V2 ---",
    "ax = axes[0]",
    "ax.plot(t_zoom, v_zoom[:, v1_idx], label='V1 (r35)', color='C0')",
    "ax.plot(t_zoom, v_zoom[:, v2_idx], label='V2 (r36)', color='C1')",
    "ax.axvspan(500, 520, color='gray', alpha=0.3, label='Stimulus')",
    "ax.set_ylabel('V (a.u.)')",
    "ax.set_title('Evoked Response at Stimulated Regions')",
    "ax.legend(loc='upper right')",
    "ax.set_xlim(zoom_start, zoom_end)",
    "",
    "# --- Panel 2: Distant regions ---",
    "ax = axes[1]",
    "for r in distant:",
    "    ax.plot(t_zoom, v_zoom[:, r], alpha=0.7, label=conn.region_labels[r] if r in distant[:4] else None)",
    "ax.axvspan(500, 520, color='gray', alpha=0.3)",
    "ax.set_ylabel('V (a.u.)')",
    "ax.set_title('Propagation to Distant Regions')",
    "ax.set_xlim(zoom_start, zoom_end)",
    "",
    "# --- Panel 3: V1 pre vs post amplitude difference ---",
    "ax = axes[2]",
    "pre_mask = (t >= 400) & (t < 500)",
    "post_mask = (t >= 500) & (t < 1500)",
    "pre_mean = np.abs(v_trace[pre_mask, :].mean(axis=0))",
    "post_mean = np.abs(v_trace[post_mask, :]).mean(axis=0)",
    "diff = post_mean - pre_mean",
    "ax.bar(range(76), diff, color='steelblue')",
    "ax.axvline(v1_idx, color='C0', linestyle='--', label='V1')",
    "ax.axvline(v2_idx, color='C1', linestyle='--', label='V2')",
    "ax.set_xlabel('Region index')",
    "ax.set_ylabel('Mean |V| difference (post - pre)')",
    "ax.set_title('Post-stimulus Amplitude Change (0.5-1.5 s vs baseline)')",
    "ax.legend()",
    "",
    "plt.tight_layout()",
    "plt.show()",
]))

cells.append(md_cell("""## 9. Parameter summary and interpretation

| Component | Choice | Reason |
|-----------|--------|--------|
| Model | `Generic2dOscillator` | Canonical 2-variable oscillator; flexible bifurcation tuning |
| a, b, c, d | 1.05, -1.0, 0.0, 0.1 | Stable spiral just below Hopf; ~10 Hz damped resonance |
| tau | 1.0 | Intrinsic time scale; with a~1 gives alpha-range frequency |
| Coupling a | 0.015 | Moderate; allows propagation without global lock-in |
| Integrator | `HeunStochastic`, dt=0.1 | Second-order accuracy for stochastic ODEs |
| nsig | [1e-5, 1e-5] | Very weak noise; ERP dominates, no masking |
| Stimulus | PulseTrain, onset 500 ms, 20 ms width, 1e-3 amp | Mimics brief visual flash; small to stay linear |
| Targets | V1 (35), V2 (36) | Hagmann atlas primary/secondary visual areas |
| Simulation | 10 s | Long enough to see ERP and late reverberation |

**What to expect:**
- A sharp deflection in V1/V2 shortly after 500 ms.
- Smaller, delayed deflections in regions anatomically connected to V1/V2 (visible in panel 2).
- The bar plot (panel 3) shows which regions show the largest change in activity due to the flash.
- Because the network is in a stable spiral regime, the response decays back to baseline
  rather than triggering sustained oscillations."""))

nb = {
    "cells": cells,
    "metadata": {
        "kernelspec": {
            "display_name": "Python 3",
            "language": "python",
            "name": "python3"
        },
        "language_info": {
            "codemirror_mode": {
                "name": "ipython",
                "version": 3
            },
            "file_extension": ".py",
            "mimetype": "text/x-python",
            "name": "python",
            "nbconvert_exporter": "python",
            "pygments_lexer": "ipython3",
            "version": "3.9.0"
        }
    },
    "nbformat": 4,
    "nbformat_minor": 4
}

with open(path, 'w') as f:
    json.dump(nb, f, indent=1)

print('Notebook rebuilt successfully at', path)
