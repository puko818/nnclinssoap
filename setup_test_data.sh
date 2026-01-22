#!/bin/bash

# Test Data Setup Script for scRNAseq and SpatialXenium Pipelines
# Downloads test datasets from Zenodo and 10x Genomics
# Repository agnostic - uses relative paths only

set -e

# Get repository root
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPATIALXENIUM_TEST_DATA_DIR="${REPO_ROOT}/SpatialXenium/test_data"
SCRNASEQ_TEST_DATA_DIR="${REPO_ROOT}/scrnaseq/test_data"

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

# Check prerequisites
log "Checking prerequisites..."

if ! command -v wget &> /dev/null && ! command -v curl &> /dev/null; then
    error "Neither wget nor curl found. Please install one of them."
fi

if ! command -v unzip &> /dev/null; then
    error "unzip not found. Please install unzip."
fi

if ! command -v tar &> /dev/null; then
    error "tar not found. Please install tar."
fi

success "Prerequisites check passed"
log ""

# Define download function (used by both sections)
download_file() {
    local url=$1
    local output=$2
    
    if command -v wget &> /dev/null; then
        wget -c -O "${output}" "${url}"
    else
        curl -L -C - -o "${output}" "${url}"
    fi
}

# scrnaseq Test Data Setup
log "==========================================="
log "Test Data Setup - scrnaseq Pipeline"
log "==========================================="
log "Repository: ${REPO_ROOT}"
log "Test data location: ${SCRNASEQ_TEST_DATA_DIR}"
log ""

# Create scrnaseq test data directory
mkdir -p "${SCRNASEQ_TEST_DATA_DIR}"
cd "${SCRNASEQ_TEST_DATA_DIR}"

# Download scRNAseq test data
SCRNASEQ_ZIP_URL="https://zenodo.org/records/18173543/files/nnclinssoap.zip?download=1"
SCRNASEQ_ZIP_FILE="nnclinssoap.zip"

log "==========================================="
log "Processing: scRNAseq Test Data"
log "==========================================="

if [ ! -f "${SCRNASEQ_ZIP_FILE}" ]; then
    log "Downloading scRNAseq test data..."
    log "URL: ${SCRNASEQ_ZIP_URL}"
    download_file "${SCRNASEQ_ZIP_URL}" "${SCRNASEQ_ZIP_FILE}"
    success "Download complete"
else
    log "Zip file already exists: ${SCRNASEQ_ZIP_FILE}"
fi

# Extract zip file
log "Extracting ${SCRNASEQ_ZIP_FILE}..."
unzip -q -o "${SCRNASEQ_ZIP_FILE}"

# Move donor folders from nested nnclinssoap directory to test_data root
if [ -d "nnclinssoap" ]; then
    log "Moving donor folders from nnclinssoap/ to test_data root..."
    mv nnclinssoap/donor* . 2>/dev/null || true
    rmdir nnclinssoap 2>/dev/null || rm -rf nnclinssoap
    success "Donor folders moved to ${SCRNASEQ_TEST_DATA_DIR}"
fi

# Clean up: remove everything except donor folders
log "Cleaning up ${SCRNASEQ_TEST_DATA_DIR}"
for item in *; do
    if [[ ! "$item" =~ ^donor[0-9]+$ ]]; then
        log "  Removing: ${item}"
        rm -rf "${item}"
    fi
done
success "scRNAseq test data setup complete"

# Create scRNAseq data summary
log "Creating scRNAseq data summary..."
cat > "${SCRNASEQ_TEST_DATA_DIR}/DATA_README.txt" << EOF
scRNAseq Test Data
==================

Setup completed: $(date '+%Y-%m-%d %H:%M:%S')
Source: Zenodo (nnclinssoap dataset)

Note: This README documents only the scRNAseq test data.
For SpatialXenium test data, see: ${SPATIALXENIUM_TEST_DATA_DIR}

Dataset:
--------
- URL: ${SCRNASEQ_ZIP_URL}
- Description: Single-cell RNA-seq data from multiple donors
- Format: 10x Genomics filtered feature-barcode matrices (H5 format)
- Zenodo Record: https://zenodo.org/records/18173543

Directory Structure:
--------------------
test_data/
├── donor1/
│   └── sample_filtered_feature_bc_matrix.h5
├── donor2/
│   └── sample_filtered_feature_bc_matrix.h5
├── donor3/
│   └── sample_filtered_feature_bc_matrix.h5
└── donor4/
    └── sample_filtered_feature_bc_matrix.h5

