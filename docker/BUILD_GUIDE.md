# Container Build Guide - nnclinssoap

**Version:** 1.0  
**Last Updated:** December 26, 2025  
**Maintainer:** zemw@novonordisk.com

---

## Overview

This guide provides step-by-step instructions for building the nnclinssoap container images. All paths are relative to the repository root, making this guide suitable for technical publications and reproducible research.

### Container Suite

| Container | Purpose | Key Packages | Build Time* |
|-----------|---------|--------------|-------------|
| **preprocessing** | QC, doublet detection, batch correction | Seurat 5.1, SoupX, scDblFinder, harmony | ~2-3 hours |
| **analysis** | Cell annotation, differential expression | Azimuth, SingleR, edgeR, Signac | ~3-4 hours |
| **spatialxenium** | Spatial transcriptomics analysis | presto, Seurat, argparser, arrow | ~2-3 hours |

*Build times are estimates and vary based on system resources and network speed.

---

## Prerequisites

### Required Software

1. **Apptainer/Singularity** (primary method)
   ```bash
   # Check if installed
   apptainer --version  # or: singularity --version
   ```
   - Minimum version: Apptainer 1.0+ or Singularity 3.8+
   - Installation: See [Apptainer Installation Guide](https://apptainer.org/docs/admin/main/installation.html)

2. **Docker** (optional, for Dockerfile builds)
   ```bash
   # Check if installed
   docker --version
   ```
   - Only needed if building from Dockerfiles directly
   - Not required if using `.def` files

### System Requirements

- **Disk space:** ~20-30 GB free space
  - Source images: ~8-10 GB
  - Build cache: ~10-15 GB
  - Final images: ~3-5 GB total
  
- **Memory:** Minimum 8 GB RAM (16 GB recommended)
  
- **CPU:** Multi-core recommended for faster builds
  
- **Network:** Stable internet connection for downloading R packages

### Build Environment

**For HPC/SLURM systems:**
```bash
# Request interactive session with sufficient resources
srun --time=08:00:00 --mem=16G --cpus-per-task=4 --pty bash

# Or submit as batch job (recommended)
sbatch docker/build_all_images.sh
```

**For local systems:**
```bash
# Ensure you have sudo/fakeroot for Apptainer
# Or use --fakeroot flag with apptainer build
```

### Network Dependencies

The build process downloads packages from:
- **CRAN:** `https://cloud.r-project.org/`
- **Bioconductor:** `https://bioconductor.org/`
- **GitHub:** `https://github.com/` (for presto, Azimuth, etc.)
  - **Important:** GitHub has rate limits (60 requests/hour unauthenticated)
  - Set `GITHUB_PAT` if experiencing rate limit issues

---

## Repository Structure

```
nnclinssoap/
├── docker/                          # Container definitions
│   ├── preprocessing/
│   │   ├── Dockerfile              # Docker definition
│   │   ├── apptainer.def           # Apptainer definition (preferred)
│   │   └── README.md               # Package details
│   ├── analysis/
│   │   ├── Dockerfile
│   │   ├── apptainer.def
│   │   └── README.md
│   ├── spatialxenium/
│   │   ├── Dockerfile
│   │   ├── apptainer.def
│   │   ├── README.md
│   │   └── version.txt
│   ├── build_all_images.sh         # Main build script (this guide)
│   ├── build_single.sh             # Single container builder
│   ├── BUILD_GUIDE.md              # This file
│   └── logs/                        # Build logs (auto-created)
├── containers/                      # Built images (auto-created)
│   ├── scrnaseq-preprocessing_4.5.2.sif
│   ├── scrnaseq-analysis_4.5.2.sif
│   ├── scrnaseq-spatialxenium_4.5.2.sif
│   └── VERSION_MANIFEST.txt
├── tests/
│   └── test_containers.sh          # Validation script
├── SpatialXenium/                   # Nextflow pipeline
│   └── conf/
│       └── containers.config        # Container configuration
└── scrnaseq/                        # R-based pipeline
    ├── run_preprocessing_containerized.sh
    └── run_analysis_containerized.sh
```

---

## Quick Start (TL;DR)

```bash
# 1. Navigate to repository root
cd /path/to/nnclinssoap

# 2. Build all containers (takes 6-8 hours)
./docker/build_all_images.sh

# 3. Verify builds
./tests/test_containers.sh

# 4. Check manifest
cat containers/VERSION_MANIFEST.txt
```

---

## Detailed Build Process

### Step 1: Prepare Environment

#### 1.1 Navigate to Repository
```bash
cd /path/to/nnclinssoap
```

#### 1.2 Set GitHub Token (Optional but Recommended)
```bash
# Avoid GitHub API rate limits
export GITHUB_PAT="your_github_personal_access_token"

# Persist for session
echo "export GITHUB_PAT='your_token'" >> ~/.bashrc
```

To create a GitHub PAT:
1. Go to: https://github.com/settings/tokens
2. Click "Generate new token (classic)"
3. Select scope: `public_repo` (read-only is sufficient)
4. Copy token

#### 1.3 Verify Prerequisites
```bash
# Check Apptainer/Singularity
which apptainer || which singularity

# Check disk space (need ~30 GB)
df -h .

# Check memory
free -h
```

### Step 2: Choose Build Method

You have three options:

#### Option A: Build All Containers (Recommended)
**Use case:** Production deployment, first-time setup, publication reproducibility

```bash
# Interactive (see progress in real-time)
./docker/build_all_images.sh

# SLURM batch job (recommended for HPC)
sbatch docker/build_all_images.sh
```

**Output:**
- All 3 containers in `containers/` directory
- Build logs in `docker/logs/`
- Version manifest in `containers/VERSION_MANIFEST.txt`

---

#### Option B: Build Single Container (For Testing/Development)
**Use case:** Testing changes, debugging, incremental development

```bash
# Build one container
./docker/build_single.sh [preprocessing|analysis|spatialxenium]

# Examples:
./docker/build_single.sh preprocessing
./docker/build_single.sh spatialxenium
```

**Advantages:**
- Faster (2-3 hours instead of 6-8)
- Test individual changes
- Debug specific build issues

---

#### Option C: Manual Build (Advanced Users)
**Use case:** Custom modifications, troubleshooting

```bash
# Navigate to specific container directory
cd docker/preprocessing

# Build using Apptainer (preferred)
apptainer build --force \
    ../../containers/scrnaseq-preprocessing_4.5.2.sif \
    apptainer.def

# OR build using Docker then convert
docker build -t nnclinssoap/preprocessing:4.5.2 .
apptainer build --force \
    ../../containers/scrnaseq-preprocessing_4.5.2.sif \
    docker-daemon://nnclinssoap/preprocessing:4.5.2
```

---

### Step 3: Monitor Build Progress

#### Real-time Monitoring
```bash
# If running in background
tail -f docker/logs/build_*_$(date +%Y%m%d).log

# Check specific container
tail -f docker/logs/build_preprocessing_$(date +%Y%m%d).log
```

#### Check Build Status
```bash
# List built containers
ls -lh containers/*.sif

# Check sizes (should be 1-2 GB each)
du -h containers/*.sif

# View manifest
cat containers/VERSION_MANIFEST.txt
```

### Step 4: Verify Builds

#### Quick Validation
```bash
# Run comprehensive test suite
./tests/test_containers.sh
```

The test script checks:
- ✅ Container files exist
- ✅ R version (should be 4.5.2)
- ✅ Key packages are installed
- ✅ Containers can execute commands

#### Manual Verification
```bash
# Test container execution
apptainer exec containers/scrnaseq-preprocessing_4.5.2.sif R --version

# Check package availability
apptainer exec containers/scrnaseq-preprocessing_4.5.2.sif \
    Rscript -e "packageVersion('Seurat')"

# Interactive R session
apptainer exec containers/scrnaseq-preprocessing_4.5.2.sif R
```

---

## Build Sequence Details

### Container 1: preprocessing

**Build order:** First (has fewest dependencies)

**What it installs:**
1. System dependencies (HDF5, GDAL, etc.)
2. Base R packages (devtools, BiocManager)
3. Rcpp ecosystem
4. Data manipulation (tidyverse)
5. Visualization packages
6. Seurat 5.1 + SeuratObject
7. Specialized packages (SoupX, scDblFinder, harmony, DropletUtils)

**Common issues:**
- `hdf5r` installation may fail if HDF5 system library is missing
  - Solution: Ensure `libhdf5-dev` is installed in base image
- `harmony` requires specific Rcpp version
  - Solution: Install Rcpp packages first (already in .def)

**Estimated time:** 2-3 hours

---

### Container 2: analysis

**Build order:** Second (builds on preprocessing patterns)

**What it installs:**
1. Everything from preprocessing pattern
2. Additional annotation databases (org.Hs.eg.db, EnsDb)
3. GitHub packages (Azimuth, SeuratData, SeuratDisk)
4. SingleR + celldex
5. Signac (multimodal analysis)
6. Differential expression (edgeR, limma, DESeq2)

**Common issues:**
- GitHub API rate limits when installing Azimuth
  - Solution: Set `GITHUB_PAT` environment variable
  - Retry logic is built into .def file
- `Signac` requires genomic annotations
  - Solution: Install BSgenome packages first (already in .def)

**Estimated time:** 3-4 hours

---

### Container 3: spatialxenium

**Build order:** Third (most specialized)

**What it installs:**
1. Spatial analysis packages (spatstat suite)
2. presto (from GitHub - fast Wilcoxon tests)
3. Advanced visualization (ggExtra, plotly, shiny)
4. File I/O (arrow, argparser)
5. Seurat ecosystem

**Common issues:**
- `presto` GitHub installation can be flaky
  - Solution: Retry logic with delays (built into .def)
- `spatstat` suite has many dependencies
  - Solution: Install in correct order (already in .def)

**Estimated time:** 2-3 hours

---

## Troubleshooting Guide

### Build Failures

#### Problem: "No space left on device"
```
Error: Cannot create container: no space left on device
```

**Solution:**
```bash
# Check available space
df -h .

# Clean up old builds
rm -rf ~/.apptainer/cache/*
apptainer cache clean --all

# Use different temp directory with more space
export APPTAINER_TMPDIR=/path/to/larger/tmp
export APPTAINER_CACHEDIR=/path/to/larger/cache
```

---

#### Problem: "GitHub API rate limit exceeded"
```
Error: API rate limit exceeded for XXX.XXX.XXX.XXX
```

**Solution:**
```bash
# Set GitHub Personal Access Token
export GITHUB_PAT="ghp_your_token_here"

# Verify it's set
echo $GITHUB_PAT

# Rebuild
./docker/build_single.sh [container_name]
```

---

#### Problem: "Package 'XXX' is not available"
```
Warning: package 'XXX' is not available for this version of R
```

**Solution:**
```bash
# Check Bioconductor version compatibility
# R 4.5.2 should use Bioconductor 3.22

# For CRAN packages, check archive
# May need specific version: install.packages("XXX", version="Y.Y.Y")

# For Bioconductor, ensure version is set:
# BiocManager::install(version='3.22', ask=FALSE)
```

---

#### Problem: "Compilation failed for package 'XXX'"
```
Error: compilation failed for package 'XXX'
```

**Solution:**
```bash
# Usually missing system dependencies
# Check error log for specific library (e.g., "cannot find -lssl")

# For libssl: apt-get install libssl-dev
# For HDF5: apt-get install libhdf5-dev
# For spatial: apt-get install libgdal-dev libgeos-dev

# System deps are already in .def files, but if custom:
# Edit docker/[container]/apptainer.def
# Add missing library to apt-get install line
```

---

#### Problem: Build hangs/stalls
```
# No progress for >1 hour
```

**Solution:**
```bash
# Check if waiting for user input (shouldn't happen with non-interactive)
# Ctrl+C to cancel

# Check network connectivity
ping cloud.r-project.org

# Check system resources
htop  # or: top

# If memory issue, increase allocation:
# For SLURM: #SBATCH --mem=32G
```

---

### Validation Failures

#### Problem: "Package not found in container"
```bash
./tests/test_containers.sh
# ❌ Seurat MISSING
```

**Solution:**
```bash
# Verify package in container
apptainer exec containers/[image].sif Rscript -e "installed.packages()[,'Package']"

# If truly missing, rebuild:
./docker/build_single.sh [container_name]

# Check build log for errors
grep -i "error\|fail" docker/logs/build_[container]*
```

---

#### Problem: "R version mismatch"
```
⚠️ WARNING: Expected R 4.5.2
```

**Solution:**
```bash
# Check base image in apptainer.def or Dockerfile
grep "FROM" docker/*/Dockerfile docker/*/*.def

# Should all be: FROM rocker/r-ver:4.5.2
# If not, edit and rebuild
```

---

## Integration with Pipelines

### Nextflow Pipeline (SpatialXenium)

After building containers, configure Nextflow to use them:

```bash
# Edit SpatialXenium/conf/containers.config
# Set container_base_path to: ../containers
```

Run pipeline:
```bash
cd SpatialXenium
nextflow run main.nf \
    -profile singularity \
    --input samplesheet.csv \
    --outdir results \
    --genes genes.txt
```

### R-based Pipeline (scrnaseq)

Use containerized execution scripts:

```bash
cd scrnaseq

# Preprocessing
./run_preprocessing_containerized.sh

# Analysis
./run_analysis_containerized.sh
```

---

## Best Practices

### For Reproducible Research

1. **Version Control Everything**
   ```bash
   git add docker/*/*.def
   git add docker/build_all_images.sh
   git add containers/VERSION_MANIFEST.txt
   git commit -m "Container definitions v1.0"
   git tag -a v1.0 -m "Release 1.0"
   ```

2. **Document Build Environment**
   ```bash
   # Save system info
   apptainer --version > containers/build_environment.txt
   uname -a >> containers/build_environment.txt
   date >> containers/build_environment.txt
   ```

3. **Archive Built Images**
   ```bash
   # Create tarball for distribution
   tar -czf nnclinssoap_containers_v4.5.2.tar.gz containers/
   
   # Calculate checksums
   sha256sum containers/*.sif > containers/SHA256SUMS.txt
   ```

### For Technical Publications

1. **Include in Methods Section:**
   ```
   "Container images were built using Apptainer v1.X.X from definition 
   files included in the repository (docker/*.def). All containers use 
   R version 4.5.2 with Bioconductor 3.22. Build process is fully 
   automated and documented in docker/BUILD_GUIDE.md. Container images 
   and build manifests are available at [repository URL]."
   ```

2. **Provide Build Manifest:**
   - Include `containers/VERSION_MANIFEST.txt` as supplementary material
   - Document exact package versions used

3. **Enable Reproducibility:**
   - Archive `.def` files (not just built containers)
   - Document any manual modifications
   - Provide test data and expected outputs

---

## Performance Optimization

### Parallel Builds
```bash
# Build multiple containers simultaneously (if resources allow)
./docker/build_single.sh preprocessing &
./docker/build_single.sh analysis &
./docker/build_single.sh spatialxenium &
wait
```

### Reduce Build Time

1. **Use local CRAN mirror:**
   ```r
   # Edit .def files to use local mirror
   install.packages(pkg, repos='http://your-local-mirror/', ...)
   ```

2. **Cache build layers:**
   ```bash
   # Apptainer caches automatically, but ensure cache directory has space
   export APPTAINER_CACHEDIR=/large/disk/cache
   ```

3. **Use pre-built base images:**
   - Consider building intermediate images with common dependencies
   - Use these as base for specific containers

---

## Maintenance

### Updating Containers

When R or package versions change:

1. **Update version numbers:**
   ```bash
   # Edit VERSION variable in build scripts
   # Edit FROM line in .def files
   ```

2. **Test new versions:**
   ```bash
   # Build single container first
   ./docker/build_single.sh preprocessing
   ./tests/test_containers.sh
   ```

3. **Full rebuild:**
   ```bash
   # Clean old builds
   rm containers/*.sif
   
   # Rebuild all
   ./docker/build_all_images.sh
   ```

### Adding New Packages

1. **Edit appropriate .def file:**
   ```bash
   # For preprocessing packages: docker/preprocessing/apptainer.def
   # For analysis packages: docker/analysis/apptainer.def
   # For spatial packages: docker/spatialxenium/apptainer.def
   ```

2. **Add package to correct section:**
   ```bash
   # CRAN packages
   Rscript -e "install.packages('newpackage', repos='https://cloud.r-project.org/')"
   
   # Bioconductor packages
   Rscript -e "BiocManager::install('newpackage', ask=FALSE)"
   
   # GitHub packages
   Rscript -e "remotes::install_github('user/repo')"
   ```

3. **Update tests:**
   ```bash
   # Edit tests/test_containers.sh
   # Add new package to verification list
   ```

4. **Rebuild and test:**
   ```bash
   ./docker/build_single.sh [container]
   ./tests/test_containers.sh
   ```

---

## Resource Requirements Summary

| Phase | Disk Space | Memory | CPU | Time |
|-------|------------|--------|-----|------|
| Single build | ~10 GB | 8 GB | 2+ cores | 2-3 hours |
| Full build | ~30 GB | 16 GB | 4+ cores | 6-8 hours |
| Storage (final) | ~5 GB | - | - | - |

---

## Getting Help

### Check Logs
```bash
# View recent build log
ls -lt docker/logs/ | head
tail -n 100 docker/logs/build_*.log
```

### Common Log Locations
- Build logs: `docker/logs/build_*_YYYYMMDD.log`
- Container stderr: Captured in build logs
- Test output: Terminal output from `test_containers.sh`

### Debug Mode
```bash
# Add verbose output
apptainer build --force --verbose \
    containers/test.sif \
    docker/preprocessing/apptainer.def 2>&1 | tee debug.log
```

---

## Appendix

### A. Complete Build Command Reference

```bash
# All containers
./docker/build_all_images.sh

# Single container (3 options)
./docker/build_single.sh preprocessing
./docker/build_single.sh analysis
./docker/build_single.sh spatialxenium

# Manual build from .def
apptainer build --force containers/[name].sif docker/[name]/apptainer.def

# Manual build from Dockerfile
docker build -t nnclinssoap/[name]:4.5.2 docker/[name]/
apptainer build --force containers/[name].sif docker-daemon://nnclinssoap/[name]:4.5.2
```

### B. Environment Variables

| Variable | Purpose | Example |
|----------|---------|---------|
| `GITHUB_PAT` | Avoid GitHub rate limits | `export GITHUB_PAT="ghp_..."` |
| `APPTAINER_TMPDIR` | Temp build directory | `export APPTAINER_TMPDIR=/scratch/tmp` |
| `APPTAINER_CACHEDIR` | Cache location | `export APPTAINER_CACHEDIR=/scratch/cache` |

### C. File Checksums

After building, verify integrity:
```bash
sha256sum containers/*.sif > containers/SHA256SUMS.txt
cat containers/SHA256SUMS.txt
```

To verify later:
```bash
cd containers
sha256sum -c SHA256SUMS.txt
```

---

## Contact & Support

**Maintainer:** zemw@novonordisk.com  
**Repository:** nnclinssoap  
**Version:** 4.5.2  
**Last Updated:** December 26, 2025

For issues or questions:
1. Check this BUILD_GUIDE.md
2. Review build logs in `docker/logs/`
3. Run test suite: `./tests/test_containers.sh`
4. Contact maintainer with log files attached
