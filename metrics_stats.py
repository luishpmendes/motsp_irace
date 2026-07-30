import csv
import os
import numpy as np
from plotter_definitions import *

dirname = os.path.dirname(__file__)

hvr_per_solver_per_instance = {}
hvr_per_solver = {}

for solver in solvers:
    hvr_per_solver_per_instance[solver] = {}
    hvr_per_solver[solver] = []

    for instance in instances:
        hvr_per_solver_per_instance[solver][instance] = []

        filename = os.path.join(dirname, "hvr/" + instance + "_" + solver + ".txt")
        if os.path.exists(filename):
            with open(filename) as csv_file:
                data = csv.reader(csv_file)
                for row in data:
                    hvr_per_solver_per_instance[solver][instance].append(float(row[0]))
                    hvr_per_solver[solver].append(float(row[0]))
                csv_file.close()
        else:
            print("File not found: " + filename)

print("Hypervolume Ratio:")

for instance in instances:
    print()
    print(instance + ":")
    for solver in solvers:
        print(solver + ":")
        print(str(np.mean(hvr_per_solver_per_instance[solver][instance])) + " +/- " + str(np.std(hvr_per_solver_per_instance[solver][instance])))

print()
print()
print("All intances:")
for solver in solvers:
    print(solver + ":")
    print(str(np.mean(hvr_per_solver[solver])) + " +/- " + str(np.std(hvr_per_solver[solver])))

print()
print()
print()

nigd_plus_per_solver_per_instance = {}
nigd_plus_per_solver = {}

for solver in solvers:
    nigd_plus_per_solver_per_instance[solver] = {}
    nigd_plus_per_solver[solver] = []

    for instance in instances:
        nigd_plus_per_solver_per_instance[solver][instance] = []

        filename = os.path.join(dirname, "nigd_plus/" + instance + "_" + solver + ".txt")
        if os.path.exists(filename):
            with open(filename) as csv_file:
                data = csv.reader(csv_file)
                for row in data:
                    nigd_plus_per_solver_per_instance[solver][instance].append(float(row[0]))
                    nigd_plus_per_solver[solver].append(float(row[0]))
                csv_file.close()
        else:
            print("File not found: " + filename)

print("NIGD+:")

for instance in instances:
    print()
    print(instance + ":")
    for solver in solvers:
        print(solver + ":")
        print(str(np.mean(nigd_plus_per_solver_per_instance[solver][instance])) + " +/- " + str(np.std(nigd_plus_per_solver_per_instance[solver][instance])))

print()
print()
print("All intances:")
for solver in solvers:
    print(solver + ":")
    print(str(np.mean(nigd_plus_per_solver[solver])) + " +/- " + str(np.std(nigd_plus_per_solver[solver])))
