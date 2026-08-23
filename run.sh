#!/bin/bash

instances=(kroAB100 kroAB200 kroAB500 kroAB1000 kroAB2000 kroABC100 kroABC200 kroABC500 kroABC1000 kroABC2000 kroABCD100 kroABCD200 kroABCD500 kroABCD1000 kroABCD2000)
solvers=(nsga2 nsga3 nspso moead mhaco ihs nsbrkga1 nsbrkga2 nsbrkga3 nsbrkga4 nsbrkga5 nsbrkga6)
seeds=(305089489 511812191 608055156 467424509 944441939 414977408 819312498 562386085 287613914 755772793)
versions=(best median)

# Executable each variant runs. A variant absent from this map runs the
# executable of its own name; the six nsbrkga* variants are the iRace ablation
# stages and all share the one NS-BRKGA binary.
declare -A solver_exec=(
    [nsbrkga1]=nsbrkga
    [nsbrkga2]=nsbrkga
    [nsbrkga3]=nsbrkga
    [nsbrkga4]=nsbrkga
    [nsbrkga5]=nsbrkga
    [nsbrkga6]=nsbrkga
)

# Extra flags per variant. Every solver's iRace-tuned configuration is already
# its compiled-in default, so no tuned parameter is repeated here. Two things
# still have to be passed explicitly:
#
#   * --memory and --preserve-diversity are ASSIGNED from the flag's presence
#     (solver.memory = arg_parser.option_exists("--memory")), not merely
#     defaulted, so dropping them would silently switch the feature off.
#   * nsbrkga1..nsbrkga5 are the earlier ablation stages, while the defaults
#     are stage 6, so they carry the best configuration found by iRace for
#     their stage -- restricted to the parameters that actually differ from
#     the stage 6 defaults. Population sizes are the tuned
#     population_size_factor times four, as the target runners compute them,
#     and stage 1's single tuned elite percentage maps to both the minimum and
#     the maximum. A feature a stage switches off needs only its interval set
#     to zero: the solver guards each of them on being positive.
declare -A solver_params=(
    [nsga3]="--memory"
    [nspso]="--memory"
    [moead]="--preserve-diversity"
    [mhaco]="--memory"
    [nsbrkga1]="--population-size 432 --min-elites-percentage 0.35 --max-elites-percentage 0.35 --mutation-distribution 28.39 --num-total-parents 2 --num-elite-parents 1 --bias-type 0 --diversity-type 0 --num-populations 1 --exchange-interval 0 --num-exchange-individuals 1 --pr-interval 0 --shake-interval 0 --reset-interval 0"
    [nsbrkga2]="--population-size 496 --min-elites-percentage 0.33 --max-elites-percentage 0.52 --mutation-distribution 20.03 --num-total-parents 4 --num-elite-parents 4 --bias-type 0 --diversity-type 1 --num-populations 1 --exchange-interval 0 --num-exchange-individuals 1 --pr-interval 0 --shake-interval 0 --reset-interval 0"
    [nsbrkga3]="--population-size 424 --min-elites-percentage 0.21 --max-elites-percentage 0.58 --mutation-distribution 9.28 --num-total-parents 2 --num-elite-parents 2 --bias-type 0 --diversity-type 1 --num-populations 2 --exchange-interval 268 --pr-interval 0 --shake-interval 0 --reset-interval 0"
    [nsbrkga4]="--population-size 484 --min-elites-percentage 0.31 --max-elites-percentage 0.93 --mutation-probability 0.68 --mutation-distribution 13.89 --num-total-parents 2 --num-elite-parents 2 --bias-type 4 --diversity-type 1 --crossover-type 1 --num-populations 2 --exchange-interval 487 --num-exchange-individuals 55 --pr-type 1 --pr-dist-func 2 --pr-percentage 0.39 --pr-interval 32 --shake-interval 0 --reset-interval 0"
    [nsbrkga5]="--population-size 180 --min-elites-percentage 0.33 --max-elites-percentage 0.49 --mutation-probability 0.89 --mutation-distribution 86.39 --num-total-parents 2 --num-elite-parents 2 --diversity-type 0 --crossover-type 1 --num-populations 4 --exchange-interval 401 --num-exchange-individuals 2 --pr-type 1 --pr-dist-func 2 --pr-percentage 0.26 --pr-interval 133 --shake-interval 28 --shake-intensity 0.77 --shake-distribution 41.3 --reset-interval 0"
    [nsbrkga6]=""
)

num_processes=6

time_limit=900
max_num_solutions=500
max_num_snapshots=30
max_ref_solutions=800

path=$(dirname $(realpath $0))

