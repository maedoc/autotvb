# Meta-Workflow: Autoresearch → Navigator/Driver Agent Pair

## Goal
Use the `autoresearch` skill as an outer optimization loop to incrementally evolve
(a) role-specific agent prompts and (b) skills for a **navigator/driver** agent pair specialized
for whole-brain modeling with TVB.

## Concrete Target
Given a natural scientific question (e.g. "How do I model visual ERP in TVB?"),
the navigator translates it to a concrete work-plan and the driver implements it
as a working Python notebook. The pair communicate synchronously via a message-passing
loop until the navigator terminates.

## Repository Layout

```
autotvb/
├── ARCHITECTURE.md              # This file
├── bin/
│   ├── orchestrator.sh          # Autoresearch loop master script
│   ├── run_trial.sh           # Single navigator/driver trial
│   └── evaluate.sh            # Independent LLM evaluation
├── prompts/
│   ├── navigator/
│   │   └── role.md            # Mutable prompt for navigator agent
│   └── driver/
│       └── role.md            # Mutable prompt for driver agent
├── skills-in-progress/
│   ├── navigator/
│   │   └── SKILL.md           # Mutable skill for navigator
│   └── driver/
│       └── SKILL.md           # Mutable skill for driver
├── benchmarks/
│   ├── goals/                 # Concrete GOAL.md benchmarks (one per demo)
│   ├── trials/                # Output of each trial (branch-committed)
│   └── scores.jsonl           # Vector scores across all trials
├── sandbox/                   # Working dir for active trial
└── CHANGELOG.md               # Autoresearch session log
```

## Trial Protocol

1. **Pick a GOAL.md** from `benchmarks/goals/` (e.g. `visual_erp.GOAL.md`)
2. **Create a git branch** `trial-N`
3. **Run navigator→driver loop**: synchronously alternate messages until:
   - Navigator says `TERMINATE` with a verdict
   - Or max turns reached (default 20)
4. **Capture artifacts** into `sandbox/`: final notebook, logs, token counts
5. **Evaluate**: independent LLM scores the notebook on {correctness, code_quality, scientific_validity, token_efficiency}
6. **Record**: append vector score to `benchmarks/scores.jsonl`
7. **Decide** (autoresearch step): keep branch / merge prompt changes, or revert

## Fitness Function

Score vector (1–5 each):
- `correctness`: Does the notebook successfully import TVB, configure connectivity, run a simulation, and produce the requested output?
- `code_quality`: Is the code well-structured, documented, error-handled?
- `scientific_validity`: Are parameter choices, model selection, and analysis appropriate for the scientific question?
- `token_efficiency`: How many tokens were consumed to reach a working result? (Log-transformed and min-max scaled.)

Scalar fitness = mean of the 4 dimensions. The autoresearch loop maximizes this.

## Evolution Operators (what autoresearch mutates)

1. **Prompt mutations**: rephrase role descriptions, add/remove constraints, add exemplar workflows, tune verbosity
2. **Skill mutations**: add new SKILL.md sections, add `references/` files, add `scripts/`
3. **Cross-pollination**: if a mutation in the navigator prompt benefits a driver skill (or vice versa), allow it

## Git Discipline

- Each trial on its own branch named `trial-<N>`
- After evaluation, if fitness improved: `git merge --no-ff trial-<N>` into `main` with message `[trial-<N> score=S tokens=T]`
- If not improved: `git branch -D trial-<N>` (keep score in jsonl for analysis)

## Dependencies

- `pi` CLI with non-interactive mode (`pi -p "..." --mode text`)
- `jupyter nbconvert` for converting notebooks
- `nbconvert --execute` or `uv pip install nbconvert ipykernel` for headless evaluation
- TVB installed in the evaluation environment (or use tvb-root cloned repo)
