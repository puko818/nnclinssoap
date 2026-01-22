# Docker image for QC Report Generation
# Maintainer: zemw <zemw@novonordisk.com>

FROM python:3.11-slim

# Add container labels
LABEL maintainer="zemw@novonordisk.com"
LABEL description="Python 3.11 with fpdf2 for QC report generation"
LABEL version="1.0"

# Install system dependencies (procps provides 'ps' command for Nextflow metrics)
RUN apt-get update && apt-get install -y \
    procps \
    && rm -rf /var/lib/apt/lists/*

# Install Python packages
RUN pip install --no-cache-dir fpdf2

# Set environment variables
ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8

# Set working directory
WORKDIR /workspace

# Default command
CMD ["python3"]
