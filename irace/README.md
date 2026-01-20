To tune NSGA-II parameters run:

Rscript -e "library(irace); irace::irace_cmdline(c('--scenario','nsga2-scenario.txt'))"  >> irace-nsga2.txt

To tune NSPSO parameters run:

Rscript -e "library(irace); irace::irace_cmdline(c('--scenario','nspso-scenario.txt'))" >> irace-nspso.txt