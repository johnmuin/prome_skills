#!/bin/bash
#===============================================================================
# Preflight: validate environment, references, inputs, and resources before
# running the Kraken2 workflow.
#
# Usage: bash preflight.sh config.sh
# Exits 0 when all checks pass, non-zero otherwise.
#===============================================================================

set -u

CONFIG_FILE="${1:-config.sh}"
if [[ ! -f "${CONFIG_FILE}" ]]; then
    echo "[FAIL] Config file not found: ${CONFIG_FILE}"
    exit 1
fi

CONFIG_DIR="$(cd "$(dirname "${CONFIG_FILE}")" && pwd)"
# shellcheck disable=SC1090
source "${CONFIG_FILE}"

# Resolve key paths
INPUT_DIR="$(resolve_path "${INPUT_DIR}")"
OUTDIR="$(resolve_path "${OUTDIR}")"
KRAKEN2_DB="$(resolve_path "${KRAKEN2_DB}")"
KRAKEN_TOOLS_DIR="$(resolve_path "${KRAKEN_TOOLS_DIR}")"
MPA2LEVELS_SCRIPT="$(resolve_path "${MPA2LEVELS_SCRIPT}")"
CONDA_BASE="$(resolve_path "${CONDA_BASE}")"

PASSES=0
FAILS=0
WARNS=0

pass()  { PASSES=$((PASSES + 1)); echo "  [PASS] $1"; }
fail()  { FAILS=$((FAILS + 1)); echo "  [FAIL] $1"; }
warn()  { WARNS=$((WARNS + 1)); echo "  [WARN] $1"; }

echo "========================================"
echo "Kraken2 Preflight"
echo "Config: ${CONFIG_FILE}"
echo "Time:   $(date)"
echo "========================================"
echo ""

# ---- Check 1: Config loaded ------------------------------------------------
echo "--- Config & paths"
if [[ -n "${CONDA_ENV:-}" ]]; then
    pass "CONDA_ENV=${CONDA_ENV}"
else
    fail "CONDA_ENV is not set"
fi

if [[ -n "${KRAKEN2_DB:-}" && "${KRAKEN2_DB}" != "/path/to/kraken2_db" ]]; then
    pass "KRAKEN2_DB=${KRAKEN2_DB}"
else
    fail "KRAKEN2_DB is not set or still has placeholder value"
fi

if [[ -n "${BRACKEN_READ_LEN:-}" ]]; then
    pass "BRACKEN_READ_LEN=${BRACKEN_READ_LEN}"
else
    fail "BRACKEN_READ_LEN is not set"
fi

if [[ -n "${KRAKEN_TOOLS_DIR:-}" && "${KRAKEN_TOOLS_DIR}" != "/path/to/KrakenTools" ]]; then
    pass "KRAKEN_TOOLS_DIR=${KRAKEN_TOOLS_DIR}"
else
    fail "KRAKEN_TOOLS_DIR is not set or still has placeholder value"
fi

if [[ -n "${INPUT_DIR:-}" && "${INPUT_DIR}" != *"/path/to/"* ]]; then
    pass "INPUT_DIR=${INPUT_DIR}"
else
    fail "INPUT_DIR is not set or still has placeholder value"
fi

if [[ -n "${OUTDIR:-}" && "${OUTDIR}" != *"/path/to/"* ]]; then
    pass "OUTDIR=${OUTDIR}"
else
    fail "OUTDIR is not set or still has placeholder value"
fi

# ---- Check 2: Conda ---------------------------------------------------------
echo ""
echo "--- Conda environment"
if [[ -f "${CONDA_BASE}/etc/profile.d/conda.sh" ]]; then
    pass "conda.sh found at ${CONDA_BASE}/etc/profile.d/conda.sh"
else
    fail "conda.sh not found at ${CONDA_BASE}/etc/profile.d/conda.sh"
fi

if [[ -d "${CONDA_BASE}/envs/${CONDA_ENV}" ]]; then
    pass "conda env exists: ${CONDA_BASE}/envs/${CONDA_ENV}"
else
    fail "conda env not found: ${CONDA_BASE}/envs/${CONDA_ENV}"
fi

