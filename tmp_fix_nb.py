import json, re, os

nb_path = "sandbox/ablation_20260504_120703/qwen36-35b/with_skills/simulate_region_stimulus/workflow.ipynb"
with open(nb_path, "r") as f:
    nb = json.load(f)

# Find the stimulus markdown cell and fix text
for cell in nb["cells"]:
    if cell["cell_type"] == "markdown":
        src = "".join(cell["source"])
        if "indices 24 and 25" in src:
            new_src = src.replace("regions pericalcarine, indices 24 and 25", "indices 35 = rV1 and 73 = lV1")
            cell["source"] = [new_src]
    elif cell["cell_type"] == "code":
        src = "".join(cell["source"])
        if "stim_weights[[24, 25], 0]" in src:
            src = src.replace("stim_weights[[24, 25], 0] = numpy.array([2.0, 2.0])",
                              "stim_weights[[35, 73], 0] = numpy.array([2.0, 2.0])")
        if 'v1_l = [i for i, l in enumerate(labels) if "pericalcarine"' in src:
            # Replace the whole region identification block
            old_block = '''# Identify key region indices by name
labels = list(conn.region_labels)
v1_l = [i for i, l in enumerate(labels) if "pericalcarine" in l.lower() and "left" in l.lower()][0]
v1_r = [i for i, l in enumerate(labels) if "pericalcarine" in l.lower() and "right" in l.lower()][0]
v2_l = [i for i, l in enumerate(labels) if "lateral occipital" in l.lower() and "left" in l.lower()][0]
m1_l = [i for i, l in enumerate(labels) if "precentral" in l.lower() and "left" in l.lower()][0]
thal_l = [i for i, l in enumerate(labels) if "thalamus" in l.lower() and "left" in l.lower()][0]'''
            new_block = '''# Identify key region indices by name
labels = list(conn.region_labels)
v1_l = [i for i, l in enumerate(labels) if l.lower() == "lv1"][0]
v1_r = [i for i, l in enumerate(labels) if l.lower() == "rv1"][0]
v2_l = [i for i, l in enumerate(labels) if l.lower() == "lv2"][0]
m1_l = [i for i, l in enumerate(labels) if l.lower() == "lm1"][0]
thal_l = [i for i, l in enumerate(labels) if l.lower() == "lhc"][0]'''
            src = src.replace(old_block, new_block)
        cell["source"] = [src]

# Ensure JSON output uses actual newlines in arrays for each line (best-effort)
for cell in nb["cells"]:
    if cell["cell_type"] in ("code", "markdown"):
        src = "".join(cell["source"])
        # Re-split by lines so that array format uses proper newlines
        cell["source"] = [line + "\n" for line in src.splitlines()]

with open(nb_path, "w") as f:
    json.dump(nb, f, indent=1, ensure_ascii=False)

# Validate JSON
with open(nb_path, "r") as f:
    json.load(f)
print("Notebook updated and JSON valid.")
