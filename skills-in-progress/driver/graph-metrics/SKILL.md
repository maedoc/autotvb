---
name: tvb-driver-graph-metrics
description: Network-neuroscience metrics computed from simulation outputs and functional connectivity matrices. Use when a goal requires quantifying network structure, synchronization, or comparing structure vs function. Triggers on phrases like "global efficiency", "clustering coefficient", "Kuramoto", "coherence", "structure-function", "synchronization", "phase".
---

# TVB Driver: Graph Metrics & Network Analysis

## 1. Kuramoto Order Parameter (Global Synchronization)

Measures phase coherence across all regions in a frequency band. Use for metastability and synchronization goals.

```python
import numpy
from scipy.signal import hilbert

def kuramoto_order_parameter(time_series, band=(8, 12), fs=200.0):
    """
    time_series: shape (n_samples, n_regions)
    band: tuple (low, high) Hz
    fs: sampling frequency in Hz
    """
    from scipy.signal import butter, filtfilt
    # Band-pass filter each region
    b, a = butter(5, [band[0], band[1]], btype='band', fs=fs)
    filtered = numpy.array([filtfilt(b, a, time_series[:, r]) for r in range(time_series.shape[1])]).T

    # Hilbert transform → instantaneous phase
    phases = numpy.angle(hilbert(filtered, axis=0))

    # Kuramoto order parameter: magnitude of mean phase vector
    r_t = numpy.abs(numpy.mean(numpy.exp(1j * phases), axis=1))

    # Metastability = std of r_t over time
    return r_t.mean(), r_t.std()
```

**Usage in sweep or analysis:**

```python
r_mean, r_std = kuramoto_order_parameter(y_post, band=(8, 12), fs=200.0)
print(f"Mean synchronization: {r_mean:.3f}, Metastability: {r_std:.3f}")
```

## 2. Magnitude-Squared Coherence (Pairwise)

Used for inter-regional coherence in alpha bands (depression rTMS, tDCS goals).

```python
from scipy.signal import coherence

def alpha_coherence(ts_a, ts_b, fs=200.0):
    freq, Cxy = coherence(ts_a, ts_b, fs=fs, nperseg=256)
    # Integrate coherence in 8–12 Hz band
    band_mask = (freq >= 8.0) & (freq <= 12.0)
    return Cxy[band_mask].mean()
```

## 3. Global Efficiency (from FC Matrix)

Used in schizophrenia and tumor goals.

```python
def global_efficiency(fc_matrix):
    """fc_matrix: Pearson correlation matrix, shape (n_regions, n_regions)"""
    n = fc_matrix.shape[0]
    # Convert correlation to "distance" (inverse of absolute correlation)
    dist = 1.0 / (numpy.abs(fc_matrix) + numpy.finfo(float).eps)
    numpy.fill_diagonal(dist, 0)
    # Sum of inverse shortest-path distances
    inv_dist = 1.0 / (dist + numpy.finfo(float).eps)
    numpy.fill_diagonal(inv_dist, 0)
    return inv_dist.sum() / (n * (n - 1))

def clustering_coefficient(fc_matrix):
    """Weighted clustering coefficient (Barrat version, simplified)."""
    n = fc_matrix.shape[0]
    # Threshold to binary for simplicity: keep top correlations
    thr = numpy.percentile(numpy.abs(fc_matrix[numpy.triu_indices_from(fc_matrix, k=1)]), 50)
    adj = (numpy.abs(fc_matrix) >= thr).astype(int)
    numpy.fill_diagonal(adj, 0)

    C = numpy.zeros(n)
    for i in range(n):
        neighbors = numpy.where(adj[i])[0]
        k = len(neighbors)
        if k < 2:
            C[i] = 0.0
            continue
        # Count triangles
        subgraph = adj[numpy.ix_(neighbors, neighbors)]
        tri = subgraph.sum()
        C[i] = tri / (k * (k - 1))
    return C.mean()
```

**If networkx is available, prefer:**

```python
import networkx as nx

def global_efficiency_nx(fc_matrix):
    G = nx.from_numpy_array(numpy.abs(fc_matrix))
    return nx.global_efficiency(G)

def clustering_nx(fc_matrix):
    G = nx.from_numpy_array(numpy.abs(fc_matrix))
    return nx.average_clustering(G, weight='weight')
```

## 4. Structure–Function Correlation

Compare simulated FC to structural connectivity. Used in stroke and tumor goals.

```python
def structure_function_correlation(sim_fc, sc_weights):
    """
    sim_fc: simulated functional connectivity (Pearson correlation)
    sc_weights: structural connectivity weights (from conn.weights)
    """
    # Extract upper triangles, excluding diagonal
    idx = numpy.triu_indices_from(sim_fc, k=1)
    fc_vec = sim_fc[idx]
    sc_vec = sc_weights[idx]
    # Pearson correlation
    return numpy.corrcoef(fc_vec, sc_vec)[0, 1]
```

**Usage:**

```python
sf_corr = structure_function_correlation(sim_fc, conn.weights)
print(f"Structure-function correlation: {sf_corr:.3f}")
```

## 5. BOLD Proxy (Low-pass Filtered Global Signal)

Used when BOLD monitors are not available or for quick validation.

```python
from scipy.signal import butter, filtfilt

def bold_proxy(time_series, fs=200.0, cutoff=0.25):
    """Low-pass filter global mean at cutoff Hz to approximate BOLD timescale."""
    global_mean = time_series.mean(axis=1)
    b, a = butter(5, cutoff, btype='low', fs=fs)
    filtered = filtfilt(b, a, global_mean)
    return filtered.std()
```

## Critical Rules

- **Always discard burn-in** before computing FC or graph metrics. First 500–1000 ms of simulation may contain transients.
- **Use absolute correlation** when converting FC to graph weights — negative FC edges still carry connectivity information.
- **Sampling rate (`fs`)**: for `TemporalAverage(period=5.0)`, `fs = 1000 / 5.0 = 200.0` Hz. Verify this matches your monitor period.
- **FC matrix must be symmetric** and have ones on the diagonal. Use `numpy.corrcoef(data.T)` which produces this naturally.
- **networkx is optional**: provide both manual and networkx implementations so the notebook works regardless.

## Common Mistakes to Avoid

| Wrong | Right |
|---|---|
| Computing FC on burn-in period | Discard first N samples (e.g., `data = data[100:]`) |
| `fs = 1000` for `period=5.0` | `fs = 1000 / period = 200.0` |
| Using raw correlation (not absolute) for graph weights | `numpy.abs(fc_matrix)` for path-based metrics |
| Forgetting `numpy.fill_diagonal(..., 0)` before graph ops | Always zero diagonal to exclude self-connections |
| `scipy.signal.coherence` with default `nperseg` on short traces | Set `nperseg=min(256, len(ts)//4)` for short data |
