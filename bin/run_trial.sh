#!/usr/bin/env bash
set -euo pipefail

# run_trial.sh — Single navigator/driver trial
echo "=== TVB Meta-Workflow: Single Trial ==="
GOAL_FILE="${1:-benchmarks/goals/visual_erp.GOAL.md}"
MAX_TURNS="${2:-20}"
TRIAL_DIR="${3:-sandbox}"
mkdir -p "$TRIAL_DIR"

# Initialize conversation state
NAVIGATOR_MSG="$TRIAL_DIR/NAVIGATOR_MESSAGE.md"
DRIVER_MSG="$TRIAL_DIR/DRIVER_MESSAGE.md"
RESULT_NOTEBOOK="$TRIAL_DIR/workflow.ipynb"

# Seed first navigator message
cp "$GOAL_FILE" "$TRIAL_DIR/GOAL.md"

cat > "$NAVIGATOR_MSG" << 'NAVINIT'
## Status: planning

## Step-by-step Plan
1. Set up imports and connectivity
2. Configure Generic2dOscillator in stable spiral regime (10 Hz)
3. Define V1/V2 stimulus with PulseTrain
4. Configure HeunStochastic integrator with low noise
5. Run simulation, record temporal average
6. Plot time series highlighting evoked response
7. Validate output addresses the scientific question

## Next Action for Driver
Create a new notebook `workflow.ipynb` implementing steps 1–3 above. 
Use the default 76-region connectivity. Target regions 35 (V1) and optionally 36 (V2).
Stimulus: onset 500ms, tau 5ms. Integrator dt = 2**-6.
NAVINIT

# Turn loop
for turn in $(seq 1 "$MAX_TURNS"); do
    echo "--- Turn $turn ---"

    # DRIVER turn
    echo "[DRIVER] Running..."
    DRIVER_OUTPUT=$(pi \
        --mode text \
        --no-session \
        --tools read,bash,write,edit \
        -p "$(cat prompts/driver/role.md)\n\n---\nNAVIGATOR MESSAGE:\n$(cat $NAVIGATOR_MSG)\n\n---\nYour task: implement or extend the notebook in $RESULT_NOTEBOOK inside $TRIAL_DIR. After writing, execute it and report results." \
        2>&1 || true)
    echo "$DRIVER_OUTPUT" > "$DRIVER_MSG"

    # Check for TERMINATE from driver (unlikely, but possible)
    if grep -q "TERMINATE" "$DRIVER_MSG" 2>/dev/null; then
        echo "[DRIVER] requested TERMINATE"
        break
    fi

    # NAVIGATOR turn
    echo "[NAVIGATOR] Running..."
    NAVIGATOR_OUTPUT=$(pi \
        --mode text \
        --no-session \
        --tools read,bash \
        -p "$(cat prompts/navigator/role.md)\n\n---\nDRIVER MESSAGE:\n$(cat $DRIVER_MSG)\n\n---\nGOAL:\n$(cat $TRIAL_DIR/GOAL.md)\n\n---\nYour task: review the driver's output. If the notebook is complete and correct, write TERMINATE to $NAVIGATOR_MSG with a verdict. Otherwise, provide the next step." \
        2>&1 || true)
    echo "$NAVIGATOR_OUTPUT" > "$NAVIGATOR_MSG"

    # Check for TERMINATE from navigator
    if grep -q "TERMINATE" "$NAVIGATOR_MSG" 2>/dev/null; then
        echo "[NAVIGATOR] TERMINATE received after turn $turn"
        break
    fi
done

# Summarize
echo "=== Trial complete ==="
echo "Notebook: $RESULT_NOTEBOOK"
echo "Navigator final message: $NAVIGATOR_MSG"
echo "Driver final message: $DRIVER_MSG"
