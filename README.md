# motsp
Multi-Objective Travelling Salesman Problem


## Dependencies

The `Makefile` hardcodes the prefixes below; they are not discovered.

* **pagmo — must be built from the `nsga3-finish` branch of
  [`luishpmendes/pagmo2`](https://github.com/luishpmendes/pagmo2/tree/nsga3-finish), installed to `/opt/pagmo`.**
  `pagmo::nsga3` does not exist in upstream pagmo (2.19.1 or otherwise), so the stock package
  builds every solver except `nsga3_solver_exec`.

  ```bash
  git clone -b nsga3-finish https://github.com/luishpmendes/pagmo2.git
  cmake -S pagmo2 -B pagmo2/build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/opt/pagmo
  cmake --build pagmo2/build -j"$(nproc)"
  sudo cmake --install pagmo2/build
  ```

  Verify with `nm -D /opt/pagmo/lib/libpagmo.so | grep nsga3` — it must print symbols.
* **NS-BRKGA** — header-only, expected as a sibling checkout at `../nsbrkga/nsbrkga`.
* **TBB** and a C++17 compiler (`libtbb-dev`, `g++`).

## Building

`clean` is the first rule, so a bare `make` deletes `bin/`. Use explicit targets, from the
repository root (the tests open `instances/*` by relative path):

```bash
make execs               # all executables
make tests               # builds and runs every test
make all                 # both
make nsga3_solver_test   # one test: builds, links and runs it
```

## Reference Pareto front

`run.sh` builds, for each instance, a reference Pareto front at `pareto/<instance>.txt`.
It is the **exact nondominated union** of every attained solution — the final front of each
solver/seed run plus every best-solutions snapshot — subject only to the `--max-num-solutions`
archive cap (`max_ref_solutions` in `run.sh`). It is written unmodified: the attained objective
values are never scaled, shifted or otherwise improved.

`hypervolume_ratio_calculator_exec` and
`normalized_modified_generational_distance_calculator_exec` use that file directly as the
baseline, via `--reference-pareto`. The hypervolume reference point is `instance.primal_bound`,
derived per instance as a deliberately "bad enough" point; `hypervolume_calculator_exec`, which
iRace uses to score candidate configurations, scores raw hypervolume against the same point.
Tuning and the final experiments therefore share one definition.

Two consequences worth knowing:

* Because the union is capped at `max_ref_solutions`, the stored front is a thinned sample of a
  larger union, so a single run can occasionally enclose slightly more volume than it. The
  hypervolume ratio is then marginally above `1.0` and is reported as is. Raise
  `max_ref_solutions` to tighten this.
* A reference front produced before this behaviour was introduced was improved by 5% and is
  therefore not comparable. Re-run the reference-front stage of `run.sh` before recomputing HVR
  or NIGD+ on any restored dataset.
