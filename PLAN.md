# Autotvb — Roadmap & Next Steps

Last updated: 2026-04-29, after DeepSeek v4 review.

## Current State

- 14 skills, 30 benchmark goals (20 tutorial + 10 paper-grounded)
- Tutorial baseline: ~3.79/5.0 (avg), best single: 5.0/5.0
- Paper-grounded goals: **unvalidated** — blocked by 2 critical infrastructure bugs (now identified)
- Per-turn latency: 5–8 min with filtered skills (~22KB payload)
- DeepSeek review found 2 critical bugs, 3 missing skill families, 1 API conflict

## Phase 1: Fix Critical Bugs (30 min)

Identified by DeepSeek v4 review. These block all unattended runs.

### P1-1: Fix heredoc literal in `run_trial.sh` (CRITICAL)
- **Bug**: `cat > "$NAVIGATOR_MSG" << 'NAVINIT'` — single quotes prevent `$(cat "$GOAL_FILE")` from expanding
- **Impact**: Navigator sees literal `$(cat "$GOAL_FILE")` instead of goal text on turn 1
- **Fix**: Change `<< 'NAVINIT'` to `<< NAVINIT`, escape any `$` that should remain literal

### P1-2: Fix tmux cwd in `overnight_batch.sh` (CRITICAL)
- **Bug**: `tmux new-session -d -s "$session" "timeout ... bash bin/run_trial.sh ..."` — tmux spawns in `$HOME`, not `$REPO_DIR`
- **Impact**: All batch runs fail with `No such file or directory`
- **Fix**: Add `cd '$REPO_DIR' &&` inside the tmux command string

### P1-3: Add `timeout 300` to all `pi` invocations in `run_trial.sh`
- **Bug**: Individual pi calls have no timeout — if one hangs, entire trial blocks
- **Fix**: Wrap each `pi` call with `timeout 300` (5 min per turn max)

### P1-4: Fix fallback score in `evaluate.sh`
- **Bug**: Fallback score=1.0 masks evaluation failures as "low quality but present"
- **Fix**: Change to `scalar_score: 0.0` so failures are distinguishable from genuine 1.0 scores

### P1-5: Fix `mutate.sh` missing script reference
- **Bug**: `python3 /tmp/extract_mutation.py` — file doesn't exist in repo
- **Fix**: Embed extraction logic inline or commit the script to `bin/`

### P1-6: Fix iEEG/SEEG conflict across 3 skills
- **Bug**: `tvb-api-mappings` says `iEEG`, `surface-forward` says `SEEG`, `common-models` says `iEEG`
- **Fix**: Verify against installed TVB version, unify all 3 skills

## Phase 2: First Paper-Goal Baseline (overnight)

After P1 fixes, run all 10 paper-grounded goals with a strong cloud model.

### P2-1: Run 10-goal overnight batch
- Model: `ollama/kimi-k2.6:cloud`
- Max turns: 5, timeout: 2h per trial
- Expected duration: 2–5 hours
- Output: `sandbox/batch_research_*/evaluation.json` per goal

### P2-2: Analyze baseline scores
- Which goals score ≥4.0? (indicates skills already sufficient)
- Which goals score <3.0? (indicates missing skills or API gaps)
- Which goals fail entirely? (indicates infrastructure issues)
- Target: identify the 3 weakest goals for targeted skill work

## Phase 3: Multi-Model Benchmarking

**Core thesis**: Skills that guide a small local model to produce valid TVB code are better skills than those that only work with frontier models. This is the real test of skill quality.

### Available model tiers

| Tier | Model | Size | Context | Speed | Notes |
|---|---|---|---|---|---|
| **Cloud strong** | `kimi-k2.6:cloud` | — | 128K | 5-8 min/turn | Current baseline |
| **Cloud budget** | `deepseek-v4-flash:cloud` | — | 128K | 3-5 min/turn | Faster, weaker reasoning |
| **Local large** | `qwen3.6:128k` | 23GB | 128K | ? | Largest local model |
| **Local mid** | `gemma4:26b` | 17GB | — | ? | Good general model |
| **Local small** | `gemma4:e4b` | 9.6GB | — | ? | **Key test**: can skills compensate? |
| **Local tiny** | `qwen3.5:9b` | 6.6GB | 128K | ? | Extreme skill quality test |

