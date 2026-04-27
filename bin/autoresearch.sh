#!/usr/bin/env bash
set -euo pipefail
# autoresearch.sh — Minimal autonomous mutation loop
# Usage: autoresearch.sh [GOAL_FILE] [MAX_ITER] [MAX_TURNS]

GOAL_FILE="${1:-benchmarks/goals/tutorial_s6_modelingepilepsy.GOAL.md}"
MAX_ITER="${2:-5}"
MAX_TURNS="${3:-5}"
TRIAL_DIR="sandbox/autoresearch"
SESSION="benchmarks/autoresearch_session.jsonl"

# Ensure clean trial dir
mkdir -p "$TRIAL_DIR"
rm -f "$TRIAL_DIR"/*.md "$TRIAL_DIR"/*.json "$TRIAL_DIR"/*.ipynb

echo "=== Autoresearch Loop ==="
echo "Goal: $GOAL_FILE"
echo "Iterations: $MAX_ITER"
echo "Max turns: $MAX_TURNS"
echo ""

# Seed session log
if [ ! -f "$SESSION" ]; then
    echo '[]' > "$SESSION"
fi

BEST_SCORE=0.0
BEST_BRANCH="main"
NO_IMPROVE=0
PATIENCE=2

for iter in $(seq 1 "$MAX_ITER"); do
    echo ""
    echo "=== Iteration $iter ==="
    BRANCH="autoresearch-iter-$iter"
    git checkout -b "$BRANCH" "$BEST_BRANCH" 2>/dev/null || git checkout "$BRANCH"

    # ─── Trial ───────────────────────────────────────────────────
    echo "[TRIAL] Running trial..."
    bash bin/run_trial.sh "$GOAL_FILE" "$MAX_TURNS" "$TRIAL_DIR" > "$TRIAL_DIR/trial.log" 2>&1 || true

    SCORE=0.0
    NOTE="no notebook"
    if [ -f "$TRIAL_DIR/workflow.ipynb" ]; then
        bash bin/evaluate.sh "$TRIAL_DIR/workflow.ipynb" "$GOAL_FILE" "$TRIAL_DIR/evaluation.json" > "$TRIAL_DIR/eval.log" 2>&1 || true
        SCORE=$(jq -r '.scalar_score // 0' "$TRIAL_DIR/evaluation.json" 2>/dev/null || echo "0")
        NOTE=$(jq -r '.justification // ""' "$TRIAL_DIR/evaluation.json" 2>/dev/null | head -c 100)
    fi
    echo "[SCORE] Iteration $iter: $SCORE"
    echo "  $NOTE"

    # Log to session
    python3 -c "
import json, sys
with open('$SESSION') as f:
    session = json.load(f)
session.append({'iteration': $iter, 'branch': '$BRANCH', 'score': float($SCORE), 'goal': '$GOAL_FILE'})
with open('$SESSION', 'w') as f:
    json.dump(session, f, indent=2)
"

    # ─── Mutate ──────────────────────────────────────────────────
    if awk "BEGIN {exit !($SCORE >= 4.0)}"; then
        echo "[SKIP] Score $SCORE >= 4.0, skipping mutation."
        git checkout main
        git branch -D "$BRANCH" 2>/dev/null || true
        continue
    fi

    echo "[MUTATE] Generating mutation plan..."
    bash bin/mutate.sh "$TRIAL_DIR" prompts skills-in-progress "$TRIAL_DIR/evaluation.json" > "$TRIAL_DIR/mutate.log" 2>&1 || true

    if [ -f "$TRIAL_DIR/mutation_plan.json" ]; then
        echo "[MUTATE] Applying mutations..."
        bash bin/apply_mutation.sh "$TRIAL_DIR/mutation_plan.json" > "$TRIAL_DIR/apply.log" 2>&1 || true
        git add -A
        git commit -m "[autoresearch-$iter] mutator scored $SCORE, applied mutations" || true
    else
        echo "[MUTATE] No mutation plan produced."
        git checkout main
        git branch -D "$BRANCH" 2>/dev/null || true
        continue
    fi

    # ─── Validate ────────────────────────────────────────────────
    echo "[VALIDATE] Running validation trial..."
    rm -f "$TRIAL_DIR"/*.md "$TRIAL_DIR"/*.json "$TRIAL_DIR"/*.ipynb
    bash bin/run_trial.sh "$GOAL_FILE" "$MAX_TURNS" "$TRIAL_DIR" > "$TRIAL_DIR/validate.log" 2>&1 || true

    NEW_SCORE=0.0
    if [ -f "$TRIAL_DIR/workflow.ipynb" ]; then
        bash bin/evaluate.sh "$TRIAL_DIR/workflow.ipynb" "$GOAL_FILE" "$TRIAL_DIR/evaluation.json" > "$TRIAL_DIR/validate_eval.log" 2>&1 || true
        NEW_SCORE=$(jq -r '.scalar_score // 0' "$TRIAL_DIR/evaluation.json" 2>/dev/null || echo "0")
    fi
    echo "[VALIDATE] New score: $NEW_SCORE (previous: $SCORE)"

    # ─── Decide ──────────────────────────────────────────────────
    if awk "BEGIN {exit !($NEW_SCORE > $SCORE)}"; then
        echo "[KEEP] Improvement! $SCORE -> $NEW_SCORE"
        BEST_SCORE="$NEW_SCORE"
        BEST_BRANCH="$BRANCH"
        git checkout main
        git merge --no-ff "$BRANCH" -m "[autoresearch-$iter] keep: $SCORE -> $NEW_SCORE" || true
        NO_IMPROVE=0
    else
        echo "[REVERT] No improvement."
        git checkout main
        git branch -D "$BRANCH" 2>/dev/null || true
        NO_IMPROVE=$((NO_IMPROVE + 1))
    fi

    # Early stop
    if [ "$NO_IMPROVE" -ge "$PATIENCE" ]; then
        echo "=== Early stop: no improvement for $PATIENCE iterations ==="
        break
    fi
done

echo ""
echo "=== Autoresearch Complete ==="
echo "Best score: $BEST_SCORE on branch $BEST_BRANCH"
echo "Session: $SESSION"
