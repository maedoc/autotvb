import json

cells = []

def add_md(text):
    cells.append({"cell_type": "markdown", "metadata": {}, "source": [text + "\n"]})

def add_code(lines):
    source = []
    for line in lines:
        # Ensure proper line endings
        if not line.endswith("\n"):
            line += "\n"
        source.append(line)
    cells.append({"cell_type": "code", "execution_count": None, "metadata": {}, "outputs": [], "source": source})

# Title
add_md("# Multiple Pulse Stimulus Propagation in TVB")
add_md("This notebook demonstrates how external stimuli applied to specific brain regions propagate through the whole-brain network in TVB. Two brief pulses are delivered to distinct regions, and the evoked responses are analyzed in the time, frequency, and connectivity domains.")

# Imports
add_code([
    "from tvb.simulator.lab import *",
    "import numpy",
    "import matplotlib.pyplot as plt",
    "from scipy import signal",
    "from scipy.stats import ttest_1samp",
    "import warnings",
    "warnings.filterwarnings('ignore')",
    "%matplotlib inline"
])

# Connectivity
add_md("## 1. Structural Connectivity")
add_md("We load the default Hagmann 76-region connectivity and set a conduction speed of 4.0 mm/ms. This speed controls signal delay along structural fibers, which is critical for observing stimulus propagation rather than instantaneous network activation.")

add_code([
    "conn = connectivity.Connectivity.from_file()",
    "conn.speed = numpy.array([4.0])",
    "conn.configure()",
    "n_regions = conn.number_of_regions",
    "print('Regions:', n_regions)",
    "print('Non-zero weights:', conn.weights[conn.weights > 0].shape[0])",
    "print('Mean tract length (mm):', numpy.mean(conn.tract_lengths[conn.tract_lengths > 0]))"
])

# Model and coupling
add_md("## 2. Neural-Mass Model and Coupling")
add_md("We use the Generic2dOscillator, which produces limit-cycle oscillations with a natural frequency near 10 Hz at these parameters. The local dynamics are stable limit cycles (a=0.5, b=-15) so that the network relies on coupling to sustain coherent activity. Linear coupling (a=0.0154) provides weak long-range interactions sufficient to propagate evoked responses without dominating local dynamics.")

add_code([
    "model = models.Generic2dOscillator(",
    "    a=numpy.array([0.5]),",
    "    b=numpy.array([-15.0]),",
    "    c=numpy.array([0.0]),",
    "    d=numpy.array([0.02]),",
    "    tau=numpy.array([1.25])",
    ")",
    "",
    "coup = coupling.Linear(a=numpy.array([0.0154]))",
    "heunint = integrators.HeunDeterministic(dt=2**-3)"
])

# Stimuli
add_md("## 3. Multiple Region Stimuli")
add_md("Two brief impulsive stimuli are applied to different regions at different times. Stimulus 1 targets left V1 (pericalcarine, region 24) at 500 ms, and Stimulus 2 targets right M1 (precentral, region 15) at 1500 ms. The weight array is shaped (76, 1) to match TVB requirements. Each stimulus is configured independently and then passed as a tuple to the simulator.")

add_code([
    "# Stimulus 1: left V1 at 500 ms",
    "stim1_weights = numpy.zeros((n_regions, 1))",
    "stim1_weights[24, 0] = 3.5",
    "",
    "eqn_t1 = equations.PulseTrain()",
    "eqn_t1.parameters['onset'] = 500.0",
    "eqn_t1.parameters['tau']   = 5.0",
    "eqn_t1.parameters['T']     = 500.0",
    "",
    "stim1 = patterns.StimuliRegion(",
    "    temporal=eqn_t1,",
    "    connectivity=conn,",
    "    weight=stim1_weights",
    ")",
    "stim1.configure()",
    "",
    "# Stimulus 2: right M1 at 1500 ms",
    "stim2_weights = numpy.zeros((n_regions, 1))",
    "stim2_weights[15, 0] = 3.5",
    "",
    "eqn_t2 = equations.PulseTrain()",
    "eqn_t2.parameters['onset'] = 1500.0",
    "eqn_t2.parameters['tau']   = 5.0",
    "eqn_t2.parameters['T']     = 500.0",
    "",
    "stim2 = patterns.StimuliRegion(",
    "    temporal=eqn_t2,",
    "    connectivity=conn,",
    "    weight=stim2_weights",
    ")",
    "stim2.configure()"
])

# Monitors
add_md("## 4. Monitors")
add_md("A Raw monitor captures full-resolution dynamics for connectivity analysis (period=0.5 ms). A TemporalAverage monitor down-samples to 5 ms for efficient time-series visualization. Both are configured before being passed to the simulator.")

