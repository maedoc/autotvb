import json

# Build a valid Jupyter notebook implementing the TVB power-spectrum analysis workflow.

cells = []

# Cell 1: Markdown — title
cells.append({
    "cell_type": "markdown",
    "metadata": {},
    "source": [
        "# Analyze the Frequency Content of Simulated Brain Activity\n",
        "\n",
        "This notebook demonstrates how to run a whole-bain simulation in TVB using the **Generic2dOscillator** neural-mass model, and then perform post-hoc spectral and correlation analyses on the resulting time series.\n"
    ]
})

# Cell 2: Imports
cells.append({
    "cell_type": "code",
    "execution_count": None,
    "metadata": {},
    "outputs": [],
    "source": [
        "import numpy as np\n",
        "import matplotlib.pyplot as plt\n",
        "from scipy import signal, stats\n",
        "\n",
        "from tvb.simulator.lab import *\n"
    ]
})

# Cell 3: Markdown — connectivity rationale
cells.append({
    "cell_type": "markdown",
    "metadata": {},
    "source": [
        "## 1. Structural connectivity\n",
        "\n",
        "We load the default 76-region TVB connectivity matrix.  The **conduction speed** is set to 4 mm/ms (≈ 4 m/s), a realistic estimate for human white-matter fibre velocity.  This speed determines inter-regional time delays, which shape the temporal dynamics and synchronisation patterns of the network.\n"
    ]
})

# Cell 4: Connectivity setup
cells.append({
    "cell_type": "code",
    "execution_count": None,
    "metadata": {},
    "outputs": [],
    "source": [
        "conn = Connectivity.from_file()\n",
        "conn.speed = np.array([4.0])   # mm/ms\n",
        "conn.configure()\n",
        "n_regions = conn.number_of_regions\n",
        "print('Regions:', n_regions)\n",
        "print('Non-zero weights:', np.count_nonzero(conn.weights))\n"
    ]
})

# Cell 5: Markdown — model rationale
cells.append({
    "cell_type": "markdown",
    "metadata": {},
    "source": [
        "## 2. Neural-mass model: Generic2dOscillator\n",
        "\n",
        "The **Generic2dOscillator** is a FitzHugh–Nagumo–style model capable of limit-cycle oscillations.  We choose parameters that place each node in a noisy limit-cycle regime producing approximately **10 Hz** alpha-like activity, which is a dominant rhythm in resting-state EEG/MEG:\n",
        "\n",
        "- `tau = 1.25` — time-scale factor that sets the intrinsic period to ≈ 100 ms.\n",
        "- `a = 1.05`, `b = -1.0`, `d = 0.5` — shape the nullclines so that the fixed point is unstable and a stable limit cycle exists.\n",
        "- `I = 0.0` — no external DC drive.\n"
    ]
})

# Cell 6: Model instantiation
cells.append({
    "cell_type": "code",
    "execution_count": None,
    "metadata": {},
    "outputs": [],
    "source": [
        "model = models.Generic2dOscillator(\n",
        "    a=np.array([1.05]),\n",
        "    b=np.array([-1.0]),\n",
        "    c=np.array([0.0]),\n",
        "    d=np.array([0.5]),\n",
        "    I=np.array([0.0]),\n",
        "    tau=np.array([1.25]),\n",
        "    e=np.array([0.0]),\n",
        "    f=np.array([0.333]),\n",
        "    g=np.array([1.0]),\n",
        "    alpha=np.array([1.0]),\n",
        "    gamma=np.array([1.0]),\n",
        ")\n"
    ]
})

# Cell 7: Markdown — coupling rationale
cells.append({
    "cell_type": "markdown",
    "metadata": {},
    "source": [
        "## 3. Coupling\n",
        "\n",
        "We use **coupling.Difference**, which transmits the activity difference between connected regions.  A moderate global coupling strength (`a = 0.015`) is chosen so that regions weakly synchronise without overriding their intrinsic rhythms.\n"
    ]
})

# Cell 8: Coupling
cells.append({
    "cell_type": "code",
    "execution_count": None,
    "metadata": {},
    "outputs": [],
    "source": [
        "coupling_fn = coupling.Difference(a=np.array([0.015]))\n"
    ]
})

