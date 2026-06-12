process SCRNASEQ_ANNOTATE {
    tag "annotation=${params.annotation_method}"
    label 'process_high'

    input:
    path input_rds

    output:
    path "annotated_seurat.rds",      emit: rds
    path "annotation_scores.csv",     emit: scores
    path "*.pdf",                     emit: plots
    path "versions.yml",              emit: versions

    script:
    """
    scrnaseq_annotate.R \\
        --input_rds        ${input_rds} \\
        --outdir           . \\
        --annotation_method ${params.annotation_method} \\
        --azimuth_ref      ${params.azimuth_ref} \\
        --singler_ref      ${params.singler_ref}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        r-base: \$(R --version | grep "R version" | sed 's/R version //')
        seurat: \$(Rscript -e "cat(as.character(packageVersion('Seurat')))")
        azimuth: \$(Rscript -e "cat(as.character(packageVersion('Azimuth')))")
        singler: \$(Rscript -e "cat(as.character(packageVersion('SingleR')))")
    END_VERSIONS
    """
}
