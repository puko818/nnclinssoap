# Docker image for scRNA-seq analysis workflow
# Inherits from the base image, which sets P3M CRAN+Bioc repos globally in Rprofile.site.
# Image name: scrnaseq-azimuth-singler-edger:4.5.2
# Main tools: Azimuth (GitHub), SingleR 2.10, edgeR 4.6.2, Signac 1.15, Seurat 5.1


FROM nnclinssoap/scrnaseq-base:4.5.2

LABEL maintainer="zemw@novonordisk.com"
LABEL description="R environment for scRNA-seq analysis: Azimuth, SingleR, edgeR, Signac"
LABEL version="4.5.2"

# Install additional visualisation packages specific to scRNA-seq analysis
RUN Rscript -e " \
    cat('Installing additional visualisation packages...\\n'); \
    install.packages(c('ggpubr', 'ggthemes', 'pheatmap', 'DT')); \ 
    cat('Additional visualisation packages installed\\n'); \
    "

# Install additional Bioconductor packages specific to scRNA-seq analysis
RUN Rscript -e " \
    cat('Installing additional Bioconductor packages...\\n'); \
    install.packages(c( \
        'GenomicFeatures', 'GenomicAlignments', 'BiocFileCache', \
        'AnnotationHub', 'ExperimentHub' \
    )); \
    cat('Additional Bioconductor packages installed\\n'); \
    "


# Install annotation and genome packages
RUN Rscript -e " \
    cat('Installing annotation packages...\\n'); \
    install.packages(c( \
        'org.Hs.eg.db', 'AnnotationDbi', 'AnnotationFilter', 'GO.db', 'KEGGREST', \
        'BSgenome', 'BSgenome.Hsapiens.UCSC.hg38', \
        'EnsDb.Hsapiens.v86', 'JASPAR2020' \
    )); \
    cat('Annotation packages installed\\n'); \
    "

# Install analysis-specific Bioconductor packages
RUN Rscript -e " \
    cat('Installing analysis-specific Bioconductor packages...\\n'); \
    install.packages(c('DropletUtils', 'glmGamPoi', 'bluster', 'DirichletMultinomial')); \
    cat('Analysis-specific Bioconductor packages installed\\n'); \
    "

# TFMPvalue from archive (required by TFBSTools -> Azimuth)
RUN Rscript -e " \
    options(timeout=600); \
    install.packages( \
        'https://cran.r-project.org/src/contrib/Archive/TFMPvalue/TFMPvalue_0.0.9.tar.gz', \
        repos=NULL, type='source'); \
    "

RUN Rscript -e " \
    cat('Installing TFBSTools...\\n'); \
    install.packages('TFBSTools'); \
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

# Download, install pbmcref reference dataset and clean up
RUN wget -q https://seurat.nygenome.org/src/contrib/pbmcref.SeuratData_1.0.0.tar.gz && \
    Rscript -e "install.packages('pbmcref.SeuratData_1.0.0.tar.gz', repos=NULL, type='source')" && \
    rm pbmcref.SeuratData_1.0.0.tar.gz


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
    install.packages(c('SingleR', 'celldex')); \
    cat('SingleR and celldex installed\\n'); \
    "
# Install Signac for multimodal analysis
RUN Rscript -e " \
    cat('Installing Signac...\\n'); \
    install.packages('Signac'); \
    cat('Signac installed\\n'); \
    "

# Install differential expression packages
RUN Rscript -e " \
    cat('Installing edgeR, limma, and DESeq2...\\n'); \
    install.packages(c('edgeR', 'limma', 'DESeq2')); \
    cat('edgeR, limma, and DESeq2 installed\\n'); \
    "

RUN Rscript -e " \
    cat('Installing SoupX...\\n'); \
    install.packages('SoupX'); \
    cat('SoupX installed\\n'); \
    "

ENV LC_ALL=C
ENV PATH=/usr/local/bin:$PATH
ENV R_LIBS_USER=/usr/local/lib/R/site-library

# Set working directory
WORKDIR /workspace

# Default command
CMD ["R"]
