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
- **`test-instances.txt`** — List of test instance filenames used by the testing phase
- **`irace_runner.sh`** — Driver that runs all twelve tunings, then the testing phase

## Prerequisites

1. **R** with the `irace` package installed:
   ```bash
   Rscript -e "install.packages('irace', repos='https://cloud.r-project.org')"
   ```

2. **Compiled solver binaries** in `../bin/exec/`:
   - `nsga2_solver_exec`, `nsbrkga_solver_exec`, etc.
   - `hypervolume_calculator_exec`

3. **Training and test instances** in `../instances/` matching the names in
   `train-instances.txt` and `test-instances.txt`.

## How iRace Calls the Target Runner

iRace invokes the target runner with:
```
./target-runner <config_id> <instance_id> <seed> <instance_path> <params...>
```

- **`<instance_path>`** is formed as `trainInstancesDir/instance_name` (e.g., `../instances/kroAB100.txt`)
- Since `maxTime` is set, the runner **must** print two values: `cost time`
  - `cost`: Negative hypervolume (minimized by iRace → maximized HV)
  - `time`: Elapsed seconds (integer)

On failure, runners print `Inf` as the cost to avoid crashing iRace.

## Quick Start

Run tuning from inside the `irace/` directory:

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

**Everything (all twelve tunings in parallel, then the testing phase):**
```bash
./irace_runner.sh
```

Optional: redirect output to a log:
```bash
Rscript -e "library(irace); irace::irace_cmdline(c('--scenario','nsga2-scenario.txt'))" 2>&1 | tee nsga2-tuning.log
```

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
- `nsga3-tunner.sh` re-checks those rules before launching anything and prints `Inf 0` for
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

- **Temporary folders** (`irace_nsga2/`, `irace_nsbrkga/`, etc.): Created during runs for Pareto files and hypervolume output; cleaned up automatically.

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `Permission denied` | Make runner executable: `chmod +x *-tunner.sh` |
| `command not found` errors | Ensure solver binaries are built in `../bin/exec/` |
| iRace reports non-numeric output | Runner must print exactly `cost time` (two numbers) |
| `No such file or directory` | Check working directory; run from inside `irace/` |
| Instance not found | Verify entries in `train-instances.txt` / `test-instances.txt` match files in `../instances/` |