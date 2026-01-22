#!/bin/bash

# Quick test of SpatialXenium container and data setup
# Tests basic functionality after build and data download

set -e

# Get repository root (agnostic path)
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTAINER="${REPO_ROOT}/containers/scrnaseq-spatialxenium_4.5.2.sif"
TEST_DATA="${REPO_ROOT}/test_data"

echo "=========================================="
echo "SpatialXenium Container Quick Test"
echo "=========================================="
echo "Repository: ${REPO_ROOT}"
echo ""

# Check if container exists
if [ ! -f "$CONTAINER" ]; then
    echo "❌ ERROR: Container not found at: $CONTAINER"
    echo "Please build it first with:"
    echo "  cd docker && sbatch build_all_images.sh"
    exit 1
fi

echo "✅ Container found: $CONTAINER"
echo ""

# Test 1: R version
echo "Test 1: R Version"
apptainer exec "$CONTAINER" R --version | head -n 1
echo ""

# Test 2: Key packages
echo "Test 2: Checking key packages..."
apptainer exec "$CONTAINER" Rscript -e "
packages <- c('Seurat', 'presto', 'argparser', 'arrow', 'ggExtra', 'spatstat.geom')
for (pkg in packages) {
    if (requireNamespace(pkg, quietly = TRUE)) {
        cat(sprintf('  ✅ %s\n', pkg))
    } else {
        cat(sprintf('  ❌ %s - MISSING!\n', pkg))
    }
}
"
echo ""

# Test 3: Simple R computation
echo "Test 3: Simple computation test..."
apptainer exec "$CONTAINER" Rscript -e "cat('Mean of 1:100 =', mean(1:100), '\n')"
echo ""

# Test 4: Check test data
echo "Test 4: Checking test data availability..."
if [ -d "${TEST_DATA}" ]; then
    echo "✅ Test data directory exists: ${TEST_DATA}"
    
    # Check for extracted datasets
    DATASETS=("Xenium_V1_hKidney_nondiseased_section_outs" "Xenium_V1_hKidney_cancer_section_outs")
    for dataset in "${DATASETS[@]}"; do
        if [ -d "${TEST_DATA}/${dataset}" ]; then
            echo "  ✅ ${dataset}"
            
            # Check if tar.gz files are extracted
            if ls "${TEST_DATA}/${dataset}"/*.tar.gz 1> /dev/null 2>&1; then
                echo "    ⚠️  WARNING: Found unextracted .tar.gz files"
                echo "    Run setup_test_data.sh again to extract them"
            fi
            
            # Verify key files
            if [ -f "${TEST_DATA}/${dataset}/experiment.xenium" ]; then
                echo "    ✅ experiment.xenium found"
            else
                echo "    ⚠️  experiment.xenium not found"
            fi
        else
            echo "  ❌ ${dataset} - NOT FOUND"
            echo "    Run: ./setup_test_data.sh"
        fi
    done
else
    echo "⚠️  Test data not found: ${TEST_DATA}"
    echo "To download test data, run:"
    echo "  ./setup_test_data.sh"
fi
echo ""

echo "=========================================="
echo "Quick test completed!"
echo "=========================================="
