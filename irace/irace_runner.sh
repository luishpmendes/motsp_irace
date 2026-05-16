#!/bin/bash

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
Rscript -e "library(irace); irace::irace_cmdline(c('--scenario','nsbrkga-scenario-stage6.txt'))" 2>&1 | tee nsbrkga-stage6-tuning.log

wait
