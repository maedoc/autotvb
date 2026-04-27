#!/usr/bin/env bash
set -euo pipefail

# orchestrator.sh — Proper autoresearch outer loop for navigator/driver evolution
cd "$(dirname "$0")/.."

# ─── Session Files ─────────────────────────────────────────────────
SESSION_MD="benchmarks/autoresearch.md"
SESSION_JSONL="benchmarks/autoresearch.jsonl"
SCORES_JSONL="benchmarks/scores.jsonl"

# ─── Configuration ─────────────────────────────────────────────────
VALIDATION_GOALS=(
    "benchmarks/goals/visual_erp.GOAL.md"
    "benchmarks/goals/tutorial_s5_modelingrestingstatenetworks.GOAL.md"
    "benchmarks/goals/tutorial_s6_modelingepilepsy.GOAL.md"
)
MAX_ITERATIONS="${1:-20}"
PATIENCE="${2:-5}"          # Stop if no improvement for N iterations
BEST_SCORE="0.0"
BEST_BRANCH="main"
PROMPT_DIR="prompts"
SKILL_DIR="skills-in-progress"

# Candidate files that may be mutated (one per iteration)
MUTATION_TARGETS=(
    "$PROMPT_DIR/navigator/role.md"
    "$PROMPT_DIR/driver/role.md"
    "$SKILL_DIR/navigator/SKILL.md"
    "$SKILL_DIR/driver/SKILL.md"
)

