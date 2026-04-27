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

### Next steps
- Run trial 3 with multi-skill architecture.
- Evaluate whether splitting skills improved correctness or token efficiency.
