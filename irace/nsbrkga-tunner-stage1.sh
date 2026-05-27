#!/bin/bash
export LC_NUMERIC=C
###############################################################################
# NS-BRKGA Ablation — Stage 1 Target Runner for iRace
#
# Vanilla NS-BRKGA: single population, fixed elite size, no advanced features.
#
# Special handling: maps --elites-percentage to both --min-elites-percentage
# and --max-elites-percentage with the same value.
###############################################################################

CONFIG_ID="$1"
INSTANCE_ID="$2"
SEED="$3"
INSTANCE="$4"
shift 4
PARAMS=("$@")

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SOLVER="${PROJECT_DIR}/bin/exec/nsbrkga_solver_exec"
HV_CALC="${PROJECT_DIR}/bin/exec/hypervolume_calculator_exec"
TIME_LIMIT=900

TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

PARETO_FILE="${TMPDIR}/pareto.txt"
HV_FILE="${TMPDIR}/hv.txt"

# Transform parameters
TRANSFORMED_PARAMS=()
i=0
while [ $i -lt ${#PARAMS[@]} ]; do
    if [ "${PARAMS[$i]}" = "--population-size-factor" ]; then
        FACTOR="${PARAMS[$((i+1))]}"
        POPULATION_SIZE=$((FACTOR * 4))
        TRANSFORMED_PARAMS+=("--population-size" "$POPULATION_SIZE")
        i=$((i + 2))
    elif [ "${PARAMS[$i]}" = "--elites-percentage" ]; then
        # Stage 1: single elite percentage maps to both min and max
        ELITES_PCT="${PARAMS[$((i+1))]}"
        TRANSFORMED_PARAMS+=("--min-elites-percentage" "$ELITES_PCT")
        TRANSFORMED_PARAMS+=("--max-elites-percentage" "$ELITES_PCT")
        i=$((i + 2))
    else
        TRANSFORMED_PARAMS+=("${PARAMS[$i]}")
        i=$((i + 1))
    fi
done

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

if [ $SOLVER_EXIT -ne 0 ] || [ ! -f "$PARETO_FILE" ]; then
    echo "Inf $ELAPSED_INT"
    exit 0
fi

"$HV_CALC" \
    --instance "$INSTANCE" \
    --pareto-0 "$PARETO_FILE" \
    --hypervolume-0 "$HV_FILE" > /dev/null 2>&1

if [ ! -f "$HV_FILE" ]; then
    echo "Inf $ELAPSED_INT"
    exit 0
fi

HV=$(tr -d '[:space:]' < "$HV_FILE")
COST=$(awk -v hv="$HV" 'BEGIN { printf "%.17g", -hv }')

echo "$COST $ELAPSED_INT"
