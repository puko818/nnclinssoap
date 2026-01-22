#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(argparser)
  library(Seurat)
  library(ggplot2)
})

p <- arg_parser("Plot features on UMAP and spatial image from a Seurat object")
p <- add_argument(p, "--inrds", help = "Path to input Seurat RDS file", type = "character") # nolint
p <- add_argument(p, "--outdir", help = "Output directory for plots", type = "character") # nolint
p <- add_argument(p, "--sample_name", help = "Sample name for plot titles and filenames", type = "character") # nolint
p <- add_argument(p, "--feat_genes_file", help = "Path to a text file with one gene per line", type = "character") # nolint

args <- parse_args(p)
inrds <- args$inrds
outdir <- args$outdir
sample_name <- args$sample_name
feat_genes_file <- args$feat_genes_file


# Load the Seurat object
seurat_obj <- readRDS(inrds)

# Read the genes from the file if provided
if (!is.null(feat_genes_file) && file.exists(feat_genes_file)) {
  feat_genes <- readLines(feat_genes_file)
  # Remove empty lines if any
  feat_genes <- feat_genes[nzchar(feat_genes)]
} else {
  feat_genes <- character()
}

# Read the genes from the file if provided
if (!is.null(feat_genes_file) && file.exists(feat_genes_file)) {
  feat_genes <- readLines(feat_genes_file)
  # Remove empty lines if any
  feat_genes <- feat_genes[nzchar(feat_genes)]
} else {
  feat_genes <- character()
}

# If feat_genes is not empty, plot them
if (length(feat_genes) > 0) {
  # Plot features on UMAP
  bygene_umap <- FeaturePlot(
    seurat_obj,
    features = feat_genes,
    keep.scale = "all"
  )

  ggsave(
    bygene_umap,
    filename = sprintf("%s/%s_umap_gene_expr.png", outdir, sample_name),
    width = 10, height = 8, dpi = 300
  )

  # Derive fov name for ImageDimPlot
  fov_name <- gsub("-", "_", paste0("sample_", sample_name, "_fov"))

  # Plot features on the tissue image
  bygene_spat <- ImageFeaturePlot(
    seurat_obj,
    features = feat_genes,
    fov = fov_name, 
  )

  ggsave(
    bygene_spat,
    filename = sprintf("%s/%s_insitu_gene_expr.png", outdir, sample_name),
    width = 21,
    height = 10,
    bg = "white",
    dpi = 300
  )

} else {
  message("No genes provided in --feat_genes_file. Skipping feature plotting.")
}