### P3-1: Cross-model single-goal benchmark
- Pick the easiest paper goal (likely `depression_gaba_tep` or `alzheimers_abeta_ei`)
- Run it with all 6 models above
- Same skills, same prompt, same evaluator
- Compare: correctness, scientific_validity, and whether notebook even executes
- **Question**: How much does model size matter vs skill quality?

### P3-2: Skill optimization for small models
- If a 4B model scores <2.0, analyze failure patterns
- Are skills too abstract? Need more concrete code templates?
- Do small models get lost in 22KB of skills? Test with even more aggressive filtering (10KB? 5KB?)
- Iterate: modify skills → re-benchmark with small model → measure delta

### P3-3: Skill-transferability matrix
- Build a matrix: model × goal × score
- Identify which skills transfer across model sizes and which don't
- Hypothesis: `boilerplate` (concrete code patterns) transfers well; `scientific-validity` (abstract reasoning) does not

### P3-4: Budget model batch
- Run full 10-goal batch with `deepseek-v4-flash:cloud` (cheapest cloud option)
- Compare scores against `kimi-k2.6:cloud` baseline
- If scores are within 0.5 points, use budget model for iteration and reserve strong model for final validation

## Phase 4: Fill Skill Gaps (targeted)

Based on Phase 2 baseline + Phase 3 model analysis, build missing skills.

### P4-1: `connectome-surgery` skill (~1KB)
- Zeroing connectivity rows/columns
- SC re-normalization after modification
- Verification of modified connectivity
- **Unblocks**: tumor_virtual_resection, stroke_sj3d_bold

### P4-2: `seizure-detection` skill (~1.5KB)
- LFP computation from source dynamics
- Amplitude thresholding for seizure onset
- Recruitment latency measurement
- **Unblocks**: vep_epileptor_permittivity, epilepsy_bayesian_fitting

### P4-3: `bold-validation` skill (~1KB)
- BOLD amplitude range check ([0.17, 87])
- Peak frequency verification (~0.05 Hz)
- Structure-function correlation
- **Unblocks**: stroke_sj3d_bold

### P4-4: Thicken `surface-forward`
- Add default surface data file paths
- Explain `Simulator(connectivity=conn)` vs `Simulator(surface=cortex)`
- Add shape-mismatch verification
- **Unblocks**: simulate_surface_seeg_eeg_meg, surface_stochastic

### P4-5: Fix skill conflicts
- Unify iEEG/SEEG across all 3 skills
- Verify parameter mappings against installed TVB version
- Add API existence checks where uncertain

## Phase 5: Autonomous Loop (when ready)

Not a priority until Phase 4 completes and baselines stabilize.

### P5-1: Re-enable autoresearch on weakest goal
- Pick the goal with lowest baseline after P4
- Run 10 iterations of mutate → evaluate → keep/revert
- Measure: does the loop improve scores beyond manual engineering?

### P5-2: Cross-model autoresearch
- Run autoresearch with a small local model
- Question: can the loop discover skill improvements that transfer to stronger models?

### P5-3: Skill distillation
- After P5-1/P5-2, distill learned patterns into permanent skill updates
- Remove noise, keep validated improvements
- Re-benchmark to confirm no regression

## Timeline Estimate

| Phase | Duration | Depends On |
|---|---|---|
| P1: Fix bugs | 30 min | Nothing |
| P2: First baseline | 2–5 hours (overnight) | P1 |
| P3: Multi-model benchmark | 1 day | P2 results |
| P4: Fill skill gaps | 2–3 days | P2 + P3 analysis |
| P5: Autonomous loop | 1–2 days | P4 stable baseline |

## Decision Points

- **After P2**: If all 10 goals score ≥3.5, skip P4 and go to P3 (model benchmarking is more interesting)
- **After P3**: If small models (<10B) can't score >2.0, investigate prompt compression (reduce skill payload to <10KB)
- **After P4**: If skill gap-filling doesn't improve weakest goals by ≥0.5, the issue may be in the driver prompt, not the skills
- **After P5**: If autonomous loop contributes >20% of improvement (vs current 5%), increase loop iterations; otherwise keep manual approach
