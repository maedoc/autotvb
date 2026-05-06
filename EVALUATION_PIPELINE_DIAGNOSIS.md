# Ablation Evaluation Pipeline — Diagnosis & Fix Proposal

*Generated 2026-05-05 after systematic analysis of the v2 re-evaluation pipeline.*

---

## Summary

The published ablation scores in README.md are **not valid**. Two independent bugs conspire to make the data useless:

1. **Self-evaluation contamination** — small models grade their own notebooks.
2. **Frontier evaluator silence** — re-evaluation with a frontier model returns empty responses for most notebooks.

We do **not** have credible data on how small models (ministral-14b, rnj-8b) perform with or without skills. The whole ablation table needs to be re-run with a fixed pipeline.

---

## Bug 1: Self-Evaluation Contamination

### Where it lives

- `bin/run_trial.sh`, line ~233:

```bash
bash bin/evaluate.sh "$NOTEBOOK" "$GOAL" "$TRIAL_DIR/evaluation.json"
```

`evaluate.sh` inherits `PI_MODEL` from the parent shell. Since `run_ablation_batch.sh` sets `PI_MODEL=$model_id` for generation, the **same model evaluates its own output**.

### Evidence

```
# rnj-8b visual_erp first-round eval.log:
[EVAL] Using model: ollama/rnj-1:8b-cloud (via env var)
[MODEL] Using: ollama/rnj-1:8b-cloud
```

This appears for rnj-8b. ministral-14b also shows `ollama/kimi-k2.6:cloud` for some (Phase 3 gap-filled), but most are self-graded.

### Why it matters

A model that generates code tends to justify it when evaluating. Shared failure modes go undetected. This is why rnj-8b shows 4.11 mean "without skills" — a meaningless number.

---

## Bug 2: Phase 3 Skip-Existing Never Fires

### Where it lives

- `bin/run_ablation_batch.sh`, line ~211:

```bash
[ -f "$dir/evaluation.json" ] && [ -s "$dir/evaluation.json" ] && continue
```

Since every trial writes `evaluation.json` during generation (Bug 1), Phase 3 **always skips** the independent frontier evaluation.

### Impact

The design intent — "generate with any model, evaluate with frontier" — is structurally dead. No notebook ever gets frontier-evaluated in the batch pipeline.

---

## Bug 3: Frontier Evaluator Returns Empty Responses

### Where it lives

- `bin/evaluate.sh` lines 78–86: truncation at 15,000 chars
- The v2 evaluator prompt (`prompts/evaluator/role_v2.md`) is 4,285 chars
- Total context = prompt + notebook + goal metadata

### Evidence

| Notebook | Notebook size | Eval prompt size | Result |
|---|---|---|---|
| compare_connectivity_normalization | 9,525 | 11,612 total | ✅ score=5.0 |
| multiple_stimuli | 13,881 | 14,619 total | ❌ empty response → FALLBACK/0 |

Notebooks **under** 15K truncation limit still fail. Something kills kimi-k2.6 when total prompt exceeds ~13–14K chars. No error in stderr, no output in stdout — complete silence.

### Impact

The v2 re-evaluation (`reevaluate_v2.sh`) produced **30/32 FALLBACK/0** scores for small-model notebooks. Only 2 passed. This is not because the notebooks are bad — it's because the evaluator vanishes.

---

## The Core Question Is Unanswered

**How do small models perform without skills?**

| Data source | Valid? | Why |
|---|---|---|
| First-round README scores | ❌ | Self-evaluation |
| v2 scores (reported from first-round) | ❌ | Same as above |
| v2 re-evaluation with frontier | ❌ | Frontier evaluator returns empty |

We have **zero valid data points** for ministral-14b and rnj-8b.

---

## Proposed Fixes

### Fix A: Decouple generation from evaluation in `run_trial.sh`

