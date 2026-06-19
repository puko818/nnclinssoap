#!/usr/bin/env nextflow
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    nf-core/spatialxenium
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Github : https://github.com/nf-core/spatialxenium
    Website: https://nf-co.re/spatialxenium
    Slack  : https://nfcore.slack.com/channels/spatialxenium
----------------------------------------------------------------------------------------
*/

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT FUNCTIONS / MODULES / SUBWORKFLOWS / WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { SPATIALXENIUM  } from './workflows/spatialxenium'
include { SCRNASEQ       } from './workflows/scrnaseq'
include { PIPELINE_INITIALISATION } from './subworkflows/local/utils_nfcore_spatialxenium_pipeline'
include { PIPELINE_COMPLETION     } from './subworkflows/local/utils_nfcore_spatialxenium_pipeline'
//include { getGenomeAttribute      } from './subworkflows/local/utils_nfcore_spatialxenium_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    GENOME PARAMETER VALUES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// TODO nf-core: Remove this line if you don't need a FASTA file
//   This is an example of how to use getGenomeAttribute() to fetch parameters


/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    NAMED WORKFLOWS FOR PIPELINE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// WORKFLOW: Run main analysis pipeline depending on type of input
//
workflow NFCORE_SPATIALXENIUM {

    take:
    samplesheet // channel: samplesheet read in from --input

    main:

    // Resolve label column and DE annotation column.
    // In integrated mode (scrnaseq_input set), the reference RDS is always produced by the pipeline so column names are fixed by annotation_method -> predicted.celltype.* for azimuth and main_labels for SingleR
    def label_col = params.single_cell_label_col
    def de_annotation_col = params.de_annotation
    if (params.scrnaseq_input) {
        if (params.annotation_method == 'Azimuth') {
            // Azimuth emits predicted.celltype.l1/l2/l3. Honour an explicit predicted.celltype.*
            // choice (e.g. --single_cell_label_col predicted.celltype.l2 for label transfer),
            // otherwise auto-default to l1. DE likewise honours --de_annotation (default l1).
            label_col         = params.single_cell_label_col?.startsWith('predicted.celltype.') ? params.single_cell_label_col : 'predicted.celltype.l1'
            de_annotation_col = params.de_annotation
        } else {
            // SingleR only emits 'main_labels'; predicted.celltype.* is not available.
            label_col         = 'main_labels'
            de_annotation_col = 'main_labels'
        }
    }
    // presence of this parameter activates the now built-in scRNAseq part of the workflow
    if (params.scrnaseq_input) {
        // Parse the tab-separated scrnaseq samplesheet into [ meta, sample_path ] tuples
        ch_scrnaseq = Channel
            .fromPath(params.scrnaseq_input, checkIfExists: true)
            .splitCsv(header: true, sep: '\t')
            .map { row ->
                def meta = [
                    id:          row.key,
                    participant: row.participant,
                    visit:       row.visit,
                    arm:         row.arm,
                    sex:         row.sex,
                    age:         row.age
                ]
                def samplesheet_dir = file(params.scrnaseq_input).parent
                def fp = row.filepath.startsWith('/') \
                    ? file(row.filepath, checkIfExists: true) \
                    : file("${samplesheet_dir}/${row.filepath}", checkIfExists: true)
                [ meta, fp ]
            }

        SCRNASEQ(ch_scrnaseq, de_annotation_col)
        // Convert to value channel so it broadcasts to every xenium sample in LABEL_TRANSFER
        ch_reference_rds = SCRNASEQ.out.annotated_rds.first()
    } else {
        ch_reference_rds = params.reference_rds
            ? Channel.value(file(params.reference_rds, checkIfExists: true))
            : Channel.empty()
    }

    SPATIALXENIUM(samplesheet, ch_reference_rds, label_col)

    emit:
    multiqc_report = SPATIALXENIUM.out.multiqc_report
}
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow {

    main:
    //
    // SUBWORKFLOW: Run initialisation tasks
    //
    PIPELINE_INITIALISATION (
        params.version,
        params.validate_params,
        params.monochrome_logs,
        args,
        params.outdir,
        params.input
    )

    //
    // WORKFLOW: Run main workflow
    //
    NFCORE_SPATIALXENIUM (
        PIPELINE_INITIALISATION.out.samplesheet
    )
    //
    // SUBWORKFLOW: Run completion tasks
    //
    PIPELINE_COMPLETION (
        params.email,
        params.email_on_fail,
        params.plaintext_email,
        params.outdir,
        params.monochrome_logs,
        params.hook_url,
        NFCORE_SPATIALXENIUM.out.multiqc_report
    )
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