# ---- Check 3: Required binaries ---------------------------------------------
echo ""
echo "--- Required binaries (after conda activate)"
load_conda
BIN_DIR="${CONDA_BASE}/envs/${CONDA_ENV}/bin"
for tool in kraken2 bracken seqkit python3 python; do
    if command -v "$tool" >/dev/null 2>&1; then
        pass "$tool -> $(command -v "$tool")"
    elif [[ -x "${BIN_DIR}/${tool}" ]]; then
        pass "$tool -> ${BIN_DIR}/${tool}"
    else
        fail "$tool not found on PATH or in ${BIN_DIR}"
    fi
done

# ---- Check 4: Kraken2 DB core files -----------------------------------------
echo ""
echo "--- Kraken2 database: ${KRAKEN2_DB}"
if [[ ! -d "${KRAKEN2_DB}" ]]; then
    fail "KRAKEN2_DB directory does not exist"
else
    pass "KRAKEN2_DB directory exists"
    for f in hash.k2d taxo.k2d opts.k2d; do
        if [[ -f "${KRAKEN2_DB}/${f}" ]]; then
            pass "${f} found"
        else
            fail "${f} missing from KRAKEN2_DB"
        fi
    done
fi

# ---- Check 5: Bracken kmer distribution FIRST (must pass before step0) ---------
echo ""
echo "--- Bracken DB: available read lengths"
shopt -s nullglob
kmers=( "${KRAKEN2_DB}"/database*mers.kmer_distrib )
shopt -u nullglob

