import json, sys, re, os

log_dir = sys.argv[1]
raw_path = os.path.join(log_dir, "mutation_raw.txt")
json_path = os.path.join(log_dir, "mutation_plan.json")
md_path = os.path.join(log_dir, "mutation_plan.md")

with open(raw_path) as f:
    raw = f.read()

# Try direct JSON parse first
plan = None
try:
    plan = json.loads(raw.strip())
    print("[OK] Direct JSON parse succeeded")
except json.JSONDecodeError:
    # Try to find the outermost JSON object by balanced braces
    start = raw.find('{')
    if start != -1:
        depth = 0
        end = start
        for i, ch in enumerate(raw[start:], start):
            if ch == '{':
                depth += 1
            elif ch == '}':
                depth -= 1
                if depth == 0:
                    end = i + 1
                    break
        candidate = raw[start:end]
        try:
            plan = json.loads(candidate)
            print(f"[OK] Extracted JSON block {start}-{end}")
        except json.JSONDecodeError as e:
            print(f"[WARN] JSON parse error: {e}")

if plan:
    with open(json_path, "w") as f:
        json.dump(plan, f, indent=2)
else:
    print("[WARN] No valid JSON found")

with open(md_path, "w") as f:
    if plan:
        f.write(f"# Mutation Plan\n\n**Summary:** {plan.get('summary', 'N/A')}\n\n")
        mutations = plan.get("mutations", [])
        f.write(f"**Mutations:** {len(mutations)}\n\n")
        for i, mut in enumerate(mutations):
            f.write(f"## {i+1}. {mut.get('type', 'unknown').upper()} — `{mut.get('file', '???')}`\n")
            if mut.get('type') == 'edit':
                f.write(f"- Old: `{mut.get('old', '')[:120]}...`\n")
                f.write(f"- New: `{mut.get('new', '')[:120]}...`\n")
            elif mut.get('type') == 'create':
                f.write(f"- Content length: {len(mut.get('content', ''))} chars\n")
            elif mut.get('type') == 'append':
                f.write(f"- Append: `{mut.get('content', '')[:120]}...`\n")
            f.write("\n")
    else:
        f.write("# Mutation Plan\n\n**Parse failed.** Raw output:\n\n```\n")
        f.write(raw[:3000])
        f.write("\n```\n")

print(f"[OK] Markdown plan -> {md_path}")

if plan and len(plan.get("mutations", [])) > 0:
    sys.exit(0)
else:
    print("[WARN] No valid mutations extracted.")
    sys.exit(1)
