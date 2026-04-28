---
name: tvb-driver-graph-metrics
description: Network analysis from FC matrices and time series. Use for "global efficiency", "clustering", "Kuramoto", "coherence", "synchronization". Triggers on network metrics, structure-function.
---

# Graph Metrics

## Kuramoto Order Parameter

```python
from scipy.signal import butter, filtfilt, hilbert

def kuramoto_order(y, band=(8,12), fs=200.0):
    b, a = butter(5, [band[0], band[1]], btype='band', fs=fs)
    f = numpy.array([filtfilt(b, a, y[:, r]) for r in range(y.shape[1])]).T
    phases = numpy.angle(hilbert(f, axis=0))
    r_t = numpy.abs(numpy.mean(numpy.exp(1j * phases), axis=1))
    return r_t.mean(), r_t.std()

r_mean, r_std = kuramoto_order(y_post, band=(8,12), fs=200.0)
```

## Alpha Coherence

```python
from scipy.signal import coherence

freq, Cxy = coherence(ts_a, ts_b, fs=200.0, nperseg=min(256, len(ts_a)//4))
alpha_mask = (freq >= 8.0) & (freq <= 12.0)
alpha_coh = Cxy[alpha_mask].mean()
```

## Global Efficiency

```python
def global_efficiency(fc):
    n = fc.shape[0]
    dist = 1.0 / (numpy.abs(fc) + numpy.finfo(float).eps)
    numpy.fill_diagonal(dist, 0)
    inv_dist = 1.0 / (dist + numpy.finfo(float).eps)
    numpy.fill_diagonal(inv_dist, 0)
    return inv_dist.sum() / (n * (n - 1))

def clustering_coeff(fc):
    n = fc.shape[0]
    thr = numpy.percentile(numpy.abs(fc[numpy.triu_indices_from(fc, k=1)]), 50)
    adj = (numpy.abs(fc) >= thr).astype(int)
    numpy.fill_diagonal(adj, 0)
    C = numpy.zeros(n)
    for i in range(n):
        neigh = numpy.where(adj[i])[0]
        k = len(neigh)
        if k < 2: continue
        C[i] = adj[numpy.ix_(neigh, neigh)].sum() / (k * (k - 1))
    return C.mean()
```

## Structure–Function Correlation

```python
def structure_function_corr(sim_fc, sc_weights):
    idx = numpy.triu_indices_from(sim_fc, k=1)
    return numpy.corrcoef(sim_fc[idx], sc_weights[idx])[0, 1]
```

## Rules
- Discard burn-in before all metrics.
- `fs = 1000 / monitor_period` (e.g., `TemporalAverage(period=5.0)` → `fs=200`).
- FC must be `numpy.corrcoef(data.T)` for symmetric output.
- Zero diagonal before graph operations: `numpy.fill_diagonal(..., 0)`.
