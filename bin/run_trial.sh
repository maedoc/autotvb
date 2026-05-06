#!/usr/bin/env bash
set -uo pipefail

# run_trial.sh — Single navigator/driver trial
# Usage: run_trial.sh GOAL_FILE [MAX_TURNS] [TRIAL_DIR]

echo "=== TVB Meta-Workflow: Single Trial ==="
GOAL_FILE="${1:-benchmarks/goals/visual_erp.GOAL.md}"
MAX_TURNS="${2:-20}"
MAX_FIX_RETRIES="${MAX_FIX_RETRIES:-2}"
TRIAL_DIR="${3:-sandbox}"
mkdir -p "$TRIAL_DIR"

# ─── Discover skills ───────────────────────────────────────────────
if [ "${NO_SKILLS:-0}" = "1" ]; then
    SKILL_FLAGS=""
    echo "[SKILLS] DISABLED (NO_SKILLS=1)"
elif [ -n "${SKILL_FLAGS_OVERRIDE:-}" ]; then
    SKILL_FLAGS="$SKILL_FLAGS_OVERRIDE"
    echo "[SKILLS] Override: $(echo "$SKILL_FLAGS" | grep -o '\-\-skill [^ ]*' | wc -l) skills"
else
    # Use keyword filtering based on goal content (falls back to all skills if no match)
    SKILL_FLAGS=$(bash bin/filter_skills.sh "$GOAL_FILE" skills-in-progress)
    echo "[SKILLS] Loaded: $(echo "$SKILL_FLAGS" | tr '\n' ' ')"
fi

# ─── Model override ────────────────────────────────────────────────
PI_MODEL="${PI_MODEL:-}"
if [ -n "$PI_MODEL" ]; then
    echo "[MODEL] Using: $PI_MODEL (via env var)"
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

# ─── Prompt variant selection ─────────────────────────────────────
PROMPT_VARIANT="${PROMPT_VARIANT:-default}"
DRIVER_ROLE="prompts/driver/role.md"
NAVIGATOR_ROLE="prompts/navigator/role.md"
if [ "$PROMPT_VARIANT" = "zero_shot" ]; then
    DRIVER_ROLE="prompts/driver/role_zero_shot.md"
    echo "[PROMPT] Using ZERO-SHOT driver prompt (no TVB API rules)"
elif [ "$PROMPT_VARIANT" = "one_shot" ]; then
    DRIVER_ROLE="prompts/driver/role_zero_shot.md"
    echo "[PROMPT] Using ONE-SHOT driver prompt (zero-shot + reference notebook)"
fi

# ─── One-shot reference notebook injection ───────────────────────
ONE_SHOT_NOTE=""
if [ "${ONE_SHOT:-0}" = "1" ]; then
    GOAL_BASENAME="$(basename "$GOAL_FILE" .GOAL.md)"
    # Try to find a reference notebook
    REF_NB="benchmarks/reference_notebooks/${GOAL_BASENAME}.ipynb"
    # Fallback: use any existing with_skills notebook from batch3
    if [ ! -f "$REF_NB" ]; then
        BATCH3_DIR="sandbox/batch_all_20260503_175853"
        HYP="$(echo "$GOAL_BASENAME" | tr '_' '-')"
        FALLBACK="${BATCH3_DIR}/${HYP}/workflow.ipynb"
        [ -f "$FALLBACK" ] && REF_NB="$FALLBACK"
    fi
    if [ -f "$REF_NB" ]; then
        ONE_SHOT_NOTE="\n\n## Reference Notebook\nYou may examine ${REF_NB} for a working example of a TVB notebook structure, but you must write your OWN implementation for THIS specific goal. Do NOT copy the reference verbatim; adapt it to the current goal."
        echo "[ONE_SHOT] Reference: $REF_NB"
    else
        echo "[ONE_SHOT] WARNING: No reference notebook found for $GOAL_BASENAME"
    fi
fi

# ─── Build base prompts ──────────────────────────────────────────
DRIVER_PROMPT_BASE=$(cat "$DRIVER_ROLE")
DRIVER_PROMPT="${DRIVER_PROMPT_BASE}

IMPORTANT ENVIRONMENT NOTE:
- TVB is installed in a Python venv at /tmp/tvb_env.
- Before executing any TVB code, run: source /tmp/tvb_env/bin/activate
- If TVB import fails, activate the venv first.
- Do NOT execute the notebook inside the same pi turn that writes it. Write first, then wait for execution results.${ONE_SHOT_NOTE}"
NAVIGATOR_PROMPT=$(cat "$NAVIGATOR_ROLE")

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
        source "${TVB_ENV_PATH:-/tmp/tvb_env}/bin/activate"
        export OPENBLAS_NUM_THREADS=1
        python3 -m nbconvert --ExecutePreprocessor.timeout=180 --to notebook \
            --execute "$nb_abs" \
            --output "$out_nb" \
            2>> "$out"
    ) || true
    echo "--- Execution finished at $(date -Iseconds) ---" >> "$out"
}