add_code([
    "mon_raw = monitors.Raw(period=0.5)",
    "mon_tavg = monitors.TemporalAverage(period=5.0)"
])

# Simulator
add_md("## 5. Simulator Configuration")
add_md("The simulator couples the model, connectivity, integrator, monitors, and both stimuli. We call configure() to finalize the object graph before running.")

add_code([
    "sim = simulator.Simulator(",
    "    model=model,",
    "    connectivity=conn,",
    "    coupling=coup,",
    "    integrator=heunint,",
    "    monitors=(mon_raw, mon_tavg),",
    "    stimulus=(stim1, stim2)",
    ")",
    "sim.configure()"
])

# Run
add_md("## 6. Run Simulation")
add_md("We simulate 3000 ms, which covers both stimuli and leaves ample time for post-stimulus network reverberations. Because the earliest stimulus is at 500 ms, we do not discard a long burn-in; if any transient exists in the first 100 ms, it is separated from the evoked window.")

add_code([
    "(t_raw, y_raw), (t_tavg, y_tavg) = sim.run(simulation_length=3000.0)"
])

# Post-hoc analysis
add_md("## 7. Post-Hoc Analysis")

# Time series
add_md("### 7.1 Evoked Time Series")
add_md("We plot the fast variable (V) for the stimulated regions (V1 left, M1 right) and a representative unstimulated region. Vertical lines mark stimulus onsets. This reveals the rapid depolarization following each pulse and the envelope of the subsequent reverberation.")

add_code([
    "ts_raw = y_raw[:, 0, :, 0].squeeze()  # (time, nodes)",
    "",
    "plt.figure(figsize=(12, 4))",
    "plt.plot(t_raw, ts_raw[:, 24], label='V1 left (stim 1)')",
    "plt.plot(t_raw, ts_raw[:, 15], label='M1 right (stim 2)')",
    "plt.plot(t_raw, ts_raw[:, 0], alpha=0.6, label='medial OFC left (unstimulated)')",
    "plt.axvline(500.0, color='r', linestyle='--', alpha=0.7, label='Stim 1')",
    "plt.axvline(1500.0, color='g', linestyle='--', alpha=0.7, label='Stim 2')",
    "plt.xlabel('Time (ms)')",
    "plt.ylabel('V (fast variable)')",
    "plt.title('Evoked Responses Across Selected Regions')",
    "plt.legend(loc='upper right')",
    "plt.xlim(0, 3000)",
    "plt.tight_layout()",
    "plt.show()"
])

# FC comparison
add_md("### 7.2 Functional Connectivity")
add_md("We compare baseline FC (100–400 ms, before any stimulus) with post-stimulus FC (600–1400 ms after Stimulus 1 and 1600–2500 ms after Stimulus 2). FC is computed as Pearson correlation across the full 76 regions. A mask zeros the diagonal so self-correlations do not dominate the comparison.")

add_code([
    "# Baseline window: 100-400 ms (brief pre-stimulus, avoids t=0 transients)",
    "mask_base = (t_raw >= 100.0) & (t_raw < 400.0)",
    "ts_base = ts_raw[mask_base, :].T  # (nodes, time)",
    "fc_base = numpy.corrcoef(ts_base)",
    "numpy.fill_diagonal(fc_base, 0.0)",
    "",
    "# Post-stimulus 1 window: 600-1400 ms",
    "mask_post1 = (t_raw >= 600.0) & (t_raw < 1400.0)",
    "ts_post1 = ts_raw[mask_post1, :].T",
    "fc_post1 = numpy.corrcoef(ts_post1)",
    "numpy.fill_diagonal(fc_post1, 0.0)",
    "",
    "# Post-stimulus 2 window: 1600-2500 ms",
    "mask_post2 = (t_raw >= 1600.0) & (t_raw < 2500.0)",
    "ts_post2 = ts_raw[mask_post2, :].T",
    "fc_post2 = numpy.corrcoef(ts_post2)",
    "numpy.fill_diagonal(fc_post2, 0.0)",
    "",
    "fig, axes = plt.subplots(1, 3, figsize=(16, 5))",
    "for ax, fm, title in [(axes[0], fc_base, 'Baseline FC (100-400 ms)'),",
    "                       (axes[1], fc_post1, 'Post-Stim 1 FC (600-1400 ms)'),",
    "                       (axes[2], fc_post2, 'Post-Stim 2 FC (1600-2500 ms)')]:",
    "    im = ax.imshow(fm, cmap='coolwarm', vmin=-1, vmax=1)",
    "    ax.set_title(title)",
    "    fig.colorbar(im, ax=ax, label='Pearson r')",
    "plt.tight_layout()",
    "plt.show()"
])

