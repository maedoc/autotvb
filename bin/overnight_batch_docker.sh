#!/usr/bin/env bash
# overnight_batch_docker.sh — Docker-based full sweep over ALL goals
# Each trial runs in an isolated container with memory limits and slug naming
# Usage: PI_MODEL=ollama/kimi-k2.6:cloud bash bin/overnight_batch_docker.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_DIR"

BATCH_DIR="$REPO_DIR/sandbox/batch_all_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BATCH_DIR"

# ─── ALL GOALS ────────────────────────────────────────────────────
EXISTING_GOALS=($(find benchmarks/goals -name '*.GOAL.md' | sort))
RESEARCH_GOALS=($(find benchmarks/goals_research -name '*.GOAL.md' | sort))
ALL_GOALS=("${EXISTING_GOALS[@]}" "${RESEARCH_GOALS[@]}")

# ─── CONFIG ──────────────────────────────────────────────────────
PI_MODEL="${PI_MODEL:-ollama/kimi-k2.6:cloud}"
MAX_TURNS=3
MAX_CONCURRENT="${MAX_CONCURRENT:-5}"
MEMORY_LIMIT="${MEMORY_LIMIT:-4g}"
CONTAINER_TIMEOUT="${CONTAINER_TIMEOUT:-7200}"
IMAGE="${AUTOTVB_IMAGE:-autotvb:latest}"
NETWORK="${AUTOTVB_NETWORK:-autotvb-net}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "=== Docker Full Sweep ==="
echo "Image: $IMAGE"
echo "Memory: $MEMORY_LIMIT"
echo "Network: $NETWORK"
echo "Existing goals: ${#EXISTING_GOALS[@]}"
echo "Research goals: ${#RESEARCH_GOALS[@]}"
echo "Total: ${#ALL_GOALS[@]}"
echo "Batch dir: $BATCH_DIR"
echo ""

# Verify image exists
if ! docker inspect "$IMAGE" >/dev/null 2>&1; then
    echo "ERROR: Docker image '$IMAGE' not found. Build it first:"
    echo "  docker build -t autotvb:latest ."
    exit 1
fi

# Create shared network if it doesn't exist (for ollama connectivity)
if ! docker network inspect "$NETWORK" >/dev/null 2>&1; then
    echo "Creating Docker network: $NETWORK"
    docker network create "$NETWORK" >/dev/null 2>&1 || true
fi

# Generate safe names
NAMES=()
for goal in "${ALL_GOALS[@]}"; do
    base=$(basename "$goal" .GOAL.md)
    # Docker container names: lowercase alphanum, hyphens only
    safe=$(echo "$base" | tr '[:upper:]' '[:lower:]' | tr '_./' '-' | sed 's/[^a-z0-9-]//g' | cut -c1-40)
    NAMES+=("$safe")
done

# Track active containers
CONTAINERS=()

