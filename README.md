# nnclinssoap

**Novo Nordisk Clinical Single-cell Spatial Omics Analytical Pipeline**

[![Nextflow](https://img.shields.io/badge/nextflow-%E2%89%A523.10.0-brightgreen.svg)](https://www.nextflow.io/)
[![Singularity](https://img.shields.io/badge/singularity-%E2%89%A53.8-blue.svg)](https://sylabs.io/singularity/)
[![R](https://img.shields.io/badge/R-4.5.2-blue.svg)](https://www.r-project.org/)

---

## Overview

A comprehensive analysis framework for spatial transcriptomics data, with primary focus on 10x Genomics Xenium platform. The repository provides both Nextflow-based and R-based workflows for processing and analyzing spatial single-cell data.

### Repository Structure

```
nnclinssoap/
├── docker/                    # Container definitions (Dockerfiles & Apptainer .def)
│   ├── preprocessing/         # QC, doublet detection, ambient RNA removal
│   ├── analysis/              # Cell annotation, differential expression
│   └── spatialxenium/        # Xenium-specific spatial analysis
├── containers/                # Built Singularity images (.sif files)
├── SpatialXenium/            # Nextflow pipeline (nf-core style)
├── scrnaseq/                 # R-based pipeline using whirl
├── test_data/                # Test datasets (gitignored, auto-downloaded)
└── tests/                    # Testing scripts and validation
```

---

## Quick Start

### 1. Check Prerequisites
```bash
./docker/check_build_prerequisites.sh
```

### 2. Build Containers
```bash
cd docker
sbatch build_all_images.sh  # SLURM
# Or: bash build_all_images.sh  # Interactive

# Builds 4 containers: preprocessing, analysis, spatialxenium, qc-report
# Total time: ~6-8 hours (parallelizable)
```

### 3. Download Test Data
```bash
./setup_test_data.sh
```

### 4. Run Pipeline
```bash
cd SpatialXenium
nextflow run main.nf -profile test,singularity --outdir test_results
```

**Full guide:** See [`docs/QUICKSTART.md`](docs/QUICKSTART.md)

---

## Pipelines

### SpatialXenium (Nextflow)

**Purpose:** Automated spatial transcriptomics analysis  
**Platform:** 10x Genomics Xenium  
**Features:**
- Quality control and filtering
- Spatial feature analysis
- Optional reference-based cell type annotation
- Comprehensive QC reporting

**Documentation:** [`SpatialXenium/README.md`](SpatialXenium/README.md)

### scrnaseq (R-based)

**Purpose:** Flexible R workflow for single-cell analysis  
**Framework:** whirl package  
**Workflows:**
- Preprocessing: QC, doublet detection, batch correction
- Analysis: Cell annotation, differential expression

**Documentation:** [`scrnaseq/README.md`](scrnaseq/README.md)

---

## Container Images

All R-based containers use **R 4.5.2** with **Bioconductor 3.22**

| Container | Purpose | Key Packages | Size |
|-----------|---------|--------------|------|
| **preprocessing** | QC & batch correction | Seurat, SoupX, scDblFinder, harmony | ~1.7 GB |
| **analysis** | Annotation & DE | Azimuth, SingleR, edgeR, Signac | ~2.6 GB |
| **spatialxenium** | Spatial analysis | presto, Seurat, argparser, arrow, spatstat | ~2.0 GB |
| **qc-report** | QC PDF generation | Python 3.11, fpdf2 | ~62 MB |

**Build documentation:** [`docker/BUILD_GUIDE.md`](docker/BUILD_GUIDE.md)

---

## Testing

### Quick Test
```bash
./test_spatialxenium_quick.sh
```

### Full Pipeline Test
```bash
cd SpatialXenium
nextflow run main.nf -profile test,singularity --outdir test_results
```

**Testing guide:** [`docs/TESTING_GUIDE.md`](docs/TESTING_GUIDE.md)

---

## Documentation

| Document | Description |
|----------|-------------|
| [`docs/QUICKSTART.md`](docs/QUICKSTART.md) | One-page quick reference |
| [`docs/TESTING_GUIDE.md`](docs/TESTING_GUIDE.md) | Complete testing procedures |
| [`docs/EXECUTIVE_SUMMARY.md`](docs/EXECUTIVE_SUMMARY.md) | Project status and accomplishments |
| [`docs/PR_SUMMARY.md`](docs/PR_SUMMARY.md) | Pull request summary and checklist |
| [`docker/BUILD_GUIDE.md`](docker/BUILD_GUIDE.md) | Container build guide |
| [`docs/DOCKER_TO_PIPELINE_INTEGRATION_ANALYSIS.md`](docs/DOCKER_TO_PIPELINE_INTEGRATION_ANALYSIS.md) | Technical analysis & architecture |

---

## Requirements

### System
- Linux OS (tested on SLURM HPC)
- 16+ GB RAM (32+ GB recommended)
- 20+ GB disk space for containers and test data

### Software
- Apptainer/Singularity ≥3.8
- Nextflow ≥23.10.0
- Standard Linux tools (wget/curl, unzip, tar)

---

## Data Sources

### Test Data (Auto-downloaded)
- **Non-diseased kidney:** Xenium V1 human kidney (10x Genomics)
- **Cancer kidney:** Xenium V1 kidney cancer (10x Genomics)
- **Total size:** ~6 GB

### Optional Reference Data
- Kidney reference: [Azimuth HubMAP](https://azimuth.hubmapconsortium.org/references/#Human%20-%20Kidney)
- Additional datasets: [10x Genomics Dataset Explorer](https://www.10xgenomics.com/products/xenium-in-situ/dataset-explorer)

---

## Usage Examples

### Basic Xenium Processing
```bash
cd SpatialXenium
nextflow run main.nf \
    -profile singularity \
    --input samplesheet.csv \
    --outdir results
```

### With Reference-based Annotation
```bash
nextflow run main.nf \
    -profile singularity \
    --input samplesheet.csv \
    --reference_rds kidney_reference.rds \
    --single_cell_label_col "cell_type" \
    --outdir results
```

### With Gene List for Feature Plots
```bash
nextflow run main.nf \
    -profile singularity \
    --input samplesheet.csv \
    --genes genes.txt \
    --outdir results
```

---

## Input Format

### Samplesheet (CSV)
```csv
sample,xenium_path
sample1,/path/to/xenium/output
sample2,/path/to/xenium/output
```

### Gene List (TXT)
```
GENE1
GENE2
GENE3
```

---

## Output Structure

```
results/
├── sample1/
│   ├── seurat_xenium/
│   │   ├── sample1_processed.rds      # Seurat object
│   │   ├── QC_plots.png               # Quality control
│   │   └── session_info.txt           # R session info
│   └── label_transfer/                # If reference provided
│       ├── sample1_labeled.rds
│       └── celltype_predictions.csv
└── pipeline_info/
    ├── execution_report.html          # Resource usage
    ├── execution_timeline.html        # Timeline
    └── execution_trace.txt            # Detailed trace
```

---

## Development

### Repository is Publication-Ready

All code and documentation designed for technical publication:
- ✅ Portable paths (no hard-coded external dependencies)
- ✅ Comprehensive documentation
- ✅ Reproducible builds with version control
- ✅ Test data auto-download
- ✅ Validation and testing framework

### Contributing

This is a technical research repository. For improvements:
1. Test changes thoroughly
2. Update relevant documentation
3. Maintain portability (no external paths)
4. Follow existing code style

---

## Troubleshooting

### Common Issues

**Container not found**
```bash
ls containers/*.sif
cd docker && bash build_all_images.sh
```

**Test data incomplete**
```bash
./setup_test_data.sh
find test_data/ -name "*.tar.gz"  # Should be empty
```

**Pipeline fails**
```bash
tail SpatialXenium/.nextflow.log
nextflow run main.nf -profile test,singularity -resume
```

**Full troubleshooting:** See [`TESTING_GUIDE.md`](TESTING_GUIDE.md#common-issues-and-solutions)

---

## Citation

If you use this pipeline in your research, please cite:

```
[Citation information to be added upon publication]
```

---

## License

Code - Apache License 2.0
Documentation - CC BY 4.0

---

## Contact

**Maintainer:** Martin E. Garcia Sola, Amaya Zaratiegui, Timothy Burfield  
**Email:**   martin.garciasola@zs.com, azeu@novonordisk.com, tmbf@novonordisk.com
**Institution:** ZS Associates & Novo Nordisk A/S

---

## Acknowledgments

- Built using [nf-core](https://nf-co.re/) framework
- Test data from [10x Genomics](https://www.10xgenomics.com/)
- Container infrastructure based on [Rocker Project](https://rocker-project.org/)

---

**Version:** 1.0  
**Last Updated:** January 23, 2026
