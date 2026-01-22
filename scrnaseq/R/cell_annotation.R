# Load libraries
library(yaml)
library(SingleR)
library(celldex)
library(Seurat)
library(tidyverse)
library(pheatmap)
library(cowplot)
library(readxl)
library(patchwork)
library(SeuratData)
library(ggplot2)
library(Azimuth)
library(dplyr)

# Prepare data -----------------------------------------------------------------
yml <- read_yaml("configs/preprocessing_workflow.yml")
s <- readRDS(yml$SeuratPath)

# Create results folder path
resultspath <- yml$CellAnnotationPath
if (!dir.exists(resultspath)) {
  dir.create(resultspath)
}

# Strategy 1 - SingleR ---------------------------------------------------------
# Calculate log fold changes for all genes
if (yml$annotation_method == "SingleR") {
  s@active.ident <- s$seurat_clusters
  logfc_dist <- FindMarkers(s, ident.1 = 0, ident.2 = 1, logfc.threshold = 0.1, min.pct = 0.01)
  
  # Plot the distribution of log fold changes
  pdf(file = paste0(resultspath, "/lfc_distribution.pdf"), width = 12, height = 10)
  print(ggplot(data = logfc_dist, aes(x = avg_log2FC)) +
          geom_histogram(bins = 50) +
          labs(title = "Distribution of Log Fold Changes", x = "Log Fold Change", y = "Frequency"))
  dev.off()
  
  #Change lofc.threshold according to the plot
  rna.markers <- FindAllMarkers(s, logfc.threshold = log(1), only.pos = TRUE, min.diff.pct = 0.3)
  write.csv(rna.markers, paste0(resultspath, "/findall_markers_singleR.csv"))
  
  # Define a named list mapping reference names to their corresponding functions
  ref_options <- list(
    dice = celldex::DatabaseImmuneCellExpressionData,
    hpca = celldex::HumanPrimaryCellAtlasData,
    blueprint_encode = celldex::BlueprintEncodeData,
    immgen = celldex::ImmGenData,
    monaco_immune = celldex::MonacoImmuneData,
    mouse_rnaseq = celldex::MouseRNAseqData,
    novershtern_hematopoietic = celldex::NovershternHematopoieticData
  )
  
  # Get reference data
  ref_function <- ref_options[[yml$singleR_ref]]
  if (!is.null(ref_function)) {
    ref <- ref_function()  # Call the reference function
  } else {
    stop(paste("Error: Reference database", yml$singleR_ref, "not recognized."))
  }
  
  # Run SingleR
  object_counts <- GetAssayData(s, assay = "RNA")
  pred.fine <- SingleR(test = object_counts, ref = ref, labels = ref$label.fine)
  pred.main <- SingleR(test = object_counts, ref = ref, labels = ref$label.main)
  
  # Create a data frame with the predictions
  annotations <- data.frame(
    fine_labels = pred.fine$labels,
    main_labels = pred.main$labels,
    row.names = rownames(pred.fine)  # Make sure to set the row names to match original data
  )
  
  # Add SingleR annotations to the Seurat object meta data
  s <- AddMetaData(s, metadata = annotations)
  
  pdf(file = paste0(resultspath, "/umap_singleR_label.pdf"), width = 12, height = 10)
  DimPlot(s, reduction = "umap", group.by = "main_labels") + ggtitle(paste0("singleR labels: ", yml$cell_reference)) +
    theme(legend.text = element_text(size = 10))
  dev.off()
  
  # Annotation diagnostics 
  pred.main$scores #correlation of each cells with all the labels
  pdf(file = paste0(resultspath, "/pred_scores_singleR_heatmap-mainlabels.pdf"), width = 12, height = 8)
  plotScoreHeatmap(pred.main)
  dev.off()
  
  # Based on deltas across cells, low delta values = uncertain match
  pdf(file = paste0(resultspath, "/delta_distribution_singleR.pdf"), width = 16, height = 10)
  plotDeltaDistribution(pred.main) + ggtitle("singleR labels.main")
  dev.off()
}

