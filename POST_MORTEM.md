# Autotvb Post-Mortem & Forward Architecture

**Date:** 2026-05-21  
**Scope:** Full review of autotvb architecture, SmallCode harness lessons, and teacher-student path forward.

---

## 1. What Autotvb Built (The Good)

Autotvb validated a core thesis: **domain-specific skills, injected into a small model's context, measurably improve performance on technical tasks.** Across multiple model sizes, the "skill delta" is real and positive:

| Model | Skill Δ | Context |
|---|---|---|
| rnj-1:8b (local, slim skills 9.7KB) | **+0.36** | 9 goals, kimi-k2.6 evaluator |
| qwen3.6:128k (full skills 41KB) | **+0.88** | 9 abstract goals |
| ministral-3:14b (cloud) | **+0.31** | 9 goals, kimi-k2.6 evaluator |

Skills double the success rate for 8B models on abstract goals (33% → 67%). Without skills, the small model literally cannot attempt most non-trivial TVB tasks.

Other achievements:
- **18 skills** across driver (14) and navigator (4) roles, organized as focused 1–4KB markdown files
- **30 benchmark goals** (20 tutorial + 10 paper-grounded research)
- **Independent evaluator** (kimi-k2.6) with absolute scoring anchors — critical insight that self-evaluation inflates scores
- **Multi-model ablation framework** spanning 8B to 128K-context models
- **Abstract goals** (no TVB class hints) for fair zero-shot baseline
- **Presentation** and pipeline diagrams

---

## 2. What Autotvb Got Wrong (The Problems)

### 2.1 Evaluation Pipeline Contamination (Critical)

Three confirmed bugs, diagnosed May 5 but unfixed:

1. **Self-evaluation** — `run_trial.sh` calls `evaluate.sh` with the same `PI_MODEL` used for generation. Every model grades its own notebook. This invalidates all cross-model comparisons in the first ablation.

2. **Phase-3 skip guard** — `[ -f "$dir/evaluation.json" ] && continue` in `run_ablation_batch.sh` causes frontier re-evaluation to be skipped for every directory that already has a self-evaluation file.

3. **Frontier evaluator silence** — 6-way concurrent evaluation against a 1T INT4 model produces ~94% empty responses (KV-cache exhaustion, not prompt-size ceiling). Only 2 of 32 re-evaluations succeeded.

These bugs mean the published ablation table is **not trustworthy**. The skill-delta numbers above come from later experiments (`exp_ministral14b.sh`, `exp_rnj8b.sh`) that fixed the evaluation separation, but the overall ablation data needs re-running.

### 2.2 Architecture Drift

The project started as a mutation-loop architecture (`autoresearch.sh`, mutation JSON plans, evolution operators) and gradually pivoted to manual skill engineering + multi-model benchmarking. The codebase never caught up:

- `PLAN.md` describes a Phase 1–5 roadmap where **Phase 1 (30-minute bug fixes) was never completed**
- The mutation machinery (`mutate.sh`, `apply_mutation.sh`, `autoresearch.sh`, `orchestrator.sh`) is still in `bin/` but was superseded by manual engineering
- The plan calls for an autonomous loop in Phase 5 — but then admits the loop contributed only ~5% of total improvement
- The README claims 10 paper-grounded goals were evaluated "avg ~4.17 → 4.46 with skills" but the actual evaluation pipeline was broken

### 2.3 Organizational Decay

- **~20 one-off Python scripts** in `sandbox/` (`fix_nb.py`, `fix_nb2.py`, `fix_notebook.py`, `fix_title.py`, `gen_notebook_final.py` through `v4`, `patch_nb.py`, `debug_shapes.py`, `test_shapes.py`...)
- **~10 overlapping experiment scripts** in `bin/` (`run_ablation_batch.sh`, `run_ablation_v2.sh`, `run_ablation_remaining.sh`, `exp_rnj8b.sh`, `exp_gemma26b.sh`, `exp_gemma26b_128k.sh`, `exp_ministral14b.sh`, `run_local_experiment.sh`)
- **~30 sandbox batch directories** with stale intermediate outputs
- **Untracked diagnostic files** that should be committed or deleted
- **`mouse_connectivity/`** — 3.6MB of Allen Institute data, unrelated to the git-tracked project
- **Duplicate files** (`DRIVER_MESSAGE.md` at root and in sandbox, `NAVIGATOR_MESSAGE.md` in skills dir)
- **Stale `.ralph/` task file** tracking a half-done rnj-8b experiment

### 2.4 Missing Harness Infrastructure (What SmallCode Has That Autotvb Doesn't)

Autotvb's harness (`run_trial.sh`) is a bash script that invokes `pi` in a loop. It has **none** of the protections that make small models viable:

