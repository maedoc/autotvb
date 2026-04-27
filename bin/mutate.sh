#!/usr/bin/env bash
set -euo pipefail
# mutate.sh — Use pi CLI to improve prompts/skills based on past trial logs

LOG_DIR="${1:-sandbox}"
PROMPT_DIR="${2:-prompts}"
SKILL_DIR="${3:-skills-in-progress}"
RESULT_FILE="${4:-$LOG_DIR/evaluation.json}"

echo "=== Mutate Step ==="

# Gather recent trial history (last 5 driver/navigator messages + evaluation)
HISTORY=$(find "$LOG_DIR" -maxdepth 1 -type f \( -name 'DRIVER_MESSAGE.md' -o -name 'NAVIGATOR_MESSAGE.md' \) | sort | tail -10 | while read f; do echo "--- $f ---"; cat "$f"; done)

EVAL=$(cat "$RESULT_FILE" 2>/dev/null || echo '{"scalar_score":0}')

# Build mutation prompt
read -r -d '' MUTATE_PROMPT <<EOF || true
You are a meta-prompt engineer optimizing a two-agent TVB workflow.

The system has a NAVIGATOR and a DRIVER. Their current prompts and skills are below.
Recent trial history and an independent evaluation are also provided.

Your task: propose concrete, targeted edits to IMPROVE the prompts and/or skills.
Output ONLY a markdown plan with:
1. What weakness the evaluation identified
2. Which file to edit (path)
3. The exact replacement text (old → new)

Do NOT write full files. Write compact diffs.

--- CURRENT NAVIGATOR PROMPT ---
$(cat $PROMPT_DIR/navigator/role.md)

--- CURRENT DRIVER PROMPT ---
$(cat $PROMPT_DIR/driver/role.md)

--- CURRENT NAVIGATOR SKILL ---
$(cat $SKILL_DIR/navigator/SKILL.md)

--- CURRENT DRIVER SKILL ---
$(cat $SKILL_DIR/driver/SKILL.md)

--- RECENT TRIAL HISTORY ---
$HISTORY

--- EVALUATION ---
$EVAL

Write your improvement plan now.
EOF

pi --mode text --no-session --tools read,edit -p "$MUTATE_PROMPT" > sandbox/mutation_plan.md

echo "Mutation plan written to sandbox/mutation_plan.md"
cat sandbox/mutation_plan.md
