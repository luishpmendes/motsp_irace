#pragma once

#include "solver/solver.hpp"

namespace motsp {
/****************************************************
 * The NSPSO_Solver represents a solver for the
 * Multi-Objective Travelling Salesman Problem using
 * the Non-Dominated Sorting Particle Swap Optmizer.
 ****************************************************/
class NSPSO_Solver : public Solver {
    public:
    /********************************
     * Size of the population.
     ********************************/
    unsigned population_size = 248;

    /*****************************
     * Particles' inertia weight.
     *****************************/
    double omega = 0.66;

    /**************************************************************
     * Magnitude of the force, applied to the particle’s velocity,
     * in the direction of its previous best position.
     **************************************************************/
    double c1 = 1.59;

    /**************************************************************
     * Magnitude of the force, applied to the particle’s velocity,
     * in the direction of its global best (i.e., leader).
     **************************************************************/
    double c2 = 1.79;

    /***************************
     * Velocity scaling factor.
     ***************************/
    double chi = 0.61;

    /*******************************************************
     * Velocity coefficient
     * (determining the maximum allowed particle velocity).
     *******************************************************/
    double v_coeff = 0.03;

    /****************************************************************
     * Leader selection range parameter
     * (i.e., the leader of each particle is selected among the best
     * leader_selection_range % individuals).
     ****************************************************************/
    unsigned leader_selection_range = 97;

    /**************************************************************************
     * The diversity mechanism used to maintain diversity on the Pareto front.
     **************************************************************************/
    std::string diversity_mechanism = "max min";

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
    NSPSO_Solver(const Instance & instance);

    /******************************
     * Constructs an empty solver.
     ******************************/
    NSPSO_Solver();

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
                                      const NSPSO_Solver & solver);
};

}
