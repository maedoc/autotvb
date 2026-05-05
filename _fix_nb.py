import json
path = '/home/duke/src/autotvb/sandbox/ablation_20260504_120703/ministral-14b/without_skills/schizophrenia_nrg1_ei/workflow.ipynb'
with open(path, 'r') as f:
    lines = f.readlines()
for i, line in enumerate(lines):
    if 'print(\"\\n\"' in line or 'print(\"\\n' in line:
        print(i, repr(line))
    if 'Quantitative Comparison Across Genotypes' in line:
        print(i, repr(line))
