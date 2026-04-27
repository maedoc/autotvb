#!/usr/bin/env python3
"""Generate GOAL.md benchmarks from TVB demo notebooks by parsing notebook structure."""
import json, re, os, sys
from pathlib import Path

TVB_DEMOS = Path("/tmp/tvb-root/tvb_documentation/demos")
TVB_TUTORIALS = Path("/tmp/tvb-root/tvb_documentation/tutorials")
OUTDIR = Path("benchmarks/goals")

NOTEBOOKS = [
    TVB_TUTORIALS / "tutorial_s1_region_simulation.ipynb",
    TVB_TUTORIALS / "tutorial_s2_surface_simulation.ipynb",
    TVB_TUTORIALS / "tutorial_s3_exploring_a_model.ipynb",
    TVB_TUTORIALS / "tutorial_s4_EvokedResponsesInTheVisualCortex.ipynb",
    TVB_TUTORIALS / "tutorial_s5_ModelingRestingStateNetworks.ipynb",
    TVB_TUTORIALS / "tutorial_s6_ModelingEpilepsy.ipynb",
    TVB_DEMOS / "simulate_region_stimulus.ipynb",
    TVB_DEMOS / "simulate_surface_seeg_eeg_meg.ipynb",
    TVB_DEMOS / "exploring_the_bold_monitor.ipynb",
    TVB_DEMOS / "skewed_fc.ipynb",
    TVB_DEMOS / "simulate_reduced_wong_wang.ipynb",
    TVB_DEMOS / "simulate_region_jansen_rit.ipynb",
    TVB_DEMOS / "multiple_stimuli.ipynb",
    TVB_DEMOS / "analyze_power_spectra.ipynb",
    TVB_DEMOS / "compare_connectivity_normalization.ipynb",
    TVB_DEMOS / "stochastic_simulation.ipynb",
    TVB_DEMOS / "sandbox/surface_stochastic.ipynb",
    TVB_DEMOS / "sandbox/stochastic_simulation.ipynb",
    TVB_DEMOS / "using_your_own_connectivity.ipynb",
    TVB_DEMOS / "interacting_with_Allen.ipynb",
]

# Natural question templates keyed by detected keywords
QUESTION_PATTERNS = {
    "epileptor": "How can I model seizure propagation and interictal-ictal transitions in a patient-specific brain network using the Epileptor model?",
    "jansen_rit": "How do I simulate evoked responses with the Jansen-Rit neural mass model and analyze peak latencies?",
    "wong_wang": "How do I run a resting-state simulation with the Reduced Wong-Wang model and compare functional connectivity to structural connectivity?",
    "bold": "How do I simulate and extract the BOLD fMRI signal from a TVB simulation, and how do different HRF kernels affect the result?",
    "resting": "How can I simulate resting-state brain activity on a structural connectivity matrix and analyze the resulting functional connectivity patterns?",
    "stimulus": "How do I apply an external stimulus to specific brain regions in TVB and observe the evoked response propagate through the network?",
    "stimuli": "How do I apply multiple external stimuli to specific brain regions in TVB and observe the evoked response propagate through the network?",
    "surface": "How do I run a whole-brain simulation on a cortical surface mesh rather than at the region level?",
    "seeg": "How do I simulate invasive (sEEG) and non-invasive (EEG/MEG) recordings from a TVB surface simulation?",
    "eeg": "How do I simulate invasive (sEEG) and non-invasive (EEG/MEG) recordings from a TVB surface simulation?",
    "power_spectra": "How do I analyze the frequency content of simulated brain activity time series?",
    "connectivity": "How do I load, inspect, and normalize structural connectivity matrices in TVB?",
    "ica": "How do I decompose simulated resting-state activity into independent components?",
    "lesion": "How do focal structural lesions alter large-scale brain dynamics in TVB?",
    "phase_plane": "How do I explore the local dynamics of a neural mass model before running a full network simulation?",
    "exploring": "How do I explore the local dynamics of a neural mass model before running a full network simulation?",
    "allen": "How do I integrate data from the Allen Brain Atlas into a TVB workflow?",
    "gpu": "How can I accelerate TVB parameter sweeps using GPU backends?",
    "integrator": "How do I choose and configure numerical integrators for TVB simulations?",
    "mouse": "How do I set up a TVB simulation using mouse brain connectivity?",
    "encrypt": "How do I encrypt and decrypt TVB data for secure sharing?",
    "surrogate": "How do I generate surrogate connectivity matrices for null-model comparison?",
    "custom_connectivity": "How do I import and use my own structural connectivity data in TVB?",
    "parameter_sweep": "How do I systematically vary model parameters and compare simulation outcomes?",
    "stochastic": "How do I introduce controlled noise into TVB simulations and assess its effects?",
    "evoked": "How do I model a visual evoked potential (ERP) by stimulating V1/V2 in a large-scale brain network?",
    "erp": "How do I model a visual evoked potential (ERP) by stimulating V1/V2 in a large-scale brain network?",
    "corrcoef": "How do I compute and visualize functional connectivity matrices from simulated time series?",
    "default": "How do I build and run a TVB whole-brain simulation to answer a specific neuroscience question?",
}

