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

### Trial 3 results
- **Score**: 4.75 (correctness=5, code_quality=5, scientific_validity=5, token_efficiency=4)
- **Turns**: 2 (down from 4)
- **Key improvement**: Scientific validity jumped from 2→5 by addressing burn-in windowing, regime verification, and stimulus-locked analysis.

### Next steps
- Test generalization on other goals (resting-state, epilepsy).
- Consider whether token_efficiency can be improved (currently 4/5).
