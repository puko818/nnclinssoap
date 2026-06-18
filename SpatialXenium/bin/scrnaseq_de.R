#!/usr/bin/env Rscript
library(dplyr)
library(tidyr)
library(ggplot2)
library(ggrepel)
library(Seurat)
library(Matrix)
library(data.table)
library(edgeR)
library(tibble)
library(cowplot)

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

input_rds     <- args$input_rds
outdir        <- args$outdir %||% "."
de_annotation <- args$de_annotation %||% "predicted.celltype.l1"

dir.create(outdir, showWarnings = FALSE, recursive = TRUE)

cat("Loading Seurat object:", input_rds, "\n")
s <- readRDS(input_rds)
s$type <- s[[de_annotation]][[1]]
cell_types <- unique(s$type)
cat("Running DE for", length(cell_types), "cell types\n")

run_edgeR <- function(seurat_obj, cell_type, outdir) {
  cell_type_label <- gsub(" ", "_", cell_type)

  s_celltype <- subset(seurat_obj, subset = type == cell_type)
  # Keep only samples with at least 5 cells of this cell type (in every visit)
  sample_counts <- table(s_celltype$patient_id, s_celltype$visit)
  keep_samples  <- names(which(apply(sample_counts, 1, min) >= 5))

  if (length(keep_samples) < 1) {
    message("Skipping ", cell_type, ": not enough cells per sample")
    return(NULL)
  }

  # Subset to the remaining samples
  s_subset <- subset(s_celltype, subset = patient_id %in% keep_samples)

  if (length(unique(s_subset$patient_id[s_subset$arm == "placebo"])) < 2 ||
      length(unique(s_subset$patient_id[s_subset$arm == "treatment"])) < 2) {
    message("Skipping ", cell_type, ": not enough paired samples")
    return(NULL)
  }

  # Pseudo-bulk: aggregate counts per (arm, patient, visit, sex, age)
  s_bulk <- AggregateExpression(s_subset, return.seurat = TRUE, assays = "RNA",
                                group.by = c("arm", "patient_id", "visit", "sex", "age"))

  # Counts matrix + metadata; rebuild the grouping columns by splitting the aggregated row names on "_"
  pseudo_mat <- as.matrix(GetAssayData(s_bulk, layer = "counts"))
  meta       <- s_bulk@meta.data
  split_df   <- do.call(rbind, strsplit(rownames(meta), "_"))
  meta$arm        <- factor(split_df[, 1]); meta$arm   <- relevel(meta$arm, "placebo")
  meta$patient_id <- split_df[, 2]
  meta$visit      <- factor(split_df[, 3]); meta$visit <- relevel(meta$visit, "bl")
  meta$sex        <- split_df[, 4]
  meta$age        <- split_df[, 5]

  y      <- DGEList(counts = pseudo_mat, samples = meta,
                    group = interaction(meta$arm, meta$visit))
  # Design: start with patient effects (account for between-patient variation),
  # then add the post (eot) vs pre (bl) treatment effect within each arm.
  design <- model.matrix(~patient_id, data = meta)
  placebo_post <- meta$arm == "placebo"    & meta$visit == "eot"
  trt_post     <- meta$arm == "treatment"  & meta$visit == "eot"
  design <- cbind(design, placebo_post, trt_post)

  # Keep genes expressed in ~>=25% of samples at 1 CPM
  y   <- y[filterByExpr(y, design), ]
  y   <- normLibSizes(y)
  y   <- estimateDisp(y, design)   # dispersion estimation
  fit <- glmQLFit(y, design)

  pdf(file.path(outdir, paste0(cell_type_label, "_bcv.pdf")), height = 6, width = 10)
  print(plotBCV(y))
  dev.off()

  # Interaction contrast (trt_post - placebo_post): genes responding differently
  # to treatment vs placebo over time (arm x time-point interaction).
  qlf.interaction <- glmQLFTest(fit, contrast = c(0, rep(0, ncol(design) - 3), -1, 1))
  counts_norm     <- edgeR::cpm(y, log = TRUE, prior.count = 3)
  write.csv(rownames_to_column(as.data.frame(counts_norm), var = "gene"),
            file.path(outdir, paste0(cell_type_label, "_countsNorm.csv")),
            row.names = FALSE)

  # Top 5 line plots
  genes     <- rownames(topTags(qlf.interaction))[1:min(5, nrow(topTags(qlf.interaction)))]
  plot_data <- counts_norm[genes, , drop = FALSE] |>
    as.data.frame() |>
    rownames_to_column("Gene") |>
    tidyr::pivot_longer(-Gene, names_to = "Sample", values_to = "Expression") |>
    tidyr::separate(Sample, into = c("arm", "patient_id", "visit"), sep = "_")

  spag_plots <- lapply(genes, function(g) {
    ggplot(dplyr::filter(plot_data, Gene == g),
           aes(x = factor(visit, level = c("bl", "eot")), y = Expression)) +
      geom_point(aes(group = patient_id), color = "grey80") +
      geom_line(aes(group = patient_id), color = "grey80") +
      stat_summary(geom = "point") +
      stat_summary(geom = "errorbar", width = 0.15) +
      stat_summary(geom = "line") +
      facet_wrap(~arm) + theme_bw() + ggtitle(g) + xlab("Visit")
  })
  pdf(file.path(outdir, paste0(cell_type_label, "_top5_lineplot.pdf")), height = 18, width = 10)
  print(cowplot::plot_grid(plotlist = spag_plots, nrow = length(genes)))
  dev.off()

  # Volcano plot + CSV
  de <- as.data.frame(topTags(qlf.interaction, n = nrow(qlf.interaction)))
  de$cell_type    <- cell_type
  de$significance <- ifelse(de$logFC > 0 & de$FDR < 0.05, "Upregulated",
                     ifelse(de$logFC < 0 & de$FDR < 0.05, "Downregulated", "Not Significant"))
  setorder(de, PValue)
  de$gene <- rownames(de)
  write.csv(de, file.path(outdir, paste0(cell_type_label, "_tx.csv")))

  pdf(file.path(outdir, paste0(cell_type_label, "_volcano.pdf")), height = 12, width = 20)
  print(ggplot(de, aes(x = logFC, y = -log10(FDR), color = significance, label = gene)) +
    geom_point(alpha = 0.8, size = 2) +
    scale_color_manual(values = c("Upregulated"   = "firebrick",
                                  "Downregulated" = "royalblue",
                                  "Not Significant" = "gray")) +
    geom_text_repel(data = subset(de, -log10(FDR) > 30 & abs(logFC) > 4),
                    aes(label = gene), vjust = 1.5, size = 3) +
    labs(x = "Effect Size", y = "-log10(FDR)") + theme_minimal())
  dev.off()

  de
}

results <- lapply(cell_types, function(ct) run_edgeR(s, ct, outdir))
results <- Filter(Negate(is.null), results)

if (length(results) > 0) {
  merged <- dplyr::bind_rows(results)
  merged <- merged[, 1:7]
  colnames(merged)[1] <- "gene"
  write.csv(merged, file.path(outdir, "summary_DE_analysis.csv"))
  cat("DE analysis complete —", nrow(merged), "results written.\n")
} else {
  cat("No cell types had sufficient cells for DE analysis.\n")
}
