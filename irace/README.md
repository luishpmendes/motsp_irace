# iRace Tuning for MOTSP Solvers

This folder contains iRace configurations for **offline algorithm configuration** (parameter tuning) of multi-objective metaheuristics applied to the Multi-Objective Traveling Salesman Problem (MOTSP).

## Supported Algorithms

| Algorithm | Scenario File | Parameters File | Target Runner |
|-----------|---------------|-----------------|---------------|
| NSGA-II   | `nsga2-scenario.txt` | `nsga2-parameters.txt` | `nsga2-tunner.sh` |
| NSGA-III  | `nsga3-scenario.txt` | `nsga3-parameters.txt` | `nsga3-tunner.sh` |
| NS-BRKGA  | `nsbrkga-scenario-stage<N>.txt` | `nsbrkga-parameters-stage<N>.txt` | `nsbrkga-tunner-stage<N>.sh` (N = 1..6) |
| MOEA/D    | `moead-scenario.txt` | `moead-parameters.txt` | `moead-tunner.sh` |
| NSPSO     | `nspso-scenario.txt` | `nspso-parameters.txt` | `nspso-tunner.sh` |
| IHS       | `ihs-scenario.txt` | `ihs-parameters.txt` | `ihs-tunner.sh` |
| MHACO     | `mhaco-scenario.txt` | `mhaco-parameters.txt` | `mhaco-tunner.sh` |

## Folder Contents

- **`*-scenario.txt`** — iRace scenario configuration (paths, budget, log file)
- **`*-parameters.txt`** — Parameter space definition (name, switch, type, range, constraints)
- **`*-tunner.sh`** — Target runner script that iRace calls to evaluate a configuration
- **`train-instances.txt`** — List of training instance filenames (one per line)
- **`test-instances.txt`** — List of test instance filenames used by the validation phase
- **`irace_runner.sh`** — Driver that runs all twelve tunings and, only if every
  one of them succeeded, the single validation pass

## Prerequisites

`irace_runner.sh` verifies all of the following before it launches anything,
and reports every problem it finds at once — a missing piece costs seconds
instead of being discovered days into a run.

1. **R** with the `irace` package installed:
   ```bash
   Rscript -e "install.packages('irace', repos='https://cloud.r-project.org')"
   ```

2. **Compiled solver binaries** in `../bin/exec/`:
   - `nsga2_solver_exec`, `nsbrkga_solver_exec`, etc.
   - `hypervolume_calculator_exec`

3. **Training and test instances** in `../instances/` matching the names in
   `train-instances.txt` and `test-instances.txt`.

4. **Executable target runners**: `chmod +x *-tunner*.sh`.

5. **`timeout`, `awk`, `sed`, `grep` and `stat`** on `PATH` (coreutils, present
   on any standard Linux). The runners no longer use `bc`.

## How iRace Calls the Target Runner

iRace invokes the target runner with:
```
./target-runner <config_id> <instance_id> <seed> <instance_path> <params...>
```

- **`<instance_path>`** is formed as `trainInstancesDir/instance_name` (e.g., `../instances/kroAB100.txt`)
- The runner prints **exactly one number**: the negated hypervolume. iRace
  minimizes it, so the hypervolume is maximized.

The budget is `maxExperiments`, not `maxTime`, so iRace needs no elapsed time
and the runner reports none.

The runner prints `Inf` — the worst possible cost, which iRace accepts without
aborting — whenever:

- the solver exits non-zero or is killed by its `TIME_LIMIT + 15` s `timeout`;
- the solver writes no Pareto front file;
- `hypervolume_calculator_exec` exits non-zero or is killed by its 60 s `timeout`;
- no hypervolume file is written, or its contents are empty, non-numeric or
  non-finite.

`Inf` is distinct from a hypervolume of 0, reported as `-0`: that is a
legitimate result meaning no point of the front dominated the reference point.

## Quick Start

**Everything (all twelve tunings in parallel, then one validation pass):**
```bash
./irace_runner.sh
```

`irace_runner.sh` changes to its own directory first, so it can be started from
anywhere:
```bash
nohup /path/to/motsp_irace/irace/irace_runner.sh > irace_runner.out 2>&1 &
```
It deletes the artifacts of any previous run (`irace-*.Rdata`, `irace.log`,
`*-tuning.log`, `*-testing.log`) before starting, so validation can never read
a stale result. Those files are committed, so `git checkout HEAD -- .` restores
them if a run was started by mistake.