```bash
# Remove or comment out lines 231–242 in run_trial.sh:
# if [ -f "$RESULT_NOTEBOOK" ]; then
#     bash bin/evaluate.sh ...
# fi
```

Generation should produce only the notebook. Evaluation is a separate pipeline step.

### Fix B: Force frontier evaluation in `run_ablation_batch.sh`

Phase 3 should **delete or rename existing `evaluation.json`** before running the independent evaluator:

```bash
# Before launching evaluate.sh:
mv "$dir/evaluation.json" "$dir/evaluation.json.self" 2>/dev/null || true
# Then always run frontier evaluator
```

Alternatively, remove Phase 3 entirely and make evaluation a mandatory separate step after all trials complete.

### Fix C: Fix the frontier evaluator silence

**Hypothesis**: kimi-k2.6:cloud silently fails on prompts between ~12K and 15K characters.

**Test plan**:

```bash
# 1. Re-run evaluate.sh with v1 prompt (shorter) on a failing notebook
EVAL_PROMPT=prompts/evaluator/role_v2.md bash bin/evaluate.sh \
    sandbox/ablation_v2_20260505_122823/ministral-14b/zero_shot/multiple_stimuli/workflow.ipynb \
    .../GOAL.md \
    .../evaluation_v1prompt.json

# 2. Strip all markdown cells from notebook before evaluation,
#    leaving only code cells. This may drop the notebook below
#    whatever threshold is killing the evaluator.

# 3. If (1) and (2) fail, test with a different frontier model
#    (e.g., ollama/gpt-oss:20b-cloud) to isolate whether this
#    is a kimi-k2.6-specific quirk.
```

### Fix D: Make truncation useful

Current code truncates notebooks **only after** `NB_LEN` exceeds 15,000. If the issue is total prompt size (notebook + role_v2.md + goal), truncation should be based on total prompt, not notebook alone:

```bash
# New logic:
PROMPT_SIZE=$(wc -c < "$EVAL_PROMPT")
GOAL_SIZE=$(wc -c < "$GOAL")
MAX_TOTAL=14000
MAX_NB_LEN=$((MAX_TOTAL - PROMPT_SIZE - GOAL_SIZE - 500))
# Then apply truncation
```

This ensures total prompt stays within whatever context limit is actually active.

---

## Recommended Next Steps

1. **Stop trusting the ablation table** in README.md. It is advertising false results.
2. **Apply Fix A and B immediately** so new trials never produce self-evaluations.
3. **Run Fix C test** on 3 notebooks (one <10K that passes, one ~13K that fails, one >15K that gets truncated) to find the actual context limit.
4. **Patch `evaluate.sh`** with the correct threshold and truncation formula.
5. **Re-run frontier evaluation on all v2 notebooks** using the fixed evaluator — this gives us actual small-model scores for the first time.
6. **Update README.md** only after step 5 completes. Do not publish self-graded numbers.

---

## Files Involved

| File | Lines | What to change |
|---|---|---|
| `bin/run_trial.sh` | 231–242 | Remove inline evaluation call |
| `bin/run_ablation_batch.sh` | 211–215 | Remove skip-existing guard; always evaluate with `EVAL_MODEL` |
| `bin/reevaluate_v2.sh` | 30–45 | Remove fallback/0 detection that skips valid-looking self-evaluations |
| `bin/evaluate.sh` | 78–86 | Fix truncation to account for total prompt size, not notebook alone |
| `prompts/evaluator/role_v2.md` | — | Keep or shorten depending on Fix C test results |

---

## Open Questions

- Why does kimi-k2.6:cloud return empty (not error) on ~14K-char prompts? Is this a cloud throttle, a context limit below reported max, or a bug in how `pi` streams the prompt?
- Does the notebook content matter, or is it purely character count? (E.g., does the presence of `# [... TRUNCATED ...]` in the text corrupt the prompt?)
- If we strip markdown cells and keep only code, can we stay under the threshold while keeping enough signal to evaluate?

---

*End of diagnosis document.*
