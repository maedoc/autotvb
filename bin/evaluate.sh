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

# ─── Resource snapshot helper ──────────────────────────────────────
log_eval_resources() {
    local label="$1"
    local ts
    ts=$(date -Iseconds)
    local loadavg
    loadavg=$(cat /proc/loadavg 2>/dev/null | awk '{print $1}' || echo "null")
    local mem_avail
    mem_avail=$(grep MemAvailable /proc/meminfo 2>/dev/null | awk '{print $2}' || echo "null")
    local rss_kb
    rss_kb=$(ps -o rss= -p $$ 2>/dev/null | tr -d ' ' || echo "null")
    local pi_count pi_rss
    pi_count=$(ps -eo comm | grep -cx 'pi' 2>/dev/null || echo "0")
    pi_rss=$(ps -eo rss,comm | awk '$2=="pi" {sum+=$1} END {print sum+0}' 2>/dev/null || echo "0")
    cat >> "$TRIAL_DIR/resources.log" <<JSON
{"timestamp":"$ts","label":"$label","loadavg_1m":$loadavg,"mem_avail_kb":$mem_avail,"proc_rss_kb":$rss_kb,"pi_procs":$pi_count,"pi_rss_kb":$pi_rss}
JSON
echo "" >> "$TRIAL_DIR/resources.log"
}

log_eval_resources "eval_start"

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

RESULT=$(timeout --foreground -k 30 "$EVAL_TIMEOUT" pi \
    $MODEL_FLAG \
    --mode text \
    --no-session \
    --tools read,bash \
    -p "$(cat "$TRIAL_DIR/.eval_prompt.txt")" \
    2>"$TRIAL_DIR/.eval_stderr.txt" || true)

# Save raw output immediately (stdout only; stderr already redirected)
echo "$RESULT" > "$TRIAL_DIR/.eval_raw.txt"

# Extract JSON with balanced-brace parsing and multiple fallbacks
python3 <<'PY' "$TRIAL_DIR/.eval_raw.txt" > "$RESULT_FILE" 2>"$TRIAL_DIR/.eval_pyerr.txt"
import sys, re, json

path = sys.argv[1]
with open(path, 'r', encoding='utf-8', errors='replace') as f:
    text = f.read()

# Strategy 1: find JSON between balanced braces (with tolerance for unbalanced)
data = None
for m in re.finditer(r'\{', text):
    start = m.start()
    depth = 0
    for i in range(start, min(len(text), start + 10000)):
        if text[i] == '{':
            depth += 1
        elif text[i] == '}':
            depth -= 1
            if depth == 0:
                try:
                    candidate = text[start:i+1]
                    data = json.loads(candidate)
                    break
                except json.JSONDecodeError:
                    continue
    if data is not None:
        break

# Strategy 2: if none found, look for simple quoted JSON block
if data is None:
    m = re.search(r'\{[^{}]*\}', text, re.DOTALL)
    if m:
        try:
            data = json.loads(m.group())
        except:
            pass

if data is not None:
    # Ensure required keys
    for k in ['correctness','code_quality','scientific_validity','token_efficiency','scalar_score','justification']:
        if k not in data:
            data[k] = 0 if k != 'justification' else 'auto-fallback'
    json.dump(data, sys.stdout)
else:
    print('{}')
PY

# If extraction failed completely, keep raw for inspection
if [ ! -s "$RESULT_FILE" ]; then
    echo '{}' > "$RESULT_FILE"
fi

# Empty-eval guard: if file is empty, too small, or just {}, write fallback
EVAL_SIZE=$(wc -c < "$RESULT_FILE" 2>/dev/null || echo 0)
EVAL_CONTENT=$(cat "$RESULT_FILE" 2>/dev/null || echo '{}')
if [ "$EVAL_SIZE" -lt 50 ] || [ "$EVAL_CONTENT" = '{}' ] || [ "$EVAL_CONTENT" = '' ]; then
    cat > "$RESULT_FILE" <<'FALLBACK'
{"correctness":0,"code_quality":0,"scientific_validity":0,"token_efficiency":5,"scalar_score":0.0,"fallback":true,"justification":"Evaluator context overflow, timeout, or empty response — notebook too large or evaluation failed. Manual review required."}
FALLBACK
    echo "WARNING: Empty or trivial evaluation detected ($EVAL_SIZE bytes). Wrote fallback score=0.0" >&2
fi

log_eval_resources "eval_end"

echo "Evaluation written to $RESULT_FILE"
cat "$RESULT_FILE"