| SmallCode Feature | Autotvb Equivalent | Gap |
|---|---|---|
| Context budget engine (never exceed 70% of context) | Manual slim skills hack (9.7KB) | **No budget enforcement** — skills can silently overflow context |
| Early-stop detection (repetition, spirals, greeting regression) | None | Driver hangs, writes prose instead of notebooks — **no detection** |
| Forgiving tool-call parser (JSON/YAML/XML/Hermes/plain text) | Relies on `pi` tool parsing | If we build our own harness for the small model, **this is essential** |
| 2-stage tool routing (category → specific tools) | None | Full tool schemas in every prompt — **wastes context** |
| Improvement loop (retry → decompose → escalate) | None | Failure = restart trial — **no auto-feedback** |
| Trust score decay (drop broken tools from schema) | None | Model loops on broken calls — **no detection** |
| Tool-call deduplication | None | Identical reads re-executed — **wastes context** |
| Snapshot & auto-rollback | None | Malformed notebook = corrupted trial — **no recovery** |
| Adaptive retry temperature | None | Same prompt → same failure — **no exploration** |
| Bootstrap detection (workspace scan on first turn) | None | Model discovers TVB environment from scratch each trial |
| Evidence store (learn from past sessions) | Evaluation.json exists but **never fed back** | Scores are collected but ignored in subsequent trials |
| TODO-driven planning with externalized state | Navigator/driver loop (state in conversation) | If conversation gets compacted, **state is lost** |
| Read-before-write guard | None | Model writes to files it hasn't read — **hallucination risk** |

---

## 3. SmallCode Harness Lessons for Autotvb

SmallCode achieves **87% single-file success with a 4B-active-parameter model** — outperforming tools running 3–4x larger models. The lessons are directly applicable to autotvb's teacher-student architecture.

### Lesson 1: The Harness IS the Product

SmallCode's competitive advantage is not better prompts — it's **harness engineering**. The improvement loop (retry → decompose → escalate), token budgeting, forgiving parsing, early-stop detection, trust decay, and deduplication collectively compensate for the small model's weaknesses. The model doesn't need to be perfect on the first try because the harness catches, repairs, and retries.

**For autotvb:** The harness itself must evolve alongside the skills. If skills tell the small model *what* to do, the harness ensures the small model *can* do it without derailing. The harness is the safety net that makes skill quality measurable — without it, skill quality is confounded with model fragility.

### Lesson 2: Context Budget Is a First-Class Concern

SmallCode caps tool results at 4K chars, does mid-turn eviction, summarizes history instead of dropping it, and never exceeds 70% of the model's context window. Autotvb's current approach — "stuff skills into the prompt and hope" — works for frontier models but is the single biggest failure mode for small models.

**For autotvb:** The skill compressor must be a first-class component, not a grep-based keyword filter. A frontier model should analyze the full skill set, the target context budget, and the goal, then produce an **optimal compressed skill payload**. This compressed payload should be validated against a test set of edge cases before deployment.

### Lesson 3: Externalize State, Don't Trust the Model's Memory

SmallCode's TODO-driven planning writes the plan to a file and re-injects it every turn. The model reads the TODO to know where it is. This compensates for limited reasoning depth and context eviction. Autotvb's navigator/driver loop keeps all state in the conversation — if the conversation gets compacted or the model forgets mid-task, the state is lost.

**For autotvb:** The trial harness should maintain an external state file (current step, what's been tried, what worked, what failed) and inject a summary each turn. This is especially important for the small model in the teacher-student setup — the frontier model can maintain context internally, but the student cannot.

### Lesson 4: Detect and Recover From Degenerate Behavior

SmallCode detects repetition loops, patch spirals (stuck on corrupted file → forces rewrite), and greeting regression (model lost context → re-injects task). Autotvb has observed all three failure modes:

- **Repetition loops**: Driver writes the same broken `sim.run()` call repeatedly
- **Patch spirals**: Multiple `fix_nb.py` scripts attest to corrupted notebook JSON
- **Greeting regression**: Cloud models (gemma4:31b, ministral-14b) wrote "I'll help you create..." prose instead of notebook JSON

**For autotvb:** The harness should detect these patterns and inject corrective signals. "You wrote prose instead of a notebook. Use the write tool to create a .ipynb file." is a fixable failure if caught early — it only becomes a wasted trial if the loop continues unmonitored.

### Lesson 5: The "Compile Once" Pattern Reduces Tool Calls

SmallCode's BoneScript integration reduces 8–15 tool calls (write server.js, routes/, models/, auth.js, migrations/, schemas.ts, package.json...) to 1–2 (write .bone file + compile). Small models degrade with each sequential tool call — fewer calls = higher reliability.

**For autotvb:** Can we define TVB "templates" or "macros" that the small model can invoke in a single call? For example, a `tvb_boilerplate` tool that takes model name, connectivity, duration and produces a complete notebook skeleton — reducing 10 write/edit calls to 1. The frontier model defines the template once; the small model invokes it.

### Lesson 6: Learn From Past Failures (Evidence Store)

SmallCode's evidence store captures "what was tried, what worked, what failed" per task and surfaces it in future sessions. Autotvb collects `evaluation.json` scores but **never feeds them back** to the generation model. The model starts each trial from scratch with no knowledge of prior failures.

**For autotvb:** The teacher-student loop should maintain a failure database. Before each trial, inject: "In the last 3 attempts at this goal, the model made these specific mistakes: (1) used `sim.run()` as a generator, (2) forgot to call `configure()`, (3) used `tau0` instead of `tau`." This turns accumulated measurement into actionable context.

### Lesson 7: Adaptive Retry Avoids Repeated Failures

SmallCode varies temperature across retries: attempt 1 lowers (deterministic fix), attempt 2 raises (explore alternatives), attempt 3 returns to base. Without this, the same prompt produces the same broken output.

**For autotvb:** When the small model fails, retry with varied temperature. This is trivial to implement and disproportionately effective for models that get stuck in local minima.

### Lesson 8: Validate Before Proceeding

SmallCode runs lint/compile after every write and feeds errors back. Autotvb validates only at the end (execution of the full notebook). By the time execution fails, the model context is stale and the failure is hard to diagnose.

**For autotvb:** After each notebook cell write, do a quick JSON validation (is the cell valid JSON? Does the code parse?). Catch `\n` literals in JSON strings immediately, not after 5 turns of accumulated damage.

---

## 4. Teacher-Student Architecture

### 4.1 Core Thesis

**Use a frontier model as the teacher — it engineers skills, improves the harness, and produces golden traces. Use those artifacts to maximize the small model's (student's) performance through two channels: skills in context (inference-time) and fine-tuning on collected traces (training-time).**

