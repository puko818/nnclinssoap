#!/bin/bash

# Build Single Container Script
# Quick build for testing individual containers
# Usage: ./build_single.sh [preprocessing|analysis|spatialxenium|qc-report]

set -e

# Get script directory and repository root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
IMAGE_OUTPUT="${REPO_ROOT}/containers"
VERSION="4.5.2"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"; }
success() { echo -e "${GREEN}✅ $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}"; exit 1; }
warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }

IMAGE_TYPE=$1

if [ -z "$IMAGE_TYPE" ]; then
    echo -e "${RED}Usage: $0 [preprocessing|analysis|spatialxenium|qc-report]${NC}"
    exit 1
fi

SOURCE_DIR="${SCRIPT_DIR}/${IMAGE_TYPE}"

if [ ! -d "$SOURCE_DIR" ]; then
    error "Directory ${IMAGE_TYPE} not found in ${SCRIPT_DIR}"
fi

# Detect available container runtimes
if command -v apptainer &> /dev/null; then
    CONTAINER_CMD="apptainer"
    BUILD_TYPE="singularity"
    log "Using: $(apptainer --version)"
elif command -v singularity &> /dev/null; then
    CONTAINER_CMD="singularity"
    BUILD_TYPE="singularity"
    log "Using: $(singularity --version)"
elif command -v docker &> /dev/null; then
    CONTAINER_CMD="docker"
    BUILD_TYPE="docker"
    log "Using: $(docker --version)"
    warning "Docker-only mode: Will build Docker image (not .sif file)"
else
    error "No container runtime found. Please install Docker, Apptainer, or Singularity."
fi

mkdir -p "$IMAGE_OUTPUT"
mkdir -p "${SCRIPT_DIR}/logs"

# Determine output naming based on build type
if [ "$BUILD_TYPE" = "docker" ]; then
    # Docker image naming
    if [ "$IMAGE_TYPE" = "qc-report" ]; then
        DOCKER_TAG="nnclinssoap/${IMAGE_TYPE}:1.0"
        OUTPUT_NAME="${DOCKER_TAG}"
    else
        DOCKER_TAG="nnclinssoap/scrnaseq-${IMAGE_TYPE}:${VERSION}"
        OUTPUT_NAME="${DOCKER_TAG}"
    fi
else
    # Singularity/Apptainer .sif naming
    if [ "$IMAGE_TYPE" = "qc-report" ]; then
        OUTPUT_NAME="qc-report_1.0.sif"
    else
        OUTPUT_NAME="scrnaseq-${IMAGE_TYPE}_${VERSION}.sif"
    fi
fi

LOG_FILE="${SCRIPT_DIR}/logs/build_${IMAGE_TYPE}_$(date +%Y%m%d_%H%M%S).log"

log "==========================================="
log "Building ${IMAGE_TYPE} container"
log "==========================================="
log "Source: ${SOURCE_DIR}"
log "Output: ${OUTPUT_NAME}"
log "Build type: ${BUILD_TYPE}"
log ""

cd "$SOURCE_DIR"

# Build based on available runtime
BUILD_SUCCESS=false

if [ "$BUILD_TYPE" = "docker" ]; then
    # Pure Docker build
    if [ ! -f "Dockerfile" ]; then
        error "Dockerfile not found in ${SOURCE_DIR}"
    fi
    
    log "Building Docker image..."
    docker build -t "${DOCKER_TAG}" . 2>&1 | tee "${LOG_FILE}"
    # PIPESTATUS[0] = docker build's exit code (tee's is always 0). Verify existence
    # with `docker image inspect`: `docker images <repo:tag>` prints repo and tag in
    # separate columns, so grepping for repo:tag never matches.
    if [ "${PIPESTATUS[0]}" -eq 0 ] && docker image inspect "${DOCKER_TAG}" >/dev/null 2>&1; then
        BUILD_SUCCESS=true
    fi
    
else
    # Singularity/Apptainer build
    if [ -f "apptainer.def" ]; then
        log "Using apptainer.def"
        if ${CONTAINER_CMD} build --force \
            "${IMAGE_OUTPUT}/${OUTPUT_NAME}" \
            apptainer.def \
            2>&1 | tee "${LOG_FILE}"; then
            # Verify file was created
            if [ -f "${IMAGE_OUTPUT}/${OUTPUT_NAME}" ]; then
                BUILD_SUCCESS=true
            fi
        fi
            
    elif [ -f "Dockerfile" ]; then
        log "Found Dockerfile - will build via Docker and convert"
        
        if command -v docker &> /dev/null; then
            log "Building with Docker..."
            if docker build -t "nnclinssoap/${IMAGE_TYPE}:${VERSION}" . 2>&1 | tee "${LOG_FILE}.docker"; then
                log "Converting to Singularity format..."
                if ${CONTAINER_CMD} build --force \
                    "${IMAGE_OUTPUT}/${OUTPUT_NAME}" \
                    "docker-daemon://nnclinssoap/${IMAGE_TYPE}:${VERSION}" \
                    2>&1 | tee -a "${LOG_FILE}"; then
                    # Verify file was created
                    if [ -f "${IMAGE_OUTPUT}/${OUTPUT_NAME}" ]; then
                        BUILD_SUCCESS=true
                    fi
                fi
            fi
        else
            error "Docker not available and cannot build from Dockerfile directly with Singularity"
        fi
    else
        error "No apptainer.def or Dockerfile found in ${SOURCE_DIR}"
    fi
fi

# Final verification and reporting
log ""
log "==========================================="
if [ "$BUILD_SUCCESS" = true ]; then
    if [ "$BUILD_TYPE" = "docker" ]; then
        success "Build complete!"
        log "Docker image: ${DOCKER_TAG}"
        log ""
        log "To test the image:"
        log "  docker run --rm ${DOCKER_TAG} R --version"
    else
        SIZE=$(du -h "${IMAGE_OUTPUT}/${OUTPUT_NAME}" | cut -f1)
        success "Build complete!"
        log "Image: ${IMAGE_OUTPUT}/${OUTPUT_NAME} (${SIZE})"
        log ""
        log "To test the image:"
        log "  ${CONTAINER_CMD} exec ${IMAGE_OUTPUT}/${OUTPUT_NAME} R --version"
    fi
    log ""
    log "Log file: ${LOG_FILE}"
    log "==========================================="
    exit 0
else
    error "Build failed! Check log file: ${LOG_FILE}"
fi
