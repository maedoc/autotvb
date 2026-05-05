import json

path = 'sandbox/ablation_20260504_120703/qwen36-35b/with_skills/stroke_sj3d_bold/workflow.ipynb'
with open(path) as f:
    nb = json.load(f)

# Fix cell 9 (markdown) - put backticks safely
nb['cells'][9]['source'] = [
    '## 4. BOLD Simulation with Optimal Parameters\n',
    '\n',
    'Using the optimal `(G, cv)` from the heatmap, we run a 2-minute\n',
    '(`120 000 ms`) simulation with a `Bold` hemodynamic-response monitor\n',
    'at `TR = 1000 ms`, stochastic Heun integration (`dt = 0.05 ms`)\n',
    'for tractability, and additive white Gaussian noise.\n'
]

with open(path, 'w') as f:
    json.dump(nb, f, indent=1)

print('Fixed cell 9.')
