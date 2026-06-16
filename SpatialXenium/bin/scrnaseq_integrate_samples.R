#!/usr/bin/env Rscript
set.seed(1234)

library(Seurat)
library(SeuratObject)
library(harmony)
library(ggplot2)
library(patchwork)

`%||%` <- function(a, b) if (!is.null(a) && !is.na(a) && a != "") a else b

parse_args <- function() {
  raw <- commandArgs(trailingOnly = TRUE)
  result <- list()
  i <- 1
  while (i <= length(raw)) {
    if (startsWith(raw[i], "--")) {
      key <- gsub("-", "_", sub("^--", "", raw[i]))
      if (i + 1 <= length(raw) && !startsWith(raw[i + 1], "--")) {
        result[[key]] <- raw[i + 1]
        i <- i + 2
      } else {
        result[[key]] <- TRUE
        i <- i + 1
      }
    } else {
      i <- i + 1
    }
  }
  result
}

args <- parse_args()

# rds_files: comma-separated paths to per-sample RDS files
# sample_ids: comma-separated sample IDs (same order as rds_files)
rds_paths          <- strsplit(args$rds_files, ",")[[1]]
sample_ids         <- strsplit(args$sample_ids, ",")[[1]]
integration_method <- args$integration_method %||% "harmony"
cluster_resolution <- as.numeric(args$cluster_resolution %||% "0.6")
outdir             <- args$outdir %||% "."

dir.create(outdir, showWarnings = FALSE, recursive = TRUE)

cat("Loading", length(rds_paths), "sample objects...\n")
nn <- lapply(rds_paths, readRDS)

if (!all(sapply(nn, is, "Seurat"))) stop("All inputs must be Seurat objects")

# Harmony integration ----------------------------------------------------------
if (integration_method == "harmony") {
  cat("Performing Harmony integration...\n")

  nn1      <- nn[[1]]
  nn_rest  <- nn[-1]
  AllNN    <- merge(nn1, y = nn_rest, add.cell.ids = sample_ids, project = "NNIntegrate")
  rm(nn, nn1, nn_rest)

  AllNN <- NormalizeData(AllNN)
  AllNN <- FindVariableFeatures(AllNN, selection.method = "vst", nfeatures = 2000)
  AllNN <- ScaleData(AllNN)
  AllNN <- RunPCA(AllNN, features = VariableFeatures(object = AllNN))
  AllNN$orig.ident <- paste0(AllNN$patient_id, "_", AllNN$visit)

  AllNN <- AllNN |>
    RunHarmony(group.by.vars = "orig.ident", plot_convergence = FALSE,
               nclust = 50, max_iter = 10, early_stop = TRUE)

  pdf(file.path(outdir, "Harmonization_Quality.pdf"), width = 16, height = 8)
  print(
    DimPlot(AllNN, reduction = "harmony", pt.size = .1, group.by = "orig.ident", raster = FALSE) /
    VlnPlot(AllNN, features = "harmony_1", group.by = "orig.ident", pt.size = 0)
  )
  dev.off()

  AllNN <- FindNeighbors(AllNN, reduction = "harmony", dims = 1:30)
  AllNN <- FindClusters(AllNN, resolution = cluster_resolution)
  AllNN <- RunUMAP(AllNN, reduction = "harmony", dims = 1:30)

  pdf(file.path(outdir, "Harmony_UMAP.pdf"), width = 12, height = 8)
  print(wrap_plots(
    DimPlot(AllNN, reduction = "umap", group.by = "patient_id", split.by = "visit",
            pt.size = .1, raster = FALSE),
    DimPlot(AllNN, reduction = "umap", label = TRUE, pt.size = .1, raster = FALSE),
    nrow = 2
  ))
  dev.off()

  integrated <- AllNN
  rm(AllNN)

# RPCA integration -------------------------------------------------------------
} else if (integration_method == "rpca") {
  cat("Performing RPCA integration...\n")

  nn_list <- lapply(nn, function(x) {
    x <- NormalizeData(x)
    x <- FindVariableFeatures(x, selection.method = "vst", nfeatures = 2000)
    x
  })

  features <- SelectIntegrationFeatures(object.list = nn_list)
  nn_list  <- lapply(nn_list, function(x) {
    x <- ScaleData(x, features = features, verbose = FALSE)
    x <- RunPCA(x, features = features, verbose = FALSE)
    x
  })

  anchors    <- FindIntegrationAnchors(object.list = nn_list,
                                       anchor.features = features, reduction = "rpca")
  integrated <- IntegrateData(anchorset = anchors, dims = 1:30)
  DefaultAssay(integrated) <- "integrated"

  integrated <- ScaleData(integrated)
  integrated <- RunPCA(integrated, features = VariableFeatures(integrated))

  pct  <- integrated[["pca"]]@stdev / sum(integrated[["pca"]]@stdev) * 100
  cumu <- cumsum(pct)
  co1  <- which(cumu > 90 & pct < 5)[1]
  co2  <- sort(which((pct[1:(length(pct)-1)] - pct[2:length(pct)]) > 0.1), decreasing = TRUE)[1] + 1
  pcs  <- min(co1, co2)

  integrated <- RunUMAP(integrated, dims = 1:pcs)
  integrated <- FindNeighbors(integrated, dims = 1:pcs)
  integrated <- FindClusters(integrated, resolution = cluster_resolution)

  pdf(file.path(outdir, "RPCA_UMAP.pdf"), width = 12, height = 8)
  print(wrap_plots(
    DimPlot(integrated, reduction = "umap", group.by = "patient_id",
            split.by = "visit", pt.size = .1, raster = FALSE),
    DimPlot(integrated, reduction = "umap", label = TRUE, pt.size = .1, raster = FALSE),
    nrow = 2
  ))
  dev.off()

} else {
  stop("Unknown integration_method: ", integration_method, ". Use 'harmony' or 'rpca'.")
}

out_rds <- file.path(outdir, "integrated_seurat.rds")
cat("Saving:", out_rds, "\n")
saveRDS(integrated, out_rds)
cat("Integration complete.\n")
