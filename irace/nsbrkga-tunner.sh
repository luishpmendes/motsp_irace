#!/bin/bash
###############################################################################
# NS-BRKGA Target Runner for iRace
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
TIME_LIMIT=300

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

HV=$(cat "$HV_FILE")
COST=$(echo "-$HV" | bc -l)

echo "$COST $ELAPSED_INT"