# Cell 9: Markdown — integrator rationale
cells.append({
    "cell_type": "markdown",
    "metadata": {},
    "source": [
        "## 4. Integrator\n",
        "\n",
        "**integrators.HeunStochastic** is a second-order predictor–corrector scheme suitable for stochastic differential equations.  A small additive noise (`nsig = [0.01, 0.01]`) perturbs the two state variables (V, W) and mimics the biological variability seen in real neural populations.  The time step `dt = 0.1 ms` ensures numerical stability while resolving the ~10 Hz oscillations.\n"
    ]
})

# Cell 10: Integrator
cells.append({
    "cell_type": "code",
    "execution_count": None,
    "metadata": {},
    "outputs": [],
    "source": [
        "integrator = integrators.HeunStochastic(\n",
        "    dt=0.1,\n",
        "    noise=noise.Additive(\n",
        "        nsig=np.array([0.01, 0.01])\n",
        "    )\n",
        ")\n"
    ]
})

# Cell 11: Markdown — monitor rationale
cells.append({
    "cell_type": "markdown",
    "metadata": {},
    "source": [
        "## 5. Monitor\n",
        "\n",
        "**monitors.TemporalAverage** samples the node-averaged state at 1 ms intervals (period = 1.0), giving a sampling rate of 1 kHz—more than sufficient for spectral analysis of the alpha band (≈ 8–13 Hz).\n"
    ]
})

# Cell 12: Monitor
cells.append({
    "cell_type": "code",
    "execution_count": None,
    "metadata": {},
    "outputs": [],
    "source": [
        "monitor = monitors.TemporalAverage(period=1.0)\n"
    ]
})

# Cell 13: Markdown — simulation
cells.append({
    "cell_type": "markdown",
    "metadata": {},
    "source": [
        "## 6. Build, configure, and run the simulator\n",
        "\n",
        "We simulate **5000 ms** of activity.  A short **50 ms burn-in** is discarded to avoid startup transients, keeping the stimulus window intact (there is no external stimulus in this protocol).\n"
    ]
})

# Cell 14: Simulator build and run
cells.append({
    "cell_type": "code",
    "execution_count": None,
    "metadata": {},
    "outputs": [],
    "source": [
        "sim = simulator.Simulator(\n",
        "    connectivity=conn,\n",
        "    model=model,\n",
        "    coupling=coupling_fn,\n",
        "    integrator=integrator,\n",
        "    monitors=[monitor],\n",
        "    simulation_length=5000.0,\n",
        ")\n",
        "sim.configure()\n",
        "\n",
        "(t, y), = sim.run()\n",
        "print('Time points:', t.shape)\n",
        "print('Data shape:', y.shape)\n"
    ]
})

# Cell 15: Markdown — post-hoc analysis
cells.append({
    "cell_type": "markdown",
    "metadata": {},
    "source": [
        "## 7. Post-hoc analysis\n",
        "\n",
        "We perform three analyses directly relevant to the scientific question:\n",
        "\n",
        "1. **Functional connectivity (FC)** — Pearson correlation matrix between regional time series.\n",
        "2. **Power spectral density (PSD)** — Welch's method per region; average across regions.\n",
        "3. **Statistical test** — one-sample t-test on Fisher-z transformed FC values to test whether mean connectivity differs from zero.\n"
    ]
})

# Cell 16: Analysis code
cells.append({
    "cell_type": "code",
    "execution_count": None,
    "metadata": {},
    "outputs": [],
    "source": [
        "# Extract time series for the first state variable (V) across all regions\n",
        "ts = y[:, 0, :, 0]   # shape: (time, regions)\n",
        "\n",
        "# Discard brief burn-in (first 50 ms = 50 points at 1 kHz)\n",
        "burn = 50\n",
        "ts_post = ts[burn:, :]\n",
        "t_post = t[burn:]\n",
        "\n",
        "# 1. Functional connectivity\n",
        "fc = np.corrcoef(ts_post.T)\n",
        "\n",
        "# 2. Power spectral density (Welch)\n",
        "fs = 1000.0  # Hz\n",
        "nperseg = 512\n",
        "psds = []\n",
        "for i in range(n_regions):\n",
        "    f, pxx = signal.welch(ts_post[:, i], fs=fs, nperseg=nperseg)\n",
        "    psds.append(pxx)\n",
        "psds = np.array(psds)   # shape: (regions, frequencies)\n",
        "mean_psd = psds.mean(axis=0)\n",
        "\n",
        "# Identify peak frequency in the 1–30 Hz range\n",
        "band = (f >= 1.0) & (f <= 30.0)\n",
        "peak_idx = np.argmax(mean_psd[band])\n",
        "peak_freq = f[band][peak_idx]\n",
        "print(f'Peak frequency (1–30 Hz): {peak_freq:.2f} Hz')\n",
        "\n",
        "# 3. Statistical test on FC (Fisher-z transform, exclude diagonal)\n",
        "mask = ~np.eye(n_regions, dtype=bool)\n",
        "r_vals = fc[mask]\n",
        "z_vals = np.arctanh(np.clip(r_vals, -0.999, 0.999))\n",
        "t_stat, p_val = stats.ttest_1samp(z_vals, 0.0)\n",
        "print(f'Mean FC (r): {r_vals.mean():.3f}, t={t_stat:.2f}, p={p_val:.2e}')\n"
    ]
})

