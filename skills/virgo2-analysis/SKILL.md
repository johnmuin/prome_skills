---
name: virgo2-analysis
description: Use the PROME lightweight VIRGO2 flow for vaginal microbiome gene mapping, compiled abundance matrices, taxonomy profiles, lineage tables, and optional annotation.
---

# VIRGO2 Analysis

Use this skill when the user wants to run or adapt the PROME VIRGO2 analysis flow.

## Bootstrap on a New Server

When deploying to a server that has never run this flow, work through these steps before creating a project config. Use preflight repeatedly — fix each [FAIL], re-run, repeat until clean.

### 1. Check conda availability

```bash
which conda || ls /path/to/miniconda3/etc/profile.d/conda.sh
```

### 2. Create the conda environment

VIRGO2 requires Python 3 with `pandas` and `numpy`:

```bash
conda create -n virgo2 python=3 pandas numpy
```

### 3. Install VIRGO2

```bash
# Clone or copy VIRGO2 to the server
git clone https://github.com/IGS/VIRGO2.git /path/to/VIRGO2
```

The installation must contain:
- `VIRGO2.py` (main script)
- `AccessoryScripts/merge_annotations.py` (needed for step5_annotate)

### 4. Create an environment profile

```bash
cp env_profiles/template.sh env_profiles/<server-name>.sh
```

Fill in `CONDA_BASE`, `CONDA_ENV_VIRGO2`, and `VIRGO2_DIR` with paths from steps 1-3.

### 5. Run preflight to validate

```bash
cd flows/virgo2
cp config_template.sh config.sh
# Edit config.sh: set PROJECT_DIR, INPUT_DIR, VIRGO2_OUTDIR, and source the env profile
bash preflight.sh config.sh
```

Fix every [FAIL] before proceeding.

## Workflow

1. Locate the flow under `flows/virgo2`.
2. Select an environment profile from `env_profiles/` or create one (see Bootstrap above).
3. Create or update a project config from `config_template.sh`.
4. Run `bash preflight.sh config.sh` to validate the environment.
5. Run steps in order:

```bash
bash step1_merge.sh config.sh
bash step2_map_parallel.sh config.sh
bash step3_compile.sh config.sh
bash step4_taxonomy.sh config.sh
bash step5_annotate.sh config.sh
```

Use `step2_map_local.sh` for small local runs and `step2_map_sge.sh` only when SGE submission is intended.

6. Use `bash status.sh config.sh` to check progress and `bash status.sh config.sh --json` for machine-readable output.

## Step Dependency Graph

```
INPUT_DIR (*.rmhost_R1.fastq.gz + R2)
 │
 ├── step1_merge ──> merged_reads/*.merged.fastq.gz
 │      │
 │      ▼
 ├── step2_map ──> map_results/*.out
 │      │
 │      ▼
 ├── step3_compile ──> compiled/VIRGO2_compiled.summary.NR.txt  [aggregate]
 │      │
 │      ▼
 ├── step4_taxonomy ──> taxonomy/VIRGO2_taxonomy.{relAbund,readCount}.csv  [aggregate]
 │      │
 │      ▼
 └── step5_annotate ──> annotation/VIRGO2_annotated_all_annotations.csv  [aggregate]
```

Steps 1-2 are per-sample and safe to re-run (existing outputs are skipped).
Steps 3-5 are aggregate — re-run after any upstream sample outputs change.

## Pre-Run Dependency Contract

- `VIRGO2_SCRIPT="${VIRGO2_DIR}/VIRGO2.py"` must exist.
- The conda environment must expose Python with `pandas` and `numpy`.
- `step2_map_parallel.sh` uses `MAP_THREADS * MAX_MAP_JOBS`; keep it within server limits.
- `step5_annotate.sh` expects `${VIRGO2_DIR}/AccessoryScripts/merge_annotations.py`.

## Human Commands

```bash
cd flows/virgo2
cp config_template.sh config.sh
vim config.sh
bash preflight.sh config.sh           # validate before compute
bash step1_merge.sh config.sh
bash step2_map_parallel.sh config.sh
bash step3_compile.sh config.sh
bash step4_taxonomy.sh config.sh
bash step5_annotate.sh config.sh
bash status.sh config.sh              # check progress
bash status.sh config.sh --json       # machine-readable status
```

## Important Checks

- `VIRGO2_SCRIPT="${VIRGO2_DIR}/VIRGO2.py"` must exist.
- The conda environment must expose the Python dependencies needed by VIRGO2.
- `step2_map_parallel.sh` uses `MAP_THREADS * MAX_MAP_JOBS`; keep it within server limits.
- `step5_annotate.sh` expects `${VIRGO2_DIR}/AccessoryScripts/merge_annotations.py`.

## Common Failure Patterns

See `docs/troubleshooting.md` for detailed diagnostics. Quick reference:

| Symptom | First Check |
|---------|-------------|
| VIRGO2.py not found | `ls "${VIRGO2_DIR}/VIRGO2.py"` |
| ImportError (pandas/numpy) | `python3 -c "import pandas; import numpy"` in conda env |
| Map step OOM | Reduce MAP_THREADS or MAX_MAP_JOBS |
| No merged reads | `ls "${VIRGO2_OUTDIR}/merged_reads/"*.merged.fastq.gz` |
| Map output empty | `cat "${VIRGO2_OUTDIR}/logs/<sample>.map.log"` |
| merge_annotations.py missing | Check `${VIRGO2_DIR}/AccessoryScripts/` |
| Taxonomy output empty | Verify compile step produced data |
| Low mapping rate | Check read quality; verify VIRGO2 reference matches sample type |

### Log Inspection

```bash
# Find all logs with errors
grep -liE '(error|fatal|exception|traceback|killed)' ${VIRGO2_OUTDIR}/logs/*.log

# Check a specific failed sample
cat ${VIRGO2_OUTDIR}/logs/<SAMPLE>.map.log
```

## Output Manifest

| Step | Directory | Key Output | Format |
|------|-----------|------------|--------|
| 1 | `${VIRGO2_OUTDIR}/merged_reads/` | `*.merged.fastq.gz` | gzipped FASTQ (merged paired reads) |
| 2 | `${VIRGO2_OUTDIR}/map_results/` | `*.out` | VIRGO2 mapping output |
| 3 | `${VIRGO2_OUTDIR}/compiled/` | `VIRGO2_compiled.summary.NR.txt` | Compiled abundance matrix |
| 4 | `${VIRGO2_OUTDIR}/taxonomy/` | `VIRGO2_taxonomy.relAbund.csv`, `VIRGO2_taxonomy.readCount.csv` | Relative abundance + read counts |
| 5 | `${VIRGO2_OUTDIR}/annotation/` | `VIRGO2_annotated_all_annotations.csv` | Functional annotations |
| - | `${VIRGO2_OUTDIR}/logs/` | `*.log` | Per-sample per-step logs |

## Resume After Failure

1. `bash status.sh config.sh` — identify which steps are partial
2. For per-sample steps (1-2): re-run the step script; completed samples are skipped
3. For aggregate steps (3-5): re-run after fixing upstream outputs
4. Delete individual sample outputs under `${VIRGO2_OUTDIR}` to force re-processing
