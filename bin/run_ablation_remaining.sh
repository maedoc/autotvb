#!/usr/bin/env bash
set -uo pipefail

# run_ablation_remaining.sh — Run remaining ablation trials
# Max 3 concurrent pi calls. Uses pipe-delimited fields to avoid colon conflicts.

BATCH_ROOT="${BATCH_ROOT:-sandbox/ablation_20260504_120703}"
MAX_CONCURRENT=3
PIDS_DIR="/tmp/ablation_pids"
rm -rf "$PIDS_DIR"
mkdir -p "$PIDS_DIR"

count_running() {
    local count=0
    for f in "$PIDS_DIR"/*.pid; do
        [ -f "$f" ] || continue
        pid=$(cat "$f")
        if kill -0 "$pid" 2>/dev/null; then
            count=$((count + 1))
        else
            rm -f "$f"
        fi
    done
    echo $count
}

wait_for_slot() {
    while [ "$(count_running)" -ge "$MAX_CONCURRENT" ]; do
        sleep 10
    done
}

# ─── Build todo list using | delimiter ──────────────────────────────
GOALS=(visual_erp analyze_power_spectra compare_connectivity_normalization exploring_the_bold_monitor multiple_stimuli simulate_region_stimulus stochastic_simulation stroke_sj3d_bold schizophrenia_nrg1_ei)

declare -a cloud_trials=()
declare -a local_trials=()

for entry in \
    "rnj-8b|ollama/rnj-1:8b-cloud|cloud" \
    "ministral-14b|ollama/ministral-3:14b-cloud|cloud" \
    "gptoss-20b|ollama/gpt-oss:20b-cloud|cloud" \
    "gemma4-31b|ollama/gemma4:31b-cloud|cloud" \
    "kimi-1t|ollama/kimi-k2.6:cloud|cloud" \
    "qwen36-35b|qwen3.6:128k|local"; do
    
    IFS='|' read -r mname mid mtype <<< "$entry"
    
    for cond in with_skills without_skills; do
        [ "$mname" = "kimi-1t" ] && [ "$cond" = "with_skills" ] && continue
        
        for g in "${GOALS[@]}"; do
            gfile=$(find benchmarks -name "${g}.GOAL.md" 2>/dev/null | head -n1)
            [ -z "$gfile" ] && gfile=$(find benchmarks -name "$(echo $g | tr '_' '-').GOAL.md" 2>/dev/null | head -n1)
            [ -z "$gfile" ] && continue
            
            dir="$BATCH_ROOT/$mname/$cond/$g"
            has_nb=$([ -f "$dir/workflow.ipynb" ] && echo 1 || echo 0)
            has_valid=0
            if [ -f "$dir/evaluation.json" ] && [ -s "$dir/evaluation.json" ]; then
                is_v=$(python3 -c "import json; d=json.load(open('$dir/evaluation.json')); print(1 if not d.get('fallback') and d.get('scalar_score',0)>0 else 0)" 2>/dev/null || echo 0)
                has_valid=$is_v
            fi
            
            if [ "$has_nb" = "0" ]; then
                # Need a trial
                if [ "$mtype" = "local" ]; then
                    local_trials+=("$mname|$mid|$cond|$g|$gfile")
                else
                    cloud_trials+=("$mname|$mid|$cond|$g|$gfile")
                fi
            elif [ "$has_valid" = "0" ]; then
                # Need an eval — do in phase 2
                :  # handled later
            fi
        done
    done
done

echo "=== Remaining work ==="
echo "Cloud trials: ${#cloud_trials[@]}"
echo "Local trials: ${#local_trials[@]}"
echo ""

# ─── Phase 1a: Cloud trials (max 3 concurrent) ─────────────────────
echo "=== Phase 1a: Cloud trials ==="
for spec in "${cloud_trials[@]}"; do
    IFS='|' read -r mname mid cond g gfile <<< "$spec"
    wait_for_slot
    
    dir="$BATCH_ROOT/$mname/$cond/$g"
    mkdir -p "$dir"
    cp "$gfile" "$dir/GOAL.md"
    
    no_skills=""
    [ "$cond" = "without_skills" ] && no_skills="1"
    
    echo "[LAUNCH] $mname/$cond/$g"
    NO_SKILLS=$no_skills PI_MODEL="$mid" MAX_TURNS=3 \
        bash bin/run_trial.sh "$dir/GOAL.md" 3 "$dir" \
        > "$dir/trial.log" 2>&1 &
    echo $! > "$PIDS_DIR/${mname}_${cond}_${g}.pid"
done

echo "Waiting for cloud trials..."
while [ "$(count_running)" -gt 0 ]; do
    running=$(count_running)
    nbs=$(find $BATCH_ROOT -name workflow.ipynb 2>/dev/null | wc -l)
    echo "  $running running, $nbs notebooks total"
    sleep 60
done
echo "Cloud trials done at $(date)"

# ─── Phase 1b: Local qwen3.6:128k trials (sequential) ───────────────
echo ""
echo "=== Phase 1b: Local trials (qwen3.6:128k) ==="
for spec in "${local_trials[@]}"; do
    IFS='|' read -r mname mid cond g gfile <<< "$spec"
    dir="$BATCH_ROOT/$mname/$cond/$g"
    mkdir -p "$dir"
    cp "$gfile" "$dir/GOAL.md"
    
    no_skills=""
    [ "$cond" = "without_skills" ] && no_skills="1"
    
    echo "  [LOCAL] $mname/$cond/$g"
    NO_SKILLS=$no_skills PI_MODEL="$mid" MAX_TURNS=3 \
        bash bin/run_trial.sh "$dir/GOAL.md" 3 "$dir" \
        > "$dir/trial.log" 2>&1 || true
    echo "  Done"
done
echo "Local trials done at $(date)"

# ─── Phase 2: Evaluate all notebooks missing valid evals ───────────
echo ""
echo "=== Phase 2: Evaluating notebooks ==="
eval_count=0

for mname in rnj-8b ministral-14b gptoss-20b qwen36-35b gemma4-31b kimi-1t; do
    for cond in with_skills without_skills; do
        [ "$mname" = "kimi-1t" ] && [ "$cond" = "with_skills" ] && continue
        for g in "${GOALS[@]}"; do
            dir="$BATCH_ROOT/$mname/$cond/$g"
            [ -f "$dir/workflow.ipynb" ] || continue
            [ -f "$dir/GOAL.md" ] || continue
            has_valid=0
            if [ -f "$dir/evaluation.json" ] && [ -s "$dir/evaluation.json" ]; then
                is_v=$(python3 -c "import json; d=json.load(open('$dir/evaluation.json')); print(1 if not d.get('fallback') and d.get('scalar_score',0)>0 else 0)" 2>/dev/null || echo 0)
                has_valid=$is_v
            fi
            [ "$has_valid" = "1" ] && continue
            
            wait_for_slot
            rm -f "$dir/evaluation.json"  # Remove stale fallback
            PI_MODEL=ollama/kimi-k2.6:cloud bash bin/evaluate.sh \
                "$dir/workflow.ipynb" "$dir/GOAL.md" "$dir/evaluation.json" \
                > "$dir/eval.log" 2>&1 &
            echo $! > "$PIDS_DIR/eval_${mname}_${cond}_${g}.pid"
            eval_count=$((eval_count + 1))
        done
    done
done

echo "Launched $eval_count evaluations. Waiting..."
while [ "$(count_running)" -gt 0 ]; do
    sleep 15
done
echo "Evaluations done."

# ─── Copy kimi-1t/with_skills from batch 3 ──────────────────────────
echo ""
for g in "${GOALS[@]}"; do
    hyp=$(echo "$g" | tr '_' '-')
    src="sandbox/batch_all_20260503_175853/$hyp"
    dst="$BATCH_ROOT/kimi-1t/with_skills/$g"
    mkdir -p "$dst"
    for f in workflow.ipynb evaluation.json GOAL.md; do
        [ -f "$src/$f" ] && [ ! -f "$dst/$f" ] && cp "$src/$f" "$dst/" 2>/dev/null
    done
done

echo ""
echo "=== ALL DONE at $(date) ==="