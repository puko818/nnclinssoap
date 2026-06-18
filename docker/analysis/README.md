# scRNA-seq Analysis Docker Environment

## Dockerfile

- **Base image**: rocker/r-ver:4.5.2 - Official R Docker image from the Rocker Project
- **R Version**: R 4.5.2
- **Bioconductor Version**: 3.22

## Main Tool Libraries

### Cell Annotation
- **Azimuth (GitHub: satijalab/azimuth)**: Reference-based cell type annotation using Seurat reference datasets
- **SingleR 2.10.0**: Automated cell type annotation using reference transcriptomic datasets
- **celldex 1.18.0**: Reference datasets for SingleR

### Multimodal Analysis
- **Signac 1.15.0**: Analysis of single-cell chromatin data (ATAC-seq, multiome)
- **SeuratData (GitHub: satijalab/seurat-data)**: Datasets for Seurat
- **SeuratDisk (GitHub: mojaveazure/seurat-disk)**: Interfaces for HDF5-based single-cell file formats

### Core Analysis
- **Seurat 5.1.0**: Comprehensive toolkit for single-cell genomics
- **SeuratObject 5.0.2**: Data structures for Seurat
- **SoupX 1.6.2**: Ambient RNA removal

### Differential Expression
- **edgeR 4.6.2**: Empirical analysis of digital gene expression data
- **limma 3.64.2**: Linear models for microarray and RNA-seq data
- **DESeq2 1.48.0**: Differential gene expression analysis

## Additional Libraries

### Data Manipulation
- **dplyr 1.1.4**, **tidyr 1.3.1**, **tibble 3.2.1**: Tidyverse data manipulation
- **readxl 1.4.3**: Read Excel files
- **yaml 2.3.10**: YAML configuration parsing
- **data.table 1.16.4**: High-performance data manipulation
- **reshape2 1.4.4**: Data reshaping

### Visualization
- **ggplot2 3.5.1**: Grammar of graphics plotting
- **ggpubr 0.6.0**: Publication-ready plots
- **ggthemes 5.1.0**: Additional themes for ggplot2
- **ggrepel 0.9.6**: Non-overlapping text labels
- **patchwork 1.3.0**: Combining plots
- **cowplot 1.1.3**: Publication-quality figures
- **pheatmap 1.0.12**: Pretty heatmaps
- **DT 0.33**: Interactive tables
- **viridis 0.6.5**: Colorblind-friendly palettes
- **Cairo 1.6-2**: High-quality graphics

### File I/O
- **hdf5r 1.3.11**: HDF5 file interface
- **HDF5Array 1.36.0**: HDF5-backed arrays

### Genome Annotation
- **org.Hs.eg.db 3.20.0**: Human genome annotation
- **BSgenome.Hsapiens.UCSC.hg38 1.4.5**: Human genome sequences
- **EnsDb.Hsapiens.v86 2.99.0**: Ensembl-based annotation
- **JASPAR2020 0.99.10**: Transcription factor binding profiles
- **AnnotationHub 3.16.0**: Access to Bioconductor annotation resources

### Bioconductor Core
- **SingleCellExperiment 1.30.3**: S4 classes for single-cell data
- **GenomicRanges 1.60.1**: Genomic interval operations
- **GenomicFeatures 1.60.2**: Tools for genomic annotations
- **BiocNeighbors 2.0.0**: Nearest neighbor detection
- **AnnotationFilter 1.32.0**: Filtering annotation resources

### Analysis Tools
- **irlba 2.3.5.1**: Fast truncated SVD
- **uwot 0.2.2**: UMAP implementation
- **Rtsne 0.17**: t-SNE implementation
- **leiden 0.4.3.1**: Community detection
- **igraph 2.1.4**: Network analysis
- **glmGamPoi 1.20.0**: Fast GLM fitting for count data
- **DirichletMultinomial 1.50.0**: Dirichlet-multinomial models

### Performance
- **Rcpp 1.0.13-1**, **RcppArmadillo 14.2.2-1**: C++ integration
- **future 1.34.0**, **future.apply 1.11.3**: Parallel processing
- **parallel**: Base R parallel computing
- **Matrix 1.7-1**: Sparse and dense matrices

## Purpose

This Docker image is designed for downstream analysis of preprocessed single-cell RNA-seq data, including:
- Automated cell type annotation (Azimuth, SingleR)
- Reference-based annotation with multiple databases
- Differential expression analysis (edgeR, limma, DESeq2)
- Multimodal single-cell analysis (Signac)
- Advanced visualization and reporting
- Statistical modeling and hypothesis testing

## Key Features

- **Multiple Annotation Methods**: Azimuth for reference-based and SingleR for automated annotation
- **Flexible Reference Databases**: celldex provides multiple reference datasets (DICE, HPCA, Monaco, etc.)
- **Comprehensive DE Analysis**: edgeR, limma, and DESeq2 for robust differential expression
- **Multimodal Support**: Signac for ATAC-seq and multiome data analysis
- **Publication-Ready Visualization**: Advanced plotting with ggpubr, pheatmap, and cowplot
- **Interactive Reports**: DT for interactive tables
- **Genome Annotation**: Multiple annotation resources including JASPAR for TF analysis

## Usage

```bash
# Build the image
docker build -t nnclinssoap/scrnaseq-analysis:4.5.2 .

# Run interactively
docker run -it --rm -v $(pwd):/workspace nnclinssoap/scrnaseq-analysis:4.5.2

# Run cell annotation script
docker run --rm -v $(pwd):/workspace nnclinssoap/scrnaseq-analysis:4.5.2 Rscript cell_annotation.R

# Run differential expression script
docker run --rm -v $(pwd):/workspace nnclinssoap/scrnaseq-analysis:4.5.2 Rscript de_analysis.R
```

## Workflow Compatibility

This environment is specifically designed for:

### Cell Annotation (`cell_annotation.R`)
- SingleR annotation with multiple reference databases (DICE, HPCA, Blueprint/ENCODE, Monaco, etc.)
- Azimuth reference-based annotation (PBMC, lung, kidney, etc.)
- Marker gene identification
- Annotation quality metrics and diagnostics
- Visualization of cell type predictions

### Differential Expression (`de_analysis.R`)
- Pseudo-bulk aggregation
- edgeR-based differential expression analysis
- Linear modeling with patient effects
- Interaction testing (treatment vs. placebo)
- Volcano plots and top gene visualization
- Normalized count matrix export

## Supported Annotation References

### SingleR (via celldex)
- `dice`: Database of Immune Cell Expression
- `hpca`: Human Primary Cell Atlas
- `blueprint_encode`: Blueprint/ENCODE data
- `monaco_immune`: Monaco Immune Cell data
- `novershtern_hematopoietic`: Novershtern Hematopoietic data

### Azimuth
- `pbmcref`: PBMC reference
- Multiple tissue-specific references available through Azimuth

## Maintainer

zemw <zemw@novonordisk.com>
