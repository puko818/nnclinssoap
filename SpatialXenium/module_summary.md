# Executive Summary

This document provides an overview of the Nextflow pipeline designed to process spatial transcriptomics data from Xenium experiments, perform optional label transfer from a reference single-cell dataset, and generate feature-specific plots.

---

## Table of Contents
1. [Pipeline Overview](#pipeline-overview)
2. [Modules](#modules)
   - [SEURAT_XENIUM](#1-seurat_xenium-module)
   - [LABEL_TRANSFER](#2-label_transfer-module)
   - [PLOT_FEATURE](#3-plot_feature-module)
3. [Explicit Module Inputs](#explicit-module-inputs)
   - [Process_Individual_Xenium_Sample.r](#process_individual_xenium_samplER)
   - [label_transfer.r](#label_transferr)
   - [plot_features.r](#plot_featuresr)
4. [Pipeline Outputs](#pipeline-outputs)
5. [Example File Structure in `results/`](#example-file-structure-in-results)


---

## Pipeline Overview

1. **Data Loading & QC (SEURAT_XENIUM)**
   - Opens Xenium data, merges QC metadata, and filters cells/genes based on user-defined thresholds.
   - Identifies highly variable genes, performs dimensionality reduction (PCA, UMAP), clustering, and marker identification.
   - Saves intermediate metrics, plots, and a final Seurat object (optionally using a generic name if `generic_name` is set to `TRUE`).

2. **Label Transfer (LABEL_TRANSFER)**
   - Optionally takes a reference single-cell Seurat object, identifies shared features, and uses anchor-based label transfer.
   - Assigns cell types to the Xenium data, applying a minimum probability cutoff.
   - Outputs labeled Seurat objects and cell-type prediction tables.
   - Incorporates an adjustable `future_mem_limit` for parallel R operations if needed.

3. **Feature Plotting (PLOT_FEATURE)**
   - Generates UMAP and spatial (ImageFeaturePlot) visualizations of gene expression for user-specified features.
   - Saves publication-ready figures.

---

## Modules

### 1. SEURAT_XENIUM Module

**Process_Individual_Xenium_Sample.r**  
- Orchestrates reading/validating data, quality control, filtering, dimensionality reduction, clustering, and saving results.
- Can optionally produce a generically named output RDS if `--generic_name` is set to `"TRUE"`.

**Key Functions**  
- *open_seurat()*: Loads Xenium data into Seurat, merging QC metadata.  
- *plot_qc()*: Generates QC plots (e.g., read count distributions, gene feature counts).  
- *filter_genes()*: Filters genes based on average quality value (QV) and read count thresholds.  
- *run_seurat()*: Normalizes data, identifies variable features, runs PCA/UMAP/clustering.  
- *get_cell_markers()*: Finds marker genes for each cluster.  
- *plot_processed_data()*: Visualizes PCA, feature distributions, and UMAP.

---

### 2. LABEL_TRANSFER Module

**label_transfer.r**  
- Reads the query Seurat RDS, reference RDS, and label column parameters.  
- Calls *transfer_labels()* to annotate the Xenium data.  
- Supports a `--future_mem_limit` parameter to set memory usage for parallel operations.  
- Outputs labeled Seurat RDS and prediction files.

**Key Functions**  
- *create_bygene_df()*: Summarizes gene counts across Seurat assays.  
- *transfer_labels()*:  
  1. Loads a reference RDS (single-cell data), ensuring matching label columns and overlapping features.  
  2. Fits a linear model (query vs. reference gene counts), calculates residuals, and identifies anchors.  
  3. Performs label transfer via *TransferData()*, generating predicted labels and probabilities.  
  4. Filters low-probability cells (“Ambiguous”) and updates Seurat metadata.

---

### 3. PLOT_FEATURE Module

**plot_features.r**  
- Loads the Seurat object from RDS.  
- Reads a text file of gene names.  
- Produces and saves UMAP and spatial plots.  
- If no gene list is provided, plotting is skipped.

**Key Functions**  
- Generates **FeaturePlot** on UMAP for each specified gene.  
- Creates **ImageFeaturePlot** to overlay gene expression on spatial coordinates.

---

## Explicit Module Inputs

### **Process_Individual_Xenium_Sample.r**

| **Parameter**                 | **Description**                                                                                | **Default**   |
|-------------------------------|------------------------------------------------------------------------------------------------|---------------|
| `--indir`                     | Path to an individual Xenium sample directory                                                  | *Required*    |
| `--outdir`                    | Output directory                                                                               | *Required*    |
| `--sample_name`               | Label for the sample (e.g., “SampleA”)                                                        | *Required*    |
| `--min_reads_per_cell`        | Minimum read count threshold                                                                   | `10`          |
| `--max_reads_per_cell`        | Maximum read count threshold                                                                   | `1e6`         |
| `--max_control_prop_per_cell` | Maximum proportion of control probes/codewords per cell                                        | `1.0`         |
| `--metadata_path`             | (Optional) Path to a sample-level CSV metadata file                                            | *None*        |
| `--n_highly_var_genes`        | Number of highly variable genes in FindVariableFeatures                                        | `1000`        |
| `--min_quality_per_gene`      | Minimum average QV for gene filtering                                                          | `20`          |
| `--generic_name`              | Flag to use a generic name (`"TRUE"`) for the output RDS (Xenium_Seurat_Object_processed.rds)  | `"FALSE"`     |

**Workflow**  
1. Loads and validates data from `--indir`.  
2. Performs cell- and gene-level QC (filters low/high read count cells, genes with low QV).  
3. Runs standard Seurat analyses (PCA, UMAP, clustering).  
4. If `--generic_name` is `"TRUE"`, final output is named `Xenium_Seurat_Object_processed.rds`; otherwise uses `<sample>_processed.rds`.  
5. Saves processed results and plots under `--outdir`.

---

### **label_transfer.r**

| **Parameter**                | **Description**                                                                      | **Default** |
|------------------------------|--------------------------------------------------------------------------------------|------------|
| `--inrds`                    | Query Seurat RDS (output of SEURAT_XENIUM)                                          | *Required* |
| `--reference_rds`           | Reference single-cell Seurat RDS                                                    | *Required* |
| `--label_col`                | Reference metadata column to transfer labels from                                   | *Required* |
| `--outdir`                   | Output directory                                                                    | *Required* |
| `--sample_name`              | Identifier for output naming                                                        | *Required* |
| `--min_celltype_probability` | Minimum probability for cell type classification                                    | `0.5`      |
| `--future_mem_limit`         | Memory limit (bytes) for R's `future` package, e.g. `8e9` for 8GB                    | `8e9`      |

**Workflow**  
1. Loads query and reference Seurat objects, finds overlapping features.  
2. Computes linear model residuals to detect outlier genes.  
3. Uses FindTransferAnchors() and TransferData() to predict cell labels.  
4. Filters out low-probability calls as “Ambiguous.”  
5. Saves updated Seurat object (`*_labeled.rds`) and predictions (`*_celltype_predictions.csv`).  
6. If `--future_mem_limit` is set, parallel tasks respect this memory cap.

---

### **plot_features.r**

| **Parameter**       | **Description**                                 | **Default**  |
|---------------------|-------------------------------------------------|--------------|
| `--inrds`           | Path to a Seurat RDS file                       | *Required*   |
| `--outdir`          | Output directory for plots                      | *Required*   |
| `--sample_name`     | Sample identifier for figure titles             | *Required*   |
| `--feat_genes_file` | Text file with one gene name per line           | *Optional*   |

**Workflow**  
1. Loads the (optionally labeled) Seurat object.  
2. Reads the list of genes to plot.  
3. Generates UMAP-based FeaturePlots and corresponding ImageFeaturePlots.  
4. Saves output images to `--outdir`.

---

## Pipeline Outputs

1. **Processed Seurat Objects**  
   - Each sample’s Seurat RDS (or `Xenium_Seurat_Object_processed.rds` if `generic_name=TRUE`) after normalization, PCA, UMAP, clustering, etc.

2. **QC Metrics**  
   - Summaries of read counts, gene counts, control probe proportions, and filtering results.

3. **Diagnostic Plots**  
   - QC distributions, scatter plots with marginal histograms, waterfall plots, PCA/UMAP embeddings, and gene expression overlays.

4. **Label Transfer Results** *(if reference is provided)*  
   - Cell type predictions and probabilities.  
   - Labeled Seurat objects with updated metadata.

5. **Feature Plots** *(if genes.txt is provided)*  
   - UMAP and spatial feature plots for specified genes.

## Example File Structure in `results/`

Below is an illustration of the final directory hierarchy after running the pipeline on two samples (`sample_1` and `sample_2`). The structure may vary based on which modules/parameters were used.

```
results/
├── sample_1
│   ├── label_transfer
│   │   └── label_transfer
│   │       ├── sample_1_celltype_predictions.csv
│   │       ├── sample_1_labeled.rds
│   │       ├── sample_1_predicted_celltype_frequencies.png
│   │       └── ... (other label-transfer outputs/plots)
│   ├── plot_features
│   │   └── Feature_Plots
│   │       ├── sample_1_umap_gene_expr.png
│   │       └── sample_1_insitu_gene_expr.png
│   └── seurat_xenium
│       ├── sample_1
│       │   ├── analysis_summary.html
│       │   ├── cells.csv.gz
│       │   ├── metrics_summary.csv
│       │   └── ... (additional Xenium raw outputs)
│       └── output
│           ├── data
│           │   ├── sample_1_bygene_tbl.csv
│           │   ├── sample_1_cluster_markers_wide.csv
│           │   └── ... (other QC tables)
│           ├── plots
│           │   ├── initial_QC
│           │   │   └── sample_1_nCount_Xenium_waterfall.png
│           │   ├── filtering_QC
│           │   │   └── sample_1_average_qv_by_nCount_log10_bygene_transcript_type.png
│           │   └── seurat_output
│           │       └── sample_1_cluster_markers_dotplot.png
│           ├── sample_1_processed.rds
│           └── sessionInfo
│               ├── Process_Individual_Xenium_Sample_sample_1_sessionInfo_start.txt
│               └── Process_Individual_Xenium_Sample_sample_1_sessionInfo_end.txt
├── sample_2
│   ├── label_transfer
│   │   └── label_transfer
│   │       ├── sample_2_celltype_predictions.csv
│   │       ├── sample_2_labeled.rds
│   │       ├── sample_2_predicted_celltype_frequencies.png
│   │       └── ... (other label-transfer outputs/plots)
│   ├── plot_features
│   │   └── Feature_Plots
│   │       ├── sample_2_umap_gene_expr.png
│   │       └── sample_2_insitu_gene_expr.png
│   └── seurat_xenium
│       ├── sample_2
│       │   ├── analysis_summary.html
│       │   ├── cells.csv.gz
│       │   ├── metrics_summary.csv
│       │   └── ... (additional Xenium raw outputs)
│       └── output
│           ├── data
│           │   ├── sample_2_bygene_tbl.csv
│           │   ├── sample_2_cluster_markers_wide.csv
│           │   └── ... (other QC tables)
│           ├── plots
│           │   ├── initial_QC
│           │   │   └── sample_2_nCount_Xenium_waterfall.png
│           │   ├── filtering_QC
│           │   │   └── sample_2_average_qv_by_nCount_log10_bygene_transcript_type.png
│           │   └── seurat_output
│           │       └── sample_2_cluster_markers_dotplot.png
│           ├── sample_2_processed.rds
│           └── sessionInfo
│               ├── Process_Individual_Xenium_Sample_sample_2_sessionInfo_start.txt
│               └── Process_Individual_Xenium_Sample_sample_2_sessionInfo_end.txt
├── pipeline_info
│   ├── execution_report_YYYY-MM-DD_hh-mm-ss.html
│   ├── execution_timeline_YYYY-MM-DD_hh-mm-ss.html
│   ├── execution_trace_YYYY-MM-DD_hh-mm-ss.txt
│   └── ... (other logs/parameter files)
└── qc_report
    └── QC_report.pdf
```

- **`sample_1/` and `sample_2/`**: Each directory contains all outputs specific to that sample.  
- **`pipeline_info/`**: Stores Nextflow execution reports, timeline, and parameter JSON for reproducibility.

---


