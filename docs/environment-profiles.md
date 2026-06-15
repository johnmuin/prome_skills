# Environment Profiles

Bioinformatics flows are usually portable only when server-specific paths are explicit.

An environment profile should describe one server or cluster environment:

```bash
export CONDA_BASE="/share/apps/miniconda3"
export CONDA_ENV="kraken2.1.2"
export SCHEDULER="local"   # local / sge / slurm
export DEFAULT_THREADS=16
export DEFAULT_MEM="64G"
```

Reference paths belong here when they are shared across projects:

```bash
export KRAKEN2_DB="/share/ref/kraken2/gvmg_202408"
export KRAKEN_TOOLS_DIR="/share/apps/KrakenTools"
export VIRGO2_DIR="/share/apps/VIRGO2"
```

Project configs should then focus on the project:

```bash
export PROJECT_DIR="/share/project/example"
export INPUT_DIR="${PROJECT_DIR}/quality"
export OUTDIR="${PROJECT_DIR}/kraken2_GVMG"
export SAMPLE_LIST=""
```

