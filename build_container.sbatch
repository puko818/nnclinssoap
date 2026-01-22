#!/bin/bash
#SBATCH --job-name=build_spatialxenium
#SBATCH --output=logs/build_spatialxenium_%j.out
#SBATCH --error=logs/build_spatialxenium_%j.err
#SBATCH --time=8:00:00
#SBATCH --mem=8G
#SBATCH --cpus-per-task=4

# Build SpatialXenium Singularity Container
# This script builds the spatialxenium container using Apptainer

set -e

echo "=========================================="
echo "Building SpatialXenium Container"
echo "=========================================="
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $HOSTNAME"
echo "Started: $(date)"
echo ""

# Get repository root
REPO_ROOT="/novo/users/zemw/zemv-zs/spatial/nnclinssoap"
cd "$REPO_ROOT"

# Create output directory
mkdir -p containers
mkdir -p logs

# Build the container
echo "Building spatialxenium container..."
./docker/build_single.sh preprocessing

echo ""
echo "=========================================="
echo "Build completed: $(date)"
echo "=========================================="
