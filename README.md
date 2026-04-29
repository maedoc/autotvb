# Autotvb — Autobuilding Domain-Specific Skills for Scientific Notebook Generation

## What This Project Is

Autotvb is a self-improving system that generates scientifically-valid computational neuroscience notebooks for [The Virtual Brain (TVB)](https://www.thevirtualbrain.org/) using AI agents. It combines a **navigator/driver agent pair** with a **structured skill library** that is iteratively refined through benchmarking, evaluation, and targeted mutation.

The core idea: **if you can encode domain expertise into composable agent skills, you can automate the generation of research-grade scientific code** — and you can measure whether it works.

## The Problem

Large language models can write TVB simulation code, but they make domain-specific mistakes:

- Using `sim.run()` as if it returns a generator (it returns a list of monitor tuples)
- Passing paper parameter names directly to TVB constructors (`tau0` instead of `tau`, `C1` instead of `a_1`)
- Confusing `monitors.SEEG` with `monitors.iEEG`
- Forgetting to activate the TVB Python venv before imports
- Writing analysis code that doesn't match the scientific regime (e.g., PSD on seizure data without burn-in removal)

Each mistake is individually small, but together they produce notebooks that compile but produce meaningless results. In computational neuroscience, **correct code that answers the wrong scientific question is worse than broken code** — because it's harder to detect.

## The Approach: Skill-Driven Agent Pairs

### Agent Architecture

```
┌─────────────┐     message     ┌─────────────┐
│  Navigator   │ ──────────────> │   Driver     │
│  (planner)   │ <────────────── │  (coder)     │
│              │   notebook+log  │              │
└─────────────┘                  └──────┬───────┘
      │                                 │
      │                            ┌────▼─────┐
      │                            │  Execute  │
      │                            │  (TVB     │
      │                            │   venv)   │
      │                            └───────────┘
      │                                 │
      ▼                                 ▼
 ┌─────────┐                    ┌──────────┐
 │ Evaluate │                    │ notebook │
 │ (judge)  │                    │  + log   │
 └─────────┘                    └──────────┘
```

- **Navigator**: Plans the approach, reviews driver output, decides when to terminate
- **Driver**: Writes the notebook using skills, reviews execution errors, fixes bugs
- **Evaluator**: Scores the final notebook on 4 dimensions (1–5 scale)

Each agent loads only the **skills relevant to the current goal**, keeping prompt payload under 25KB.

### Skill Library

Skills are small (1–3KB) Markdown files that encode executable domain knowledge:

| Skill | Purpose |
|---|---|
| `boilerplate` | TVB imports, Simulator assembly, `sim.run()` vs `sim()` patterns |
| `tvb-api-mappings` | Paper→TVB parameter name translation table |
| `parameter-sweep` | Grid search with per-config Simulator rebuild |
| `heterogeneous-params` | Region-specific parameter arrays |
| `graph-metrics` | Kuramoto order, coherence, global efficiency, SC-FC correlation |
| `connectome-surgery` | Zeroing connectivity rows/columns (tumor, stroke) |
| `seizure-detection` | LFP thresholding, event detection, recruitment latency |
| `analysis` | FC, PSD, time-series plots, burn-in removal |
| `surface-forward` | Cortex, RegionMapping, forward solution setup |
| `notebook-format` | Jupyter cell structure, `\n` literal bug avoidance |

Skills are **keyword-filtered per goal** — an Alzheimer's simulation loads `parameter-sweep` + `heterogeneous-params` but not `stimulus` or `surface-forward`. This reduces prompt payload from ~38KB (all skills) to ~22KB (relevant skills), cutting per-turn latency from 15+ minutes to 5–8 minutes.

### Benchmark Goals

The system is evaluated against **30 benchmark goals** across two tiers:

**Tutorial goals** (20): Basic TVB operations — region simulation, surface simulation, stochastic integration, BOLD monitoring, epilepsy modeling. Average score: **3.79/5.0** (baseline), rising to **4.2+** after skill engineering.

**Paper-grounded research goals** (10): Reproductions of published TVB studies:
- Epilepsy: VEP Epileptor with permittivity coupling (Jirsa 2017)
- Stroke: SJ3D + BOLD prediction (Falcon 2016)
- Alzheimer's: Aβ effect on EEG slowing (Stefanovski 2019)
- Depression: GABA TEP with JansenRit (Hofsähs 2026)
- Depression: rTMS with Wilson-Cowan (Iliaens 2021)
- Schizophrenia: NRG1 knockout with Epileptor (Costa-Klein 2020)
- Tumor: Virtual resection (Aerts 2020)
- tDCS: FC modulation (Kunze 2016)
- Epilepsy: Bayesian fitting (Jirsa 2017 Methods)
- Parameter space exploration (Falcon/Deco methodology)

## What We Learned

### The measurement system is the real product

The autonomous mutation loop contributed ~5% of score improvement. Manual skill engineering contributed ~95%. But the **batch benchmarking pipeline** — run 20 goals in parallel, score each, aggregate patterns — was the single highest-leverage investment. It turned "I think this skill helps" into "this skill raised correctness by 0.8 points across 12 goals."

### Evaluator hallucinations are a real danger

Our evaluator was downvoting correct code because it believed `sim.run()` returns a generator. In reality, it returns a list. Correcting this single misconception raised 3 goals by 0.25–2.0 points. **The evaluator must encode domain-specific API facts**, not just general code review criteria.

### Paper parameter names ≠ TVB parameter names

Published papers use names like `tau0`, `C1`, `gamma` that map to TVB traits `tau`, `a_1`, `bb`. Without an explicit mapping table loaded early in the prompt, agents use paper names directly and produce TraitTypeErrors. A 1.5KB `tvb-api-mappings` skill solved this.

### Skills must be small and composable

Early monolithic skills (15KB+) caused 15+ minute LLM turns and low signal-to-noise. The current 1–3KB per-skill approach with keyword filtering keeps latency manageable and makes mutations precise — a change to `boilerplate` doesn't affect `analysis`.

### The autonomous loop is premature

Until skills cover the domain thoroughly and baseline scores stabilize, the mutation-selection loop adds noise. It becomes valuable for fine-tuning (e.g., "optimize token efficiency without losing correctness"), but not for capability building.

## Key Metrics

| Metric | Value |
|---|---|
| Tutorial goal average | ~3.79 → ~4.2+ (with fixed evaluator) |
| Best single goal | 5.00/5.00 (region simulation, surface+SEEG) |
| Skills | 14 active (driver: 10, navigator: 4) |
| Skill payload per goal | ~22KB (filtered from 38KB total) |
| Per-turn latency | 5–8 min (with filtering) |
| Paper-grounded goals | 10 (unvalidated — blocked by infrastructure bugs) |
| Total git commits | ~30 |

## Repository Structure

```
autotvb/
├── bin/                          # Pipeline scripts
│   ├── run_trial.sh              # Single navigator/driver trial
│   ├── evaluate.sh               # Structured notebook evaluation
│   ├── overnight_batch.sh        # Parallel 10-goal batch runner
│   ├── filter_skills.sh          # Keyword-based skill selection
│   ├── autoresearch.sh           # Mutation-selection loop
│   └── mutate.sh                 # JSON mutation planner
├── prompts/
│   ├── driver/role.md            # Driver system prompt
│   └── navigator/role.md         # Navigator system prompt
├── skills-in-progress/
│   ├── driver/                   # Code generation skills (10)
│   └── navigator/                # Planning/review skills (4)
├── benchmarks/
│   ├── goals/                    # 20 tutorial benchmark goals
│   └── goals_research/           # 10 paper-grounded research goals
├── CHANGELOG.md                  # Detailed progress log
├── PLAN.md                       # Prioritized roadmap
└── ARCHITECTURE.md               # System design document
```

## Getting Started

```bash
# Prerequisites: TVB installed in /tmp/tvb_env, pi CLI available

# Run a single trial
PI_MODEL=ollama/kimi-k2.6:cloud bash bin/run_trial.sh \
    benchmarks/goals_research/alzheimers_abeta_ei.GOAL.md 5 sandbox/trial_alzheimers

# Run all 10 research goals overnight
PI_MODEL=ollama/kimi-k2.6:cloud bash bin/overnight_batch.sh

# Evaluate a completed notebook
PI_MODEL=ollama/kimi-k2.6:cloud bash bin/evaluate.sh \
    sandbox/trial_alzheimers/workflow.ipynb \
    benchmarks/goals_research/alzheimers_abeta_ei.GOAL.md \
    sandbox/trial_alzheimers/evaluation.json

# Poll batch progress
bash bin/poll_batch.sh sandbox/batch_research_*/
```

## Broader Applicability

The pattern — composable domain skills + agent pairs + structured evaluation + iterative benchmarking — is not TVB-specific. It should work for any domain where:

1. **API surface is large and error-prone** — LLMs need explicit guard rails
2. **Correctness requires domain-specific validation** — generic code review isn't enough
3. **Benchmarks can be automated** — you can score outputs without human judgment
4. **Skills compose** — the domain decomposes into independent concerns (imports, parameters, analysis, visualization)

Candidates: quantum computing frameworks, finite element analysis pipelines, bioinformatics workflows, multi-physics simulators.
