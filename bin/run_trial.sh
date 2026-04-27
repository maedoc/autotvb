#!/usr/bin/env bash
set -euo pipefail

# run_trial.sh — Single navigator/driver trial
# Usage: run_trial.sh GOAL_FILE [MAX_TURNS] [TRIAL_DIR]

echo "=== TVB Meta-Workflow: Single Trial ==="
GOAL_FILE="${1:-benchmarks/goals/visual_erp.GOAL.md}"
MAX_TURNS="${2:-20}"
TRIAL_DIR="${3:-sandbox}"
mkdir -p "$TRIAL_DIR"

# ─── Discover skills ───────────────────────────────────────────────
SKILL_FLAGS=""
while IFS= read -r skill_md; do
    skill_dir=$(dirname "$skill_md")
    SKILL_FLAGS="$SKILL_FLAGS --skill $skill_dir"
done < <(find skills-in-progress -name 'SKILL.md' | sort)

echo "[SKILLS] Loaded: $(echo "$SKILL_FLAGS" | tr '\n' ' ')"

# ─── Conversation state ────────────────────────────────────────────
NAVIGATOR_MSG="$TRIAL_DIR/NAVIGATOR_MESSAGE.md"
DRIVER_MSG="$TRIAL_DIR/DRIVER_MESSAGE.md"
RESULT_NOTEBOOK="$TRIAL_DIR/workflow.ipynb"
EXEC_LOG="$TRIAL_DIR/exec.log"
EXEC_REPORT="$TRIAL_DIR/EXECUTION_REPORT.md"

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

# ─── Build base prompts ──────────────────────────────────────────
DRIVER_PROMPT="$(cat prompts/driver/role.md)

IMPORTANT ENVIRONMENT NOTE:
- TVB is installed in a Python venv at /tmp/tvb_env.
- Before executing any TVB code, run: source /tmp/tvb_env/bin/activate
- If TVB import fails, activate the venv first.
- Do NOT execute the notebook inside the same pi turn that writes it. Write first, then wait for execution results."
NAVIGATOR_PROMPT="$(cat prompts/navigator/role.md)"

# ─── Helper: execute notebook locally ──────────────────────────────
execute_notebook() {
    local nb="$1"
    local out="$2"
    if [ ! -f "$nb" ]; then
        echo "NOTEBOOK MISSING" > "$out"
        return 1
    fi
    local nb_abs="$(realpath "$nb")"
    local out_nb="$(dirname "$nb_abs")/$(basename "${nb%.ipynb}_executed.ipynb")"
    (
        source /tmp/tvb_env/bin/activate
        python3 -m nbconvert --ExecutePreprocessor.timeout=180 --to notebook \
            --execute "$nb_abs" \
            --output "$out_nb" \
            2>> "$out"
    ) || true
    echo "--- Execution finished at $(date -Iseconds) ---" >> "$out"
}

# Turn loop
for turn in $(seq 1 "$MAX_TURNS"); do
    echo ""
    echo "--- Turn $turn ---"

    # ─── DRIVER WRITE turn ─────────────────────────────────────────
    echo "[DRIVER] Writing notebook..."
    DRIVER_OUTPUT=$(pi \
        --mode text \
        --no-session \
        --tools read,bash,write,edit \
        $SKILL_FLAGS \
        --system-prompt "$DRIVER_PROMPT" \
        -p "NAVIGATOR MESSAGE:\n$(cat $NAVIGATOR_MSG)\n\nYour task: implement or extend the notebook in $RESULT_NOTEBOOK inside $TRIAL_DIR. After writing the notebook, do NOT execute it. Instead, report what you wrote, what changed, and any concerns." \
        2>&1 || true)
    echo "$DRIVER_OUTPUT" > "$DRIVER_MSG"

    # Check for TERMINATE from driver
    if grep -q "TERMINATE" "$DRIVER_MSG" 2>/dev/null; then
        echo "[DRIVER] requested TERMINATE"
        break
    fi

    # ─── LOCAL EXECUTION ──────────────────────────────────────────
    echo "[EXEC] Running notebook with TVB venv..."
    > "$EXEC_LOG"
    execute_notebook "$RESULT_NOTEBOOK" "$EXEC_LOG"

    # Build execution report
    EXEC_STATUS="Success"
    if grep -qi "error\|traceback\|exception" "$EXEC_LOG" 2>/dev/null; then
        EXEC_STATUS="Error"
    fi

    cat > "$EXEC_REPORT" <<EOF
## Execution Status
$EXEC_STATUS

## Log
$(cat "$EXEC_LOG" 2>/dev/null | tail -100)

## Next Action
If Error: fix the notebook. If Success: verify outputs are correct.
EOF

    # ─── DRIVER FIX/REPORT turn ──────────────────────────────────
    echo "[DRIVER] Reviewing execution results..."
    DRIVER_OUTPUT=$(pi \
        --mode text \
        --no-session \
        --tools read,bash,write,edit \
        $SKILL_FLAGS \
        --system-prompt "$DRIVER_PROMPT" \
        -p "NAVIGATOR MESSAGE:\n$(cat $NAVIGATOR_MSG)\n\nYOUR PREVIOUS DRIVER MESSAGE:\n$(cat $DRIVER_MSG)\n\nEXECUTION REPORT:\n$(cat $EXEC_REPORT)\n\nYour task: fix any errors in $RESULT_NOTEBOOK, or if execution succeeded, confirm completion. Report results." \
        2>&1 || true)
    echo "$DRIVER_OUTPUT" > "$DRIVER_MSG"

    # ─── NAVIGATOR turn ──────────────────────────────────────────
    echo "[NAVIGATOR] Running..."
    NAVIGATOR_OUTPUT=$(pi \
        --mode text \
        --no-session \
        --tools read,bash \
        $SKILL_FLAGS \
        --system-prompt "$NAVIGATOR_PROMPT" \
        -p "DRIVER MESSAGE:\n$(cat $DRIVER_MSG)\n\nGOAL:\n$(cat $TRIAL_DIR/GOAL.md)\n\nYour task: review the driver's output. If the notebook is complete and correct, write TERMINATE to $NAVIGATOR_MSG with a verdict. Otherwise, provide the next step." \
        2>&1 || true)
    echo "$NAVIGATOR_OUTPUT" > "$NAVIGATOR_MSG"

    if grep -q "TERMINATE" "$NAVIGATOR_MSG" 2>/dev/null; then
        echo "[NAVIGATOR] TERMINATE received after turn $turn"
        break
    fi
done

echo ""
echo "=== Trial complete ==="
echo "Notebook: $RESULT_NOTEBOOK"
echo "Navigator final message: $NAVIGATOR_MSG"
echo "Driver final message: $DRIVER_MSG"
echo "Turns used: $turn"
