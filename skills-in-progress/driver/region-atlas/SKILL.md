---
name: region-atlas
description: TVB default connectivity region names and indices for the 76-region Hagmann parcellation. Use when setting region-specific parameters (stimulus weights, x0, model.I), selecting regions by name, or mapping neuroscience labels to TVB indices. Triggers on region, index, label, V1, V2, M1, hippocampus, atlas, parcellation.
---

# TVB Default 76-Region Atlas

The default `Connectivity.from_file()` loads the Hagmann parcellation (76 regions). Region names and indices are:

```
 0: medial orbitofrontal (l)     1: medial orbitofrontal (r)
 2: frontal pole (l)            3: frontal pole (r)
 4: insula (l)                  5: insula (r)
 6: temporal pole (l)           7: temporal pole (r)
 8: superior temporal (l)       9: superior temporal (r)
10: parahippocampal (l)        11: parahippocampal (r)
12: amygdala (l)              13: amygdala (r)
14: precentral (l)             15: precentral (r)       ← M1
16: postcentral (l)            17: postcentral (r)      ← S1
18: superior parietal (l)      19: superior parietal (r)
20: supramarginal (l)          21: supramarginal (r)
22: lingual (l)                23: lingual (r)
24: pericalcarine (l)          25: pericalcarine (r)    ← V1
26: cuneus (l)                 27: cuneus (r)
28: lateral occipital (l)      29: lateral occipital (r) ← V2 area
30: precuneus (l)              31: precuneus (r)
32: rostral anterior cingulate (l) 33: rostral anterior cingulate (r)
34: caudal anterior cingulate (l)  35: caudal anterior cingulate (r)
36: posterior cingulate (l)    37: posterior cingulate (r)
38: isthmus cingulate (l)      39: isthmus cingulate (r)
40: hippocampus (l)            41: hippocampus (r)
42: fusiform (l)               43: fusiform (r)
44: parietal operculum (l)     45: parietal operculum (r)
46: bankssts (l)               47: bankssts (r)
48: entorhinal (l)             49: entorhinal (r)
50: rostral middle frontal (l) 51: rostral middle frontal (r)
52: caudal middle frontal (l) 53: caudal middle frontal (r)  ← DLPFC
54: pars opercularis (l)      55: pars opercularis (r)
56: pars triangularis (l)     57: pars triangularis (r)
58: pars orbitalis (l)        59: pars orbitalis (r)
60: lateral orbitofrontal (l) 61: lateral orbitofrontal (r)
62: transverse temporal (l)   63: transverse temporal (r)  ← A1
64: superior frontal (l)      65: superior frontal (r)
66: frontal pole (l)          67: frontal pole (r)  [duplicate label]
68: thalamus proper (l)       69: thalamus proper (r)
70: caudate (l)               71: caudate (r)
72: putamen (l)               73: putamen (r)
74: pallidum (l)              75: pallidum (r)
```

## Common neuroscience labels → TVB indices

| Label | TVB region name | Index |
|-------|----------------|-------|
| V1 | pericalcarine (l)/(r) | 24, 25 |
| V2 | lateral occipital (l)/(r) | 28, 29 |
| A1 | transverse temporal (l)/(r) | 62, 63 |
| M1 | precentral (l)/(r) | 14, 15 |
| S1 | postcentral (l)/(r) | 16, 17 |
| DLPFC | caudal middle frontal (l)/(r) | 52, 53 |
| hippocampus | hippocampus (l)/(r) | 40, 41 |
| amygdala | amygdala (l)/(r) | 12, 13 |
| ACC | caudal anterior cingulate (l)/(r) | 34, 35 |
| PCC | posterior cingulate (l)/(r) | 36, 37 |
| thalamus | thalamus proper (l)/(r) | 68, 69 |

## Safe lookup pattern

```python
conn = connectivity.Connectivity.from_file()
conn.speed = 4.0
conn.configure()
labels = conn.region_labels  # list of 76 strings

# Find index by partial name match
v1_idx = [i for i, l in enumerate(labels) if "pericalcarine" in l]
# Use to set stimulus weights
stim_weights = numpy.zeros((76, 1))
stim_weights[v1_idx, 0] = 1.0
```

## Critical warnings

- Never use invented labels like "rHC" or "rCCP" — they do not exist in the atlas.
- Always verify with `conn.region_labels` before assigning region-specific parameters.
- Left = even-ish indices (0,2,4...), Right = odd-ish — but NOT guaranteed. Always look up by name.