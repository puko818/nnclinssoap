# SpatialXenium Pipeline Testing Guide

**Version:** 1.0  
**Date:** December 29, 2025  
**Repository:** nnclinssoap

---

## Overview

This guide walks through testing the SpatialXenium Nextflow pipeline with real Xenium kidney datasets from 10x Genomics. All paths are relative to the repository root for portability.

---

## Prerequisites

### System Requirements

- **OS:** Linux (tested on SLURM-based HPC)
- **Container Runtime:** Apptainer/Singularity
- **Workflow Engine:** Nextflow ≥23.10.0
- **Storage:** ~6-8 GB for test data
- **Memory:** 16+ GB recommended for pipeline execution

### Software Dependencies

```bash
# Check required tools
command -v apptainer || command -v singularity  # Container runtime
command -v nextflow                              # Workflow engine
command -v wget || command -v curl              # File download
command -v unzip                                 # Zip extraction
command -v tar                                   # Archive extraction
```

Install missing dependencies:
```bash
# On CentOS/RHEL
sudo yum install unzip tar wget

# On Ubuntu/Debian
sudo apt-get install unzip tar wget

# Nextflow installation
curl -s https://get.nextflow.io | bash
sudo mv nextflow /usr/local/bin/
```

---

## Testing Workflow

### Phase 1: Verify Container Build

**Step 1.1: Check if containers exist**

```bash
cd /path/to/nnclinssoap  # Navigate to your clone

# List built containers
ls -lh containers/*.sif
```

Expected output:
```
scrnaseq-analysis_4.5.2.sif         # Analysis workflow container
scrnaseq-preprocessing_4.5.2.sif    # Preprocessing workflow container
scrnaseq-spatialxenium_4.5.2.sif    # Spatial Xenium container
```

**Step 1.2: If containers don't exist, build them**

```bash
cd docker

# Option A: Build all containers (SLURM)
sbatch build_all_images.sh

# Option B: Build all containers (interactive)
bash build_all_images.sh

# Monitor build progress
tail -f logs/build_*.log
```

Build time: ~1-10 min per container (~20 min for the full stack; binary-package build)

**Step 1.3: Quick container test**

```bash
cd ..  # Return to repo root
./test_spatialxenium_quick.sh
```

Expected output:
```
✅ Container found
✅ R version 4.5.2
✅ All key packages loaded
✅ Computation test passed
```

---

### Phase 2: Download and Prepare Test Data

**Step 2.1: Run the data setup script**

```bash
# From repository root
./setup_test_data.sh
```

This script will:
1. ✅ Download two Xenium kidney datasets (~2-3 GB each)
2. ✅ Extract zip files
3. ✅ Extract internal `.tar.gz` files (e.g., `cell_feature_matrix.tar.gz`)
4. ✅ Verify all required files
5. ✅ Create `test_data/` directory structure
6. ✅ Clean up compressed files to save space

**Expected directory structure after setup:**

```
nnclinssoap/
└── test_data/
    ├── DATA_README.txt
    ├── Xenium_V1_hKidney_nondiseased_section_outs/
    │   ├── cell_feature_matrix/        # ← Extracted from .tar.gz
    │   │   ├── barcodes.tsv.gz
    │   │   ├── features.tsv.gz
    │   │   └── matrix.mtx.gz
    │   ├── cell_feature_matrix.h5
    │   ├── cells.csv.gz
    │   ├── experiment.xenium
    │   └── ... (other Xenium outputs)
    └── Xenium_V1_hKidney_cancer_section_outs/
        ├── cell_feature_matrix/        # ← Extracted from .tar.gz
        ├── cell_feature_matrix.h5
        ├── cells.csv.gz
        ├── experiment.xenium
        └── ... (other Xenium outputs)
```

**Step 2.2: Verify data extraction**

```bash
# Check if all files are properly extracted
./test_spatialxenium_quick.sh

# Or manually verify
ls test_data/Xenium_V1_hKidney_nondiseased_section_outs/
ls test_data/Xenium_V1_hKidney_cancer_section_outs/

# Ensure NO .tar.gz files remain (they should be extracted and removed)
find test_data/ -name "*.tar.gz"  # Should return nothing
```

**Step 2.3: Read the data documentation**

```bash
cat test_data/DATA_README.txt
```

---

### Phase 3: Configure Pipeline for Testing

**Step 3.1: Verify samplesheet**

The samplesheet at `SpatialXenium/assets/samplesheet.csv` should reference the test data:

```csv
sample,xenium_path
hKidney_nondiseased,test_data/Xenium_V1_hKidney_nondiseased_section_outs
hKidney_cancer,test_data/Xenium_V1_hKidney_cancer_section_outs
```

