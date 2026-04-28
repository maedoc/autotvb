#!/usr/bin/env bash
set -euo pipefail
# apply_mutation.sh — Apply a structured JSON mutation plan
# Usage: apply_mutation.sh PLAN_JSON

PLAN="${1:-sandbox/mutation_plan.json}"

if [ ! -f "$PLAN" ]; then
    echo "[ERROR] No mutation plan found at $PLAN"
    exit 1
fi

echo "=== Applying mutation plan: $PLAN ==="

# Use Python for reliable JSON + file operations
python3 - "$PLAN" <<'PYEOF'
import json, sys, os, pathlib, shutil

plan_file = sys.argv[1]
with open(plan_file) as f:
    plan = json.load(f)

mutations = plan.get("mutations", plan if isinstance(plan, list) else [plan])
applied = 0
failed = 0

for m in mutations:
    mtype = m.get("type")
    path = m.get("file", m.get("path", ""))
    if not path:
        print(f"[SKIP] mutation with no path: {m}")
        failed += 1
        continue

    abs_path = pathlib.Path(path).resolve()
    
    # Reject obviously invalid paths
    if path in ('', '.', '..', 'EOF'):
        print(f"[FAIL] invalid path: {path}")
        failed += 1
        continue
    
    if mtype == "create":
        content = m.get("content", "")
        abs_path.parent.mkdir(parents=True, exist_ok=True)
        with open(abs_path, "w") as f:
            f.write(content)
        print(f"[CREATE] {abs_path}")
        applied += 1

    elif mtype == "edit":
        old = m.get("old", "")
        new = m.get("new", "")
        if not abs_path.exists():
            print(f"[FAIL] edit target missing: {abs_path}")
            failed += 1
            continue
        text = abs_path.read_text()
        if old not in text:
            print(f"[FAIL] old text not found in {abs_path}")
            failed += 1
            continue
        if text.count(old) > 1:
            print(f"[FAIL] old text appears multiple times in {abs_path}")
            failed += 1
            continue
        text = text.replace(old, new, 1)
        abs_path.write_text(text)
        print(f"[EDIT] {abs_path}")
        applied += 1

    elif mtype == "delete":
        if abs_path.exists():
            if abs_path.is_dir():
                shutil.rmtree(abs_path)
            else:
                abs_path.unlink()
            print(f"[DELETE] {abs_path}")
            applied += 1
        else:
            print(f"[SKIP] already missing: {abs_path}")

    elif mtype == "append":
        content = m.get("content", "")
        with open(abs_path, "a") as f:
            f.write(content)
        print(f"[APPEND] {abs_path}")
        applied += 1

    else:
        print(f"[SKIP] unknown mutation type: {mtype}")
        failed += 1

print(f"\n=== Applied {applied} mutations, {failed} failed ===")
PYEOF

echo "Done."
# No-op — will insert via python instead
