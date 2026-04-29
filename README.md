# Autotvb — Experimental Architecture for Autobuilding Domain Skills

## The Core Thesis

**Use large models and goals derived from scientific literature to build composable agent skills, then validate that those skills enable smaller models to perform as domain experts.**

Autotvb is not a TVB notebook generator. It is an experimental architecture for testing whether the skill-creation process works at all. TVB (The Virtual Brain) is the validation domain — a computational neuroscience framework with a large, error-prone API surface, published benchmarks, and objectively scorable outputs. If the architecture produces skills that guide a 4B-parameter model to write valid TVB simulations, the approach is validated.

## The Problem This Solves

Frontier LLMs can write domain-specific code, but they are expensive, slow, and locked behind API gates. A 4B model running locally on a laptop cannot. The gap between "frontier model with deep domain knowledge" and "small model with no domain knowledge" is where skills live.

Skills are not prompts. They are compressed, composable, validated domain expertise — the distillation of what the large model learned through trial, error, and evaluation into reusable artifacts that any model can load. Think of them as **the output of an automated curriculum design process**.

The key claim: **if skills are well-built, a small model with skills outperforms a large model without them** on domain-specific tasks. Autotvb exists to test this claim.

## How It Works

### The Skill-Creation Loop

```
┌──────────────────────────────────────────────────────────────┐
│                    Skill Creation Phase                       │
│                                                              │
│  Literature ──► Goals ──► Large Model ──► Notebook ──► Score │
│                  │            │                              │
│                  │            ▼                              │
│                  │       Failure Analysis                    │
│                  │            │                              │
│                  │            ▼                              │
│                  └──── Skills ("best so far") ◄── Mutation   │
│                                                              │
│  Model: frontier (kimi-k2, deepseek-v4, etc.)               │
│  Goals: derived from published papers                        │
│  Skills: never "done" — always "best version we've measured" │
└──────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌──────────────────────────────────────────────────────────────┐
│                    Skill Validation Phase                     │
│                                                              │
│  Small Model + Skills ──► Notebook ──► Score                 │
│                                                              │
│  Question: does a 4B/9B model with skills match or beat      │
│  a frontier model WITHOUT skills on the same goals?          │
└──────────────────────────────────────────────────────────────┘
```

The architecture has two distinct phases:

1. **Skill creation**: A frontier model attempts domain tasks, gets scored, and the failure patterns are compressed into skills. This is expensive and iterative. The output is a skill library — never final, always "best so far."

2. **Skill validation**: A small model loads the skills and attempts the same tasks. If scores are comparable to the frontier model's baseline, the skills are working. If not, the skills need more work.

### What Skills Actually Are

Skills are small (1–3KB) Markdown files encoding executable domain knowledge. Examples from the TVB domain:

| Skill | What It Captures |
|---|---|
| `boilerplate` | TVB Simulator assembly pattern — `sim.run()` returns a list, not a generator; configure before run |
| `tvb-api-mappings` | Paper parameter names → TVB trait names: `tau0` → `tau`, `C1` → `a_1`, `gamma` → `bb` |
| `connectome-surgery` | How to zero connectivity matrix rows/columns for virtual lesion simulations |
| `seizure-detection` | LFP computation, amplitude thresholding, recruitment latency from TVB source dynamics |

Each skill is the product of repeated failure. The `boilerplate` skill exists because frontier models consistently made the same `sim.run()` mistake. The `tvb-api-mappings` skill exists because published papers use different names than the TVB API. Skills are **scar tissue from measured failures**.

### Why Skills Must Be "Best So Far"

No skill is ever declared correct or complete. The domain evolves (new TVB versions, new APIs), the goals evolve (new papers, new clinical targets), and the models evolve (new capabilities, new failure modes). A skill that produces correct code today may break tomorrow when TVB renames a parameter or adds a required argument.

The architecture treats skills as a **versioned, measured, continuously-improving artifact** — like a test suite that grows coverage over time. The benchmark scores are the CI system.

## Validation Domain: The Virtual Brain (TVB)

TVB was chosen as the validation domain for specific reasons:

1. **Large, error-prone API surface** — Hundreds of classes with non-obvious constructor signatures, trait-based parameter systems, and version-specific naming changes. LLMs get the details wrong in reproducible ways.

2. **Published ground truth** — Decades of computational neuroscience papers describe exactly what simulations should produce (seizure propagation patterns, BOLD signal characteristics, EEG frequency shifts). These become objective benchmarks.

3. **Automatable scoring** — Notebooks either execute correctly or they don't. Analysis outputs (PSD peaks, correlation coefficients, seizure counts) can be checked against expected ranges. No human judgment required for basic scoring.

4. **Multiple difficulty tiers** — From "simulate a region" (easy) to "fit epilepsy parameters via Bayesian search" (hard). This lets us measure skill quality across a range of complexity.

### Current TVB Benchmarks

| Tier | Count | Source | Status |
|---|---|---|---|
| Tutorial goals | 20 | TVB documentation examples | Baselined: avg ~3.8/5.0 |
| Paper-grounded goals | 10 | Published TVB studies (Jirsa, Falcon, Stefanovski, etc.) | Unvalidated (infrastructure bugs) |
| Clinical validation | future | Patient-specific TVB outputs | Not started |

