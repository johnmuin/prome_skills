---
name: virgo2-analysis
description: Use the PROME lightweight VIRGO2 flow for vaginal microbiome gene mapping, compiled abundance matrices, taxonomy profiles, lineage tables, and optional annotation.
---

# VIRGO2 Analysis

Use this skill when the user wants to run or adapt the PROME VIRGO2 analysis flow.

## Workflow

1. Locate the flow under `flows/virgo2`.
2. Create or update a project config from `config_template.sh`.
3. Confirm key environment values: `VIRGO2_DIR`, `CONDA_BASE`, `CONDA_ENV`, `INPUT_DIR`, and `VIRGO2_OUTDIR`.
4. Check inputs under `INPUT_DIR` using the expected `*.rmhost_R1.fastq.gz` and `*.rmhost_R2.fastq.gz` naming.
5. Run steps in order:

```bash
bash step1_merge.sh config.sh
bash step2_map_parallel.sh config.sh
bash step3_compile.sh config.sh
bash step4_taxonomy.sh config.sh
bash step5_annotate.sh config.sh
```

Use `step2_map_local.sh` for small local runs and `step2_map_sge.sh` only when SGE submission is intended.

## Important Checks

- `VIRGO2_SCRIPT="${VIRGO2_DIR}/VIRGO2.py"` must exist.
- The conda environment must expose the Python dependencies needed by VIRGO2.
- `step2_map_parallel.sh` uses `MAP_THREADS * MAX_MAP_JOBS`; keep it within server limits.
- `step5_annotate.sh` expects `${VIRGO2_DIR}/AccessoryScripts/merge_annotations.py`.

## Outputs

Primary outputs are:

- `${VIRGO2_OUTDIR}/merged_reads/*.merged.fastq.gz`
- `${VIRGO2_OUTDIR}/map_results/*.out`
- `${VIRGO2_OUTDIR}/compiled/VIRGO2_compiled.summary.NR.txt`
- `${VIRGO2_OUTDIR}/taxonomy/VIRGO2_taxonomy.relAbund.csv`
- `${VIRGO2_OUTDIR}/taxonomy/VIRGO2_taxonomy.readCount.csv`
- `${VIRGO2_OUTDIR}/annotation/VIRGO2_annotated_all_annotations.csv`

