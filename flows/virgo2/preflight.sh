#!/bin/bash
#===============================================================================
# Preflight: validate environment, references, inputs, and resources before
# running the VIRGO2 workflow.
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
resolve_path() {
    local value="$1"
    case "${value}" in
        "~")       printf '%s\n' "${HOME}" ;;
        "~/"*)     printf '%s/%s\n' "${HOME}" "${value#~/}" ;;
        /*)        printf '%s\n' "${value}" ;;
        *)         printf '%s/%s\n' "${CONFIG_DIR}" "${value}" ;;
    esac
}

INPUT_DIR="$(resolve_path "${INPUT_DIR}")"
VIRGO2_OUTDIR="$(resolve_path "${VIRGO2_OUTDIR}")"
VIRGO2_DIR="$(resolve_path "${VIRGO2_DIR}")"
CONDA_BASE="$(resolve_path "${CONDA_BASE}")"

PASSES=0
FAILS=0
WARNS=0

pass()  { PASSES=$((PASSES + 1)); echo "  [PASS] $1"; }
fail()  { FAILS=$((FAILS + 1)); echo "  [FAIL] $1"; }
warn()  { WARNS=$((WARNS + 1)); echo "  [WARN] $1"; }

echo "========================================"
echo "VIRGO2 Preflight"
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

if [[ -n "${VIRGO2_DIR:-}" && "${VIRGO2_DIR}" != "/path/to/VIRGO2" ]]; then
    pass "VIRGO2_DIR=${VIRGO2_DIR}"
else
    fail "VIRGO2_DIR is not set or still has placeholder value"
fi

if [[ -n "${INPUT_DIR:-}" && "${INPUT_DIR}" != *"/path/to/"* ]]; then
    pass "INPUT_DIR=${INPUT_DIR}"
else
    fail "INPUT_DIR is not set or still has placeholder value"
fi

if [[ -n "${VIRGO2_OUTDIR:-}" && "${VIRGO2_OUTDIR}" != *"/path/to/"* ]]; then
    pass "VIRGO2_OUTDIR=${VIRGO2_OUTDIR}"
else
    fail "VIRGO2_OUTDIR is not set or still has placeholder value"
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

# ---- Check 3: Required binaries (from configured conda env) ------------------
echo ""
echo "--- Required binaries"
BIN_DIR="${CONDA_BASE}/envs/${CONDA_ENV}/bin"

# Activate the configured env so PATH reflects it
if [[ -f "${CONDA_BASE}/etc/profile.d/conda.sh" ]]; then
    # shellcheck disable=SC1091
    source "${CONDA_BASE}/etc/profile.d/conda.sh"
    conda activate "${CONDA_ENV}" 2>/dev/null || true
fi

for tool in python3 python; do
    # Prefer the binary from the configured env, not the current shell
    if [[ -x "${BIN_DIR}/${tool}" ]]; then
        pass "$tool -> ${BIN_DIR}/${tool}"
    elif command -v "$tool" >/dev/null 2>&1; then
        warn "$tool not in ${BIN_DIR}, using $(command -v "$tool") — may not match CONDA_ENV=${CONDA_ENV}"
    else
        fail "$tool not found in ${BIN_DIR} or on PATH"
    fi
done

# ---- Check 4: VIRGO2.py -----------------------------------------------------
echo ""
echo "--- VIRGO2 installation: ${VIRGO2_DIR}"
if [[ ! -d "${VIRGO2_DIR}" ]]; then
    fail "VIRGO2_DIR directory does not exist"
else
    pass "VIRGO2_DIR exists"
    VIRGO2_SCRIPT="${VIRGO2_DIR}/VIRGO2.py"
    if [[ -f "${VIRGO2_SCRIPT}" ]]; then
        pass "VIRGO2.py found"
    else
        fail "VIRGO2.py missing from ${VIRGO2_DIR}"
    fi

    merge_script="${VIRGO2_DIR}/AccessoryScripts/merge_annotations.py"
    if [[ -f "${merge_script}" ]]; then
        pass "AccessoryScripts/merge_annotations.py found"
    else
        warn "AccessoryScripts/merge_annotations.py missing — needed for step5_annotate"
    fi
fi

# ---- Check 5: Python dependencies -------------------------------------------
echo ""
echo "--- Python dependency check"
if [[ -x "${BIN_DIR}/python3" ]]; then
    PY="${BIN_DIR}/python3"
elif [[ -x "${BIN_DIR}/python" ]]; then
    PY="${BIN_DIR}/python"
else
    PY=$(command -v python3 2>/dev/null || command -v python 2>/dev/null || echo "")
fi
if [[ -x "${PY}" ]]; then
    # Quick import check for common VIRGO2 dependencies
    for mod in pandas numpy; do
        if "${PY}" -c "import ${mod}" 2>/dev/null; then
            pass "Python module '${mod}' available"
        else
            fail "Python module '${mod}' not available — install in ${CONDA_ENV}"
        fi
    done
else
    fail "No Python interpreter found to check dependencies"
fi

# ---- Check 6: Input samples -------------------------------------------------
echo ""
echo "--- Input samples: ${INPUT_DIR}"
get_samples() {
    if [[ -n "${SAMPLE_LIST:-}" && -f "${SAMPLE_LIST}" ]]; then
        cat "${SAMPLE_LIST}"
    else
        ls "${INPUT_DIR}"/*.rmhost_R1.fastq.gz 2>/dev/null | \
            xargs -n1 basename | sed 's/.rmhost_R1.fastq.gz//'
    fi
}
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

# ---- Check 7: Output directory writable -------------------------------------
echo ""
echo "--- Output directory"
out_parent="${VIRGO2_OUTDIR}"
while [[ ! -d "${out_parent}" ]]; do
    out_parent="$(dirname "${out_parent}")"
done
if [[ -w "${out_parent}" ]]; then
    pass "Output parent writable: ${out_parent}"
else
    fail "Output parent not writable: ${out_parent}"
fi

# ---- Check 8: Resource sanity -----------------------------------------------
echo ""
echo "--- Resource sanity"
avail_cores=$(getconf _NPROCESSORS_ONLN 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 0)
if [[ "${avail_cores}" -gt 0 ]]; then
    requested=$(( MAP_THREADS * MAX_MAP_JOBS ))
    if [[ "${requested}" -le "${avail_cores}" ]]; then
        pass "MAP_THREADS(${MAP_THREADS}) × MAX_MAP_JOBS(${MAX_MAP_JOBS}) = ${requested} ≤ ${avail_cores} available cores"
    else
        warn "MAP_THREADS(${MAP_THREADS}) × MAX_MAP_JOBS(${MAX_MAP_JOBS}) = ${requested} > ${avail_cores} available cores — may overload"
    fi
else
    warn "Could not detect available cores; MAP_THREADS=${MAP_THREADS} MAX_MAP_JOBS=${MAX_MAP_JOBS}"
fi

# ---- Check 9: Preview first 3 sample pairs ----------------------------------
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
