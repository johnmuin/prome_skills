# Environment Profiles

Bioinformatics flows are usually portable only when server-specific paths are explicit.

An environment profile should describe one server or cluster environment:

```bash
export CONDA_BASE="/path/to/miniconda3"
export CONDA_ENV="kraken2.1.2"
export SCHEDULER="local"   # local / sge / slurm
export DEFAULT_THREADS=16
export DEFAULT_MEM="64G"
```

Reference paths belong here when they are shared across projects:

```bash
export KRAKEN2_DB="/path/to/kraken2_db"
export KRAKEN_TOOLS_DIR="/path/to/KrakenTools"
export VIRGO2_DIR="/path/to/VIRGO2"
```

Reference-specific tool constraints also belong in the profile when needed:

```bash
export CONDA_ENV="kraken2.1.2"
export BRACKEN_READ_LEN="100"
export TRIM_LEN="100"
```

Before running a Kraken2 profile, confirm the database contains `hash.k2d`, `taxo.k2d`, `opts.k2d`, and a matching `database${BRACKEN_READ_LEN}mers.kmer_distrib`. `KRAKEN_TOOLS_DIR` should point to a `jenniferlu717/KrakenTools` checkout with `kreport2mpa.py` and `combine_mpa.py`.

Project configs should then focus on the project:

```bash
export PROJECT_DIR="/path/to/project"
export INPUT_DIR="${PROJECT_DIR}/quality"
export OUTDIR="${PROJECT_DIR}/kraken2_output"
export SAMPLE_LIST=""
```
