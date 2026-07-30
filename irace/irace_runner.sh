#!/bin/bash

# pipefail is required so that a failing Rscript is not masked by the exit
# status of the `tee` at the end of each pipeline.
set -o pipefail

# Scenario base names, in launch order: the five baseline algorithms followed
# by the six NS-BRKGA ablation stages.
SCENARIOS=(nsga2 nspso moead mhaco ihs)
STAGES=(1 2 3 4 5 6)

PIDS=()
LABELS=()
FAILURES=()

# Waits for every job launched since the last call and records the ones that
# failed, without aborting the jobs that are still running.
wait_for_jobs() {
    local phase="$1"
    local i status

    for i in "${!PIDS[@]}"; do
        wait "${PIDS[$i]}"
        status=$?

        if [ $status -ne 0 ]; then
            FAILURES+=("${phase}: ${LABELS[$i]} (exit ${status})")
        fi
    done

    PIDS=()
    LABELS=()
}

# ---------------------------------------------------------------------------
# Tuning phase: all jobs run in parallel.
# ---------------------------------------------------------------------------

for scenario in "${SCENARIOS[@]}"; do
    Rscript -e "library(irace); irace::irace_cmdline(c('--scenario','${scenario}-scenario.txt'))" 2>&1 | tee "${scenario}-tuning.log" &
    PIDS+=("$!")
    LABELS+=("$scenario")
done

for stage in "${STAGES[@]}"; do
    Rscript -e "library(irace); irace::irace_cmdline(c('--scenario','nsbrkga-scenario-stage${stage}.txt'))" 2>&1 | tee "nsbrkga-stage${stage}-tuning.log" &
    PIDS+=("$!")
    LABELS+=("nsbrkga-stage${stage}")
done

# Wait for all tuning jobs to finish before starting the testing phase.
wait_for_jobs "tuning"

# ---------------------------------------------------------------------------
# Testing phase: validate the best elite configurations on the independent
# test instances using irace's built-in testing_fromlog().
# All jobs run in parallel, as in the tuning phase.
# Results are tee'd to *-testing.log files, separate from the tuning logs.
# ---------------------------------------------------------------------------

for scenario in "${SCENARIOS[@]}"; do
    Rscript -e "library(irace); testing_fromlog(logFile='./irace-${scenario}.Rdata', testNbElites=5, testIterationElites=0, testInstancesDir='../instances', testInstancesFile='./test-instances.txt')" 2>&1 | tee "${scenario}-testing.log" &
    PIDS+=("$!")
    LABELS+=("$scenario")
done

for stage in "${STAGES[@]}"; do
    Rscript -e "library(irace); testing_fromlog(logFile='./irace-nsbrkga-stage${stage}.Rdata', testNbElites=5, testIterationElites=0, testInstancesDir='../instances', testInstancesFile='./test-instances.txt')" 2>&1 | tee "nsbrkga-stage${stage}-testing.log" &
    PIDS+=("$!")
    LABELS+=("nsbrkga-stage${stage}")
done

# Wait for all testing jobs to finish before exiting.
wait_for_jobs "testing"

# ---------------------------------------------------------------------------
# Report.
# ---------------------------------------------------------------------------

if [ ${#FAILURES[@]} -ne 0 ]; then
    echo "The following jobs failed:" >&2

    for failure in "${FAILURES[@]}"; do
        echo "  ${failure}" >&2
    done

    exit 1
fi

echo "All tuning and testing jobs completed successfully."

exit 0