**Important:** Paths are relative to where you run Nextflow (i.e., from `SpatialXenium/` directory)

**Step 3.2: Check test configuration**

```bash
cat SpatialXenium/conf/test.config
```

Key parameters:
- `input`: Points to samplesheet
- `genes`: Optional gene list for feature plotting
- `reference_rds`: Optional reference for label transfer
- `outdir`: Where results will be saved

**Step 3.3: Verify container configuration**

```bash
cat SpatialXenium/conf/containers.config
```

Should contain:
```nextflow
params {
    container_base_path = "${projectDir}/../containers"
    container_version   = "4.5.2"
}
```

---

### Phase 4: Run the Pipeline

**Step 4.1: Navigate to pipeline directory**

```bash
cd SpatialXenium
```

**Step 4.2: Test run with minimal data (dry run)**

```bash
nextflow run main.nf \
    -profile test,singularity \
    --outdir test_results \
    -preview
```

This shows what will be executed without running anything.

**Step 4.3: Run the full pipeline**

```bash
# Option A: Interactive run
nextflow run main.nf \
    -profile test,singularity \
    --outdir test_results \
    -resume

# Option B: Submit to SLURM
sbatch <<EOF
#!/bin/bash
#SBATCH --job-name=spatialxenium_test
#SBATCH --time=08:00:00
#SBATCH --mem=32G
#SBATCH --cpus-per-task=8
#SBATCH --output=logs/pipeline_test_%j.out
#SBATCH --error=logs/pipeline_test_%j.err

cd SpatialXenium

nextflow run main.nf \\
    -profile test,singularity \\
    --outdir test_results \\
    -resume
EOF
```

**Step 4.4: Monitor execution**

```bash
# Watch Nextflow output
tail -f .nextflow.log

# Check SLURM queue (if using SLURM)
squeue -u $USER

# View work directory
ls -lh work/
```

---

### Phase 5: Validate Results

**Step 5.1: Check pipeline completion**

Look for:
```
[100%] 4 of 4 ✔
Pipeline completed successfully!
```

**Step 5.2: Inspect output structure**

```bash
tree -L 2 test_results/
```

Expected structure:
```
test_results/
├── hKidney_cancer/
│   ├── seurat_xenium/
│   │   ├── hKidney_cancer_processed.rds
│   │   ├── plots (QC plots)
│   │   └── session_info.txt
│   └── label_transfer/ (if reference provided)
├── hKidney_nondiseased/
│   └── seurat_xenium/
│       ├── hKidney_nondiseased_processed.rds
│       └── ...
└── pipeline_info/
    ├── execution_timeline.html
    ├── execution_report.html
    └── execution_trace.txt
```

**Step 5.3: Verify key outputs**

```bash
# Check RDS files exist
ls test_results/*/seurat_xenium/*.rds

# Check QC plots
ls test_results/*/seurat_xenium/*.png

# View session info
cat test_results/hKidney_nondiseased/seurat_xenium/session_info.txt
```

**Step 5.4: Inspect execution reports**

```bash
# Open in browser or view as text
firefox test_results/pipeline_info/execution_report.html

# Check resource usage
cat test_results/pipeline_info/execution_trace.txt
```

---

## Common Issues and Solutions

### Issue 1: Container Not Found

**Error:**
```
Container image not found: containers/scrnaseq-spatialxenium_4.5.2.sif
```

**Solution:**
```bash
# Build containers
cd docker
bash build_all_images.sh

# Verify build
ls -lh ../containers/*.sif
```

---

### Issue 2: Test Data Missing or Incomplete

**Error:**
```
No such file: test_data/Xenium_V1_hKidney_nondiseased_section_outs
```

**Solution:**
```bash
# Run data setup
./setup_test_data.sh

# Verify extraction
./test_spatialxenium_quick.sh
```

---

### Issue 3: tar.gz Files Not Extracted

**Symptom:** Pipeline fails to find `cell_feature_matrix` directory

**Solution:**
```bash
# Check for unextracted archives
find test_data/ -name "*.tar.gz"

# If found, extract manually
cd test_data/Xenium_V1_hKidney_nondiseased_section_outs
tar -xzf cell_feature_matrix.tar.gz
rm cell_feature_matrix.tar.gz

# Repeat for cancer dataset
cd ../Xenium_V1_hKidney_cancer_section_outs
tar -xzf cell_feature_matrix.tar.gz
rm cell_feature_matrix.tar.gz
```

---

### Issue 4: Nextflow Not Found

