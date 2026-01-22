#!/bin/bash

# Containerized Preprocessing Workflow
# Runs preprocessing_workflow.R inside the preprocessing container
# All paths are relative to repository

set -e

# Get script directory and repository root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONTAINER="${REPO_ROOT}/containers/scrnaseq-preprocessing_4.5.2.sif"
WORKDIR="${SCRIPT_DIR}"
CONFIG_FILE="configs/preprocessing_workflow.yml"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}==========================================${NC}"
echo -e "${BLUE}scRNA-seq Preprocessing (Containerized)${NC}"
echo -e "${BLUE}==========================================${NC}"
echo "Repository root: ${REPO_ROOT}"
echo "Working directory: ${WORKDIR}"
echo "Container: ${CONTAINER}"
echo "Config: ${CONFIG_FILE}"
echo ""

# Validate config exists
if [ ! -f "${WORKDIR}/${CONFIG_FILE}" ]; then
    echo -e "${RED}ERROR: Config file not found: ${WORKDIR}/${CONFIG_FILE}${NC}"
    exit 1
fi

# Detect container runtime and select appropriate mode
CONTAINER_CMD=""
USE_DOCKER=false
DOCKER_IMAGE="nnclinssoap/scrnaseq-preprocessing:4.5.2"

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
            echo "  ./build_single.sh preprocessing"
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
echo -e "${BLUE}Starting preprocessing workflow...${NC}"
echo ""

# Run preprocessing workflow in container
if [ "$USE_DOCKER" = true ]; then
    docker run --rm \
        -v ${WORKDIR}:/work \
        -w /work \
        -e R_LIBS_USER=/usr/local/lib/R/site-library \
        ${DOCKER_IMAGE} \
        R -e "whirl::run('whirl/whirl_runner_preprocessing.R')"
else
    ${CONTAINER_CMD} exec \
        --bind ${WORKDIR}:/work \
        --pwd /work \
        --env R_LIBS_USER=/usr/local/lib/R/site-library \
        ${CONTAINER} \
        R -e "whirl::run('whirl/whirl_runner_preprocessing.R')"
fi

EXIT_CODE=$?

echo ""
if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✅ Preprocessing complete!${NC}"
    exit 0
else
    echo -e "${RED}❌ Preprocessing failed with exit code ${EXIT_CODE}${NC}"
    exit $EXIT_CODE
fi
