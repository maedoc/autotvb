---
name: tvb-driver-analysis
description: Analyze and visualize TVB simulation output. Use when plotting time series, computing functional connectivity, power spectra, or performing post-hoc statistical analysis. Triggers on `plt.plot`, `corrcoef`, `fft`, `psd`, `imshow`, `FunctionalConnectivity`.
---

# TVB Driver: Analysis & Visualization

## Time Series Plot
```python
plt.figure(figsize=(12, 4))
plt.plot(t, y[:, 0, :, 0].squeeze())
plt.xlabel("Time (ms)")
plt.ylabel("Activity")
plt.title("Region-averaged signal")
```

## Functional Connectivity
```python
# y shape is (time, state_vars, nodes, modes)
ts = y[:, 0, :, 0].squeeze()  # (time, nodes)
fc = numpy.corrcoef(ts.T)

plt.figure(figsize=(8, 8))
plt.imshow(fc, cmap='viridis', vmin=-1, vmax=1)
plt.colorbar(label='Pearson r')
plt.title("Functional Connectivity")
```

## Power Spectra
```python
from scipy import signal
freqs, psd = signal.welch(ts[:, 0], fs=1000.0/(monitors[0].period), nperseg=256)
plt.semilogy(freqs, psd)
plt.xlabel("Frequency (Hz)")
plt.ylabel("PSD")
plt.xlim(0, 50)
```

## Rules
- Always label axes and add titles.
- If the scientific question asks about a specific frequency band, restrict the plot to that range.
- Report quantitative summaries (peak frequency, mean FC, etc.) in the markdown cell before the plot.

## Burn-in & Stimulus-Aligned Windows
```python
# WRONG: discards the evoked response
post_burn = y[t > 1000]

# CORRECT: keep stimulus onset; analyze the evoked window
stim_onset = 500.0
evoked_mask = (t >= stim_onset) & (t < stim_onset + 1000.0)
ts_evoked = y[evoked_mask, 0, :, 0].squeeze()
fc_evoked = numpy.corrcoef(ts_evoked.T)
```

## Regime Verification
```python
from scipy import signal
# Verify a claimed "~10 Hz spiral" before writing the prose
freqs, psd = signal.welch(ts[:, node], fs=1000.0/monitors[0].period, nperseg=256)
peak_freq = freqs[numpy.argmax(psd)]
# Report peak_freq in the markdown; only then assert the regime.
```
