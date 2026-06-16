# nnclinssoap — CLAUDE.md

Novo Nordisk Clinical Single-cell Spatial Omics Analytical Pipeline.
Pre-print: bioRxiv 2026.01.23.701261. Maintainers: ZS Associates & Novo Nordisk A/S.

---

## Repository structure

```
nnclinssoap/
├── docker/                   # Container definitions
│   ├── base/                 # NEW: shared base image (built first)
│   ├── preprocessing/        # scRNA-seq QC, doublets, batch correction
│   ├── analysis/             # Cell annotation, differential expression
│   ├── spatialxenium/        # Xenium spatial analysis
│   ├── qc-report/            # Python PDF generation
│   └── build_all_images.sh   # Builds base → preprocessing → analysis → spatialxenium → qc-report
├── containers/               # Built .sif files (not committed)
├── SpatialXenium/            # Nextflow pipeline (nf-core style)
│   ├── main.nf               # Entry point — runs SCRNASEQ then SPATIALXENIUM
│   ├── nextflow.config       # All params including new scrnaseq_* params
│   ├── workflows/
│   │   ├── spatialxenium.nf  # Original Xenium spatial workflow
│   │   └── scrnaseq.nf       # NEW: scRNA-seq workflow (wraps 4 modules)
│   ├── modules/local/
│   │   ├── seurat_xenium.nf  # Original
│   │   ├── label_transfer.nf # Original — now accepts annotated_rds from SCRNASEQ
│   │   ├── plot_features.nf  # Original
│   │   ├── qc_report.nf      # Original
│   │   ├── scrnaseq_preprocess.nf  # NEW: per-sample, parallel
│   │   ├── scrnaseq_integrate.nf   # NEW: multi-sample Harmony/RPCA
│   │   ├── scrnaseq_annotate.nf    # NEW: Azimuth or SingleR
│   │   └── scrnaseq_de.nf          # NEW: edgeR pseudo-bulk DE
│   ├── bin/
│   │   ├── Process_Individual_Xenium_Sample.r  # Original
│   │   ├── label_transfer.r                    # Original
│   │   ├── plot_features.r                     # Original
│   │   ├── generate_report.py                  # Original (called by QC_REPORT process)
│   │   ├── scrnaseq_preprocess_sample.R  # NEW: per-sample preprocessing
│   │   ├── scrnaseq_integrate_samples.R  # NEW: integration
│   │   ├── scrnaseq_annotate.R           # NEW: annotation
│   │   └── scrnaseq_de.R                 # NEW: differential expression
│   └── conf/
│       ├── containers.config  # Updated: includes scrnaseq process→container mappings
│       └── ...
├── scrnaseq/                 # Original whirl-based R pipeline (kept for reference)
│   ├── R/                    # Original R scripts (unchanged)
│   ├── whirl/                # whirl orchestration (unchanged)
│   └── configs/              # YAML configs (unchanged)
└── tests/
```

---

## Docker architecture

### Key decision: shared base image

All three R containers share ~150 lines of identical system deps and R packages. A `scrnaseq-base` image was introduced to eliminate this duplication.

**Build order** (enforced by `build_all_images.sh`):
```
scrnaseq-base → preprocessing
             → analysis
             → spatialxenium
qc-report (independent)
```

**What lives in each layer:**

| Image | FROM | Unique additions |
|---|---|---|
| `scrnaseq-base:4.5.2` | `rocker/r-ver:4.5.2` | System deps (superset), Seurat, tidyverse, Bioconductor core, HDF5 |
| `scrnaseq-preprocessing:4.5.2` | `scrnaseq-base:4.5.2` | SoupX, scDblFinder, harmony, DropletUtils, org.Hs.eg.db, whirl |
| `scrnaseq-analysis:4.5.2` | `scrnaseq-base:4.5.2` | Azimuth, SingleR, edgeR, Signac, pbmcref, whirl |
| `scrnaseq-spatialxenium:4.5.2` | `scrnaseq-base:4.5.2` | argparser, arrow, spatstat.*, presto (GitHub), shiny, plotly |
| `qc-report:1.0` | `python:3.11-slim` | fpdf2, procps |

### Apptainer .def files

The `.def` files are **thin wrappers** — they use `Bootstrap: docker-daemon` to convert the already-built Docker image to `.sif`. Docker is the single source of truth for package content. This prevents the drift that existed previously (analysis `.def` was missing pbmcref; spatialxenium `.def` was missing scattermore/fastDummies).

```def
Bootstrap: docker-daemon
From: nnclinssoap/scrnaseq-preprocessing:4.5.2
# No %post section — the Docker image is complete
```

The base `docker/base/apptainer.def` still uses `Bootstrap: docker` (Docker Hub) since it has no local parent.

