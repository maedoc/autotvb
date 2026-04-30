#!/usr/bin/env bash
# overnight_batch.sh — Fresh full sweep over ALL goals (existing + research)
# Uses background jobs + wait -n for true 2-worker concurrency.
# Usage: PI_MODEL=ollama/kimi-k2.6:cloud bash bin/overnight_batch.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_DIR"

BATCH_DIR="$REPO_DIR/sandbox/batch_all_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BATCH_DIR"

# ─── ALL GOALS ────────────────────────────────────────────────────
EXISTING_GOALS=($(find benchmarks/goals -name '*.GOAL.md' | sort))
RESEARCH_GOALS=($(find benchmarks/goals_research -name '*.GOAL.md' | sort))
ALL_GOALS=("${EXISTING_GOALS[@]}" "${RESEARCH_GOALS[@]}")

echo "=== Fresh Full Sweep ==="
echo "Existing goals: ${#EXISTING_GOALS[@]}"
echo "Research goals: ${#RESEARCH_GOALS[@]}"
echo "Total: ${#ALL_GOALS[@]}"
echo "Batch dir: $BATCH_DIR"
echo ""

# Generate safe names
NAMES=()
for goal in "${ALL_GOALS[@]}"; do
    base=$(basename "$goal" .GOAL.md)
    safe=$(echo "$base" | sed 's/-/_/g' | cut -c1-30)
    NAMES+=("$safe")
done

GLOBAL_TIMEOUT=7200
PI_MODEL="${PI_MODEL:-ollama/kimi-k2.6:cloud}"
export PI_MODEL
echo "Model: $PI_MODEL"

MAX_TURNS=3
MAX_CONCURRENT="${MAX_CONCURRENT:-4}"
echo "Max turns: $MAX_TURNS"
echo "Workers: $MAX_CONCURRENT"
echo ""

# Track background PIDs for concurrency
PIDS=()

for i in "${!ALL_GOALS[@]}"; do
    goal="${ALL_GOALS[$i]}"
    name="${NAMES[$i]}"
    dir="$BATCH_DIR/$name"
    mkdir -p "$dir"
    cp "$goal" "$dir/GOAL.md"
    
    # Launch trial in background, capture PID
    (
        PI_MODEL="$PI_MODEL" timeout $GLOBAL_TIMEOUT bash bin/run_trial.sh "$goal" $MAX_TURNS "$dir" > "$dir/trial.log" 2>&1
        echo "=== BATCH_TRIAL_DONE status=$? ===" >> "$dir/trial.log"
    ) &
    pid=$!
    PIDS+=("$pid")
    echo "Launched [$((i+1))/${#ALL_GOALS[@]}] $name (pid: $pid)"
    
    # $MAX_CONCURRENT-worker limit
    if [ "${#PIDS[@]}" -ge "$MAX_CONCURRENT" ]; then
        wait -n
        # Remove finished PIDs
        NEWPIDS=()
        for p in "${PIDS[@]}"; do
            if kill -0 "$p" 2>/dev/null; then
                NEWPIDS+=("$p")
            fi
        done
        PIDS=("${NEWPIDS[@]}")
    fi
done

# Wait for remaining
echo ""
echo "Waiting for ${#PIDS[@]} remaining trials..."
for p in "${PIDS[@]}"; do
    wait "$p"
done

echo ""
echo "All ${#ALL_GOALS[@]} trials completed."
echo "Poll with: bash bin/poll_batch.sh $BATCH_DIR"
echo ""

# Batch metadata
{
    echo '{'
    echo "  \"batch_type\": \"full_sweep\","
    echo "  \"timestamp\": \"$(date -Iseconds)\","
    echo "  \"goals_count\": ${#ALL_GOALS[@]},"
    echo "  \"existing_count\": ${#EXISTING_GOALS[@]},"
    echo "  \"research_count\": ${#RESEARCH_GOALS[@]},"
    echo "  \"max_turns\": $MAX_TURNS,"
    echo "  \"timeout_seconds\": $GLOBAL_TIMEOUT,"
    echo "  \"git_commit\": \"$(git rev-parse --short HEAD)\""
    echo '}'
} > "$BATCH_DIR/batch.json"

echo "Batch metadata: $BATCH_DIR/batch.json"
