#pragma once

#include "solver/solver.hpp"

namespace motsp {
/****************************************************
 * The NSGA3_Solver represents a solver for the
 * Multi-Objective Travelling Salesman Problem using
 * the Non-Dominated Sorting Genetic Algorithm III.
 ****************************************************/
class NSGA3_Solver : public Solver {
    public:
    /********************************
     * Size of the population.
     ********************************/
    unsigned population_size = 300;

    /************************************
     * Crossover probability.
     ************************************/
    double crossover_probability = 0.95;

    /**************************************
     * Distribution index for crossover.
     **************************************/
    double crossover_distribution = 10.00;

    /***********************************
     * Mutation probability.
     ***********************************/
    double mutation_probability = 0.01;

    /*************************************
     * Distribution index for mutation.
     *************************************/
    double mutation_distribution = 50.00;

    /**********************************************************
     * Number of divisions per objective used to generate the
     * reference point set.
     **********************************************************/
    unsigned divisions = 6;

    /********************************************************************
     * Memory parameter.
     * If true, memory is activated in the algorithm for multiple calls.
     ********************************************************************/
    bool memory = true;

    /*********************************************
     * Constructs a new solver.
     *
     * @param instance the instance to be solved.
     *********************************************/
    NSGA3_Solver(const Instance & instance);

    /******************************
     * Constructs an empty solver.
     ******************************/
    NSGA3_Solver();

    /**********************
     * Solve the instance.
     **********************/
    void solve();

    /***************************************************************
     * Standard stream operator.
     *
     * @param os the standard output stream object.
     * @param solver the solver.
     *
     * @return the stream object.
     ***************************************************************/
    friend std::ostream & operator <<(std::ostream & os,
                                      const NSGA3_Solver & solver);
};

}
