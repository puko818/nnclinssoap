# Base image for all workflow containers in this project, with R 4.5.2 and Bioconductor 3.22.
# Building the original upstream stack takes substantial time (benchmarked at ~360mins with r6i.4xlarge -> 16vCPU and 128GB RAM):
# Changes were targeted towads improving performance, and compared to the original upstream docker architecture, this one:
    # this base docker unifies everything common across all workflow containers, so the derived workflow-specific dockers are much faster to build
    # CRAN packages are installed from a binary mirror (rocker's existing P3M binary CRAN mirror) rather than from source, which is much faster
    # CRAN packages are pinned specifically at the version in rocker's 4.5.2 snapshot, unlike in the original implementation, where always the latest version was installed, which could lead to unexpected behaviour if a package was updated in the meantime 
    # Bioconductor packages are still installed from source, they are set to use a  single source repo as there were some issues with the mirror when tested 
    # added parallelisation if the packages still needed to be installed from the source (Bioconductor packages)
    # ditched dependencies=TRUE and repos= arguments to install.packages() to make sure that the global repos set in Rprofile.site are used, and to avoid unnecessary installation of dependencies that are already installed in the base image
# Build:  docker build -t nnclinssoap/scrnaseq-base:4.5.2 docker/base

FROM rocker/r-ver:4.5.2

LABEL maintainer="zemw@novonordisk.com"
LABEL description="Base R 4.5.2 / Bioc 3.22 environment with Seurat — binary-package build"
LABEL version="4.5.2"

# bioconductor version
ARG BIOC_RELEASE=3.22
# repo link (this seems more stable thant the Bioconductor mirror, which was sometimes down when tested)
ENV P3M=https://packagemanager.posit.co
# Bioconductor repos (source) for Bioc packages, annotation data, and experiment data
ENV BIOC_SOFT=${P3M}/bioconductor/packages/${BIOC_RELEASE}/bioc
ENV BIOC_ANN=${P3M}/bioconductor/packages/${BIOC_RELEASE}/data/annotation
ENV BIOC_EXP=${P3M}/bioconductor/packages/${BIOC_RELEASE}/data/experiment

# Add Bioconductor repos to Rprofile.site, so that all install.packages() calls use them by default. Also set MAKEFLAGS to use all available cores for parallel builds.
RUN { \
      echo "local({"; \
      echo "  r <- getOption('repos')"; \
      printf "  r <- c(r, '%s', '%s', '%s')\n" "${BIOC_SOFT}" "${BIOC_ANN}" "${BIOC_EXP}"; \
      echo "  options(repos = r)"; \
      echo "})"; \
    } >> /usr/local/lib/R/etc/Rprofile.site \
 && printf "MAKEFLAGS=-j%s\n" "$(nproc)" >> /usr/local/lib/R/etc/Renviron.site

# Install system dependencies
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

# Install devtools, remotes,
# No reason to install BiocManager as it is not used and the Bioconductor repos are set to be used by default in Rprofile.site
# No reason to install renv as it is not used anymore (was used in whirl but not in the current implementation)
RUN Rscript -e "install.packages(c('devtools', 'remotes'))"


# Install essential Rcpp packages first
RUN Rscript -e " \
    cat('Installing Rcpp packages...\\n'); \
    rcpp_packages <- c('Rcpp', 'RcppArmadillo', 'RcppEigen', 'RcppAnnoy', 'RcppHNSW', 'RcppProgress', 'RcppRoll', 'RcppTOML', 'RcppML'); \
    install.packages(rcpp_packages); \
    cat('Rcpp packages installed\\n'); \
    "

# Install Matrix package (required by many downstream packages)
RUN Rscript -e " \
    cat('Installing Matrix package...\\n'); \
    install.packages('Matrix'); \
    cat('Matrix package installed\\n'); \
    "

# Install tidyverse and data manipulation packages
RUN Rscript -e " \
    cat('Installing tidyverse and data packages...\\n'); \
    data_packages <- c( \
        'tidyverse', 'dplyr', 'tidyr', 'tibble', 'purrr', 'stringr', 'ggplot2', 'readr', 'readxl', \
        'data.table', 'reshape2', 'yaml', 'magrittr' \
    ); \
    install.packages(data_packages); \
    cat('Data manipulation packages installed\\n'); \
    "

# Install visualization packages (common subset used across workflows)
RUN Rscript -e " \
    cat('Installing visualization packages...\\n'); \
    viz_packages <- c( \
        'ggrepel', 'ggridges', 'cowplot', 'patchwork', \
          'scales', 'viridis', 'viridisLite', 'RColorBrewer', 'Cairo' \
    ); \
    install.packages(viz_packages); \
    cat('Visualization packages installed\\n'); \
    "

# Install HDF5 and file I/O packages
RUN Rscript -e " \
    cat('Installing HDF5 and file I/O packages...\\n'); \
    install.packages(c('hdf5r', 'rhdf5', 'Rhdf5lib', 'HDF5Array')); \
    cat('HDF5 packages installed\\n'); \
    "


# Install Bioconductor core packages
RUN Rscript -e " \
    cat('Installing Bioconductor core packages...\\n'); \
    install.packages(c( \
        'BiocGenerics', 'S4Vectors', 'IRanges', 'GenomeInfoDb', \
        'GenomicRanges', 'GenomicFeatures', 'GenomicAlignments', \
        'Biobase', 'SummarizedExperiment', 'SingleCellExperiment', \
        'DelayedArray', 'DelayedMatrixStats', 'BiocNeighbors', \
        'BiocSingular', 'beachmat', 'ScaledMatrix', 'BiocFileCache', \
        'AnnotationHub', 'ExperimentHub' \
    )); \
    cat('Bioconductor core packages installed\\n'); \
    "
    
# Install analysis packages for dimensionality reduction and clustering
RUN Rscript -e " \
    cat('Installing analysis packages...\\n'); \
    analysis_packages <- c( \
        'irlba', 'RSpectra', 'Rtsne', 'uwot', 'FNN', 'RANN', \
        'igraph', 'leiden', 'future', 'future.apply', 'progressr', \
        'parallel' \
    ); \
    install.packages(analysis_packages); \
    cat('Analysis packages installed\\n'); \
    "

# Install Seurat and SeuratObject
RUN Rscript -e " \
    cat('Installing Seurat ecosystem...\\n'); \
    install.packages(c('SeuratObject', 'Seurat', 'sctransform')); \
    cat('Seurat installed successfully\\n'); \
    "


# Smoke test - check some of the heavy packages load properly and print their versions.
RUN R -e "library(Seurat); library(SingleCellExperiment); library(tidyverse); \
          cat('OK — Seurat', as.character(packageVersion('Seurat')), \
              '| SingleCellExperiment', as.character(packageVersion('SingleCellExperiment')), \
              '| tidyverse', as.character(packageVersion('tidyverse')), '\n')"

ENV LC_ALL=C
ENV PATH=/usr/local/bin:$PATH
ENV R_LIBS_USER=/usr/local/lib/R/site-library

WORKDIR /workspace
CMD ["R"]
