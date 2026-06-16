#!/usr/bin/env Rscript
set.seed(1234)

library(dplyr)
library(ggplot2)
library(hdf5r)
library(magrittr)
library(viridis)
library(scDblFinder)
library(harmony)
library(Seurat)
library(SoupX)
library(SeuratObject)
library(patchwork)
library(DropletUtils)
library(glmGamPoi)
library(org.Hs.eg.db)
library(reshape2)

# Simple named arg parser (no package dependencies)
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

sample_path       <- args$sample_path
sample_id         <- args$sample_id
outdir            <- args$outdir %||% "."
participant       <- args$participant %||% NA
visit             <- args$visit %||% NA
arm               <- args$arm %||% NA
sex               <- args$sex %||% NA
age               <- args$age %||% NA
input_type        <- args$input_type %||% "h5_filtered"  # mtx | h5_filtered | h5_raw_filtered
modality_type     <- args$modality_type %||% "Gene Expression"
do_empty_drop     <- as.logical(args$do_empty_drop %||% "FALSE")
fdr_cutoff        <- as.numeric(args$fdr_cutoff %||% "0.01")
n_features_max    <- as.numeric(args$n_features_max %||% "5000")
n_features_min    <- as.numeric(args$n_features_min %||% "500")
n_cells_cutoff    <- as.numeric(args$n_cells_cutoff %||% "10")
percent_mt_cutoff <- as.numeric(args$percent_mt_cutoff %||% "10")
cluster_resolution <- as.numeric(args$cluster_resolution %||% "0.6")
genes_of_interest <- if (!is.null(args$genes_of_interest) && args$genes_of_interest != "")
  strsplit(args$genes_of_interest, ",")[[1]] else character(0)

dir.create(outdir, showWarnings = FALSE, recursive = TRUE)
qc_dir <- file.path(outdir, "qc_plots")
dir.create(qc_dir, showWarnings = FALSE, recursive = TRUE)

# 1. Read data -----------------------------------------------------------------
cat("Reading data:", sample_id, "\n")

