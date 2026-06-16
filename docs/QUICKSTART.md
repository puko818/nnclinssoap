# Quick Start - SpatialXenium Testing

**One-page reference for testing the pipeline**

## Prerequisites Check
```bash
./docker/check_build_prerequisites.sh
```

## Step 1: Build Containers (~20 min)
```bash
cd docker
sbatch build_all_images.sh
# Or: bash build_all_images.sh

# Monitor
tail -f logs/build_*.log
```

## Step 2: Download Test Data (~15-30 minutes)
```bash
./setup_test_data.sh

# Verify
./test_spatialxenium_quick.sh
```

## Step 3: Run Pipeline (~1.5-3 hours)
```bash
cd SpatialXenium

# Test run
nextflow run main.nf -profile test,singularity --outdir test_results -resume
```

## Step 4: Check Results
```bash
# List outputs
ls -lh test_results/*/seurat_xenium/*.rds

# View reports
firefox test_results/pipeline_info/execution_report.html
```

---

## Troubleshooting

**Container not found?**
```bash
ls containers/*.sif
cd docker && bash build_all_images.sh
```

**Data missing?**
```bash
./setup_test_data.sh
find test_data/ -name "*.tar.gz"  # Should be empty
```

**Pipeline fails?**
```bash
# Check logs
tail SpatialXenium/.nextflow.log

# Retry with resume
nextflow run main.nf -profile test,singularity -resume
```

---

## File Locations

| Item | Path |
|------|------|
| Containers | `containers/*.sif` |
| Test data | `test_data/Xenium_V1_*` |
| Pipeline | `SpatialXenium/` |
| Results | `test_results/` |
| Logs | `logs/` and `docker/logs/` |

---

## Expected Timeline

1. **Container build:** ~20 min (one-time, binary-package build)
2. **Data download:** 15-30 minutes (one-time, ~6 GB)
3. **Pipeline run:** 1.5-3 hours (per test run)
4. **Total first run:** ~2-4 hours
5. **Subsequent runs:** ~2 hours (with `-resume`)

---

## Validation Checklist

- [ ] 3 .sif files in `containers/`
- [ ] 2 datasets in `test_data/`
- [ ] No .tar.gz in test_data/ (all extracted)
- [ ] Pipeline completes with [100%] 4 of 4 ✔
- [ ] .rds files in test_results/
- [ ] QC plots (.png) generated

---

## Full Documentation

See `TESTING_GUIDE.md` for complete details, troubleshooting, and advanced usage.
