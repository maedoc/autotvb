#!/usr/bin/env bash
# poll_batch.sh — Poll overnight batch status
# Usage: poll_batch.sh BATCH_DIR [INTERVAL_SECONDS]

BATCH_DIR="${1:-sandbox/batch_research_latest}"
INTERVAL="${2:-1800}"  # 30 minutes

if [ ! -d "$BATCH_DIR" ]; then
    echo "ERROR: Batch directory not found: $BATCH_DIR"
    exit 1
fi

NAMES=($(python3 -c "
import json
with open('$BATCH_DIR/batch.json') as f:
    d = json.load(f)
    print(' '.join([g['name'] for g in d['goals']]))
"))

poll_once() {
    echo ""
    echo "=== Batch Poll $(date '+%Y-%m-%d %H:%M:%S') ==="
    echo "Batch: $BATCH_DIR"
    echo ""
    
    completed=0
    total=${#NAMES[@]}
    
    printf "%-12s %-10s %-8s %-8s %-8s %-10s %s\n" "Goal" "Notebook" "Turns" "Message" "Exec" "Status" "Notes"
    echo "--------------------------------------------------------------------------------"
    
    for name in "${NAMES[@]}"; do
        dir="$BATCH_DIR/$name"
        nb="$([ -f "$dir/workflow.ipynb" ] && echo $(wc -c <"$dir/workflow.ipynb") || echo 0)"
        msg="$([ -f "$dir/DRIVER_MESSAGE.md" ] && echo $(wc -c <"$dir/DRIVER_MESSAGE.md") || echo 0)"
        exec="$([ -f "$dir/EXECUTION_REPORT.md" ] && echo $(wc -c <"$dir/EXECUTION_REPORT.md") || echo 0)"
        turns=$(grep -c "Turn [0-9]" "$dir/trial.log" 2>/dev/null || echo 0)
        status="running"
        notes=""
        
        if grep -q "BATCH_TRIAL_DONE" "$dir/trial.log" 2>/dev/null; then
            status="COMPLETED"
            completed=$((completed + 1))
            if [ "$nb" -gt 0 ] && [ "$exec" -gt 0 ]; then
                exec_status=$(head -n2 "$dir/EXECUTION_REPORT.md" 2>/dev/null | grep -o "Success\|Error" || echo "?")
                notes="exec=$exec_status"
            else
                notes="no notebook"
            fi
        elif grep -qi "TERMINATE" "$dir/NAVIGATOR_MESSAGE.md" "$dir/DRIVER_MESSAGE.md" 2>/dev/null; then
            status="TERMINATED"
            completed=$((completed + 1))
            notes="early terminate"
        fi
        
        if [ "$nb" -gt 0 ]; then
            nb_str="yes"
        else
            nb_str="no"
        fi
        
        printf "%-12s %-10s %-8s %-8s %-8s %-10s %s\n" "$name" "$nb_str" "$turns" "$msg" "$exec" "$status" "$notes"
    done
    
    echo ""
    echo "Progress: $completed / $total trials ($(( 100 * completed / total ))%)"
    
    if [ "$completed" -eq "$total" ]; then
        echo "ALL TRIALS COMPLETE"
        return 1  # signal to stop polling
    fi
    return 0
}

# Single poll mode (for manual check)
if [ "$INTERVAL" = "once" ]; then
    poll_once
    exit 0
fi

# Continuous poll mode
echo "Polling every ${INTERVAL}s. Press Ctrl+C to stop."
while true; do
    poll_once
    if [ $? -ne 0 ]; then break; fi
    echo "Next poll in ${INTERVAL}s..."
    sleep "$INTERVAL"
done

echo ""
echo "Batch complete! Run evaluation:"
echo "  for d in $BATCH_DIR/*/; do bash bin/evaluate.sh \$d/workflow.ipynb \$d/GOAL.md \$d/evaluation.json; done"
