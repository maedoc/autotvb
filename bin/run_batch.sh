#!/usr/bin/env bash
set -uo pipefail
# run_batch.sh — Parallel baseline sweep across many goals
# Note: no set -e — we handle errors manually to avoid killing the batch on minor failures
# Usage: run_batch.sh [GOAL_DIR] [MAX_JOBS] [MAX_TURNS]
#   GOAL_DIR: directory containing *.GOAL.md files (default: benchmarks/goals)
#   MAX_JOBS: parallel workers (default: 4)
#   MAX_TURNS: per-trial turn budget (default: 5)

GOAL_DIR="${1:-benchmarks/goals}"
MAX_JOBS="${2:-4}"
MAX_TURNS="${3:-5}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BATCH_DIR="benchmarks/batch_${TIMESTAMP}"
mkdir -p "$BATCH_DIR"

# Collect goals
goals=()
while IFS= read -r -d '' goal; do
    goals+=("$goal")
done < <(find "$GOAL_DIR" -maxdepth 1 -name '*.GOAL.md' -print0 | sort -z)

echo "=== Batch run: ${#goals[@]} goals | ${MAX_JOBS} workers | ${MAX_TURNS} turns ==="

# Track PIDs and their goal names
declare -A GOAL_BY_PID
declare -A DIR_BY_PID

run_one() {
    local goal="$1"
    local goal_name=$(basename "$goal" .GOAL.md)
    local trial_dir="$BATCH_DIR/${goal_name}"
    mkdir -p "$trial_dir"
    local log="$trial_dir/batch.log"

    echo "[START] $goal_name"
    bash bin/run_trial.sh "$goal" "$MAX_TURNS" "$trial_dir" > "$log" 2>&1
    local trial_exit=$?

    if [ -f "$trial_dir/workflow.ipynb" ]; then
        bash bin/evaluate.sh "$trial_dir/workflow.ipynb" "$goal" "$trial_dir/evaluation.json" >> "$log" 2>&1
    fi

    echo "[DONE] $goal_name exit=$trial_exit"
}

# Semaphore-style parallel execution
active=0
for goal in "${goals[@]}"; do
    if [ "$active" -ge "$MAX_JOBS" ]; then
        wait -n  # wait for ANY background job to finish
        active=$((active - 1))
    fi
    run_one "$goal" &
    active=$((active + 1))
done
wait  # drain remaining jobs

# ─── Aggregate results ────────────────────────────────────────────
SUMMARY="$BATCH_DIR/summary.jsonl"
echo '{"event":"batch_start","timestamp":"'$(date -Iseconds)'","goals":'${#goals[@]}',"workers":'${MAX_JOBS}',"max_turns":'${MAX_TURNS}'}' > "$SUMMARY"

for goal in "${goals[@]}"; do
    goal_name=$(basename "$goal" .GOAL.md)
    trial_dir="$BATCH_DIR/${goal_name}"
    eval_file="$trial_dir/evaluation.json"
    if [ -f "$eval_file" ] && [ -s "$eval_file" ]; then
        jq -c --arg goal "$goal_name" --arg dir "$trial_dir" \
            '{goal: $goal, trial_dir: $dir} + .' \
            "$eval_file" >> "$SUMMARY"
    else
        echo '{"goal":"'$goal_name'","trial_dir":"'$trial_dir'","scalar_score":0,"correctness":0,"code_quality":0,"scientific_validity":0,"token_efficiency":0,"justification":"no evaluation produced"}' >> "$SUMMARY"
    fi
done

# ─── Print summary ─────────────────────────────────────────────────
cat <<EOF

=== Batch Complete ===
Results: $BATCH_DIR/summary.jsonl

Per-Goal Scores:
EOF

jq -r '[.goal, .scalar_score, .correctness, .code_quality, .scientific_validity, .token_efficiency, .turns // "?"] | @tsv' "$SUMMARY" 2>/dev/null | tail -n +2 | column -t -N GOAL,SCORE,CN,CQ,SV,TE,TURNS

avg=$(jq -s 'map(.scalar_score // 0) | add / length' "$SUMMARY")
echo ""
echo "Average scalar score: $avg"
echo "Batch dir: $BATCH_DIR"
