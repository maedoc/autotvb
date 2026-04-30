#!/usr/bin/env bash
set -uo pipefail

# run_trial.sh — Single navigator/driver trial
# Usage: run_trial.sh GOAL_FILE [MAX_TURNS] [TRIAL_DIR]

echo "=== TVB Meta-Workflow: Single Trial ==="
GOAL_FILE="${1:-benchmarks/goals/visual_erp.GOAL.md}"
MAX_TURNS="${2:-20}"
TRIAL_DIR="${3:-sandbox}"
mkdir -p "$TRIAL_DIR"

# ─── Discover skills ───────────────────────────────────────────────
# Use keyword filtering based on goal content (falls back to all skills if no match)
SKILL_FLAGS=$(bash bin/filter_skills.sh "$GOAL_FILE" skills-in-progress)
echo "[SKILLS] Loaded: $(echo "$SKILL_FLAGS" | tr '\n' ' ')"

# ─── Model override ────────────────────────────────────────────────
PI_MODEL="${PI_MODEL:-}"
MODEL_FLAG=""
if [ -n "$PI_MODEL" ]; then
    MODEL_FLAG="--model $PI_MODEL"
    echo "[MODEL] Using: $PI_MODEL"
fi
# ─── Conversation state ────────────────────────────────────────────
NAVIGATOR_MSG="$TRIAL_DIR/NAVIGATOR_MESSAGE.md"
DRIVER_MSG="$TRIAL_DIR/DRIVER_MESSAGE.md"
RESULT_NOTEBOOK="$TRIAL_DIR/workflow.ipynb"
EXEC_LOG="$TRIAL_DIR/exec.log"
EXEC_REPORT="$TRIAL_DIR/EXECUTION_REPORT.md"

# Seed first navigator message
cp "$GOAL_FILE" "$TRIAL_DIR/GOAL.md"

cat > "$NAVIGATOR_MSG" << NAVINIT
## Status: planning

I have read the goal below. I will now create a step-by-step plan and then instruct the driver to implement it.

## Goal
$(cat "$GOAL_FILE")

## Next Action for Driver
Read the goal in $TRIAL_DIR/GOAL.md and create a new notebook $RESULT_NOTEBOOK that implements the expected output. Do NOT execute it yet; report what you plan to implement.
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
    DRIVER_OUTPUT=$(timeout 300 pi \
        $MODEL_FLAG \
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
    DRIVER_OUTPUT=$(timeout 300 pi \
        $MODEL_FLAG \
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
    NAVIGATOR_OUTPUT=$(timeout 300 pi \
        $MODEL_FLAG \
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

# ─── EVALUATION ─────────────────────────────────────────────────
if [ -f "$RESULT_NOTEBOOK" ]; then
    echo "[EVAL] Running evaluator..."
    bash bin/evaluate.sh "$RESULT_NOTEBOOK" "$GOAL_FILE" "$TRIAL_DIR/evaluation.json" > "$TRIAL_DIR/eval.log" 2>&1 || true
    if [ -f "$TRIAL_DIR/evaluation.json" ]; then
        score=$(jq -r '.scalar_score // "N/A"' "$TRIAL_DIR/evaluation.json" 2>/dev/null)
        echo "[EVAL] Score: $score"
    else
        echo "[EVAL] Failed — no evaluation.json produced"
    fi
else
    echo "[EVAL] Skipped — no notebook found"
fi