# Extract available read lengths from filenames
declare -a AVAILABLE_LENS
if [[ ${#kmers[@]} -eq 0 ]]; then
    fail "No database*mers.kmer_distrib found in KRAKEN2_DB"
else
    pass "Found ${#kmers[@]} kmer distribution file(s):"
    for k in "${kmers[@]}"; do
        base=$(basename "$k")
        len=$(echo "$base" | sed -E 's/database([0-9]+)mers.kmer_distrib/\1/')
        AVAILABLE_LENS+=("$len")
        echo "         ${base}  ->  BRACKEN_READ_LEN=${len}"
    done
fi

# Validate BRACKEN_READ_LEN against available
echo ""
echo "--- BRACKEN_READ_LEN check"
if [[ ${#AVAILABLE_LENS[@]} -eq 0 ]]; then
    fail "Cannot validate BRACKEN_READ_LEN — no kmer files found"
else
    matched=false
    for len in "${AVAILABLE_LENS[@]}"; do
        if [[ "${BRACKEN_READ_LEN}" == "${len}" ]]; then
            matched=true
            break
        fi
    done
    if [[ "${matched}" == "true" ]]; then
        pass "BRACKEN_READ_LEN=${BRACKEN_READ_LEN} matches database${BRACKEN_READ_LEN}mers.kmer_distrib"
    else
        avail_str=$(IFS=,; echo "${AVAILABLE_LENS[*]}")
        fail "BRACKEN_READ_LEN=${BRACKEN_READ_LEN} not found in database"
        echo "         Available: ${avail_str}"
        echo "         Fix: set BRACKEN_READ_LEN to one of [${avail_str}] in your config"
    fi
fi

# ---- Check 5b: Validate TRIM_LEN matches BRACKEN_READ_LEN -----------------------
echo ""
echo "--- TRIM_LEN vs BRACKEN_READ_LEN"
# Use string comparison to avoid arithmetic crash on non-numeric config values
if [[ "${TRIM_LEN:-0}" == "${BRACKEN_READ_LEN}" ]]; then
    pass "TRIM_LEN=${TRIM_LEN} matches BRACKEN_READ_LEN=${BRACKEN_READ_LEN}"
elif [[ "${TRIM_LEN:-0}" == "0" ]]; then
    warn "TRIM_LEN=0 — step0 will be skipped; step1 reads directly from INPUT_DIR. Ensure reads are already ${BRACKEN_READ_LEN}bp."
else
    fail "TRIM_LEN=${TRIM_LEN} differs from BRACKEN_READ_LEN=${BRACKEN_READ_LEN} — reads will be trimmed to wrong length for Bracken"
fi

# ---- Check 6: KrakenTools ---------------------------------------------------
echo ""
echo "--- KrakenTools: ${KRAKEN_TOOLS_DIR}"
if [[ ! -d "${KRAKEN_TOOLS_DIR}" ]]; then
    fail "KRAKEN_TOOLS_DIR directory does not exist"
else
    pass "KRAKEN_TOOLS_DIR exists"
    for f in kreport2mpa.py combine_mpa.py; do
        if [[ -f "${KRAKEN_TOOLS_DIR}/${f}" ]]; then
            pass "${f} found"
        else
            fail "${f} missing from KRAKEN_TOOLS_DIR"
        fi
    done
fi

# ---- Check 7: mpa2levels script ---------------------------------------------
echo ""
echo "--- mpa2levels script"
if [[ -f "${MPA2LEVELS_SCRIPT}" ]]; then
    pass "MPA2LEVELS_SCRIPT=${MPA2LEVELS_SCRIPT}"
else
    fail "MPA2LEVELS_SCRIPT not found: ${MPA2LEVELS_SCRIPT}"
fi

# ---- Check 8: Input samples -------------------------------------------------
echo ""
echo "--- Input samples: ${INPUT_DIR}"
if [[ ! -d "${INPUT_DIR}" ]]; then
    fail "INPUT_DIR does not exist"
else
    pass "INPUT_DIR exists"
    samples=$(get_samples)
    total=$(echo "${samples}" | wc -l | tr -d ' ')
    if [[ "${total}" -eq 0 ]]; then
        fail "No *.rmhost_R1.fastq.gz files found in INPUT_DIR"
    else
        pass "Found ${total} sample(s)"
    fi
fi

# ---- Check 9: Output directory writable -------------------------------------
echo ""
echo "--- Output directory"
out_parent="${OUTDIR}"
while [[ ! -d "${out_parent}" ]]; do
    out_parent="$(dirname "${out_parent}")"
done
if [[ -w "${out_parent}" ]]; then
    pass "Output parent writable: ${out_parent}"
else
    fail "Output parent not writable: ${out_parent}"
fi

# ---- Check 10: Resource sanity ----------------------------------------------
echo ""
echo "--- Resource sanity"
avail_cores=$(getconf _NPROCESSORS_ONLN 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 0)
if [[ "${avail_cores}" -gt 0 ]]; then
    requested=$(( THREADS * MAX_PARALLEL ))
    if [[ "${requested}" -le "${avail_cores}" ]]; then
        pass "THREADS(${THREADS}) × MAX_PARALLEL(${MAX_PARALLEL}) = ${requested} ≤ ${avail_cores} available cores"
    else
        warn "THREADS(${THREADS}) × MAX_PARALLEL(${MAX_PARALLEL}) = ${requested} > ${avail_cores} available cores — may overload"
    fi
else
    warn "Could not detect available cores; THREADS=${THREADS} MAX_PARALLEL=${MAX_PARALLEL}"
fi

# ---- Check 11: Preview first 3 sample pairs ---------------------------------
echo ""
echo "--- Sample file preview (first 3)"
count=0
for sample in ${samples}; do
    count=$((count + 1))
    [[ ${count} -gt 3 ]] && break
    r1="${INPUT_DIR}/${sample}.rmhost_R1.fastq.gz"
    r2="${INPUT_DIR}/${sample}.rmhost_R2.fastq.gz"
    if [[ -s "$r1" && -s "$r2" ]]; then
        size1=$(du -h "$r1" 2>/dev/null | cut -f1)
        size2=$(du -h "$r2" 2>/dev/null | cut -f1)
        pass "${sample}: R1=${size1} R2=${size2}"
    else
        details=""
        [[ ! -f "$r1" ]] && details="${details}missing R1 "
        [[ ! -s "$r1" && -f "$r1" ]] && details="${details}empty R1 "
        [[ ! -f "$r2" ]] && details="${details}missing R2 "
        [[ ! -s "$r2" && -f "$r2" ]] && details="${details}empty R2 "
        fail "${sample}: ${details}"
    fi
done

# ---- Summary ----------------------------------------------------------------
echo ""
echo "========================================"
echo "Preflight Summary"
echo "  Passed: ${PASSES}"
echo "  Failed: ${FAILS}"
echo "  Warnings: ${WARNS}"
echo "========================================"

if [[ "${FAILS}" -gt 0 ]]; then
    echo ""
    echo "Fix the [FAIL] items above before running the workflow."
    exit 1
fi

echo "All checks passed. Ready to run."