The frontier model plays four roles:
1. **Engineer** — writes skills, compresses them for context budgets, **modifies harness code**, **creates/removes/modifies tool definitions**
2. **Executor** — produces golden traces (correct, validated notebook-generation tool-call sequences)
3. **Evaluator** — judges small-model outputs with absolute scoring anchors
4. **Architect** — when it sees a failure pattern, it can change ANY part of the system: skills, prompts, tools, harness rules, or the student's environment

The small model is improved through two channels:
1. **Skills in context** — compressed, validated domain knowledge injected at inference time
2. **Fine-tuning** — SFT on golden traces to improve tool-call hygiene, API correctness, and format adherence

The harness and tool definitions are NOT static — they are **living artifacts** that the teacher continuously improves in response to measured failures. A failure that can be fixed by a harness rule should be fixed by a harness rule, not by a longer skill.

### 4.2 Why Two Channels Are Necessary

The current autotvb data shows that skills alone hit a ceiling:
- rnj-1:8b + slim skills → best score ~4.5, several goals still fail
- qwen3.6:128k + full skills → mean only 1.58/5 on abstract goals

The missing piece is that small models are fundamentally weaker at **following multi-turn tool-use instructions**, regardless of skill quality. They produce garbled JSON, forget the goal mid-session, write prose instead of notebooks. Skills are knowledge; fine-tuning is behavior. Both are needed.

### 4.3 Architecture Diagram

```
┌──────────────────────────────────────────────────────────────────┐
│               TEACHER WRITES EVERYTHING (Frontier Model)          │
│                                                                   │
│  When the teacher sees a failure pattern, it can modify:          │
│                                                                   │
│  1. SKILLS                                                        │
│     Add/remove/rewrite skill content                              │
│     Compress skills for target context budget                     │
│                                                                   │
│  2. HARNESS                                                       │
│     Add early-stop detection rules (repetition, prose, spirals)   │
│     Add validation gates (JSON parse, syntax check)               │
│     Modify retry logic (temperature schedule, max attempts)       │
│     Add context budget tracking + eviction rules                  │
│                                                                   │
│  3. TOOLS                                                         │
│     Create new tools (tvb_simulate macro, tvb_validate)          │
│     Modify existing tool schemas (add params, fix descriptions)   │
│     Remove tools that confuse the student (trust decay)           │
│     Add tool macros: one student call → harness expands to N correct calls│
│                                                                   │
│  4. PROMPTS                                                       │
│     Rewrite system prompts for clarity/precision                  │
│     Inject failure-context (evidence from past trials)             │
│     Adjust verbosity, examples, constraints                       │
│                                                                   │
│  EVERY change goes through:                                       │
│    generate → validate gate → regression test → deploy            │
│  If validation fails, teacher gets failure context and retries.   │
│  If regression test fails, change is reverted automatically.      │
└──────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│                    STUDENT EXECUTES (Small Model)                 │
│                                                                   │
│  Student + skills + harness + tools ──► notebook                  │
│  Harness validates each step (JSON check, syntax parse)           │
│  Harness detects degenerate behavior (loops, spirals, prose)      │
│  Harness retries with adaptive temperature on failure             │
│  Teacher evaluates final notebook (blind, absolute anchors)       │
│                                                                   │
│  Failure patterns → feed back to TEACHER WRITES EVERYTHING        │
└──────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│                    GOLDEN TRACE COLLECTION                        │
│                                                                   │
│  Teacher executes goals with current skills+harness+tools         │
│  Notebook executes correctly + score ≥ 4.0 → save trace           │
│  Traces converted to SFT dataset for student fine-tuning          │
│  LoRA fine-tuning: improves tool-call behavior, not just knowledge│
│                                                                   │
│  Fine-tuned student → re-enter evaluation loop → measure delta    │
└──────────────────────────────────────────────────────────────────┘
```

