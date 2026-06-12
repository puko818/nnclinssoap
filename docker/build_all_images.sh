#!/bin/bash

# Build All Containers Script
# Agnostic script for building all container images from Dockerfiles/Apptainer definitions
# No hard-coded external paths - works relative to repository root

set -e

# Get script directory and repository root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DOCKER_DIR="${SCRIPT_DIR}"
IMAGE_OUTPUT="${REPO_ROOT}/containers"
VERSION="4.5.2"
DATE_TAG=$(date +%Y%m%d)

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"; }
success() { echo -e "${GREEN}✅ $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}"; exit 1; }
warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }

# Create output directories
mkdir -p "${IMAGE_OUTPUT}" "${DOCKER_DIR}/logs"

log "==========================================="
log "Container Build Script - nnclinssoap"
log "==========================================="
log "Repository root: ${REPO_ROOT}"
log "Docker directory: ${DOCKER_DIR}"
log "Output directory: ${IMAGE_OUTPUT}"
log "Version: ${VERSION}"
log ""

# Check prerequisites
log "Checking prerequisites..."

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
    warning "Docker-only mode: Will build Docker images (not .sif files)"
else
    error "No container runtime found. Please install Docker, Apptainer, or Singularity."
fi

# Function to build from Apptainer def or Dockerfile
build_container() {
    local name=$1
    local source_dir="${DOCKER_DIR}/${name}"
    
    # Determine output naming based on build type
    if [ "$BUILD_TYPE" = "docker" ]; then
        # Docker image naming
        if [ "$name" = "qc-report" ]; then
            local docker_tag="nnclinssoap/${name}:1.0"
        else
            local docker_tag="nnclinssoap/scrnaseq-${name}:${VERSION}"
        fi
        local output_name="${docker_tag}"
    else
        # Singularity/Apptainer .sif naming
        if [ "$name" = "qc-report" ]; then
            local output_name="qc-report_1.0.sif"
        else
            local output_name="scrnaseq-${name}_${VERSION}.sif"
        fi
    fi
    
    local log_file="${DOCKER_DIR}/logs/build_${name}_${DATE_TAG}.log"
    
    log "==========================================="
    log "Building: ${name}"
    log "==========================================="
    log "Source: ${source_dir}"
    log "Output: ${output_name}"
    log "Build type: ${BUILD_TYPE}"
    
    if [ ! -d "$source_dir" ]; then
        error "Source directory not found: ${source_dir}"
    fi
    
    cd "${source_dir}"
    
    # Build based on available runtime
    if [ "$BUILD_TYPE" = "docker" ]; then
        # Pure Docker build
        if [ ! -f "Dockerfile" ]; then
            error "Dockerfile not found in ${source_dir}"
        fi
        
        log "Building Docker image..."
        docker build -t "${docker_tag}" . \
            2>&1 | tee "${log_file}"
        
        local build_exit_code=$?
        
        # Verify both exit code and image existence
        if [ $build_exit_code -eq 0 ] && docker images "${docker_tag}" | grep -q "${docker_tag}"; then
            success "${name} Docker image built successfully"
            log "Image: ${docker_tag}"
            log "Log: ${log_file}"
            return 0
        else
            log "Build failed with exit code: ${build_exit_code}"
            return 1
        fi
        
    else
        # Singularity/Apptainer build
        # Priority: apptainer.def > Dockerfile
        if [ -f "apptainer.def" ]; then
            log "Using apptainer.def"
            ${CONTAINER_CMD} build --force \
                "${IMAGE_OUTPUT}/${output_name}" \
                apptainer.def \
                2>&1 | tee "${log_file}"
            
            local build_exit_code=$?
            
            # Verify both exit code and file existence
            if [ $build_exit_code -eq 0 ] && [ -f "${IMAGE_OUTPUT}/${output_name}" ]; then
                local size=$(du -h "${IMAGE_OUTPUT}/${output_name}" | cut -f1)
                success "${name} built successfully (${size})"
                log "Log: ${log_file}"
                return 0
            else
                log "Build failed with exit code: ${build_exit_code}"
                return 1
            fi
            
        elif [ -f "Dockerfile" ]; then
            log "Found Dockerfile - will build via Docker and convert"
            
            # Check if Docker is available for conversion
            if command -v docker &> /dev/null; then
                log "Building with Docker..."
                docker build -t "nnclinssoap/${name}:${VERSION}" . \
                    2>&1 | tee "${log_file}.docker"
                
                local docker_exit_code=$?
                
                if [ $docker_exit_code -ne 0 ]; then
                    log "Docker build failed with exit code: ${docker_exit_code}"
                    return 1
                fi
                
                log "Converting to Singularity format..."
                ${CONTAINER_CMD} build --force \
                    "${IMAGE_OUTPUT}/${output_name}" \
                    "docker-daemon://nnclinssoap/${name}:${VERSION}" \
                    2>&1 | tee -a "${log_file}"
                
                local convert_exit_code=$?
                
                # Verify both exit code and file existence
                if [ $convert_exit_code -eq 0 ] && [ -f "${IMAGE_OUTPUT}/${output_name}" ]; then
                    local size=$(du -h "${IMAGE_OUTPUT}/${output_name}" | cut -f1)
                    success "${name} built successfully (${size})"
                    log "Log: ${log_file}"
                    return 0
                else
                    log "Conversion failed with exit code: ${convert_exit_code}"
                    return 1
                fi
            else
                error "Docker not available and cannot build from Dockerfile directly with Singularity"
                return 1
            fi
        else
            error "No apptainer.def or Dockerfile found in ${source_dir}"
            return 1
        fi
    fi
}

