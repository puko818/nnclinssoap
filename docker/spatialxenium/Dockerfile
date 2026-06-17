# Spatial Xenium container — binary-package build
# Spatial transcriptomics analysis for 10x Genomics Xenium platform
# Extends the binary base, which sets P3M CRAN+Bioc repos globally in Rprofile.site.
# install.packages now pulls binaries from P3M (notably 'arrow', whose source build
# of libarrow is otherwise very slow).

FROM nnclinssoap/scrnaseq-base:4.5.2

LABEL maintainer="zemw@novonordisk.com"
LABEL description="R environment for spatial transcriptomics: presto, argparser, arrow, spatstat"
LABEL version="4.5.2"

# Instal additional visualisation packages specific to this workflow
RUN Rscript -e " \
    cat('Installing additional visualisation packages...\\n'); \
    install.packages(c('ggExtra', 'plotly', 'shiny', 'shinyjs')); \
    cat('Additional visualisation packages installed\\n'); \
    "

# Install spatial analysis packages
RUN Rscript -e " \
    cat('Installing spatial analysis packages...\\n'); \
    spatial_packages <- c( \
        'sp', 'spatstat.data', 'spatstat.geom', 'spatstat.explore', \
        'spatstat.random', 'spatstat.sparse', 'spatstat.univar', 'spatstat.utils', \
        'deldir', 'polyclip' \
    ); \
    install.packages(spatial_packages); \
    cat('Spatial analysis packages installed\\n'); \
    "

# Install analysis and machine learning packages
RUN Rscript -e " \
    cat('Installing analysis and machine learning packages...\\n'); \
    install.packages(c('argparser', 'fitdistrplus', 'ROCR', 'pbapply', 'scattermore', 'fastDummies')); \
    cat('Analysis and machine learning packages installed\\n'); \
    "

# LIBARROW_MINIMAL only matters if P3M falls back to a source build; with the P3M
# binary it is ignored (binary arrow ships full libarrow).
RUN R -e " \
    Sys.setenv('LIBARROW_MINIMAL'=FALSE); \
    install.packages('arrow'); \
    "

# Install presto from GitHub 
# Note: there is a newer version of RCPPArmadillo going forward (in later CRAN releases), might be worthile revisiting if the base image is updated in the future
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