### pbmcref download fix (analysis container)

Previously the download was on line 46 (early in the file, cache-busted by any upstream change) and the `.tar.gz` was left in the image layer. Fixed to download, install, and clean up in a single `RUN`:

```dockerfile
RUN wget -q https://seurat.nygenome.org/src/contrib/pbmcref.SeuratData_1.0.0.tar.gz && \
    Rscript -e "install.packages('pbmcref.SeuratData_1.0.0.tar.gz', repos=NULL, type='source')" && \
    rm pbmcref.SeuratData_1.0.0.tar.gz
```

### Quarto removal

Quarto was installed in preprocessing and analysis containers but never used (scripts generate PDFs directly via `pdf()`/fpdf2). Removed from both.

### Binary-package build (build-time: ~4h → ~6min)

The Dockerfiles install **precompiled binaries** instead of compiling from source. The original `repos='https://cloud.r-project.org/'` served source-only on Linux, so ~319 packages compiled from source (the base alone took ~4h; the `devtools` layer alone was ~2.4h). Now:

- **CRAN → Posit P3M binary repo**, pinned: `https://packagemanager.posit.co/cran/__linux__/noble/<CRAN_DATE>`. Pinned date = reproducible *and* binary.
- **Bioconductor → P3M's Bioc mirror** (`.../bioconductor/__linux__/noble/packages/3.22/bioc` + `data/annotation` + `data/experiment`). P3M has **no** Bioc Linux binaries, so these ~32 packages still compile from source — but fast (~3min under parallel make) and, critically, **redirect-free**.
- **Do NOT use `BiocManager::install` or bioconductor.org directly.** bioconductor.org's `BioCsoft` index 302-redirects to a mirror that **hangs >90s per request** from some networks — it stalled a full build for 2h. All Dockerfiles set the P3M repos globally in `Rprofile.site` and use `install.packages` only.
- `dependencies=TRUE` was dropped (it pulled the unused `Suggests` tree). Verified no runtime `library()` relies on a Suggests-only package.
- `UBUNTU_CODENAME` (noble) must match the base image's Ubuntu release or P3M serves ABI-incompatible binaries — the base Dockerfile asserts this and fails fast.
- `docker/base/apptainer.def` mirrors this (it is **not** a thin wrapper — keep its `%post` in sync with the Dockerfile).

**presto gotcha (spatialxenium):** presto 1.0.0 declares `CXX_STD=CXX11`, but the newer binary RcppArmadillo 15.x requires C++14+. The Dockerfile raises `CXX11STD=-std=gnu++17` in `Makevars.site` before installing presto, and guards the install with a `stop()` (because `install.packages`/`install_github` only **warn** on compile failure, which would otherwise ship a broken image silently).

### build script exit-code bugs (fixed)

`build_all_images.sh` / `build_single.sh` used `docker images <repo:tag> | grep <repo:tag>` to verify a build — which **never matches** (the listing prints repo and tag in separate columns), so successful builds were reported FAILED and `VERSION_MANIFEST.txt` showed all ❌ even when images built fine. Fixed to use `docker image inspect`, `${PIPESTATUS[0]}` (not `$?` after a `| tee`), and a `BUILD_TYPE`-aware manifest check (Docker mode has no `.sif` files).

---

## Nextflow / scRNA-seq integration

### Why the integration was done

The `scrnaseq/` whirl pipeline and `SpatialXenium/` Nextflow pipeline were originally independent. The intended data flow was:

```
scrnaseq → annotated .rds → SpatialXenium LABEL_TRANSFER
```

But this handoff was manual. The integration makes it automatic when `--scrnaseq_input` is provided.

### Key design decisions

**CLI args via `commandArgs(trailingOnly=TRUE)` instead of optparse/argparse**
The containers have no guarantee that `optparse` or `argparse` are installed. Base R's `commandArgs` requires no packages. A simple named-arg parser (`--key value`) is inlined in each script.

**New R scripts in `SpatialXenium/bin/`, not `scrnaseq/R/`**
Nextflow automatically stages everything in `bin/` into each process work directory. Scripts in `bin/` are called directly by name. The original `scrnaseq/R/` scripts are kept unchanged for reference.

**`scrnaseq/R/` originals are untouched**
The whirl-based versions remain as-is. The new `SpatialXenium/bin/scrnaseq_*.R` scripts are the Nextflow-adapted versions with CLI args.

**BCO compliance via nf-prov, not whirl**
The `whirl::write_biocompute()` function generated IEEE 2791 BCOs. Nextflow's `nf-prov` plugin (already configured in `nextflow.config`) generates equivalent IEEE 2791 BCOs in `pipeline_info/bco.json`. No downstream tooling depends on the whirl BCO format specifically.

