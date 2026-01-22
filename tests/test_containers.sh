#!/bin/bash

# Container Testing Suite
# Tests all built containers for functionality
# All paths relative to repository

set -e

# Get script directory and repository root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONTAINER_DIR="${REPO_ROOT}/containers"
VERSION="4.5.2"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}==========================================="
echo "Container Testing Suite - nnclinssoap"
echo "==========================================="
echo -e "${NC}"
echo "Repository: ${REPO_ROOT}"
echo "Container directory: ${CONTAINER_DIR}"
echo ""

# Detect container runtime and mode
USE_DOCKER=false
CONTAINER_CMD=""

if command -v apptainer &> /dev/null; then
    CONTAINER_CMD="apptainer"
    echo "Using: Apptainer with .sif files"
elif command -v singularity &> /dev/null; then
    CONTAINER_CMD="singularity"
    echo "Using: Singularity with .sif files"
elif command -v docker &> /dev/null; then
    CONTAINER_CMD="docker"
    USE_DOCKER=true
    echo "Using: Docker with images"
else
    echo -e "${RED}ERROR: No container runtime found (apptainer, singularity, or docker)${NC}"
    exit 1
fi
echo ""

test_container() {
    local name=$1
    
    if [ "$USE_DOCKER" = true ]; then
        local image="nnclinssoap/scrnaseq-${name}:${VERSION}"
        echo -e "${BLUE}Testing: ${name}${NC}"
        echo "Docker image: ${image}"
        
        # Check if image exists
        if ! docker image inspect "$image" &> /dev/null; then
            echo -e "${RED}❌ FAIL: Docker image not found${NC}"
            echo "  Build with: cd ${REPO_ROOT}/docker && ./build_single.sh ${name}"
            echo ""
            return 1
        fi
        
        # Test 1: Container runs
        echo "  Test 1: Container execution..."
        if docker run --rm "$image" R --version > /dev/null 2>&1; then
            echo -e "  ${GREEN}✅ PASS${NC}"
        else
            echo -e "  ${RED}❌ FAIL${NC}"
            return 1
        fi
        
        # Test 2: R version
        echo "  Test 2: R version check..."
        R_VERSION=$(docker run --rm "$image" R --version | head -n1)
        echo "    $R_VERSION"
        if echo "$R_VERSION" | grep -q "4.5.2"; then
            echo -e "  ${GREEN}✅ PASS - R 4.5.2${NC}"
        else
            echo -e "  ${YELLOW}⚠️  WARNING: Expected R 4.5.2${NC}"
        fi
        
        # Test 3: Key packages
        echo "  Test 3: Package availability..."
        case $name in
            preprocessing)
                PACKAGES="Seurat SoupX scDblFinder harmony DropletUtils whirl"
                ;;
            analysis)
                PACKAGES="Seurat SingleR Azimuth edgeR Signac whirl"
                ;;
            spatialxenium)
                PACKAGES="Seurat presto argparser arrow"
                ;;
        esac
        
        local all_packages_ok=true
        for pkg in $PACKAGES; do
            if docker run --rm "$image" Rscript -e "library($pkg)" > /dev/null 2>&1; then
                echo -e "    ${GREEN}✅ ${pkg}${NC}"
            else
                echo -e "    ${RED}❌ ${pkg} MISSING${NC}"
                all_packages_ok=false
            fi
        done
        
        if [ "$all_packages_ok" = true ]; then
            echo -e "  ${GREEN}✅ All packages present${NC}"
        else
            echo -e "  ${RED}❌ Some packages missing${NC}"
            return 1
        fi
        
        # Test 4: Package versions
        echo "  Test 4: Key package versions..."
        SEURAT_VERSION=$(docker run --rm "$image" Rscript -e "cat(as.character(packageVersion('Seurat')))" 2>/dev/null || echo "unknown")
        echo -e "    Seurat: ${SEURAT_VERSION}"
        
    else
        # Original .sif file testing
        local image="${CONTAINER_DIR}/scrnaseq-${name}_${VERSION}.sif"
        
        echo -e "${BLUE}Testing: ${name}${NC}"
        echo "Image: ${image}"
        
        if [ ! -f "$image" ]; then
            echo -e "${RED}❌ FAIL: Image not found${NC}"
            echo ""
            return 1
        fi
        
        # Test 1: Container runs
        echo "  Test 1: Container execution..."
        if ${CONTAINER_CMD} exec "$image" R --version > /dev/null 2>&1; then
            echo -e "  ${GREEN}✅ PASS${NC}"
        else
            echo -e "  ${RED}❌ FAIL${NC}"
            return 1
        fi
        
        # Test 2: R version
        echo "  Test 2: R version check..."
        R_VERSION=$(${CONTAINER_CMD} exec "$image" R --version | head -n1)
        echo "    $R_VERSION"
        if echo "$R_VERSION" | grep -q "4.5.2"; then
            echo -e "  ${GREEN}✅ PASS - R 4.5.2${NC}"
        else
            echo -e "  ${YELLOW}⚠️  WARNING: Expected R 4.5.2${NC}"
        fi
        
        # Test 3: Key packages
        echo "  Test 3: Package availability..."
        case $name in
            preprocessing)
                PACKAGES="Seurat SoupX scDblFinder harmony DropletUtils whirl"
                ;;
            analysis)
                PACKAGES="Seurat SingleR Azimuth edgeR Signac whirl"
                ;;
            spatialxenium)
                PACKAGES="Seurat presto argparser arrow"
                ;;
        esac
        
        local all_packages_ok=true
        for pkg in $PACKAGES; do
            if ${CONTAINER_CMD} exec "$image" Rscript -e "library($pkg)" > /dev/null 2>&1; then
                echo -e "    ${GREEN}✅ ${pkg}${NC}"
            else
                echo -e "    ${RED}❌ ${pkg} MISSING${NC}"
                all_packages_ok=false
            fi
        done
        
        if [ "$all_packages_ok" = true ]; then
            echo -e "  ${GREEN}✅ All packages present${NC}"
        else
            echo -e "  ${RED}❌ Some packages missing${NC}"
            return 1
        fi
        
        # Test 4: Package versions
        echo "  Test 4: Key package versions..."
        SEURAT_VERSION=$(${CONTAINER_CMD} exec "$image" Rscript -e "cat(as.character(packageVersion('Seurat')))" 2>/dev/null || echo "unknown")
        echo -e "    Seurat: ${SEURAT_VERSION}"
    fi
    
    echo -e "  ${GREEN}✅ All tests passed for ${name}${NC}"
    echo ""
    return 0
}

# Test all containers
FAILED=0
CONTAINERS=("preprocessing" "analysis" "spatialxenium")

for container in "${CONTAINERS[@]}"; do
    if ! test_container "$container"; then
        FAILED=1
    fi
done

echo -e "${BLUE}==========================================="
if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ ALL TESTS PASSED${NC}"
    echo -e "${BLUE}==========================================="
    echo ""
    echo "All containers are ready to use!"
    echo ""
    echo "Next steps:"
    echo "  - Nextflow: cd ${REPO_ROOT}/SpatialXenium && nextflow run main.nf -profile singularity"
    echo "  - R preprocessing: cd ${REPO_ROOT}/scrnaseq && ./run_preprocessing_containerized.sh"
    echo "  - R analysis: cd ${REPO_ROOT}/scrnaseq && ./run_analysis_containerized.sh"
    exit 0
else
    echo -e "${RED}❌ SOME TESTS FAILED${NC}"
    echo -e "${BLUE}==========================================="
    echo ""
    echo "Please rebuild failed containers:"
    echo "  cd ${REPO_ROOT}/docker"
    echo "  ./build_single.sh [container_name]"
    exit 1
fi
