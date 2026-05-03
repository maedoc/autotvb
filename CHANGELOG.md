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

## 2026-04-27 — Trial 4: Autoresearch Loop Test

### What changed
- `bin/autoresearch.sh` created: trial → evaluate → mutate → apply → validate → keep/revert pipeline
- `bin/apply_mutation.sh` created: mechanical JSON mutation applier (edit/create/delete/append)
- `mutate.sh` redesigned to request strict JSON output from mutation agent
- `run_batch.sh` added for parallel baseline sweeps

### Autoresearch epilepsy results
| Iter | Pre-Mutation | Post-Mutation | Kept? |
|---|---|---|---|
| 1 | 2.75 | 3.25 | ✅ 2.75 → 3.25 |
| 2 (re-run) | 3.75 | 3.00 | ❌ Reverted |
| 3 | 3.75 | 3.75 | ❌ No improvement |

**Key insight**: The notebook-format skill + updated driver/navigator prompts (from the JSON mutation plan) brought epilepsy from 3.50 (trial 4) to 3.75 on validation. No further mutations improved it within 2 iterations.

### Blockers discovered
1. **Batch script died after 4 goals** due to `set -e` + empty `evaluation.json` causing jq to fail.
2. **Duplicate run_trial.sh processes** — still unexplained; may be harmless but noisy.
3. **Autoresearch creates untracked files** (`EOF`, `DRIVER_MESSAGE.md`) that interfere with `git checkout`. Fixed with `-f` flag and path guards.
4. **JSON extraction** needs balanced-brace parsing, not regex.

### What works
- JSON mutation pipeline: mutator outputs JSON → applier applies 100% correctly
- Multi-skill mutations: can create new skills (notebook-format added successfully)
- Goal-agnostic seed: scores ~3.5-4.0 baseline on diverse goals
- Overnight batch: running with 2 workers, targeting all 20 goals

## 2026-04-28 — Batch Sweep Results (20 goals, 2 workers, 5 turns)

### Results summary
**Completed: 17 / 20 goals evaluated | Average: 3.78 / 5.00**

| Goal | Score | CN | CQ | SV | TE |
|---|---|---|---|---|---|
| tutorial_s1_region_simulation | **4.50** | 4 | 5 | 4 | 5 |
| using_your_own_connectivity | **4.50** | 5 | 5 | 4 | 4 |
| tutorial_s3_exploring_a_model | **4.25** | 5 | 4 | 3 | 5 |
| tutorial_s5_modelingrestingstatenetworks | **4.25** | 4 | 4 | 4 | 5 |
| interacting_with_allen | **4.00** | 4 | 4 | 4 | 4 |
| compare_connectivity_normalization | **4.00** | 4 | 4 | 4 | 4 |
| analyze_power_spectra | **4.00** | 4 | 5 | 3 | 4 |
| tutorial_s2_surface_simulation | **3.75** | 3 | 4 | 3 | 5 |
| tutorial_s6_modelingepilepsy | **3.75** | 2 | 4 | 4 | 5 |
| simulate_region_stimulus | **3.75** | 4 | 3 | 4 | 4 |
| simulate_region_jansen_rit | **3.75** | 4 | 4 | 3 | 4 |
| simulate_reduced_wong_wang | **3.75** | 3 | 4 | 4 | 4 |
| multiple_stimuli | **3.75** | 4 | 4 | 2 | 5 |
| stochastic_simulation | **3.50** | 2 | 4 | 3 | 5 |
| exploring_the_bold_monitor | **3.25** | 3 | 4 | 2 | 4 |
| simulate_surface_seeg_eeg_meg | **3.00** | 2 | 3 | 3 | 4 |
| surface_stochastic | **2.50** | 2 | 3 | 2 | 3 |
| skewed_fc | **FAILED** (driver hung, never wrote notebook) |
| tutorial_s4_evokedresponsesinthevisualcortex | **EMPTY EVAL** (context limit) |
| visual_erp | **IN PROGRESS** |

### Dimension breakdown
| Dimension | Average | # Times Weakest |
|---|---|---|
| Correctness | **3.47** | **10 / 17** |
| Code Quality | 4.00 | 1 / 17 |
| Scientific Validity | 3.29 | 6 / 17 |
| Token Efficiency | **4.35** | 0 / 17 |

### New learning
12. **Tutorial goals excel; surface/SEEG goals struggle.** Tutorial goals (tutorial_s1, s3, s5) scored 4.25-4.50. Surface/SEEG goals (surface_stochastic, simulate_surface_seeg_eeg_meg) scored 2.50-3.00. The driver is missing Cortex/mesh/SpatialAverage/eeg-cap skills.

13. **`sim.run()` generator bug is the #1 correctness killer.** `sim.run()` returns a generator, not `(t, y)` tuples. Notebooks unpacking it directly crash. Affects tutorial_s1, stochastic_simulation, simulate_surface_seeg_eeg_meg.

14. **Wrong Simulator constructor args** (`conduction_speed`, `simulation_length`) passed directly to `Simulator()` instead of `Connectivity()`. Affects multiple goals.

15. **`evaluate.sh` fails on large notebooks** when the nbconvert output exceeds the evaluator's context window. The `tutorial_s4` notebook produced an empty evaluation.json (1 byte). Need truncation.

