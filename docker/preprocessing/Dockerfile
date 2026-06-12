# scRNA-seq preprocessing container
# QC, doublet detection, ambient RNA removal, batch correction
# Extends: nnclinssoap/scrnaseq-base:4.5.2

FROM nnclinssoap/scrnaseq-base:4.5.2

LABEL maintainer="zemw@novonordisk.com"
LABEL description="R environment for scRNA-seq preprocessing: Seurat, SoupX, scDblFinder, harmony"
LABEL version="4.5.2"

RUN Rscript -e "BiocManager::install(c('DropletUtils', 'scDblFinder', 'glmGamPoi', 'bluster'), ask=FALSE)"

RUN Rscript -e "BiocManager::install(c('org.Hs.eg.db', 'AnnotationDbi', 'GO.db', 'KEGGREST'), ask=FALSE)"

RUN Rscript -e "install.packages('SoupX', repos='https://cloud.r-project.org/', dependencies=TRUE)"

RUN Rscript -e "BiocManager::install('harmony', ask=FALSE)"

RUN Rscript -e "remotes::install_github('NovoNordisk-OpenSource/whirl', dependencies=TRUE)"

ENV LC_ALL=C
ENV PATH=/usr/local/bin:$PATH
ENV R_LIBS_USER=/usr/local/lib/R/site-library

WORKDIR /workspace
CMD ["R"]
