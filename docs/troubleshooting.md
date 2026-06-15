# Troubleshooting Guide

Common failure patterns and diagnostic commands for PROME lightweight flows.

## Kraken2 Flow

### Pre-run checks

Before running the workflow, always execute preflight:

```bash
bash preflight.sh config.sh
```

### Symptom → Cause → Fix

| Symptom | Likely Cause | Diagnostic | Fix |
|---------|-------------|------------|-----|
| `[FATAL] 缺工具 kraken2` | conda env not activated or missing package | `ls "${CONDA_BASE}/envs/${CONDA_ENV}/bin/kraken2"` | `conda install -c bioconda kraken2=2.1.2` |
| `[FATAL] 找不到 hash.k2d` | Wrong KRAKEN2_DB path or incomplete DB | `ls "${KRAKEN2_DB}"/hash.k2d` | Verify DB path; re-download if incomplete |
| `bracken: invalid kmer distribution` | BRACKEN_READ_LEN doesn't match any DB file | `ls "${KRAKEN2_DB}"/database*mers.kmer_distrib` | Set BRACKEN_READ_LEN to match an available file |
| Kraken2 runs out of memory | DB too large for available RAM | `du -sh "${KRAKEN2_DB}"` | Reduce THREADS, use `KRAKEN2_USE_MM=1`, or increase memory |
| Empty/missing `.kreport2` | Kraken2 crashed mid-run | `cat "${OUTDIR}/logs/${sample}.kraken2.log"` | Check for OOM, disk full, or corrupted input FASTQ |
| `[FATAL] KrakenTools 目录不存在` | KRAKEN_TOOLS_DIR not set up | `ls "${KRAKEN_TOOLS_DIR}/kreport2mpa.py"` | `git clone https://github.com/jenniferlu717/KrakenTools` and set path |
| Empty `.mpa` output | kreport2mpa failed silently | `cat "${OUTDIR}/logs/${sample}.kreport2mpa.log"` | Check kreport2 has expected column format |
| `seqkit: command not found` | seqkit not installed in conda env | `conda list -n "${CONDA_ENV}" \| grep seqkit` | `conda install -c bioconda seqkit` |
| Unclassified rate >90% | Wrong database for sample type | `head -20 "${OUTDIR}/kraken2/${sample}.kreport2"` | Verify KRAKEN2_DB matches expected sample origin |
| TRIM_LEN/BRACKEN_READ_LEN mismatch | Config inconsistency | preflight.sh will warn | Set TRIM_LEN = BRACKEN_READ_LEN |

### Step-specific log inspection

```bash
# Find all log files with errors
grep -liE '(error|fatal|exception|killed)' ${OUTDIR}/logs/*.log

# Check a specific failed sample across all steps
sample="SAMPLE_NAME"
for log in ${OUTDIR}/logs/${sample}.*.log; do
    echo "=== $(basename $log) ==="
    tail -20 "$log"
done

# View kraken2 classification rates
grep 'classified' ${OUTDIR}/logs/*.kraken2.log
```

### Resume checklist

1. Run `bash status.sh config.sh` to see which steps have partial output
2. The step scripts skip completed samples automatically — safe to re-run
3. If a step failed for specific samples, check those samples' log files first
4. If you need to re-run from scratch for a sample, delete its output files under `${OUTDIR}` and re-run

## VIRGO2 Flow

### Pre-run checks

```bash
bash preflight.sh config.sh
```

### Symptom → Cause → Fix

| Symptom | Likely Cause | Diagnostic | Fix |
|---------|-------------|------------|-----|
| `VIRGO2.py not found` | Wrong VIRGO2_DIR | `ls "${VIRGO2_DIR}/VIRGO2.py"` | Verify VIRGO2 installation path |
| `ImportError: No module named pandas` | Python deps missing in conda env | `python3 -c "import pandas; import numpy"` | `conda install pandas numpy` |
| Map step OOM | MAP_THREADS or memory too high | `dmesg \| grep -i oom` | Reduce MAP_THREADS or MAX_MAP_JOBS |
| `No merged reads found` | step1_merge didn't run or failed | `ls "${VIRGO2_OUTDIR}/merged_reads/"*.merged.fastq.gz` | Re-run step1_merge.sh |
| Map output `.out` file empty or missing | VIRGO2 map failed | `cat "${VIRGO2_OUTDIR}/logs/${sample}.map.log"` | Check for Python traceback or memory errors |
| `merge_annotations.py not found` | VIRGO2 AccessoryScripts not installed | `ls "${VIRGO2_DIR}/AccessoryScripts/merge_annotations.py"` | Ensure VIRGO2 installation includes AccessoryScripts |
| Taxonomy output empty | compile step produced no data | `wc -l "${VIRGO2_OUTDIR}/compiled/VIRGO2_compiled.summary.NR.txt"` | Check map results had sufficient coverage |
| `Error: Input dir not found` | INPUT_DIR incorrect or NFS issue | `ls "${INPUT_DIR}"` | Verify path and mount |
| Low mapping rate | Wrong reference or poor quality reads | `grep 'mapped' "${VIRGO2_OUTDIR}/logs/"*.map.log` | Check read quality, consider re-trimming |

### Step-specific log inspection

```bash
# Find all log files with errors
grep -liE '(error|fatal|exception|traceback|killed)' ${VIRGO2_OUTDIR}/logs/*.log

# Check a specific failed sample
sample="SAMPLE_NAME"
cat "${VIRGO2_OUTDIR}/logs/${sample}.map.log"
```

### Resume checklist

1. Run `bash status.sh config.sh` to see workflow progress
2. step1_merge and step2_map are per-sample — re-running them is safe
3. step3_compile through step5_annotate are aggregate steps — re-run if upstream outputs changed
4. Delete individual sample outputs under `${VIRGO2_OUTDIR}` to force re-processing

## General

### Disk space

```bash
# Check available space on output volume
df -h "$(dirname "${OUTDIR:-${VIRGO2_OUTDIR}}")"
```

### NFS / network filesystem issues

Both pg-xujm reference databases and input data may be on NFS mounts. If tools hang or report I/O errors:

```bash
# Check mount status
mount | grep -E '(pynas0|data10)'
ls "${KRAKEN2_DB}/hash.k2d"  # quick liveness check
```

### Getting help from logs

When reporting issues, include:
- The config file (with paths redacted if needed)
- The preflight output: `bash preflight.sh config.sh`
- The status output: `bash status.sh config.sh`
- Relevant per-sample log files from `${OUTDIR}/logs/`
