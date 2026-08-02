#include "solver/nsga3/nsga3_solver.hpp"
#include "solver/nsga3/problem.hpp"
// <pagmo/algorithm.hpp> must precede <pagmo/algorithms/nsga3.hpp>: the latter
// uses PAGMO_S11N_ALGORITHM_EXPORT_KEY without including its definition.
#include <pagmo/algorithm.hpp>
#include <pagmo/algorithms/nsga3.hpp>
#include <stdexcept>

namespace motsp {

namespace {

/**********************************************************************
 * Computes the number of reference points NSGA-III generates for the
 * given number of objectives and divisions per objective, that is,
 * the binomial coefficient C(num_objectives + divisions - 1,
 * divisions).
 *
 * pagmo declares n_choose_k in <pagmo/utils/reference_point.hpp> but
 * does not export it from libpagmo, hence this local definition.
 *
 * @param num_objectives the number of objectives.
 * @param divisions the number of divisions per objective.
 *
 * @return the number of reference points.
 **********************************************************************/
std::size_t num_reference_points(std::size_t num_objectives,
                                 std::size_t divisions) {
    std::size_t n = num_objectives + divisions - 1,
                k = std::min(divisions, num_objectives - 1),
                result = 1;

    for(std::size_t i = 1; i <= k; i++) {
        result = (result * (n - k + i)) / i;
    }

    return result;
}

}

NSGA3_Solver::NSGA3_Solver(const Instance & instance)
    : Solver::Solver(instance) {}

NSGA3_Solver::NSGA3_Solver() = default;

void NSGA3_Solver::solve() {
    if(this->crossover_probability < 0.0 ||
       this->crossover_probability > 1.0) {
        throw std::invalid_argument(
                "The crossover probability must be in the range [0, 1], while "
                "a value of " + std::to_string(this->crossover_probability) +
                " was detected.");
    }

    if(this->mutation_probability < 0.0 || this->mutation_probability > 1.0) {
        throw std::invalid_argument(
                "The mutation probability must be in the range [0, 1], while "
                "a value of " + std::to_string(this->mutation_probability) +
                " was detected.");
    }

    if(this->crossover_distribution < 1.0 ||
       this->crossover_distribution > 100.0) {
        throw std::invalid_argument(
                "The distribution index for crossover must be in the range "
                "[1, 100], while a value of " +
                std::to_string(this->crossover_distribution) +
                " was detected.");
    }

    if(this->mutation_distribution < 1.0 ||
       this->mutation_distribution > 100.0) {
        throw std::invalid_argument(
                "The distribution index for mutation must be in the range "
                "[1, 100], while a value of " +
                std::to_string(this->mutation_distribution) +
                " was detected.");
    }

    if(this->divisions == 0) {
        throw std::invalid_argument(
                "The number of divisions per objective must be positive, "
                "while a value of " + std::to_string(this->divisions) +
                " was detected.");
    }

    if(this->population_size < 8 || this->population_size % 4 != 0) {
        throw std::invalid_argument(
                "NSGA-III requires a population size of at least 8 and "
                "divisible by 4, while a value of " +
                std::to_string(this->population_size) + " was detected.");
    }

    if(this->population_size < this->initial_individuals.size()) {
        throw std::invalid_argument(
                "The population size must be at least the number of initial "
                "individuals, while a population size of " +
                std::to_string(this->population_size) + " and " +
                std::to_string(this->initial_individuals.size()) +
                " initial individuals were detected.");
    }

    std::size_t num_ref_points = num_reference_points(
            this->instance.num_objectives, this->divisions);

    if(this->population_size <= num_ref_points) {
        throw std::invalid_argument(
                "NSGA-III requires a population larger than the reference "
                "point set: " +
                std::to_string(this->instance.num_objectives) +
                " objectives with " + std::to_string(this->divisions) +
                " divisions generate " + std::to_string(num_ref_points) +
                " reference points, while the population size is " +
                std::to_string(this->population_size) + ".");
    }

    this->start_time = std::chrono::steady_clock::now();

    pagmo::problem prob{Problem(this->instance)};

    pagmo::algorithm algo{pagmo::nsga3(1,
                                       this->crossover_probability,
                                       this->crossover_distribution,
                                       this->mutation_probability,
                                       this->mutation_distribution,
                                       this->divisions,
                                       this->seed,
                                       this->memory)};

    pagmo::population pop{
        prob,
        this->population_size - this->initial_individuals.size(),
        this->seed};

    for(const auto & individual : this->initial_individuals) {
        pop.push_back(individual.second, individual.first);
    }

    this->update_best_individuals(pop);

    if(this->max_num_snapshots > this->num_snapshots + 1) {
        this->capture_snapshot(pop);

        if (this->time_limit < std::numeric_limits<double>::max()) {
            this->time_snapshot_factor = std::pow(this->time_limit / this->time_last_snapshot, 1.0 / (this->max_num_snapshots - this->num_snapshots));
            this->time_next_snapshot = this->time_last_snapshot * this->time_snapshot_factor;
        } else {
            this->time_next_snapshot = std::numeric_limits<double>::max();
            this->time_snapshot_factor = 1.0;
        }

        if (this->iterations_limit < std::numeric_limits<unsigned>::max()) {
            this->iteration_snapshot_factor = std::pow(this->iterations_limit / (this->iteration_last_snapshot + 1.0), 1.0 / (this->max_num_snapshots - this->num_snapshots));
            this->iteration_next_snapshot = unsigned(std::round(double(this->iteration_last_snapshot) * this->iteration_snapshot_factor));
        } else {
            this->iteration_next_snapshot = std::numeric_limits<unsigned>::max();
            this->iteration_snapshot_factor = 1.0;
        }
    } else {
        this->time_next_snapshot = 0.0;
        this->iteration_next_snapshot = 0;
        this->time_snapshot_factor = 1.0;
        this->iteration_snapshot_factor = 1.0;
    }

    while(!this->are_termination_criteria_met()) {
        this->num_iterations++;
        pop = algo.evolve(pop);
        this->update_best_individuals(pop);

        if(this->max_num_snapshots > this->num_snapshots + 1) {
            if (this->num_iterations >= this->iteration_next_snapshot) {
                this->capture_snapshot(pop);

                if (this->time_limit < std::numeric_limits<double>::max()) {
                    this->time_next_snapshot = this->time_last_snapshot * this->time_snapshot_factor;
                    this->time_snapshot_factor = std::pow(this->time_limit / this->time_last_snapshot, 1.0 / (this->max_num_snapshots - this->num_snapshots));
                }

                if (this->iterations_limit < std::numeric_limits<unsigned>::max()) {
                    this->iteration_next_snapshot = unsigned(std::round(double(this->iteration_last_snapshot) * this->iteration_snapshot_factor));
                    this->iteration_snapshot_factor = std::pow(this->iterations_limit / this->iteration_last_snapshot, 1.0 / (this->max_num_snapshots - this->num_snapshots));
                }
            } else if (this->elapsed_time() >= this->time_next_snapshot) {
                this->capture_snapshot(pop);

                if (this->time_limit < std::numeric_limits<double>::max()) {
                    this->time_next_snapshot = this->time_last_snapshot * this->time_snapshot_factor;
                    this->time_snapshot_factor = std::pow(this->time_limit / this->time_last_snapshot, 1.0 / (this->max_num_snapshots - this->num_snapshots));
                }

                if (this->iterations_limit < std::numeric_limits<unsigned>::max()) {
                    this->iteration_next_snapshot = unsigned(std::round(double(this->iteration_last_snapshot) * this->iteration_snapshot_factor));
                    this->iteration_snapshot_factor = std::pow(this->iterations_limit / this->iteration_last_snapshot, 1.0 / (this->max_num_snapshots - this->num_snapshots));
                }
            }
        }
    }

    if(this->max_num_snapshots > 0) {
        this->capture_snapshot(pop);
    }

    this->best_solutions.clear();

    for(const auto & best_individual : this->best_individuals) {
        this->best_solutions.push_back(Solution(this->instance,
                                                best_individual.second));
    }

    this->solving_time = this->elapsed_time();
}

std::ostream & operator <<(std::ostream & os, const NSGA3_Solver & solver) {
    os << static_cast<const Solver &>(solver)
       << "Population size: " << solver.population_size << std::endl
       << "Crossover probability: " << solver.crossover_probability << std::endl
       << "Distribution index for crossover: " << solver.crossover_distribution
       << std::endl
       << "Mutation probability: " << solver.mutation_probability << std::endl
       << "Distribution index for mutation: " << solver.mutation_distribution
       << std::endl
       << "Reference point divisions: " << solver.divisions << std::endl
       << "Memory: " << solver.memory << std::endl;
    return os;
}

}
