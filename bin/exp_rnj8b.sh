#!/usr/bin/env bash
set -uo pipefail
# exp_rnj8b.sh — rnj-1:8b (local, 32K) zero_shot vs prompt+skills

cd ~/src/autotvb

BATCH_ROOT="sandbox/rnj8b_$(date +%Y%m%d_%H%M%S)"
GEN_MODEL="ollama/rnj-1:8b"
EVAL_MODEL="ollama/kimi-k2.6"
MAX_TURNS=1

GOALS=(
  "analyze_power_spectra"
  "compare_connectivity_normalization"
  "exploring_the_bold_monitor"
  "multiple_stimuli"
  "simulate_region_stimulus"
  "stochastic_simulation"
  "stroke_sj3d_bold"
  "visual_erp"
  "schizophrenia_nrg1_ei"
)

# Slim skill set for 32K context (2043 + 2 goal-specific)
# These 3 skills cover the essential API knowledge for rnj-1:8b
SLIM_SKILLS="--skill skills-in-progress/driver/small-model-essentials --skill skills-in-progress/driver/boilerplate --skill skills-in-progress/driver/simulation-duration"

declare -A GOAL_FILES
for g in "${GOALS[@]}"; do
    # Prefer abstract goals (no class hints), fall back to original
    f="benchmarks/goals_abstract/${g}.GOAL.md"
    [ -f "$f" ] || f=$(find benchmarks -name "${g}.GOAL.md" 2>/dev/null | head -n1)
    [ -z "$f" ] && f=$(find benchmarks -name "$(echo $g | tr '_' '-').GOAL.md" 2>/dev/null | head -n1)
    [ -n "$f" ] && GOAL_FILES[$g]="$f" || echo "WARN: no goal file for $g"
done

mkdir -p "$BATCH_ROOT"
echo "=== rnj-1:8b Experiment ==="
echo "Gen:  $GEN_MODEL (32K ctx)"
echo "Eval: $EVAL_MODEL (frontier)"
echo "Batch: $BATCH_ROOT"
echo "Skills: 3 slim skills (~8KB total)"
echo ""

total=$((${#GOALS[@]} * 2))  # 2 conditions: zero_shot, with_skills
n=0

# ─── Phase 1: Generate ─────────────────────────────────────────
echo "=== Phase 1: Generation ==="

for condition in zero_shot with_skills; do
    for goal in "${GOALS[@]}"; do
        n=$((n + 1))
        goal_file="${GOAL_FILES[$goal]:-}"
        [ -z "$goal_file" ] && continue
        
        dir="$BATCH_ROOT/$condition/$goal"
        mkdir -p "$dir"
        cp "$goal_file" "$dir/GOAL.md"
        
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
                SKILL_FLAGS_OVERRIDE="$SLIM_SKILLS" \
                timeout 600 bash bin/run_trial.sh "$dir/GOAL.md" "$MAX_TURNS" "$dir" \
                > "$dir/trial.log" 2>&1 || true
        fi
        
        if [ -f "$dir/workflow.ipynb" ]; then
            sz=$(wc -c < "$dir/workflow.ipynb")
            echo "OK (${sz} bytes)"
            touch "$dir/done"
        else
            echo "FAILED"
        fi
    done
done

echo ""

# ─── Phase 2: Evaluate (blinded) ──────────────────────────────
echo "=== Phase 2: Blinded Evaluation with $EVAL_MODEL ==="
eval_n=0; ok_n=0

for condition in zero_shot with_skills; do
    for goal in "${GOALS[@]}"; do
        dir="$BATCH_ROOT/$condition/$goal"
        nb="$dir/workflow.ipynb"
        [ -f "$nb" ] || continue
        
        eval_n=$((eval_n + 1))
        echo -n "[EVAL $eval_n] $condition/$goal ... "
        
        EVAL_TIMEOUT=600 PI_MODEL=$EVAL_MODEL bash bin/evaluate.sh \
            "$nb" "$dir/GOAL.md" "$dir/evaluation.json" \
            > "$dir/eval.log" 2>&1
        
        score=$(python3 -c "import json; d=json.load(open('$dir/evaluation.json')); print(d.get('scalar_score','?'))" 2>/dev/null)
        fb=$(python3 -c "import json; d=json.load(open('$dir/evaluation.json')); print('FALLBACK' if d.get('fallback') else '')" 2>/dev/null)
        echo "→ $score $fb"
        [ "$score" != "0" ] && [ "$score" != "0.0" ] && [ "$score" != "?" ] && ok_n=$((ok_n + 1))
    done
done

echo "Valid evaluations: $ok_n / $eval_n"
echo ""

# ─── Phase 3: Results ─────────────────────────────────────────
python3 << PYEOF
import json, os
from collections import defaultdict

batch = "$BATCH_ROOT"
results = defaultdict(lambda: defaultdict(list))
per_goal = defaultdict(lambda: defaultdict(dict))

for cond in ["zero_shot", "with_skills"]:
    for goal in os.listdir(os.path.join(batch, cond)):
        gd = os.path.join(batch, cond, goal)
        ev = os.path.join(gd, "evaluation.json")
        if not os.path.exists(ev): continue
        try:
            d = json.load(open(ev))
            if d.get("fallback") or d.get("scalar_score", 0) <= 0: continue
            results[cond]["scores"].append(d["scalar_score"])
            per_goal[goal][cond] = d
        except: pass

print("=" * 60)
print(f"{'Condition':<16} {'N':>4} {'Mean':>7}")
print("=" * 60)
for cond in ["zero_shot", "with_skills"]:
    scores = results[cond].get("scores", [])
    if scores:
        print(f"{cond:<16} {len(scores):>4} {sum(scores)/len(scores):7.2f}")
print("=" * 60)

if results["zero_shot"]["scores"] and results["with_skills"]["scores"]:
    zs = sum(results["zero_shot"]["scores"]) / len(results["zero_shot"]["scores"])
    ws = sum(results["with_skills"]["scores"]) / len(results["with_skills"]["scores"])
    print(f"\nSkill Δ: {ws:.2f} − {zs:.2f} = {ws-zs:+.2f}")

print("\n--- Per-Goal ---")
for goal in sorted(per_goal.keys()):
    zs = per_goal[goal].get("zero_shot", {})
    ws = per_goal[goal].get("with_skills", {})
    zs_s = zs.get("scalar_score", "-")
    ws_s = ws.get("scalar_score", "-")
    print(f"  {goal:<40} zs={zs_s}  ws={ws_s}")
PYEOF

echo ""
echo "=== Experiment complete ==="
