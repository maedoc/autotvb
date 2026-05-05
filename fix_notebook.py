import json

path = 'sandbox/ablation_20260504_120703/qwen36-35b/without_skills/visual_erp/workflow.ipynb'

with open(path, 'r') as f:
    nb = json.load(f)

# Fix connectivity cell (cell index 3)
cell3 = nb['cells'][3]
for i, line in enumerate(cell3['source']):
    if 'load_default=True' in line:
        cell3['source'][i] = line.replace('connectivity.Connectivity(load_default=True)', 'connectivity.Connectivity.from_file()')

# Fix stimulus cell (cell index 9)
cell9 = nb['cells'][9]
new_source = []
for line in cell9['source']:
    if line.startswith('stimulus = stimuli.PulseTrain('):
        new_source.append('stimulus = equations.PulseTrain(\n')
    elif 'onset=' in line and 'T=' in line:
        # skip individual lines and replace with parameters dict
        pass
    elif line.strip() == 'onset=500.0,' or line.strip() == 'T=10000.0,        # long period so only one pulse occurs' or line.strip() == 'tau=20.0,         # pulse width 20 ms' or line.strip() == 'amp=1e-3,         # small amplitude':
        pass
    elif line.strip() == ')':
        new_source.append("    parameters={'onset': 500.0, 'T': 10000.0, 'tau': 20.0, 'amp': 1e-3}\n")
        new_source.append(')\n')
    else:
        new_source.append(line)
cell9['source'] = new_source

# Fix plotting cell (cell index 15)
cell15 = nb['cells'][15]
new_source2 = []
for line in cell15['source']:
    if 'mask_zoom = (t[:, 0]' in line:
        new_source2.append('mask_zoom = (t >= zoom_start) & (t <= zoom_end)\n')
    elif 't_zoom = t[mask_zoom][:, 0]' in line:
        new_source2.append('t_zoom = t[mask_zoom]\n')
    elif 'pre_mask = (t[:, 0]' in line:
        new_source2.append('pre_mask = (t >= 400) & (t < 500)\n')
    elif 'post_mask = (t[:, 0]' in line:
        new_source2.append('post_mask = (t >= 500) & (t < 1500)\n')
    else:
        new_source2.append(line)
cell15['source'] = new_source2

with open(path, 'w') as f:
    json.dump(nb, f, indent=1)

print('Notebook fixed.')
