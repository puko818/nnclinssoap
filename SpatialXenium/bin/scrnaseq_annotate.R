#!/usr/bin/env Rscript
library(yaml)
library(SingleR)
library(celldex)
library(Seurat)
library(dplyr)
library(ggplot2)
library(patchwork)
library(pheatmap)
library(cowplot)
library(Azimuth)

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

input_rds         <- args$input_rds
outdir            <- args$outdir %||% "."
annotation_method <- args$annotation_method %||% "Azimuth"
azimuth_ref       <- args$azimuth_ref %||% "pbmcref"
singler_ref       <- args$singler_ref %||% "dice"

dir.create(outdir, showWarnings = FALSE, recursive = TRUE)

cat("Loading Seurat object:", input_rds, "\n")
s <- readRDS(input_rds)

# SingleR ----------------------------------------------------------------------
if (annotation_method == "SingleR") {
  s <- JoinLayers(s)
  Idents(s) <- s$seurat_clusters

  # Log fold-change distribution (cluster 0 vs 1) to inform the marker threshold
  logfc_dist <- FindMarkers(s, ident.1 = 0, ident.2 = 1, logfc.threshold = 0.1, min.pct = 0.01)
  pdf(file.path(outdir, "lfc_distribution.pdf"), width = 12, height = 10)
  print(ggplot(logfc_dist, aes(x = avg_log2FC)) +
    geom_histogram(bins = 50) +
    labs(title = "Distribution of Log Fold Changes", x = "Log Fold Change", y = "Frequency"))
  dev.off()

  rna.markers <- FindAllMarkers(s, logfc.threshold = log(1), only.pos = TRUE, min.diff.pct = 0.3)
  write.csv(rna.markers, file.path(outdir, "findall_markers_singleR.csv"))

  ref_options <- list(
    dice                      = celldex::DatabaseImmuneCellExpressionData,
    hpca                      = celldex::HumanPrimaryCellAtlasData,
    blueprint_encode          = celldex::BlueprintEncodeData,
    immgen                    = celldex::ImmGenData,
    monaco_immune             = celldex::MonacoImmuneData,
    mouse_rnaseq              = celldex::MouseRNAseqData,
    novershtern_hematopoietic = celldex::NovershternHematopoieticData
  )
  ref_fn <- ref_options[[singler_ref]]
  if (is.null(ref_fn)) stop("Unrecognised singleR reference: ", singler_ref)
  ref <- ref_fn()

  object_counts <- GetAssayData(s, assay = "RNA", layer = "data")
  pred.fine <- SingleR(test = object_counts, ref = ref, labels = ref$label.fine)
  pred.main <- SingleR(test = object_counts, ref = ref, labels = ref$label.main)

  s <- AddMetaData(s, metadata = data.frame(
    fine_labels = pred.fine$labels,
    main_labels = pred.main$labels,
    row.names   = rownames(pred.fine)
  ))

  pdf(file.path(outdir, "umap_singleR_label.pdf"), width = 12, height = 10)
  print(DimPlot(s, reduction = "umap", group.by = "main_labels") +
        ggtitle(paste0("SingleR labels: ", singler_ref)))
  dev.off()

  pdf(file.path(outdir, "pred_scores_heatmap.pdf"), width = 12, height = 8)
  plotScoreHeatmap(pred.main)
  dev.off()

  pdf(file.path(outdir, "delta_distribution.pdf"), width = 16, height = 10)
  print(plotDeltaDistribution(pred.main))
  dev.off()

  # Summary stats for scoring (only defined in SingleR branch)
  df         <- data.frame(label = s$main_labels, score = apply(pred.main$scores, 1, max))
  cell_count <- data.frame(table(s$main_labels))
  colnames(cell_count) <- c("label", "count")
  avg_df     <- aggregate(score ~ label, data = df, FUN = mean)
  summary_df <- merge(avg_df, cell_count, by = "label")
  write.csv(summary_df, file.path(outdir, "annotation_scores.csv"))

  pdf(file.path(outdir, "IQR_boxplot.pdf"), width = 20, height = 10)
  print(ggplot(df, aes(x = label, y = score)) +
    geom_boxplot() +
    labs(x = "", y = "Prediction Score") +
    theme(axis.text.x = element_text(angle = 30, hjust = 1)))
  dev.off()

# Azimuth ----------------------------------------------------------------------
} else if (annotation_method == "Azimuth") {
  s <- JoinLayers(s)
  s <- RunAzimuth(s, reference = azimuth_ref, assay = "RNA", query.modality = "RNA")

  pdf(file.path(outdir, "Azimuth_umaps.pdf"), width = 20, height = 10)
  print(wrap_plots(
    DimPlot(s, group.by = "predicted.celltype.l1", label = TRUE, label.size = 3) + NoLegend(),
    DimPlot(s, group.by = "predicted.celltype.l2", label = TRUE, label.size = 3) + NoLegend(),
    DimPlot(s, group.by = "predicted.celltype.l3", label = TRUE, label.size = 3) + NoLegend(),
    ncol = 2
  ))
  dev.off()

  for (lvl in c("l1", "l2", "l3")) {
    pdf(file.path(outdir, paste0("azimuth-umap-", lvl, ".pdf")), width = 20, height = 10)
    print(DimPlot(s, reduction = "ref.umap", group.by = paste0("predicted.celltype.", lvl),
                  label = TRUE, label.size = 3) + NoLegend())
    dev.off()
  }

  df         <- data.frame(label = s$predicted.celltype.l2, score = s$predicted.celltype.l2.score)
  cell_count <- data.frame(table(s$predicted.celltype.l2))
  colnames(cell_count) <- c("label", "count")
  avg_df     <- aggregate(score ~ label, data = df, FUN = mean)
  summary_df <- merge(avg_df, cell_count, by = "label")
  write.csv(summary_df, file.path(outdir, "annotation_scores.csv"))

  pdf(file.path(outdir, "score_violin.pdf"), width = 20, height = 10)
  print(VlnPlot(s, features = "predicted.celltype.l2.score") + NoLegend())
  dev.off()

  iqr_prediction_score <- IQR(df$score)
  cat("IQR of prediction scores:", iqr_prediction_score, "\n")

  pdf(file.path(outdir, "IQR_boxplot.pdf"), width = 20, height = 10)
  print(ggplot(df, aes(x = label, y = score)) +
    geom_boxplot() +
    labs(x = "", y = "Prediction Score") +
    ggtitle("Box Plot of Prediction Scores") +
    theme(axis.text.x = element_text(angle = 30, hjust = 1)))
  dev.off()

  pdf(file.path(outdir, "boxplot_Labelcount_scores.pdf"), width = 18, height = 10)
  print(wrap_plots(
    ggplot(df, aes(x = "", y = score)) + geom_boxplot() + labs(x = "", y = "Prediction Score") + ggtitle("Label Scores"),
    ggplot(cell_count, aes(x = "", y = count)) + geom_boxplot() + labs(x = "", y = "Cell count") + ggtitle("Cell count"),
    ncol = 2
  ))
  dev.off()

} else {
  stop("Unknown annotation_method: ", annotation_method, ". Use 'Azimuth' or 'SingleR'.")
}

out_rds <- file.path(outdir, "annotated_seurat.rds")
cat("Saving:", out_rds, "\n")
saveRDS(s, out_rds)
cat("Annotation complete.\n")