Run a single tuning from inside the `irace/` directory:

**NSGA-II:**
```bash
Rscript -e "library(irace); irace::irace_cmdline(c('--scenario','nsga2-scenario.txt'))"
```

**NS-BRKGA (one ablation stage, N = 1..6):**
```bash
Rscript -e "library(irace); irace::irace_cmdline(c('--scenario','nsbrkga-scenario-stage1.txt'))"
```

**NSGA-III:**
```bash
Rscript -e "library(irace); irace::irace_cmdline(c('--scenario','nsga3-scenario.txt'))"
```

Optional: redirect output to a log:
```bash
Rscript -e "library(irace); irace::irace_cmdline(c('--scenario','nsga2-scenario.txt'))" 2>&1 | tee nsga2-tuning.log
```

**Check a scenario without running a full tuning:**
```bash
TIME_LIMIT=1 Rscript -e "library(irace); irace::irace_cmdline(c('--check','--scenario','nsga2-scenario.txt'))"
```
`--check` really executes the target runner twice, so `TIME_LIMIT=1` keeps it
to a few seconds. The `irace` executable shipped with the R package is not on
`PATH` by default, hence the `Rscript` form.

**Validate manually after a tuning** (`irace_runner.sh` does this for you):
```bash
Rscript -e "library(irace); testing_fromlog(logFile='./irace-nsga2.Rdata', testNbElites=5, testIterationElites=0, testInstancesDir='../instances', testInstancesFile='./test-instances.txt')"
```
The scenario files carry no `test*` settings, so `irace_cmdline` never runs a
validation phase of its own and the arguments above are the only source of the
validation configuration. This is what makes validation happen exactly once.

## Budget and Reproducibility

| Setting | Value | Source |
|---------|-------|--------|
| Solver time limit | 300 s (override with `TIME_LIMIT`) | Tuning budget only |
| Hard cap per evaluation | 330 s | `targetRunnerTimeout` in each scenario |
| iRace budget per scenario | `maxExperiments = 2500` | Fixed evaluation count, equal across scenarios |
| Concurrency | 12 tunings in parallel, then 12 validations in parallel | `irace_runner.sh` on 16 cores |
| Validation elites | 5 | `testNbElites` argument in `irace_runner.sh` |
| Test instances | 3 | `test-instances.txt` |

The budget is an **experiment count**, not a time budget: iRace stops after
2500 evaluations of the target runner. `maxTime` is deliberately absent —
iRace 4.x treats `maxExperiments` and `maxTime` as mutually exclusive and
aborts with "Two different tuning budgets provided" if both are set.

The 300 s tuning limit **deliberately differs** from `run.sh`'s
`time_limit=900` used for the final experiments: it buys 2500 evaluations per
scenario within a predictable budget. Configurations are therefore selected
under a shorter per-run budget than the one they are finally measured under.

### Nested time limits

Four limits bound each evaluation. The intent is that a slow or hung run costs
a single `Inf` rather than the whole tuning — see the caveat below:

| Limit | Value | Enforced by | Effect when it fires |
|-------|-------|-------------|----------------------|
| Solver budget | `TIME_LIMIT` = 300 s | the solver's own `--time-limit` | normal termination, real cost |
| Solver kill | `TIME_LIMIT + 15` = 315 s, SIGKILL at 320 s (`timeout -k 5`) | `timeout` in the target runner | runner prints `Inf` |
| Hypervolume kill | `HV_TIMEOUT` = 60 s, SIGKILL at 62 s (`timeout -k 2`) | `timeout` in the target runner | runner prints `Inf` |
| Hard cap | 330 s | `targetRunnerTimeout` in the scenario | **aborts that whole tuning** |

