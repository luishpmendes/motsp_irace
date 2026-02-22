#include "instance/instance.hpp"
#include "utils/argument_parser.hpp"
#include <fstream>
#include <pagmo/utils/hypervolume.hpp>

static inline double
compute_hypervolume(const std::vector<NSBRKGA::Sense> &senses,
                    const std::vector<double> &reference_point,
                    const std::vector<std::vector<double>> &front) {
    std::vector<double> reference_point_prime(reference_point.size());
    std::vector<std::vector<double>> front_prime(front.size());

    for (unsigned i = 0; i < reference_point.size(); i++) {
        if (senses[i] == NSBRKGA::Sense::MINIMIZE) {
            reference_point_prime[i] = reference_point[i];
        } else {
            reference_point_prime[i] = -reference_point[i];
        }
    }

    for (unsigned i = 0; i < front.size(); i++) {
        front_prime[i] = std::vector<double>(front[i].size());
        for (unsigned j = 0; j < front[i].size(); j++) {
            if (senses[j] == NSBRKGA::Sense::MINIMIZE) {
                front_prime[i][j] = front[i][j];
            } else {
                front_prime[i][j] = -front[i][j];
            }
        }
    }

    pagmo::hypervolume hv(front_prime);
    return hv.compute(reference_point_prime);
}

int main(int argc, char *argv[]) {
    Argument_Parser arg_parser(argc, argv);

    if (arg_parser.option_exists("--instance")) {
        std::ifstream ifs;
        motsp::Instance instance;

        ifs.open(arg_parser.option_value("--instance"));

        if (ifs.is_open()) {
            ifs >> instance;

            ifs.close();
        } else {
            throw std::runtime_error("File " +
                                     arg_parser.option_value("--instance") +
                                     " not found.");
        }

        std::vector<double> reference_point = instance.primal_bound;
        std::vector<std::vector<std::vector<double>>> paretos;
        std::vector<std::vector<unsigned>> iteration_snapshots;
        std::vector<std::vector<double>> time_snapshots;
        std::vector<std::vector<std::vector<std::vector<double>>>>
            best_solutions_snapshots;
        unsigned num_solvers;

        for (num_solvers = 0;
             arg_parser.option_exists("--pareto-" +
                                      std::to_string(num_solvers)) ||
             arg_parser.option_exists("--best-solutions-snapshots-" +
                                      std::to_string(num_solvers)) ||
             arg_parser.option_exists("--hypervolume-" +
                                      std::to_string(num_solvers)) ||
             arg_parser.option_exists("--hypervolume-snapshots-" +
                                      std::to_string(num_solvers));
             num_solvers++) {
        }

        paretos.resize(num_solvers);
        iteration_snapshots.resize(num_solvers);
        time_snapshots.resize(num_solvers);
        best_solutions_snapshots.resize(num_solvers);

        for (unsigned i = 0; i < num_solvers; i++) {
            if (arg_parser.option_exists("--pareto-" + std::to_string(i))) {
                ifs.open(
                    arg_parser.option_value("--pareto-" + std::to_string(i)));

                if (ifs.is_open()) {
                    for (std::string line; std::getline(ifs, line);) {
                        std::istringstream iss(line);
                        std::vector<double> cost(instance.num_objectives, 0.0);

                        for (unsigned j = 0; j < instance.num_objectives; j++) {
                            iss >> cost[j];
                        }

                        paretos[i].push_back(cost);
                    }

                    ifs.close();
                } else {
                    throw std::runtime_error(
                        "File " +
                        arg_parser.option_value("--pareto-" +
                                                std::to_string(i)) +
                        " not found.");
                }
            }
        }

        for (unsigned i = 0; i < num_solvers; i++) {
            if (arg_parser.option_exists("--best-solutions-snapshots-" +
                                         std::to_string(i))) {
                std::string best_solutions_snapshots_filename =
                    arg_parser.option_value("--best-solutions-snapshots-" +
                                            std::to_string(i));

                for (unsigned j = 0;; j++) {
                    ifs.open(best_solutions_snapshots_filename +
                             std::to_string(j) + ".txt");

                    if (ifs.is_open()) {
                        unsigned iteration;
                        double time;

                        ifs >> iteration >> time;

                        iteration_snapshots[i].push_back(iteration);
                        time_snapshots[i].push_back(time);
                        best_solutions_snapshots[i].emplace_back();

                        ifs.ignore();

                        for (std::string line; std::getline(ifs, line);) {
                            std::istringstream iss(line);
                            std::vector<double> cost(instance.num_objectives,
                                                     0.0);

                            for (unsigned j = 0; j < instance.num_objectives;
                                 j++) {
                                iss >> cost[j];
                            }

                            best_solutions_snapshots[i].back().push_back(cost);
                        }

                        ifs.close();
                    } else {
                        break;
                    }
                }
            }
        }

        for (unsigned i = 0; i < num_solvers; i++) {
            std::ofstream ofs;

            ofs.open(
                arg_parser.option_value("--hypervolume-" + std::to_string(i)));

            if (ofs.is_open()) {
                double hypervolume = compute_hypervolume(
                    instance.senses, reference_point, paretos[i]);

                assert(hypervolume >= 0.0);

                ofs << hypervolume << std::endl;

                if (ofs.eof() || ofs.fail() || ofs.bad()) {
                    throw std::runtime_error(
                        "Error writing file " +
                        arg_parser.option_value("--hypervolume-" +
                                                std::to_string(i)) +
                        ".");
                }

                ofs.close();
            } else {
                throw std::runtime_error(
                    "File " +
                    arg_parser.option_value("--hypervolume-" +
                                            std::to_string(i)) +
                    " not created.");
            }
        }

        for (unsigned i = 0; i < num_solvers; i++) {
            if (arg_parser.option_exists("--hypervolume-snapshots-" +
                                         std::to_string(i))) {
                std::ofstream ofs;

                ofs.open(arg_parser.option_value("--hypervolume-snapshots-" +
                                                 std::to_string(i)));

                if (ofs.is_open()) {
                    for (unsigned j = 0; j < best_solutions_snapshots[i].size();
                         j++) {
                        double hypervolume = compute_hypervolume(
                            instance.senses, reference_point,
                            best_solutions_snapshots[i][j]);

                        assert(hypervolume >= 0.0);

                        ofs << iteration_snapshots[i][j] << ","
                            << time_snapshots[i][j] << "," << hypervolume
                            << std::endl;

                        if (ofs.eof() || ofs.fail() || ofs.bad()) {
                            throw std::runtime_error(
                                "Error writing file " +
                                arg_parser.option_value(
                                    "--hypervolume-snapshots-" +
                                    std::to_string(i)) +
                                ".");
                        }
                    }

                    ofs.close();
                } else {
                    throw std::runtime_error(
                        "File " +
                        arg_parser.option_value("--hypervolume-snapshots-" +
                                                std::to_string(i)) +
                        " not created.");
                }
            }
        }
    } else {
        std::cerr
            << "./hypervolume_calculator_exec "
            << "--instance <instance_filename> "
            << "--pareto-i <pareto_filename> "
            << "--best-solutions-snapshots-i "
               "<best_solutions_snapshots_filename> "
            << "--hypervolume-i <hypervolume_filename> "
            << "--hypervolume-snapshots-i <hypervolume_snapshots_filename> "
            << std::endl;
    }

    return 0;
}
