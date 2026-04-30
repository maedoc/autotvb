#!/usr/bin/env bash
# watch_batch.sh — Background poller for batch status
# Usage: bash watch_batch.sh <batch_dir>
# Writes to <batch_dir>/poll.log every 15 minutes

BATCH_DIR="${1:-$(ls -td sandbox/batch_all_*/ | head -n1)}"
POLL_LOG="$BATCH_DIR/poll.log"
mkdir -p "$BATCH_DIR"

echo "=== Batch watcher started: $(date -Iseconds) ===" >> "$POLL_LOG"
echo "Watching: $BATCH_DIR" >> "$POLL_LOG"
echo "" >> "$POLL_LOG"

while true; do
    done=$(grep -rl "BATCH_TRIAL_DONE" "$BATCH_DIR"/*/trial.log 2>/dev/null | wc -l)
    total=$(ls -1 "$BATCH_DIR" | wc -l)
    evaluated=$(find "$BATCH_DIR" -name "evaluation.json" | wc -l)
    
    # Check if orchestrator still running
    if pgrep -f "overnight_batch.sh" >/dev/null; then
        orch="RUNNING"
    else
        orch="STOPPED"
    fi
    
    timestamp=$(date +%H:%M:%S)
    
    # Build summary line
    echo "[$timestamp] Done=$done | Started=$total | Eval=$evaluated | Orch=$orch" >> "$POLL_LOG"
    
    # List scores for newly evaluated
    for dir in "$BATCH_DIR"/*/; do
      if [ -f "$dir/evaluation.json" ]; then
        name=$(basename "$dir")
        score=$(jq -r '.scalar_score // "N/A"' "$dir/evaluation.json" 2>/dev/null)
        fb=$(jq -r '.fallback // false' "$dir/evaluation.json" 2>/dev/null)
        if [ "$fb" = "true" ]; then
          echo "  $name: FB($score)" >> "$POLL_LOG"
        else
          echo "  $name: $score" >> "$POLL_LOG"
        fi
      fi
    done | sort >> "$POLL_LOG"
    
    # Count running trials
    running=0
    for dir in "$BATCH_DIR"/*/; do
      if [ -f "$dir/trial.log" ] && ! tail -n1 "$dir/trial.log" 2>/dev/null | grep -q "BATCH_TRIAL_DONE"; then
        ((running++))
      fi
    done
    if [ "$running" -gt 0 ]; then
      echo "  [$running trials running]" >> "$POLL_LOG"
    fi
    
    echo "" >> "$POLL_LOG"
    
    # If orchestrator stopped and all evaluated, exit
    if [ "$orch" = "STOPPED" ] && [ "$evaluated" -eq "$done" ] && [ "$total" -gt 0 ]; then
        echo "=== Batch finished at $(date -Iseconds) ===" >> "$POLL_LOG"
        break
    fi
    
    sleep 900
done
