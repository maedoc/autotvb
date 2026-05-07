#!/usr/bin/env bash
set -uo pipefail
# exp_gemma26b_128k.sh — gemma4.26b.128k:latest (local, 128K) abstract zero_shot vs prompt+skills
# 128K context → sufficient for full skill set via filter_skills.sh

cd ~/src/autotvb

BATCH_ROOT="sandbox/qwen36_$(date +%Y%m%d_%H%M%S)"
GEN_MODEL="ollama/qwen3.6:128k"
EVAL_MODEL="ollama/kimi-k2.6"
MAX_TURNS=1

GOALS=(
  "analyze_power_spectra" "compare_connectivity_normalization"
  "exploring_the_bold_monitor" "multiple_stimuli"
  "simulate_region_stimulus" "stochastic_simulation"
  "stroke_sj3d_bold" "visual_erp"
  "schizophrenia_nrg1_ei"
)

# Use abstract goals (no class hints)
declare -A GOAL_FILES
for g in "${GOALS[@]}"; do
    f="benchmarks/goals_abstract/${g}.GOAL.md"
    [ -f "$f" ] || f=$(find benchmarks -name "${g}.GOAL.md" 2>/dev/null | head -n1)
    [ -n "$f" ] && GOAL_FILES[$g]="$f" || echo "WARN: no goal file for $g"
done

mkdir -p "$BATCH_ROOT"
echo "=== qwen3.6:128k Experiment (128K context, full skills) ==="
echo "Gen:  $GEN_MODEL"
echo "Eval: $EVAL_MODEL"
echo "Batch: $BATCH_ROOT"
echo ""

total=$((${#GOALS[@]} * 2)); n=0

# ─── Phase 1: Generate ─────────────────────────────────────────
echo "=== Phase 1: Generation ==="
for condition in zero_shot with_skills; do
    for goal in "${GOALS[@]}"; do
        n=$((n + 1))
        goal_file="${GOAL_FILES[$goal]:-}"
        [ -z "$goal_file" ] && continue
        dir="$BATCH_ROOT/$condition/$goal"
        mkdir -p "$dir"; cp "$goal_file" "$dir/GOAL.md"
        [ -f "$dir/workflow.ipynb" ] && [ -f "$dir/done" ] && { echo "[$n/$total] SKIP $condition/$goal"; continue; }
        
        echo -n "[$n/$total] $condition/$goal ... "
        
        if [ "$condition" = "zero_shot" ]; then
            NO_SKILLS=1 PROMPT_VARIANT=zero_shot ONE_SHOT=0 \
                PI_MODEL=$GEN_MODEL MAX_TURNS=$MAX_TURNS MAX_FIX_RETRIES=0 \
                timeout 600 bash bin/run_trial.sh "$dir/GOAL.md" "$MAX_TURNS" "$dir" \
                > "$dir/trial.log" 2>&1 || true
        else
            NO_SKILLS=0 PROMPT_VARIANT=default ONE_SHOT=0 \
                PI_MODEL=$GEN_MODEL MAX_TURNS=$MAX_TURNS MAX_FIX_RETRIES=0 \
                timeout 600 bash bin/run_trial.sh "$dir/GOAL.md" "$MAX_TURNS" "$dir" \
                > "$dir/trial.log" 2>&1 || true
        fi
        
        if [ -f "$dir/workflow.ipynb" ]; then
            echo "OK ($(wc -c < "$dir/workflow.ipynb") bytes)"; touch "$dir/done"
        else
            echo "FAILED"
        fi
    done
done

# ─── Phase 2: Evaluate (sequential, single concurrent) ──────
echo ""
echo "=== Phase 2: Evaluation (sequential) ==="
eval_n=0
for condition in zero_shot with_skills; do
    for goal in "${GOALS[@]}"; do
        dir="$BATCH_ROOT/$condition/$goal"
        nb="$dir/workflow.ipynb"; [ -f "$nb" ] || continue
        eval_n=$((eval_n + 1))
        echo -n "[EVAL $eval_n] $condition/$goal ... "
        EVAL_TIMEOUT=600 PI_MODEL=$EVAL_MODEL bash bin/evaluate.sh \
            "$nb" "$dir/GOAL.md" "$dir/evaluation.json" > "$dir/eval.log" 2>&1
        s=$(python3 -c "import json; d=json.load(open('$dir/evaluation.json')); print(d.get('scalar_score','?'))" 2>/dev/null)
        echo "→ $s"
    done
done

# ─── Phase 3: Results ─────────────────────────────────────────
echo ""
python3 << PYEOF
import json, os
from collections import defaultdict
batch = "$BATCH_ROOT"
results = defaultdict(list); per = defaultdict(dict)
for cond in ["zero_shot","with_skills"]:
    for goal in os.listdir(os.path.join(batch, cond)):
        ev = os.path.join(batch, cond, goal, "evaluation.json")
        if not os.path.exists(ev): continue
        d = json.load(open(ev))
        if not d.get("fallback") and d.get("scalar_score",0) > 0:
            results[cond].append(d); per[goal][cond] = d
goals_list = sorted(set(per.keys()))
print("=" * 62)
print(f"{'Condition':<14} {'N':>3} {'Mean':>7} {'Corr':>6} {'Qual':>6} {'Sci':>6} {'Tok':>6}")
print("=" * 62)
for cond in ["zero_shot","with_skills"]:
    entries = results.get(cond,[])
    if not entries: continue
    scores = [d["scalar_score"] for d in entries]
    avg = sum(scores)/len(scores)
    dims = ["correctness","code_quality","scientific_validity","token_efficiency"]
    da = {dim: sum(d[dim] for d in entries if d.get(dim,0)>0)/max(1,sum(1 for d in entries if d.get(dim,0)>0)) for dim in dims}
    print(f"{cond:<14} {len(entries):>3} {avg:7.2f} {da['correctness']:6.1f} {da['code_quality']:6.1f} {da['scientific_validity']:6.1f} {da['token_efficiency']:6.1f}")
zs = [d["scalar_score"] for d in results.get("zero_shot",[])]
ws = [d["scalar_score"] for d in results.get("with_skills",[])]
if zs and ws:
    print(f"\nSkill Δ: {sum(ws)/len(ws):.2f} − {sum(zs)/len(zs):.2f} = {sum(ws)/len(ws)-sum(zs)/len(zs):+.2f}")
print(f"\nSuccess rate: zs={len(zs)}/{len(goals_list)} ws={len(ws)}/{len(goals_list)}")
print(f"All-goals mean (failures=0): zs={sum(zs)/len(goals_list):.2f} ws={sum(ws)/len(goals_list):.2f}")
print("\n--- Per-Goal ---")
for goal in goals_list:
    z = per[goal].get("zero_shot",{}); w = per[goal].get("with_skills",{})
    print(f"  {goal:<40} zs={z.get('scalar_score','-'):<5} ws={w.get('scalar_score','-'):<5}")
PYEOF
echo ""
echo "=== Done at $(date -Iseconds) ==="
