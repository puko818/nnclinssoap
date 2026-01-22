#!/bin/bash

# Pre-flight Check for SpatialXenium Pipeline Testing
# Verifies all dependencies and setup before running tests
# Repository agnostic - uses relative paths

set -e

# Get repository root
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[PASS]${NC} $1"; }
error() { echo -e "${RED}[FAIL]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }

ERRORS=0
WARNINGS=0

echo ""
echo "=========================================="
echo "  Pre-flight Check - SpatialXenium"
echo "=========================================="
echo "Repository: ${REPO_ROOT}"
echo ""

# Check 1: System commands
log "Checking system commands..."
REQUIRED_CMDS=("wget|curl" "unzip" "tar" "nextflow")
for cmd_group in "${REQUIRED_CMDS[@]}"; do
    IFS='|' read -ra CMDS <<< "$cmd_group"
    FOUND=false
    for cmd in "${CMDS[@]}"; do
        if command -v "$cmd" &> /dev/null; then
            success "$cmd: $(command -v $cmd)"
            FOUND=true
            break
        fi
    done
    if [ "$FOUND" = false ]; then
        error "None of [${cmd_group}] found - at least one required"
        ERRORS=$((ERRORS+1))
    fi
done

# Check container runtime
CONTAINER_RUNTIME=""
if command -v apptainer &> /dev/null; then
    success "Container runtime: apptainer $(apptainer --version | head -n1)"
    CONTAINER_RUNTIME="apptainer"
elif command -v singularity &> /dev/null; then
    success "Container runtime: singularity $(singularity --version)"
    CONTAINER_RUNTIME="singularity"
elif command -v docker &> /dev/null; then
    success "Container runtime: docker $(docker --version)"
    CONTAINER_RUNTIME="docker"
else
    error "No container runtime found (apptainer, singularity, or docker required)"
    ERRORS=$((ERRORS+1))
fi

echo ""

# Check 2: Containers
log "Checking containers..."
CONTAINER_DIR="${REPO_ROOT}/containers"
EXPECTED_CONTAINERS=(
    "scrnaseq-preprocessing_4.5.2.sif"
    "scrnaseq-analysis_4.5.2.sif"
    "scrnaseq-spatialxenium_4.5.2.sif"
)

EXPECTED_DOCKER_IMAGES=(
    "nnclinssoap/scrnaseq-preprocessing:4.5.2"
    "nnclinssoap/scrnaseq-analysis:4.5.2"
    "nnclinssoap/scrnaseq-spatialxenium:4.5.2"
)

mkdir -p "$CONTAINER_DIR"

MISSING_CONTAINERS=0

if [ "$CONTAINER_RUNTIME" = "docker" ]; then
    # Check for Docker images
    for image in "${EXPECTED_DOCKER_IMAGES[@]}"; do
        if docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "^${image}$"; then
            SIZE=$(docker images --format "{{.Size}}" "${image}")
            success "${image} (${SIZE})"
        else
            warning "${image} - NOT FOUND"
            MISSING_CONTAINERS=$((MISSING_CONTAINERS+1))
            WARNINGS=$((WARNINGS+1))
        fi
    done
else
    # Check for Apptainer/Singularity .sif files
    for container in "${EXPECTED_CONTAINERS[@]}"; do
        if [ -f "${CONTAINER_DIR}/${container}" ]; then
            SIZE=$(du -h "${CONTAINER_DIR}/${container}" | cut -f1)
            success "${container} (${SIZE})"
        else
            warning "${container} - NOT FOUND"
            MISSING_CONTAINERS=$((MISSING_CONTAINERS+1))
            WARNINGS=$((WARNINGS+1))
        fi
    done
fi

if [ $MISSING_CONTAINERS -gt 0 ]; then
    warning "Missing $MISSING_CONTAINERS container(s)"
    log "To build: cd docker && bash build_all_images.sh"
fi

echo ""

# Check 3: Test data
log "Checking test data..."
TEST_DATA_DIR="${REPO_ROOT}/SpatialXenium/test_data"
EXPECTED_DATASETS=(
    "Xenium_V1_hKidney_nondiseased_section_outs"
    "Xenium_V1_hKidney_cancer_section_outs"
)

if [ ! -d "$TEST_DATA_DIR" ]; then
    warning "Test data directory not found: ${TEST_DATA_DIR}"
    warning "To download: ./setup_test_data.sh"
    WARNINGS=$((WARNINGS+1))
else
    MISSING_DATA=0
    for dataset in "${EXPECTED_DATASETS[@]}"; do
        if [ -d "${TEST_DATA_DIR}/${dataset}" ]; then
            # Check for key files
            if [ -f "${TEST_DATA_DIR}/${dataset}/experiment.xenium" ]; then
                SIZE=$(du -sh "${TEST_DATA_DIR}/${dataset}" | cut -f1)
                success "${dataset} (${SIZE})"
                
                # Check if tar.gz files remain
                if ls "${TEST_DATA_DIR}/${dataset}"/*.tar.gz 1> /dev/null 2>&1; then
                    warning "  Unextracted .tar.gz files found - run setup_test_data.sh again"
                    WARNINGS=$((WARNINGS+1))
                fi
            else
                warning "${dataset} - incomplete (missing experiment.xenium)"
                MISSING_DATA=$((MISSING_DATA+1))
                WARNINGS=$((WARNINGS+1))
            fi
        else
            warning "${dataset} - NOT FOUND"
            MISSING_DATA=$((MISSING_DATA+1))
            WARNINGS=$((WARNINGS+1))
        fi
    done
    
    if [ $MISSING_DATA -gt 0 ]; then
        warning "Missing or incomplete test data"
        log "To download: ./setup_test_data.sh"
    fi
fi

echo ""

# Check 4: Pipeline files
log "Checking pipeline files..."
PIPELINE_DIR="${REPO_ROOT}/SpatialXenium"
REQUIRED_FILES=(
    "main.nf"
    "nextflow.config"
    "conf/test.config"
    "conf/containers.config"
    "assets/samplesheet.csv"
)

MISSING_FILES=0
for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "${PIPELINE_DIR}/${file}" ]; then
        success "${file}"
    else
        error "${file} - NOT FOUND"
        MISSING_FILES=$((MISSING_FILES+1))
        ERRORS=$((ERRORS+1))
    fi
done

if [ $MISSING_FILES -gt 0 ]; then
    error "Pipeline files missing - repository may be incomplete"
fi

echo ""

# Check 5: Samplesheet validity
log "Checking samplesheet..."
SAMPLESHEET="${PIPELINE_DIR}/assets/samplesheet.csv"
if [ -f "$SAMPLESHEET" ]; then
    # Check format
    if head -n1 "$SAMPLESHEET" | grep -q "sample,xenium_path"; then
        success "Samplesheet header valid"
        
        # Check if paths exist (relative to SpatialXenium dir)
        SAMPLE_COUNT=0
        while IFS=, read -r sample path; do
            if [ "$sample" != "sample" ]; then
                SAMPLE_COUNT=$((SAMPLE_COUNT+1))
                FULL_PATH="${PIPELINE_DIR}/${path}"
                if [ -d "$FULL_PATH" ]; then
                    success "Sample ${sample}: ${path} ✓"
                else
                    # Try from repo root
                    FULL_PATH="${REPO_ROOT}/${path}"
                    if [ -d "$FULL_PATH" ]; then
                        success "Sample ${sample}: ${path} ✓"
                    else
                        warning "Sample ${sample}: ${path} - path not found"
                        WARNINGS=$((WARNINGS+1))
                    fi
                fi
            fi
        done < "$SAMPLESHEET"
        
        if [ $SAMPLE_COUNT -gt 0 ]; then
            success "Found ${SAMPLE_COUNT} sample(s) in samplesheet"
        else
            warning "No samples found in samplesheet"
            WARNINGS=$((WARNINGS+1))
        fi
    else
        error "Samplesheet header invalid - expected 'sample,xenium_path'"
        ERRORS=$((ERRORS+1))
    fi
else
    error "Samplesheet not found: ${SAMPLESHEET}"
    ERRORS=$((ERRORS+1))
fi

echo ""

# Check 6: Nextflow configuration
log "Checking Nextflow configuration..."
cd "$PIPELINE_DIR"

# Determine profile based on container runtime
if [ "$CONTAINER_RUNTIME" = "docker" ]; then
    PROFILE="test,docker"
else
    PROFILE="test,singularity"
fi

if nextflow config -profile "$PROFILE" > /dev/null 2>&1; then
    success "Nextflow config valid (profile: ${PROFILE})"
else
    error "Nextflow config has errors"
    ERRORS=$((ERRORS+1))
fi
cd "$REPO_ROOT"

echo ""

# Check 7: Disk space
log "Checking disk space..."
AVAILABLE_SPACE=$(df -k "$REPO_ROOT" | tail -n1 | awk '{print $4}')
AVAILABLE_SPACE_GB=$((AVAILABLE_SPACE / 1024 / 1024))
if [ "$AVAILABLE_SPACE_GB" -gt 20 ]; then
    success "Available space: ${AVAILABLE_SPACE_GB}GB (sufficient)"
elif [ "$AVAILABLE_SPACE_GB" -gt 10 ]; then
    warning "Available space: ${AVAILABLE_SPACE_GB}GB (tight - recommend 20GB+)"
    WARNINGS=$((WARNINGS+1))
else
    error "Available space: ${AVAILABLE_SPACE_GB}GB (insufficient - need 20GB+)"
    ERRORS=$((ERRORS+1))
fi

echo ""

# Summary
echo "=========================================="
echo "  Summary"
echo "=========================================="

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    success "✅ ALL CHECKS PASSED"
    echo ""
    log "System is ready for testing!"
    log ""
    log "Next steps:"
    log "  cd SpatialXenium"
    if [ "$CONTAINER_RUNTIME" = "docker" ]; then
        log "  nextflow run main.nf -profile test,docker --outdir test_results"
    else
        log "  nextflow run main.nf -profile test,singularity --outdir test_results"
    fi
    echo ""
    exit 0
elif [ $ERRORS -eq 0 ]; then
    warning "⚠️  PASSED WITH ${WARNINGS} WARNING(S)"
    echo ""
    log "System is functional but has warnings"
    log "Review warnings above before proceeding"
    echo ""
    exit 0
else
    error "❌ FAILED WITH ${ERRORS} ERROR(S) AND ${WARNINGS} WARNING(S)"
    echo ""
    log "Please fix errors before running tests"
    echo ""
    log "Common fixes:"
    log "  - Build containers: cd docker && bash build_all_images.sh"
    log "  - Download test data: ./setup_test_data.sh"
    log "  - Install Nextflow: curl -s https://get.nextflow.io | bash"
    log "  - Install container runtime:"
    log "    * Docker: https://docs.docker.com/get-docker/"
    log "    * Apptainer: https://apptainer.org/docs/user/main/quick_start.html"
    echo ""
    exit 1
fi
