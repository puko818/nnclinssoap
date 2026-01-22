# scRNA-seq Preprocessing Docker Environment

## Dockerfile

- **Base image**: rocker/r-ver:4.5.2 - Official R Docker image from the Rocker Project
- **R Version**: R 4.5.2
- **Bioconductor Version**: 3.22

## Main Tool Libraries

- **Seurat 5.1.0**: Comprehensive toolkit for single-cell genomics data analysis
- **SeuratObject 5.0.2**: Data structures and methods for Seurat objects
- **SoupX 1.6.2**: Removal of ambient RNA contamination from single-cell data
- **scDblFinder 1.22.0**: Doublet detection in single-cell RNA sequencing data
- **harmony 1.2.2**: Integration of single-cell data from multiple batches/conditions
- **DropletUtils 1.28.0**: Utilities for handling droplet-based single-cell RNA-seq data
- **glmGamPoi 1.20.0**: Fast and accurate fitting of gamma-Poisson GLMs for single-cell count data

## Additional Libraries

### Data Manipulation
- **dplyr 1.1.4**, **tidyr 1.3.1**, **tibble 3.2.1**: Tidyverse data manipulation
- **yaml 2.3.10**: YAML configuration file parsing
- **magrittr 2.0.3**: Pipe operators for R
- **data.table 1.16.4**: High-performance data manipulation
- **reshape2 1.4.4**: Data reshaping

### Visualization
- **ggplot2 3.5.1**: Grammar of graphics plotting
- **patchwork 1.3.0**: Combining multiple plots
- **viridis 0.6.5**: Colorblind-friendly color palettes
- **RColorBrewer 1.1-3**: Color palettes
- **Cairo 1.6-2**: Graphics device for high-quality output

### File I/O
- **hdf5r 1.3.11**: Interface to HDF5 files
- **HDF5Array 1.36.0**: HDF5-backed arrays for large datasets

### Bioconductor Core
- **SingleCellExperiment 1.30.3**: S4 classes for single-cell data
- **BiocNeighbors 2.0.0**: Nearest neighbor detection for Bioconductor
- **BiocSingular 1.24.0**: Singular value decomposition methods
- **org.Hs.eg.db 3.20.0**: Human genome annotation database

### Analysis Tools
- **irlba 2.3.5.1**: Fast truncated SVD
- **uwot 0.2.2**: UMAP implementation
- **Rtsne 0.17**: t-SNE implementation
- **leiden 0.4.3.1**: Community detection algorithm
- **igraph 2.1.4**: Network analysis and graph algorithms

### Performance
- **Rcpp 1.0.13-1**, **RcppArmadillo 14.2.2-1**, **RcppEigen 0.3.4.0.2**: C++ integration
- **future 1.34.0**, **future.apply 1.11.3**: Parallel processing
- **Matrix 1.7-1**: Sparse and dense matrix operations

## Purpose

This Docker image is designed for the preprocessing workflow of single-cell RNA-seq data, including:
- Quality control and filtering
- Ambient RNA removal (SoupX)
- Doublet detection (scDblFinder)
- Normalization and scaling
- Dimensionality reduction (PCA, UMAP, t-SNE)
- Clustering
- Batch correction (harmony)
- Data integration

## Key Features

- **Quality Control**: Comprehensive QC metrics and filtering
- **Ambient RNA Removal**: SoupX for decontamination
- **Doublet Detection**: scDblFinder for identifying multiplets
- **Batch Integration**: Harmony for batch effect correction
- **Efficient Processing**: Optimized packages for large-scale single-cell data
- **Droplet Utilities**: DropletUtils for droplet-based protocols (10x, Drop-seq, etc.)
- **Fast GLM Fitting**: glmGamPoi for efficient statistical modeling

## Usage

```bash
# Build the image
docker build -t scrnaseq-seurat-soupx-harmony:4.5.2 .

# Run interactively
docker run -it --rm -v $(pwd):/workspace scrnaseq-seurat-soupx-harmony:4.5.2

# Run a script
docker run --rm -v $(pwd):/workspace scrnaseq-seurat-soupx-harmony:4.5.2 Rscript preprocessing_workflow.R
```

## Workflow Compatibility

This environment is specifically designed for the `preprocessing_workflow.R` script, which includes:
1. Data loading (matrix, barcode, features, or h5 formats)
2. Seurat object creation
3. QC metrics calculation
4. Filtering and subsetting
5. Normalization
6. Cell cycle scoring
7. Variable feature identification
8. Scaling and PCA
9. Clustering and UMAP
10. Doublet detection
11. Optional data integration

## Maintainer

zemw <zemw@novonordisk.com>
