process PLOT_FEATURES {
    tag "$meta.id"
    label 'process_low'
    
    // Container specified in conf/containers.config
    
    input:
    tuple val(meta), path(rds)
    path(ch_genes)


    output:
    tuple val(meta), path("**.png"), emit: plots
    path "versions.yml", emit: versions

    script:
    """
    mkdir Feature_Plots
 
    # Run the R script with explicit output directory
    plot_features.r \\
    --inrds ${rds} \\
    --outdir Feature_Plots \\
    --sample_name $meta.id \\
    --feat_genes_file $ch_genes

    


    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        r-base: \$(R --version | grep "R version" | sed 's/R version //')
        seurat: \$(Rscript -e "cat(as.character(packageVersion('Seurat')))")
    END_VERSIONS
    """
}