> **⚠ The nesting is currently incomplete — the hard cap is reachable.**
>
> The two runner timeouts run in sequence, not in parallel, so the cap has to
> dominate their sum, and 330 s does not:
>
> - **Solver killed.** The runner gives up at 315 s, 320 s if the process
>   ignores SIGTERM, and prints `Inf` without ever calling the hypervolume
>   calculator. Inside the cap.
> - **Solver finishes normally.** It self-stops at ≈ 300 s, and only then does
>   the hypervolume calculator start, with up to 62 s of its own. The runner can
>   return as late as **≈ 362 s** — past the 330 s cap.
>
> `targetRunnerTimeout` is not a per-evaluation `Inf`: iRace passes it to R's
> `system2(timeout=)` and turns an expiry into a fatal `targetRunner` error,
> which ends that scenario's **entire run**. One slow hypervolume call can
> therefore throw away days of tuning.
>
> Restoring the invariant needs either `targetRunnerTimeout >= 382`
> (= 320 s solver kill + 62 s hypervolume kill) in every `*-scenario*.txt`, or
> an `HV_TIMEOUT` small enough that `300 + HV_TIMEOUT + 2 < 330`, i.e. at most
> 27 s. Neither is applied here.

### Wall clock

Two bounds, because they lead to different conclusions.

**Worst case** — every evaluation runs to the 330 s hard cap. This is an upper
bound on a run that *survives*: an evaluation that actually reached the cap
would abort its scenario, so nothing slower can also finish.

| Phase | Formula | Time |
|-------|---------|------|
| Tuning — 12 scenarios in parallel, `parallel = 1`, so 2500 serial evaluations each | 2500 × 330 s | 825 000 s = 9.549 d |
| Validation — 12 jobs in parallel, 5 elites × 3 test instances each | 5 × 3 × 330 s | 4 950 s = 1.375 h |
| **This repository** | | **829 950 s = 9.606 d** |

**Realistic** — the solver stops itself at 300 s and the hypervolume call takes
seconds, so ≈ 305 s per evaluation.

| Phase | Formula | Time |
|-------|---------|------|
| Tuning | 2500 × 305 s | 762 500 s = 8.825 d |
| Validation | 5 × 3 × 305 s | 4 575 s = 1.271 h |
| **This repository** | | **767 075 s = 8.878 d** |

Validation is 0.6 % of tuning either way, so it adds no meaningful time.

Running the three repositories one after another — all three use 5 training and
3 test instances, so their totals are identical:

| Bound | Per repository | Three repositories | vs. the 28 d (2 419 200 s) budget |
|-------|----------------|--------------------|-----------------------------------|
| Worst case, 330 s/eval | 829 950 s | 2 489 850 s = 28.818 d | **over by 70 650 s ≈ 19.6 h** |
| Realistic, 305 s/eval | 767 075 s | 2 301 225 s = 26.634 d | under by 117 975 s ≈ 32.8 h |

**The plan fits 28 days only if evaluations behave normally.** The worst case no
longer does, and there is no headroom to buy back: tuning alone is
3 × 2500 × 330 s = 28.65 d at the cap, so neither `maxExperiments = 2500` nor
the 330 s cap can be raised. What makes the realistic figure hold is that the
solver stops itself at 300 s, rejected NSGA-III configurations return `Inf`
immediately, and iRace eliminates weak configurations long before spending the
full budget on them. iRace's own per-iteration overhead (model update, I/O) is
minutes per scenario and fits inside the realistic margin.

Run one repository at a time — three at once would put 36 solvers on 16 cores
and each evaluation would get well under a full core.

## Notes on Parameter Files

### Format
Each parameter is defined as:
```
name  "switch"  type  (min, max)  [condition]
```
where `type` is: `i` (integer), `r` (real), `c` (categorical).

### NSGA-II Parameters
- **`population_size_factor`**: The runner multiplies this by 4 → actual `population_size` (range 100–500).
- Other params: `crossover_probability`, `crossover_distribution`, `mutation_probability`, `mutation_distribution`.

### NSGA-III Parameters
- Same five parameters as NSGA-II, plus **`divisions`** (range `1..10`) and
  **`divisions_inner`** — the number of divisions per objective of the outer and of the
  optional inner layer of reference directions.
- NSGA-III builds its reference directions as an outer Das and Dennis layer of
  `C(m + divisions - 1, divisions)` directions for an `m`-objective instance plus, when
  `divisions_inner > 0`, an inner layer of `C(m + divisions_inner - 1, divisions_inner)`
  directions. **`divisions_inner = 0` disables the inner layer entirely** and contributes
  no direction, which is why it is excluded from the sum rather than counted as `C(m-1, 0) = 1`.
