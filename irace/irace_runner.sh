#!/bin/bash

# Runs the twelve iRace tunings in parallel and, only if every one of them
# succeeded, validates the resulting elite configurations on the held-out test
# instances -- exactly once.
#
# The scenario files deliberately carry no test* settings, so irace_cmdline()
# does not run a testing phase of its own; the testing_fromlog() calls below
# are the single validation site.

# pipefail is required so that a failing Rscript is not masked by the exit
# status of the `tee` at the end of each pipeline.
set -o pipefail

# Every path below is relative to this script's own directory, which is also
# each scenario's execDir, so the script works from any current directory.
cd "$(dirname "$(readlink -f "$0")")" || exit 1

# Scenario base names, in launch order: the six baseline algorithms followed
# by the six NS-BRKGA ablation stages.
SCENARIOS=(nsga2 nsga3 nspso moead mhaco ihs)
STAGES=(1 2 3 4 5 6)

INSTANCES_DIR="../instances"
EXEC_DIR="../bin/exec"
TRAIN_INSTANCES="./train-instances.txt"
TEST_INSTANCES="./test-instances.txt"
TEST_NB_ELITES=5

# The twelve tunings, as parallel arrays: label, scenario file, log file.
LABELS=()
SCENARIO_FILES=()
LOG_FILES=()

for scenario in "${SCENARIOS[@]}"; do
    LABELS+=("$scenario")
    SCENARIO_FILES+=("${scenario}-scenario.txt")
    LOG_FILES+=("./irace-${scenario}.Rdata")
done

for stage in "${STAGES[@]}"; do
    LABELS+=("nsbrkga-stage${stage}")
    SCENARIO_FILES+=("nsbrkga-scenario-stage${stage}.txt")
    LOG_FILES+=("./irace-nsbrkga-stage${stage}.Rdata")
done

PIDS=()
JOB_LABELS=()
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
            FAILURES+=("${phase}: ${JOB_LABELS[$i]} (exit ${status})")
        fi
    done

    PIDS=()
    JOB_LABELS=()
}

# ---------------------------------------------------------------------------
# Preflight: everything a run needs must be in place before a single solver
# starts, because the tunings take days. All problems are collected and
# reported together rather than failing on the first one.
# ---------------------------------------------------------------------------