Setup Process:
--------------
1. Downloaded ZIP file from Zenodo
2. Extracted ZIP file
3. Moved donor folders from nested directory to test_data root
4. Cleaned up temporary files and nested directories

Note:
-----
- These files are gitignored (listed in .gitignore)
- Data is from Zenodo public repository
- Licensed under respective terms of use

EOF

success "Data summary created: ${SCRNASEQ_TEST_DATA_DIR}/DATA_README.txt"
log ""


# SpatialXenium Test Data Setup
log "==========================================="
log "Test Data Setup - SpatialXenium Pipeline"
log "==========================================="
log "Repository: ${REPO_ROOT}"
log "Test data location: ${SPATIALXENIUM_TEST_DATA_DIR}"
log ""

# Create SpatialXenium test data directory
cd "${REPO_ROOT}"
log "Switching to SpatialXenium test data directory..."
mkdir -p "${SPATIALXENIUM_TEST_DATA_DIR}"
cd "${SPATIALXENIUM_TEST_DATA_DIR}"

# Define datasets
declare -A DATASETS=(
    ["hKidney_nondiseased"]="https://cf.10xgenomics.com/samples/xenium/1.5.0/Xenium_V1_hKidney_nondiseased_section/Xenium_V1_hKidney_nondiseased_section_outs.zip"
    ["hKidney_cancer"]="https://cf.10xgenomics.com/samples/xenium/1.5.0/Xenium_V1_hKidney_cancer_section/Xenium_V1_hKidney_cancer_section_outs.zip"
)

# Reference RDS file for label transfer
REFERENCE_RDS_URL="https://zenodo.org/records/10694842/files/ref.Rds?download=1"
REFERENCE_RDS_FILE="ref.rds"

