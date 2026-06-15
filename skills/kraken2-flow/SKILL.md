---
name: kraken2-flow
description: Use the PROME lightweight Kraken2 flow for paired metagenomic reads: configure server-specific conda/reference paths, run Kraken2, Bracken, kreport2mpa, mpa2levels, combine outputs, and diagnose logs.
---

# Kraken2 Flow

Use this skill when the user wants to run or adapt the PROME Kraken2 classification flow.

## Bootstrap on a New Server

When deploying to a server that has never run this flow before, work through these steps before creating a project config. Use preflight repeatedly — fix each [FAIL], re-run, repeat until clean.

### 1. Check conda availability

```bash
which conda || ls /path/to/miniconda3/etc/profile.d/conda.sh
```

If conda is not installed, install Miniconda3 first.

### 2. Create the conda environment

```bash
conda create -n kraken2.1.2 -c bioconda kraken2=2.1.2 bracken=2.7 seqkit python=3
```

If the server has no network access, clone from an existing env on a reachable server:
```bash
conda create -n kraken2.1.2 --clone /path/to/existing/env
```

### 3. Obtain or locate the Kraken2 database

The database must contain `hash.k2d`, `taxo.k2d`, `opts.k2d`, and `database*<N>mers.kmer_distrib`. Either:
- Point to an existing DB on a shared filesystem
- Download from a Kraken2 DB source (e.g. `kraken2-build --standard --db $DB_PATH`)
- Copy from another server

Run preflight to verify: `bash preflight.sh config.sh` will check every required file.

### 4. Choose the correct read length

**Do this before running step0 (trim) — picking the wrong length will break Bracken.**

```bash
ls "${KRAKEN2_DB}"/database*mers.kmer_distrib
# Example output:
#   database100mers.kmer_distrib  database150mers.kmer_distrib  database250mers.kmer_distrib
```

Set `BRACKEN_READ_LEN` to match one of these (e.g., 150 for `database150mers.kmer_distrib`). Set `TRIM_LEN` to the same value.

### 5. Clone KrakenTools

```bash
git clone https://github.com/jenniferlu717/KrakenTools.git /path/to/KrakenTools
```

Must contain `kreport2mpa.py` and `combine_mpa.py`.

### 6. Create an environment profile

```bash
cp env_profiles/template.sh env_profiles/<server-name>.sh
```

Fill in the absolute paths discovered in steps 1-4. This profile is shared across all projects on this server.

### 7. Run preflight to validate

```bash
cd flows/kraken2
cp config_template.sh config.sh
# Edit config.sh: set PROJECT_DIR, INPUT_DIR, OUTDIR, and source the env profile
bash preflight.sh config.sh
```

Fix every [FAIL] before proceeding. [WARN] items are advisory but should be reviewed.

## Workflow

1. Locate the flow under `flows/kraken2`.
2. Select an environment profile from `env_profiles/` or create one (see Bootstrap above).
3. Create or update a project config from `config_template.sh`.
4. Run `bash preflight.sh config.sh` to validate the environment.
5. Run the complete workflow with `bash run_all.sh config.sh`, or individual steps if resuming.
6. Use `bash status.sh config.sh` to check progress and `bash status.sh config.sh --json` for machine-readable output.
7. Inspect `${OUTDIR}/logs` and `${OUTDIR}/combined/profile` for status and final outputs.

## Step Dependency Graph

```
INPUT_DIR (*.rmhost_R1.fastq.gz + R2)
 │
 ├── step0_trim ──> trim${TRIM_LEN}/*.trim*_R{1,2}.fastq.gz
 │      │
 │      ▼
 ├── step1_kraken2 ──> kraken2/*.kraken2, *.kreport2
 │      │
 │      ▼
 ├── step2_bracken ──> bracken/*.bracken, *.bracken.kreport
 │      │
 │      ▼
 ├── step3_kreport2mpa ──> mpa/*.mpa
 │      │
 │      ├──────────────────────────┐
 │      ▼                          ▼
 ├── step4_mpa2levels ──> profile/<sample>/L{1..8}.txt
 │
 └── step5_combine ──> combined/bracken.mpa + combined/profile/L{1..8}.txt
                          (uses mpa/*.mpa from step3)
```

Steps 0-4 are per-sample and can be re-run safely (existing outputs are skipped).
Step 5 is aggregate — re-run after any upstream mpa changes.

## Pre-Run Dependency Contract

Before running a Kraken2 flow, verify or prepare the reference-specific runtime:

- `KRAKEN2_DB` points to a Kraken2 database directory containing `hash.k2d`, `taxo.k2d`, `opts.k2d`, and at least one `database*mers.kmer_distrib` file for Bracken.
- `BRACKEN_READ_LEN` matches the database kmer distribution file, such as `BRACKEN_READ_LEN=100` for `database100mers.kmer_distrib`.
- `TRIM_LEN` should normally match `BRACKEN_READ_LEN` when reads are longer than the Bracken read length; set `TRIM_LEN=0` only when skipping trimming is intentional.
- The conda environment contains compatible `kraken2`, `bracken`, `seqkit`, and `python`.
- `KRAKEN_TOOLS_DIR` points to a local checkout of `jenniferlu717/KrakenTools` and contains `kreport2mpa.py` and `combine_mpa.py`.

For a database that requires pinned tool versions, encode the exact versions in the project config or environment profile before running.

## Human Commands

```bash
cd flows/kraken2
cp config_template.sh config.sh
vim config.sh
bash preflight.sh config.sh        # validate before compute
bash run_all.sh config.sh          # full workflow (stop on error)
bash run_all.sh config.sh --continue-on-error  # full workflow (collect all errors)
bash status.sh config.sh           # check progress
bash status.sh config.sh --json    # machine-readable status
```

## Important Checks

- `KRAKEN2_DB` must contain `hash.k2d`, `taxo.k2d`, `opts.k2d`, and `database${BRACKEN_READ_LEN}mers.kmer_distrib`.
- List available Bracken distributions with `ls "${KRAKEN2_DB}"/database*mers.kmer_distrib` before choosing `BRACKEN_READ_LEN`.
- `TRIM_LEN` should match the read length expected by the Bracken database.
- `KRAKEN_TOOLS_DIR` must contain `kreport2mpa.py` for Step 3 and `combine_mpa.py` for Step 5.
- `THREADS * MAX_PARALLEL` should fit the server.
- Existing non-empty outputs are skipped, so reruns are normally safe.

## Common Failure Patterns

See `docs/troubleshooting.md` for detailed diagnostics. Quick reference:

| Symptom | First Check |
|---------|-------------|
| `[FATAL] 缺工具` | `ls "${CONDA_BASE}/envs/${CONDA_ENV}/bin/<tool>"` |
| OOM / killed | Reduce THREADS or MAX_PARALLEL; check `dmesg` |
| Empty kreport2 | `cat "${OUTDIR}/logs/${sample}.kraken2.log"` |
| Bracken fails | `ls "${KRAKEN2_DB}"/database*mers.kmer_distrib` to verify BRACKEN_READ_LEN |
| combine_mpa fails | Verify all `.mpa` files are non-empty: `wc -l "${OUTDIR}"/mpa/*.mpa` |
| High unclassified rate | Kraken2 DB may not match sample origin |

### Log Inspection

```bash
# Find all logs with errors
grep -liE '(error|fatal|exception|killed)' ${OUTDIR}/logs/*.log

# Check classification rates
grep 'classified' ${OUTDIR}/logs/*.kraken2.log

# Tail a failed sample's log
tail -50 ${OUTDIR}/logs/<SAMPLE>.<step>.log
```

## Output Manifest

| Step | Directory | Key Output | Format |
|------|-----------|------------|--------|
| 0 | `${OUTDIR}/trim${TRIM_LEN}/` | `*.trim${TRIM_LEN}_R{1,2}.fastq.gz` | gzipped FASTQ |
| 1 | `${OUTDIR}/kraken2/` | `*.kreport2` | TSV (6 col: pct, count, uniq, rank, taxid, name) |
| 2 | `${OUTDIR}/bracken/` | `*.bracken.kreport` | TSV with Bracken-adjusted counts |
| 3 | `${OUTDIR}/mpa/` | `*.mpa` | 2-col TSV (taxonomy_path, count) |
| 4 | `${OUTDIR}/profile/<sample>/` | `L{1..8}.txt` | Feature table per taxonomic level |
| 5 | `${OUTDIR}/combined/` | `bracken.mpa` + `profile/L{1..8}.txt` | Combined across all samples |
| - | `${OUTDIR}/logs/` | `*.log` | Per-sample per-step logs |

Level mapping: L1=Domain, L2=Phylum, L3=Class, L4=Order, L5=Family, L6=Genus, L7=Species, L8=Strain.

## Resume After Failure

1. `bash status.sh config.sh` — identify which steps are partial
2. Re-run the failed step: `bash step<N>_<name>.sh config.sh` (completed samples are skipped)
3. If individual sample outputs are corrupt, delete them and re-run the step
4. Re-run downstream steps if upstream outputs changed
