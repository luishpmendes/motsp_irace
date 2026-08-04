#!/bin/bash
export LC_ALL=C
###############################################################################
# MOEA/D Target Runner for iRace
###############################################################################

CONFIG_ID="$1"
INSTANCE_ID="$2"
SEED="$3"
INSTANCE="$4"
shift 4
PARAMS=("$@")

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SOLVER="${PROJECT_DIR}/bin/exec/moead_solver_exec"
HV_CALC="${PROJECT_DIR}/bin/exec/hypervolume_calculator_exec"
TIME_LIMIT="${TIME_LIMIT:-300}"

# Wall-clock backstops nested inside the scenario's targetRunnerTimeout of
# 315 s: the solver is killed at TIME_LIMIT + 5 s and the hypervolume
# calculator at HV_TIMEOUT, so this script always returns a cost on time.
# If irace's own timeout ever fired it would abort the whole tuning.
SOLVER_TIMEOUT=$((TIME_LIMIT + 15))
HV_TIMEOUT=60

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
    elif [ "${PARAMS[$i]}" = "--weight-generation" ]; then
        # Handle weight-generation values that may contain spaces
        VALUE="${PARAMS[$((i+1))]}"
        # Check if the next word is part of a multi-word value
        if [ "$VALUE" = "low" ] && [ "${PARAMS[$((i+2))]}" = "discrepancy" ]; then
            TRANSFORMED_PARAMS+=("--weight-generation" "low discrepancy")
            i=$((i + 3))
        else
            # Single word value (grid, random)
            TRANSFORMED_PARAMS+=("--weight-generation" "$VALUE")
            i=$((i + 2))
        fi
    elif [ "${PARAMS[$i]}" = "--decomposition" ]; then
        # Handle decomposition values (all single words: weighted, tchebycheff, bi)
        VALUE="${PARAMS[$((i+1))]}"
        TRANSFORMED_PARAMS+=("--decomposition" "$VALUE")
        i=$((i + 2))
    else
        TRANSFORMED_PARAMS+=("${PARAMS[$i]}")
        i=$((i + 1))
    fi
done

{ timeout -k 5 "$SOLVER_TIMEOUT" "$SOLVER" \
    --instance "$INSTANCE" \
    --seed "$SEED" \
    --time-limit "$TIME_LIMIT" \
    --pareto "$PARETO_FILE" \
    --preserve-diversity \
    "${TRANSFORMED_PARAMS[@]}" > /dev/null 2>&1; } 2>/dev/null

SOLVER_EXIT=$?

if [ $SOLVER_EXIT -ne 0 ] || [ ! -f "$PARETO_FILE" ]; then
    echo "Inf"
    exit 0
fi

{ timeout -k 2 "$HV_TIMEOUT" "$HV_CALC" \
    --instance "$INSTANCE" \
    --pareto-0 "$PARETO_FILE" \
    --hypervolume-0 "$HV_FILE" > /dev/null 2>&1; } 2>/dev/null

HV_EXIT=$?

if [ $HV_EXIT -ne 0 ] || [ ! -f "$HV_FILE" ]; then
    echo "Inf"
    exit 0
fi

# Read the hypervolume and negate it (iRace minimizes, we want to maximize HV).
# The value must be present, numeric and finite; anything else is a failed run.
if ! COST=$(awk '
    { for (i = 1; i <= NF; i++) { hv = $i; n++ } }
    END {
        if (n != 1) exit 1                  # empty file, or more than one value
        if (hv !~ /^[+-]?([0-9]+(\.[0-9]*)?|\.[0-9]+)([eE][+-]?[0-9]+)?$/) exit 1
        v = hv + 0
        if (v != v) exit 1                  # NaN
        if (v != 0 && v == v * 2) exit 1    # +/-Inf
        printf "%.17g", -v
    }' "$HV_FILE"); then
    echo "Inf"
    exit 0
fi

echo "$COST"
