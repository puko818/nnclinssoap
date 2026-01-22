## Dockerfile

- Base image: rocker/r-ver:4.3.2. Official R Docker image from the Rocker Project, providing a stable R environment.
- R Version: R 4.3.2. A stable R version for spatial single-cell analysis.

Main tool lib(s):
- presto 1.0.0: Fast implementation of Wilcoxon rank sum test and auROC analysis optimized for large-scale single-cell data. Installed from GitHub (immunogenomics/presto).
- Seurat 5.1.0: Comprehensive toolkit for single-cell genomics data analysis, including quality control, analysis, and exploration.
- SeuratObject 5.0.2: Data structures and methods for Seurat objects.

Additional lib(s):
- sctransform 0.4.1: Variance stabilization and normalization for single-cell UMI count data.
- argparser 0.7.2: Command-line argument parsing for R scripts.
- arrow 18.1.0: R interface to Apache Arrow for efficient columnar data processing.
- ggExtra 0.10.1: Marginal density plots and enhancements for ggplot2 visualizations.
- dplyr 1.1.4, tidyr 1.3.1, tibble 3.2.1, purrr 1.0.2, stringr 1.5.1: Tidyverse packages for data manipulation.
- ggplot2 3.5.1, ggrepel 0.9.6, ggridges 0.5.6, cowplot 1.1.3, patchwork 1.3.0: Visualization libraries.
- Matrix 1.6.5, data.table 1.15.4: High-performance data structures.
- spatstat.* packages (spatstat.geom, spatstat.explore, etc.): Spatial statistics and analysis toolkit.
- sp 2.1.4, deldir 2.0-4, polyclip 1.10-7: Spatial data handling and geometric operations.
- irlba 2.3.5.1, RSpectra 0.16-2, Rtsne 0.17, uwot 0.1.16: Dimensionality reduction algorithms.
- igraph 2.0.3, leiden 0.4.3.1: Graph analysis and community detection.
- Rcpp 1.0.13-1, RcppArmadillo 14.2.2-1, RcppEigen 0.3.4.0.2: High-performance C++ integration for R.
- devtools 2.4.5, remotes 2.5.0: Development tools for package installation from GitHub.

## Version.txt
As **presto** is the key library that must be installed from GitHub (not available on CRAN), the version represents **presto** version used (1.0.0).

## Purpose
This image was created to support spatial transcriptomics and single-cell RNA-seq analysis workflows, particularly for Xenium spatial data. It combines the fast differential expression testing of presto with the comprehensive analysis capabilities of Seurat, along with spatial analysis tools and modern data processing libraries.


## Key Features
- **Fast differential expression**: presto provides optimized Wilcoxon rank sum tests for single-cell data
- **Comprehensive single-cell analysis**: Full Seurat ecosystem for clustering, visualization, and annotation
- **Spatial analysis**: Complete spatstat suite for spatial statistics
- **Modern data processing**: Arrow for efficient data I/O, data.table for high-performance operations
- **Visualization**: Rich set of plotting libraries including ggplot2 extensions
- **Command-line ready**: argparser for creating user-friendly R scripts