# Build all containers — base must be first as derived containers depend on it
CONTAINERS=("base" "preprocessing" "analysis" "spatialxenium" "qc-report")
FAILED_BUILDS=()

for container in "${CONTAINERS[@]}"; do
    if ! build_container "$container"; then
        FAILED_BUILDS+=("$container")
    fi
    echo ""
done

# Create version manifest
log "Creating version manifest..."
cat > "${IMAGE_OUTPUT}/VERSION_MANIFEST.txt" << EOF
Container Build Manifest - nnclinssoap
======================================
Build Date: $(date '+%Y-%m-%d %H:%M:%S')
R Version: ${VERSION}
Bioconductor: 3.22
Builder: $($CONTAINER_CMD --version)

Images Built:
-------------
EOF

for container in "${CONTAINERS[@]}"; do
    if [ "$container" = "qc-report" ]; then
        img_file="${IMAGE_OUTPUT}/qc-report_1.0.sif"
    else
        img_file="${IMAGE_OUTPUT}/scrnaseq-${container}_${VERSION}.sif"
    fi
    
    if [ -f "$img_file" ]; then
        size=$(du -h "$img_file" | cut -f1)
        echo "✅ $(basename $img_file) (${size})" >> "${IMAGE_OUTPUT}/VERSION_MANIFEST.txt"
    else
        echo "❌ $(basename $img_file) (FAILED)" >> "${IMAGE_OUTPUT}/VERSION_MANIFEST.txt"
    fi
done

cat >> "${IMAGE_OUTPUT}/VERSION_MANIFEST.txt" << EOF

Image Details:
--------------
0. scrnaseq-base_${VERSION}.sif
   - Purpose: Shared base — Seurat, common R packages, system dependencies
   - Key packages: Seurat 5.1, tidyverse, Bioconductor core, HDF5
   - Source: docker/base/

1. scrnaseq-preprocessing_${VERSION}.sif
   - Purpose: Initial QC, doublet detection, ambient RNA removal
   - Key packages: SoupX, scDblFinder, harmony, DropletUtils, whirl
   - Source: docker/preprocessing/

2. scrnaseq-analysis_${VERSION}.sif
   - Purpose: Cell type annotation, differential expression
   - Key packages: Azimuth, SingleR, edgeR, Signac, whirl
   - Source: docker/analysis/

3. scrnaseq-spatialxenium_${VERSION}.sif
   - Purpose: Spatial transcriptomics (Xenium platform)
   - Key packages: presto, argparser, arrow, spatstat
   - Source: docker/spatialxenium/

4. qc-report_1.0.sif
   - Purpose: QC PDF report generation
   - Key packages: Python 3.11, fpdf2
   - Source: docker/qc-report/

Build Logs:
-----------
docker/logs/build_*_${DATE_TAG}.log

Repository Structure:
---------------------
nnclinssoap/
├── docker/              # Container definitions
│   ├── preprocessing/
│   ├── analysis/
│   └── spatialxenium/
├── containers/          # Built images (this directory)
├── SpatialXenium/       # Nextflow pipeline
└── scrnaseq/            # R-based pipeline

EOF

success "Version manifest created: ${IMAGE_OUTPUT}/VERSION_MANIFEST.txt"

# Summary
log "==========================================="
log "Build Summary"
log "==========================================="

if [ ${#FAILED_BUILDS[@]} -eq 0 ]; then
    success "All containers built successfully!"
    
    if [ "$BUILD_TYPE" = "docker" ]; then
        log "Docker images created:"
        docker images | grep nnclinssoap
        log ""
        log "To use with Nextflow, update nextflow.config:"
        log "  docker.enabled = true"
        log "  singularity.enabled = false"
    else
        log "Images location: ${IMAGE_OUTPUT}/"
        log "To test containers, run: ${REPO_ROOT}/tests/test_containers.sh"
    fi
    exit 0
else
    error "Some builds failed: ${FAILED_BUILDS[*]}"
    log "Check logs in: ${DOCKER_DIR}/logs/"
    exit 1
fi