preflight() {
    local problems=()
    local i label tool exe instance list runner param execs problem

    # Tooling used by this script and by every target runner.
    for tool in Rscript timeout awk sed grep stat; do
        command -v "$tool" > /dev/null 2>&1 \
            || problems+=("required command not found: ${tool}")
    done

    if command -v Rscript > /dev/null 2>&1; then
        if ! Rscript -e 'library(irace)' > /dev/null 2>&1; then
            problems+=("the R package 'irace' is not installed or fails to load")
        else
            echo "[preflight] irace $(Rscript -e 'cat(as.character(packageVersion("irace")))' 2>/dev/null)"
        fi
    fi

    # Scenario, parameter and target-runner files for each of the twelve jobs.
    for i in "${!LABELS[@]}"; do
        label="${LABELS[$i]}"

        if [ ! -r "${SCENARIO_FILES[$i]}" ]; then
            problems+=("${label}: missing scenario file ${SCENARIO_FILES[$i]}")
            continue
        fi

        runner=$(sed -n 's/^targetRunner[[:space:]]*=[[:space:]]*"\(.*\)"[[:space:]]*$/\1/p' "${SCENARIO_FILES[$i]}")
        param=$(sed -n 's/^parameterFile[[:space:]]*=[[:space:]]*"\(.*\)"[[:space:]]*$/\1/p' "${SCENARIO_FILES[$i]}")

        if [ -z "$runner" ]; then
            problems+=("${label}: no targetRunner in ${SCENARIO_FILES[$i]}")
        elif [ ! -f "$runner" ]; then
            problems+=("${label}: target runner not found: ${runner}")
        elif [ ! -x "$runner" ]; then
            problems+=("${label}: target runner is not executable: ${runner} (chmod +x it)")
        fi

        if [ -z "$param" ]; then
            problems+=("${label}: no parameterFile in ${SCENARIO_FILES[$i]}")
        elif [ ! -r "$param" ]; then
            problems+=("${label}: parameter file not found: ${param}")
        fi
    done

    # Solver and hypervolume executables, derived from the runners themselves
    # so this check follows them if they ever point somewhere else.
    execs=$(grep -h '^\(SOLVER\|HV_CALC\)=' ./*-tunner*.sh 2>/dev/null \
            | sed 's|.*bin/exec/||; s|"$||' | sort -u)

    if [ -z "$execs" ]; then
        problems+=("could not determine the required executables from ./*-tunner*.sh")
    else
        for exe in $execs; do
            if [ ! -f "${EXEC_DIR}/${exe}" ]; then
                problems+=("executable not built: ${EXEC_DIR}/${exe} (run 'make execs' in the repository root)")
            elif [ ! -x "${EXEC_DIR}/${exe}" ]; then
                problems+=("executable is not executable: ${EXEC_DIR}/${exe}")
            fi
        done
    fi

    # Instance lists, and every instance they name.
    for list in "$TRAIN_INSTANCES" "$TEST_INSTANCES"; do
        if [ ! -r "$list" ]; then
            problems+=("missing instance list: ${list}")
            continue
        fi

        if [ "$(grep -cv '^[[:space:]]*$' "$list")" -eq 0 ]; then
            problems+=("instance list is empty: ${list}")
            continue
        fi

        while read -r instance; do
            [ -r "${INSTANCES_DIR}/${instance}" ] \
                || problems+=("${list}: instance not found: ${INSTANCES_DIR}/${instance}")
        done < <(grep -v '^[[:space:]]*$' "$list")
    done

    if [ ${#problems[@]} -ne 0 ]; then
        echo "[preflight] FAILED -- nothing was launched:" >&2

        for problem in "${problems[@]}"; do
            echo "  ${problem}" >&2
        done

        return 1
    fi

    echo "[preflight] OK: ${#LABELS[@]} scenarios, $(grep -cv '^[[:space:]]*$' "$TRAIN_INSTANCES") training and $(grep -cv '^[[:space:]]*$' "$TEST_INSTANCES") test instances."
    return 0
}

preflight || exit 1

# ---------------------------------------------------------------------------
# Remove the artifacts of any previous run. The validation phase reads the
# .Rdata log files written by the tuning phase, so a stale one from an earlier
# run must never be left where it could be picked up. They are committed, so
# an unwanted run is recoverable with `git checkout HEAD -- .`.
# ---------------------------------------------------------------------------

rm -f ./irace-*.Rdata ./irace.log ./*-tuning.log ./*-testing.log

# ---------------------------------------------------------------------------
# Tuning phase: all twelve jobs run in parallel, each of them serial
# (parallel = 1 in every scenario).
# ---------------------------------------------------------------------------

TUNING_START=$(date +%s)

for i in "${!LABELS[@]}"; do
    Rscript -e "library(irace); irace::irace_cmdline(c('--scenario','${SCENARIO_FILES[$i]}'))" 2>&1 | tee "${LABELS[$i]}-tuning.log" &
    PIDS+=("$!")
    JOB_LABELS+=("${LABELS[$i]}")
done

# Wait for all tuning jobs to finish before considering the validation phase.
wait_for_jobs "tuning"

# Every tuning must have produced its log file during this run. An absent file
# means the tuning died; one predating the phase would be a leftover.
for i in "${!LABELS[@]}"; do
    if [ ! -f "${LOG_FILES[$i]}" ]; then
        FAILURES+=("tuning: ${LABELS[$i]} produced no ${LOG_FILES[$i]}")
    elif [ "$(stat -c %Y "${LOG_FILES[$i]}")" -lt "$TUNING_START" ]; then
        FAILURES+=("tuning: ${LOG_FILES[$i]} predates this run (stale)")
    fi
done

# ---------------------------------------------------------------------------
# Validation only makes sense on a complete set of results, so a single failed
# tuning stops the run here rather than validating a partial one.
# ---------------------------------------------------------------------------

if [ ${#FAILURES[@]} -ne 0 ]; then
    echo "Tuning failed; the validation phase was not started." >&2

    for failure in "${FAILURES[@]}"; do
        echo "  ${failure}" >&2
    done

    exit 1
fi

echo "All ${#LABELS[@]} tunings completed successfully; starting validation."

# ---------------------------------------------------------------------------
# Validation phase: validate the best elite configurations on the independent
# test instances using irace's built-in testing_fromlog(). Because the
# scenarios carry no test* settings, the arguments below are the only source
# of the testing configuration, and this is the only place it happens.
# All jobs run in parallel, as in the tuning phase.
# Results are tee'd to *-testing.log files, separate from the tuning logs.
# ---------------------------------------------------------------------------

for i in "${!LABELS[@]}"; do
    Rscript -e "library(irace); testing_fromlog(logFile='${LOG_FILES[$i]}', testNbElites=${TEST_NB_ELITES}, testIterationElites=0, testInstancesDir='${INSTANCES_DIR}', testInstancesFile='${TEST_INSTANCES}')" 2>&1 | tee "${LABELS[$i]}-testing.log" &
    PIDS+=("$!")
    JOB_LABELS+=("${LABELS[$i]}")
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
