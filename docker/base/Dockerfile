# Base image for all scRNA-seq workflow containers
# Contains all R packages shared across preprocessing, analysis, and spatialxenium
# Derived containers use: FROM nnclinssoap/scrnaseq-base:4.5.2

FROM rocker/r-ver:4.5.2

LABEL maintainer="zemw@novonordisk.com"
LABEL description="Base R 4.5.2 environment with Seurat and common dependencies"
LABEL version="4.5.2"

# System dependencies (superset across all derived containers)
RUN apt-get update && apt-get install -qq \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libgit2-dev \
    libfontconfig1-dev \
    libharfbuzz-dev \
    libfribidi-dev \
    libfreetype6-dev \
    libpng-dev \
    libtiff5-dev \
    libjpeg-dev \
    libhdf5-dev \
    libudunits2-dev \
    libgdal-dev \
    libgeos-dev \
    libproj-dev \
    libfftw3-dev \
    libgsl-dev \
    libcairo2-dev \
    librsvg2-dev \
    libprotobuf-dev \
    protobuf-compiler \
    libglpk-dev \
    pkg-config \
    cmake \
    git \
    wget \
    build-essential \
    libnode-dev \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

RUN R -e "install.packages(c('devtools', 'remotes', 'BiocManager', 'renv'), repos='https://cloud.r-project.org/', dependencies=TRUE)"

RUN R -e "BiocManager::install(version='3.22', ask=FALSE)"

# Rcpp family (superset across all containers)
RUN Rscript -e " \
    install.packages( \
        c('Rcpp', 'RcppArmadillo', 'RcppEigen', 'RcppAnnoy', 'RcppHNSW', \
          'RcppProgress', 'RcppRoll', 'RcppTOML', 'RcppML'), \
        repos='https://cloud.r-project.org/', dependencies=TRUE); \
    "

RUN Rscript -e "install.packages('Matrix', repos='https://cloud.r-project.org/', dependencies=TRUE)"

# Data manipulation (superset across all containers)
RUN Rscript -e " \
    install.packages( \
        c('tidyverse', 'dplyr', 'tidyr', 'tibble', 'purrr', 'stringr', \
          'ggplot2', 'readr', 'readxl', 'data.table', 'reshape2', \
          'plyr', 'yaml', 'magrittr'), \
        repos='https://cloud.r-project.org/', dependencies=TRUE); \
    "

# Visualization (common subset — spatialxenium-specific viz stays in that container)
RUN Rscript -e " \
    install.packages( \
        c('ggrepel', 'ggridges', 'cowplot', 'patchwork', \
          'scales', 'viridis', 'viridisLite', 'RColorBrewer', 'Cairo'), \
        repos='https://cloud.r-project.org/', dependencies=TRUE); \
    "

# Dimensionality reduction, clustering, parallelism
RUN Rscript -e " \
    install.packages( \
        c('irlba', 'RSpectra', 'Rtsne', 'uwot', 'FNN', 'RANN', \
          'igraph', 'leiden', 'future', 'future.apply', 'progressr'), \
        repos='https://cloud.r-project.org/', dependencies=TRUE); \
    "

# HDF5
RUN Rscript -e "install.packages('hdf5r', repos='https://cloud.r-project.org/', dependencies=TRUE)"
RUN Rscript -e "BiocManager::install(c('rhdf5', 'Rhdf5lib', 'HDF5Array'), ask=FALSE)"

# Bioconductor core
RUN Rscript -e " \
    BiocManager::install(c( \
        'BiocGenerics', 'S4Vectors', 'IRanges', 'GenomeInfoDb', \
        'GenomicRanges', 'Biobase', 'SummarizedExperiment', \
        'SingleCellExperiment', 'DelayedArray', 'DelayedMatrixStats', \
        'BiocNeighbors', 'BiocSingular', 'beachmat', 'ScaledMatrix' \
    ), ask=FALSE); \
    "

# Seurat ecosystem
RUN Rscript -e " \
    install.packages( \
        c('SeuratObject', 'Seurat', 'sctransform'), \
        repos='https://cloud.r-project.org/', dependencies=TRUE); \
    "

ENV LC_ALL=C
ENV PATH=/usr/local/bin:$PATH
ENV R_LIBS_USER=/usr/local/lib/R/site-library

WORKDIR /workspace
CMD ["R"]
