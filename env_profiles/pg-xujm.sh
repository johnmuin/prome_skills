#!/bin/bash
#===============================================================================
# Environment Profile: pg-xujm
# Server-specific paths for the pg-xujm bioinformatics workstation.
#
# Usage: source env_profiles/pg-xujm.sh
#
# Verified: 2026-06-15 with kraken2_gvmg test run (3 samples, all steps passed).
#===============================================================================

# ---- Conda ----------------------------------------------------------------
export CONDA_BASE="/share/data2/xujm/miniconda3"

# ---- Scheduler ------------------------------------------------------------
export SCHEDULER="local"
export DEFAULT_THREADS=8
export DEFAULT_MEM="64G"

# ---- Kraken2 --------------------------------------------------------------
# Verified with Kraken2 v2.1.2 + Bracken v2.7
export CONDA_ENV_KRAKEN2="prome_kraken2_212_bracken27"

# GVMG Kraken database (2024-08 build)
# Contains: hash.k2d, taxo.k2d, opts.k2d, database100mers.kmer_distrib
export KRAKEN2_DB="/share/pynas0/pub_data/GVMG/data/work/krakendb_202408"

# Bracken/trim read length matching the GVMG database
export BRACKEN_READ_LEN="100"
export TRIM_LEN="100"

# KrakenTools checkout
# https://github.com/jenniferlu717/KrakenTools
export KRAKEN_TOOLS_DIR="/share/data2/xujm/apps/MAG_flow/utils/KrakenTools-master"

# ---- VIRGO2 ---------------------------------------------------------------
export CONDA_ENV_VIRGO2="virgo2"
export VIRGO2_DIR="/share/data2/xujm/apps/VIRGO2"

# ---- SGE defaults ---------------------------------------------------------
export SGE_QUEUE="all.q"
export SGE_VF="64G"
export SGE_P="16"

# ---- SLURM defaults -------------------------------------------------------
export SLURM_PARTITION="default"
export SLURM_MEM="64G"
export SLURM_TIME="12:00:00"
