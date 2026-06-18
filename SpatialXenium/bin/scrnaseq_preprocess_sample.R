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

# custom operator definition
`%||%` <- function(a, b) if (!is.null(a) && !is.na(a) && a != "") a else b


# Read config file from command line (not using yml configuration from whirl in this version), command line params are  parsed with builin arg parser
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
cat("Reading sample:", sample_id, "\n")

# file.path preferred over paste0 (OS specific separator)
if (input_type == "mtx") {
  counts <- Seurat::ReadMtx(
    cells    = file.path(sample_path, "sample_filtered_feature_bc_matrix", "barcodes.tsv"),
    mtx      = file.path(sample_path, "sample_filtered_feature_bc_matrix", "matrix.mtx"),
    features = file.path(sample_path, "sample_filtered_feature_bc_matrix", "features.tsv"),
    feature.column = 1
  )

  # Extract current ENSG IDs from the matrix and map to gene symbols
  ensembl_ids       <- rownames(counts)
  ensembl_ids_clean <- gsub("\\..*$", "", ensembl_ids)
  gene_symbols      <- mapIds(org.Hs.eg.db, keys = ensembl_ids_clean, column = "SYMBOL", keytype = "ENSEMBL", multiVals = "first")
  # Keeping the Ensembl ID for not found genes
  new_gene_names <- ifelse(is.na(gene_symbols), ensembl_ids, gene_symbols)
  # Check for duplicates among the new gene names
  duplicate_indices <- which(duplicated(new_gene_names))
  if (length(duplicate_indices) > 0) {
    message(paste("Found", length(duplicate_indices), "duplicate gene symbols after mapping. Making them unique."))
    # Make them unique by appending suffixes like "_1", "_2", etc.
    new_gene_names <- make.unique(new_gene_names)
  }
  # Assign the new gene names to your matrix rownames
  rownames(counts) <- new_gene_names

  # Check how many IDs mapped
  message(paste("Mapped", sum(!is.na(gene_symbols)), "out of", length(ensembl_ids), "Ensembl IDs."))

  if (do_empty_drop) {
    cat("Performing Empty Drop ... \n")
    ret    <- DropletUtils::emptyDropsCellRanger(counts)
    counts <- counts[, which(ret$FDR <= fdr_cutoff), drop = FALSE]
    df     <- as.data.frame(ret) |>
      dplyr::filter(!is.na(FDR)) |>
      dplyr::mutate(Group = factor(ifelse(PValue < fdr_cutoff, "Cell", "EmptyDrop")))
    pdf(file.path(qc_dir, "EmptyDrop_Diag.pdf"), width = 10, height = 8)
    print(ggplot(df, aes(x = Total, y = -LogProb, color = Group)) + geom_point(alpha = 0.5) + labs(x = "Total UMI Count", y = "-Log Probability"))
    dev.off()
  }
# note that input_type was stored in multiple boolean flags in the upstream implementation in yml, now this is unified into a single input_type param
} else if (input_type == "h5_filtered") {
  hdf5  <- Seurat::Read10X_h5(file.path(sample_path, "sample_filtered_feature_bc_matrix.h5"),
                               use.names = TRUE, unique.features = TRUE)
  # no modality checking parameter in this version, the modus operandi is inferred directly from the hdf5's cardinality
  counts <- if (is.list(hdf5)) hdf5[[modality_type]] else hdf5

  # TODO check if do_empty_drop set to true is actually meaningful here - I assumed if the input is h5_filtered than this will add an additional null distribution estimation on top of already filetered input
  if (do_empty_drop) {
    cat("Performing Empty Drop ... \n")
    ret    <- DropletUtils::emptyDropsCellRanger(counts)
    counts <- counts[, which(ret$FDR <= fdr_cutoff), drop = FALSE]

    df     <- as.data.frame(ret) |>
      dplyr::filter(!is.na(FDR)) |>
      dplyr::mutate(Group = factor(ifelse(PValue < fdr_cutoff, "Cell", "EmptyDrop")))
    pdf(file.path(qc_dir, "EmptyDrop_Diag.pdf"), width = 10, height = 8)
    print(ggplot(df, aes(x = Total, y = -LogProb, color = Group)) + geom_point(alpha = 0.5) + labs(x = "Total UMI Count", y = "-Log Probability"))
    dev.off()
  }

} else if (input_type == "h5_raw_filtered") {
  # Read matrix filtered and raw matrix
  filt.matrix <- Read10X_h5(file.path(sample_path, "filtered_feature_bc_matrix.h5"))
  raw.matrix  <- Read10X_h5(file.path(sample_path, "raw_feature_bc_matrix.h5"))
  if (is.list(filt.matrix)) {
    filt.matrix <- filt.matrix[[modality_type]]
    raw.matrix  <- raw.matrix[[modality_type]]
  }

  # Barcode-rank plot (pre-ambient-removal)
  barcode_umis_sorted <- sort(Matrix::colSums(filt.matrix), decreasing = TRUE)
  brank_df <- data.frame(rank = seq_along(barcode_umis_sorted), total = barcode_umis_sorted)
  pdf(file.path(qc_dir, "barcode_rank_before_ed.pdf"), width = 10, height = 8)
  print(ggplot(brank_df, aes(x = rank, y = total)) +
    geom_point(size = 0.5) +
    scale_x_log10() + scale_y_log10() +
    labs(title = "Barcode Rank Plot", x = "Barcode Rank", y = "Total UMI Count") +
    theme_bw())
  dev.off()

  ## Remove ambient RNA with SoupX — cluster the filtered matrix to inform the soup channel
  cat("Removing ambient RNA with SoupX...\n")
  srat <- CreateSeuratObject(counts = filt.matrix)
  srat <- SCTransform(srat, verbose = FALSE)
  srat <- RunPCA(srat, verbose = FALSE)
  srat <- RunUMAP(srat, dims = 1:30, verbose = FALSE)
  srat <- FindNeighbors(srat, dims = 1:30, verbose = FALSE)
  srat <- FindClusters(srat, verbose = FALSE)

  # Adding clusters and the UMAP embedding to the soup channel
  soup.channel <- SoupChannel(tod = raw.matrix, toc = filt.matrix)
  soup.channel <- setClusters(soup.channel, setNames(srat@meta.data$seurat_clusters, rownames(srat@meta.data)))
  soup.channel <- setDR(soup.channel, srat@reductions$umap@cell.embeddings)

  # Calculate ambient RNA profile; tryCatch so a failure falls back to the filtered matrix
  soup.channel <- tryCatch(autoEstCont(soup.channel), error = function(e) {
    message("autoEstCont failed: ", e$message)
    NULL
  })

  # Proceed only if soup.channel is not NULL
  if (!is.null(soup.channel)) {
    pdf(file.path(qc_dir, "SoupX_contamination_densityPlot.pdf"), width = 10, height = 8)
    print(autoEstCont(soup.channel))
    dev.off()
    
    # Get counts after SoupX and remove unnecessary columns
    top_genes <- head(soup.channel$soupProfile[order(soup.channel$soupProfile$est, decreasing = TRUE), ], n = 20)
    print(top_genes)

    counts <- adjustCounts(soup.channel, roundToInt = TRUE)  # SoupX-adjusted counts
  } else {
      # If an error occurred, use the alternative option
      counts <- filt.matrix # Assign counts to filt.matrix if an error occurred
      message("Using filtered matrix as backup due to an error in autoEstCont.")
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

# Subset seurat object, according to min and max nfeatures and percent of mt rna
s <- subset(s, subset = nFeature_RNA < n_features_max & percent_mito < percent_mt_cutoff)

# Add metadata
cat("Adding metadata and QC metrics to the seurat object...\n")
s$patient_id <- participant
s$visit      <- visit
s$arm        <- arm
s$age        <- age
s$sex        <- sex

pdf(file.path(qc_dir, "QC_vln_scCustom.pdf"), width = 12, height = 12)
# note 'nCount_RNA' was present twice in the upstream implementation
print(wrap_plots(
  VlnPlot(s, features = "nFeature_RNA",  pt.size = 0),
  VlnPlot(s, features = "nCount_RNA",    pt.size = 0),
  VlnPlot(s, features = "percent_mito",  pt.size = 0),
  VlnPlot(s, features = "percent_ribo",  pt.size = 0),
  VlnPlot(s, features = "percent_plat",  pt.size = 0),
  VlnPlot(s, features = "complexity",    pt.size = 0),
  nrow = 2
))
dev.off()

# Plot scatter plots
pdf(file.path(qc_dir, "Scatter_plots.pdf"), width = 12, height = 10)
print(FeatureScatter(s, "percent_mito", "percent_ribo") +
      FeatureScatter(s, "nCount_RNA",   "nFeature_RNA"))
dev.off()

# Plot histogram of QC metrics
feats  <- c("nFeature_RNA", "nCount_RNA", "percent_mito", "percent_ribo", "percent_plat")
df_qc  <- melt(s[[]], variable.name = "Feature", value.name = "Value")
pdf(file.path(qc_dir, "Histogram.pdf"), width = 16, height = 12)
print(ggplot(df_qc, aes(x = Value)) +
  geom_histogram(fill = "blue", color = "black", bins = 40) +
  facet_wrap(~Feature, scales = "free") + theme_minimal())
dev.off()

# Filter seurat object- filter out MALAT1, mitochondrial (^MT-) and ribosomal (^RP[SL]) genes
s <- s[!grepl("MALAT1", rownames(s)), ]
s <- s[!grepl("^MT-",   rownames(s)), ]
s <- s[!grepl("^RP[SL]", rownames(s)), ]

# Gender plot - check if the genes actually exist first
gender_genes <- intersect(c("XIST", "DDX3Y", "TTTY14"), rownames(s))
if (length(gender_genes) > 0) {
  pdf(file.path(qc_dir, "GenderCheck_VlnPlot.pdf"), width = 6, height = 10)
  print(VlnPlot(s, features = gender_genes, pt.size = 0) +
        theme(axis.text.x = element_text(angle = 45, hjust = 1)))
  dev.off()
}

# 3. Normalize --------------------------------------------
cat("Normalizing data...\n")
s <- NormalizeData(s)

# Cell cycle scoring — cells in S and G2M phase
g2m       <- cc.genes$g2m.genes[cc.genes$g2m.genes %in% rownames(s)]
s_features <- cc.genes$s.genes[cc.genes$s.genes %in% rownames(s)]
s <- CellCycleScoring(s, g2m.features = g2m, s.features = s_features)

# Cell cycle plot
gender_feats <- c("S.Score", "G2M.Score")
pdf(file.path(qc_dir, "CellCycle_VlnPlot.pdf"), width = 12, height = 8)
print(VlnPlot(s, features = gender_feats, pt.size = 0) + theme(axis.text.x = element_text(angle = 45, hjust = 1)))
dev.off()

# 4. Identify highly variable features------------------------------------------
cat("Identifying highly variable features...\n")
s <- FindVariableFeatures(s, verbose = FALSE)

# View and plot top10 if wanted (he does not do it)
top10 <- head(VariableFeatures(s), 10)
pdf(file.path(qc_dir, "Top10_VariableFeatures.pdf"), width = 12, height = 8)
print(LabelPoints(VariableFeaturePlot(s), points = top10, repel = TRUE, xnudge = 0, ynudge = 0))
dev.off()

# 5. Scale and PCA -------------------------------------------------------------
cat("Scaling...")
s <- ScaleData(s, vars.to.regress = c("percent_mito", "S.Score", "G2M.Score"), verbose = FALSE)
  
cat("Performing linear dimensionality reduction...\n")
s <- RunPCA(s, verbose = FALSE, npcs = 30)

# Visualize PCA results using heatmap and elbowplot
pdf(file.path(qc_dir, "Heatmap_PCAPlot.pdf"))
DimHeatmap(s, dims = 1:30, cells = 500, balanced = TRUE)
dev.off()

# Choosing right number of PCAs
# Determine percent of variation associated with each PC
pct  <- s[["pca"]]@stdev / sum(s[["pca"]]@stdev) * 100   # % variation per PC
cumu <- cumsum(pct)                                       # cumulative % variation
# Determine which PC exhibits cumulative percent greater than 90% and % variation associated with the PC as less than 5
co1  <- which(cumu > 90 & pct < 5)[1]            

# Determine the difference between variation of PC and subsequent PC, last point where change of % of variation is more than 0.1%.
co2  <- sort(which((pct[1:(length(pct)-1)] - pct[2:length(pct)]) > 0.1), decreasing = TRUE)[1] + 1  # last PC where successive %-variation drop still > 0.1%

# Minimum of the two calculation
pcs  <- min(co1, co2)

pdf(file.path(qc_dir, "PCA_ElbowPlot.pdf"), width = 12, height = 8)
print(ElbowPlot(s, ndims = pcs + 5) +
      ggtitle(paste0("PCAs selected:", pcs)) +
      theme(plot.title = element_text(hjust = 0.5)))
dev.off()

s <- FindNeighbors(s, dims = 1:pcs)
s <- FindClusters(s, resolution = cluster_resolution)
s <- RunUMAP(s, dims = 1:pcs, verbose = FALSE)

head(Idents(s), 5)

pdf(file = paste0(resultspath, "Dimplot_umap_scCustom.pdf"), width = 12, height = 8)
print(DimPlot(s, reduction = "umap", group.by = "ident", label = TRUE, repel = TRUE, ncol = 2))
dev.off()


#Plot genes of interest, genes_of_interest loaded from the cli (previously yml)
if (length(genes_of_interest) > 0) {
  valid_genes <- genes_of_interest[genes_of_interest %in% rownames(s)]
  if (length(valid_genes) > 0) {
    pdf(file.path(qc_dir, "CheckGenesofInterest.pdf"), width = 16, height = 24)
    print(FeaturePlot(s, features = valid_genes, ncol = 2))
    dev.off()
  }
}

# 6. Doublet detection ---------------------------------------------------------
cat("Running doublet detection...\n")
sce <- scDblFinder(GetAssayData(s, layer = "counts"), clusters = Idents(s))

# Import the scDblFinder class from sce object to the Seurat Object
s$scDblFinder.class <- sce$scDblFinder.class

pdf(file.path(qc_dir, "Umap_Doublet_vs_Singlet.pdf"), width = 14, height = 8)
print(wrap_plots(
  DimPlot(s, reduction = "umap", group.by = "scDblFinder.class", raster = FALSE),
  DimPlot(s, reduction = "umap", split.by = "scDblFinder.class", raster = FALSE),
  ncol = 2
))
dev.off()

# Set identity to doublet class so we can subset on it
Idents(s) <- s$scDblFinder.class

pdf(file.path(qc_dir, "VlnPlot_Doublet_vs_singlet.pdf"), width = 12, height = 8)
print(
  (VlnPlot(s, features = "nFeature_RNA", split.by = "scDblFinder.class", pt.size = 0) +
     theme(axis.text.x = element_text(angle = 45, hjust = 1))) /
  (VlnPlot(s, features = "nCount_RNA", split.by = "scDblFinder.class", pt.size = 0) +
     theme(axis.text.x = element_text(angle = 45, hjust = 1)))
)
dev.off()

# Keep only singlets
s <- subset(s, idents = "singlet")

# Save -------------------------------------------------------------------------
out_rds <- file.path(outdir, paste0(sample_id, "_processed.rds"))
cat("Saving:", out_rds, "\n")
saveRDS(s, out_rds)
cat("Done:", sample_id, "\n")
