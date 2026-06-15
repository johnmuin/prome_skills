#!/bin/bash
#===============================================================================
# Environment Profile Template
# Copy this file and fill in server-specific paths for your cluster/server.
#
# Usage: source env_profiles/<your-server>.sh
#
# The project config (config.sh) should source an env profile first so that
# reference paths and tool versions stay centralized.
#===============================================================================

# ---- Conda ----------------------------------------------------------------
# Base install directory of miniconda3 / anaconda3
export CONDA_BASE="/path/to/miniconda3"

# ---- Scheduler ------------------------------------------------------------
# local / sge / slurm
export SCHEDULER="local"
export DEFAULT_THREADS=16
export DEFAULT_MEM="64G"

# ---- Kraken2 --------------------------------------------------------------
# Conda environment containing kraken2, bracken, seqkit, python
export CONDA_ENV_KRAKEN2="kraken2.1.2"

# Kraken2 database directory (must contain hash.k2d, taxo.k2d, opts.k2d,
# and database*mers.kmer_distrib)
export KRAKEN2_DB="/path/to/kraken2_db"

# Bracken read length — must match a database*<N>mers.kmer_distrib file in KRAKEN2_DB
export BRACKEN_READ_LEN="100"

# Trim length — normally matches BRACKEN_READ_LEN; set to 0 to skip trimming
export TRIM_LEN="100"

# KrakenTools checkout: https://github.com/jenniferlu717/KrakenTools
export KRAKEN_TOOLS_DIR="/path/to/KrakenTools"

# ---- VIRGO2 ---------------------------------------------------------------
# Conda environment for VIRGO2 (Python 3 with pandas, numpy)
export CONDA_ENV_VIRGO2="virgo2"

# VIRGO2 installation directory (contains VIRGO2.py)
export VIRGO2_DIR="/path/to/VIRGO2"

# ---- SGE defaults (if applicable) -----------------------------------------
export SGE_QUEUE="all.q"
export SGE_VF="64G"
export SGE_P="16"

# ---- SLURM defaults (if applicable) ---------------------------------------
export SLURM_PARTITION="default"
export SLURM_MEM="64G"
export SLURM_TIME="12:00:00"
