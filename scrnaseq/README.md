# nnclinssoap
* The scRNAseq pipeline has been fully integrated into the SpatialXenium Nextflow workflow
* This bypasses the whirl execution and makes this folder obsolete for this version of the pipeline
* The R scripts also integrated into SpatialXenium/bin
Novo Nordisk Clinical Single-cell Spatial Omics Analytical Pipeline

Unzip test_data and move to folder test_data

Install environment renv_processing.lock
Run whirl::run("whirl/whirl_runner_preprocessing.R")

Install environment renv_analaysis.lock
Run whirl::run("whirl/whirl_runner_analysis.R")
