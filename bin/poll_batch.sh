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
import json, sys, os
batch_json = os.path.join('$BATCH_DIR', 'batch.json')
if os.path.exists(batch_json):
    with open(batch_json) as f:
        d = json.load(f)
    if 'goals' in d:
        print(' '.join([g['name'] for g in d['goals']]))
    else:
        subs = [x for x in os.listdir('$BATCH_DIR') if os.path.isdir(os.path.join('$BATCH_DIR',x)) and not x.startswith('.') and x != 'batch.json']
        print(' '.join(subs))
else:
    subs = [x for x in os.listdir('$BATCH_DIR') if os.path.isdir(os.path.join('$BATCH_DIR',x)) and not x.startswith('.') and x != 'batch.json']
    print(' '.join(subs))
"))

poll_once() {
    echo ""
    echo "=== Batch Poll $(date '+%Y-%m-%d %H:%M:%S') ==="
    echo "Batch: $BATCH_DIR"
    echo ""
    
    completed=0
    total=${#NAMES[@]}
    
    # Check for Docker batch
    is_docker=false
    if python3 -c "import json, os; p=os.path.join('$BATCH_DIR','batch.json'); print(d.get('image','')) if os.path.exists(p) else ''" 2>/dev/null | grep -q autotvb; then
        is_docker=true
    fi
    
    if [ "$is_docker" = true ]; then
        printf "%-12s %-10s %-8s %-8s %-8s %-10s %-15s %s\n" "Goal" "Notebook" "Turns" "Message" "Exec" "Status" "Container" "Notes"
    else
        printf "%-12s %-10s %-8s %-8s %-8s %-10s %s\n" "Goal" "Notebook" "Turns" "Message" "Exec" "Status" "Notes"
    fi
    echo "--------------------------------------------------------------------------------"
    
    for name in "${NAMES[@]}"; do
        dir="$BATCH_DIR/$name"
        nb="$([ -f \"$dir/workflow.ipynb\" ] && echo $(wc -c <"$dir/workflow.ipynb") || echo 0)"
        msg="$([ -f \"$dir/DRIVER_MESSAGE.md\" ] && echo $(wc -c <"$dir/DRIVER_MESSAGE.md") || echo 0)"
        exec="$([ -f \"$dir/EXECUTION_REPORT.md\" ] && echo $(wc -c <"$dir/EXECUTION_REPORT.md") || echo 0)"
        turns=$(grep -c "Turn [0-9]" "$dir/trial.log" 2>/dev/null || echo 0)
        status="running"
        notes=""
        container_status=""
        
        if grep -q "BATCH_TRIAL_DONE" "$dir/trial.log" 2>/dev/null; then
            status="COMPLETED"
            completed=$((completed + 1))
            if [ "$nb" -gt 0 ] && [ "$exec" -gt 0 ]; then
                exec_status=$(head -n2 "$dir/EXECUTION_REPORT.md" 2>/dev/null | grep -o "Success\|Error" || echo "?")
                notes="exec=$exec_status"
            elif [ "$nb" -gt 0 ]; then
                notes="nb ok, no exec log"
            else
                notes="no notebook"
            fi
        elif grep -qi "TERMINATE" "$dir/NAVIGATOR_MESSAGE.md" "$dir/DRIVER_MESSAGE.md" 2>/dev/null; then
            status="TERMINATED"
            completed=$((completed + 1))
            notes="early terminate"
        fi
        
        if [ "$is_docker" = true ]; then
            container=$(docker ps --filter "name=autotvb-$name" --format "{{.Names}}:{{.Status}}" 2>/dev/null | grep -v "^$" | head -n1)
            if [ -n "$container" ]; then
                container_status="$container"
                notes="container active"
            elif [ "$status" != "COMPLETED" ]; then
                container_status="exited"
            fi
        fi
        
        if [ "$nb" -gt 0 ]; then
            nb_str="yes"
        else
            nb_str="no"
        fi
        
        if [ "$is_docker" = true ]; then
            printf "%-12s %-10s %-8s %-8s %-8s %-10s %-15s %s\n" "${name:0:12}" "$nb_str" "$turns" "$msg" "$exec" "$status" "${container_status:0:15}" "$notes"
        else
            printf "%-12s %-10s %-8s %-8s %-8s %-10s %s\n" "${name:0:12}" "$nb_str" "$turns" "$msg" "$exec" "$status" "$notes"
        fi
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