This architecture makes a critical distinction: **the teacher has write access to the entire system, not just the skills.** A failure mode like "student writes prose instead of notebooks" is a harness fix (add a validation gate), not a skill fix. A failure like "student makes 10 tool calls to set up a simulation" is a tool fix (create a `tvb_region_sim` macro tool). The teacher diagnoses the failure and picks the right level to intervene.

### 4.4 Phase 1: Fix and Harden the Harness (Week 1)

Before any teacher-student work, the evaluation pipeline must be fixed and the harness must be hardened. This is the foundation — all subsequent results depend on it.

#### 4.4.1 Fix Evaluation Bugs (P0)

| Task | Detail |
|---|---|
| Separate generate/evaluate | `run_trial.sh` produces notebook only; separate `evaluate_trial.sh` |
| Fix `EVAL_MODEL` propagation | Evaluator never inherits `PI_MODEL` from generation |
| Remove Phase-3 skip guard | Or split into generation-only + evaluation-only passes |
| Max eval concurrency = 1 | For >100B models, sequential only |
| Retry empty responses | 3× retry with 10s backoff before writing fallback |
| Add metadata to evaluation.json | `evaluator_model`, `generation_model`, `notebook_size_bytes`, `retry_count`, `prompt_hash` |

#### 4.4.2 Add Harness Protections (SmallCode Lessons)

| Feature | Implementation |
|---|---|
| **Early-stop detection** | Detect: repetition loops (same 200-char tail 3×), prose-instead-of-notebook (no `write` tool calls in first 3 turns), greeting regression (mid-task greeting patterns). Inject corrective signal and continue. |
| **JSON validation gate** | After each notebook write, parse as JSON. If `\n` literals detected, inject fix instruction. If invalid JSON, mark cell for rewrite. |
| **Adaptive retry** | On tool-call failure, retry with temperature: 0.3 → 0.7 → base. After 3 failures, inject explicit error context. |
| **External state file** | Maintain `STATE.md` in trial dir: current step, completed cells, known errors, what to try next. Inject summary each turn. |
| **Context budget tracker** | Count tokens per turn. If total context > 70% of model limit, trim oldest tool results first, then summarize conversation. Never let skills silently overflow. |
| **Tool macros** | Define `tvb_simulate(model, connectivity, duration)` macro that the harness expands to the correct 5–10 tool calls. One call from the model, reliable execution by the harness. |
| **Evidence injection** | Before each trial, inject: "Past failures on this goal: [list of 3 most common mistakes from evidence store]." |
| **Read-before-write guard** | Track which files the model has read. Warn if writing to unread existing file. Allow on second attempt. |

### 4.5 Phase 2: Skill Compression (Week 1–2)

Replace the current keyword-filter approach (`filter_skills.sh`) with a teacher-model-driven compression pipeline.

#### 4.5.1 Compression Protocol

```
Input:  Full skill set (41KB, 18 skills)
        Target context budget (e.g., 8KB for 32K-context models)
        Goal description
        Model profile (capabilities, known failure patterns)

Process: Teacher model analyzes:
        1. Which skills are essential for THIS goal?
        2. Which skill sections can be condensed (patterns → templates)?
        3. Which examples are most relevant?
        4. What edge cases does the compressed version risk missing?

Output: Compressed skill payload within budget
        Test set of edge cases that MUST pass with compressed skills
        Justification of what was removed and why
```

#### 4.5.2 Validation Gate

Before deploying compressed skills:
1. Run the teacher model on the goal with compressed skills — must score ≥ 4.0
2. Run the edge-case test set — must not regress
3. If validation fails, teacher re-compresses with failure context

#### 4.5.3 Per-Model Skill Variants

Different models need different skill formats:
- **8B models (32K context):** Concrete code templates, explicit import lists, no abstract reasoning
- **14B models (128K context):** Mix of templates and rules, some abstract patterns
- **20B+ models:** More abstract rules, fewer concrete templates (they can infer)

The compressor should produce model-specific variants, stored as `skills/{goal}/{model_size}.md`.

### 4.6 Phase 3: Golden Trace Collection (Week 2)

The teacher model (kimi-k2.6 or equivalent) generates validated tool-call traces.

#### 4.6.1 Golden Trace Criteria

A trace is "golden" if:
1. The notebook executes without errors (`nbconvert --execute --allow-errors` returns clean)
2. The independent evaluator score ≥ 4.0
3. All tool calls are valid (no `\n` literals, no garbled JSON)
4. The trace is complete (navigator terminated naturally, not by timeout)

#### 4.6.2 Trace Format

