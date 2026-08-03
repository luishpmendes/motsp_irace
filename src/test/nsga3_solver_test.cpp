#include "solver/nsga3/nsga3_solver.hpp"
#include <pagmo/algorithms/nsga3.hpp>
#include <pagmo/detail/reference_point.hpp>
#include <stdexcept>
#include <string>

int main() {
    std::ifstream ifs;
    motsp::Instance instance;
    motsp::NSGA3_Solver solver;

    std::cout << "instances/kroAC100.txt" << std::endl;

    ifs.open("instances/kroAC100.txt");
    assert(ifs.is_open());
    ifs >> instance;
    ifs.close();

    solver = motsp::NSGA3_Solver(instance);

    solver.set_seed(2351389233);
    solver.time_limit = 5.0;
    solver.iterations_limit = 100;
    solver.max_num_solutions = 64;
    solver.population_size = 32;
    solver.max_num_snapshots = 16;
    solver.divisions = 3;

    assert((solver.seed = 2351389233));
    assert(fabs(solver.time_limit - 5.0) <
            std::numeric_limits<double>::epsilon());
    assert(solver.iterations_limit == 100);
    assert(solver.max_num_solutions == 64);
    assert(solver.population_size == 32);
    assert(solver.max_num_snapshots == 16);
    assert(fabs(solver.crossover_probability - 0.95) <
            std::numeric_limits<double>::epsilon());
    assert(fabs(solver.crossover_distribution - 10.00) <
            std::numeric_limits<double>::epsilon());
    assert(fabs(solver.mutation_probability - 0.01) <
            std::numeric_limits<double>::epsilon());
    assert(fabs(solver.mutation_distribution - 50.00) <
            std::numeric_limits<double>::epsilon());
    assert(solver.divisions == 3);
    assert(solver.divisions_inner == 0);
    assert(solver.random_mating);
    assert(solver.memory);

    solver.solve();

    assert(solver.solving_time > 0);

    assert(solver.num_iterations > 0);
    assert(solver.num_iterations <= solver.iterations_limit);

    assert(solver.best_solutions.size() > 0);
    assert(solver.best_solutions.size() <= solver.max_num_solutions);

    assert(solver.num_snapshots == solver.max_num_snapshots);

    assert(solver.best_solutions_snapshots.size() == solver.num_snapshots);
    assert(solver.num_non_dominated_snapshots.size() == solver.num_snapshots);
    assert(solver.num_fronts_snapshots.size() == solver.num_snapshots);
    assert(solver.populations_snapshots.size() == solver.num_snapshots);

    for(const auto & s1 : solver.best_solutions) {
        assert(s1.is_feasible());
        assert(s1.cost.size() == instance.num_objectives);
        assert(s1.cost[0] >= 21282);
        assert(s1.cost[1] >= 20749);

        for(const auto & s2 : solver.best_solutions) {
            assert(!s1.dominates(s2));
            assert(!s2.dominates(s1));
        }
    }

    for(const auto & snapshot : solver.best_solutions_snapshots) {
        assert(std::get<0>(snapshot) >= 0);
        assert(std::get<0>(snapshot) <= solver.num_iterations);
        assert(std::get<1>(snapshot) >= 0.0);
        assert(std::get<1>(snapshot) <= solver.solving_time);
        assert(std::get<2>(snapshot).size() > 0);
        assert(std::get<2>(snapshot).size() <= solver.max_num_solutions);

        for(const auto & s : std::get<2>(snapshot)) {
            assert(s.size() == instance.num_objectives);
            assert(s[0] >= 21282);
            assert(s[1] >= 20749);
        }
    }

    for(const auto & snapshot : solver.num_non_dominated_snapshots) {
        assert(std::get<0>(snapshot) >= 0);
        assert(std::get<0>(snapshot) <= solver.num_iterations);
        assert(std::get<1>(snapshot) >= 0.0);
        assert(std::get<1>(snapshot) <= solver.solving_time);
        assert(std::get<2>(snapshot).size() > 0);
        assert(std::get<2>(snapshot).size() <= solver.max_num_solutions);

        for(const unsigned & num_non_dominated : std::get<2>(snapshot)) {
            assert(num_non_dominated > 0);
            assert(num_non_dominated <= solver.population_size);
        }
    }

    for(const auto & snapshot : solver.num_fronts_snapshots) {
        assert(std::get<0>(snapshot) >= 0);
        assert(std::get<0>(snapshot) <= solver.num_iterations);
        assert(std::get<1>(snapshot) >= 0.0);
        assert(std::get<1>(snapshot) <= solver.solving_time);
        assert(std::get<2>(snapshot).size() > 0);
        assert(std::get<2>(snapshot).size() <= solver.max_num_solutions);

        for(const unsigned & num_fronts : std::get<2>(snapshot)) {
            assert(num_fronts > 0);
            assert(num_fronts < solver.population_size);
        }
    }

    for(const auto & snapshot : solver.populations_snapshots) {
        assert(std::get<0>(snapshot) >= 0);
        assert(std::get<0>(snapshot) <= solver.num_iterations);
        assert(std::get<1>(snapshot) >= 0.0);
        assert(std::get<1>(snapshot) <= solver.solving_time);
        assert(std::get<2>(snapshot).size() > 0);
        assert(std::get<2>(snapshot).size() <= solver.max_num_solutions);

        for(const auto & population : std::get<2>(snapshot)) {
            assert(population.size() == solver.population_size);

            for(const auto & s : population) {
                assert(s.size() == instance.num_objectives);
                assert(s[0] >= 21282);
                assert(s[1] >= 20749);
            }
        }
    }

    std::cout << solver << std::endl;

    std::cout << "Num non dominated snapshots: ";
    for(unsigned i = 0;
        i < solver.num_non_dominated_snapshots.size() - 1;
        i++) {
        std::cout << "(" 
                  << std::get<0>(solver.num_non_dominated_snapshots[i])
                  << ", "
                  << std::get<1>(solver.num_non_dominated_snapshots[i])
                  << ", "
                  << std::accumulate(
            std::get<2>(solver.num_non_dominated_snapshots[i]).begin(),
            std::get<2>(solver.num_non_dominated_snapshots[i]).end(),
            0) / std::get<2>(solver.num_non_dominated_snapshots[i]).size()
                  << "), ";
    }
    std::cout << "("
              << std::get<0>(solver.num_non_dominated_snapshots.back())
              << ", "
              << std::get<1>(solver.num_non_dominated_snapshots.back())
              << ", "
              << std::accumulate(
        std::get<2>(solver.num_non_dominated_snapshots.back()).begin(),
        std::get<2>(solver.num_non_dominated_snapshots.back()).end(),
        0) / std::get<2>(solver.num_non_dominated_snapshots.back()).size()
              << ")" << std::endl;

    std::cout << "Num fronts snapshots: ";
    for(unsigned i = 0; i < solver.num_fronts_snapshots.size() - 1; i++) {
        std::cout << "("
                  << std::get<0>(solver.num_fronts_snapshots[i])
                  << ", "
                  << std::get<1>(solver.num_fronts_snapshots[i])
                  << ", "
                  << std::accumulate(
            std::get<2>(solver.num_fronts_snapshots[i]).begin(),
            std::get<2>(solver.num_fronts_snapshots[i]).end(),
            0) / std::get<2>(solver.num_fronts_snapshots[i]).size()
                  << "), ";
    }
    std::cout << "("
              << std::get<0>(solver.num_fronts_snapshots.back())
              << ", "
              << std::get<1>(solver.num_fronts_snapshots.back())
              << ", "
              << std::accumulate(
        std::get<2>(solver.num_fronts_snapshots.back()).begin(),
        std::get<2>(solver.num_fronts_snapshots.back()).end(),
        0) / std::get<2>(solver.num_fronts_snapshots.back()).size()
              << ")" << std::endl;

    std::cout << "instances/kroAD100.txt" << std::endl;

    ifs.open("instances/kroAD100.txt");
    assert(ifs.is_open());
    ifs >> instance;
    ifs.close();

    solver = motsp::NSGA3_Solver(instance);

    solver.set_seed(2351389233);
    solver.time_limit = 5.0;
    solver.iterations_limit = 100;
    solver.max_num_solutions = 64;
    solver.population_size = 32;
    solver.max_num_snapshots = 16;
    solver.divisions = 3;

    assert((solver.seed = 2351389233));
    assert(fabs(solver.time_limit - 5.0) <
            std::numeric_limits<double>::epsilon());
    assert(solver.iterations_limit == 100);
    assert(solver.max_num_solutions == 64);
    assert(solver.population_size == 32);
    assert(solver.max_num_snapshots == 16);
    assert(fabs(solver.crossover_probability - 0.95) <
            std::numeric_limits<double>::epsilon());
    assert(fabs(solver.crossover_distribution - 10.00) <
            std::numeric_limits<double>::epsilon());
    assert(fabs(solver.mutation_probability - 0.01) <
            std::numeric_limits<double>::epsilon());
    assert(fabs(solver.mutation_distribution - 50.00) <
            std::numeric_limits<double>::epsilon());
    assert(solver.divisions == 3);
    assert(solver.divisions_inner == 0);
    assert(solver.random_mating);
    assert(solver.memory);

    solver.solve();

    assert(solver.solving_time > 0);

    assert(solver.num_iterations > 0);
    assert(solver.num_iterations <= solver.iterations_limit);

    assert(solver.best_solutions.size() > 0);
    assert(solver.best_solutions.size() <= solver.max_num_solutions);

    assert(solver.num_snapshots == solver.max_num_snapshots);

    assert(solver.best_solutions_snapshots.size() == solver.num_snapshots);
    assert(solver.num_non_dominated_snapshots.size() == solver.num_snapshots);
    assert(solver.num_fronts_snapshots.size() == solver.num_snapshots);
    assert(solver.populations_snapshots.size() == solver.num_snapshots);

    for(const auto & s1 : solver.best_solutions) {
        assert(s1.is_feasible());
        assert(s1.cost.size() == instance.num_objectives);
        assert(s1.cost[0] >= 21282);
        assert(s1.cost[1] >= 21294);

        for(const auto & s2 : solver.best_solutions) {
            assert(!s1.dominates(s2));
            assert(!s2.dominates(s1));
        }
    }

    for(const auto & snapshot : solver.best_solutions_snapshots) {
        assert(std::get<0>(snapshot) >= 0);
        assert(std::get<0>(snapshot) <= solver.num_iterations);
        assert(std::get<1>(snapshot) >= 0.0);
        assert(std::get<1>(snapshot) <= solver.solving_time);
        assert(std::get<2>(snapshot).size() > 0);
        assert(std::get<2>(snapshot).size() <= solver.max_num_solutions);

        for(const auto & s : std::get<2>(snapshot)) {
            assert(s.size() == instance.num_objectives);
            assert(s[0] >= 21282);
            assert(s[1] >= 21294);
        }
    }

    for(const auto & snapshot : solver.num_non_dominated_snapshots) {
        assert(std::get<0>(snapshot) >= 0);
        assert(std::get<0>(snapshot) <= solver.num_iterations);
        assert(std::get<1>(snapshot) >= 0.0);
        assert(std::get<1>(snapshot) <= solver.solving_time);
        assert(std::get<2>(snapshot).size() > 0);
        assert(std::get<2>(snapshot).size() <= solver.max_num_solutions);

        for(const unsigned & num_non_dominated : std::get<2>(snapshot)) {
            assert(num_non_dominated > 0);
            assert(num_non_dominated <= solver.population_size);
        }
    }

    for(const auto & snapshot : solver.num_fronts_snapshots) {
        assert(std::get<0>(snapshot) >= 0);
        assert(std::get<0>(snapshot) <= solver.num_iterations);
        assert(std::get<1>(snapshot) >= 0.0);
        assert(std::get<1>(snapshot) <= solver.solving_time);
        assert(std::get<2>(snapshot).size() > 0);
        assert(std::get<2>(snapshot).size() <= solver.max_num_solutions);

        for(const unsigned & num_fronts : std::get<2>(snapshot)) {
            assert(num_fronts > 0);
            assert(num_fronts < solver.population_size);
        }
    }

    for(const auto & snapshot : solver.populations_snapshots) {
        assert(std::get<0>(snapshot) >= 0);
        assert(std::get<0>(snapshot) <= solver.num_iterations);
        assert(std::get<1>(snapshot) >= 0.0);
        assert(std::get<1>(snapshot) <= solver.solving_time);
        assert(std::get<2>(snapshot).size() > 0);
        assert(std::get<2>(snapshot).size() <= solver.max_num_solutions);

        for(const auto & population : std::get<2>(snapshot)) {
            assert(population.size() == solver.population_size);

            for(const auto & s : population) {
                assert(s.size() == instance.num_objectives);
                assert(s[0] >= 21282);
                assert(s[1] >= 21294);
            }
        }
    }

    std::cout << solver << std::endl;

    std::cout << "Num non dominated snapshots: ";
    for(unsigned i = 0;
        i < solver.num_non_dominated_snapshots.size() - 1;
        i++) {
        std::cout << "(" 
                  << std::get<0>(solver.num_non_dominated_snapshots[i])
                  << ", "
                  << std::get<1>(solver.num_non_dominated_snapshots[i])
                  << ", "
                  << std::accumulate(
            std::get<2>(solver.num_non_dominated_snapshots[i]).begin(),
            std::get<2>(solver.num_non_dominated_snapshots[i]).end(),
            0) / std::get<2>(solver.num_non_dominated_snapshots[i]).size()
                  << "), ";
    }
    std::cout << "("
              << std::get<0>(solver.num_non_dominated_snapshots.back())
              << ", "
              << std::get<1>(solver.num_non_dominated_snapshots.back())
              << ", "
              << std::accumulate(
        std::get<2>(solver.num_non_dominated_snapshots.back()).begin(),
        std::get<2>(solver.num_non_dominated_snapshots.back()).end(),
        0) / std::get<2>(solver.num_non_dominated_snapshots.back()).size()
              << ")" << std::endl;

    std::cout << "Num fronts snapshots: ";
    for(unsigned i = 0; i < solver.num_fronts_snapshots.size() - 1; i++) {
        std::cout << "("
                  << std::get<0>(solver.num_fronts_snapshots[i])
                  << ", "
                  << std::get<1>(solver.num_fronts_snapshots[i])
                  << ", "
                  << std::accumulate(
            std::get<2>(solver.num_fronts_snapshots[i]).begin(),
            std::get<2>(solver.num_fronts_snapshots[i]).end(),
            0) / std::get<2>(solver.num_fronts_snapshots[i]).size()
                  << "), ";
    }
    std::cout << "("
              << std::get<0>(solver.num_fronts_snapshots.back())
              << ", "
              << std::get<1>(solver.num_fronts_snapshots.back())
              << ", "
              << std::accumulate(
        std::get<2>(solver.num_fronts_snapshots.back()).begin(),
        std::get<2>(solver.num_fronts_snapshots.back()).end(),
        0) / std::get<2>(solver.num_fronts_snapshots.back()).size()
              << ")" << std::endl;

    std::cout << "instances/kroCD100.txt" << std::endl;

    ifs.open("instances/kroCD100.txt");
    assert(ifs.is_open());
    ifs >> instance;
    ifs.close();

    solver = motsp::NSGA3_Solver(instance);

    solver.set_seed(2351389233);
    solver.time_limit = 5.0;
    solver.iterations_limit = 100;
    solver.max_num_solutions = 64;
    solver.population_size = 32;
    solver.max_num_snapshots = 16;
    solver.divisions = 3;

    assert((solver.seed = 2351389233));
    assert(fabs(solver.time_limit - 5.0) <
            std::numeric_limits<double>::epsilon());
    assert(solver.iterations_limit == 100);
    assert(solver.max_num_solutions == 64);
    assert(solver.population_size == 32);
    assert(solver.max_num_snapshots == 16);
    assert(fabs(solver.crossover_probability - 0.95) <
            std::numeric_limits<double>::epsilon());
    assert(fabs(solver.crossover_distribution - 10.00) <
            std::numeric_limits<double>::epsilon());
    assert(fabs(solver.mutation_probability - 0.01) <
            std::numeric_limits<double>::epsilon());
    assert(fabs(solver.mutation_distribution - 50.00) <
            std::numeric_limits<double>::epsilon());
    assert(solver.divisions == 3);
    assert(solver.divisions_inner == 0);
    assert(solver.random_mating);
    assert(solver.memory);

    solver.solve();

    assert(solver.solving_time > 0);

    assert(solver.num_iterations > 0);
    assert(solver.num_iterations <= solver.iterations_limit);

    assert(solver.best_solutions.size() > 0);
    assert(solver.best_solutions.size() <= solver.max_num_solutions);

    assert(solver.num_snapshots == solver.max_num_snapshots);

    assert(solver.best_solutions_snapshots.size() == solver.num_snapshots);
    assert(solver.num_non_dominated_snapshots.size() == solver.num_snapshots);
    assert(solver.num_fronts_snapshots.size() == solver.num_snapshots);
    assert(solver.populations_snapshots.size() == solver.num_snapshots);

    for(const auto & s1 : solver.best_solutions) {
        assert(s1.is_feasible());
        assert(s1.cost.size() == instance.num_objectives);
        assert(s1.cost[0] >= 20749);
        assert(s1.cost[1] >= 21294);

        for(const auto & s2 : solver.best_solutions) {
            assert(!s1.dominates(s2));
            assert(!s2.dominates(s1));
        }
    }

    for(const auto & snapshot : solver.best_solutions_snapshots) {
        assert(std::get<0>(snapshot) >= 0);
        assert(std::get<0>(snapshot) <= solver.num_iterations);
        assert(std::get<1>(snapshot) >= 0.0);
        assert(std::get<1>(snapshot) <= solver.solving_time);
        assert(std::get<2>(snapshot).size() > 0);
        assert(std::get<2>(snapshot).size() <= solver.max_num_solutions);

        for(const auto & s : std::get<2>(snapshot)) {
            assert(s.size() == instance.num_objectives);
            assert(s[0] >= 20749);
            assert(s[1] >= 21294);
        }
    }

    for(const auto & snapshot : solver.num_non_dominated_snapshots) {
        assert(std::get<0>(snapshot) >= 0);
        assert(std::get<0>(snapshot) <= solver.num_iterations);
        assert(std::get<1>(snapshot) >= 0.0);
        assert(std::get<1>(snapshot) <= solver.solving_time);
        assert(std::get<2>(snapshot).size() > 0);
        assert(std::get<2>(snapshot).size() <= solver.max_num_solutions);

        for(const unsigned & num_non_dominated : std::get<2>(snapshot)) {
            assert(num_non_dominated > 0);
            assert(num_non_dominated <= solver.population_size);
        }
    }

    for(const auto & snapshot : solver.num_fronts_snapshots) {
        assert(std::get<0>(snapshot) >= 0);
        assert(std::get<0>(snapshot) <= solver.num_iterations);
        assert(std::get<1>(snapshot) >= 0.0);
        assert(std::get<1>(snapshot) <= solver.solving_time);
        assert(std::get<2>(snapshot).size() > 0);
        assert(std::get<2>(snapshot).size() <= solver.max_num_solutions);

        for(const unsigned & num_fronts : std::get<2>(snapshot)) {
            assert(num_fronts > 0);
            assert(num_fronts < solver.population_size);
        }
    }

    for(const auto & snapshot : solver.populations_snapshots) {
        assert(std::get<0>(snapshot) >= 0);
        assert(std::get<0>(snapshot) <= solver.num_iterations);
        assert(std::get<1>(snapshot) >= 0.0);
        assert(std::get<1>(snapshot) <= solver.solving_time);
        assert(std::get<2>(snapshot).size() > 0);
        assert(std::get<2>(snapshot).size() <= solver.max_num_solutions);

        for(const auto & population : std::get<2>(snapshot)) {
            assert(population.size() == solver.population_size);

            for(const auto & s : population) {
                assert(s.size() == instance.num_objectives);
                assert(s[0] >= 20749);
                assert(s[1] >= 21294);
            }
        }
    }

    std::cout << solver << std::endl;

    std::cout << "Num non dominated snapshots: ";
    for(unsigned i = 0;
        i < solver.num_non_dominated_snapshots.size() - 1;
        i++) {
        std::cout << "(" 
                  << std::get<0>(solver.num_non_dominated_snapshots[i])
                  << ", "
                  << std::get<1>(solver.num_non_dominated_snapshots[i])
                  << ", "
                  << std::accumulate(
            std::get<2>(solver.num_non_dominated_snapshots[i]).begin(),
            std::get<2>(solver.num_non_dominated_snapshots[i]).end(),
            0) / std::get<2>(solver.num_non_dominated_snapshots[i]).size()
                  << "), ";
    }
    std::cout << "("
              << std::get<0>(solver.num_non_dominated_snapshots.back())
              << ", "
              << std::get<1>(solver.num_non_dominated_snapshots.back())
              << ", "
              << std::accumulate(
        std::get<2>(solver.num_non_dominated_snapshots.back()).begin(),
        std::get<2>(solver.num_non_dominated_snapshots.back()).end(),
        0) / std::get<2>(solver.num_non_dominated_snapshots.back()).size()
              << ")" << std::endl;

    std::cout << "Num fronts snapshots: ";
    for(unsigned i = 0; i < solver.num_fronts_snapshots.size() - 1; i++) {
        std::cout << "("
                  << std::get<0>(solver.num_fronts_snapshots[i])
                  << ", "
                  << std::get<1>(solver.num_fronts_snapshots[i])
                  << ", "
                  << std::accumulate(
            std::get<2>(solver.num_fronts_snapshots[i]).begin(),
            std::get<2>(solver.num_fronts_snapshots[i]).end(),
            0) / std::get<2>(solver.num_fronts_snapshots[i]).size()
                  << "), ";
    }
    std::cout << "("
              << std::get<0>(solver.num_fronts_snapshots.back())
              << ", "
              << std::get<1>(solver.num_fronts_snapshots.back())
              << ", "
              << std::accumulate(
        std::get<2>(solver.num_fronts_snapshots.back()).begin(),
        std::get<2>(solver.num_fronts_snapshots.back()).end(),
        0) / std::get<2>(solver.num_fronts_snapshots.back()).size()
              << ")" << std::endl;

    /**********************************************************************
     * Settings introduced by the migration to the finished NSGA-III
     * implementation of luishpmendes/pagmo2, branch nsga3-finish.
     **********************************************************************/
    std::cout << std::endl << "NSGA-III settings" << std::endl;

    /*  The ten argument constructor. Neither the seed nor the memory flag
     *  may end up on divisions_inner or random_mating, which is what the
     *  old eight argument call silently did against this pagmo.
     */
    pagmo::nsga3 algo(1, 0.95, 10.00, 0.01, 50.00, 3, 0, true, 2351389233u,
                      true);

    assert(algo.get_seed() == 2351389233u);

    std::string extra_info = algo.get_extra_info();

    assert(extra_info.find("Reference direction divisions: 3") !=
            std::string::npos);
    assert(extra_info.find("Reference direction inner divisions: 0") !=
            std::string::npos);
    assert(extra_info.find("Random mating: true") != std::string::npos);
    assert(extra_info.find("Inter-generational memory: true") !=
            std::string::npos);
    assert(extra_info.find("Seed: 2351389233") != std::string::npos);

    ifs.open("instances/kroAC100.txt");
    assert(ifs.is_open());
    ifs >> instance;
    ifs.close();

    /*  Terminates on the iteration limit alone, leaving the time limit at
     *  its default, so that the wall clock cannot influence the result.
     */
    auto solve_and_collect = [&instance](unsigned divisions,
                                         unsigned divisions_inner,
                                         bool random_mating,
                                         unsigned population_size) {
        motsp::NSGA3_Solver solver(instance);

        solver.set_seed(2351389233);
        solver.iterations_limit = 20;
        solver.max_num_solutions = 64;
        solver.max_num_snapshots = 0;
        solver.population_size = population_size;
        solver.divisions = divisions;
        solver.divisions_inner = divisions_inner;
        solver.random_mating = random_mating;

        solver.solve();

        std::vector<std::vector<double>> costs;

        for(const auto & solution : solver.best_solutions) {
            costs.push_back(solution.cost);
        }

        std::sort(costs.begin(), costs.end());

        return costs;
    };

    // The same seed must give the same result, under either mating scheme
    for(bool random_mating : {true, false}) {
        std::vector<std::vector<double>> first =
            solve_and_collect(3, 0, random_mating, 32);
        std::vector<std::vector<double>> second =
            solve_and_collect(3, 0, random_mating, 32);

        assert(!first.empty());
        assert(first == second);

        std::cout << "Random mating " << random_mating << ": "
                  << first.size() << " solutions, reproducible" << std::endl;
    }

    // An inner layer finer than the outer one is rejected
    bool inner_layer_rejected = false;

    try {
        motsp::NSGA3_Solver solver(instance);

        solver.set_seed(2351389233);
        solver.iterations_limit = 1;
        solver.max_num_snapshots = 0;
        solver.population_size = 32;
        solver.divisions = 3;
        solver.divisions_inner = 4;

        solver.solve();
    } catch(const std::invalid_argument &) {
        inner_layer_rejected = true;
    }

    assert(inner_layer_rejected);

    /*  Two objectives with seven outer divisions generate
     *  C(2 + 7 - 1, 7) = 8 reference directions. The finished
     *  implementation accepts a population of exactly that size.
     */
    assert(pagmo::detail::generate_reference_directions(
                instance.num_objectives, 7, 0).size() == 8);

    std::vector<std::vector<double>> equal_costs =
        solve_and_collect(7, 0, true, 8);

    assert(!equal_costs.empty());

    std::cout << "Population equal to the reference direction count: "
              << equal_costs.size() << " solutions" << std::endl;

    /*  Adding an inner layer of three divisions contributes
     *  C(2 + 3 - 1, 3) = 4 further directions, none of which coincides
     *  with an outer one here, for a total of 12.
     */
    assert(pagmo::detail::generate_reference_directions(
                instance.num_objectives, 7, 3).size() == 12);

    /*  The two layers do not simply add up: pagmo drops an inner direction
     *  which coincides with an outer one. With four outer divisions the
     *  outer coordinates are 0, 1/4, 1/2, 3/4 and 1, onto which the single
     *  inner division maps exactly, so both of its directions are dropped
     *  and 5 + 2 gives 5 rather than 7. This is why the iRace forbidden
     *  rule, which cannot express the test, uses the sum as an upper bound.
     */
    assert(pagmo::detail::generate_reference_directions(
                instance.num_objectives, 4, 1).size() == 5);

    // A positive inner layer solves, with the population sized for both layers
    std::vector<std::vector<double>> two_layer_costs =
        solve_and_collect(7, 3, true, 12);

    assert(!two_layer_costs.empty());

    std::cout << "Two layer reference directions: "
              << two_layer_costs.size() << " solutions" << std::endl;

    /*  A population which would have been large enough for the outer layer
     *  alone is rejected once the inner layer is added. Eight individuals
     *  satisfy both the minimum of 5 and the multiple of 4, so it is the
     *  reference direction rule which rejects this, not the size rule.
     */
    bool combined_set_rejected = false;

    try {
        solve_and_collect(7, 3, true, 8);
    } catch(const std::invalid_argument &) {
        combined_set_rejected = true;
    }

    assert(combined_set_rejected);

    std::cout << std::endl << "NSGA3 Solver Test PASSED" << std::endl;

    return 0;
}
