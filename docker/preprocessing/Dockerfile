# Docker image for scRNA-seq preprocessing workflow
# Image name: scrnaseq-seurat-soupx-harmony:4.5.2
# Main tools: Seurat 5.1, SoupX 1.6.2, scDblFinder 1.22, harmony 1.2.2, DropletUtils 1.28
# Maintainer: zemw <zemw@novonordisk.com>

FROM rocker/r-ver:4.5.2

# Add container labels
LABEL maintainer="zemw@novonordisk.com"
LABEL description="R environment for scRNA-seq preprocessing workflow with Seurat, SoupX, scDblFinder, and harmony"

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
    && rm -rf /var/lib/apt/lists/*

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
    rcpp_packages <- c('Rcpp', 'RcppArmadillo', 'RcppEigen', 'RcppAnnoy', 'RcppProgress', 'RcppTOML', 'RcppML'); \
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
        'tidyverse', 'dplyr', 'tidyr', 'tibble', 'purrr', 'stringr', 'ggplot2', 'readr', \
        'data.table', 'reshape2', 'yaml', 'magrittr' \
    ); \
    install.packages(data_packages, repos='https://cloud.r-project.org/', dependencies=TRUE); \
    cat('Data manipulation packages installed\\n'); \
    "

# Install visualization packages
RUN Rscript -e " \
    cat('Installing visualization packages...\\n'); \
    viz_packages <- c( \
        'ggrepel', 'ggridges', 'cowplot', 'patchwork', \
        'scales', 'viridis', 'viridisLite', 'RColorBrewer', 'Cairo' \
    ); \
    install.packages(viz_packages, repos='https://cloud.r-project.org/', dependencies=TRUE); \
    cat('Visualization packages installed\\n'); \
    "

# Install hdf5r from CRAN
RUN Rscript -e " \
    cat('Installing hdf5r...\\n'); \
    install.packages('hdf5r', repos='https://cloud.r-project.org/', dependencies=TRUE); \
    cat('hdf5r installed\\n'); \
    "

# Install HDF5 Bioconductor packages
RUN Rscript -e " \
    cat('Installing HDF5 Bioconductor packages...\\n'); \
    BiocManager::install(c('rhdf5', 'Rhdf5lib', 'HDF5Array'), ask=FALSE); \
    cat('HDF5 Bioconductor packages installed\\n'); \
    "

# Install Bioconductor core packages
RUN Rscript -e " \
    cat('Installing Bioconductor core packages...\\n'); \
    BiocManager::install(c( \
        'BiocGenerics', 'S4Vectors', 'IRanges', 'GenomeInfoDb', \
        'GenomicRanges', 'Biobase', 'SummarizedExperiment', \
        'SingleCellExperiment', 'DelayedArray', 'DelayedMatrixStats', \
        'BiocNeighbors', 'BiocSingular', 'beachmat', 'ScaledMatrix' \
    ), ask=FALSE); \
    cat('Bioconductor core packages installed\\n'); \
    "

# Install annotation packages
RUN Rscript -e " \
    cat('Installing annotation packages...\\n'); \
    BiocManager::install(c( \
        'org.Hs.eg.db', 'AnnotationDbi', 'GO.db', 'KEGGREST' \
    ), ask=FALSE); \
    cat('Annotation packages installed\\n'); \
    "

# Install analysis packages for dimensionality reduction and clustering
RUN Rscript -e " \
    cat('Installing analysis packages...\\n'); \
    analysis_packages <- c( \
        'irlba', 'RSpectra', 'Rtsne', 'uwot', 'FNN', 'RANN', \
        'igraph', 'leiden', 'future', 'future.apply', 'progressr' \
    ); \
    install.packages(analysis_packages, repos='https://cloud.r-project.org/', dependencies=TRUE); \
    cat('Analysis packages installed\\n'); \
    "

# Install Seurat and SeuratObject
RUN Rscript -e " \
    cat('Installing Seurat and SeuratObject...\\n'); \
    install.packages(c('SeuratObject', 'Seurat', 'sctransform'), repos='https://cloud.r-project.org/', dependencies=TRUE); \
    cat('Seurat installed successfully\\n'); \
    "

# Install preprocessing-specific Bioconductor packages
RUN Rscript -e " \
    cat('Installing preprocessing packages...\\n'); \
    BiocManager::install(c( \
        'DropletUtils', 'scDblFinder', 'glmGamPoi', 'bluster' \
    ), ask=FALSE); \
    cat('Preprocessing packages installed\\n'); \
    "

# Install SoupX from CRAN
RUN Rscript -e " \
    cat('Installing SoupX...\\n'); \
    install.packages('SoupX', repos='https://cloud.r-project.org/', dependencies=TRUE); \
    cat('SoupX installed\\n'); \
    "

# Install harmony from Bioconductor
RUN Rscript -e " \
    cat('Installing harmony...\\n'); \
    BiocManager::install('harmony', ask=FALSE); \
    cat('harmony installed\\n'); \
    "

# Install whirl for preprocessing workflows
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
