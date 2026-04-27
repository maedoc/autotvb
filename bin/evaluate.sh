#!/usr/bin/env bash
set -euo pipefail

# evaluate.sh — Independent LLM evaluation of a trial notebook
echo "=== Evaluator ==="
NOTEBOOK="${1:-sandbox/workflow.ipynb}"
GOAL="${2:-benchmarks/goals/visual_erp.GOAL.md}"
TRIAL_DIR="$(dirname "$NOTEBOOK")"
RESULT_FILE="${3:-$TRIAL_DIR/evaluation.json}"

# Convert notebook to script for inspection
NB_SCRIPT="$TRIAL_DIR/workflow.py"
python -m nbconvert --to script "$NOTEBOOK" --output "$NB_SCRIPT" 2>/dev/null || true

# Count tokens consumed (from driver messages if available)
TOKENS="unknown"
if [ -f "$TRIAL_DIR/DRIVER_MESSAGE.md" ]; then
    TOKENS=$(grep -oiE '[0-9]+ tokens|[0-9]+ token' "$TRIAL_DIR/DRIVER_MESSAGE.md" | grep -oE '[0-9]+' | head -1 || echo "unknown")
fi

# Build evaluation prompt
GOAL_TEXT=$(cat "$GOAL")
NB_TEXT=$(if [ -f "$NB_SCRIPT" ]; then cat "$NB_SCRIPT"; else echo "NOTEBOOK NOT FOUND"; fi)

read -r -d '' EVAL_PROMPT <<EOF || true
You are an independent scientific reviewer. Evaluate a Jupyter notebook produced by an AI agent pair trying to answer:

$GOAL_TEXT

Here is the notebook converted to a Python script:

$NB_TEXT

Rate the notebook on these 4 dimensions from 1 (poor) to 5 (excellent). Output ONLY a JSON object with no markdown formatting, no code fences, no commentary:

{
  "correctness": <1-5>,
  "code_quality": <1-5>,
  "scientific_validity": <1-5>,
  "token_efficiency": <1-5>,
  "scalar_score": <mean of the 4>,
  "justification": "<one sentence>"
}
EOF

RESULT=$(pi \
    --mode text \
    --no-session \
    --tools read,bash \
    -p "$EVAL_PROMPT" \
    2>&1 || true)

echo "$RESULT" > "$RESULT_FILE"
echo "Evaluation written to $RESULT_FILE"
cat "$RESULT_FILE"