Each golden trace is a JSONL file with one object per turn:

```json
{
  "turn": 1,
  "role": "navigator",
  "model": "ollama/kimi-k2.6:cloud",
  "prompt_tokens": 3240,
  "completion_tokens": 512,
  "content": "Create a plan: 1. Import TVB...",
  "tool_calls": null
}
{
  "turn": 2,
  "role": "driver",
  "model": "ollama/kimi-k2.6:cloud",
  "prompt_tokens": 4521,
  "completion_tokens": 2048,
  "content": "I'll write the import cell first.",
  "tool_calls": [
    {"name": "write", "args": {"path": "workflow.ipynb", "content": "..."}}
  ]
}
```

#### 4.6.3 Target Collection

| Goal Type | Target Traces | Rationale |
|---|---|---|
| Region simulation | 2 traces | Most common TVB pattern |
| Surface simulation | 2 traces | Requires surface-specific API knowledge |
| BOLD monitoring | 2 traces | Most common failure mode (hemodynamic params) |
| Stimulus/ERP | 2 traces | Stimulus pattern configuration |
| Parameter sweep | 2 traces | Multi-variable exploration |
| Epilepsy | 1 trace | Complex, state-variable-heavy |

Target: **10–12 golden traces** covering the API surface diversity.

### 4.7 Phase 4: Fine-Tuning (Week 2–3)

#### 4.7.1 Dataset Construction

Convert golden traces to chat-format training examples:

```
System: [Compressed skills + role prompt]
User: [Goal description]
Assistant: [Navigator plan]
...
Tool: [Write tool executed: notebook cell created]
Assistant: [Driver response: cell written, what next]
```

Each trace produces 4–6 training examples (one per turn). With 10–12 traces, that's 50–70 examples. Augment with:
- **Error recovery variants**: Inject common failure patterns into traces, show correct recovery
- **Format variations**: Same goal with different phrasings

#### 4.7.2 Fine-Tuning Strategy

| Parameter | Choice | Rationale |
|---|---|---|
| Method | LoRA (rank 8–16) | Preserves base model capabilities, small trainable footprint |
| Base model | rnj-1:8b or qwen3.5:9b | Models already benchmarked in autotvb |
| LR | 2e-4 | Standard for LoRA instruction tuning |
| Epochs | 3–5 | Small dataset, risk of overfitting beyond 5 |
| Validation | Hold out 2 traces | Check for overfitting |
| Target modules | All linear layers | Tool-call format involves attention patterns |

#### 4.7.3 What Fine-Tuning Should Improve

The SFT dataset specifically targets:
1. **Tool-call format**: Valid JSON, correct parameter names, no `\n` literals
2. **Notebook cell flow**: Imports → connectivity → model config → sim.run() → analysis, in order
3. **API correctness**: `sim.run()` returns list-of-tuples not tuple-of-arrays, `configure()` before `run()`
4. **Error recovery**: On JSON validation failure, read current file and rewrite, don't keep patching
5. **Completion signals**: Signal when notebook is done (navigator TERMINATE), don't drift into prose

### 4.8 Phase 5: Continuous Improvement Loop (Ongoing)

```
┌─────────────────────────────────────────┐
│              MEASURE                     │
│  Student + current system → notebook     │
│  System = skills + harness + tools + prompts│
│  Frontier evaluator → per-dimension score │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│              ANALYZE                     │
│  Which goals regressed? Why?             │
│  Classify each failure:                  │
│    skill gap? harness gap? tool gap?     │
│    prompt gap? model capability floor?   │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│        TEACHER INTERVENES                │
│  Picks the right level for each failure: │
│                                          │
│  Skill gap → rewrite/compress skill      │
│  Harness gap → add detection/recovery    │
│  Tool gap → create/modify/remove tool    │
│  Prompt gap → rewrite system prompt      │
│  Capability floor → accept, document     │
│                                          │
│  ALL changes → validation gate →         │
│    regression test → deploy or revert    │
└──────────────┬──────────────────────────┘
               │
               ▼
         (back to MEASURE)
```