**Error:**
```
nextflow: command not found
```

**Solution:**
```bash
# Install Nextflow
curl -s https://get.nextflow.io | bash
sudo mv nextflow /usr/local/bin/

# Or use module system
module load nextflow

# Verify
nextflow -version
```

---

### Issue 5: Insufficient Memory

**Error:**
```
Process killed due to insufficient memory
```

**Solution:**

Edit `SpatialXenium/conf/base.config`:
```nextflow
withLabel:process_medium {
    memory = { 32.GB * task.attempt }  // Increase from 8.GB
}
```

Or run with more resources:
```bash
nextflow run main.nf \
    -profile test,singularity \
    --max_memory 64.GB
```

---

### Issue 6: Singularity/Apptainer Bind Issues

**Error:**
```
FATAL: container creation failed: mount /path: permission denied
```

**Solution:**
```bash
# Check bind paths in Nextflow config
# Should auto-mount current directory

# Or explicitly set in nextflow.config:
singularity {
    autoMounts = true
    runOptions = '-B /path/to/data'
}
```

---

## Advanced Testing

### Test with Custom Parameters

```bash
nextflow run main.nf \
    -profile singularity \
    --input custom_samplesheet.csv \
    --outdir custom_results \
    --min_reads_per_cell 50 \
    --max_reads_per_cell 500000 \
    --n_highly_var_genes 2000
```

### Test with Reference Dataset

```bash
# Download or prepare reference
# Example: Kidney reference from Azimuth

nextflow run main.nf \
    -profile test,singularity \
    --reference_rds /path/to/kidney_reference.rds \
    --single_cell_label_col "cell_type" \
    --min_celltype_probability 0.7
```

### Test Individual Modules

```bash
# Test just Seurat processing
nextflow run main.nf \
    -profile test,singularity \
    -entry SEURAT_XENIUM
```

---

## Performance Benchmarking

### Expected Runtime

- **Preprocessing (per sample):** ~30-60 minutes
- **Label transfer (if enabled):** +15-30 minutes
- **Total for 2 samples:** ~1.5-3 hours

### Resource Usage

| Process | CPUs | Memory | Time |
|---------|------|--------|------|
| SEURAT_XENIUM | 6 | 8-16 GB | 30-60 min |
| LABEL_TRANSFER | 8 | 16-32 GB | 15-30 min |
| QC_REPORT | 2 | 4 GB | 5 min |

---

## Cleanup

### Remove Test Results

```bash
# Remove pipeline outputs
rm -rf test_results/
rm -rf SpatialXenium/work/
rm -rf SpatialXenium/.nextflow*
```

### Remove Test Data (to save space)

```bash
# Remove test data (can re-download anytime)
rm -rf test_data/

# Keep containers (expensive to rebuild)
# ls containers/*.sif
```

### Complete Cleanup

```bash
# Remove everything except source code
rm -rf test_results/ test_data/ containers/ logs/
rm -rf SpatialXenium/work/ SpatialXenium/.nextflow*
```

---

## Validation Checklist

- [ ] Containers built successfully (all 3 .sif files)
- [ ] Test data downloaded and extracted
- [ ] No .tar.gz files remain in test_data/
- [ ] Samplesheet paths are correct
- [ ] Container config points to correct path
- [ ] Nextflow installed and accessible
- [ ] Pipeline runs without errors
- [ ] Output RDS files created
- [ ] QC plots generated
- [ ] Execution reports available
- [ ] Memory/CPU usage reasonable

---

## Next Steps

After successful testing:

1. **Document any issues** encountered and solutions
2. **Benchmark performance** on your HPC system
3. **Test with your own data** using real experimental samples
4. **Customize parameters** based on your tissue type and QC standards
5. **Set up production runs** with proper resource allocation

---

## Support and Resources

### Documentation
- Pipeline README: `SpatialXenium/README.md`
- Build documentation: `docker/BUILD_INSTRUCTIONS.md`
- Integration analysis: `DOCKER_TO_PIPELINE_INTEGRATION_ANALYSIS.md`

### Data Sources
- 10x Genomics Xenium datasets: https://www.10xgenomics.com/products/xenium-in-situ/dataset-explorer
- Kidney reference: https://azimuth.hubmapconsortium.org/references/#Human%20-%20Kidney

### Troubleshooting
- Check logs in `logs/` and `SpatialXenium/.nextflow.log`
- Review Nextflow trace: `test_results/pipeline_info/execution_trace.txt`
- Container testing: `./test_spatialxenium_quick.sh`

---

**Version History:**
- v1.0 (2025-12-29): Initial testing guide with data extraction support