if (input_type == "mtx") {
  counts <- Seurat::ReadMtx(
    cells    = file.path(sample_path, "sample_filtered_feature_bc_matrix/barcodes.tsv"),
    mtx      = file.path(sample_path, "sample_filtered_feature_bc_matrix/matrix.mtx"),
    features = file.path(sample_path, "sample_filtered_feature_bc_matrix/features.tsv"),
    feature.column = 1
  )
  ensembl_ids       <- rownames(counts)
  ensembl_ids_clean <- gsub("\\..*$", "", ensembl_ids)
  gene_symbols      <- mapIds(org.Hs.eg.db, keys = ensembl_ids_clean,
                              column = "SYMBOL", keytype = "ENSEMBL", multiVals = "first")
  new_names         <- ifelse(is.na(gene_symbols), ensembl_ids, gene_symbols)
  rownames(counts)  <- make.unique(new_names)

  if (do_empty_drop) {
    ret    <- DropletUtils::emptyDropsCellRanger(counts)
    counts <- counts[, which(ret$FDR <= fdr_cutoff), drop = FALSE]
    df     <- as.data.frame(ret) |>
      dplyr::filter(!is.na(FDR)) |>
      dplyr::mutate(Group = factor(ifelse(PValue < fdr_cutoff, "Cell", "EmptyDrop")))
    pdf(file.path(qc_dir, "EmptyDrop_Diag.pdf"), width = 10, height = 8)
    print(ggplot(df, aes(x = Total, y = -LogProb, color = Group)) + geom_point(alpha = 0.5))
    dev.off()
  }

} else if (input_type == "h5_filtered") {
  hdf5  <- Seurat::Read10X_h5(file.path(sample_path, "sample_filtered_feature_bc_matrix.h5"),
                               use.names = TRUE, unique.features = TRUE)
  counts <- if (is.list(hdf5)) hdf5[[modality_type]] else hdf5

  if (do_empty_drop) {
    ret    <- DropletUtils::emptyDropsCellRanger(counts)
    counts <- counts[, which(ret$FDR <= fdr_cutoff), drop = FALSE]
    df     <- as.data.frame(ret) |>
      dplyr::filter(!is.na(FDR)) |>
      dplyr::mutate(Group = factor(ifelse(PValue < fdr_cutoff, "Cell", "EmptyDrop")))
    pdf(file.path(qc_dir, "EmptyDrop_Diag.pdf"), width = 10, height = 8)
    print(ggplot(df, aes(x = Total, y = -LogProb, color = Group)) + geom_point(alpha = 0.5))
    dev.off()
  }

} else if (input_type == "h5_raw_filtered") {
  filt.matrix <- Read10X_h5(file.path(sample_path, "filtered_feature_bc_matrix.h5"))
  raw.matrix  <- Read10X_h5(file.path(sample_path, "raw_feature_bc_matrix.h5"))
  if (is.list(filt.matrix)) {
    filt.matrix <- filt.matrix[[modality_type]]
    raw.matrix  <- raw.matrix[[modality_type]]
  }

  srat <- CreateSeuratObject(counts = filt.matrix)
  srat <- SCTransform(srat, verbose = FALSE)
  srat <- RunPCA(srat, verbose = FALSE)
  srat <- RunUMAP(srat, dims = 1:30, verbose = FALSE)
  srat <- FindNeighbors(srat, dims = 1:30, verbose = FALSE)
  srat <- FindClusters(srat, verbose = FALSE)

  soup.channel <- SoupChannel(tod = raw.matrix, toc = filt.matrix)
  soup.channel <- setClusters(soup.channel, setNames(srat@meta.data$seurat_clusters, rownames(srat@meta.data)))
  soup.channel <- setDR(soup.channel, srat@reductions$umap@cell.embeddings)

  soup.channel <- tryCatch(autoEstCont(soup.channel), error = function(e) {
    message("autoEstCont failed: ", e$message, " — using filtered matrix as fallback")
    NULL
  })

  if (!is.null(soup.channel)) {
    pdf(file.path(qc_dir, "SoupX_contamination_densityPlot.pdf"), width = 10, height = 8)
    print(autoEstCont(soup.channel))
    dev.off()
    counts <- adjustCounts(soup.channel, roundToInt = TRUE)
  } else {
    counts <- filt.matrix
  }
}

# 2. Create Seurat object + QC -------------------------------------------------
cat("Creating Seurat object...\n")
s <- CreateSeuratObject(counts = counts, min.cells = n_cells_cutoff, min.features = n_features_min)
DefaultAssay(s) <- "RNA"
s[["percent_mito"]] <- PercentageFeatureSet(s, pattern = "^MT-")
s[["percent_ribo"]] <- PercentageFeatureSet(s, pattern = "^RPS|^RPL")
s[["percent_plat"]] <- PercentageFeatureSet(s, "PECAM1|PF4")
s[["complexity"]]   <- s$nFeature_RNA / s$nCount_RNA
s <- subset(s, subset = nFeature_RNA < n_features_max & percent_mito < percent_mt_cutoff)

s$patient_id <- participant
s$visit      <- visit
s$arm        <- arm
s$age        <- age
s$sex        <- sex

pdf(file.path(qc_dir, "QC_vln.pdf"), width = 12, height = 12)
print(wrap_plots(
  VlnPlot(s, features = "nFeature_RNA",  pt.size = 0),
  VlnPlot(s, features = "nCount_RNA",    pt.size = 0),
  VlnPlot(s, features = "percent_mito",  pt.size = 0),
  VlnPlot(s, features = "percent_ribo",  pt.size = 0),
  VlnPlot(s, features = "complexity",    pt.size = 0),
  nrow = 2
))
dev.off()

pdf(file.path(qc_dir, "Scatter_plots.pdf"), width = 12, height = 10)
print(FeatureScatter(s, "percent_mito", "percent_ribo") +
      FeatureScatter(s, "nCount_RNA",   "nFeature_RNA"))
dev.off()

