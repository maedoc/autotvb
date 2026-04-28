# Autoresearch Next Steps Plan

Generated after 20-goal baseline sweep (avg 3.78/5.00, 17/20 evaluated).

---

## P0 — Fix Critical Infrastructure

### 1. Fix `evaluate.sh` for large notebooks
**Problem:** Large notebooks with plots exceed evaluator context window → empty `evaluation.json` (1 byte).
**Seen on:** `tutorial_s4_evokedresponsesinthevisualcortex`.
**Fix:** Truncate nbconvert output to first ~300 lines + last 50 lines, or summarize with `wc -l`, number of cells, and key code patterns rather than full script.
**Expected impact:** Re-enable evaluation for large-plot goals (tutorial_s4, surface simulations).
**Effort:** 15 min.

### 2. Fix `skewed_fc` driver hang
**Problem:** Driver never wrote `workflow.ipynb` — hung after turn 1, 6 log lines.
**Hypothesis:** Driver got stuck proposing plans without writing files, or context window exhausted.
**Fix:** Add explicit "YOU MUST write the notebook file" guard to driver prompt. Or reduce seed message verbosity.
**Expected impact:** Completes another goal baseline.
**Effort:** 10 min.

---

## P1 — Highest-Impact Skill Mutations

### 3. Add `sim.run()` generator pattern to driver skills
**Problem:** Correctness killer — #1 weak dimension (10/17 goals). Notebooks unpack `sim.run()` as `(t, y)` tuples; it returns a generator.
**Affected goals:** tutorial_s1, stochastic_simulation, simulate_surface_seeg_eeg_meg.
**Fix:** Add explicit pattern to `skills-in-progress/driver/boilerplate/SKILL.md`:
```python
# CORRECT: sim.run() returns a generator
for (t, raw), in sim(simulation_length=1000):
    pass
# OR: use monitor for output
(t, raw), = next(sim(simulation_length=1000))
```
**Expected impact:** Correctness +0.5 on affected goals, raising avg to ~4.0.
**Effort:** Run mutator on a low-correctness result, or manually add pattern.

### 4. Add surface/SEEG-specific API skills
**Problem:** Surface/SEEG goals score 2.50-3.00 — worst category.
**Seen errors:** `Cortex.from_file()` with wrong args, shape-indexing bug in EEG post-processing, `SpatialAverage` vs global average confusion.
**Fix:** Create `skills-in-progress/driver/surface-mesh/SKILL.md` with:
- `Cortex.from_file()` usage patterns
- `monitors.EEG` / `monitors.iEEG` / `monitors.SEEG` distinctions
- `SpatialAverage` shape expectations
- eeg cap file paths (`eeg_65.txt`)

Also create `skills-in-progress/navigator/surface-review/SKILL.md` with surface-specific checklist.
**Expected impact:** surface_stochastic 2.50 → 3.50, simulate_surface_seeg_eeg_meg 3.00 → 3.75.
**Effort:** 30 min manual + mutation on surface results.

### 5. Add "Common TVB API Mistakes" skill
**Problem:** Recurring constructor arg errors.
**Seen errors:**
- `conduction_speed` passed to `Simulator()` instead of `Connectivity()`
- `simulation_length` passed to `Simulator()` instead of `sim(simulation_length=...)`
- `monitors.iEEG` instead of `monitors.SEEG`
**Fix:** Create `skills-in-progress/driver/api-patterns/SKILL.md` with "anti-patterns" section.
**Expected impact:** Correctness +0.25 on 5+ goals.
**Effort:** 15 min.

---

## P2 — Targeted Autoresearch

### 6. Run autoresearch on worst-performing goal
**Target:** `surface_stochastic` (score 2.50) or `exploring_the_bold_monitor` (3.25).
**Approach:**
1. Create branch, run trial
2. Run mutator with batch history + low score as critique
3. Apply mutations
4. Validate
5. Keep if score > 2.50

**Expected impact:** Learn whether mutations can close the surface gap.
**Effort:** 2-3 iterations (~45 min each).

### 7. Re-test `visual_erp` with new skills
**Status:** In progress in batch (has workflow.ipynb, awaiting eval).
**Expected:** Should score ≥ 4.00 with current skills (was 4.75 in trial 3).
If it scores lower, investigate what degraded.

---

## P3 — System Robustness

### 8. Fix duplicate `run_trial` process issue
**Problem:** The parent `run_trial.sh` spawns a child that also runs `run_trial.sh` with identical args.
**Hypothesis:** A `pi` agent running inside the trial executes a bash command that sources `run_trial.sh`, or a signal handler forks.
**Fix:** Add `PI_AGENT_CONTEXT=1` environment variable to prevent nested execution. Or check `$$` pid against parent.
**Expected impact:** Cleaner process trees, less confusion.
**Effort:** 10 min.

### 9. Add notebook-size guard to `evaluate.sh`
**Problem:** Context limits silently cause empty evaluations.
**Fix:** Before calling `pi`, check `wc -c` of nbconvert output. If > 8KB, truncate or replace with structural summary ("N cells, M lines, includes plots").
**Expected impact:** No more empty evals.
**Effort:** 15 min.

---

## P4 — Documentation

### 10. Update `ARCHITECTURE.md`
**Current:** Out of date — describes 2 monolithic skills, no mutation pipeline, no batch system.
**Fix:** Document the 10 sub-skills, JSON mutation pipeline, batch runner, autoresearch loop.
**Expected impact:** Onboarding clarity.
**Effort:** 20 min.

---

## Summary: Recommended Order

| Step | Action | Effort | Impact |
|---|---|---|---|
| 1 | Fix `evaluate.sh` truncation | 15 min | Enable 3 more goals |
| 2 | Fix skewed_fc hang | 10 min | +1 goal baseline |
| 3 | Add `sim.run()` pattern | 15 min | Correctness +0.5 avg |
| 4 | Add surface/SEEG skills | 30 min | Surface +1.0 avg |
| 5 | Add API anti-patterns skill | 15 min | Correctness +0.25 avg |
| 6 | Run autoresearch on surface | 90 min | Close worst gap |
| 7 | Fix duplicate processes | 10 min | Cleaner infra |
| 8 | Re-test visual_erp | ongoing | Validate skills transfer |
| 9 | Update ARCHITECTURE.md | 20 min | Docs |

**Total estimated time: ~3.5 hours focused work.**
Expected outcome: Average baseline score rises from **3.78 → 4.20+**.