# Cell 17: Markdown — figures
cells.append({
    "cell_type": "markdown",
    "metadata": {},
    "source": [
        "## 8. Figures\n"
    ]
})

# Cell 18: Plotting code
cells.append({
    "cell_type": "code",
    "execution_count": None,
    "metadata": {},
    "outputs": [],
    "source": [
        "fig, axes = plt.subplots(2, 2, figsize=(12, 10))\n",
        "\n",
        "# A. Time series of three representative regions\n",
        "ax = axes[0, 0]\n",
        "for idx in [0, 10, 20]:\n",
        "    ax.plot(t_post, ts_post[:, idx], label=f'Region {idx}')\n",
        "ax.set_xlabel('Time (ms)')\n",
        "ax.set_ylabel('V (a.u.)')\n",
        "ax.set_title('Simulated time series (post burn-in)')\n",
        "ax.legend()\n",
        "ax.set_xlim(t_post[0], t_post[0] + 1000)\n",
        "\n",
        "# B. FC matrix\n",
        "ax = axes[0, 1]\n",
        "im = ax.imshow(fc, cmap='coolwarm', vmin=-1, vmax=1)\n",
        "ax.set_title('Functional connectivity (Pearson r)')\n",
        "fig.colorbar(im, ax=ax, shrink=0.8)\n",
        "\n",
        "# C. Average PSD\n",
        "ax = axes[1, 0]\n",
        "ax.plot(f, mean_psd, color='darkblue')\n",
        "ax.axvline(peak_freq, color='red', linestyle='--', label=f'Peak = {peak_freq:.1f} Hz')\n",
        "ax.set_xlim(0, 50)\n",
        "ax.set_xlabel('Frequency (Hz)')\n",
        "ax.set_ylabel('Power (a.u.)')\n",
        "ax.set_title('Mean power spectral density')\n",
        "ax.legend()\n",
        "\n",
        "# D. Distribution of FC values\n",
        "ax = axes[1, 1]\n",
        "ax.hist(r_vals, bins=50, color='steelblue', edgecolor='white')\n",
        "ax.axvline(r_vals.mean(), color='red', linestyle='--', label=f'Mean = {r_vals.mean():.3f}')\n",
        "ax.set_xlabel('Pearson r')\n",
        "ax.set_ylabel('Count')\n",
        "ax.set_title('FC distribution (off-diagonal)')\n",
        "ax.legend()\n",
        "\n",
        "plt.tight_layout()\n",
        "plt.show()\n"
    ]
})

# Cell 19: Markdown — summary
cells.append({
    "cell_type": "markdown",
    "metadata": {},
    "source": [
        "## Summary\n",
        "\n",
        "- The simulator was configured with realistic structural connectivity, a stochastic limit-cycle neural-mass model, and a deterministic coupling scheme.\n",
        "- After discarding a 50 ms burn-in, the regional time series were analysed with correlation and Welch spectral estimation.\n",
        "- The peak frequency of the average PSD quantifies the dominant oscillation frequency, while the FC matrix reveals how spatially distant regions synchronise.\n",
        "- The statistical test assesses whether the observed mean functional connectivity is significantly non-zero.\n"
    ]
})

# Assemble notebook
notebook = {
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
    "nbformat_minor": 4,
    "cells": cells
}

out_path = "/home/duke/src/autotvb/sandbox/ablation_20260504_120703/gemma4-31b/without_skills/analyze_power_spectra/workflow.ipynb"
with open(out_path, "w") as f:
    json.dump(notebook, f, indent=2)

print("Notebook written to", out_path)
