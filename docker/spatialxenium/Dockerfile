# Spatial Xenium container — binary-package build
# Spatial transcriptomics analysis for 10x Genomics Xenium platform
# Extends the binary base, which sets P3M CRAN+Bioc repos globally in Rprofile.site.
# install.packages now pulls binaries from P3M (notably 'arrow', whose source build
# of libarrow is otherwise very slow).

FROM nnclinssoap/scrnaseq-base:4.5.2

LABEL maintainer="zemw@novonordisk.com"
LABEL description="R environment for spatial transcriptomics: presto, argparser, arrow, spatstat"
LABEL version="4.5.2"

RUN R -e "install.packages(c('ggExtra', 'plotly', 'shiny', 'shinyjs'))"

RUN R -e "install.packages(c('sp', 'spatstat.data', 'spatstat.geom', 'spatstat.explore', \
          'spatstat.random', 'spatstat.sparse', 'spatstat.univar', 'spatstat.utils', \
          'deldir', 'polyclip'))"

RUN R -e "install.packages(c('argparser', 'fitdistrplus', 'ROCR', 'pbapply', 'scattermore', 'fastDummies'))"

# LIBARROW_MINIMAL only matters if P3M falls back to a source build; with the P3M
# binary it is ignored (binary arrow ships full libarrow).
RUN R -e " \
    Sys.setenv('LIBARROW_MINIMAL'=FALSE); \
    install.packages('arrow'); \
    "

# presto 1.0.0 declares CXX_STD=CXX11, but the (newer) binary RcppArmadillo 15.x
# requires C++14+. Raise the C++11-package standard to gnu++17 so presto compiles
# against modern Armadillo. The trailing guard makes the build FAIL LOUDLY if presto
# is missing — install.packages/install_github only warn on compile failure, so
# without this a broken (presto-less) image would silently ship.
RUN printf "CXX11STD = -std=gnu++17\n" >> /usr/local/lib/R/etc/Makevars.site \
 && R -e "devtools::install_github('immunogenomics/presto', ref='1.0.0', upgrade='never'); \
          if (!requireNamespace('presto', quietly=TRUE)) stop('presto failed to install')"

ENV LC_ALL=C
ENV PATH=/usr/local/bin:$PATH
ENV R_LIBS_USER=/usr/local/lib/R/site-library

WORKDIR /workspace
CMD ["R"]
