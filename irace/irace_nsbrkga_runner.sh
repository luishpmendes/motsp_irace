#!/bin/bash

# Runs the six NS-BRKGA ablation tunings (stages 1-6) in parallel and, only if
# every one of them succeeded, validates the resulting elite configurations on
# the held-out test instances -- exactly once.
#
# This is the NS-BRKGA-only counterpart of irace_runner.sh. It reads, writes
# and deletes NS-BRKGA artifacts only; the baseline algorithms' scenarios,
# logs and .Rdata results are never touched.
#
# Each stage runs two evaluations at a time (irace --parallel 2), so the six
# stages keep 12 single-threaded solvers busy -- 12 of the VM's 16 threads.
# The scenario files are not modified: --parallel on the command line
# overrides their `parallel = 1`, and irace stores the merged scenario in the
# .Rdata log, which testing_fromlog() then reuses for the validation phase.
# Budgets (maxExperiments, targetRunnerTimeout) come from the scenarios as is.
#
# Wall clock, realistic: 2500 evaluations x ~305 s / 2 slots ~= 4.4 days of
# tuning, then 5 elites x 3 test instances / 2 slots ~= 40 min of validation.
#
# The scenario files deliberately carry no test* settings, so irace_cmdline()
# does not run a testing phase of its own; the testing_fromlog() calls below
# are the single validation site.
#
# Usage: irace_nsbrkga_runner.sh [--dry-run]
#   --dry-run  run the preflight checks, print the commands that would be
#              executed, and exit without deleting or launching anything.

# pipefail is required so that a failing Rscript is not masked by the exit
# status of the `tee` at the end of each pipeline.
set -o pipefail

usage() {
    echo "Usage: $(basename "$0") [--dry-run]" >&2
}

DRY_RUN=0

for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown argument: ${arg}" >&2; usage; exit 2 ;;
    esac
done

SCRIPT_PATH="$(readlink -f "$0")"

# Every path below is relative to this script's own directory, which is also
# each scenario's execDir, so the script works from any current directory.
cd "$(dirname "$SCRIPT_PATH")" || exit 1

# Only one copy of this runner may be active: a second one would delete the
# logs of the tunings still in progress. The lock is taken on the script file
# itself, so no lock file is created, and it is inherited by every child
# process, so it is held until the last tuning or validation job has exited.
if ! command -v flock > /dev/null 2>&1; then
    echo "required command not found: flock" >&2
    exit 1
fi

exec 9< "$SCRIPT_PATH"

if ! flock -n 9; then
    echo "Another irace_nsbrkga_runner.sh is already running from $(pwd); nothing was done." >&2
    exit 1
fi

# The six NS-BRKGA ablation stages, in launch order.
STAGES=(1 2 3 4 5 6)

