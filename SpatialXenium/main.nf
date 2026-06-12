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

        SCRNASEQ(ch_scrnaseq)
        // Convert to value channel so it broadcasts to every xenium sample in LABEL_TRANSFER
        ch_reference_rds = SCRNASEQ.out.annotated_rds.first()
    } else {
        ch_reference_rds = params.reference_rds
            ? Channel.value(file(params.reference_rds, checkIfExists: true))
            : Channel.empty()
    }

    SPATIALXENIUM(samplesheet, ch_reference_rds)

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