# Strategy 2 - Azimuth ---------------------------------------------------------
if (yml$annotation_method == "Azimuth") {
  s <- JoinLayers(s)
  s <- RunAzimuth(s, reference = "pbmcref", assay = "RNA", query.modality = "RNA")
  
  pdf(file = paste0(resultspath, "/Azimuth_umaps_3levels.pdf"), width = 20, height = 10)
  p1 <- DimPlot(s, group.by = "predicted.celltype.l1", label = TRUE, label.size = 3) + NoLegend() + ggtitle("Pbmcref 1")
  p2 <- DimPlot(s, group.by = "predicted.celltype.l2", label = TRUE, label.size = 3) + NoLegend() + ggtitle("Pbmcref 2")
  p3 <- DimPlot(s, group.by = "predicted.celltype.l3", label = TRUE, label.size = 3) + NoLegend() + ggtitle("Pbmcref 3")
  print(wrap_plots(p1, p2, p3, ncol = 2))
  dev.off()
  
  pdf(file = paste0(resultspath, "/azimuth-umap-l1.pdf"), width = 20, height = 10)
  print(DimPlot(s, reduction = "ref.umap", group.by = "predicted.celltype.l1", label = TRUE, label.size = 3) + NoLegend())
  dev.off()
  
  pdf(file = paste0(resultspath, "/azimuth-umap-l2.pdf"), width = 20, height = 10)
  print(DimPlot(s, reduction = "ref.umap", group.by = "predicted.celltype.l2", label = TRUE, label.size = 3) + NoLegend())
  dev.off()
  
  pdf(file = paste0(resultspath, "/azimuth-umap-l3.pdf"), width = 20, height = 10)
  print(DimPlot(s, reduction = "ref.umap", group.by = "predicted.celltype.l3", label = TRUE, label.size = 3) + NoLegend())
  dev.off()
  
  ## Summary stats ---------------------------------------------------------------
  # Cell count
  cell_count <- data.frame(table(s$predicted.celltype.l2))
  colnames(cell_count) <- c("label", "count")
  
  df <- data.frame(
    label = s$predicted.celltype.l2,
    score = s$predicted.celltype.l2.score
  )
  
  avg_df <- aggregate(score ~ label, data = df, FUN = mean)
  
  summary_df <- merge(avg_df, cell_count, by = "label")
  write.csv(summary_df, paste0(resultspath, "/annotation_scores.csv"))
  
  pdf(file = paste0(resultspath, "/score_l2_vln.pdf"), width = 20, height = 10)
  print(VlnPlot(s, features = "predicted.celltype.l2.score") + NoLegend())
  dev.off()
}

#Save object 
saveRDS(s, yml$SeuratPath)

## Compute IQR -----------------------------------------------------------------
iqr_prediction_score <- IQR(df$score)
print(iqr_prediction_score)

# Create a box plot
pdf(file = paste0(resultspath, "/IQR_boxplot.pdf"), width = 20, height = 10)
ggplot(df, aes(x = label, y = score)) +
  geom_boxplot() +
  labs(x = "", y = "Prediction Score") +
  ggtitle("Box Plot of Prediction Scores") +
  theme(axis.text.x = element_text(angle = 30, hjust = 1))
dev.off()

pdf(file = paste0(resultspath, "/boxplot_Labelcount_scores.pdf"), width = 18, height = 10)
b1 <- ggplot(df, aes(x = "", y = score)) +
  geom_boxplot() +
  labs(x = "", y = "Prediction Score") +
  ggtitle("Label Scores") +
  theme(axis.text.x = element_text(angle = 30, hjust = 1))
b2 <- ggplot(cell_count, aes(x = "", y = count)) +
  geom_boxplot() +
  labs(x = "", y = "Cell count") +
  ggtitle("Cell count") +
  theme(axis.text.x = element_text(angle = 30, hjust = 1))
wrap_plots(b1, b2, ncol = 2)
dev.off()