**preprocessing container used for both PREPROCESS and INTEGRATE**
Both steps use harmony/RPCA which live in the preprocessing container. The analysis container is only for annotation and DE.

### Workflow wiring

`main.nf` now imports both workflows. When `--scrnaseq_input` is set:

```
scrnaseq samplesheet (TSV)
    → SCRNASEQ_PREPROCESS (per sample, parallel, preprocessing container)
    → SCRNASEQ_INTEGRATE  (collected, preprocessing container)
    → SCRNASEQ_ANNOTATE   (analysis container)
    → SCRNASEQ_DE         (analysis container)
    → annotated_rds
        → LABEL_TRANSFER  (spatialxenium container)
```

When `--scrnaseq_input` is not set, `--reference_rds` works as before (manual handoff).

### Channel wiring details (important for future edits)

**TSV parsing** — `main.nf` uses `splitCsv(header:true, sep:'\t')` to parse the scrnaseq samplesheet into `[ meta, sample_path ]` tuples. `meta` is a map with keys: `id`, `participant`, `visit`, `arm`, `sex`, `age`. The `filepath` column must point to the **directory** containing the matrix file (not the file itself).

**Value channel for LABEL_TRANSFER** — `SCRNASEQ_ANNOTATE` emits a single `path` (queue channel). It is converted to a value channel with `.first()` before being passed to `SPATIALXENIUM`, so it broadcasts to every xenium sample rather than zipping with only the first.

**Channel-driven LABEL_TRANSFER** — `spatialxenium.nf` no longer guards `LABEL_TRANSFER` with `if(params.reference_rds)`. It always calls `LABEL_TRANSFER(ch_xenium_rds, ch_reference_rds)`. The process simply doesn't run when `ch_reference_rds` is `Channel.empty()`.

**`if/else` instead of ternary for workflow calls** — Nextflow DSL2 workflow calls must be in `if/else` blocks, not ternary expressions. `main.nf` uses `if (params.scrnaseq_input) { SCRNASEQ(...) ... } else { ... }` for this reason.

### Bugs fixed in bin/ scrnaseq scripts

**`scrnaseq_annotate.R` — variable scoping**
The original `scrnaseq/R/cell_annotation.R` referenced `df` and `cell_count` outside their defining `if (annotation_method == "Azimuth")` block. This caused a crash when `annotation_method == "SingleR"`. Fixed by scoping both variables inside their respective branches.

**All four `scrnaseq_*.R` scripts — systematic dropped-`r` corruption**
All four new bin/ scripts (`scrnaseq_preprocess_sample.R`, `scrnaseq_integrate_samples.R`, `scrnaseq_annotate.R`, `scrnaseq_de.R`) contained ~40–60 instances of the letter `r` dropped from identifiers, function calls, and string literals (e.g. `pase_args`, `NomalizeData`, `di.create`, `tidy::` instead of `tidyr::`). All four were fully rewritten on 2026-06-11 using `scrnaseq/R/` originals as reference. If these scripts are ever regenerated from an external source, scan for `pase_args` / `pint(` / `di.create` before running.

**`scrnaseq_preprocess_sample.R` — doublet subset**
`subset(s, idents = "singlet")` fails unless `Idents(s) <- s$scDblFinder.class` is called first, because the active identity after `FindClusters` is cluster numbers, not doublet class.

**`scrnaseq_de.R` — missing libraries**
Requires `library(tidyr)` (for `pivot_longer`/`separate`) and `library(cowplot)` — both must be present in the `scrnaseq-analysis` container.

---

## Running the pipeline

### Spatial only (original behaviour)
```bash
cd SpatialXenium
nextflow run main.nf \
  --input samplesheet.csv \
  --outdir results \
  -profile singularity
```

### Integrated scRNA-seq + Spatial
```bash
cd SpatialXenium
nextflow run main.nf \
  --input xenium_samplesheet.csv \
  --scrnaseq_input ../scrnaseq/configs/read_samples.txt \
  --outdir results \
  -profile singularity
```

### Test run (Mode 2) with Docker
```bash
cd SpatialXenium
nextflow run main.nf \
  -profile test,docker \
  --scrnaseq_input ../scrnaseq/configs/read_samples.txt \
  --input_type h5_filtered \
  --outdir test_results_mode2
```

The test Xenium data is at `SpatialXenium/test_data/`. The test scrnaseq data is at `scrnaseq/test_data/donor{1,2,3,4}/sample_filtered_feature_bc_matrix.h5`. The `read_samples.txt` references these as `test_data/donor{1..4}` (relative paths from `scrnaseq/` dir) — use absolute paths when running from `SpatialXenium/`.

