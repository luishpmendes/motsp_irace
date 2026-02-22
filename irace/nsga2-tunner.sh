#!/bin/bash
###############################################################################
# NSGA-II Target Runner for iRace
# 
# Usage: ./nsga2-tunner.sh <config_id> <instance_id> <seed> <instance> [params...]
# Output: cost time
###############################################################################

CONFIG_ID="$1"
INSTANCE_ID="$2"
SEED="$3"
INSTANCE="$4"
shift 4
PARAMS=("$@")

# Project directory (one level up from irace/)
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Executables
SOLVER="${PROJECT_DIR}/bin/exec/nsga2_solver_exec"
HV_CALC="${PROJECT_DIR}/bin/exec/hypervolume_calculator_exec"

# Time limit per run (seconds)
TIME_LIMIT=300

# Create temporary directory for this run
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

# Output files
PARETO_FILE="${TMPDIR}/pareto.txt"
HV_FILE="${TMPDIR}/hv.txt"

# Transform parameters (population_size_factor -> population_size)
TRANSFORMED_PARAMS=()
i=0
while [ $i -lt ${#PARAMS[@]} ]; do
    if [ "${PARAMS[$i]}" = "--population-size-factor" ]; then
        FACTOR="${PARAMS[$((i+1))]}"
        # Population size = factor * 4
        POPULATION_SIZE=$((FACTOR * 4))
        TRANSFORMED_PARAMS+=("--population-size" "$POPULATION_SIZE")
        i=$((i + 2))
    else
        TRANSFORMED_PARAMS+=("${PARAMS[$i]}")
        i=$((i + 1))
    fi
done

# Run solver
START_TIME=$(date +%s.%N)

"$SOLVER" \
    --instance "$INSTANCE" \
    --seed "$SEED" \
    --time-limit "$TIME_LIMIT" \
    --pareto "$PARETO_FILE" \
    "${TRANSFORMED_PARAMS[@]}" > /dev/null 2>&1

SOLVER_EXIT=$?

END_TIME=$(date +%s.%N)
ELAPSED=$(echo "$END_TIME - $START_TIME" | bc)
ELAPSED_INT=$(printf "%.0f" "$ELAPSED")

# Check if solver succeeded
if [ $SOLVER_EXIT -ne 0 ] || [ ! -f "$PARETO_FILE" ]; then
    echo "Inf $ELAPSED_INT"
    exit 0
fi

# Calculate hypervolume
"$HV_CALC" \
    --instance "$INSTANCE" \
    --pareto-0 "$PARETO_FILE" \
    --hypervolume-0 "$HV_FILE" > /dev/null 2>&1

if [ ! -f "$HV_FILE" ]; then
    echo "Inf $ELAPSED_INT"
    exit 0
fi

# Read hypervolume and negate (iRace minimizes, we want to maximize HV)
HV=$(cat "$HV_FILE")
COST=$(echo "-$HV" | bc -l)

echo "$COST $ELAPSED_INT"
