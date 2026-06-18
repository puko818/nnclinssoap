# Container Builds - Documentation Index

**nnclinssoap Container Build System**  
**Version:** 1.0  
**Last Updated:** December 26, 2025

---

## 📚 Documentation Files

### Quick Start
- **[QUICK_START.md](QUICK_START.md)** - Fast reference guide (read this first!)
  - 30-second prerequisites check
  - Build commands
  - Common troubleshooting

### Comprehensive Guides
- **[BUILD_GUIDE.md](BUILD_GUIDE.md)** - Complete build documentation
  - Detailed step-by-step instructions
  - Build sequence and timing
  - Integration with pipelines
  - Best practices for publications

- **[DEPENDENCIES.md](DEPENDENCIES.md)** - Requirements and setup
  - Software prerequisites
  - System requirements
  - Network dependencies
  - HPC/SLURM configuration

### Container Definitions
- **[preprocessing/](preprocessing/)** - QC, doublet detection, batch correction
  - `apptainer.def` - Build definition
  - `Dockerfile` - Alternative Docker build
  - `README.md` - Package details

- **[analysis/](analysis/)** - Cell annotation, differential expression
  - `apptainer.def` - Build definition
  - `Dockerfile` - Alternative Docker build
  - `README.md` - Package details

- **[spatialxenium/](spatialxenium/)** - Spatial transcriptomics
  - `apptainer.def` - Build definition
  - `Dockerfile` - Alternative Docker build
  - `README.md` - Package details

### Build Scripts
- **[build_all_images.sh](build_all_images.sh)** - Build all containers
- **[build_single.sh](build_single.sh)** - Build individual container
- **[check_prerequisites.sh](check_prerequisites.sh)** - Verify environment

---

## 🚀 Quick Start (30 seconds)

```bash
# 1. Check prerequisites
./docker/check_prerequisites.sh

# 2. If all checks pass, build
./docker/build_all_images.sh

# 3. Verify builds
./tests/test_containers.sh
```

---

## 📋 Documentation Roadmap

**First time building?** Follow this order:

1. **Start here:** [QUICK_START.md](QUICK_START.md)
   - Get overview of process
   - Check prerequisites
   - Start first build

2. **Having issues?** [DEPENDENCIES.md](DEPENDENCIES.md)
   - Verify all software installed
   - Check system requirements
   - Configure network/proxies

3. **Need details?** [BUILD_GUIDE.md](BUILD_GUIDE.md)
   - Understand build process
   - Customize builds
   - Integrate with pipelines

4. **Container details?** Check `docker/*/README.md`
   - Package versions
   - Specific purposes
   - Known issues

---

## 📊 Build Overview

### Containers

| Container | Purpose | Build Time | Size |
|-----------|---------|------------|------|
| base | Shared Seurat/Bioconductor/tidyverse layer | ~6 min | ~2.5 GB |
| preprocessing | QC, doublets, batch correction | ~3 min | ~3.2 GB |
| analysis | Annotation, differential expression | ~10 min | ~4.7 GB |
| spatialxenium | Spatial transcriptomics | ~1 min | ~2.6 GB |

**Total:** ~20 min (binary-package build via Posit P3M, tested with 16vCPUs+128GB RAM)

### Requirements

- **Software:** Apptainer ≥1.0.0 or Singularity ≥3.8.0
- **Disk:** 20-30 GB free space
- **Memory:** 8-16 GB RAM
- **Network:** Stable internet (2-4 GB download)
- **Optional:** GitHub PAT (avoid rate limits)

---

## 🔧 Build Commands

### Check Environment
```bash
./docker/check_prerequisites.sh
```

### Build All (Recommended)
```bash
./docker/build_all_images.sh
```

### Build Single (For Testing)
```bash
./docker/build_single.sh [preprocessing|analysis|spatialxenium]
```

### Submit to SLURM (HPC)
```bash
module load apptainer
sbatch docker/build_all_images.sh
```

---

## ✅ Validation

### After building:
```bash
# Test all containers
./tests/test_containers.sh

# Check manifest
cat containers/VERSION_MANIFEST.txt

# Verify checksums
cd containers
sha256sum *.sif > SHA256SUMS.txt
```

---

## 🐛 Troubleshooting

### Common Issues