# Concurrent evaluations per stage, and the CPUs the whole run keeps busy.
EVALS_PER_STAGE=2
REQUIRED_CPUS=$(( ${#STAGES[@]} * EVALS_PER_STAGE ))

INSTANCES_DIR="../instances"
EXEC_DIR="../bin/exec"
TRAIN_INSTANCES="./train-instances.txt"
TEST_INSTANCES="./test-instances.txt"
TEST_NB_ELITES=5

# Every evaluation is one single-threaded solver, so each stage must not use
# more than its EVALS_PER_STAGE threads. Cap every threading runtime that could
# start nested threads: OpenMP (solver, if ever built with -fopenmp), the BLAS
# libraries used by R, and data.table, which irace uses and which otherwise
# starts threads on half the CPUs in each of the 6 R processes. These are
# inherited by Rscript, its forked irace workers, the target runners and the
# solvers.
export OMP_NUM_THREADS=1
export OPENBLAS_NUM_THREADS=1
export MKL_NUM_THREADS=1
export R_DATATABLE_NUM_THREADS=1

# The six tunings, as parallel arrays: label, scenario file, log file, the
# console logs of both phases, and the R expressions each phase evaluates.
LABELS=()
SCENARIO_FILES=()
LOG_FILES=()
TUNING_LOGS=()
TESTING_LOGS=()
TUNING_EXPRS=()
TESTING_EXPRS=()

for stage in "${STAGES[@]}"; do
    label="nsbrkga-stage${stage}"
    LABELS+=("$label")
    SCENARIO_FILES+=("nsbrkga-scenario-stage${stage}.txt")
    LOG_FILES+=("./irace-nsbrkga-stage${stage}.Rdata")
    TUNING_LOGS+=("${label}-tuning.log")
    TESTING_LOGS+=("${label}-testing.log")
done

for i in "${!LABELS[@]}"; do
    TUNING_EXPRS+=("library(irace); irace::irace_cmdline(c('--scenario','${SCENARIO_FILES[$i]}','--parallel','${EVALS_PER_STAGE}'))")
    TESTING_EXPRS+=("library(irace); testing_fromlog(logFile='${LOG_FILES[$i]}', testNbElites=${TEST_NB_ELITES}, testIterationElites=0, testInstancesDir='${INSTANCES_DIR}', testInstancesFile='${TEST_INSTANCES}')")
done

# Loads each scenario exactly as irace_cmdline() does, applies the --parallel
# override, and runs irace's own checkScenario() on it, which reads the
# parameter file and checks the target runner and the instances without
# executing anything. Prints one line per scenario; exits 1 on any error.
R_SCENARIO_CHECK='
suppressMessages(library(irace))
args <- commandArgs(trailingOnly = TRUE)
parallel <- as.integer(args[1])
ok <- TRUE
for (f in args[-1]) {
    line <- tryCatch({
        invisible(utils::capture.output({
            s <- readScenario(f)
            s$parallel <- parallel
            s <- checkScenario(s)
        }))
        nb <- s$parameters$nbVariable
        sprintf("%s: maxExperiments=%s, parallel=%s, targetRunnerTimeout=%s, tunable parameters=%s, training instances=%d",
                f, s$maxExperiments, s$parallel, s$targetRunnerTimeout,
                if (is.null(nb)) "NA" else nb, length(s$instances))
    }, error = function(e) {
        ok <<- FALSE
        sprintf("ERROR %s: %s", f, gsub("[[:space:]]+", " ", conditionMessage(e)))
    })
    cat(line, "\n", sep = "")
}
quit(status = if (ok) 0 else 1)
'

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
    local i label tool exe instance list runner param logfile execs problem
    local irace_ok=0 scenarios_ok=1 cpus line

    # Tooling used by this script and by every target runner.
    for tool in Rscript timeout awk sed grep stat nproc; do
        command -v "$tool" > /dev/null 2>&1 \
            || problems+=("required command not found: ${tool}")
    done

    if command -v Rscript > /dev/null 2>&1; then
        if ! Rscript -e 'library(irace)' > /dev/null 2>&1; then
            problems+=("the R package 'irace' is not installed or fails to load")
        else
            irace_ok=1
            echo "[preflight] irace $(Rscript -e 'cat(as.character(packageVersion("irace")))' 2>/dev/null)"
        fi

        # irace runs parallel evaluations through parallel::mclapply().
        Rscript -e 'quit(status = if (requireNamespace("parallel", quietly = TRUE)) 0 else 1)' > /dev/null 2>&1 \
            || problems+=("the R package 'parallel' is not available (needed for --parallel ${EVALS_PER_STAGE})")
    fi

    # The run keeps EVALS_PER_STAGE solvers per stage busy; fewer CPUs than
    # that would oversubscribe them and distort the time-limited evaluations.
    # GNU nproc honours OMP_NUM_THREADS, exported as 1 above, so it is counted
    # without it (still respecting this process's CPU affinity).
    if command -v nproc > /dev/null 2>&1; then
        cpus=$(env -u OMP_NUM_THREADS -u OMP_THREAD_LIMIT nproc)

        if [ "$cpus" -lt "$REQUIRED_CPUS" ]; then
            problems+=("only ${cpus} CPUs available; ${#STAGES[@]} stages x ${EVALS_PER_STAGE} evaluations need ${REQUIRED_CPUS}")
        else
            echo "[preflight] ${cpus} CPUs available; the run uses ${REQUIRED_CPUS} (${#STAGES[@]} stages x ${EVALS_PER_STAGE} evaluations)."
        fi
    fi

    # Scenario, parameter, target-runner and log files for each of the six stages.
    for i in "${!LABELS[@]}"; do
        label="${LABELS[$i]}"

        if [ ! -r "${SCENARIO_FILES[$i]}" ]; then
            problems+=("${label}: missing scenario file ${SCENARIO_FILES[$i]}")
            scenarios_ok=0
            continue
        fi

        runner=$(sed -n 's/^targetRunner[[:space:]]*=[[:space:]]*"\(.*\)"[[:space:]]*$/\1/p' "${SCENARIO_FILES[$i]}")
        param=$(sed -n 's/^parameterFile[[:space:]]*=[[:space:]]*"\(.*\)"[[:space:]]*$/\1/p' "${SCENARIO_FILES[$i]}")
        logfile=$(sed -n 's/^logFile[[:space:]]*=[[:space:]]*"\(.*\)"[[:space:]]*$/\1/p' "${SCENARIO_FILES[$i]}")

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

        # Cleanup, the stale-log check and validation all assume this exact
        # name; anything else could point them at another algorithm's results.
        if [ "$logfile" != "${LOG_FILES[$i]}" ]; then
            problems+=("${label}: logFile in ${SCENARIO_FILES[$i]} is '${logfile}', expected '${LOG_FILES[$i]}'")
        fi
    done

    # Solver and hypervolume executables, derived from the NS-BRKGA runners
    # themselves so this check follows them if they ever point somewhere else.
    execs=$(grep -h '^\(SOLVER\|HV_CALC\)=' ./nsbrkga-tunner-stage*.sh 2>/dev/null \
            | sed 's|.*bin/exec/||; s|"$||' | sort -u)

    if [ -z "$execs" ]; then
        problems+=("could not determine the required executables from ./nsbrkga-tunner-stage*.sh")
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

    # The complete configuration of each stage as irace will see it, including
    # the --parallel override and the parameter file.
    if [ $irace_ok -eq 1 ] && [ $scenarios_ok -eq 1 ]; then
        while IFS= read -r line; do
            case "$line" in
                ERROR*) problems+=("irace scenario check: ${line#ERROR }") ;;
                ?*) echo "[preflight] ${line}" ;;
            esac
        done < <(Rscript -e "$R_SCENARIO_CHECK" "$EVALS_PER_STAGE" "${SCENARIO_FILES[@]}" 2>&1 \
                 || echo "ERROR the scenario check exited with an error")
    fi

    if [ ${#problems[@]} -ne 0 ]; then
        echo "[preflight] FAILED -- nothing was launched:" >&2

        for problem in "${problems[@]}"; do
            echo "  ${problem}" >&2
        done

        return 1
    fi

    echo "[preflight] OK: ${#LABELS[@]} NS-BRKGA scenarios, $(grep -cv '^[[:space:]]*$' "$TRAIN_INSTANCES") training and $(grep -cv '^[[:space:]]*$' "$TEST_INSTANCES") test instances."
    return 0
}

preflight || exit 1

if [ $DRY_RUN -eq 1 ]; then
    echo "[dry-run] Would remove: ${LOG_FILES[*]} ${TUNING_LOGS[*]} ${TESTING_LOGS[*]}"
    echo "[dry-run] Tuning phase (all ${#LABELS[@]} in parallel):"

    for i in "${!LABELS[@]}"; do
        echo "  Rscript -e \"${TUNING_EXPRS[$i]}\" 2>&1 | tee \"${TUNING_LOGS[$i]}\" &"
    done

    echo "[dry-run] Validation phase (all ${#LABELS[@]} in parallel, only if every tuning succeeded):"

    for i in "${!LABELS[@]}"; do
        echo "  Rscript -e \"${TESTING_EXPRS[$i]}\" 2>&1 | tee \"${TESTING_LOGS[$i]}\" &"
    done

    echo "[dry-run] Nothing was deleted or launched."
    exit 0
fi

# ---------------------------------------------------------------------------
# Remove the artifacts of any previous NS-BRKGA run -- and only those, named
# one by one. The validation phase reads the .Rdata log files written by the
# tuning phase, so a stale one from an earlier run must never be left where it
# could be picked up. They are committed, so an unwanted run is recoverable
# with `git checkout HEAD -- <file>...` on exactly these files. The baseline
# algorithms' results and irace.log are left alone.
# ---------------------------------------------------------------------------

rm -f -- "${LOG_FILES[@]}" "${TUNING_LOGS[@]}" "${TESTING_LOGS[@]}"

# ---------------------------------------------------------------------------
# Tuning phase: all six stages run in parallel, each of them running
# EVALS_PER_STAGE evaluations at a time (--parallel on the command line).
# ---------------------------------------------------------------------------

TUNING_START=$(date +%s)

for i in "${!LABELS[@]}"; do
    Rscript -e "${TUNING_EXPRS[$i]}" 2>&1 | tee "${TUNING_LOGS[$i]}" &
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
# testing_fromlog() runs on the scenario stored in each .Rdata log, so it
# inherits the --parallel setting of the tuning phase.
# All jobs run in parallel, as in the tuning phase.
# Results are tee'd to *-testing.log files, separate from the tuning logs.
# ---------------------------------------------------------------------------

for i in "${!LABELS[@]}"; do
    Rscript -e "${TESTING_EXPRS[$i]}" 2>&1 | tee "${TESTING_LOGS[$i]}" &
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
