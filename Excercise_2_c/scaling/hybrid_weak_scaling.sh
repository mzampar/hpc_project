#!/bin/bash

#SBATCH --nodes=1
#SBATCH --ntasks-per-node=8
#SBATCH --cpus-per-task=16
#SBATCH --time=01:00:00
#SBATCH --partition=EPYC
#SBATCH --job-name=hybrid_weak_scaling
#SBATCH --error=hybrid_strong_weak_%j.err
#SBATCH --output=hybrid_strong_weak_%j.out
#SBATCH -A dssc

# Load modules
module load openMPI/4.1.6/gnu/14.2.1

# Compile the program
mpicc -O3 -march=native -o ./build/mandelbrot mandelbrot.c -lm -fopenmp

# Output file for storing results
out_csv="./scaling/results/hybrid_weak_scaling.csv"

echo "Iteration,Total Tasks,Total Threads,Elapsed Time(s),Computation Time(s),Gathering Time(s)" > "$out_csv"  # Clear and set header

# Constant amout of work per worker: C = problem size / number of workers
# Therefore, problem size = C * number of workers 

BASE_ROWS=2000
BASE_COLS=2000

iterations=5

tasks_list=(1 2 4 8)
threads_list=(1 2 4 8 16)

echo "Running MPI weak scaling."

for i in $(seq 1 $iterations); do
    for total_tasks in "${tasks_list[@]}"; do
        for total_threads in "${threads_list[@]}"; do
            export OMP_NUM_THREADS=$total_threads
            export OMP_PLACES=cores
            export OMP_PROC_BIND=close
            rows=$(echo "$BASE_ROWS * sqrt($total_tasks) * sqrt($total_threads) " | bc -l)
            cols=$(echo "$BASE_COLS * sqrt($total_tasks) * sqrt($total_threads)" | bc -l)
            echo "Running iteration $i with $total_tasks MPI tasks and $total_threads threads."
            output=$(mpirun -np $total_tasks --map-by socket --bind-to socket ./build/mandelbrot $rows $cols -1.5 -1.25 0.5 1.25 255)
            elapsed_time=$(echo "$output" | grep "Elapsed time:" | awk '{print $3}')
            computation_time=$(echo "$output" | grep "Computation time:" | awk '{print $3}')
            gathering_time=$(echo "$output" | grep "Gathering time:" | awk '{print $3}')        
            echo "$i,$total_tasks,$total_threads,$elapsed_time,$computation_time,$gathering_time" >> "$out_csv"
        done
    done
done


echo "Execution completed. Results saved to $out_csv"