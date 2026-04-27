#!/usr/bin/env bash
set -euo pipefail
# mutate.sh — Use pi CLI to improve prompts/skills based on past trial logs

LOG_DIR="${1:-sandbox}"
PROMPT_DIR="${2:-prompts}"
SKILL_DIR="${3:-skills-in-progress}"
RESULT_FILE="${4:-$LOG_DIR/evaluation.json}"

echo "=== Mutate Step ==="

# Gather recent trial history (last 10 driver/navigator messages)
HISTORY=$(find "$LOG_DIR" -maxdepth 1 -type f \( -name 'DRIVER_MESSAGE.md' -o -name 'NAVIGATOR_MESSAGE.md' \) | sort | tail -10 | while read f; do echo "--- $f ---"; cat "$f"; done)

EVAL=$(cat "$RESULT_FILE" 2>/dev/null || echo '{"scalar_score":0}')

# Dynamically discover all mutable files
PROMPT_FILES=$(find "$PROMPT_DIR" -name '*.md' | sort)
SKILL_FILES=$(find "$SKILL_DIR" -name '*.md' | sort)
ALL_FILES=$(echo "$PROMPT_FILES" "$SKILL_FILES" | sort)

# Build per-file sections
FILE_SECTIONS=""
for f in $ALL_FILES; do
    FILE_SECTIONS="${FILE_SECTIONS}\n--- FILE: $f ---\n$(cat "$f")"
done

# Build mutation prompt
read -r -d '' MUTATE_PROMPT <<EOF || true
You are a meta-prompt engineer optimizing a two-agent TVB workflow.

The system has a NAVIGATOR and a DRIVER. Their current prompts and skills are below.
Recent trial history and an independent evaluation are also provided.

Your task: propose concrete, targeted edits to IMPROVE the prompts and/or skills.

IMPORTANT — you are NOT limited to editing existing files. You may also:
- **Create** a new skill by writing a new SKILL.md in a new subdirectory of $SKILL_DIR.
- **Split** an existing skill by extracting sections into new, focused skills and removing them from the original.
- **Merge** two closely-related skills into one if they are redundant.
- **Delete** a skill entirely if it is obsolete or harmful.
- **Edit** any existing prompt or skill file in place.

A skill directory should look like:
  $SKILL_DIR/agent-name/skill-topic/SKILL.md
with a YAML front-matter block:
  ---
  name: short-name
  description: One-line description for the pi skill loader.
  ---

Output ONLY a markdown plan with:
1. What weakness the evaluation identified
2. Which file to edit or create (full path)
3. The exact replacement text (old → new) OR the full content for new files

Do NOT write full files unless creating a brand-new skill. For edits, write compact diffs.

--- CURRENT FILES ---
$FILE_SECTIONS

--- RECENT TRIAL HISTORY ---
$HISTORY

--- EVALUATION ---
$EVAL

Write your improvement plan now.
EOF

mkdir -p "$LOG_DIR"
pi --mode text --no-session --tools read,write,edit,bash -p "$MUTATE_PROMPT" > "$LOG_DIR/mutation_plan.md"

echo "Mutation plan written to $LOG_DIR/mutation_plan.md"
cat "$LOG_DIR/mutation_plan.md"
