#!/usr/bin/env bash
# overnight_batch.sh — Run all 10 paper-grounded research goals
# Usage: overnight_batch.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_DIR"

BATCH_DIR="$REPO_DIR/sandbox/batch_research_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BATCH_DIR"

GOALS=(
    "benchmarks/goals_research/vep_epileptor_permittivity.GOAL.md"
    "benchmarks/goals_research/alzheimers_abeta_ei.GOAL.md"
    "benchmarks/goals_research/depression_gaba_tep.GOAL.md"
    "benchmarks/goals_research/depression_rtms_wilsoncowan.GOAL.md"
    "benchmarks/goals_research/schizophrenia_nrg1_ei.GOAL.md"
    "benchmarks/goals_research/stroke_sj3d_bold.GOAL.md"
    "benchmarks/goals_research/tdcs_fc_modulation.GOAL.md"
    "benchmarks/goals_research/tumor_virtual_resection.GOAL.md"
    "benchmarks/goals_research/epilepsy_bayesian_fitting.GOAL.md"
    "benchmarks/goals_research/parameter_space_exploration.GOAL.md"
)

NAMES=(
    "vep"
    "alzheimers"
    "gaba_tep"
    "rtms"
    "nrg1"
    "stroke"
    "tdcs"
    "tumor"
    "bayesian"
    "param_sweep"
)

# Global timeout: 2 hours per trial (7200 seconds)
GLOBAL_TIMEOUT=7200
MAX_TURNS=5

echo "=== Overnight Batch: Research Goals ==="
echo "Batch dir: $BATCH_DIR"
echo "Goals: ${#GOALS[@]}"
echo "Max turns: $MAX_TURNS"
echo "Global timeout per trial: ${GLOBAL_TIMEOUT}s"
echo ""

# Launch all trials in tmux sessions
for i in "${!GOALS[@]}"; do
    goal="${GOALS[$i]}"
    name="${NAMES[$i]}"
    dir="$BATCH_DIR/$name"
    mkdir -p "$dir"
    
    # Pre-copy goal for reference
    cp "$goal" "$dir/GOAL.md"
    
    session="batch_research_${name}"
    tmux new-session -d -s "$session" \
        "timeout ${GLOBAL_TIMEOUT} bash bin/run_trial.sh \"$goal\" ${MAX_TURNS} \"$dir\" > \"$dir/trial.log\" 2>&1; echo '=== BATCH_TRIAL_DONE status=$? ===' >> \"$dir/trial.log\""
    
    echo "Launched $name (tmux: $session)"
done

echo ""
echo "All ${#GOALS[@]} trials launched."
echo "Poll with: bash bin/poll_batch.sh $BATCH_DIR"
echo ""

# Write batch metadata
cat > "$BATCH_DIR/batch.json" <<EOF
{
  "batch_type": "paper_grounded_research",
  "timestamp": "$(date -Iseconds)",
  "goals_count": ${#GOALS[@]},
  "max_turns": $MAX_TURNS,
  "timeout_seconds": $GLOBAL_TIMEOUT,
  "git_commit": "$(git rev-parse --short HEAD)",
  "goals": [
$(for i in "${!NAMES[@]}"; do
    echo "    {\"name\": \"${NAMES[$i]}\", \"goal_file\": \"${GOALS[$i]}\"}${SEP:-}"
    SEP=","
done)
  ]
}
EOF

echo "Batch metadata written to $BATCH_DIR/batch.json"
