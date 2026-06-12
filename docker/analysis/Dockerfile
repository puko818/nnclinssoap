# scRNA-seq analysis container
# Cell type annotation and differential expression
# Extends: nnclinssoap/scrnaseq-base:4.5.2

FROM nnclinssoap/scrnaseq-base:4.5.2

LABEL maintainer="zemw@novonordisk.com"
LABEL description="R environment for scRNA-seq analysis: Azimuth, SingleR, edgeR, Signac"
LABEL version="4.5.2"

RUN Rscript -e " \
    install.packages( \
        c('ggpubr', 'ggthemes', 'pheatmap', 'DT'), \
        repos='https://cloud.r-project.org/', dependencies=TRUE); \
    "

RUN Rscript -e " \
    BiocManager::install(c( \
        'GenomicFeatures', 'GenomicAlignments', 'BiocFileCache', \
        'AnnotationHub', 'ExperimentHub' \
    ), ask=FALSE); \
    "

RUN Rscript -e " \
    BiocManager::install(c( \
        'org.Hs.eg.db', 'AnnotationDbi', 'AnnotationFilter', 'GO.db', 'KEGGREST', \
        'BSgenome', 'BSgenome.Hsapiens.UCSC.hg38', 'EnsDb.Hsapiens.v86', 'JASPAR2020' \
    ), ask=FALSE); \
    "

RUN Rscript -e " \
    BiocManager::install(c('DropletUtils', 'glmGamPoi', 'bluster', 'DirichletMultinomial'), ask=FALSE); \
    "

# TFMPvalue from archive (required by TFBSTools -> Azimuth)
RUN Rscript -e " \
    options(timeout=600); \
    install.packages( \
        'https://cran.r-project.org/src/contrib/Archive/TFMPvalue/TFMPvalue_0.0.9.tar.gz', \
        repos=NULL, type='source'); \
    "

RUN Rscript -e "BiocManager::install('TFBSTools', ask=FALSE)"

RUN Rscript -e " \
    remotes::install_github('satijalab/azimuth', ref='master', dependencies=TRUE, upgrade='never'); \
    "

# Download, install, and clean up pbmcref in a single layer to avoid bloating image
RUN wget -q https://seurat.nygenome.org/src/contrib/pbmcref.SeuratData_1.0.0.tar.gz && \
    Rscript -e "install.packages('pbmcref.SeuratData_1.0.0.tar.gz', repos=NULL, type='source')" && \
    rm pbmcref.SeuratData_1.0.0.tar.gz

RUN Rscript -e "BiocManager::install(c('SingleR', 'celldex'), ask=FALSE)"

RUN Rscript -e "install.packages('Signac', repos='https://cloud.r-project.org/', dependencies=TRUE)"

RUN Rscript -e "BiocManager::install(c('edgeR', 'limma', 'DESeq2'), ask=FALSE)"

RUN Rscript -e "install.packages('SoupX', repos='https://cloud.r-project.org/', dependencies=TRUE)"

RUN Rscript -e "remotes::install_github('NovoNordisk-OpenSource/whirl', dependencies=TRUE)"

ENV LC_ALL=C
ENV PATH=/usr/local/bin:$PATH
ENV R_LIBS_USER=/usr/local/lib/R/site-library

WORKDIR /workspace
CMD ["R"]