feats  <- c("nFeature_RNA", "nCount_RNA", "percent_mito", "percent_ribo", "percent_plat")
df_qc  <- melt(s[[]], variable.name = "Feature", value.name = "Value")
pdf(file.path(qc_dir, "Histogram.pdf"), width = 16, height = 12)
print(ggplot(df_qc, aes(x = Value)) +
  geom_histogram(fill = "blue", color = "black", bins = 40) +
  facet_wrap(~Feature, scales = "free") + theme_minimal())
dev.off()

s <- s[!grepl("MALAT1", rownames(s)), ]
s <- s[!grepl("^MT-",   rownames(s)), ]
s <- s[!grepl("^RP[SL]", rownames(s)), ]

# 3. Normalize + cell cycle scoring --------------------------------------------
cat("Normalizing...\n")
s <- NormalizeData(s)
g2m       <- cc.genes$g2m.genes[cc.genes$g2m.genes %in% rownames(s)]
s_features <- cc.genes$s.genes[cc.genes$s.genes %in% rownames(s)]
s <- CellCycleScoring(s, g2m.features = g2m, s.features = s_features)

pdf(file.path(qc_dir, "CellCycle_VlnPlot.pdf"), width = 12, height = 8)
print(VlnPlot(s, features = c("S.Score", "G2M.Score"), pt.size = 0))
dev.off()

# 4. Variable features ---------------------------------------------------------
s <- FindVariableFeatures(s, verbose = FALSE)
top10 <- head(VariableFeatures(s), 10)
pdf(file.path(qc_dir, "Top10_VariableFeatures.pdf"), width = 12, height = 8)
print(LabelPoints(VariableFeaturePlot(s), points = top10, repel = TRUE, xnudge = 0, ynudge = 0))
dev.off()

# 5. Scale + PCA + clustering + UMAP ------------------------------------------
cat("Scaling and clustering...\n")
s <- ScaleData(s, vars.to.regress = c("percent_mito", "S.Score", "G2M.Score"), verbose = FALSE)
s <- RunPCA(s, verbose = FALSE, npcs = 30)

pct  <- s[["pca"]]@stdev / sum(s[["pca"]]@stdev) * 100
cumu <- cumsum(pct)
co1  <- which(cumu > 90 & pct < 5)[1]
co2  <- sort(which((pct[1:(length(pct)-1)] - pct[2:length(pct)]) > 0.1), decreasing = TRUE)[1] + 1
pcs  <- min(co1, co2)

s <- FindNeighbors(s, dims = 1:pcs)
s <- FindClusters(s, resolution = cluster_resolution)
s <- RunUMAP(s, dims = 1:pcs, verbose = FALSE)

pdf(file.path(qc_dir, "UMAP_clusters.pdf"), width = 12, height = 8)
print(DimPlot(s, reduction = "umap", label = TRUE, repel = TRUE))
dev.off()

if (length(genes_of_interest) > 0) {
  valid_genes <- genes_of_interest[genes_of_interest %in% rownames(s)]
  if (length(valid_genes) > 0) {
    pdf(file.path(qc_dir, "GenesOfInterest.pdf"), width = 16, height = 24)
    print(FeaturePlot(s, features = valid_genes, ncol = 2))
    dev.off()
  }
}

# 6. Doublet detection ---------------------------------------------------------
cat("Running doublet detection...\n")
sce <- scDblFinder(GetAssayData(s, layer = "counts"), clusters = Idents(s))
s$scDblFinder.class <- sce$scDblFinder.class

pdf(file.path(qc_dir, "Doublet_UMAP.pdf"), width = 14, height = 8)
print(wrap_plots(
  DimPlot(s, reduction = "umap", group.by = "scDblFinder.class", raster = FALSE),
  DimPlot(s, reduction = "umap", split.by = "scDblFinder.class", raster = FALSE),
  ncol = 2
))
dev.off()

Idents(s) <- s$scDblFinder.class
s <- subset(s, idents = "singlet")

# Save -------------------------------------------------------------------------
out_rds <- file.path(outdir, paste0(sample_id, "_processed.rds"))
cat("Saving:", out_rds, "\n")
saveRDS(s, out_rds)
cat("Done:", sample_id, "\n")
