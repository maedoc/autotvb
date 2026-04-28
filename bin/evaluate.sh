#!/usr/bin/env bash
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

RESULT=$(pi \
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

echo "Evaluation written to $RESULT_FILE"
cat "$RESULT_FILE"
