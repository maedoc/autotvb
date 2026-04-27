#!/usr/bin/env bash
set -euo pipefail

# orchestrator.sh — Autoresearch outer loop for navigator/driver evolution
cd "$(dirname "$0")/.."
TRIAL_ID="${1:-$(date +%s)}"
GOAL_FILE="${2:-benchmarks/goals/visual_erp.GOAL.md}"
MAX_TRIALS="${3:-20}"
CURRENT_SCORE="0.0"
BEST_SCORE="0.0"

BRANCH="trial-$TRIAL_ID"
git checkout -b "$BRANCH" 2>/dev/null || git checkout "$BRANCH"

echo "=== Autoresearch Outer Loop ==="
echo "Goal: $GOAL_FILE"
echo "Branch: $BRANCH"

for i in $(seq 1 "$MAX_TRIALS"); do
    echo ""
    echo "=== Trial $i (branch $BRANCH) ==="

    # Optional: mutate prompts/skills before trial (evolution step)
    # For now, prompts are static; evolution will be added later.

    # Run trial
    bash bin/run_trial.sh "$GOAL_FILE" 20 "sandbox"

    # Evaluate
    bash bin/evaluate.sh "sandbox/workflow.ipynb" "$GOAL_FILE" "sandbox/evaluation.json"

    # Extract score
    if [ -f "sandbox/evaluation.json" ]; then
        CURRENT_SCORE=$(grep -oP '"scalar_score":\s*\K[0-9.]+' sandbox/evaluation.json || echo "0.0")
    else
        CURRENT_SCORE="0.0"
    fi

    echo "Trial $i score: $CURRENT_SCORE (best: $BEST_SCORE)"

    # Record
    echo '{"trial":'$i',"branch":"'$BRANCH'","score":'$CURRENT_SCORE',"timestamp":"'$(date -Iseconds)'"}' >> benchmarks/scores.jsonl

    # Decide: keep or revert
    if awk "BEGIN {exit !($CURRENT_SCORE > $BEST_SCORE)}"; then
        echo "[KEEP] New best score. Committing..."
        BEST_SCORE="$CURRENT_SCORE"
        git add -A
        git commit -m "[trial-$TRIAL_ID-$i] score=$CURRENT_SCORE" || echo "Nothing to commit"
        git checkout main 2>/dev/null || true
        git merge --no-ff "$BRANCH" -m "Merge trial-$TRIAL_ID-$i (score=$CURRENT_SCORE)" || true
    else
        echo "[REVERT] Score did not improve."
        git checkout main 2>/dev/null || true
        git branch -D "$BRANCH" 2>/dev/null || true
    fi

    # Next branch
    BRANCH="trial-$TRIAL_ID-$((i+1))"
    git checkout -b "$BRANCH" main 2>/dev/null || git checkout "$BRANCH"
done

echo ""
echo "=== Autoresearch complete ==="
echo "Best score: $BEST_SCORE"
echo "Scores log: benchmarks/scores.jsonl"