mkdir -p ${path}/statistics
# mkdir -p ${path}/solutions
mkdir -p ${path}/pareto
mkdir -p ${path}/best_solutions_snapshots
mkdir -p ${path}/num_non_dominated_snapshots
mkdir -p ${path}/num_fronts_snapshots
mkdir -p ${path}/populations_snapshots
mkdir -p ${path}/num_elites_snapshots
mkdir -p ${path}/hvr
mkdir -p ${path}/hvr_snapshots
mkdir -p ${path}/nigd_plus
mkdir -p ${path}/nigd_plus_snapshots
mkdir -p ${path}/metrics
mkdir -p ${path}/metrics_snapshots

commands=()

for ((i=0;i<num_processes;i++))
do
    commands[$i]="("
done

i=0

for instance in ${instances[@]}
do
    for solver in ${solvers[@]}
    do
        for seed in ${seeds[@]}
        do
            command="${path}/bin/exec/${solver_exec[$solver]:-$solver}_solver_exec "
            command+="--instance ${path}/instances/${instance}.txt "
            command+="--seed ${seed} "
            command+="--time-limit ${time_limit} "
            command+="--max-num-solutions ${max_num_solutions} "
            command+="--max-num-snapshots ${max_num_snapshots} "
            command+="--statistics ${path}/statistics/${instance}_${solver}_${seed}.txt "
            # command+="--solutions ${path}/solutions/${instance}_${solver}_${seed}_ "
            command+="--pareto ${path}/pareto/${instance}_${solver}_${seed}.txt "
            command+="--best-solutions-snapshots ${path}/best_solutions_snapshots/${instance}_${solver}_${seed}_ "
            command+="--num-non-dominated-snapshots ${path}/num_non_dominated_snapshots/${instance}_${solver}_${seed}.txt "
            command+="--num-fronts-snapshots ${path}/num_fronts_snapshots/${instance}_${solver}_${seed}.txt "
            command+="--populations-snapshots ${path}/populations_snapshots/${instance}_${solver}_${seed}_ "
            command+="${solver_params[$solver]} "
            if [[ $solver == nsbrkga* ]]
            then
                command+="--num-elites-snapshots ${path}/num_elites_snapshots/${instance}_${solver}_${seed}.txt "
            fi
            if [ $i -lt $num_processes ]
            then
                commands[$i]+="$command"
            else
                commands[$((i%num_processes))]+=" && $command"
            fi
            i=$((i+1))
        done
    done
done

for ((i=0;i<num_processes;i++))
do
    commands[$i]+=") &> ${path}/log_${i}.txt"
done

final_command=""

for ((i=0;i<num_processes;i++))
do 
    command=${commands[$i]}
    final_command+="$command & "
done

eval $final_command

wait

commands=()

for ((i=0;i<num_processes;i++))
do
    commands[$i]="("
done

i=0

for instance in ${instances[@]}
do
    command="${path}/bin/exec/reference_pareto_front_calculator_exec "
    command+="--instance ${path}/instances/${instance}.txt "
    command+="--max-num-solutions ${max_ref_solutions} "
    j=0;
    for solver in ${solvers[@]}
    do
        for seed in ${seeds[@]}
        do
            command+="--pareto-${j} ${path}/pareto/${instance}_${solver}_${seed}.txt "
            command+="--best-solutions-snapshots-${j} ${path}/best_solutions_snapshots/${instance}_${solver}_${seed}_ "
            command+="--reference-pareto ${path}/pareto/${instance}.txt "
            j=$((j+1))
        done
    done
    if [ $i -lt $num_processes ]
    then
        commands[$i]+="$command"
    else
        commands[$((i%num_processes))]+=" && $command"
    fi
    i=$((i+1))
done

for ((i=0;i<num_processes;i++))
do
    commands[$i]+=") &>> ${path}/log_${i}.txt"
done

final_command=""

for ((i=0;i<num_processes;i++))
do
    command=${commands[$i]}
    final_command+="$command & "
done

eval $final_command

wait

commands=()

for ((i=0;i<num_processes;i++))
do
    commands[$i]="("
done

i=0

for instance in ${instances[@]}
do
    command="${path}/bin/exec/hypervolume_ratio_calculator_exec "
    command+="--instance ${path}/instances/${instance}.txt "
    command+="--reference-pareto ${path}/pareto/${instance}.txt "
    j=0;
    for solver in ${solvers[@]}
    do
        for seed in ${seeds[@]}
        do
            command+="--pareto-${j} ${path}/pareto/${instance}_${solver}_${seed}.txt "
            command+="--best-solutions-snapshots-${j} ${path}/best_solutions_snapshots/${instance}_${solver}_${seed}_ "
            command+="--hvr-${j} ${path}/hvr/${instance}_${solver}_${seed}.txt "
            command+="--hvr-snapshots-${j} ${path}/hvr_snapshots/${instance}_${solver}_${seed}.txt "
            j=$((j+1))
        done
    done
    if [ $i -lt $num_processes ]
    then
        commands[$i]+="$command"
    else
        commands[$((i%num_processes))]+=" && $command"
    fi
    i=$((i+1))