def slugify(name):
    return re.sub(r'[^a-z0-9]+', '_', name.lower()).strip('_')

def extract_title(nb):
    for cell in nb.get('cells', []):
        if cell.get('cell_type') == 'markdown':
            src = ''.join(cell.get('source', []))
            m = re.search(r'^#+\s*(.+)', src, re.MULTILINE)
            if m:
                return m.group(1).strip()
    return "TVB Workflow"

def extract_code_cells(nb):
    code = []
    for cell in nb.get('cells', []):
        if cell.get('cell_type') == 'code':
            code.append(''.join(cell.get('source', [])))
    return '\n'.join(code)

def detect_components(code):
    comps = {
        'models': list(set(re.findall(r'models\.([A-Za-z0-9_]+)', code))),
        'coupling': list(set(re.findall(r'coupling\.([A-Za-z0-9_]+)', code))),
        'integrators': list(set(re.findall(r'integrators\.([A-Za-z0-9_]+)', code))),
        'monitors': list(set(re.findall(r'monitors\.([A-Za-z0-9_]+)', code))),
        'stimuli': list(set(re.findall(r'patterns\.([A-Za-z0-9_]+)', code))),
        'connectivity': bool(re.search(r'connectivity\.Connectivity', code)),
        'surface': bool(re.search(r'Cortex|surface|RegionMapping', code)),
        'plots': bool(re.search(r'plt\.|plot\(|imshow|figure', code)),
        'analysis': bool(re.search(r'corrcoef|fft|psd|ica|pca|ttest|arctanh', code)),
    }
    return comps

def build_question(title, code, comps):
    low = (title + ' ' + code).lower()
    for keyword, q in QUESTION_PATTERNS.items():
        if keyword in low:
            return q
    return QUESTION_PATTERNS['default']

def build_expected(comps):
    out = []
    out.append("1. Import TVB (`from tvb.simulator.lab import *`) and standard libraries.")
    if comps['connectivity']:
        out.append("2. Load and configure structural connectivity (`Connectivity.from_file()`) with appropriate speed.")
    if comps['models']:
        model_str = ', '.join(f'`models.{m}`' for m in comps['models'])
        out.append(f"3. Instantiate the neural-mass model(s): {model_str}.")
    if comps['coupling']:
        coup_str = ', '.join(f'`coupling.{c}`' for c in comps['coupling'])
        out.append(f"4. Define coupling function: {coup_str}.")
    if comps['stimuli']:
        stim_str = ', '.join(f'`patterns.{s}`' for s in comps['stimuli'])
        out.append(f"5. Configure stimulus: {stim_str}.")
    if comps['integrators']:
        int_str = ', '.join(f'`integrators.{i}`' for i in comps['integrators'])
        out.append(f"6. Choose integrator: {int_str}.")
    if comps['monitors']:
        mon_str = ', '.join(f'`monitors.{m}`' for m in comps['monitors'])
        out.append(f"7. Attach monitor(s): {mon_str}.")
    out.append("8. Build and configure the `Simulator`, then run it.")
    if comps['analysis']:
        out.append("9. Perform post-hoc analysis (correlation, spectral, statistical tests, etc.).")
    if comps['plots']:
        out.append("10. Generate figures with matplotlib showing key results.")
    out.append("11. Include brief markdown comments explaining scientific rationale for parameter choices.")
    return '\n'.join(out)

def generate_goal(nb_path):
    with open(nb_path, 'r', encoding='utf-8') as f:
        nb = json.load(f)
    title = extract_title(nb)
    code = extract_code_cells(nb)
    comps = detect_components(code)
    
    question = build_question(title, code, comps)
    expected = build_expected(comps)
    
    body = f"""# Goal: {title}

## Scientific Question
{question}

## Expected Output
A single runnable Jupyter notebook that:
{expected}
"""
    return body

def main():
    OUTDIR.mkdir(parents=True, exist_ok=True)
    count = 0
    for nb_path in NOTEBOOKS:
        if not nb_path.exists():
            print(f"Skip missing: {nb_path}")
            continue
        slug = slugify(nb_path.stem)
        out = OUTDIR / f"{slug}.GOAL.md"
        goal = generate_goal(nb_path)
        out.write_text(goal, encoding='utf-8')
        print(f"Generated {out}")
        count += 1
    print(f"Done: {count} goals in {OUTDIR}")

if __name__ == '__main__':
    main()
