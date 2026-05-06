#!/usr/bin/env bash
set -uo pipefail
# reevaluate_all.sh — Re-evaluate ALL existing v2 notebooks
# Uses kimi-k2.6 (frontier, 262K context) for evaluation — no truncation issues.

cd ~/src/autotvb

V2_DIR="${1:-sandbox/ablation_v2_20260505_122823}"
EVAL_MODEL="${EVAL_MODEL:-ollama/kimi-k2.6}"

echo "=== Re-evaluating ALL v2 notebooks with $EVAL_MODEL ==="
echo "V2 dir:  $V2_DIR"
echo ""

# Collect all notebooks
declare -a dirs=()
while IFS= read -r -d '' nb; do
    dirs+=("$(dirname "$nb")")
done < <(find "$V2_DIR" -name "workflow.ipynb" -print0)

echo "Found ${#dirs[@]} notebooks"
echo ""

eval_n=0; ok_n=0; fail_n=0

for dir in "${dirs[@]}"; do
    eval_n=$((eval_n + 1))
    nb="$dir/workflow.ipynb"
    goal="$dir/GOAL.md"
    
    [ -f "$nb" ] || continue
    [ -f "$goal" ] || continue
    
    # Remove old evaluation  
    rm -f "$dir/evaluation.json" "$dir/.eval_raw.txt" "$dir/eval.log" "$dir/.eval_prompt.txt"
    
    echo -n "[$eval_n/${#dirs[@]}] $(echo "$dir" | sed "s|$V2_DIR/||") ... "
    
    PI_MODEL=$EVAL_MODEL bash bin/evaluate.sh "$nb" "$goal" "$dir/evaluation.json" \
        > "$dir/eval.log" 2>&1 || true
    
    if [ -f "$dir/evaluation.json" ]; then
        score=$(python3 -c "import json; d=json.load(open('$dir/evaluation.json')); print(d.get('scalar_score','?'))" 2>/dev/null)
        fb=$(python3 -c "import json; d=json.load(open('$dir/evaluation.json')); print('FALLBACK' if d.get('fallback') else '')" 2>/dev/null)
        echo "→ $score $fb"
        [ "$score" != "0" ] && [ "$score" != "0.0" ] && [ "$score" != "?" ] && ok_n=$((ok_n + 1)) || fail_n=$((fail_n + 1))
    else
        echo "→ MISSING"
        fail_n=$((fail_n + 1))
    fi
done

echo ""
echo "=== Done ==="
echo "Evaluated: $eval_n, OK: $ok_n, Failed: $fail_n"
echo ""

# Summary
python3 << PYEOF
import json, os
from collections import defaultdict

v2_dir = "$V2_DIR"
results = defaultdict(lambda: defaultdict(list))
dims = ["correctness", "code_quality", "scientific_validity", "token_efficiency"]

for root, dirs, files in os.walk(v2_dir):
    if "evaluation.json" in files and "workflow.ipynb" in files and "GOAL.md" in files:
        rel = os.path.relpath(root, v2_dir)
        parts = rel.split("/")
        if len(parts) < 3: continue
        model, cond, goal = parts[0], parts[1], parts[2]
        try:
            d = json.load(open(os.path.join(root, "evaluation.json")))
            if not d.get("fallback") and d.get("scalar_score", 0) > 0:
                key = f"{model}/{cond}"
                results[key]["scores"].append(d["scalar_score"])
                for dim in dims:
                    if d.get(dim, 0) > 0:
                        results[key][dim].append(d[dim])
        except: pass

print("=" * 72)
print(f"{'Model/Condition':<30} {'N':>4} {'Mean':>7} {'Corr':>6} {'Qual':>6} {'Sci':>6} {'Tok':>6}")
print("=" * 72)
for key in sorted(results.keys()):
    r = results[key]
    scores = r.get("scores", [])
    if scores:
        avg = sum(scores)/len(scores)
        d_avg = {dim: sum(r.get(dim,[0]))/len(r.get(dim,[1])) if r.get(dim) else 0 for dim in dims}
        print(f"{key:<30} {len(scores):>4} {avg:7.2f} {d_avg['correctness']:6.1f} {d_avg['code_quality']:6.1f} {d_avg['scientific_validity']:6.1f} {d_avg['token_efficiency']:6.1f}")
print("=" * 72)

# Skill effects
for m in ["rnj-8b", "ministral-14b"]:
    zs = [s for k,scores in results.items() if k==f"{m}/zero_shot" for s in scores.get("scores",[])]
    ws = [s for k,scores in results.items() if k==f"{m}/with_skills" for s in scores.get("scores",[])]
    if zs and ws:
        zs_avg = sum(zs)/len(zs)
        ws_avg = sum(ws)/len(ws)
        print(f"\n{m}: skills Δ = {ws_avg:.2f} - {zs_avg:.2f} = {ws_avg - zs_avg:+.2f} (n_zs={len(zs)}, n_ws={len(ws)})")
PYEOF