done

for ((i=0;i<num_processes;i++))
do
    commands[$i]+=") &>> ${path}/log_${i}.txt"
done

final_command=""

for ((i=0;i<num_processes;i++))
do 
    command=${commands[$i]}
    final_command+="$command & "
done

eval $final_command

wait

commands=()

for ((i=0;i<num_processes;i++))
do
    commands[$i]="("
done

i=0

for instance in ${instances[@]}
do
    command="${path}/bin/exec/normalized_modified_generational_distance_calculator_exec "
    command+="--instance ${path}/instances/${instance}.txt "
    command+="--reference-pareto ${path}/pareto/${instance}.txt "
    j=0;
    for solver in ${solvers[@]}
    do
        for seed in ${seeds[@]}
        do
            command+="--pareto-${j} ${path}/pareto/${instance}_${solver}_${seed}.txt "
            command+="--best-solutions-snapshots-${j} ${path}/best_solutions_snapshots/${instance}_${solver}_${seed}_ "
            command+="--nigd-plus-${j} ${path}/nigd_plus/${instance}_${solver}_${seed}.txt "
            command+="--nigd-plus-snapshots-${j} ${path}/nigd_plus_snapshots/${instance}_${solver}_${seed}.txt "
            j=$((j+1))
        done
    done
    if [ $i -lt $num_processes ]
    then
        commands[$i]+="$command"
    else
        commands[$((i%num_processes))]+=" && $command"
    fi
    i=$((i+1))
done

for ((i=0;i<num_processes;i++))
do
    commands[$i]+=") &>> ${path}/log_${i}.txt"
done

final_command=""

for ((i=0;i<num_processes;i++))
do
    command=${commands[$i]}
    final_command+="$command & "
done

eval $final_command

wait


commands=()

for ((i=0;i<num_processes;i++))
do
    commands[$i]="("
done

i=0

for instance in ${instances[@]}
do
    for solver in ${solvers[@]}
    do
        command="${path}/bin/exec/results_aggregator_exec "
        command+="--hvrs ${path}/hvr/${instance}_${solver}.txt "
        command+="--hvr-statistics ${path}/hvr/${instance}_${solver}_stats.txt "
        command+="--nigd-pluses ${path}/nigd_plus/${instance}_${solver}.txt "
        command+="--nigd-plus-statistics ${path}/nigd_plus/${instance}_${solver}_stats.txt "
        command+="--statistics-best ${path}/statistics/${instance}_${solver}_best.txt "
        command+="--statistics-median ${path}/statistics/${instance}_${solver}_median.txt "
        command+="--pareto-best ${path}/pareto/${instance}_${solver}_best.txt "
        command+="--pareto-median ${path}/pareto/${instance}_${solver}_median.txt "
        command+="--hvr-snapshots-best ${path}/hvr_snapshots/${instance}_${solver}_best.txt "
        command+="--hvr-snapshots-median ${path}/hvr_snapshots/${instance}_${solver}_median.txt "
        command+="--best-solutions-snapshots-best ${path}/best_solutions_snapshots/${instance}_${solver}_best_ "
        command+="--best-solutions-snapshots-median ${path}/best_solutions_snapshots/${instance}_${solver}_median_ "
        command+="--num-non-dominated-snapshots-best ${path}/num_non_dominated_snapshots/${instance}_${solver}_best.txt "
        command+="--num-non-dominated-snapshots-median ${path}/num_non_dominated_snapshots/${instance}_${solver}_median.txt "
        command+="--populations-snapshots-best ${path}/populations_snapshots/${instance}_${solver}_best_ "
        command+="--populations-snapshots-median ${path}/populations_snapshots/${instance}_${solver}_median_ "
        command+="--num-fronts-snapshots-best ${path}/num_fronts_snapshots/${instance}_${solver}_best.txt "
        command+="--num-fronts-snapshots-median ${path}/num_fronts_snapshots/${instance}_${solver}_median.txt "
        if [[ $solver == nsbrkga* ]]
        then
            command+="--num-elites-snapshots-best ${path}/num_elites_snapshots/${instance}_${solver}_best.txt "
            command+="--num-elites-snapshots-median ${path}/num_elites_snapshots/${instance}_${solver}_median.txt "
        fi
        j=0;
        for seed in ${seeds[@]}
        do
            command+="--statistics-${j} ${path}/statistics/${instance}_${solver}_${seed}.txt "
            command+="--pareto-${j} ${path}/pareto/${instance}_${solver}_${seed}.txt "
            command+="--hvr-${j} ${path}/hvr/${instance}_${solver}_${seed}.txt "
            command+="--hvr-snapshots-${j} ${path}/hvr_snapshots/${instance}_${solver}_${seed}.txt "
            command+="--nigd-plus-${j} ${path}/nigd_plus/${instance}_${solver}_${seed}.txt "
            command+="--nigd-plus-snapshots-${j} ${path}/nigd_plus_snapshots/${instance}_${solver}_${seed}.txt "
            command+="--best-solutions-snapshots-${j} ${path}/best_solutions_snapshots/${instance}_${solver}_${seed}_ "
            command+="--num-non-dominated-snapshots-${j} ${path}/num_non_dominated_snapshots/${instance}_${solver}_${seed}.txt "
            command+="--populations-snapshots-${j} ${path}/populations_snapshots/${instance}_${solver}_${seed}_ "
            command+="--num-fronts-snapshots-${j} ${path}/num_fronts_snapshots/${instance}_${solver}_${seed}.txt "
            if [[ $solver == nsbrkga* ]]
            then
                command+="--num-elites-snapshots-${j} ${path}/num_elites_snapshots/${instance}_${solver}_${seed}.txt "
            fi
            j=$((j+1))
        done
        if [ $i -lt $num_processes ]
        then
            commands[$i]+="$command"
        else
            commands[$((i%num_processes))]+=" && $command"
        fi
        i=$((i+1))
    done
