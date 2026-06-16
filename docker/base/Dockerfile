# Base image for all scRNA-seq workflow containers — binary-package build.
# Derived containers use: FROM nnclinssoap/scrnaseq-base:4.5.2
# Goal: cut build time from ~4h to ~6min by avoiding source compilation and the
# bioconductor.org redirect hang. Two changes vs the original Dockerfile:
#   - CRAN packages come from Posit P3M  __linux__/noble  binary repo (precompiled)
#   - Bioc packages come from P3M's Bioc mirror (redirect-free; still source-built
#     since P3M has no Bioc Linux binaries, but the ~2h bioconductor.org index hang
#     is gone and the compiles are fast under parallel make)
# Also drops `repos='https://cloud.r-project.org/'` (source-only on Linux) and
# `dependencies=TRUE` (pulled the unused Suggests tree).
#
# Stays on the lean rocker base (≈1.5GB image vs ≈5.4GB for bioconductor_docker);
# the apt superset below supplies every -dev lib the Bioc source builds need.
#
# Build:  docker build -t nnclinssoap/scrnaseq-base:4.5.2 docker/base

FROM rocker/r-ver:4.5.2

LABEL maintainer="zemw@novonordisk.com"
LABEL description="Base R 4.5.2 / Bioc 3.22 environment with Seurat — binary-package build"
LABEL version="4.5.2"

# P3M repos. CRAN packages are precompiled binaries (the big win); Bioc packages
# are source (P3M has no Bioc Linux binaries) but served redirect-free.
# CRITICAL: BiocManager's default Bioc repos point at bioconductor.org, whose
# BioCsoft index 302-redirects to a mirror that hangs >90s per request from some
# networks (verified — it stalled a full build for 2h). We set ALL Bioc repos to
# P3M paths so install.packages never contacts bioconductor.org.
# UBUNTU_CODENAME must match the base image's Ubuntu release or P3M serves an
# ABI-incompatible CRAN binary — the assertion below fails the build fast if it drifts.
ARG UBUNTU_CODENAME=noble
ARG CRAN_DATE=2026-06-15
ARG BIOC_RELEASE=3.22
ENV P3M=https://packagemanager.posit.co
ENV CRAN_BINARY=${P3M}/cran/__linux__/${UBUNTU_CODENAME}/${CRAN_DATE}
ENV BIOC_SOFT=${P3M}/bioconductor/__linux__/${UBUNTU_CODENAME}/packages/${BIOC_RELEASE}/bioc
ENV BIOC_ANN=${P3M}/bioconductor/packages/${BIOC_RELEASE}/data/annotation
ENV BIOC_EXP=${P3M}/bioconductor/packages/${BIOC_RELEASE}/data/experiment

# Fail fast if the base image's codename != the P3M path we assumed.
RUN . /etc/os-release \
 && echo "base codename=$VERSION_CODENAME ; P3M path codename=${UBUNTU_CODENAME}" \
 && [ "$VERSION_CODENAME" = "${UBUNTU_CODENAME}" ] \
    || { echo "CODENAME MISMATCH — set --build-arg UBUNTU_CODENAME=$VERSION_CODENAME"; exit 1; }

# Make binary P3M repos the global default for CRAN *and* Bioconductor, and
# parallelise the few remaining source/GitHub compiles (e.g. Rhtslib, whirl, presto).
RUN printf "options(repos = c(BioCsoft='%s', BioCann='%s', BioCexp='%s', CRAN='%s'), Ncpus = parallel::detectCores())\n" \
      "${BIOC_SOFT}" "${BIOC_ANN}" "${BIOC_EXP}" "${CRAN_BINARY}" \
      >> /usr/local/lib/R/etc/Rprofile.site \
 && printf "MAKEFLAGS=-j%s\n" "$(nproc)" >> /usr/local/lib/R/etc/Renviron.site

# System deps — same superset as the original base. The lean rocker base ships
# none of these -dev libs, so all are needed for the Bioc/CRAN source builds.
RUN apt-get update && apt-get install -y --no-install-recommends \
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

# Toolchain / installers. No repos= (global P3M now) and no dependencies=TRUE.
RUN R -e "install.packages(c('devtools', 'remotes', 'BiocManager', 'renv'))"

# Rcpp family (superset across all containers)
RUN R -e "install.packages(c('Rcpp', 'RcppArmadillo', 'RcppEigen', 'RcppAnnoy', 'RcppHNSW', \
          'RcppProgress', 'RcppRoll', 'RcppTOML', 'RcppML'))"

RUN R -e "install.packages('Matrix')"

# Data manipulation (superset across all containers)
RUN R -e "install.packages(c('tidyverse', 'dplyr', 'tidyr', 'tibble', 'purrr', 'stringr', \
          'ggplot2', 'readr', 'readxl', 'data.table', 'reshape2', \
          'plyr', 'yaml', 'magrittr'))"

# Visualization (common subset)
RUN R -e "install.packages(c('ggrepel', 'ggridges', 'cowplot', 'patchwork', \
          'scales', 'viridis', 'viridisLite', 'RColorBrewer', 'Cairo'))"

# Dimensionality reduction, clustering, parallelism
RUN R -e "install.packages(c('irlba', 'RSpectra', 'Rtsne', 'uwot', 'FNN', 'RANN', \
          'igraph', 'leiden', 'future', 'future.apply', 'progressr'))"

# HDF5 — install.packages() (not BiocManager::install) so the P3M Bioc repos in
# Rprofile.site are used and bioconductor.org is never contacted.
RUN R -e "install.packages('hdf5r')"
RUN R -e "install.packages(c('rhdf5', 'Rhdf5lib', 'HDF5Array'))"

# Bioconductor core (source via P3M BioCsoft repo — fast under parallel make)
RUN R -e "install.packages(c( \
        'BiocGenerics', 'S4Vectors', 'IRanges', 'GenomeInfoDb', \
        'GenomicRanges', 'Biobase', 'SummarizedExperiment', \
        'SingleCellExperiment', 'DelayedArray', 'DelayedMatrixStats', \
        'BiocNeighbors', 'BiocSingular', 'beachmat', 'ScaledMatrix'))"

# Seurat ecosystem
RUN R -e "install.packages(c('SeuratObject', 'Seurat', 'sctransform'))"

# Smoke test: confirm the heavy binary packages load.
RUN R -e "library(Seurat); library(SingleCellExperiment); library(tidyverse); \
          cat('OK Seurat', as.character(packageVersion('Seurat')), '\n')"

ENV LC_ALL=C
ENV PATH=/usr/local/bin:$PATH
ENV R_LIBS_USER=/usr/local/lib/R/site-library

WORKDIR /workspace
CMD ["R"]
