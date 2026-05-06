#!/usr/bin/env bash

# ─── Model override ────────────────────────────────────────────────
PI_MODEL="${PI_MODEL:-}"
if [ -n "$PI_MODEL" ]; then
    echo "[EVAL] Using model: $PI_MODEL (via env var)"
    echo "[MODEL] Using: $PI_MODEL" >&2
fi
set -uo pipefail

# evaluate.sh — Independent LLM evaluation of a trial notebook
echo "=== Evaluator ==="

NOTEBOOK="${1:-sandbox/workflow.ipynb}"
GOAL="${2:-benchmarks/goals/visual_erp.GOAL.md}"
TRIAL_DIR="$(dirname "$(realpath "$NOTEBOOK")")"
RESULT_FILE="${3:-$TRIAL_DIR/evaluation.json}"

GOAL_TEXT=$(cat "$GOAL")

# ─── Extract code cells only (strips markdown, outputs, metadata) ──
NB_TEXT=$(python3 -c "
import json
nb = json.load(open('$NOTEBOOK'))
src = []
for c in nb.get('cells', []):
    if c.get('cell_type') == 'code':
        s = ''.join(c.get('source', []))
        src.append(s)
text = chr(10).join(src)
# 100K cap is generous — kimi has 262K context, code is most of signal
print(text[:100000])
" 2>/dev/null || echo "EXTRACTION FAILED")

EVAL_TIMEOUT=${EVAL_TIMEOUT:-120}

# ─── Build evaluator prompt ───────────────────────────────────────
EVAL_PROMPT="${EVAL_PROMPT:-prompts/evaluator/role.md}"
if [ -f "$EVAL_PROMPT" ]; then
    cat "$EVAL_PROMPT" > "$TRIAL_DIR/.eval_prompt.txt"
else
    cat > "$TRIAL_DIR/.eval_prompt.txt" <<'PRMPT'
You are an independent scientific reviewer evaluating Jupyter notebooks for The Virtual Brain (TVB) simulator.

### Critical TVB API Facts
- sim.run() returns a LIST. Correct: (t1, d1), (t2, d2) = sim.run(...).
- conn.speed = numpy.array([v]) before conn.configure().
- conn.scaled_weights() and conn.tract_lengths are valid methods.

### Absolute Scoring Anchors — Apply to EVERY notebook identically
- correctness: code that crashes → ≤2. Runs with API errors → 3. Runs cleanly → 4-5.
- scientific_validity: wrong model or missing metrics → ≤2. Correct but unverified → 3. Verified against output → 4-5.
- Simulation too short for task → deduct 1-2 from scientific_validity (e.g. BOLD <120s for FC → max 3).
- Missing markdown rationale → deduct 1 from code_quality (goal explicitly requests it).

### Dimensions (1-5)
- correctness: Code executes without errors? Crashes ≤2, runs 3-4, clean 5.
- code_quality: Readable, structured, no dead code?
- scientific_validity: Analysis matches goal? Parameters justified?
- token_efficiency: Concise, no repetition?

Output ONLY a JSON object — no markdown, no fences. Justification ≤30 words:

{"correctness": INT, "code_quality": INT, "scientific_validity": INT, "token_efficiency": INT, "scalar_score": FLOAT, "justification": "<30 words>"}
PRMPT
fi

cat >> "$TRIAL_DIR/.eval_prompt.txt" <<EOF

### Goal
$GOAL_TEXT

### Notebook Code
$NB_TEXT
EOF

# ─── Evaluate ─────────────────────────────────────────────────────
RESULT=$(timeout --foreground -k 30 "$EVAL_TIMEOUT" pi \
    --mode text \
    --no-session \
    --tools read,bash \
    -p "$(cat "$TRIAL_DIR/.eval_prompt.txt")" \
    2>"$TRIAL_DIR/.eval_stderr.txt" || true)

echo "$RESULT" > "$TRIAL_DIR/.eval_raw.txt"

# ─── Extract JSON ─────────────────────────────────────────────────
EVAL_RAW_PATH="$TRIAL_DIR/.eval_raw.txt" python3 <<'PY' > "$RESULT_FILE"
import sys, re, json, os

path = os.environ['EVAL_RAW_PATH']
with open(path, 'r', encoding='utf-8', errors='replace') as f:
    text = f.read()

data = None
# Strategy 1: balanced braces
for m in re.finditer(r'\{', text):
    start = m.start()
    depth = 0
    for i in range(start, min(len(text), start + 10000)):
        if text[i] == '{': depth += 1
        elif text[i] == '}':
            depth -= 1
            if depth == 0:
                try: data = json.loads(text[start:i+1]); break
                except: continue
    if data is not None: break

# Strategy 2: simple JSON block
if data is None:
    m = re.search(r'\{[^{}]*\}', text, re.DOTALL)
    if m:
        try: data = json.loads(m.group())
        except: pass

# Strategy 3: regex-based extraction
if data is None:
    scores = {}
    for key in ['correctness','code_quality','scientific_validity','token_efficiency','scalar_score']:
        m2 = re.search(rf'"{key}"\s*:\s*(\d+\.?\d*)', text)
        scores[key] = float(m2.group(1)) if m2 else 0
    just_m = re.search(r'"justification"\s*:\s*"([^"]*)', text)
    scores['justification'] = just_m.group(1) if just_m else 'regex-extracted'
    if len(scores) == 6: data = scores

if data is not None:
    for k in ['correctness','code_quality','scientific_validity','token_efficiency','scalar_score','justification']:
        if k not in data:
            data[k] = 0 if k != 'justification' else 'auto-fallback'
    json.dump(data, sys.stdout)
else:
    print('{}')
PY

# ─── Fallback guard ───────────────────────────────────────────────
if [ ! -s "$RESULT_FILE" ]; then echo '{}' > "$RESULT_FILE"; fi

EVAL_SIZE=$(wc -c < "$RESULT_FILE" 2>/dev/null || echo 0)
EVAL_CONTENT=$(cat "$RESULT_FILE" 2>/dev/null || echo '{}')
IS_REGEX_EXTRACTED=$(python3 -c "import json; d=json.load(open('$RESULT_FILE')); print(1 if d.get('justification','')=='regex-extracted' else 0)" 2>/dev/null || echo 0)

if [ "$EVAL_SIZE" -lt 50 ] || [ "$EVAL_CONTENT" = '{}' ] || [ "$EVAL_CONTENT" = '' ] || [ "$IS_REGEX_EXTRACTED" = "1" ]; then
    cat > "$RESULT_FILE" <<'FALLBACK'
{"correctness":0,"code_quality":0,"scientific_validity":0,"token_efficiency":5,"scalar_score":0.0,"fallback":true,"justification":"Evaluator context overflow, timeout, or empty response."}
FALLBACK
    echo "WARNING: Empty/regex-extracted eval ($EVAL_SIZE bytes). Wrote fallback." >&2
fi

echo "Evaluation written to $RESULT_FILE"
cat "$RESULT_FILE"
