# Docker image for scRNA-seq preprocessing workflow
# Inherits from the base image, which sets P3M CRAN+Bioc repos globally in Rprofile.site.
# Main tools: Seurat 5.1, SoupX 1.6.2, scDblFinder 1.22, harmony 1.2.2, DropletUtils 1.28
# Extends the binary base, which sets P3M CRAN+Bioc repos globally in Rprofile.site.

FROM nnclinssoap/scrnaseq-base:4.5.2

LABEL maintainer="zemw@novonordisk.com"
LABEL description="R environment for scRNA-seq preprocessing: Seurat, SoupX, scDblFinder, harmony"
LABEL version="4.5.2"


# Install Quarto - have not found this being used in the upstream implementation
# RUN ARCH=$(dpkg --print-architecture) && \
# wget https://github.com/quarto-dev/quarto-cli/releases/download/v1.5.57/quarto-1.5.57-linux-${ARCH}.deb && \
# dpkg -i quarto-1.5.57-linux-${ARCH}.deb || true && \
# apt-get update && apt-get install -f -y && \
# rm quarto-1.5.57-linux-${ARCH}.deb && \
# rm -rf /var/lib/apt/lists/* && \
# quarto check install

# Install preprocessing-specific Bioconductor packages
RUN Rscript -e "\
    cat('Installing preprocessing packages...\\n'); \
    install.packages(c('DropletUtils', 'scDblFinder', 'glmGamPoi', 'bluster'))\ 
    cat('Preprocessing packages installed\\n'); \
"
# Install annotation packages
RUN Rscript -e " \
    cat('Installing annotation packages...\\n'); \
    install.packages(c('org.Hs.eg.db', 'AnnotationDbi', 'GO.db', 'KEGGREST'))\ 
    cat('Annotation packages installed\\n'); \
"

# Install SoupX from CRAN
RUN Rscript -e " \
    cat('Installing SoupX...\\n'); \
    install.packages('SoupX'); \
    cat('SoupX installed\\n'); \
"

# Install harmony from Bioconductor (repo already set to P3M in base image)
RUN Rscript -e " \
    cat('Installing harmony...\\n'); \
    install.packages('harmony'); \
    cat('harmony installed\\n'); \
"

ENV LC_ALL=C
ENV PATH=/usr/local/bin:$PATH
ENV R_LIBS_USER=/usr/local/lib/R/site-library


# Set working directory
WORKDIR /workspace

# Default command
CMD ["R"]