### scrnaseq samplesheet format
Tab-separated with these exact column names (order matters):
```
key	filepath	participant	visit	arm	sex	age
donor01-bl	test_data/donor1	donor01	bl	placebo	M	68
```

`filepath` is a **directory** — the R script appends `sample_filtered_feature_bc_matrix.h5` (h5_filtered mode) or `sample_filtered_feature_bc_matrix/` (mtx mode) to it.

**Path resolution:** `filepath` can be absolute or relative. Relative paths are resolved relative to the samplesheet file's own directory (not the Nextflow launch directory). The `scrnaseq/configs/read_samples.txt` test samplesheet uses `test_data/donor1` etc., which correctly resolves to `scrnaseq/test_data/donor1` since the samplesheet lives in `scrnaseq/configs/`.

### Key params (new scrnaseq params in nextflow.config)

| Param | Default | Description |
|---|---|---|
| `scrnaseq_input` | `null` | Path to scrnaseq TSV samplesheet. If null, scrnaseq workflow is skipped. |
| `input_type` | `h5_filtered` | Matrix format: `mtx`, `h5_filtered`, `h5_raw_filtered` |
| `integration_method` | `harmony` | `harmony` or `rpca` |
| `annotation_method` | `Azimuth` | `Azimuth` or `SingleR` |
| `azimuth_ref` | `pbmcref` | Azimuth reference (must be installed in container) |
| `singler_ref` | `dice` | celldex reference name |
| `de_annotation` | `predicted.celltype.l1` | Seurat metadata column used for DE grouping |
| `genes_of_interest` | `null` | Comma-separated gene symbols for QC feature plots |
| `n_features_max` | `5000` | Upper nFeature_RNA filter |
| `n_features_min` | `500` | Lower nFeature_RNA filter |
| `percent_mt_cutoff` | `10` | Max mitochondrial % |
| `cluster_resolution` | `0.6` | Louvain resolution |

---

## Building containers

```bash
cd docker
./build_all_images.sh         # Docker mode (builds all 5 images)
./build_all_images.sh -v singularity  # Apptainer mode
```

Base image must exist before derived images. The script handles this automatically by building `base` first.

To build a single container:
```bash
./build_single.sh base
./build_single.sh preprocessing
```

---

## Container runtime notes

- **Docker** is the primary build path. All package logic lives in Dockerfiles.
- **Apptainer/Singularity** `.def` files are thin wrappers (`Bootstrap: docker-daemon`) — they convert the Docker image to `.sif` without re-executing package installs.
- Building `.sif` files from `.def` requires Docker daemon to be running alongside Apptainer.
- Pre-built `.sif` files live in `containers/` and are not committed to git.

---

## Nextflow resource overrides

Per-process CPU/memory overrides live in a top-level `process` block in `nextflow.config` (lines ~86–92), applied after `base.config` is loaded and before the `profiles` block. This takes priority over the label defaults in `conf/base.config`.

```groovy
process {
    withName: 'SCRNASEQ_INTEGRATE' {
        cpus   = 4
        memory = 8.GB
    }
}
```

The `SCRNASEQ_INTEGRATE` process has `label 'process_high'` (12 CPUs / 16 GB by default) but integration is memory-bound not CPU-bound — tune `memory` up and `cpus` down for large datasets. The `(n=8)` in the Nextflow task name is the number of input samples (from the `tag` directive), not the CPU count.

`SCRNASEQ_DE` uses `label 'process_high_memory'` (16 GB first attempt). It was `process_medium` (8 GB), which OOM-killed the first attempt on the test data (edgeR pseudo-bulk peaks ~11 GB) and wasted a retry. If you see DE fail with exit 137 (`Killed`), it's memory — bump the label, not a code bug.

Use `-resume` on re-runs to skip successfully completed tasks. Without `-resume` Nextflow starts from scratch. Cannot be added retroactively to an already-running job.

---

## Developer environment (Windows)

Java is installed via SDKMAN at `~/.sdkman/candidates/java/current`. It may not be on `PATH` in all shells. If `nextflow` complains about Java:

```bash
export JAVA_HOME="$HOME/.sdkman/candidates/java/current"
export PATH="$JAVA_HOME/bin:$PATH"
nextflow -version
```

Nextflow binary is at `~/bin/nextflow`. Docker Desktop is installed and running (version 29.5.2). All 5 pipeline images are built and available locally:
- `nnclinssoap/scrnaseq-base:4.5.2`
- `nnclinssoap/scrnaseq-preprocessing:4.5.2`
- `nnclinssoap/scrnaseq-analysis:4.5.2`
- `nnclinssoap/scrnaseq-spatialxenium:4.5.2`
- `nnclinssoap/qc-report:1.0`