**Build fails:**
- Check disk space: `df -h .`
- Check memory: `free -h`
- Review logs: `less docker/logs/build_*.log`

**GitHub rate limit:**
```bash
export GITHUB_PAT="your_token"
```

**No space left:**
```bash
apptainer cache clean --all
export APPTAINER_TMPDIR=/larger/disk/tmp
```

**See:** [BUILD_GUIDE.md](BUILD_GUIDE.md#troubleshooting-guide) for complete troubleshooting

---

## 📦 Output Structure

After successful build:

```
nnclinssoap/
├── containers/                                      # Built images
│   ├── scrnaseq-preprocessing_4.5.2.sif
│   ├── scrnaseq-analysis_4.5.2.sif
│   ├── scrnaseq-spatialxenium_4.5.2.sif
│   └── VERSION_MANIFEST.txt                        # Build details
└── docker/
    └── logs/                                        # Build logs
        ├── build_preprocessing_YYYYMMDD.log
        ├── build_analysis_YYYYMMDD.log
        └── build_spatialxenium_YYYYMMDD.log
```

---

## 🔗 Integration

### With Nextflow Pipeline (SpatialXenium)
```bash
cd ../SpatialXenium
nextflow run main.nf -profile singularity --input samplesheet.csv --outdir results
```
- Configuration: `SpatialXenium/conf/containers.config`
- Automatically uses `../containers/*.sif`

### With R-based Pipeline (scrnaseq)
```bash
cd ../scrnaseq
./run_preprocessing_containerized.sh
./run_analysis_containerized.sh
```
- Execution scripts use containers directly
- No additional configuration needed

---

## 📖 Complete Documentation

| Document | Purpose | When to Use |
|----------|---------|-------------|
| [QUICK_START.md](QUICK_START.md) | Fast reference | Starting new build, quick lookup |
| [BUILD_GUIDE.md](BUILD_GUIDE.md) | Comprehensive guide | First-time setup, troubleshooting |
| [DEPENDENCIES.md](DEPENDENCIES.md) | Requirements | Environment setup, prerequisites |
| docker/*/README.md | Package details | Understanding container contents |

---

## 🎯 For Technical Publications

When documenting in publications:

1. **Include build manifests:**
   - `containers/VERSION_MANIFEST.txt`
   - Shows exact package versions used

2. **Reference definition files:**
   - `docker/*/apptainer.def`
   - Complete reproducible specifications

3. **Document build process:**
   ```
   "Container images were built using Apptainer v1.X.X from 
   definition files included in the repository (docker/*.def). 
   All containers use R version 4.5.2 with Bioconductor 3.22. 
   Build process is fully automated and documented in 
   docker/BUILD_GUIDE.md."
   ```

4. **Archive for reproducibility:**
   ```bash
   # Create distribution archive
   tar -czf nnclinssoap_containers_v4.5.2.tar.gz \
       containers/*.sif \
       containers/VERSION_MANIFEST.txt \
       docker/*/*.def
   
   # Calculate checksums
   sha256sum containers/*.sif > containers/SHA256SUMS.txt
   ```

---

## 💡 Tips

- **For first-time users:** Read [QUICK_START.md](QUICK_START.md), run `check_prerequisites.sh`, then build
- **For HPC users:** Set `APPTAINER_CACHEDIR` to scratch space before building
- **For publications:** Archive both `.def` files and `VERSION_MANIFEST.txt`
- **For troubleshooting:** Always check `docker/logs/build_*.log` first
- **For updates:** Modify `.def` files, bump version, rebuild

---

## 📞 Support

- **Documentation:** See links above
- **Maintainer:** zemw@novonordisk.com
- **Repository:** /path/to/nnclinssoap

When reporting issues, include:
- Output from `check_prerequisites.sh`
- Relevant build log: `docker/logs/build_*.log`
- System info: `apptainer --version`, `uname -a`

---

**Quick Links:**
- 🚀 [Quick Start](QUICK_START.md)
- 📖 [Build Guide](BUILD_GUIDE.md)
- 🔧 [Dependencies](DEPENDENCIES.md)
- ✅ [Check Prerequisites](check_prerequisites.sh)
- 🏗️ [Build Script](build_all_images.sh)

---

**Last Updated:** December 26, 2025  
**Version:** 1.0
