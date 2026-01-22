process QC_REPORT {

    // Container specified in conf/containers.config
    // Uses qc-report_1.0.sif (Python 3.11 + fpdf2)
    
    // Define the input: meta info and a path to the plots directory
    input:
    path(qc_plots_to_report)

    // Define the output: the report in PDF format
    output:
    path "QC_report.pdf"

    // Define the script that generates the report
    script:
    """
    generate_report.py --plots ${qc_plots_to_report} --output QC_report.pdf
    """
}
