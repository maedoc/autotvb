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
| Tutorial goals | 20 | TVB documentation examples | Baselined: avg ~3.8/5.0 (no skills) → 4.50/5.0 (with skills) |
| Paper-grounded goals | 10 | Published TVB studies (Jirsa, Falcon, Stefanovski, etc.) | Evaluated: avg ~4.17/5.0 (no skills) → 4.46/5.0 (with skills) |
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

On well-documented tasks (tutorial goals), frontier models score 4.5–5.0 without skills. Skills help most on edge cases and unfamiliar APIs. This is expected — the real test is whether skills close the gap for small models. The ablation study confirmed this: kimi-1T gains only +0.09 from skills, while ministral-14B gains +0.39.

### Skills can over-constrain large models

The ablation study revealed an unexpected finding: skills hurt scientific validity for large models (gemma4-31b: −0.32, qwen3.6: −0.48, kimi-1T: −0.31). The skills nudge models toward canonical TVB patterns that are correct but uncreative. Large models produce better scientific analysis when given freedom; skills reduce that freedom.

### 8B models can't exploit skill context

rnj-1 (8B) gained only +0.08 from skills despite the skills containing targeted, high-leverage TVB API facts. The model lacks the capacity to follow the multi-turn tool-use protocol with 22KB of skill context — it produces empty or garbled output. Skills as payload have a minimum model-size threshold.

### The autonomous mutation loop is premature

~95% of measured improvement came from manual skill engineering (identifying failure patterns, writing targeted skills). The mutation-selection loop contributed ~5%. The loop may become valuable for fine-tuning skills once baseline coverage is sufficient, but capability-building still requires human pattern recognition.

### Cloud API rate limits are a real constraint

Running 108 concurrent trials across 6 models hit API rate limits hard. Limiting to 3–4 concurrent requests was essential. The full ablation took ~12 hours of wall-clock time with that throttle. Batch experiment design must account for API capacity, not just GPU capacity.

## Key Metrics

| Metric | Value |
|---|---|
| Active skills | 18 (driver: 14, navigator: 4) |
| Skill payload | ~41KB total, ~22KB per goal (filtered) |
| Benchmark goals | 30 (20 tutorial + 10 paper-grounded) |
| Best single score | 5.0/5.0 (analyze-power-spectra, using-your-own-connectivity) |
| Batch 3 avg (kimi + skills) | 4.50/5.0 across 24 goals |

## Multi-Model Ablation Study

The critical experiment: **run the same benchmark goals across a range of model sizes, with and without skills, and measure the score delta.** 9 shared goals were evaluated across 6 models (8B to 1T), each in with-skills and without-skills conditions (108 total trials).

### Overall Scores

| Model | Params | Without Skills | With Skills | Skill Δ |
|---|---|---|---|---|
| rnj-1 | 8B | 4.11 | 4.19 | +0.08 |
| ministral-3 | 14B | 4.25 | 4.64 | **+0.39** |
| gpt-oss | 20B | 4.58 | 4.66 | +0.07 |
| gemma4 | 31B | 4.75 | 4.72 | −0.03 |
| qwen3.6 | 35B | 4.57 | 4.47 | −0.10 |
| kimi-k2.6 | 1T | 4.47 | 4.56 | +0.09 |

### Per-Dimension Breakdown

| Model | Params | C (ws/ns) | Q (ws/ns) | S (ws/ns) | T (ws/ns) |
|---|---|---|---|---|---|
| rnj-1 | 8B | 4.25 / 4.00 | 4.25 / 4.22 | 4.25 / 4.33 | 4.00 / 3.89 |
| ministral-3 | 14B | 4.71 / 3.86 | 4.71 / 4.43 | 4.71 / 4.57 | 4.43 / 4.14 |
| gpt-oss | 20B | 4.62 / 4.78 | 4.62 / 4.67 | 4.88 / 4.56 | 4.50 / 4.33 |
| gemma4 | 31B | 5.00 / 4.86 | 5.00 / 5.00 | 4.25 / 4.57 | 4.62 / 4.57 |
| qwen3.6 | 35B | 4.88 / 4.57 | 4.62 / 4.57 | 4.38 / 4.86 | 4.00 / 4.29 |
| kimi-k2.6 | 1T | 4.89 / 4.38 | 4.78 / 4.38 | 4.44 / 4.75 | 4.11 / 4.38 |

C = correctness, Q = code quality, S = scientific validity, T = token efficiency. ws = with skills, ns = without skills.

### Key Findings

1. **Skills help most at 14B**: ministral-3 gained +0.39 overall, +0.86 on correctness. This is the strongest evidence for the thesis — a mid-size model benefits most from domain expertise compression.

2. **Large models don't need skills for code quality**: gemma4-31b scores 5.00/5.00 on both code dimensions regardless of skills. The benefit is zero because the model already writes clean code.

3. **Skills hurt scientific validity for large models**: gemma4 (−0.32), qwen3.6 (−0.48), and kimi-1T (−0.31) all score lower on scientific validity with skills. The skills may be **over-constraining** large models — nudging them toward canonical TVB patterns at the cost of creative, domain-appropriate analysis.

4. **8B models can't use skills well**: rnj-1 gained only +0.08 despite skills containing targeted TVB API facts. The model lacks the capacity to follow multi-turn tool-use protocols with 22KB of skill context.

5. **Frontier model WITHOUT skills (4.47) is beatable**: gemma4-31b without skills scores 4.75 and ministral-3 with skills scores 4.64 — both exceed kimi-1T without skills. Skills partially close the gap but model capability matters more.

### What This Means for the Thesis

The thesis — *"small models with skills match frontier models without them"* — is **partially validated**:

- ✅ Skills provide a large benefit to mid-size models (14B: +0.39)
- ✅ Skills improve correctness across most models (especially 14B: +0.86)
- ❌ Skills over-constrain large models on scientific validity
- ❌ 8B models lack capacity to exploit skill context
- ❌ Model capability dominates: gemma4-31b without skills (4.75) > kimi-1T without skills (4.47)

The refined claim: **skills are a 14–31B sweet spot technology** — they compress domain expertise into a form that mid-size models can exploit for correctness gains, but they're not yet a substitute for raw model capability at the extremes.

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