# Download and extract datasets
for dataset in "${!DATASETS[@]}"; do
    url="${DATASETS[$dataset]}"
    zipfile="${dataset}_outs.zip"
    outdir="Xenium_V1_${dataset}_section_outs"
    
    log "==========================================="
    log "Processing: ${dataset}"
    log "==========================================="
    
    # Check if already extracted
    if [ -d "${outdir}" ]; then
        warning "Directory ${outdir} already exists. Skipping download."
        
        # Verify key files exist
        if [ -f "${outdir}/cell_feature_matrix.h5" ]; then
            success "${dataset} data already available and valid"
            continue
        else
            warning "Directory exists but appears incomplete. Re-downloading..."
            rm -rf "${outdir}"
        fi
    fi
    
    # Download
    if [ ! -f "${zipfile}" ]; then
        log "Downloading ${dataset}..."
        log "URL: ${url}"
        download_file "${url}" "${zipfile}"
        success "Download complete"
    else
        log "Zip file already exists: ${zipfile}"
    fi
    
    # Extract zip file
    log "Extracting ${zipfile}..."
    
    # Create output directory if it doesn't exist
    mkdir -p "${outdir}"
    
    # Extract into the directory
    unzip -q "${zipfile}" -d "${outdir}"
    
    # Check if files were extracted to a subdirectory or directly
    # If extracted to subdirectory, move them up
    SUBDIR=$(find "${outdir}" -maxdepth 1 -type d ! -path "${outdir}" | head -n1)
    if [ -n "$SUBDIR" ] && [ -d "$SUBDIR" ]; then
        log "  Moving files from subdirectory to ${outdir}..."
        mv "${SUBDIR}"/* "${outdir}/"
        rmdir "${SUBDIR}"
    fi
    
    # Verify extraction
    if [ ! -d "${outdir}" ]; then
        error "Extraction failed - directory not found: ${outdir}"
    fi
    
    success "Zip file extracted to ${outdir}"
    
    # Extract internal tar.gz files
    log "Checking for compressed archives inside ${outdir}..."
    cd "${outdir}"
    
    # Find and extract all .tar.gz files
    if compgen -G "*.tar.gz" > /dev/null; then
        for tarfile in *.tar.gz; do
            log "  Extracting ${tarfile}..."
            tar -xzf "${tarfile}"
            success "  ${tarfile} extracted"
            
            # Optional: remove tar.gz to save space
            log "  Removing ${tarfile} to save space..."
            rm -f "${tarfile}"
        done
    else
        log "No .tar.gz files found (this is normal for some datasets)"
    fi
    
    # Return to test data directory
    cd "${SPATIALXENIUM_TEST_DATA_DIR}"
    
    # Check essential files
    log "Verifying extracted files..."
    REQUIRED_FILES=(
        "cell_feature_matrix.h5"
        "cells.csv.gz"
        "experiment.xenium"
    )
    
    MISSING_FILES=()
    for file in "${REQUIRED_FILES[@]}"; do
        if [ ! -f "${outdir}/${file}" ]; then
            warning "Optional file not found: ${outdir}/${file}"
            MISSING_FILES+=("${file}")
        else
            log "  ✓ ${file}"
        fi
    done
    
    # cell_feature_matrix might be in a subdirectory after tar extraction
    if [ ! -f "${outdir}/cell_feature_matrix.h5" ]; then
        log "  Searching for cell_feature_matrix in subdirectories..."
        MATRIX_PATH=$(find "${outdir}" -name "cell_feature_matrix.h5" -o -name "cell_feature_matrix" -type d | head -n1)
        if [ -n "${MATRIX_PATH}" ]; then
            log "  Found: ${MATRIX_PATH}"
        else
            warning "cell_feature_matrix not found - pipeline may still work with other formats"
        fi
    fi
    
    success "${dataset} extracted and verified"
    
    # Clean up zip file to save space
    log "Removing zip file to save space..."
    rm -f "${zipfile}"
    
    log ""
done

# Download reference RDS file
log "==========================================="
log "Downloading Reference RDS File"
log "==========================================="

if [ -f "${REFERENCE_RDS_FILE}" ]; then
    log "Reference RDS already exists: ${REFERENCE_RDS_FILE}"
    
    # Verify it's a valid file (at least 1MB)
    FILE_SIZE=$(stat -f%z "${REFERENCE_RDS_FILE}" 2>/dev/null || stat -c%s "${REFERENCE_RDS_FILE}" 2>/dev/null || echo "0")
    if [ "$FILE_SIZE" -gt 1000000 ]; then
        success "Reference RDS file is valid ($(numfmt --to=iec --suffix=B $FILE_SIZE 2>/dev/null || echo \"${FILE_SIZE} bytes\"))"
    else
        warning "File exists but appears too small. Re-downloading..."
        rm -f "${REFERENCE_RDS_FILE}"
    fi
fi

if [ ! -f "${REFERENCE_RDS_FILE}" ]; then
    log "Downloading reference RDS from Zenodo..."
    log "URL: ${REFERENCE_RDS_URL}"
    
    download_file "${REFERENCE_RDS_URL}" "${REFERENCE_RDS_FILE}"
    
    # Verify download
    if [ -f "${REFERENCE_RDS_FILE}" ]; then
        FILE_SIZE=$(stat -f%z "${REFERENCE_RDS_FILE}" 2>/dev/null || stat -c%s "${REFERENCE_RDS_FILE}" 2>/dev/null || echo "0")
        if [ "$FILE_SIZE" -gt 1000000 ]; then
            success "Reference RDS downloaded successfully ($(numfmt --to=iec --suffix=B $FILE_SIZE 2>/dev/null || echo \"${FILE_SIZE} bytes\"))"
        else
            error "Downloaded file appears corrupted or incomplete"
        fi
    else
        error "Failed to download reference RDS file"
    fi
fi
log ""

# Create data summary
log "Creating SpatialXenium data summary..."
cat > "${SPATIALXENIUM_TEST_DATA_DIR}/DATA_README.txt" << EOF
SpatialXenium Test Data
=======================

Setup completed: $(date '+%Y-%m-%d %H:%M:%S')
Source: 10x Genomics Xenium Public Datasets & Zenodo

Note: This README documents only the SpatialXenium test data.
For scRNAseq test data, see: ${SCRNASEQ_TEST_DATA_DIR}

Datasets:
---------

1. Non-diseased Kidney (Xenium_V1_hKidney_nondiseased_section_outs)
   - URL: https://cf.10xgenomics.com/samples/xenium/1.5.0/Xenium_V1_hKidney_nondiseased_section/
   - Description: Normal kidney tissue section
   - Platform: Xenium 1.5.0

2. Cancer Kidney (Xenium_V1_hKidney_cancer_section_outs)
   - URL: https://cf.10xgenomics.com/samples/xenium/1.5.0/Xenium_V1_hKidney_cancer_section/
   - Description: Kidney cancer tissue section
   - Platform: Xenium 1.5.0

3. Reference RDS (ref.rds)
   - URL: ${REFERENCE_RDS_URL}
   - Description: Single-cell reference for label transfer
   - Label column: annotation.l1
   - Source: Zenodo (DOI: 10.5281/zenodo.10694842)

Directory Structure:
--------------------
test_data/
├── ref.rds                                      # Reference for label transfer
├── Xenium_V1_hKidney_nondiseased_section_outs/
│   ├── cell_feature_matrix.h5
│   ├── cell_feature_matrix/ (extracted from .tar.gz)
│   ├── cells.csv.gz
│   ├── experiment.xenium
│   └── ... (other files)
└── Xenium_V1_hKidney_cancer_section_outs/
    ├── cell_feature_matrix.h5
    ├── cell_feature_matrix/ (extracted from .tar.gz)
    ├── cells.csv.gz
    ├── experiment.xenium
    └── ... (other files)

Extraction Process:
-------------------
1. Downloaded .zip files from 10x Genomics
2. Extracted zip files to get output directories
3. Extracted internal .tar.gz files (e.g., cell_feature_matrix.tar.gz)
4. Downloaded reference RDS from Zenodo
5. Removed compressed files to save disk space

Usage:
------
These datasets are referenced in SpatialXenium/assets/samplesheet.csv
The reference RDS is used for label transfer annotation

To run the test pipeline:
  cd SpatialXenium
  nextflow run main.nf -profile test,singularity

Note:
-----
- These files are gitignored (listed in .gitignore)
- Total size: ~2-3 GB per Xenium dataset + reference RDS
- Data is from 10x Genomics public datasets
- Reference from Zenodo: https://zenodo.org/records/10694842
- Licensed under respective terms of use

EOF

success "Data summary created: ${SPATIALXENIUM_TEST_DATA_DIR}/DATA_README.txt"
log ""

# Calculate total size
log "Calculating dataset sizes..."
for dataset in "${!DATASETS[@]}"; do
    outdir="Xenium_V1_${dataset}_section_outs"
    if [ -d "${outdir}" ]; then
        size=$(du -sh "${outdir}" | cut -f1)
        log "  ${dataset}: ${size}"
    fi
done

# Show reference RDS size
if [ -f "${REFERENCE_RDS_FILE}" ]; then
    size=$(du -sh "${REFERENCE_RDS_FILE}" | cut -f1)
    log "  Reference RDS: ${size}"
fi

total_size=$(du -sh . | cut -f1)
log "  Total size: ${total_size}"
log ""

# Final verification
log "==========================================="
log "Final Verification"
log "==========================================="

VERIFICATION_PASSED=true

# Verify Xenium datasets
for dataset in "${!DATASETS[@]}"; do
    outdir="Xenium_V1_${dataset}_section_outs"
    if [ -d "${outdir}" ] && [ -f "${outdir}/cell_feature_matrix.h5" ]; then
        success "${dataset}: OK"
    else
        error "${dataset}: FAILED"
        VERIFICATION_PASSED=false
    fi
done

# Verify reference RDS
if [ -f "${REFERENCE_RDS_FILE}" ]; then
    FILE_SIZE=$(stat -f%z "${REFERENCE_RDS_FILE}" 2>/dev/null || stat -c%s "${REFERENCE_RDS_FILE}" 2>/dev/null || echo "0")
    if [ "$FILE_SIZE" -gt 1000000 ]; then
        success "Reference RDS: OK"
    else
        error "Reference RDS: FAILED (file too small)"
        VERIFICATION_PASSED=false
    fi
else
    error "Reference RDS: FAILED (file not found)"
    VERIFICATION_PASSED=false
fi

log ""
if [ "$VERIFICATION_PASSED" = true ]; then
    success "========================================="
    success "Test Data Setup Complete!"
    success "========================================="
    log ""
    log "Test data locations:"
    log "  - scRNAseq: ${SCRNASEQ_TEST_DATA_DIR}"
    log "  - SpatialXenium: ${SPATIALXENIUM_TEST_DATA_DIR}"
    log ""
    log "Next steps:"
    log "  1. Verify containers are built:"
    log "     ls -lh containers/*.sif"
    log ""
    log "  2. Check container configuration:"
    log "     cat SpatialXenium/conf/containers.config"
    log ""
    log "  3. Run the SpatialXenium test pipeline:"
    log "     cd SpatialXenium"
    log "     nextflow run main.nf -profile test,singularity -resume"
    log ""
    log "Data location: ${SPATIALXENIUM_TEST_DATA_DIR}"
    log "Samplesheet: SpatialXenium/assets/samplesheet.csv"
    exit 0
else
    error "Setup failed - please check errors above"
    exit 1
fi
