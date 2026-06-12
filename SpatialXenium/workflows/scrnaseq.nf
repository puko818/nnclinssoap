include { SCRNASEQ_PREPROCESS } from '../modules/local/scrnaseq_preprocess'
include { SCRNASEQ_INTEGRATE  } from '../modules/local/scrnaseq_integrate'
include { SCRNASEQ_ANNOTATE   } from '../modules/local/scrnaseq_annotate'
include { SCRNASEQ_DE         } from '../modules/local/scrnaseq_de'

workflow SCRNASEQ {
    take:
    samplesheet  // channel: [ [meta], sample_path ]
                 // meta must contain: id, participant, visit, arm, sex, age

    main:

    // 1. Per-sample preprocessing — runs in parallel across all samples
    SCRNASEQ_PREPROCESS(samplesheet)

    // 2. Collect all per-sample RDS files and integrate
    rds_collected     = SCRNASEQ_PREPROCESS.out.rds.map { meta, rds -> rds }.collect()
    ids_collected     = SCRNASEQ_PREPROCESS.out.rds.map { meta, rds -> meta.id }.collect()

    SCRNASEQ_INTEGRATE(rds_collected, ids_collected)

    // 3. Cell type annotation
    SCRNASEQ_ANNOTATE(SCRNASEQ_INTEGRATE.out.rds)

    // 4. Differential expression
    SCRNASEQ_DE(SCRNASEQ_ANNOTATE.out.rds)

    emit:
    // Annotated RDS is the key output — fed into SpatialXenium LABEL_TRANSFER
    annotated_rds = SCRNASEQ_ANNOTATE.out.rds
    de_summary    = SCRNASEQ_DE.out.summary
}
