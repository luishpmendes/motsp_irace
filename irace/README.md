# iRace Configuration for NSGA-II (MOTSP)

This directory contains the iRace configuration files for tuning the NSGA-II solver on the Multi-Objective Traveling Salesman Problem (MOTSP).

## Files

- **parameters.txt**: Defines the tunable parameters for NSGA-II
- **scenario.txt**: iRace scenario configuration (budget, instances, etc.)
- **target-runner.sh**: Script that iRace calls to evaluate each configuration

## Parameters Being Tuned

| Parameter | Type | Range | Description |
|-----------|------|-------|-------------|
| `population_size` | integer | [50, 500] | Population size of the genetic algorithm |
| `crossover_probability` | real | [0.50, 1.00] | Probability of applying crossover |
| `crossover_distribution` | real | [1.00, 50.00] | Distribution index for SBX crossover |
| `mutation_probability` | real | [0.00, 0.10] | Probability of mutation per gene |
| `mutation_distribution` | real | [1.00, 50.00] | Distribution index for polynomial mutation |

## Prerequisites

1. **Build the executables**: Ensure the NSGA-II solver and hypervolume calculator are compiled:
   ```bash
   make nsga2_solver_exec hypervolume_calculator_exec
   ```

2. **Install iRace**: Install the iRace R package:
   ```R
   install.packages("irace")
   ```

3. **Prepare instances**: Place training instance files in the `./instances/` directory.

4. **Prepare reference Pareto fronts**: For accurate hypervolume computation, provide reference Pareto front files. The target runner looks for files in these locations (in order):
   - `./instances/<instance_name>_reference_pareto.txt`
   - `./reference_pareto/<instance_name>.txt`
   - `./pareto/<instance_name>_reference.txt`

## Running iRace

From the project root directory, run:

```bash
# Using R
Rscript -e "library(irace); irace.main(scenario = 'irace/scenario.txt')"

# Or using the irace command-line wrapper (if installed)
irace --scenario irace/scenario.txt
```

## Tuning Budget

The default configuration uses:
- **24 hours** total tuning time (`maxTime = 86400` seconds)
- **60 seconds** per solver run (time limit)
- **Sequential execution** (`parallel = 1`)

## Results

After tuning completes, the best configurations are saved in `irace/irace-output.Rdata`. To extract the best parameters:

```R
library(irace)
results <- read_logfile("irace/irace-output.Rdata")

# View best configuration
print(results$allConfigurations[results$iterationElites[[length(results$iterationElites)]], ])

# Or get all elite configurations
getFinalElites(results$scenario, results, n = 5)
```

## Customization

### Adjusting the Time Budget

Modify `maxTime` in `scenario.txt`:
```
maxTime = 43200  # 12 hours
```

### Using Parallel Evaluation

Set `parallel` in `scenario.txt`:
```
parallel = 4  # Run 4 configurations in parallel
```

### Changing the Per-Run Time Limit

Edit `TIME_LIMIT` in `target-runner.sh`:
```bash
TIME_LIMIT=120  # 2 minutes per run
```

## Troubleshooting

1. **"Reference Pareto file not found" warning**: Provide proper reference Pareto fronts for accurate hypervolume computation.

2. **Permission denied**: Ensure `target-runner.sh` is executable:
   ```bash
   chmod +x irace/target-runner.sh
   ```

3. **Executables not found**: Build the project first:
   ```bash
   make nsga2_solver_exec hypervolume_calculator_exec
   ```
