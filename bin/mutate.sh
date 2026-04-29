#!/usr/bin/env bash
set -euo pipefail
# mutate.sh — Generate a structured JSON mutation plan for apply_mutation.sh

LOG_DIR="${1:-sandbox}"
PROMPT_DIR="${2:-prompts}"
SKILL_DIR="${3:-skills-in-progress}"
RESULT_FILE="${4:-$LOG_DIR/evaluation.json}"

# Gather context
HISTORY=$(find "$LOG_DIR" -maxdepth 1 -type f \( -name 'DRIVER_MESSAGE.md' -o -name 'NAVIGATOR_MESSAGE.md' -o -name 'EXECUTION_REPORT.md' \) 2>/dev/null | sort | tail -10 | while IFS= read -r f; do echo "--- FILE: $f ---"; cat "$f"; done)

EVAL=$(cat "$RESULT_FILE" 2>/dev/null || echo '{"scalar_score":0}')

# Discover mutable files
PROMPT_FILES=$(find "$PROMPT_DIR" -name '*.md' | sort)
SKILL_FILES=$(find "$SKILL_DIR" -name '*.md' | sort)
ALL_FILES=$(echo "$PROMPT_FILES" "$SKILL_FILES" | sort)

FILE_SECTIONS=""
for f in $ALL_FILES; do
    # Truncate very large files to avoid token limits
    content=$(cat "$f" 2>/dev/null | head -c 15000)
    FILE_SECTIONS="${FILE_SECTIONS}\\n--- FILE: $f ---\\n${content}"
done

# Build mutation prompt
read -r -d '' MUTATE_PROMPT <<EOF || true
You are a meta-prompt engineer optimizing a two-agent TVB workflow system.

The system has a NAVIGATOR (reviews and directs) and a DRIVER (writes/executes TVB notebooks).
Their current prompts and skills are below. Recent trial history and an evaluation are provided.

IMPORTANT — you are NOT limited to editing existing files. You may:
- **Create** a new skill by writing a new SKILL.md in a new subdirectory of $SKILL_DIR.
- **Split** an existing skill by extracting sections into new, focused skills.
- **Merge** two closely-related skills into one if redundant.
- **Delete** a skill if obsolete or harmful.
- **Edit** any existing prompt or skill file.

A skill directory should look like:
  $SKILL_DIR/agent-name/skill-topic/SKILL.md
with YAML front-matter:
  ---
  name: short-name
  description: One-line description.
  ---

Output ONLY a JSON object with no markdown formatting, no code fences, no commentary.
The JSON must strictly follow this schema:

{
  "summary": "one-sentence summary of the mutation strategy",
  "mutations": [
    {"type": "edit",   "file": "relative/path", "old": "exact old text", "new": "exact new text"},
    {"type": "create", "file": "relative/path", "content": "full file content"},
    {"type": "delete", "file": "relative/path"},
    {"type": "append", "file": "relative/path", "content": "text to append"}
  ]
}

Rules:
- "old" must appear exactly once in the target file.
- For "create", the full file content must be provided.
- All paths are relative to the repo root.
- Do NOT edit the same file twice in one mutation — merge them into a single edit if needed.
- Do NOT output markdown around the JSON.

--- CURRENT FILES ---
$FILE_SECTIONS

--- RECENT HISTORY ---
$HISTORY

--- EVALUATION ---
$EVAL

Write ONLY the JSON mutation plan now.
EOF

mkdir -p "$LOG_DIR"
echo "=== Mutate Step ==="
echo "Calling mutation agent..."

# Run mutation agent
pi --mode text --no-session --tools read,bash -p "$MUTATE_PROMPT" > "$LOG_DIR/mutation_raw.txt" 2>&1 || true

# Extract JSON from raw output using project script
python3 "$REPO_DIR/bin/extract_mutation.py" "$LOG_DIR"
exit_code=$?

# Report
if [ -f "$LOG_DIR/mutation_plan.json" ]; then
    echo ""
    echo "Plan preview:"
    jq -r '.summary, "Mutations: \(.mutations | length)"' "$LOG_DIR/mutation_plan.json" 2>/dev/null || true
fi
