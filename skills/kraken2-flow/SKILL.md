---
name: kraken2-flow
description: Use the PROME lightweight Kraken2 flow for paired metagenomic reads: configure server-specific conda/reference paths, run Kraken2, Bracken, kreport2mpa, mpa2levels, combine outputs, and diagnose logs.
---

# Kraken2 Flow

Use this skill when the user wants to run or adapt the PROME Kraken2 classification flow.

## Workflow

1. Locate the flow under `flows/kraken2`.
2. Create or update a project config from `config_template.sh`.
3. Confirm key environment values: `CONDA_BASE`, `CONDA_ENV`, `KRAKEN2_DB`, `KRAKEN_TOOLS_DIR`, and `BRACKEN_READ_LEN`.
4. Check inputs under `INPUT_DIR` using the expected `*.rmhost_R1.fastq.gz` and `*.rmhost_R2.fastq.gz` naming.
5. Run the complete workflow with `bash run_all.sh config.sh`, or run individual steps if resuming.
6. Inspect `${OUTDIR}/logs` and `${OUTDIR}/combined/profile` for status and final outputs.

## Human Commands

```bash
cd flows/kraken2
cp config_template.sh config.sh
vim config.sh
bash run_all.sh config.sh
```

## Important Checks

- `KRAKEN2_DB` must contain `hash.k2d`, `taxo.k2d`, `opts.k2d`, and `database${BRACKEN_READ_LEN}mers.kmer_distrib`.
- `TRIM_LEN` should match the read length expected by the Bracken database.
- `THREADS * MAX_PARALLEL` should fit the server.
- Existing non-empty outputs are skipped, so reruns are normally safe.

## Outputs

Primary outputs are:

- `${OUTDIR}/kraken2/*.kreport2`
- `${OUTDIR}/bracken/*.bracken.kreport`
- `${OUTDIR}/mpa/*.mpa`
- `${OUTDIR}/combined/bracken.mpa`
- `${OUTDIR}/combined/profile/L1.txt` through `L8.txt`