for i in "${!ALL_GOALS[@]}"; do
    goal="${ALL_GOALS[$i]}"
    name="${NAMES[$i]}"
    dir="$BATCH_DIR/$name"
    mkdir -p "$dir"
    cp "$goal" "$dir/GOAL.md"

    # Unique container slug: autotvb-<name>-<timestamp>-<idx>
    slug="autotvb-${name}-${TIMESTAMP}-$((i+1))"

    # Convert host path to container path (replace $REPO_DIR prefix with /app)
    container_goal="${goal/#$REPO_DIR//app}"
    container_dir="${dir/#$REPO_DIR//app}"

    # Limit concurrent containers
    if [ "${#CONTAINERS[@]}" -ge "$MAX_CONCURRENT" ]; then
        echo "[WAIT] Max concurrent ($MAX_CONCURRENT) reached, waiting..."
        # Poll until at least one container slot frees up
        while true; do
            NEW_CONTAINERS=()
            for c in "${CONTAINERS[@]}"; do
                # With --rm, container is removed after exit,
                # so 'docker inspect' failure means it's done
                status=$(docker inspect -f '{{.State.Status}}' "$c" 2>/dev/null) || status="gone"
                if [ "$status" = "running" ] || [ "$status" = "created" ] || [ "$status" = "restarting" ]; then
                    NEW_CONTAINERS+=("$c")
                fi
            done
            CONTAINERS=("${NEW_CONTAINERS[@]}")
            if [ "${#CONTAINERS[@]}" -lt "$MAX_CONCURRENT" ]; then
                break
            fi
            sleep 10
        done
        echo "[WAIT] Now ${#CONTAINERS[@]} containers running"
    fi

    # Launch trial in Docker container
    echo "[LAUNCH] [$((i+1))/${#ALL_GOALS[@]}] $slug → $name"
    docker run \
        --rm \
        --detach \
        --name="$slug" \
        --memory="$MEMORY_LIMIT" \
        --memory-swap="$MEMORY_LIMIT" \
        --cpus="2" \
        --pids-limit=50 \
        --network="$NETWORK" \
        --hostname="$slug" \
        --stop-timeout=300 \
        -e "PI_MODEL=$PI_MODEL" \
        -e "MAX_TURNS=$MAX_TURNS" \
        -e "TZ=Europe/Berlin" \
        -v "$REPO_DIR:/app" \
        -v "/tmp/tvb_env:/opt/tvb_env:ro" \
        -v "$HOME/.pi/agent:/root/.pi/agent:ro" \
        --entrypoint bash \
        "$IMAGE" \
        -c "
            set -uo pipefail
            cd /app
            # Ensure TVB venv is active
            export PATH=/opt/tvb_env/bin:\$PATH
            # Run trial
            bash bin/run_trial.sh '$container_goal' $MAX_TURNS '$container_dir' > '$container_dir/trial.log' 2>&1
            exit_code=\$?
            echo '=== BATCH_TRIAL_DONE status=\$exit_code ===' >> '$container_dir/trial.log'
            exit \$exit_code
        " > /dev/null 2>&1

    if [ $? -eq 0 ]; then
        CONTAINERS+=("$slug")
        echo "  Container $slug started (mem=${MEMORY_LIMIT})"
    else
        echo "  ERROR: Failed to start container $slug"
    fi
done

# Wait for remaining containers
echo ""
echo "Waiting for ${#CONTAINERS[@]} remaining containers..."
for c in "${CONTAINERS[@]}"; do
    echo "  Waiting for $c..."
    docker wait "$c" >/dev/null 2>&1 || true
done

# Final cleanup: remove any dangling containers with our prefix
docker container prune --filter "label=name=autotvb" --force >/dev/null 2>&1 || true

echo ""
echo "All ${#ALL_GOALS[@]} trials completed."
echo "Poll with: bash bin/poll_batch.sh $BATCH_DIR"
echo ""

# Batch metadata
{
    mem_avail=$(grep MemAvailable /proc/meminfo 2>/dev/null | awk '{print $2}' || echo "null")
    mem_total=$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}' || echo "null")
    loadavg=$(cat /proc/loadavg 2>/dev/null | awk '{print $1}' || echo "null")
    echo '{'
    echo "  \"batch_type\": \"docker_full_sweep\","
    echo "  \"timestamp\": \"$(date -Iseconds)\","
    echo "  \"goals_count\": ${#ALL_GOALS[@]},"
    echo "  \"existing_count\": ${#EXISTING_GOALS[@]},"
    echo "  \"research_count\": ${#RESEARCH_GOALS[@]},"
    echo "  \"max_turns\": $MAX_TURNS,"
    echo "  \"max_concurrent\": $MAX_CONCURRENT,"
    echo "  \"memory_limit\": \"$MEMORY_LIMIT\","
    echo "  \"timeout_seconds\": $CONTAINER_TIMEOUT,"
    echo "  \"image\": \"$IMAGE\","
    echo "  \"network\": \"$NETWORK\","
    echo "  \"git_commit\": \"$(git rev-parse --short HEAD)\","
    echo "  \"host_mem_total_kb\": $mem_total,"
    echo "  \"host_mem_avail_kb\": $mem_avail,"
    echo "  \"host_loadavg_1m\": $loadavg"
    echo '}'
} > "$BATCH_DIR/batch.json"

echo "Batch metadata: $BATCH_DIR/batch.json"
