#!/usr/bin/env bash
# init_env.sh — Bootstrap autotvb environment (container-friendly)
# Usage: ./init_env.sh [VENV_PATH]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# If running as container entrypoint or in a detached dir, ensure we run
# inside the repo where paths are predictable.
cd "$SCRIPT_DIR"

VENV_ARG="${1:-}"
# If arg looks like a command (starts with special chars or 'bash'), ignore it
if [ -n "$VENV_ARG" ] && [ -d "$VENV_ARG" ] 2>/dev/null; then
    VENV_PATH="$VENV_ARG"
else
    VENV_PATH="/tmp/tvb_env"
fi
PYTHON="${PYTHON:-python3}"

echo "=== Autotvb Environment Init ==="
echo "Repo dir:   $SCRIPT_DIR"
echo "VENV path:  $VENV_PATH"
echo "Python:     $(which $PYTHON)"
echo ""

# ─── Ensure Python ───────────────────────────────────────────────
if ! command -v "$PYTHON" &>/dev/null; then
    echo "ERROR: Python ($PYTHON) not found in PATH" >&2
    exit 1
fi

PY_VER="$($PYTHON --version)"
echo "Python version: $PY_VER"

# ─── Create venv ─────────────────────────────────────────────────
if [ ! -f "$VENV_PATH/bin/activate" ]; then
    echo "Creating venv at $VENV_PATH ..."
    "$PYTHON" -m venv "$VENV_PATH"
else
    echo "Venv already exists."
fi

source "$VENV_PATH/bin/activate"

# ─── Install core dependencies ──────────────────────────────────
REQUIRED=("tvb-library~=2.10" "tvb-data~=3.0" "jupyter" "nbconvert>=7"
          "matplotlib" "numpy<2" "scipy" "seaborn" "pandas")

MISSING=""
for pkg in "${REQUIRED[@]}"; do
    # pip package name may contain extras/version markers
    base="$(echo "$pkg" | sed 's/\[.*\]//g; s/[~<>!=].*//g')"
    if ! pip show "$base" &>/dev/null; then
        MISSING="$MISSING $pkg"
    fi
done

if [ -n "$MISSING" ]; then
    echo "Installing missing packages: $MISSING"
    pip install $MISSING
else
    echo "All required packages already installed."
fi

# ─── Check pi CLI ────────────────────────────────────────────────
if ! command -v pi &>/dev/null; then
    echo "WARNING: pi CLI not found in PATH." >&2
    echo "Install it globally or via npx/uvx before using this project." >&2
    echo "  npm i -g @mariozechner/pi-coding-agent" >&2
    PI_OK=false
else
    PI_V="$(pi --version 2>/dev/null || echo 'unknown')"
    echo "pi CLI:     $PI_V"
    PI_OK=true
fi

# ─── Check available pi model ─────────────────────────────────
if command -v ollama &>/dev/null; then
    if ollama list 2>/dev/null | grep -q . ; then
        echo "Available local ollama models:"
        ollama list 2>/dev/null | awk 'NR>1 && $1 {print "  - " $1}'
    else
        echo "WARNING: No local ollama models found." >&2
    fi
    MODELS_AVAILABLE="$(ollama list 2>/dev/null | awk 'NR>1 && $1 {print $1}' | tr '\n' ' ')"
    if [ -z "$MODELS_AVAILABLE" ]; then
        echo "  (none)"
    fi
else
    echo "WARNING: ollama not found. Cloud-only provider setup assumed." >&2
fi

# ─── Ensure .env (optional) ─────────────────────────────────────
if [ ! -f "$SCRIPT_DIR/.env" ]; then
    cat > "$SCRIPT_DIR/.env" <<EOF
# Autotvb environment
# Override default model for pi invocations
# PI_MODEL=ollama/kimi-k2.6:cloud
# PI_MODEL=ollama/deepseek-v4-flash:cloud
# PI_MODEL=ollama/gemmm4:e4b
EOF
    echo "Created template .env file."
fi

# ─── Sanity check: TVB import ──────────────────────────────────
VENV_PYTHON="$VENV_PATH/bin/python"
if "$VENV_PYTHON" -c "import tvb.simulator.lab; print('TVB OK')" &>/dev/null; then
    echo "TVB OK"
else
    echo "WARNING: tvb import failed — something may be wrong with the venv." >&2
fi

# ─── Summary ─────────────────────────────────────────────────────
echo ""
echo "=== Environment ready ==="
echo "Activate:   source $VENV_PATH/bin/activate"
if [ "$PI_OK" = true ]; then
    echo "Run trial:  PI_MODEL=ollama/kimi-k2.6:cloud bash bin/run_trial.sh benchmarks/goals/visual_erp.GOAL.md"
    echo "Batch:      PI_MODEL=ollama/kimi-k2.6:cloud bash bin/overnight_batch.sh"
else
    echo "Install pi CLI before running trials."
fi
