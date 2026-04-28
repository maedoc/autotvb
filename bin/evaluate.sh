#!/usr/bin/env bash

# ─── Model override ────────────────────────────────────────────────
PI_MODEL="${PI_MODEL:-}"
MODEL_FLAG=""
if [ -n "$PI_MODEL" ]; then
    MODEL_FLAG="--model $PI_MODEL"
    echo "[MODEL] Using: $PI_MODEL" >&2
fi
set -euo pipefail

# evaluate.sh — Independent LLM evaluation of a trial notebook
echo "=== Evaluator ==="

NOTEBOOK="${1:-sandbox/workflow.ipynb}"
GOAL="${2:-benchmarks/goals/visual_erp.GOAL.md}"
TRIAL_DIR="$(dirname "$(realpath "$NOTEBOOK")")"
RESULT_FILE="${3:-$TRIAL_DIR/evaluation.json}"

GOAL_TEXT=$(cat "$GOAL")

# Convert notebook to script for inspection
NB_SCRIPT="$TRIAL_DIR/workflow.py"
python -m nbconvert --to python "$NOTEBOOK" --output "$TRIAL_DIR/workflow.py" >/dev/null 2>&1 || true

# nbconvert may produce workflow.py.py or .txt rather than .py
if [ ! -f "$NB_SCRIPT" ] && [ -f "$TRIAL_DIR/workflow.py.py" ]; then
    NB_SCRIPT="$TRIAL_DIR/workflow.py.py"
fi
if [ ! -f "$NB_SCRIPT" ] && [ -f "$TRIAL_DIR/workflow.txt" ]; then
    NB_SCRIPT="$TRIAL_DIR/workflow.txt"
fi

NB_TEXT=$(if [ -f "$NB_SCRIPT" ]; then cat "$NB_SCRIPT"; else echo "NOTEBOOK NOT FOUND"; fi)

EVAL_TIMEOUT=${EVAL_TIMEOUT:-180}

# Truncate overly long notebooks to prevent evaluator context overflow
NB_LEN=${#NB_TEXT}
MAX_NB_LEN=15000
if [ "$NB_LEN" -gt "$MAX_NB_LEN" ]; then
    TRUNCATED_LEN=12000
    NB_TEXT=$(printf '%s' "$NB_TEXT" | head -c "$TRUNCATED_LEN")
    NB_TEXT="${NB_TEXT}"$'\n\n# [... NOTEBOOK TRUNCATED: '"$NB_LEN"' characters total, showing first '"$TRUNCATED_LEN"'. Complete notebook: '"$NB_SCRIPT"' ...]\n'
    echo "WARNING: Notebook too large ($NB_LEN chars), truncated to $TRUNCATED_LEN for evaluation" >&2
fi

# Build prompt — use single-quoted heredoc to avoid shell expansion of API examples
cat > "$TRIAL_DIR/.eval_prompt.txt" <<'PRMPT'
You are an independent scientific reviewer evaluating Jupyter notebooks for The Virtual Brain (TVB) Python simulator.

### Critical TVB API Facts
- sim.run(simulation_length=X) returns a LIST of monitor-output tuples (not a generator). It is CORRECT to unpack as: monitor1, monitor2 = sim.run(...).
- sim() (calling the Simulator object directly) yields per-step tuples where some monitors may be None between sampling instants. List comprehension is needed for this mode.
- Conduction speed must be set on the Connectivity object: conn.speed = numpy.array([value]) before conn.configure(). It is WRONG to pass conduction_speed to Simulator().
- conn.scaled_weights() and conn.tract_lengths are valid Connectivity methods.

### Execution Evidence
When scoring correctness, PRIORITIZE whether the notebook ACTUALLY RAN without errors. If it executed successfully, do NOT downgrade correctness for API usage you merely disagree with.

### Dimensions
- correctness: Does the code execute? Are TVB API calls used correctly? (1-5)
- code_quality: Readable, structured, maintainable? (1-5)
- scientific_validity: Does the analysis answer the question with correct methods? (1-5)
- token_efficiency: Concise without gratuitous extras? (1-5)

Output ONLY a JSON object with no markdown, no code fences, no commentary:

{"correctness": INT, "code_quality": INT, "scientific_validity": INT, "token_efficiency": INT, "scalar_score": FLOAT, "justification": "one sentence"}
PRMPT

cat >> "$TRIAL_DIR/.eval_prompt.txt" <<EOF

### Goal
$GOAL_TEXT

### Notebook Code
$NB_TEXT
EOF

RESULT=$(timeout "$EVAL_TIMEOUT" pi \
    $MODEL_FLAG \
    --mode text \
    --no-session \
    --tools read,bash \
    -p "$(cat "$TRIAL_DIR/.eval_prompt.txt")" \
    2>&1 || true)

# Try to extract JSON — handle markdown fences
echo "$RESULT" > "$TRIAL_DIR/.eval_raw.txt"

# Extract JSON between { and }
python3 -c "
import sys, re
text = sys.stdin.read()
# Try to find JSON block
m = re.search(r'\{.*\}', text, re.DOTALL)
if m:
    try:
        import json
        data = json.loads(m.group())
        print(json.dumps(data))
    except:
        pass
" < "$TRIAL_DIR/.eval_raw.txt" > "$RESULT_FILE" 2>/dev/null || true

# If extraction failed, keep raw
if [ ! -s "$RESULT_FILE" ]; then
    echo '{}' > "$RESULT_FILE"
fi

# Empty-eval guard: if file is empty, too small, or just {}, write fallback
EVAL_SIZE=$(wc -c < "$RESULT_FILE" 2>/dev/null || echo 0)
EVAL_CONTENT=$(cat "$RESULT_FILE" 2>/dev/null || echo '{}')
if [ "$EVAL_SIZE" -lt 50 ] || [ "$EVAL_CONTENT" = '{}' ] || [ "$EVAL_CONTENT" = '' ]; then
    cat > "$RESULT_FILE" <<'FALLBACK'
{"correctness":1,"code_quality":1,"scientific_validity":1,"token_efficiency":5,"scalar_score":1.0,"fallback":true,"justification":"Evaluator context overflow, timeout, or empty response — notebook too large or evaluation failed. Manual review required."}
FALLBACK
    echo "WARNING: Empty or trivial evaluation detected ($EVAL_SIZE bytes). Wrote fallback score=1.0" >&2
fi

echo "Evaluation written to $RESULT_FILE"
cat "$RESULT_FILE"