- pagmo requires **`population_size >= the direction count`** — equality is permitted — on
  top of the usual **`population_size` divisible by 4** (which `population_size_factor × 4`
  guarantees), and **`divisions_inner <= divisions`**.
- `divisions_inner` uses the dependent domain `i (0, "min(divisions, 5)")`. The
  `divisions` cap is pagmo's own rule, expressed in the domain so no sample is ever wasted
  on it; the cap of 5 follows Deb and Jain, who introduce the inner layer only for
  many-objective problems and never use more than two divisions for it.
- The `[forbidden]` rule
  `population_size_factor * 4 < choose(4 + divisions - 1, divisions) + ifelse(divisions_inner > 0, choose(4 + divisions_inner - 1, divisions_inner), 0)`
  evaluates that bound at `m = 4`, the largest objective count in the instance set
  (`kroABCD*`), so no sampled configuration can be rejected on any instance.
  It is an **upper bound**: pagmo drops any inner direction which coincides with an outer
  one, and iRace cannot express that test, so the rule is conservative. At `m = 4` the two
  grids can only meet when `divisions` is 8, where the bound overshoots by 4 to 35
  directions; for every other value of `divisions` it is exact.
- `nsga3-tunner.sh` re-checks those rules before launching anything and prints `Inf` for
  a configuration that would be rejected, so no solver time is wasted. iRace should never
  produce one; the guard covers manual invocations.
- `random_mating` remains **untuned** at its default `true`, the mating scheme of the
  original NSGA-III paper. It is configurable on the executable via `--random-mating <0|1>`
  if a later study needs it.
- `nsga3-tunner.sh` always passes `--memory`, matching how `run.sh` invokes the solver, so
  tuning and the final experiments use the same algorithm configuration.
- The solver validates all of the above itself and aborts with an explicit message rather than
  running an invalid configuration.

### NS-BRKGA Parameters
- Uses the same `population_size_factor` convention.
- **Forbidden constraints** (in `[forbidden]` section):
  - `min_elites_percentage >= max_elites_percentage` — rejected
  - `num_elite_parents > num_total_parents` — rejected
  - `shake_interval >= reset_interval` — rejected (stage 6 only)

## Output Artifacts

- **`irace-*.Rdata`**: The `logFile` containing all iRace results. Load in R to inspect elite configurations:
  ```r
  load("irace-nsga2.Rdata")
  print(iraceResults$allElites[[length(iraceResults$allElites)]])
  ```
  `irace_runner.sh` deletes these at startup, so they always describe the most
  recent run.

- **`<label>-tuning.log` / `<label>-testing.log`**: console output of each
  tuning and of each validation job, one pair per scenario. Also deleted at
  startup.

- **Scratch files**: every target-runner invocation creates its own `mktemp -d`
  directory for the Pareto front and the hypervolume output, and removes it on
  exit.

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `[preflight] FAILED` | Fix every problem listed; nothing was launched. |
| `target runner is not executable` | `chmod +x *-tunner*.sh` |
| `executable not built` | Build the solvers: `make execs` from the repository root |
| `instance not found` | Verify entries in `train-instances.txt` / `test-instances.txt` match files in `../instances/` |
| `Tuning failed; the validation phase was not started.` | One or more tunings died. Read the named `<label>-tuning.log`, fix the cause and re-run; the script exits 1 and validates nothing. |
| iRace reports non-numeric output | The runner must print exactly one number. Try it by hand: `TIME_LIMIT=1 ./nsga2-tunner.sh 1 1 1234 ../instances/kroAB100.txt` |
| `terminated before completion` from `targetRunner` | An evaluation exceeded `targetRunnerTimeout = 330 s`, and that scenario's whole tuning is over. This is **reachable** — see [Nested time limits](#nested-time-limits): a solver finishing near 300 s followed by a slow hypervolume call reaches ≈ 362 s. Check `hypervolume_calculator_exec` and `HV_TIMEOUT` first, then a solver ignoring `--time-limit`. |
| `No such file or directory` | `irace_runner.sh` works from any directory, but the single-scenario commands above must be run from inside `irace/`. |
