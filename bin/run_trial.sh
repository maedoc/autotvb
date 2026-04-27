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
# Find all SKILL.md files and convert to --skill flags
SKILL_FLAGS=""
while IFS= read -r skill_md; do
    skill_dir=$(dirname "$skill_md")
    SKILL_FLAGS="$SKILL_FLAGS --skill $skill_dir"
done < <(find skills-in-progress -name 'SKILL.md' | sort)

echo "[SKILLS] Loaded:$(echo $SKILL_FLAGS | sed 's/--skill/\n  -/g')"

# ─── Conversation state ────────────────────────────────────────────
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

# ─── Build base prompts ──────────────────────────────────────────
DRIVER_PROMPT="$(cat prompts/driver/role.md)"
NAVIGATOR_PROMPT="$(cat prompts/navigator/role.md)"

# Turn loop
for turn in $(seq 1 "$MAX_TURNS"); do
    echo ""
    echo "--- Turn $turn ---"

    # DRIVER turn
    echo "[DRIVER] Running..."
    DRIVER_OUTPUT=$(pi \
        --mode text \
        --no-session \
        --tools read,bash,write,edit \
        $SKILL_FLAGS \
        --system-prompt "$DRIVER_PROMPT" \
        -p "NAVIGATOR MESSAGE:\n$(cat $NAVIGATOR_MSG)\n\nYour task: implement or extend the notebook in $RESULT_NOTEBOOK inside $TRIAL_DIR. After writing, execute it and report results to me." \
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
        $SKILL_FLAGS \
        --system-prompt "$NAVIGATOR_PROMPT" \
        -p "DRIVER MESSAGE:\n$(cat $DRIVER_MSG)\n\nGOAL:\n$(cat $TRIAL_DIR/GOAL.md)\n\nYour task: review the driver's output. If the notebook is complete and correct, write TERMINATE to $NAVIGATOR_MSG with a verdict. Otherwise, provide the next step." \
        2>&1 || true)
    echo "$NAVIGATOR_OUTPUT" > "$NAVIGATOR_MSG"

    # Check for TERMINATE from navigator
    if grep -q "TERMINATE" "$NAVIGATOR_MSG" 2>/dev/null; then
        echo "[NAVIGATOR] TERMINATE received after turn $turn"
        break
    fi
done

# Summarize
echo ""
echo "=== Trial complete ==="
echo "Notebook: $RESULT_NOTEBOOK"
echo "Navigator final message: $NAVIGATOR_MSG"
echo "Driver final message: $DRIVER_MSG"
echo "Turns used: $turn"
