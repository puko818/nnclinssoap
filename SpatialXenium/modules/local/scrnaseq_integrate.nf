process SCRNASEQ_INTEGRATE {
    tag "n=${rds_files.size()}"
    label 'process_high'

    input:
    path rds_files   // collected list of per-sample RDS files
    val  sample_ids  // collected list of sample IDs (same order)

    output:
    path "integrated_seurat.rds", emit: rds
    path "*.pdf",                 emit: plots
    path "versions.yml",          emit: versions

    script:
    def rds_list = rds_files.join(",")
    def ids_list = sample_ids.join(",")
    """
    scrnaseq_integrate_samples.R \\
        --rds_files          "${rds_list}" \\
        --sample_ids         "${ids_list}" \\
        --integration_method ${params.integration_method} \\
        --cluster_resolution ${params.cluster_resolution} \\
        --outdir             .

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        r-base: \$(R --version | grep "R version" | sed 's/R version //')
        harmony: \$(Rscript -e "cat(as.character(packageVersion('harmony')))")
        seurat: \$(Rscript -e "cat(as.character(packageVersion('Seurat')))")
    END_VERSIONS
    """
}
