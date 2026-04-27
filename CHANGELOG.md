# Autoresearch Changelog

## 2026-04-27 — Multi-Skill Architecture Refactor

### What changed
- **Split monolithic skills into focused sub-skills:**
  - Driver: `boilerplate`, `stimulus`, `surface-forward`, `noise-and-integrator`, `analysis`
  - Navigator: `planning`, `code-review`, `scientific-validity`, `common-models`
- **Updated `run_trial.sh`** to auto-discover all skills via `find` and pass them to `pi` with `--skill` flags (instead of inlining via `cat`).
- **Updated `mutate.sh`** to dynamically enumerate all prompt/skill files and explicitly instruct the mutation agent to create, split, merge, or delete skills — not just edit in-place.
- **Updated `orchestrator.sh`** to dynamically discover all `.md` files under `prompts/` and `skills-in-progress/` as mutation targets, instead of hardcoding 4 files.

### Why
Monolithic skills limited the granularity of evolution. By allowing the mutator to spawn new focused skills (e.g., separating "stimulus" from "boilerplate"), improvements can be more targeted and composable.

### Current best score
- Baseline (trial 1): 2.75 on `visual_erp.GOAL.md`
- Post-mutation (trial 2): 3.50 on `visual_erp.GOAL.md`
- Multi-skill + targeted mutation (trial 3): **4.75** on `visual_erp.GOAL.md`

### Key Learnings
1. **Multi-skill architecture enables surgical mutations.** When the mutator can target a specific sub-skill (e.g. `scientific-validity`) rather than appending to a monolithic blob, improvements are precise and composable.
2. **Execution must be decoupled from the LLM agent.** Writing + executing + reporting in a single `pi` call caused timeouts. The write → local exec → review pipeline is fast and reliable.
3. **Scientific validity was the bottleneck, not correctness.** Trial 3 proved the notebooks were already mechanically correct (proper API calls, `configure()`, noise shape). The gap was in *analysis choices* — windowing, regime claims, aligning computations with the scientific question.
4. **The mutator needs explicit authority.** The mutation agent correctly diagnosed all failures once we gave it permission (in `mutate.sh`) to edit, create, split, merge, and delete skills — not just tweak existing files in place.
5. **Venv awareness matters.** The driver didn't know TVB lived in `/tmp/tvb_env` without an explicit note in the system prompt. Adding "IMPORTANT ENVIRONMENT NOTE" to the driver prompt solved import failures.
6. **Output/Claim drift guards work.** Adding explicit checklist items like "if prose claims 10 Hz, the PSD peak must agree within 1 Hz" directly raised scientific_validity from 2 to 5.

### Trial 3 results
- **Score**: 4.75 (correctness=5, code_quality=5, scientific_validity=5, token_efficiency=4)
- **Turns**: 2 (down from 4)
- **Key improvement**: Scientific validity jumped from 2→5 by addressing burn-in windowing, regime verification, and stimulus-locked analysis.

### Next steps
- Test generalization on other goals (resting-state, epilepsy).
- Consider whether token_efficiency can be improved (currently 4/5).

## 2026-04-27 — Trial 4: Generalization to Epilepsy

### Setup
- Goal: `tutorial_s6_modelingepilepsy.GOAL.md` (Epileptor model, 6 state variables, heterogeneous x0, seizure propagation metrics)
- Branch: `trial-4-epilepsy`
- Skills: same multi-skill architecture from trial 3

### Results
- **Score**: 3.50 (correctness=3, code_quality=4, scientific_validity=3, token_efficiency=4)
- **Turns**: 2
- **Execution**: succeeded after driver self-repair of malformed JSON `\n` in notebook source strings

### Generalization gap
| Goal | Score | Notes |
|---|---|---|
| visual_erp | **4.75** | regime verification + windowing fixes clearly helped |
| epilepsy | **3.50** | ~1.25 point drop on harder goal |

### What the evaluator wanted
1. **Seizure-propagation metrics** (not just generic FC/PSD) — the Epileptor-specific analysis skill is missing.
2. **Broadcasting bug claim** — evaluator flagged a stimulus weight assignment bug, though execution succeeded after driver fix. Likely a false positive from nbconvert output parsing.

### New learning
7. **Goal-specific analysis skills are needed.** Visual-ERP fixes (windowing, regime verification) don't transfer to epilepsy because the required post-hoc analyses are totally different: seizure count, propagation velocity, ictal/interictal ratio, etc. The mutator should spawn a goal-specific analysis skill when it detects a novel task type.

### New learning
8. **Driver can self-repair malformed notebooks.** The first write produced literal `\n` inside JSON source strings; the driver diagnosed and fixed this in its review turn without navigator intervention. This resilience is valuable.

## 2026-04-27 — Infrastructure: Mutation Pipeline + Batch System

### What changed
- **Added `bin/apply_mutation.sh`** — Parses structured JSON mutation plans and applies edits mechanically (edit/create/delete/append).
- **Redesigned `bin/mutate.sh`** — Now instructs the mutation agent to output ONLY JSON, with a strict schema. Extractor uses balanced-brace parsing to robustly extract the JSON block.
- **Added `bin/run_batch.sh`** — Parallel baseline sweep across all goals, with concurrency control via `wait -n` semaphore.
- **Added `bin/autoresearch.sh`** — Minimal autonomous mutation loop: trial → evaluate → mutate → apply → validate → keep/revert.
- **Fixed `run_trial.sh` hardcoded seed** — Replaced visual-ERP-specific `NAVINIT` with goal-agnostic seed that lets the navigator derive a plan from the goal itself.
- **Created `skills-in-progress/driver/notebook-format/SKILL.md`** — Addresses the `\n` serialization bug where notebook code cells contained literal backslash-n characters instead of real newlines.

### New learning
9. **Structured JSON mutations are necessary for automation.** The mutator can produce valid JSON plans consistently when given a strict schema. Human-readable markdown plans are insufficient for unattended application.
10. **Balanced-brace extraction beats regex for JSON extraction.** A naive `\{.*?\}` regex fails on nested braces inside string values. A simple depth-counter (`{` depth++, `}` depth--) correctly isolates the outermost JSON object.
11. **The seed message must be goal-agnostic.** Hardcoding a visual-ERP plan biases every goal toward Generic2dOscillator + V1/V2 stimulus. Replacing it with "read the goal and create a plan" gives ~3.5 on average but transfers to any goal.

### Batch system findings (preliminary)
| Goal | Score | Correctness | Code Quality | Scientific Validity | Token Efficiency |
|---|---|---|---|---|---|
| analyze_power_spectra | 3.50 | 4 | 4 | 2 | 4 |
| compare_connectivity_normalization | 3.25 | 2 | 3 | 3 | 5 |

The batch is running; more results will be collected overnight.

### Next steps
- Let batch complete overnight (~2 hrs remaining with 2 workers).
- Run `autoresearch.sh` on epilepsy goal (3.50 → target 4.75) to test full autonomous pipeline.
- Based on batch results, identify which dimensions need skill-level mutations per goal type.
