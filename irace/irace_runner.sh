#!/bin/bash

# ---------------------------------------------------------------------------
# Tuning phase: all jobs run in parallel.
# ---------------------------------------------------------------------------

Rscript -e "library(irace); irace::irace_cmdline(c('--scenario','nsga2-scenario.txt'))" 2>&1 | tee nsga2-tuning.log &
Rscript -e "library(irace); irace::irace_cmdline(c('--scenario','nspso-scenario.txt'))" 2>&1 | tee nspso-tuning.log &
Rscript -e "library(irace); irace::irace_cmdline(c('--scenario','moead-scenario.txt'))" 2>&1 | tee moead-tuning.log &
Rscript -e "library(irace); irace::irace_cmdline(c('--scenario','mhaco-scenario.txt'))" 2>&1 | tee mhaco-tuning.log &
Rscript -e "library(irace); irace::irace_cmdline(c('--scenario','ihs-scenario.txt'))" 2>&1 | tee ihs-tuning.log &
Rscript -e "library(irace); irace::irace_cmdline(c('--scenario','nsbrkga-scenario-stage1.txt'))" 2>&1 | tee nsbrkga-stage1-tuning.log &
Rscript -e "library(irace); irace::irace_cmdline(c('--scenario','nsbrkga-scenario-stage2.txt'))" 2>&1 | tee nsbrkga-stage2-tuning.log &
Rscript -e "library(irace); irace::irace_cmdline(c('--scenario','nsbrkga-scenario-stage3.txt'))" 2>&1 | tee nsbrkga-stage3-tuning.log &
Rscript -e "library(irace); irace::irace_cmdline(c('--scenario','nsbrkga-scenario-stage4.txt'))" 2>&1 | tee nsbrkga-stage4-tuning.log &
Rscript -e "library(irace); irace::irace_cmdline(c('--scenario','nsbrkga-scenario-stage5.txt'))" 2>&1 | tee nsbrkga-stage5-tuning.log &
Rscript -e "library(irace); irace::irace_cmdline(c('--scenario','nsbrkga-scenario-stage6.txt'))" 2>&1 | tee nsbrkga-stage6-tuning.log &

# Wait for all tuning jobs to finish before starting the testing phase.
wait

# ---------------------------------------------------------------------------
# Testing phase: validate the best elite configuration(s) on the independent
# test instances using irace's built-in testing_fromlog().
# Runs sequentially so that target-runner processes do not compete for cores.
# Results are tee'd to *-testing.log files, separate from the tuning logs.
# ---------------------------------------------------------------------------

Rscript -e "library(irace); testing_fromlog(logFile='./irace-nsga2.Rdata', testNbElites=1, testIterationElites=0, testInstancesDir='../instances', testInstancesFile='./test-instances.txt')" 2>&1 | tee nsga2-testing.log

Rscript -e "library(irace); testing_fromlog(logFile='./irace-nspso.Rdata', testNbElites=1, testIterationElites=0, testInstancesDir='../instances', testInstancesFile='./test-instances.txt')" 2>&1 | tee nspso-testing.log

Rscript -e "library(irace); testing_fromlog(logFile='./irace-moead.Rdata', testNbElites=1, testIterationElites=0, testInstancesDir='../instances', testInstancesFile='./test-instances.txt')" 2>&1 | tee moead-testing.log

Rscript -e "library(irace); testing_fromlog(logFile='./irace-mhaco.Rdata', testNbElites=1, testIterationElites=0, testInstancesDir='../instances', testInstancesFile='./test-instances.txt')" 2>&1 | tee mhaco-testing.log

Rscript -e "library(irace); testing_fromlog(logFile='./irace-ihs.Rdata', testNbElites=1, testIterationElites=0, testInstancesDir='../instances', testInstancesFile='./test-instances.txt')" 2>&1 | tee ihs-testing.log

Rscript -e "library(irace); testing_fromlog(logFile='./irace-nsbrkga-stage1.Rdata', testNbElites=1, testIterationElites=0, testInstancesDir='../instances', testInstancesFile='./test-instances.txt')" 2>&1 | tee nsbrkga-stage1-testing.log

Rscript -e "library(irace); testing_fromlog(logFile='./irace-nsbrkga-stage2.Rdata', testNbElites=1, testIterationElites=0, testInstancesDir='../instances', testInstancesFile='./test-instances.txt')" 2>&1 | tee nsbrkga-stage2-testing.log

Rscript -e "library(irace); testing_fromlog(logFile='./irace-nsbrkga-stage3.Rdata', testNbElites=1, testIterationElites=0, testInstancesDir='../instances', testInstancesFile='./test-instances.txt')" 2>&1 | tee nsbrkga-stage3-testing.log

Rscript -e "library(irace); testing_fromlog(logFile='./irace-nsbrkga-stage4.Rdata', testNbElites=1, testIterationElites=0, testInstancesDir='../instances', testInstancesFile='./test-instances.txt')" 2>&1 | tee nsbrkga-stage4-testing.log

Rscript -e "library(irace); testing_fromlog(logFile='./irace-nsbrkga-stage5.Rdata', testNbElites=1, testIterationElites=0, testInstancesDir='../instances', testInstancesFile='./test-instances.txt')" 2>&1 | tee nsbrkga-stage5-testing.log

Rscript -e "library(irace); testing_fromlog(logFile='./irace-nsbrkga-stage6.Rdata', testNbElites=1, testIterationElites=0, testInstancesDir='../instances', testInstancesFile='./test-instances.txt')" 2>&1 | tee nsbrkga-stage6-testing.log