# ─── Helpers ───────────────────────────────────────────────────────
init_session() {
    if [ -f "$SESSION_JSONL" ]; then
        echo "=== Resuming from existing session ==="
        BEST_SCORE=$(jq -sr 'map(.scalar_score) | max' "$SESSION_JSONL" 2>/dev/null || echo "0.0")
        return
    fi
    mkdir -p "$(dirname "$SESSION_MD")"
    cat > "$SESSION_MD" <<EOF
# Autoresearch Session

Goal: Optimize navigator/driver prompts and skills for TVB workflow generation.
Benchmark: Average scalar score across $((${#VALIDATION_GOALS[@]})) validation goals.
Fitness: higher is better.

## Baseline
$(for g in "${VALIDATION_GOALS[@]}"; do echo "- $(basename $g)"; done)
EOF
    echo '{"event":"init","timestamp":"'$(date -Iseconds)'","validation_goals":'$(printf '%s\n' "${VALIDATION_GOALS[@]}" | jq -R . | jq -s .)'}' >> "$SESSION_JSONL"
}

log_event() {
    local iter="$1" branch="$2" target="$3" summary="$4" score="$5" action="$6"
    jq -n \
        --arg iter "$iter" \
        --arg branch "$branch" \
        --arg target "$target" \
        --arg summary "$summary" \
        --arg score "$score" \
        --arg action "$action" \
        --arg ts "$(date -Iseconds)" \
        '{iteration: ($iter|tonumber), branch: $branch, mutated: $target, mutation_summary: $summary, scalar_score: ($score|tonumber), action: $action, timestamp: $ts}' \
        >> "$SESSION_JSONL"
}

pick_mutation_target() {
    # Cycle through targets deterministically, one per iteration
    local idx=$(( ($1 - 1) % ${#MUTATION_TARGETS[@]} ))
    echo "${MUTATION_TARGETS[$idx]}"
}

compute_fitness() {
    # Run the validation set and average scores
    local tmpdir="$1"
    local total=0
    local count=0
    for goal in "${VALIDATION_GOALS[@]}"; do
        local goal_name=$(basename "$goal" .GOAL.md)
        local trial_dir="$tmpdir/$goal_name"
        bash bin/run_trial.sh "$goal" 20 "$trial_dir" > "$trial_dir/orchestrator.log" 2>&1 || true
        bash bin/evaluate.sh "$trial_dir/workflow.ipynb" "$goal" "$trial_dir/evaluation.json" > "$trial_dir/evaluate.log" 2>&1 || true
        local s=$(jq -r '.scalar_score // 0' "$trial_dir/evaluation.json" 2>/dev/null || echo "0")
        total=$(awk "BEGIN {print $total + $s}")
        count=$((count + 1))
        echo '{"goal":"'$goal_name'","score":'$s',"trial":"'$trial_dir'"}' >> "$tmpdir/validation_details.jsonl"
    done
    awk "BEGIN {printf \"%.3f\", $total / $count}"
}

# ─── Init ──────────────────────────────────────────────────────────
init_session
ITERATION=0
NO_IMPROVE_COUNT=0

while true; do
    ITERATION=$((ITERATION + 1))
    if [ "$ITERATION" -gt "$MAX_ITERATIONS" ]; then
        echo "=== Max iterations ($MAX_ITERATIONS) reached ==="
        break
    fi

    echo ""
    echo "=== Autoresearch Iteration $ITERATION ==="

    # 1. Create branch
    BRANCH="autoresearch-$ITERATION"
    git checkout -b "$BRANCH" "$BEST_BRANCH" 2>/dev/null || git checkout "$BRANCH"

    # 2. Pick and mutate ONE target
    TARGET_FILE=$(pick_mutation_target "$ITERATION")
    TARGET_NAME=$(basename "$TARGET_FILE")
    echo "[MUTATE] Target: $TARGET_FILE"
    
    # Run mutation agent
    bash bin/mutate.sh sandbox "$PROMPT_DIR" "$SKILL_DIR" "sandbox/evaluation.json" > "sandbox/mutation_$ITERATION.log" 2>&1 || true
    
    MUTATION_SUMMARY=$(head -c 200 sandbox/mutation_plan.md 2>/dev/null || echo "no_plan")
    
    # Apply the top diff from mutation_plan.md (naive: look for "→" or code blocks)
    # In practice the mutation agent should use edit tool; we just check if files changed
    if git diff --quiet; then
        echo "[SKIP] No mutation applied. Trying random prompt injection."
        # Fallback: inject a small random instruction at end of target file
        echo "" >> "$TARGET_FILE"
        echo "<!-- mutation-$ITERATION: added random instruction -->" >> "$TARGET_FILE"
        echo "Always include a progress check after each simulation step." >> "$TARGET_FILE"
        MUTATION_SUMMARY="fallback: added progress-check instruction to $TARGET_NAME"
    fi

    git add -A
    git commit -m "[autoresearch-$ITERATION] mutate $TARGET_NAME" || true

    # 3. Benchmark: run validation set
    TMPDIR=$(mktemp -d)
    CURRENT_SCORE=$(compute_fitness "$TMPDIR")
    rm -rf "$TMPDIR"
    echo "[SCORE] Iteration $ITERATION: $CURRENT_SCORE (best: $BEST_SCORE)"

    # 4. Decide: keep or revert
    if awk "BEGIN {exit !($CURRENT_SCORE > $BEST_SCORE)}"; then
        echo "[KEEP] New best!"
        BEST_SCORE="$CURRENT_SCORE"
        BEST_BRANCH="$BRANCH"
        git checkout main 2>/dev/null || true
        git merge --no-ff "$BRANCH" -m "[autoresearch-$ITERATION] score=$CURRENT_SCORE keep $TARGET_NAME"
        log_event "$ITERATION" "$BRANCH" "$TARGET_NAME" "$MUTATION_SUMMARY" "$CURRENT_SCORE" "keep"
        NO_IMPROVE_COUNT=0
    else
        echo "[REVERT] No improvement."
        git checkout main 2>/dev/null || true
        git branch -D "$BRANCH" 2>/dev/null || true
        log_event "$ITERATION" "$BRANCH" "$TARGET_NAME" "$MUTATION_SUMMARY" "$CURRENT_SCORE" "revert"
        NO_IMPROVE_COUNT=$((NO_IMPROVE_COUNT + 1))
    fi

    echo '{"iteration":'$ITERATION',"current_score":'$CURRENT_SCORE',"best_score":'$BEST_SCORE',"no_improve_count":'$NO_IMPROVE_COUNT'}' >> "$SCORES_JSONL"

    # 5. Convergence check
    if [ "$NO_IMPROVE_COUNT" -ge "$PATIENCE" ]; then
        echo "=== Early stopping: no improvement for $PATIENCE iterations ==="
        break
    fi
done

echo ""
echo "=== Autoresearch Complete ==="
echo "Best score: $BEST_SCORE on branch $BEST_BRANCH"
echo "Session: $SESSION_JSONL"
echo "Dashboard: $SESSION_MD"
