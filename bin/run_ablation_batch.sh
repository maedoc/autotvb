#!/usr/bin/env bash
set -uo pipefail

# run_ablation_batch.sh — Skills ablation study across models
# Runs trials natively (cloud models via API, local models sequentially)
#
# Usage: bash run_ablation_batch.sh
#
# Environment:
#   MAX_CONCURRENT  - parallel cloud trials (default 5)
#   MAX_TURNS       - turns per trial (default 3)

BATCH_ROOT="${BATCH_ROOT:-sandbox/ablation_$(date +%Y%m%d_%H%M%S)}"
MAX_CONCURRENT="${MAX_CONCURRENT:-5}"
MAX_TURNS="${MAX_TURNS:-3}"

# ─── Model specs ────────────────────────────────────────────────────
# name:PI_MODEL:type  (type=cloud runs in parallel bg, type=local runs in fg)
MODEL_SPECS=(
    "rnj-8b:ollama/rnj-1:8b-cloud:cloud"
    "ministral-14b:ollama/ministral-3:14b-cloud:cloud"
    "gptoss-20b:ollama/gpt-oss:20b-cloud:cloud"
    "gemma4-31b:ollama/gemma4:31b-cloud:cloud"
    "qwen36-35b:qwen3.6:128k:local"
    "kimi-1t:ollama/kimi-k2.6:cloud:cloud"
)

CONDITIONS=("with_skills" "without_skills")

# ─── Goals ──────────────────────────────────────────────────────────
GOAL_NAMES=(
    visual_erp
    analyze_power_spectra
    compare_connectivity_normalization
    exploring_the_bold_monitor
    multiple_stimuli
    simulate_region_stimulus
    stochastic_simulation
    stroke_sj3d_bold
    schizophrenia_nrg1_ei
)

# ─── Resolve goal files ─────────────────────────────────────────────
declare -A GOAL_FILES
for g in "${GOAL_NAMES[@]}"; do
    f=$(find benchmarks -name "${g}.GOAL.md" 2>/dev/null | head -n1)
    if [ -z "$f" ]; then
        # Try hyphenated name
        f=$(find benchmarks -name "$(echo $g | tr '_' '-').GOAL.md" 2>/dev/null | head -n1)
    fi
    if [ -n "$f" ]; then
        GOAL_FILES[$g]="$f"
    else
        echo "WARN: Goal file not found for $g"
    fi
done

