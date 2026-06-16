process SCRNASEQ_DE {
    tag "de_annotation=${de_annotation}"
    // edgeR pseudo-bulk DE peaks ~11GB on the test data; process_medium's 8GB
    // first attempt OOMs and wastes a retry. process_high_memory starts at 16GB.
    label 'process_high_memory'

    input:
    path input_rds
    val de_annotation

    output:
    path "de_results/summary_DE_analysis.csv", emit: summary
    path "de_results/*.csv",                   emit: de_tables
    path "de_results/*.pdf",                   emit: plots
    path "versions.yml",                        emit: versions

    script:
    """
    mkdir -p de_results

    scrnaseq_de.R \\
        --input_rds     ${input_rds} \\
        --outdir        de_results \\
        --de_annotation ${de_annotation}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        r-base: \$(R --version | grep "R version" | sed 's/R version //')
        edger: \$(Rscript -e "cat(as.character(packageVersion('edgeR')))")
        seurat: \$(Rscript -e "cat(as.character(packageVersion('Seurat')))")
    END_VERSIONS
    """
}
