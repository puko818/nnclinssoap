process SCRNASEQ_PREPROCESS {
    tag "$meta.id"
    label 'process_medium'

    input:
    tuple val(meta), path(sample_path)

    output:
    tuple val(meta), path("${meta.id}_processed.rds"), emit: rds
    tuple val(meta), path("qc_plots/"),                emit: qc_plots
    path "versions.yml",                               emit: versions

    script:
    def genes = params.genes_of_interest ? "--genes_of_interest \"${params.genes_of_interest}\"" : ""
    """
    scrnaseq_preprocess_sample.R \\
        --sample_path   ${sample_path} \\
        --sample_id     ${meta.id} \\
        --outdir        . \\
        --participant   ${meta.participant} \\
        --visit         ${meta.visit} \\
        --arm           ${meta.arm} \\
        --sex           ${meta.sex} \\
        --age           ${meta.age} \\
        --input_type    ${params.input_type} \\
        --n_features_max    ${params.n_features_max} \\
        --n_features_min    ${params.n_features_min} \\
        --n_cells_cutoff    ${params.n_cells_cutoff} \\
        --percent_mt_cutoff ${params.percent_mt_cutoff} \\
        --cluster_resolution ${params.cluster_resolution} \\
        --do_empty_drop ${params.do_empty_drop} \\
        --fdr_cutoff    ${params.fdr_cutoff} \\
        ${genes}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        r-base: \$(R --version | grep "R version" | sed 's/R version //')
        seurat: \$(Rscript -e "cat(as.character(packageVersion('Seurat')))")
        scDblFinder: \$(Rscript -e "cat(as.character(packageVersion('scDblFinder')))")
    END_VERSIONS
    """
}
