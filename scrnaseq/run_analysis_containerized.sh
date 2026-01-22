#!/bin/bash

# Containerized Analysis Workflow
# Runs cell_annotation.R and de_analysis.R inside the analysis container
# All paths are relative to repository

set -e

# Get script directory and repository root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONTAINER="${REPO_ROOT}/containers/scrnaseq-analysis_4.5.2.sif"
WORKDIR="${SCRIPT_DIR}"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}scRNA-seq Analysis (Containerized)${NC}"
echo -e "${BLUE}======================================${NC}"
echo "Repository root: ${REPO_ROOT}"
echo "Working directory: ${WORKDIR}"
echo "Container: ${CONTAINER}"
echo ""

# Detect container runtime and select appropriate mode
CONTAINER_CMD=""
USE_DOCKER=false
DOCKER_IMAGE="nnclinssoap/scrnaseq-analysis:4.5.2"

if [ -f "$CONTAINER" ]; then
    # .sif file exists, use Apptainer/Singularity
    if command -v apptainer &> /dev/null; then
        CONTAINER_CMD="apptainer"
    elif command -v singularity &> /dev/null; then
        CONTAINER_CMD="singularity"
    else
        echo -e "${RED}ERROR: .sif container found but neither apptainer nor singularity available${NC}"
        exit 1
    fi
    echo "Using: ${CONTAINER_CMD} with ${CONTAINER}"
else
    # No .sif file, check for Docker
    if command -v docker &> /dev/null; then
        # Check if Docker image exists
        if docker image inspect ${DOCKER_IMAGE} &> /dev/null; then
            USE_DOCKER=true
            echo "Using: Docker with image ${DOCKER_IMAGE}"
        else
            echo -e "${RED}ERROR: Docker found but image ${DOCKER_IMAGE} does not exist${NC}"
            echo ""
            echo "Please build the Docker image first:"
            echo "  cd ${REPO_ROOT}/docker"
            echo "  ./build_single.sh analysis"
            exit 1
        fi
    else
        echo -e "${RED}ERROR: No container runtime found${NC}"
        echo ""
        echo "Please install one of:"
        echo "  - Apptainer/Singularity (and build .sif files)"
        echo "  - Docker (and build Docker images)"
        exit 1
    fi
fi

echo ""

# Run cell annotation and differential expression analysis
if [ -f "R/cell_annotation.R" ] && [ -f "R/de_analysis.R" ]; then
    echo -e "${BLUE}Both required R scripts found. Running combined analysis with whirl${NC}"
    if [ "$USE_DOCKER" = true ]; then
        docker run --rm \
            -v ${WORKDIR}:/work \
            -w /work \
            -e R_LIBS_USER=/usr/local/lib/R/site-library \
            ${DOCKER_IMAGE} \
            R -e 'whirl::run("whirl/whirl_runner_analysis.R")'
    else
        ${CONTAINER_CMD} exec \
            --bind ${WORKDIR}:/work \
            --pwd /work \
            --env R_LIBS_USER=/usr/local/lib/R/site-library \
            ${CONTAINER} \
            R -e 'whirl::run("whirl/whirl_runner_analysis.R")'
    fi

    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Cell annotation failed${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ Cell annotation complete${NC}"
    echo ""
fi

echo ""
echo -e "${GREEN}✅ Analysis pipeline complete!${NC}"