# ─── Count running background trials ────────────────────────────────
count_bg_jobs() {
    # Count PIDs in /tmp/ablation_pids that are still running
    local count=0
    for pid_file in /tmp/ablation_*.pid; do
        [ -f "$pid_file" ] || continue
        pid=$(cat "$pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            count=$((count + 1))
        else
            rm -f "$pid_file"
        fi
    done
    echo $count
}

wait_for_slot() {
    while [ "$(count_bg_jobs)" -ge "$MAX_CONCURRENT" ]; do
        sleep 10
    done
}

wait_for_all() {
    echo "Waiting for all background trials to finish..."
    while [ "$(count_bg_jobs)" -gt 0 ]; do
        running=$(count_bg_jobs)
        echo "  $running trials still running..."
        sleep 30
    done
    echo "All background trials finished."
}

# ─── Main ────────────────────────────────────────────────────────────
mkdir -p "$BATCH_ROOT"

total_trials=0
cloud_trials=0
local_trials=0
skipped=0

# Count expected trials
for model_spec in "${MODEL_SPECS[@]}"; do
    IFS=':' read -r model_name model_id model_type <<< "$model_spec"
    for condition in "${CONDITIONS[@]}"; do
        # Skip kimi-1t/with_skills — use existing batch 3 data
        if [ "$model_name" = "kimi-1t" ] && [ "$condition" = "with_skills" ]; then
            continue
        fi
        for g in "${GOAL_NAMES[@]}"; do
            total_trials=$((total_trials + 1))
            [ "$model_type" = "cloud" ] && cloud_trials=$((cloud_trials + 1))
            [ "$model_type" = "local" ] && local_trials=$((local_trials + 1))
        done
    done
done

echo "=== Ablation Study ==="
echo "Batch dir: $BATCH_ROOT"
echo "Total new trials: $total_trials (cloud: $cloud_trials, local: $local_trials)"
echo "Plus kimi-1t/with_skills from existing batch data (9 goals)"
echo ""

# ─── Phase 1: Run trials ────────────────────────────────────────────
echo "=== Phase 1: Running trials ==="

for model_spec in "${MODEL_SPECS[@]}"; do
    IFS=':' read -r model_name model_id model_type <<< "$model_spec"
    
    for condition in "${CONDITIONS[@]}"; do
        # Skip kimi with_skills (already have data)
        if [ "$model_name" = "kimi-1t" ] && [ "$condition" = "with_skills" ]; then
            echo "[SKIP] kimi-1t/with_skills — using existing batch data"
            continue
        fi
        
        no_skills_val=""
        [ "$condition" = "without_skills" ] && no_skills_val="1"
        
        for g in "${GOAL_NAMES[@]}"; do
            goal_file="${GOAL_FILES[$g]:-}"
            [ -z "$goal_file" ] && continue
            
            dir="$BATCH_ROOT/$model_name/$condition/$g"
            mkdir -p "$dir"
            
            # Skip if already done
            if [ -f "$dir/workflow.ipynb" ] && [ -f "$dir/trial.log" ] && grep -q BATCH_TRIAL_DONE "$dir/trial.log" 2>/dev/null; then
                echo "[SKIP] $model_name/$condition/$g — already done"
                skipped=$((skipped + 1))
                continue
            fi
            
            # Copy goal file
            cp "$goal_file" "$dir/GOAL.md"
            
            if [ "$model_type" = "local" ]; then
                # Local model: run sequentially in foreground
                echo "[LOCAL] $model_name/$condition/$g"
                NO_SKILLS=$no_skills_val PI_MODEL=$model_id MAX_TURNS=$MAX_TURNS \
                    bash bin/run_trial.sh "$dir/GOAL.md" "$MAX_TURNS" "$dir" \
                    > "$dir/trial.log" 2>&1 || true
                echo "BATCH_TRIAL_DONE" >> "$dir/trial.log"
            else
                # Cloud model: run in background with concurrency limit
                wait_for_slot
                echo "[CLOUD] $model_name/$condition/$g"
                NO_SKILLS=$no_skills_val PI_MODEL=$model_id MAX_TURNS=$MAX_TURNS \
                    bash bin/run_trial.sh "$dir/GOAL.md" "$MAX_TURNS" "$dir" \
                    > "$dir/trial.log" 2>&1 &
                pid=$!
                echo "$pid" > "/tmp/ablation_${model_name}_${condition}_${g}.pid"
            fi
        done
    done
done

# Wait for all cloud trials
wait_for_all

# ─── Phase 2: Copy existing kimi-1t/with_skills data ────────────────
echo ""
echo "=== Copying kimi-1t/with_skills from batch 3 ==="
BATCH3_DIR="sandbox/batch_all_20260503_175853"
for g in "${GOAL_NAMES[@]}"; do
    # Try hyphenated name in batch 3
    hyphenated=$(echo "$g" | tr '_' '-')
    src="$BATCH3_DIR/$hyphenated"
    dst="$BATCH_ROOT/kimi-1t/with_skills/$g"
    mkdir -p "$dst"
    
    [ -f "$src/workflow.ipynb" ] && cp "$src/workflow.ipynb" "$dst/" 2>/dev/null
    [ -f "$src/evaluation.json" ] && cp "$src/evaluation.json" "$dst/" 2>/dev/null
    [ -f "$src/GOAL.md" ] && [ ! -f "$dst/GOAL.md" ] && cp "$src/GOAL.md" "$dst/" 2>/dev/null
    
    if [ -f "$dst/evaluation.json" ]; then
        echo "  $g: copied"
    else
        echo "  $g: no data"
    fi
done

# ─── Phase 3: Evaluate all notebooks ────────────────────────────────
echo ""
echo "=== Phase 3: Evaluating notebooks ==="
EVAL_MODEL="${EVAL_MODEL:-ollama/kimi-k2.6:cloud}"
eval_count=0

for model_spec in "${MODEL_SPECS[@]}"; do
    IFS=':' read -r model_name model_id model_type <<< "$model_spec"
    for condition in "${CONDITIONS[@]}"; do
        for g in "${GOAL_NAMES[@]}"; do
            dir="$BATCH_ROOT/$model_name/$condition/$g"
            [ -f "$dir/workflow.ipynb" ] || continue
            [ -f "$dir/evaluation.json" ] && [ -s "$dir/evaluation.json" ] && continue
            
            PI_MODEL=$EVAL_MODEL bash bin/evaluate.sh \
                "$dir/workflow.ipynb" "$dir/GOAL.md" "$dir/evaluation.json" \
                > "$dir/eval.log" 2>&1 || true
            eval_count=$((eval_count + 1))
        done
    done
done

echo "Evaluated $eval_count notebooks"

# ─── Phase 4: Print results table ───────────────────────────────────
echo ""
echo "=== Phase 4: Results ==="
echo "BATCH_ROOT=$BATCH_ROOT"

python3 << 'PYEOF'
import json, os, sys

batch_root = os.environ.get("BATCH_ROOT", "")
if not batch_root:
    # Find the latest ablation directory
    dirs = sorted([d for d in os.listdir("sandbox") if d.startswith("ablation_")])
    if dirs:
        batch_root = os.path.join("sandbox", dirs[-1])
    else:
        print("No ablation directory found")
        sys.exit(1)

print(f"Reading from: {batch_root}")

models = [
    ("rnj-8b", "8B"),
    ("ministral-14b", "14B"),
    ("gptoss-20b", "20B"),
    ("qwen36-35b", "35B"),
    ("gemma4-31b", "31B"),
    ("kimi-1t", "1T"),
]

conditions = ["without_skills", "with_skills"]
goals = ["visual_erp", "analyze_power_spectra", "compare_connectivity_normalization",
         "exploring_the_bold_monitor", "multiple_stimuli", "simulate_region_stimulus",
         "stochastic_simulation", "stroke_sj3d_bold", "schizophrenia_nrg1_ei"]

dims = ["correctness", "code_quality", "scientific_validity", "token_efficiency"]

results = {}
for model_name, _ in models:
    for condition in conditions:
        key = f"{model_name}/{condition}"
        scores = []
        for goal in goals:
            f = os.path.join(batch_root, model_name, condition, goal, "evaluation.json")
            if os.path.exists(f):
                try:
                    d = json.load(open(f))
                    if not d.get("fallback") and d.get("scalar_score", 0) > 0:
                        scores.append(d)
                except:
                    pass
        if scores:
            avg = sum(s["scalar_score"] for s in scores) / len(scores)
            dim_avgs = {dim: sum(s.get(dim, 0) for s in scores) / len(scores) for dim in dims}
            results[key] = {"avg": avg, "n": len(scores), "dims": dim_avgs}

# Main table
print()
print("=" * 95)
print(f"{'Model':<16} {'Params':>5} {'No Skills':>10} {'With Skills':>12} {'Skill Δ':>8} {'vs kimi no-sk':>15}")
print("=" * 95)

kimi_ns = results.get("kimi-1t/without_skills", {}).get("avg", 0)

for model_name, params in models:
    ws = results.get(f"{model_name}/with_skills", {})
    ns = results.get(f"{model_name}/without_skills", {})
    ws_avg = ws.get("avg", 0)
    ns_avg = ns.get("avg", 0)
    
    if ws_avg > 0 and ns_avg > 0:
        delta = ws_avg - ns_avg
        vs_kimi = ws_avg - kimi_ns
        marker = " ✓" if vs_kimi >= 0 else ""
        print(f"{model_name:<16} {params:>5} {ns_avg:10.2f} {ws_avg:12.2f} {delta:+7.2f} {vs_kimi:+14.2f}{marker}")
    elif ws_avg > 0:
        print(f"{model_name:<16} {params:>5} {'—':>10} {ws_avg:12.2f} {'—':>8} {'—':>15}")
    elif ns_avg > 0:
        print(f"{model_name:<16} {params:>5} {ns_avg:10.2f} {'—':>12} {'—':>8} {'—':>15}")
    else:
        print(f"{model_name:<16} {params:>5} {'—':>10} {'—':>12} {'—':>8} {'—':>15}")

print("=" * 95)

# Per-dimension table
print()
print("--- Per-Dimension Breakdown ---")
for dim in dims:
    print(f"\n  {dim}:")
    print(f"    {'Model':<16} {'No Skills':>10} {'With Skills':>12} {'Δ':>7}")
    for model_name, params in models:
        ws = results.get(f"{model_name}/with_skills", {})
        ns = results.get(f"{model_name}/without_skills", {})
        ws_d = ws.get("dims", {}).get(dim, 0)
        ns_d = ns.get("dims", {}).get(dim, 0)
        if ws_d > 0 or ns_d > 0:
            d = (ws_d - ns_d) if (ws_d > 0 and ns_d > 0) else 0
            print(f"    {model_name:<16} {ns_d:10.2f} {ws_d:12.2f} {d:+7.2f}")

# Per-goal detail
print()
print("--- Per-Goal Detail (with_skills - without_skills) ---")
for model_name, params in models:
    ws_key = f"{model_name}/with_skills"
    ns_key = f"{model_name}/without_skills"
    if ws_key not in results and ns_key not in results:
        continue
    print(f"\n  {model_name} ({params}):")
    for goal in goals:
        ws_f = os.path.join(batch_root, model_name, "with_skills", goal, "evaluation.json")
        ns_f = os.path.join(batch_root, model_name, "without_skills", goal, "evaluation.json")
        ws_s = json.load(open(ws_f)).get("scalar_score", "?") if os.path.exists(ws_f) else "—"
        ns_s = json.load(open(ns_f)).get("scalar_score", "?") if os.path.exists(ns_f) else "—"
        d = "—"
        if isinstance(ws_s, (int, float)) and isinstance(ns_s, (int, float)):
            d = f"{ws_s - ns_s:+.2f}"
        print(f"    {goal:<40} no_skills={ns_s}  with={ws_s}  Δ={d}")

PYEOF

echo ""
echo "=== Ablation study complete ==="