done

for ((i=0;i<num_processes;i++))
do
    commands[$i]+=") &>> ${path}/log_${i}.txt"
done

final_command=""

for ((i=0;i<num_processes;i++))
do 
    command=${commands[$i]}
    final_command+="$command & "
done

eval $final_command

wait

python3 ${path}/plotter_hvr.py &
python3 ${path}/plotter_hvr_snapshots.py &
python3 ${path}/plotter_nigd_plus.py &
python3 ${path}/plotter_nigd_plus_snapshots.py &
python3 ${path}/plotter_metrics.py &
python3 ${path}/plotter_metrics_snapshots.py &
python3 ${path}/plotter_num_non_dominated_snapshots.py &
python3 ${path}/plotter_num_fronts_snapshots.py &
python3 ${path}/plotter_num_elites_snapshots.py &
python3 ${path}/plotter_pareto.py &
python3 ${path}/plotter_best_solutions_snapshots.py &
python3 ${path}/plotter_populations_snapshots.py

wait

for instance in ${instances[@]}
do
    for version in ${versions[@]}
    do
        ffmpeg -y -r 5 -i ${path}/best_solutions_snapshots/${instance}_${version}_%d.png -c:v libx264 -vf fps=60 -pix_fmt yuv420p ${path}/best_solutions_snapshots/${instance}_${version}.mp4 &
        ffmpeg -y -r 5 -i ${path}/populations_snapshots/${instance}_${version}_%d.png -c:v libx264 -vf fps=60 -pix_fmt yuv420p ${path}/populations_snapshots/${instance}_${version}.mp4

        wait

        rm ${path}/best_solutions_snapshots/${instance}_${version}_*.png &
        rm ${path}/populations_snapshots/${instance}_${version}_*.png

        wait
    done
done

ffmpeg -y -r 5 -i ${path}/hvr_snapshots/snapshot_%d.png -c:v libx264 -vf fps=60 -pix_fmt yuv420p ${path}/hvr_snapshots/hvr.mp4 &
ffmpeg -y -r 5 -i ${path}/nigd_plus_snapshots/snapshot_%d.png -c:v libx264 -vf fps=60 -pix_fmt yuv420p ${path}/nigd_plus_snapshots/nigd_plus.mp4 &
ffmpeg -y -r 5 -i ${path}/metrics_snapshots/raincloud_%d.png -c:v libx264 -vf fps=60 -pix_fmt yuv420p ${path}/metrics_snapshots/raincloud.mp4 &
ffmpeg -y -r 5 -i ${path}/metrics_snapshots/scatter_%d.png -c:v libx264 -vf fps=60 -pix_fmt yuv420p ${path}/metrics_snapshots/scatter.mp4

wait

rm ${path}/hvr_snapshots/snapshot_*.png &
rm ${path}/nigd_plus_snapshots/snapshot_*.png &
rm ${path}/metrics_snapshots/raincloud_*.png &
rm ${path}/metrics_snapshots/scatter_*.png

wait

python3 ${path}/metrics_stats.py > ${path}/metrics_stats.txt
