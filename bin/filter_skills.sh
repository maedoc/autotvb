#!/usr/bin/env bash
# filter_skills.sh — Select relevant skills for a goal based on keyword matching
# Usage: filter_skills.sh GOAL_FILE [SKILLS_ROOT]
# Outputs: space-separated --skill flags for pi

GOAL_FILE="${1}"
SKILLS_ROOT="${2:-skills-in-progress}"

# Extract keywords from goal file
GOAL_TEXT=$(cat "$GOAL_FILE" 2>/dev/null | tr '[:upper:]' '[:lower:]')

# Define skill→keyword mappings
# Format: "skill_subdir|keyword1|keyword2|keyword3|..."
declare -A SKILL_MAP=(
    ["driver/boilerplate"]="generic2d|epileptor|jansen|wilson|wong|kuramoto|reduced|import|connectivity|simulator|configure"
    ["driver/stimulus"]="stimul|pulse|gaussian|tms|tdcs|rtms|stimulus|input|perturb|onset|tau"
    ["driver/surface-forward"]="surface|eeg|meg|seeg|ieeg|cortex|sensors|projection|spatial|forward"
    ["driver/noise-and-integrator"]="noise|integrator|heun|euler|dt|stochastic|deterministic|nsig"
    ["driver/analysis"]="analysis|fc|correlat|spectr|fft|welch|power|psd|variance|mean|plot|visualiz|burn"
    ["driver/notebook-format"]="notebook|json|ipynb|cell|markdown|latex|format"
    ["driver/parameter-sweep"]="sweep|explore|grid|heatmap|optimal|parameter|space|cv|coupling|range"
    ["driver/heterogeneous-params"]="heterogeneous|region|focal|ez|pz|tier|genotype|spatial|map|abeta|pharmaco"
    ["driver/graph-metrics"]="graph|network|efficien|cluster|kuramoto|coherence|synchron|phase|structure|function|modular"
    ["driver/tvb-api-mappings"]="epileptor|jansen|wilson|reducedset|sj3d|seeg|tau0|gamma|c1|c2|c3|c4"
    ["driver/simulation-duration"]="duration|simulation_length|bold|time|seconds|minute|length|vol|temporalaverage"
    ["driver/concise-code"]="plot|figure|concise|verbose|token|efficient|redundant|heatmap|subplot|display|output"
    ["driver/region-atlas"]="region|index|label|v1|v2|m1|hippocampus|amygdala|atlas|parcellation|pericalcarine|precentral|dlpfc|thalamus"
    ["driver/simulation-duration"]="duration|simulation_length|bold|time|seconds|minute|length|vol|temporalaverage"
    ["driver/concise-code"]="plot|figure|concise|verbose|token|efficient|redundant|heatmap|subplot|display|output"
    ["driver/region-atlas"]="region|index|label|v1|v2|m1|hippocampus|amygdala|atlas|parcellation|pericalcarine|precentral|dlpfc|thalamus"
    ["navigator/planning"]="plan|decompos|workflow|step|strategy|approach|design|architect"
    ["navigator/code-review"]="review|check|inspect|audit|lint|drift|bug|error|mistake|correctness"
    ["navigator/common-models"]="model|connectivity|coupling|monitor|integrator|stimulus|parameter|trait|api"
    ["navigator/scientific-validity"]="valid|regime|plausib|physiologic|empirical|literature|paper|range|threshold|burn"
)

MATCHED=""
for skill_dir in "${!SKILL_MAP[@]}"; do
    keywords="${SKILL_MAP[$skill_dir]}"
    matched=0
    IFS='|' read -ra KWS <<< "$keywords"
    for kw in "${KWS[@]}"; do
        if echo "$GOAL_TEXT" | grep -qi "$kw"; then
            matched=1
            break
        fi
    done
    if [ "$matched" -eq 1 ]; then
        full_path="$SKILLS_ROOT/$skill_dir"
        if [ -f "$full_path/SKILL.md" ]; then
            MATCHED="$MATCHED --skill $full_path"
        fi
    fi
done

# Always include boilerplate and notebook-format as safety
for safety in "driver/boilerplate" "driver/notebook-format"; do
    if [ -f "$SKILLS_ROOT/$safety/SKILL.md" ]; then
        if ! echo "$MATCHED" | grep -q "\-\-skill $SKILLS_ROOT/$safety"; then
            MATCHED="$MATCHED --skill $SKILLS_ROOT/$safety"
        fi
    fi
done

# If nothing matched, load all (fallback)
if [ -z "$MATCHED" ]; then
    while IFS= read -r skill_md; do
        skill_dir=$(dirname "$skill_md")
        MATCHED="$MATCHED --skill $skill_dir"
    done < <(find "$SKILLS_ROOT" -name 'SKILL.md' | sort)
fi

echo "$MATCHED"
