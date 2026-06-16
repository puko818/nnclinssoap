# scRNA-seq analysis container — binary-package build
# Cell type annotation and differential expression
# Extends the binary base, which sets P3M CRAN+Bioc repos globally in Rprofile.site.
# All installs use install.packages (NOT BiocManager::install) so they go through the
# inherited P3M repos and never contact bioconductor.org (which hangs on a 302 redirect).

FROM nnclinssoap/scrnaseq-base:4.5.2

LABEL maintainer="zemw@novonordisk.com"
LABEL description="R environment for scRNA-seq analysis: Azimuth, SingleR, edgeR, Signac"
LABEL version="4.5.2"

RUN R -e "install.packages(c('ggpubr', 'ggthemes', 'pheatmap', 'DT'))"

RUN R -e "install.packages(c( \
        'GenomicFeatures', 'GenomicAlignments', 'BiocFileCache', \
        'AnnotationHub', 'ExperimentHub'))"

RUN R -e "install.packages(c( \
        'org.Hs.eg.db', 'AnnotationDbi', 'AnnotationFilter', 'GO.db', 'KEGGREST', \
        'BSgenome', 'BSgenome.Hsapiens.UCSC.hg38', 'EnsDb.Hsapiens.v86', 'JASPAR2020'))"

RUN R -e "install.packages(c('DropletUtils', 'glmGamPoi', 'bluster', 'DirichletMultinomial'))"

# TFMPvalue from archive (required by TFBSTools -> Azimuth)
RUN R -e " \
    options(timeout=600); \
    install.packages( \
        'https://cran.r-project.org/src/contrib/Archive/TFMPvalue/TFMPvalue_0.0.9.tar.gz', \
        repos=NULL, type='source'); \
    "

RUN R -e "install.packages('TFBSTools')"

RUN R -e " \
    remotes::install_github('satijalab/azimuth', ref='master', upgrade='never'); \
    "

# Download, install, and clean up pbmcref in a single layer to avoid bloating image
RUN wget -q https://seurat.nygenome.org/src/contrib/pbmcref.SeuratData_1.0.0.tar.gz && \
    R -e "install.packages('pbmcref.SeuratData_1.0.0.tar.gz', repos=NULL, type='source')" && \
    rm pbmcref.SeuratData_1.0.0.tar.gz

RUN R -e "install.packages(c('SingleR', 'celldex'))"

RUN R -e "install.packages('Signac')"

RUN R -e "install.packages(c('edgeR', 'limma', 'DESeq2'))"

RUN R -e "install.packages('SoupX')"

RUN R -e "remotes::install_github('NovoNordisk-OpenSource/whirl')"

ENV LC_ALL=C
ENV PATH=/usr/local/bin:$PATH
ENV R_LIBS_USER=/usr/local/lib/R/site-library

WORKDIR /workspace
CMD ["R"]
