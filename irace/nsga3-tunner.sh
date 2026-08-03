#!/bin/bash
export LC_NUMERIC=C
###############################################################################
# NSGA-III Target Runner for iRace
# 
# Usage: ./nsga3-tunner.sh <config_id> <instance_id> <seed> <instance> [params...]
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
SOLVER="${PROJECT_DIR}/bin/exec/nsga3_solver_exec"
HV_CALC="${PROJECT_DIR}/bin/exec/hypervolume_calculator_exec"

# Time limit per run (seconds)
TIME_LIMIT="${TIME_LIMIT:-900}"

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

# Reject a configuration the solver would refuse, without paying for a run. These are
# the rules of the [forbidden] section of nsga3-parameters.txt, evaluated at the worst
# case of m = 4 objectives, so iRace should never send a rejected configuration here;
# the guard covers manual invocations and acts as a backstop. Defaults match the
# solver's own defaults, for the case of a parameter not being passed at all.
POPULATION_SIZE=300
DIVISIONS=6
DIVISIONS_INNER=0

i=0
while [ $i -lt ${#TRANSFORMED_PARAMS[@]} ]; do
    case "${TRANSFORMED_PARAMS[$i]}" in
        --population-size) POPULATION_SIZE="${TRANSFORMED_PARAMS[$((i+1))]}" ;;
        --divisions)       DIVISIONS="${TRANSFORMED_PARAMS[$((i+1))]}" ;;
        --divisions-inner) DIVISIONS_INNER="${TRANSFORMED_PARAMS[$((i+1))]}" ;;
    esac
    i=$((i + 1))
done

# Upper bound on the number of reference directions: the outer Das and Dennis layer
# plus, when it is enabled, the inner one. pagmo drops inner directions coinciding
# with an outer one, so the true count can only be smaller and this test is safe.
NUM_DIRECTIONS=$(awk -v m=4 -v d="$DIVISIONS" -v di="$DIVISIONS_INNER" '
function layer(m, p,    n, k, r, i) {
    n = m + p - 1
    k = (p < m - 1) ? p : m - 1
    r = 1
    for (i = 1; i <= k; i++) {
        r = r * (n - k + i) / i
    }
    return int(r + 0.5)
}
BEGIN { print layer(m, d) + (di > 0 ? layer(m, di) : 0) }')

if [ "$DIVISIONS_INNER" -gt "$DIVISIONS" ] \
|| [ "$POPULATION_SIZE" -lt 8 ] \
|| [ $((POPULATION_SIZE % 4)) -ne 0 ] \
|| [ "$POPULATION_SIZE" -lt "$NUM_DIRECTIONS" ]; then
    echo "Inf 0"
    exit 0
fi

# Run solver
START_TIME=$(date +%s.%N)

{ "$SOLVER" \
    --instance "$INSTANCE" \
    --seed "$SEED" \
    --time-limit "$TIME_LIMIT" \
    --pareto "$PARETO_FILE" \
    --memory \
    "${TRANSFORMED_PARAMS[@]}" > /dev/null 2>&1; } 2>/dev/null

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
{ "$HV_CALC" \
    --instance "$INSTANCE" \
    --pareto-0 "$PARETO_FILE" \
    --hypervolume-0 "$HV_FILE" > /dev/null 2>&1; } 2>/dev/null

if [ ! -f "$HV_FILE" ]; then
    echo "Inf $ELAPSED_INT"
    exit 0
fi

# Read hypervolume and negate (iRace minimizes, we want to maximize HV)
HV=$(tr -d '[:space:]' < "$HV_FILE")
COST=$(awk -v hv="$HV" 'BEGIN { printf "%.17g", -hv }')

echo "$COST $ELAPSED_INT"
