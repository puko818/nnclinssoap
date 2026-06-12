# Spatial Xenium analysis container
# Spatial transcriptomics analysis for 10x Genomics Xenium platform
# Extends: nnclinssoap/scrnaseq-base:4.5.2

FROM nnclinssoap/scrnaseq-base:4.5.2

LABEL maintainer="zemw@novonordisk.com"
LABEL description="R environment for spatial transcriptomics: presto, argparser, arrow, spatstat"
LABEL version="4.5.2"

RUN Rscript -e " \
    install.packages( \
        c('ggExtra', 'plotly', 'shiny', 'shinyjs'), \
        repos='https://cloud.r-project.org/', dependencies=TRUE); \
    "

RUN Rscript -e " \
    install.packages( \
        c('sp', 'spatstat.data', 'spatstat.geom', 'spatstat.explore', \
          'spatstat.random', 'spatstat.sparse', 'spatstat.univar', 'spatstat.utils', \
          'deldir', 'polyclip'), \
        repos='https://cloud.r-project.org/', dependencies=TRUE); \
    "

RUN Rscript -e " \
    install.packages( \
        c('argparser', 'fitdistrplus', 'ROCR', 'pbapply', 'scattermore', 'fastDummies'), \
        repos='https://cloud.r-project.org/', dependencies=TRUE); \
    "

RUN Rscript -e " \
    Sys.setenv('LIBARROW_MINIMAL'=FALSE); \
    install.packages('arrow', repos='https://cloud.r-project.org/', dependencies=TRUE); \
    "

RUN Rscript -e "devtools::install_github('immunogenomics/presto', ref='1.0.0', upgrade='never')"

ENV LC_ALL=C
ENV PATH=/usr/local/bin:$PATH
ENV R_LIBS_USER=/usr/local/lib/R/site-library

WORKDIR /workspace
CMD ["R"]