# FC change summary
add_md("### 7.3 FC Change Summary")
add_md("We quantify stimulus-induced FC changes by taking the upper-triangular elements (excluding diagonal) and comparing baseline to post-stimulus distributions with a paired one-sample t-test on difference scores.")

add_code([
    "def upper_tri(mat):",
    "    return mat[numpy.triu_indices_from(mat, k=1)]",
    "",
    "diff1 = upper_tri(fc_post1) - upper_tri(fc_base)",
    "diff2 = upper_tri(fc_post2) - upper_tri(fc_base)",
    "",
    "t1, p1 = ttest_1samp(diff1, 0.0)",
    "t2, p2 = ttest_1samp(diff2, 0.0)",
    "",
    "print(f'Post-stim 1: mean delta FC = {numpy.mean(diff1):.4f}, t = {t1:.3f}, p = {p1:.4e}')",
    "print(f'Post-stim 2: mean delta FC = {numpy.mean(diff2):.4f}, t = {t2:.3f}, p = {p2:.4e}')"
])

# Spectral
add_md("### 7.4 Spectral Characterization")
add_md("We estimate the power spectral density (Welch method) for the stimulated V1 region in the post-stimulus 1 window to empirically verify the oscillatory regime. This ensures that any claims about dominant frequency are grounded in data rather than model parameters alone.")

add_code([
    "fs = 1000.0 / 0.5  # Raw monitor sampling rate (Hz)",
    "sig = ts_post1[24, :]  # V1 left in post-stim 1 window",
    "freqs, psd = signal.welch(sig, fs=fs, nperseg=256)",
    "peak_freq = freqs[numpy.argmax(psd)]",
    "",
    "plt.figure(figsize=(8, 3))",
    "plt.semilogy(freqs, psd)",
    "plt.axvline(peak_freq, color='r', linestyle='--', alpha=0.7, label=f'Peak = {peak_freq:.1f} Hz')",
    "plt.xlim(0, 50)",
    "plt.xlabel('Frequency (Hz)')",
    "plt.ylabel('PSD')",
    "plt.title('Power Spectrum of V1 Left (Post-Stimulus 1)')",
    "plt.legend()",
    "plt.tight_layout()",
    "plt.show()"
])

# Propagation heatmap
add_md("### 7.5 Spatiotemporal Propagation Map")
add_md("A 2-D heatmap of all 76 regions over the first 500 ms after each stimulus onset visualizes how the evoked wavefront spreads from the stimulation site across the connectome. Regions are sorted by geodesic distance from the stimulated node (approximated by structural shortest path) to accentuate the propagation delay.")

add_code([
    "# Rank regions by shortest-path distance from region 24 (V1 left)",
    "G = (conn.weights > 0).astype(float)",
    "from scipy.sparse.csgraph import shortest_path",
    "dist24 = shortest_path(G, directed=False, indices=24, unweighted=True)",
    "order24 = numpy.argsort(dist24)",
    "",
    "# First stimulus window: 500-1000 ms",
    "win1 = (t_raw >= 500.0) & (t_raw < 1000.0)",
    "sig1 = ts_raw[win1, :][:, order24].T  # (regions, time)",
    "",
    "plt.figure(figsize=(10, 6))",
    "plt.imshow(sig1, aspect='auto', cmap='viridis',",
    "           extent=[500, 1000, 0, n_regions])",
    "plt.xlabel('Time (ms)')",
    "plt.ylabel('Regions (sorted by distance from V1 left)')",
    "plt.title('Propagation Map After Stimulus 1 (V1 left)')",
    "plt.colorbar(label='V')",
    "plt.tight_layout()",
    "plt.show()"
])

# Final verification
add_md("## 8. Regime Verification Summary")
add_code([
    "print(f'Peak oscillation frequency after stimulus 1: {peak_freq:.1f} Hz')",
    "print(f'Mean baseline FC (upper-tri): {numpy.mean(upper_tri(fc_base)):.4f}')",
    "print(f'Mean post-stim 1 FC (upper-tri): {numpy.mean(upper_tri(fc_post1)):.4f}')",
    "print(f'Mean post-stim 2 FC (upper-tri): {numpy.mean(upper_tri(fc_post2)):.4f}')"
])

notebook = {
    "cells": cells,
    "metadata": {
        "kernelspec": {
            "display_name": "Python 3",
            "language": "python",
            "name": "python3"
        },
        "language_info": {
            "name": "python",
            "version": "3.10.0"
        }
    },
    "nbformat": 4,
    "nbformat_minor": 4
}

out_path = "sandbox/ablation_20260504_120703/gemma4-31b/with_skills/multiple_stimuli/workflow.ipynb"
with open(out_path, "w") as f:
    json.dump(notebook, f, indent=2, ensure_ascii=False)

print("Notebook written to:", out_path)