The 10 paper-grounded goals span epilepsy, stroke, Alzheimer's, depression, schizophrenia, tumor resection, tDCS, and parameter space exploration — a broad test of whether skills transfer across clinical applications within the same domain.

## What We've Learned So Far

### The measurement system IS the architecture

The batch evaluation pipeline — run N goals in parallel, score each on 4 dimensions, aggregate patterns — is the most valuable component. It turned qualitative "I think this helps" into quantitative "this raised correctness by 0.8 points across 12 goals." Without measurement, skill creation is just prompt engineering with extra steps.

### Skills must be discovered, not designed

Every skill in the library was created in response to a measured failure pattern, not from upfront design. The `tvb-api-mappings` skill exists because notebooks consistently used `tau0` instead of `tau`. The `notebook-format` skill exists because Jupyter cell serialization produced `\n` literals inside JSON strings. Design-first skills would have missed these entirely.

### The evaluator can hallucinate too

Our evaluator was downvoting correct code because it believed `sim.run()` returns a generator (it returns a list). Fixing this single evaluator misconception raised 3 goals by 0.25–2.0 points. **Evaluation quality caps skill quality** — if the evaluator is wrong, the skills converge toward the wrong target.

### Frontier models don't need skills as much

On well-documented tasks (tutorial goals), frontier models score 4.5–5.0 without skills. Skills help most on edge cases and unfamiliar APIs. This is expected — the real test is whether skills close the gap for small models.

### The autonomous mutation loop is premature

~95% of measured improvement came from manual skill engineering (identifying failure patterns, writing targeted skills). The mutation-selection loop contributed ~5%. The loop may become valuable for fine-tuning skills once baseline coverage is sufficient, but capability-building still requires human pattern recognition.

## Key Metrics

| Metric | Value |
|---|---|
| Active skills | 14 (driver: 10, navigator: 4) |
| Benchmark goals | 30 (20 tutorial + 10 paper-grounded) |
| Tutorial baseline | ~3.8/5.0 (best: 5.0) |
| Paper-goal baseline | Not yet measured |
| Skill payload per goal | ~22KB (filtered from 38KB total) |
| Small-model scores | Not yet measured |

## The Multi-Model Benchmark (Next Step)

The critical experiment: **run the same benchmark goals across a range of model sizes, with and without skills, and measure the score delta.**

| Model | Size | With Skills | Without Skills | Delta |
|---|---|---|---|---|
| kimi-k2.6 (cloud) | — | ? | ? | ? |
| deepseek-v4-flash (cloud) | — | ? | ? | ? |
| qwen3.6 | 23B | ? | ? | ? |
| gemma4 | 26B | ? | ? | ? |
| gemma4:e4b | 4B | ? | ? | ? |
| qwen3.5:9b | 9B | ? | ? | ? |

If the delta (with skills − without skills) is large for small models and small for large models, the thesis is validated: skills are the mechanism for transferring frontier-model domain expertise to local models.

## Broader Applicability

If the approach works on TVB, it should transfer to any domain where:

1. **The API surface is large enough** that LLMs make systematic, reproducible errors
2. **Ground truth exists** in the form of published results, test suites, or objective evaluation criteria
3. **Tasks decompose** into composable sub-problems (imports, parameters, execution, analysis)
4. **Scoring can be automated** — no human-in-the-loop required for the evaluation loop

Candidate domains: quantum computing (Qiskit/Cirq), finite element analysis (FEniCS/COMSOL), bioinformatics (Scanpy/DESeq2), robotics (ROS2), chip design (OpenROAD).

## Repository Structure

```
autotvb/
├── bin/                          # Pipeline scripts
│   ├── run_trial.sh              # Single navigator/driver trial
│   ├── evaluate.sh               # Structured notebook evaluation
│   ├── overnight_batch.sh        # Parallel batch runner
│   ├── filter_skills.sh          # Per-goal skill selection
│   └── autoresearch.sh           # Mutation-selection loop
├── prompts/
│   ├── driver/role.md            # Driver system prompt
│   └── navigator/role.md         # Navigator system prompt
├── skills-in-progress/           # "Best so far" — never final
│   ├── driver/                   # Code generation skills
│   └── navigator/                # Planning/review skills
├── benchmarks/
│   ├── goals/                    # Tutorial benchmark goals
│   └── goals_research/           # Paper-grounded goals
├── PLAN.md                       # Phased roadmap
├── CHANGELOG.md                  # Detailed progress log
└── ARCHITECTURE.md               # System design document
```

## Quick Start

```bash
# Run a single trial (skill creation phase — frontier model)
PI_MODEL=ollama/kimi-k2.6:cloud bash bin/run_trial.sh \
    benchmarks/goals_research/alzheimers_abeta_ei.GOAL.md 5 sandbox/trial_alzheimers

# Validate skills with a small model
PI_MODEL=ollama/gemma4:e4b bash bin/run_trial.sh \
    benchmarks/goals_research/alzheimers_abeta_ei.GOAL.md 5 sandbox/validate_4b

# Run all 10 research goals overnight
PI_MODEL=ollama/kimi-k2.6:cloud bash bin/overnight_batch.sh

# Evaluate a completed notebook
PI_MODEL=ollama/kimi-k2.6:cloud bash bin/evaluate.sh \
    sandbox/trial_alzheimers/workflow.ipynb \
    benchmarks/goals_research/alzheimers_abeta_ei.GOAL.md \
    sandbox/trial_alzheimers/evaluation.json
```
