# scRNA-seq preprocessing container — binary-package build
# QC, doublet detection, ambient RNA removal, batch correction
# Extends the binary base, which sets P3M CRAN+Bioc repos globally in Rprofile.site.
# All installs use install.packages (NOT BiocManager::install) so they go through the
# inherited P3M repos and never contact bioconductor.org (which hangs on a 302 redirect).

FROM nnclinssoap/scrnaseq-base:4.5.2

LABEL maintainer="zemw@novonordisk.com"
LABEL description="R environment for scRNA-seq preprocessing: Seurat, SoupX, scDblFinder, harmony"
LABEL version="4.5.2"

RUN R -e "install.packages(c('DropletUtils', 'scDblFinder', 'glmGamPoi', 'bluster'))"

RUN R -e "install.packages(c('org.Hs.eg.db', 'AnnotationDbi', 'GO.db', 'KEGGREST'))"

RUN R -e "install.packages('SoupX')"

RUN R -e "install.packages('harmony')"

RUN R -e "remotes::install_github('NovoNordisk-OpenSource/whirl')"

ENV LC_ALL=C
ENV PATH=/usr/local/bin:$PATH
ENV R_LIBS_USER=/usr/local/lib/R/site-library

WORKDIR /workspace
CMD ["R"]