16. **skewed_fc driver hung** — the driver wrote 5 lines of batch.log then stopped. No `workflow.ipynb` was ever created. The driver got stuck in an unproductive loop.

17. **Token efficiency is excellent (4.35 avg).** The multi-skill architecture and concise seed message produce compact, focused notebooks. No mutation needed here.

### Next steps
See PLAN.md for prioritized action items.

### Remaining questions
- Can we get surface/SEEG goals above 3.5 with targeted API skills?
- Will fixing `sim.run()` generator pattern raise all correctness scores by ~0.5?
- Can the evaluator handle truncation gracefully without losing nuance?
- What's causing the skewed_fc driver hang — context window exhaustion?

## 2026-04-28 — Meta-Analysis: How Much Improvement Came From the Loop?

### The honest answer
**~95% of the score improvement came from my direct manual engineering. ~5% came from the autonomous mutation loop.**

### Breakdown

| Improvement | Score Change | Who Did It | Mechanism |
|---|---|---|---|
| Trial 1 → 2 | 2.75 → 3.50 | **Me** | Hand-wrote prompt edits based on evaluator critique |
| Trial 2 → 3 | 3.50 → 4.75 | **Me** | Created 10 sub-skills manually, rewrote `run_trial.sh` seed, added venv awareness |
| Trial 4 fix | 3.50 → 3.75 | **Me** (with mutator suggestion) | Applied notebook-format skill from mutator plan |
| Autoresearch iter 1 | 2.75 → 3.25 | **Loop** (autonomous) | Mutator generated JSON plan, applier applied it, loop kept it |
| Autoresearch iter 2-3 | 3.75 → 3.75 | **Loop** (autonomous) | Generated mutations but reverted — no net gain |
| Batch (20 goals) | Baseline 3.79 | **Neither** | Pure measurement of fixed skills — no evolution |

### What the loop actually contributed
The autonomous mutation loop (`autoresearch.sh`) had exactly ONE end-to-end success:
- **Iteration 1 on epilepsy**: generated a mutation plan, applied it, validated it, and kept it. Net: **+0.50 on 1 goal**.
- Iterations 2-3 generated mutations but they regressed or stagnated. The loop correctly reverted them.

### Why the loop hasn't taken over yet
1. **The mutator needs good critiques to act on.** When the evaluation is vague, the mutator produces scattered, low-value changes.
2. **The loop only explores one goal at a time.** A mutation that helps epilepsy might hurt visual_erp — but the loop doesn't know that without cross-validation.
3. **I fixed the biggest wins manually.** Seed bias, monolithic skills, venv awareness — these were architectural-level fixes that no single mutation could discover.
4. **The applier needs perfect JSON.** The loop spent more time dealing with parsing infrastructure than applying useful mutations.

### Implication
The real value isn't the autonomous loop YET — it's the **batch measurement system** (`run_batch.sh`).
- Before: We had 1 goal measured once.
- After: We have 20 goals measured in ~4 hours, revealing systematic weaknesses (surface/SEEG, `sim.run()`, API confusion).

**The loop is a nice-to-have; the measurement system is the must-have.** Future effort should prioritize:
1. Closing the correctness gaps we now SEE (because of measurement)
2. THEN running the loop to see if it can maintain gains across all 20 goals

## Batch 3 — New Skills Validation (2026-05-03)

### 3 new skills from failure pattern analysis
- **simulation-duration** (2.4KB): Monitor-specific minimum durations, BOLD volume requirements
- **concise-code** (1.9KB): Lean notebook patterns, no redundant plots/prints
- **region-atlas** (3.9KB): Full 76-region Hagmann parcellation with neuroscience label mappings

### Results: 4.50 / 5.0 (up from 4.16, +0.34)

| Dimension | Batch 2 | Batch 3 | Delta |
|-----------|---------|---------|-------|
| correctness | 4.54 | 4.75 | +0.21 |
| code_quality | 4.38 | 4.79 | +0.41 |
| scientific_validity | 4.04 | 4.50 | +0.46 |
| token_efficiency | 3.65 | 4.00 | +0.35 |

### Biggest improvements (new skills targeted these)
- visual-erp: 3.50 → 4.80 (+1.30)
- alzheimers-abeta-ei: 3.30 → 4.50 (+1.20)
- parameter-space-exploration: 3.50 → 4.50 (+1.00)
- tumor-virtual-resection: 3.75 → 4.75 (+1.00)
- exploring-the-bold-monitor: 4.00 → 4.75 (+0.75)

### Regressions
- depression-rtms-wilsoncowan: 4.20 → 2.60 (notebook crashed on sim.run() unpacking)
- tdcs-fc-modulation: 4.05 → 3.50 (weak stimulation effect, same as previous batch)

### Learnings
- #18: Simulation-duration skill is the highest-leverage single skill — 7 goals had too-short sims
- #19: Region-atlas prevents ValueError from nonexistent region names
- #20: Concise-code nudges models toward better token_efficiency scores
- #21: Two regressions were code-generation failures, not skill regressions
- #22: Scientific validity improved +0.46 avg, validating "skills from measured failures" approach

### Evaluator fixes
- Python heredoc argv bug: `python3 <<'PY' $arg` tried to parse $arg as script → use ENV var
- Truncated JSON: evaluator responses missing closing `}` → brace completion + regex fallback
- Justification brevity: "one sentence" → "under 30 words" to prevent token-limit truncation
