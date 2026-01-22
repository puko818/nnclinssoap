#######################################
## Runner script which runs proteomics, and generates log of execution
## and BioCompute object
#######################################
library(whirl)
options(whirl.wait_timeout = 50000)
options(whirl.track_files_discards = TRUE)

# Generate bco object while running scripts defined in _whirl.yml
write_biocompute(queue = run("whirl/_whirl_analysis.yml", track_files = FALSE), path = "R/BCO_analysis.json", pretty = TRUE)
