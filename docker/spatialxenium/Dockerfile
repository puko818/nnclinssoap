# Docker image for R with presto (from GitHub), Seurat, argparser, arrow, and ggExtra
# Maintainer: zemw <zemw@novonordisk.com>

FROM rocker/r-ver:4.5.2

# Add container labels
LABEL maintainer="zemw@novonordisk.com"

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
    pkg-config \
    cmake \
    git \
    wget \
    build-essential \
    libnode-dev \
    && rm -rf /var/lib/apt/lists/*

# Install devtools and remotes first (needed for GitHub installations)
RUN R -e "install.packages(c('devtools', 'remotes', 'BiocManager'), repos='https://cloud.r-project.org/', dependencies=TRUE)"

# Install essential Rcpp packages first (dependencies for many other packages)
RUN Rscript -e " \
    cat('Installing Rcpp packages...\\n'); \
    rcpp_packages <- c('Rcpp', 'RcppArmadillo', 'RcppEigen', 'RcppAnnoy', 'RcppHNSW', 'RcppProgress', 'RcppTOML'); \
    install.packages(rcpp_packages, repos='https://cloud.r-project.org/', dependencies=TRUE, quiet=TRUE); \
    cat('Rcpp packages installed\\n'); \
    "

# Install Matrix package first (required by many downstream packages)
RUN Rscript -e " \
    cat('Installing Matrix package...\\n'); \
    install.packages('Matrix', repos='https://cloud.r-project.org/', dependencies=TRUE); \
    cat('Matrix package installed\\n'); \
    "

# Install tidyverse and data manipulation packages
RUN Rscript -e " \
    cat('Installing tidyverse and data packages...\\n'); \
    data_packages <- c( \
        'dplyr', 'tidyr', 'tibble', 'purrr', 'stringr', 'ggplot2', \
        'data.table', 'reshape2', 'plyr' \
    ); \
    install.packages(data_packages, repos='https://cloud.r-project.org/', dependencies=TRUE); \
    cat('Data manipulation packages installed\\n'); \
    "

# Install visualization packages
RUN Rscript -e " \
    cat('Installing visualization packages...\\n'); \
    viz_packages <- c( \
        'ggExtra', 'ggrepel', 'ggridges', 'cowplot', 'patchwork', \
        'scales', 'viridisLite', 'RColorBrewer', 'plotly', \
        'shiny', 'shinyjs' \
    ); \
    install.packages(viz_packages, repos='https://cloud.r-project.org/', dependencies=TRUE); \
    cat('Visualization packages installed\\n'); \
    "

# Install spatial analysis packages
RUN Rscript -e " \
    cat('Installing spatial analysis packages...\\n'); \
    spatial_packages <- c( \
        'sp', 'spatstat.data', 'spatstat.geom', 'spatstat.explore', \
        'spatstat.random', 'spatstat.sparse', 'spatstat.univar', 'spatstat.utils', \
        'deldir', 'polyclip' \
    ); \
    install.packages(spatial_packages, repos='https://cloud.r-project.org/', dependencies=TRUE); \
    cat('Spatial analysis packages installed\\n'); \
    "

# Install analysis and machine learning packages
RUN Rscript -e " \
    cat('Installing analysis packages...\\n'); \
    analysis_packages <- c( \
        'argparser', 'arrow', 'fitdistrplus', 'ROCR', \
        'future', 'future.apply', 'progressr', 'pbapply', \
        'irlba', 'RSpectra', 'Rtsne', 'uwot', 'FNN', 'RANN', \
        'igraph', 'leiden', 'scattermore', 'fastDummies' \
    ); \
    Sys.setenv('LIBARROW_MINIMAL' = FALSE); \
    install.packages(analysis_packages, repos='https://cloud.r-project.org/', dependencies=TRUE); \
    cat('Analysis packages installed\\n'); \
    "

# Install Seurat and dependencies
RUN Rscript -e " \
    cat('Installing Seurat and related packages...\\n'); \
    seurat_packages <- c( \
        'SeuratObject', 'Seurat', 'sctransform', 'ica' \
    ); \
    install.packages(seurat_packages, repos='https://cloud.r-project.org/', dependencies=TRUE); \
    cat('Seurat installed successfully\\n'); \
    "

# Install presto from GitHub
RUN Rscript -e " \
    cat('Installing presto from GitHub (immunogenomics/presto)...\\n'); \
    devtools::install_github('immunogenomics/presto', ref='1.0.0', upgrade='never'); \
    cat('Presto installed successfully\\n'); \
    "

# Set environment variables
ENV LC_ALL=C
ENV PATH=/usr/local/bin:$PATH
ENV R_LIBS_USER=/usr/local/lib/R/site-library

# Set working directory
WORKDIR /workspace

# Default command
CMD ["R"]
