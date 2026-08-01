# motsp
Multi-Objective Travelling Salesman Problem


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
