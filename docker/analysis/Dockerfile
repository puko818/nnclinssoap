# Docker image for scRNA-seq analysis workflow
# Image name: scrnaseq-azimuth-singler-edger:4.5.2
# Main tools: Azimuth (GitHub), SingleR 2.10, edgeR 4.6.2, Signac 1.15, Seurat 5.1
# Maintainer: zemw <zemw@novonordisk.com>

FROM rocker/r-ver:4.5.2

# Add container labels
LABEL maintainer="zemw@novonordisk.com"
LABEL description="R environment for scRNA-seq analysis workflow with Azimuth, SingleR, Signac, and differential expression"

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
    zlib1g-dev \
    libglpk-dev \
    && rm -rf /var/lib/apt/lists/*

RUN wget http://seurat.nygenome.org/src/contrib/pbmcref.SeuratData_1.0.0.tar.gz

# Install Quarto
RUN ARCH=$(dpkg --print-architecture) && \
    wget https://github.com/quarto-dev/quarto-cli/releases/download/v1.5.57/quarto-1.5.57-linux-${ARCH}.deb && \
    dpkg -i quarto-1.5.57-linux-${ARCH}.deb || true && \
    apt-get update && apt-get install -f -y && \
    rm quarto-1.5.57-linux-${ARCH}.deb && \
    rm -rf /var/lib/apt/lists/* && \
    quarto check install
    
# Install devtools, remotes, and BiocManager first
RUN R -e "install.packages(c('devtools', 'remotes', 'BiocManager', 'renv'), repos='https://cloud.r-project.org/', dependencies=TRUE)"

# Set Bioconductor version
RUN R -e "BiocManager::install(version='3.22', ask=FALSE)"

# Install essential Rcpp packages first
RUN Rscript -e " \
    cat('Installing Rcpp packages...\\n'); \
    rcpp_packages <- c('Rcpp', 'RcppArmadillo', 'RcppEigen', 'RcppAnnoy', 'RcppHNSW', 'RcppProgress', 'RcppRoll', 'RcppTOML', 'RcppML'); \
    install.packages(rcpp_packages, repos='https://cloud.r-project.org/', dependencies=TRUE); \
    cat('Rcpp packages installed\\n'); \
    "

# Install Matrix package (required by many downstream packages)
RUN Rscript -e " \
    cat('Installing Matrix package...\\n'); \
    install.packages('Matrix', repos='https://cloud.r-project.org/', dependencies=TRUE); \
    cat('Matrix package installed\\n'); \
    "

# Install tidyverse and data manipulation packages
RUN Rscript -e " \
    cat('Installing tidyverse and data packages...\\n'); \
    data_packages <- c( \
        'tidyverse', 'dplyr', 'tidyr', 'tibble', 'purrr', 'stringr', 'ggplot2', 'readr', 'readxl', \
        'data.table', 'reshape2', 'yaml', 'magrittr' \
    ); \
    install.packages(data_packages, repos='https://cloud.r-project.org/', dependencies=TRUE); \
    cat('Data manipulation packages installed\\n'); \
    "

# Install visualization packages
RUN Rscript -e " \
    cat('Installing visualization packages...\\n'); \
    viz_packages <- c( \
        'ggrepel', 'ggridges', 'ggpubr', 'ggthemes', 'cowplot', 'patchwork', \
        'scales', 'viridis', 'viridisLite', 'RColorBrewer', 'Cairo', \
        'pheatmap', 'DT' \
    ); \
    install.packages(viz_packages, repos='https://cloud.r-project.org/', dependencies=TRUE); \
    cat('Visualization packages installed\\n'); \
    "

# Install HDF5 and file I/O packages
RUN Rscript -e " \
    cat('Installing HDF5 and file I/O packages...\\n'); \
    BiocManager::install(c('hdf5r', 'rhdf5', 'Rhdf5lib', 'HDF5Array'), ask=FALSE); \
    cat('HDF5 packages installed\\n'); \
    "

# Install Bioconductor core packages
RUN Rscript -e " \
    cat('Installing Bioconductor core packages...\\n'); \
    BiocManager::install(c( \
        'BiocGenerics', 'S4Vectors', 'IRanges', 'GenomeInfoDb', \
        'GenomicRanges', 'GenomicFeatures', 'GenomicAlignments', \
        'Biobase', 'SummarizedExperiment', 'SingleCellExperiment', \
        'DelayedArray', 'DelayedMatrixStats', 'BiocNeighbors', \
        'BiocSingular', 'beachmat', 'ScaledMatrix', 'BiocFileCache', \
        'AnnotationHub', 'ExperimentHub' \
    ), ask=FALSE); \
    cat('Bioconductor core packages installed\\n'); \
    "

# Install annotation and genome packages
RUN Rscript -e " \
    cat('Installing annotation packages...\\n'); \
    BiocManager::install(c( \
        'org.Hs.eg.db', 'AnnotationDbi', 'AnnotationFilter', 'GO.db', 'KEGGREST', \
        'BSgenome', 'BSgenome.Hsapiens.UCSC.hg38', \
        'EnsDb.Hsapiens.v86', 'JASPAR2020' \
    ), ask=FALSE); \
    cat('Annotation packages installed\\n'); \
    "

# Install analysis packages for dimensionality reduction and clustering
RUN Rscript -e " \
    cat('Installing analysis packages...\\n'); \
    analysis_packages <- c( \
        'irlba', 'RSpectra', 'Rtsne', 'uwot', 'FNN', 'RANN', \
        'igraph', 'leiden', 'future', 'future.apply', 'progressr', \
        'parallel' \
    ); \
    install.packages(analysis_packages, repos='https://cloud.r-project.org/', dependencies=TRUE); \
    cat('Analysis packages installed\\n'); \
    "

# Install Seurat and SeuratObject
RUN Rscript -e " \
    cat('Installing Seurat ecosystem...\\n'); \
    install.packages(c('SeuratObject', 'Seurat', 'sctransform'), repos='https://cloud.r-project.org/', dependencies=TRUE); \
    cat('Seurat installed successfully\\n'); \
    "

# Install TFMPvalue from archive (required for TFBSTools -> Azimuth)
RUN Rscript -e " \
    cat('Installing TFMPvalue from CRAN archive...\\n'); \
    options(timeout = 600); \
    install.packages('https://cran.r-project.org/src/contrib/Archive/TFMPvalue/TFMPvalue_0.0.9.tar.gz', repos = NULL, type = 'source'); \
    cat('TFMPvalue installed\\n'); \
    "
# Install TFBSTools (dependency for Azimuth)
RUN Rscript -e " \
    cat('Installing TFBSTools...\\n'); \
    BiocManager::install('TFBSTools', ask=FALSE); \
    cat('TFBSTools installed\\n'); \
    "

# Install Azimuth with proper error handling
RUN Rscript -e " \
    cat('Installing Azimuth from GitHub...\\n'); \
    remotes::install_github('satijalab/azimuth', ref='master', dependencies = TRUE, upgrade = 'never'); \
    if (!require('Azimuth', quietly = TRUE)) { \
        stop('Azimuth installation failed - package not loadable'); \
    }; \
    cat('Azimuth installed and verified successfully\\n'); \
    "

# Install pbmcref reference dataset from downloaded tar.gz
RUN Rscript -e " \
    cat('Installing pbmcref.SeuratData package from local tar.gz...\\n'); \
    install.packages('pbmcref.SeuratData_1.0.0.tar.gz', repos = NULL, type = 'source'); \
    cat('pbmcref.SeuratData package installed\\n'); \
    "

# Verify pbmcref installation
RUN Rscript -e " \
    cat('Verifying pbmcref dataset installation...\\n'); \
    library(SeuratData); \
    installed <- InstalledData(); \
    print(installed); \
    if ('pbmcref' %in% installed\$Dataset) { \
        cat('\\n✓ pbmcref successfully installed and available for use\\n'); \
    } else { \
        cat('\\n✗ WARNING: pbmcref not found in InstalledData()\\n'); \
        stop('pbmcref installation verification failed'); \
    }; \
    "

# Install SingleR and celldex
RUN Rscript -e " \
    cat('Installing SingleR and celldex...\\n'); \
    BiocManager::install(c('SingleR', 'celldex'), ask=FALSE); \
    cat('SingleR and celldex installed\\n'); \
    "

# Install Signac for multimodal analysis
RUN Rscript -e " \
    cat('Installing Signac...\\n'); \
    install.packages('Signac', repos='https://cloud.r-project.org/', dependencies=TRUE); \
    cat('Signac installed\\n'); \
    "

# Install differential expression packages
RUN Rscript -e " \
    cat('Installing differential expression packages...\\n'); \
    BiocManager::install(c('edgeR', 'limma', 'DESeq2'), ask=FALSE); \
    cat('Differential expression packages installed\\n'); \
    "

# Install analysis-specific Bioconductor packages
RUN Rscript -e " \
    cat('Installing additional analysis packages...\\n'); \
    BiocManager::install(c( \
        'DropletUtils', 'glmGamPoi', 'bluster', \
        'DirichletMultinomial' \
    ), ask=FALSE); \
    cat('Additional analysis packages installed\\n'); \
    "

# Install SoupX
RUN Rscript -e " \
    cat('Installing SoupX...\\n'); \
    install.packages('SoupX', repos='https://cloud.r-project.org/', dependencies=TRUE); \
    cat('SoupX installed\\n'); \
    "

# Install whirl for analysis workflows
RUN Rscript -e " \
    cat('Installing whirl...\\n'); \
    remotes::install_github('NovoNordisk-OpenSource/whirl', dependencies = TRUE); \
    cat('whirl installed\\n'); \
    "

# Set environment variables
ENV LC_ALL=C
ENV PATH=/usr/local/bin:$PATH
ENV R_LIBS_USER=/usr/local/lib/R/site-library

# Set working directory
WORKDIR /workspace

# Default command
CMD ["R"]
