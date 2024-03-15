#!/bin/bash

#SBATCH --nodes=1
#SBATCH --ntasks-per-node=24
#SBATCH --time=02:00:00
#SBATCH --partition=THIN
#SBATCH --job-name=HPC_ex02_mandelbrot
#SBATCH --exclusive
#SBATCH -A dssc
#SBATCH --exclude=fat[001-002]

# Load necessary modules
module load openMPI/4.1.5/icc/2021.7.1

# Compile the program
mpicc -o ./build/mandelbrot_mpi mandelbrot_mpi.c -lm -fopenmp

# Output file for storing results
out_csv="./results/mandelbrot_mpi_execution_times.csv"

# Number of repetitions
repetitions=1

# OMP scaling
echo "OMP scaling:"

for threads in {1..8}; do
    total_time=0
    times=()

    for ((i=1; i<=$repetitions; i++)); do
        echo "Running repetition $i with $threads OMP threads..."
        export OMP_NUM_THREADS=$threads
        time=$(mpirun -n 1 ./mandelbrot_mpi 1000 1000 -2 -2 2 2 1000 | grep "real" | awk '{print $2}')
        times+=("$time")
        total_time=$(echo "$total_time + $time" | bc)
    done

    # Calculate average time
    average_time=$(echo "scale=3; $total_time / $repetitions" | bc)

    # Calculate standard deviation
    sum_of_squares=0
    for t in "${times[@]}"; do
        deviation=$(echo "$t - $average_time" | bc)
        sum_of_squares=$(echo "$sum_of_squares + $deviation * $deviation" | bc)
    done
    variance=$(echo "scale=3; $sum_of_squares / $repetitions" | bc)
    sd=$(echo "scale=3; sqrt($variance)" | bc)

    # Write results to CSV
    echo "$threads,$average_time,$sd" >> "$out_csv"
done

echo "Execution completed. Results saved to $out_csv"