# ─── Helper: log resource snapshot ───────────────────────────────────
log_resources() {
    local label="$1"
    local ts
    ts=$(date -Iseconds)
    local loadavg
    loadavg=$(cat /proc/loadavg 2>/dev/null | awk '{print $1}' || echo "null")
    local mem_avail
    mem_avail=$(grep MemAvailable /proc/meminfo 2>/dev/null | awk '{print $2}' || echo "null")
    local mem_total
    mem_total=$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}' || echo "null")
    local rss_kb
    rss_kb=$(ps -o rss= -p $$ 2>/dev/null | tr -d ' ' || echo "null")
    local pi_count pi_rss
    pi_count=$(ps -eo comm | grep -cx 'pi' 2>/dev/null || echo "0")
    pi_rss=$(ps -eo rss,comm | awk '$2=="pi" {sum+=$1} END {print sum+0}' 2>/dev/null || echo "0")

    cat >> "$TRIAL_DIR/resources.log" <<JSON
{"timestamp":"$ts","label":"$label","loadavg_1m":$loadavg,"mem_avail_kb":$mem_avail,"mem_total_kb":$mem_total,"proc_rss_kb":$rss_kb,"pi_procs":$pi_count,"pi_rss_kb":$pi_rss}
JSON
echo "" >> "$TRIAL_DIR/resources.log"
}

# Turn loop
log_resources "trial_start"

for turn in $(seq 1 "$MAX_TURNS"); do
    echo ""
    echo "--- Turn $turn ---"
    log_resources "turn_${turn}_start"

    # ─── DRIVER WRITE turn ─────────────────────────────────────────
    echo "[DRIVER] Writing notebook..."
    timeout --foreground -k 30 300 pi \
        --mode text \
        --no-session \
        --tools read,bash,write,edit \
        $SKILL_FLAGS \
        --system-prompt "$DRIVER_PROMPT" \
        -p "NAVIGATOR MESSAGE:\n$(cat $NAVIGATOR_MSG)\n\nYour task: implement or extend the notebook in $RESULT_NOTEBOOK inside $TRIAL_DIR. After writing the notebook, do NOT execute it. Instead, report what you wrote, what changed, and any concerns." \
        > "$DRIVER_MSG" 2>"$TRIAL_DIR/.driver_stderr" || true

    # Check for TERMINATE from driver
    if grep -q "TERMINATE" "$DRIVER_MSG" 2>/dev/null; then
        echo "[DRIVER] requested TERMINATE"
        break
    fi

    # ─── LOCAL EXECUTION ──────────────────────────────────────────
    log_resources "turn_${turn}_pre_exec"
    echo "[EXEC] Running notebook with TVB venv..."
    > "$EXEC_LOG"
    execute_notebook "$RESULT_NOTEBOOK" "$EXEC_LOG"
    log_resources "turn_${turn}_post_exec"

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

    # ─── Retry guard ─────────────────────────────────────────────
    if [ $turn -gt $MAX_FIX_RETRIES ] && [ "$EXEC_STATUS" = "Error" ]; then
        echo "[DRIVER] Max fix retries ($MAX_FIX_RETRIES) reached. Preserving last notebook and exiting."
        break
    fi

    # ─── DRIVER FIX/REPORT turn ──────────────────────────────────
    echo "[DRIVER] Reviewing execution results..."
    timeout --foreground -k 30 300 pi \
        --mode text \
        --no-session \
        --tools read,bash,write,edit \
        $SKILL_FLAGS \
        --system-prompt "$DRIVER_PROMPT" \
        -p "NAVIGATOR MESSAGE:\n$(cat $NAVIGATOR_MSG)\n\nYOUR PREVIOUS DRIVER MESSAGE:\n$(cat $DRIVER_MSG)\n\nEXECUTION REPORT:\n$(cat $EXEC_REPORT)\n\nYour task: fix any errors in $RESULT_NOTEBOOK, or if execution succeeded, confirm completion. Report results." \
        > "$DRIVER_MSG" 2>"$TRIAL_DIR/.driver2_stderr" || true

    # ─── NAVIGATOR turn ──────────────────────────────────────────
    echo "[NAVIGATOR] Running..."
    timeout --foreground -k 30 300 pi \
        --mode text \
        --no-session \
        --tools read,bash \
        $SKILL_FLAGS \
        --system-prompt "$NAVIGATOR_PROMPT" \
        -p "DRIVER MESSAGE:\n$(cat $DRIVER_MSG)\n\nGOAL:\n$(cat $TRIAL_DIR/GOAL.md)\n\nYour task: review the driver's output. If the notebook is complete and correct, write TERMINATE to $NAVIGATOR_MSG with a verdict. Otherwise, provide the next step." \
        > "$NAVIGATOR_MSG" 2>"$TRIAL_DIR/.nav_stderr" || true

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
log_resources "trial_end"

# ─── EVALUATION ─────────────────────────────────────────────────
# BUGFIX: Do NOT evaluate during generation — this caused self-evaluation contamination.
# Evaluation is now a separate pipeline step run by run_ablation_batch.sh Phase 3.
# The generated notebook is saved but NOT scored here.
if [ -f "$RESULT_NOTEBOOK" ]; then
    echo "[EVAL] Skipped inline evaluation (self-eval contamination fix). Notebook saved to $RESULT_NOTEBOOK"
    echo "BATCH_TRIAL_DONE" >> "$TRIAL_DIR/trial.log"
else
    echo "[EVAL] No notebook generated."
fi
