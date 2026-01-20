#!/bin/bash
###############################################################################
# iRace Target Runner Script for NSPSO Solver (MOTSP)
#
# This script is called by iRace to evaluate a single configuration.
# Arguments passed by iRace:
#   $1: Experiment ID (configuration ID)
#   $2: Instance ID (index)
#   $3: Random seed for this run
#   $4: Instance file path
#   $5+: Parameter settings (e.g., --population-size 100 --crossover-probability 0.8 ...)
#
# Output: A single line with "cost time" where:
#   - cost: Negative hypervolume (to minimize in iRace, thus maximizing hypervolume)
#   - time: Elapsed time in seconds
###############################################################################

# Exit on error
set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Parse iRace arguments
CONFIG_ID="$1"
INSTANCE_ID="$2"
SEED="$3"
INSTANCE="$4"
shift 4
# Remaining arguments are the tunable parameters
PARAMS=("$@")

# Transform --population-size-factor to --population-size (multiply by 4)
# This ensures population_size is always a multiple of 4
TRANSFORMED_PARAMS=()
i=0
while [ $i -lt ${#PARAMS[@]} ]; do
    if [ "${PARAMS[$i]}" = "--population-size-factor" ]; then
        FACTOR="${PARAMS[$((i+1))]}"
        POPULATION_SIZE=$((FACTOR * 4))
        TRANSFORMED_PARAMS+=("--population-size" "$POPULATION_SIZE")
        i=$((i + 2))
    elif [ "${PARAMS[$i]}" = "--diversity-mechanism" ]; then
        # Handle diversity-mechanism values that may contain spaces
        VALUE="${PARAMS[$((i+1))]}"
        # Check if the next word is part of a multi-word value
        if [ "$VALUE" = "crowding" ] && [ "${PARAMS[$((i+2))]}" = "distance" ]; then
            TRANSFORMED_PARAMS+=("--diversity-mechanism" "crowding distance")
            i=$((i + 3))
        elif [ "$VALUE" = "niche" ] && [ "${PARAMS[$((i+2))]}" = "count" ]; then
            TRANSFORMED_PARAMS+=("--diversity-mechanism" "niche count")
            i=$((i + 3))
        elif [ "$VALUE" = "max" ] && [ "${PARAMS[$((i+2))]}" = "min" ]; then
            TRANSFORMED_PARAMS+=("--diversity-mechanism" "max min")
            i=$((i + 3))
        else
            # Single word value (shouldn't happen but handle it)
            TRANSFORMED_PARAMS+=("--diversity-mechanism" "$VALUE")
            i=$((i + 2))
        fi
    else
        TRANSFORMED_PARAMS+=("${PARAMS[$i]}")
        i=$((i + 1))
    fi
done
PARAMS=("${TRANSFORMED_PARAMS[@]}")

# Executables (adjust paths if needed)
SOLVER="${PROJECT_DIR}/bin/exec/nspso_solver_exec"
HV_CALC="${PROJECT_DIR}/bin/exec/hypervolume_calculator_exec"

# Fixed solver settings
TIME_LIMIT=300  # Each run is capped at 5 minutes (300 seconds)

# Create directory for this run
mkdir -p "${PROJECT_DIR}/irace/irace_nspso"
TMP_DIR="${PROJECT_DIR}/irace/irace_nspso"
PARETO_FILE="${TMP_DIR}/pareto.txt"
HV_FILE="${TMP_DIR}/hv.txt"

# Cleanup function to remove temporary files
cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

# Record start time (ns)
START_TIME_NS=$(date +%s%N)

# Run the NSPSO solver with the given configuration
if ! "$SOLVER" \
    --instance "$INSTANCE" \
    --seed "$SEED" \
    --time-limit "$TIME_LIMIT" \
    --pareto "$PARETO_FILE" \
    "${PARAMS[@]}" \
    > /dev/null 2>&1; then
    # Print the failed command for debugging
    END_TIME_NS=$(date +%s%N)
    ELAPSED_NS=$((END_TIME_NS - START_TIME_NS))
    ELAPSED_INT=$(( (ELAPSED_NS + 500000000) / 1000000000 ))
    echo "1e18 $ELAPSED_INT"
    exit 0
fi

# Record end time (ns) and compute elapsed seconds
END_TIME_NS=$(date +%s%N)
ELAPSED_NS=$((END_TIME_NS - START_TIME_NS))
ELAPSED_INT=$(( (ELAPSED_NS + 500000000) / 1000000000 ))

# Check if Pareto file was created and has content
if [ ! -s "$PARETO_FILE" ]; then
    # No solutions found - return a very high cost (worst case)
    echo "1e18 $ELAPSED_INT"
    exit 0
fi

# Compute hypervolume using the hypervolume calculator
if ! "$HV_CALC" \
    --instance "$INSTANCE" \
    --pareto-0 "$PARETO_FILE" \
    --hypervolume-0 "$HV_FILE" \
    > /dev/null 2>&1; then
    # Print failed command
    echo "Failed to compute hypervolume"
    echo "$HV_CALC --instance $INSTANCE --pareto-0 $PARETO_FILE --hypervolume-0 $HV_FILE"
    echo "1e18 $ELAPSED_INT"
    exit 0
fi

# Read the hypervolume value
if [ -s "$HV_FILE" ]; then
    HV=$(tr -d '[:space:]' < "$HV_FILE")
else
    # If hypervolume computation failed, return worst cost
    exit 0
fi

# Compute cost as negative hypervolume (to minimize in iRace = maximize HV)
# Output the result in iRace format: "cost time"
echo "-$HV $ELAPSED_INT"

exit 0