Key discipline: **the teacher diagnoses the failure class before choosing an intervention.** The same symptom ("notebook didn't execute") could be a skill gap (missing import), a harness gap (no JSON validation, malformed cells not caught), a tool gap (no macro for the multi-step pattern), or a capability floor (model can't maintain state across 5+ turns). Each demands a different fix.

**Gating rule:** modify one thing at a time per iteration. Measure the delta. If it regresses, revert and re-analyze. The bottleneck is not iteration speed — it's **signal quality** from each measurement.

### 4.9 Tool Macros: The Teacher's Highest-Leverage Intervention

SmallCode's BoneScript pattern (one `.bone` file → entire backend) proves that **reducing tool-call count is the single most effective intervention for small models.** Each additional tool call is a failure point — the model can produce garbled JSON, lose context, or drift from the goal.

For autotvb, the teacher should define **tool macros** — compound tools that the harness expands into correct sequences of primitive calls. One call from the student, N correct primitive calls by the harness.

#### Example: `tvb_region_sim` macro

**Student calls:**
```json
{"name": "tvb_region_sim", "args": {
  "model": "Generic2dOscillator",
  "connectivity": "default_76",
  "duration": "2000ms",
  "noise_nsig": 0.01
}}
```

**Harness expands to:**
1. `write` import cell (with verified import paths for current TVB version)
2. `write` connectivity cell (load default 76-region connectome, configure conduction speed)
3. `write` model cell (instantiate `models.Generic2dOscillator`, set parameters)
4. `write` simulator cell (`sim.configure()`, `sim.run()`, correct list-of-tuples unpacking)
5. `write` analysis cell (basic PSD plot, timeseries plot)
6. `bash` nbconvert --execute to validate

All 6 steps are generated deterministically by the harness from the macro call. The student never touches individual cells — it just says "I need a region simulation with these parameters."

#### When the teacher creates a macro

1. **Teacher identifies a recurring multi-step pattern** in golden traces or a common failure mode in student traces
2. **Teacher defines the macro**: name, parameters, expansion logic
3. **Teacher writes the expansion code** (bash/Python that generates correct cells)
4. **Teacher runs regression**: known-good goals using the macro must score ≥ same as manual generation
5. **Teacher deploys**: macro is added to student's tool schema

#### Macro library (initial candidates)

| Macro | Expands To | Saves |
|---|---|---|
| `tvb_region_sim` | imports + connectivity + model + sim.run + analysis | 5→6 tool calls |
| `tvb_surface_sim` | region sim + surface + local connectome + SEEG/EEG/MEG monitors | 8→10 tool calls |
| `tvb_bold_monitor` | region sim + BOLD monitor + hemodynamic params + BOLD analysis | 6→8 tool calls |
| `tvb_stimulus` | region sim + StimulusRegion + temporal pattern + ERP analysis | 7→9 tool calls |
| `tvb_param_sweep` | region sim + parameter ranges + grid search + comparison plot | 8→12 tool calls |

This is the teacher's highest-leverage intervention because it **fundamentally changes what the student has to do.** Instead of "follow these 10 instructions to set up a simulation" (which the student will fail at some step), it becomes "say what you want and the harness handles the details." The frontier model defines the macros once; the student invokes them reliably forever.

### 4.10 Example: End-to-End Teacher Intervention

To make this concrete, here's how the teacher would handle a real failure observed in autotvb:

**Observed failure:** ministral-14b writes prose markdown instead of a `.ipynb` JSON notebook (observed in cloud model drilldown, README).

**Teacher diagnoses:**
1. Root cause: The model doesn't know it must produce a notebook via the `write` tool. The system prompt says so, but the model ignores it when confused.
2. Classification: This is a **harness failure**, not a skill failure. Adding more skill text about notebook format won't help — the model already has that skill and ignored it.

**Teacher interventions (in priority order):**

1. **Harness: Add prose detection** — After turn 1, check if `write` tool was called. If not, inject corrective signal: "You must use the write tool to create a .ipynb notebook. Do not output prose." Retry the turn.

2. **Tool: Modify write tool description** — Add to the `write` tool schema: "This is the ONLY way to create output. You MUST use this tool. Do not output markdown or prose text as your response — use write_file."

3. **Prompt: Rephrase priority** — Move the notebook requirement from paragraph 3 to sentence 1 of the system prompt: "YOUR ONLY TASK is to create a valid .ipynb notebook using the write tool. Nothing else is acceptable."

4. **Skill: Add negative example** — To the notebook-format skill, add: "WRONG (common failure): writing markdown prose about TVB. CORRECT: calling the write tool with valid JSON notebook cells."

**Validation gate:**
1. Run the same goal with the student → must produce a valid notebook (JSON parseable)
2. Run 3 other goals → must not regress
3. Run the teacher on the same goal → must not regress
4. If any gate fails, revert the highest-risk change and re-test

**Result:** After these interventions, the failure rate for prose-instead-of-notebook should drop from ~30% (observed in autotvb) to <5%. The teacher doesn't just diagnose — it surgically modifies the system at the right level.

---

## 5. Repository Reorganization Plan

Before any new work, the repo needs to be pruned to a clean baseline.

### 5.1 Delete

| Path | Reason |
|---|---|
| `sandbox/batch_all_*` (10+ dirs) | Stale batch outputs, contaminated data |
| `sandbox/ablation_*` (3 dirs) | Contaminated ablation data |
| `sandbox/gemma26b*` (4 dirs) | Intermediate experiment outputs |
| `sandbox/qwen36_*`, `sandbox/rnj8b_*` | Intermediate experiment outputs |
| `sandbox/gen_*`, `sandbox/local_exp_*` | Intermediate experiment outputs |
| `sandbox/missing_goals/`, `sandbox/cloud_ablation/` | Intermediate data |
| `sandbox/autoresearch/` | Superseded by manual approach |
| `sandbox/*.py` (~20 files) | One-off fix/generate scripts |
| `sandbox/smoke_test`, `test_*` dirs | Ad-hoc test dirs |
| `bin/orchestrator.sh` | Mutation loop orchestrator, superseded |
| `bin/mutate.sh`, `bin/apply_mutation.sh` | Mutation pipeline, superseded |
| `bin/autoresearch.sh` | Mutation loop, superseded |
| `bin/run_ablation_batch.sh`, `run_ablation_v2.sh`, `run_ablation_remaining.sh` | Overlapping ablation scripts |
| `bin/reevaluate_all.sh`, `bin/reevaluate_v2.sh` | Pipeline-fix scripts, superseded |
| `bin/poll_batch.sh`, `bin/watch_batch.sh` | Docker batch monitors, not needed after reorganization |
| `bin/overnight_batch.sh`, `bin/overnight_batch_docker.sh` | Superseded by parametrized experiment runner |
| `bin/run_batch.sh` | Superseded |
| `mouse_connectivity/` | Unrelated to this project |
| `ministral14b_20260507_173314/` | Stale experiment output (move to sandbox or delete) |
| `test_nb/`, `TEST_OUTPUT/` | Empty/stale test dirs |
| `sandbox/DRIVER_MESSAGE.md`, `skills-in-progress/driver/DRIVER_MESSAGE.md`, `skills-in-progress/driver/NAVIGATOR_MESSAGE.md` | Duplicate/stale message files |
| `.ralph/` | Stale task file |

### 5.2 Keep and Consolidate

| Current | New | Purpose |
|---|---|---|
| `exp_rnj8b.sh`, `exp_gemma26b.sh`, `exp_ministral14b.sh`, `exp_gemma26b_128k.sh`, `run_local_experiment.sh` | **`bin/run_experiment.sh`** | Single parametrized experiment runner: model, goals, conditions, evaluator |
| `run_trial.sh` | **`bin/generate.sh`** | Generate notebook only (no evaluation) |
| `evaluate.sh` | **`bin/evaluate.sh`** | Evaluate notebook only (fixed frontiers) |
| `filter_skills.sh` | **`bin/compress_skills.sh`** | Teacher-driven skill compression |
| — | **`bin/collect_trace.sh`** | Golden trace collector (new) |
| — | **`bin/fine_tune.sh`** | LoRA fine-tuning pipeline (new) |
| — | **`bin/harness/`** | Harness protection modules (new) |
| `generate_goals.py` | **`bin/generate_goals.py`** | Keep — useful |
| `extract_mutation.py` | Delete | Mutation pipeline, superseded |

### 5.3 New Directory Structure

```
autotvb/
├── bin/
│   ├── generate.sh              # Generate notebook (teacher or student)
│   ├── evaluate.sh              # Evaluate with frontier model
│   ├── run_experiment.sh        # Parametrized batch runner
│   ├── compress_skills.sh       # Teacher-driven skill compression
│   ├── collect_trace.sh         # Golden trace collector
│   ├── fine_tune.sh             # LoRA fine-tuning pipeline
│   └── harness/                 # Harness protection modules
│       ├── early_stop.sh        # Degenerate behavior detection
│       ├── context_budget.sh    # Token counting + eviction
│       ├── validate_json.sh     # JSON validation gate
│       └── evidence.sh          # Failure pattern injection
├── skills/                      # Renamed from skills-in-progress
│   ├── driver/
│   │   ├── boilerplate/
│   │   ├── stimulus/
│   │   ├── ... (14 skills)
│   │   └── compressed/          # Per-model compressed variants
│   │       ├── 8b_32k/
│   │       └── 14b_128k/
│   └── navigator/
│       ├── planning/
│       ├── code-review/
│       ├── scientific-validity/
│       └── common-models/
├── prompts/
│   ├── driver/
│   └── evaluator/
├── benchmarks/
│   ├── goals/                   # Tutorial goals
│   ├── goals_research/          # Paper-grounded goals
│   └── goals_abstract/          # No-TVb-hints goals
├── traces/                      # Golden traces (new)
│   ├── region_sim_001.jsonl
│   ├── surface_sim_001.jsonl
│   └── ...
├── results/                     # Experiment outputs (new, gitignored)
│   └── exp_2026-05-21_rnj8b/
├── ARCHITECTURE.md
├── PLAN.md                      # Updated with teacher-student roadmap
├── README.md
├── CHANGELOG.md
└── POST_MORTEM.md               # This file
```

---

## 6. Risk Register

| Risk | Severity | Mitigation |
|---|---|---|
| **Fine-tuning causes catastrophic forgetting** | Medium | Use LoRA (frozen base weights). Validate on general benchmarks before/after. Reversible — just remove adapter. |
| **Teacher model produces incorrect golden traces** | High | Golden trace criteria include execution validation. A trace is only golden if the notebook actually runs. Multiple traces per goal type reduce single-trace bias. |
| **Skill compression removes critical edge cases** | Medium | Compression protocol includes edge-case test generation. Compressed skills are validated before deployment. Teacher re-compresses on validation failure. |
| **Harness modifications break existing functionality** | Medium | Regression test suite: 5 known-good goals must not regress after harness changes. Gate all harness mutations through this suite. |
| **Small model can't follow even compressed skills** | Medium | The fine-tuning channel addresses behavioral deficits that skills can't fix. If fine-tuning doesn't help, the model may be below the capability floor for TVB tasks — accept and document. |
| **Golden traces encode model-specific style that doesn't transfer** | Low | Strip conversational fluff from traces. Focus on tool-call sequences and action structure. Use multiple teacher models to diversify traces. |
| **The loop converges to a local optimum** | Low | The continuous improvement loop should be run until diminishing returns (<0.1 score improvement per iteration for 3 consecutive iterations). At that point, the architecture has done its job — document the ceiling. |

---

## 7. Success Criteria

| Criterion | Target | Measurement |
|---|---|---|
| **Skill Δ for 8B model** | ≥ +0.50 on abstract goals | Mean score difference (with_skills − zero_shot) across 9 goals |
| **Fine-tuning Δ** | ≥ +0.30 over skills-only baseline | Mean score (fine-tuned+skills) − (base+skills) |
| **Success rate** | ≥ 80% notebooks generated without harness intervention | % of trials where no early-stop/retry/repair was needed |
| **Golden trace coverage** | ≥ 5 goal types with validated golden traces | Count of distinct goal types with ≥1 golden trace |
| **Evaluation integrity** | 100% of scores from independent evaluator | Zero trials with PI_MODEL == EVAL_MODEL |
| **Context budget compliance** | 0 trials exceeding model context limit | Token count never > model max |

---

## 8. Timeline

| Phase | Duration | Deliverable |
|---|---|---|
| **Repo cleanup** | 2 hours | Pruned repo, deleted stale artifacts, consolidated scripts |
| **Phase 1: Fix + harden harness** | 1 week | Fixed evaluation pipeline, early-stop detection, JSON validation gate, adaptive retry, context budget tracker, external state file, evidence injection |
| **Phase 2: Teacher-driven tool macros** | 1 week | 4–5 tool macros (region_sim, surface_sim, bold_monitor, stimulus, param_sweep) — teacher defines, harness expands, student invokes |
| **Phase 3: Skill compression** | 1 week | Teacher-driven compressor, per-model skill variants, edge-case validation gate |
| **Phase 4: Golden traces + fine-tuning** | 1 week | 10–12 validated golden traces across 5+ goal types, LoRA fine-tuned 8B model, before/after benchmarks |
| **Phase 5: Continuous loop** | Ongoing | Weekly iteration: measure → diagnose failure class → teacher intervenes at correct level → deploy → re-measure |

**Total to initial results:** ~4 weeks to Phase 4 completion.

Note: Phase 2 (tool macros) moves before skill compression because macros are higher-leverage — they fundamentally reduce what the student has to do, while compression only makes existing skills fit. A student that can call `tvb_region_sim` in one tool call needs fewer skills than one that must execute 6 sequential primitive calls.

---

## 9. Key Principles (Closing)

1. **The teacher writes everything.** Skills, harness rules, tool definitions, macros, prompts — when the teacher sees a failure, it picks the right level to intervene. A harness fix is faster and more reliable than a skill rewrite. A tool macro replaces 10 fragile student tool calls with 1 reliable invocation.

2. **The harness IS the product.** SmallCode proved that harness engineering compensates for 3–4x smaller models. Autotvb's harness must evolve from a bash loop into a protective runtime — and the teacher is the one evolving it.

3. **Measure everything, trust nothing.** The evaluation bugs cost weeks of false confidence. Every score must have provenance: which model generated it, which model evaluated it, and whether evaluation succeeded on first attempt.

4. **Skills are knowledge; fine-tuning is behavior; harness is safety; tools are leverage.** Four channels, each addresses a different class of failure. Use the right one for each problem.

5. **Compress for the student, not the teacher.** A skill that works for a frontier model may be useless for an 8B model. Always validate with the target student.

6. **Externalize state.** Small models cannot maintain internal context across turns. Write the plan to a file. Inject it every turn. This is cheap insurance.

7. **Fail fast, recover faster.** Detect degenerate behavior within 2–3 turns, not after 20. A 2-second JSON validation gate saves 5 minutes of wasted generation.

8. **Golden traces are the bridge.** They convert the teacher's capability into the student's training data. Collect them deliberately, validate them rigorously, and treat them as the most valuable artifact in the system.

9. **Diagnose before intervening.** "Notebook didn't execute" ≠ "skill is missing." It could be a harness gap (no JSON validation), a tool gap (no macro for the pattern), a prompt gap (wrong priority), or a capability floor. The teacher classifies before it modifies.

10. **Gate every change.** Every modification — skill, harness, tool, or prompt — goes through: generate → validate → regression test → deploy. Revert on regression. This is non-negotiable.
