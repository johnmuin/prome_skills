#!/bin/bash
#===============================================================================
# Verify the Kraken2 conda environment has the correct tools and versions.
# Usage: bash check_kraken2_env.sh <profile.sh>
#===============================================================================
set -u

PROFILE="${1:-}"
if [[ -z "${PROFILE}" || ! -f "${PROFILE}" ]]; then
    echo "Usage: bash $0 <path/to/profile.sh>"
    echo "  profile.sh should export CONDA_BASE and CONDA_ENV_KRAKEN2"
    exit 1
fi

# shellcheck disable=SC1090
source "${PROFILE}"

if [[ -z "${CONDA_BASE:-}" || -z "${CONDA_ENV_KRAKEN2:-}" ]]; then
    echo "[FAIL] Profile must set CONDA_BASE and CONDA_ENV_KRAKEN2"
    exit 1
fi

# Activate conda
if [[ -f "${CONDA_BASE}/etc/profile.d/conda.sh" ]]; then
    # shellcheck disable=SC1091
    source "${CONDA_BASE}/etc/profile.d/conda.sh"
    conda activate "${CONDA_ENV_KRAKEN2}" 2>/dev/null || {
        echo "[FAIL] Could not activate conda env: ${CONDA_ENV_KRAKEN2}"
        exit 1
    }
else
    export PATH="${CONDA_BASE}/envs/${CONDA_ENV_KRAKEN2}/bin:${PATH}"
fi

PASSES=0
FAILS=0
pass() { PASSES=$((PASSES + 1)); echo "  [PASS] $1"; }
fail() { FAILS=$((FAILS + 1)); echo "  [FAIL] $1"; }

echo "Kraken2 Environment Check"
echo "Profile:  ${PROFILE}"
echo "Conda:    ${CONDA_BASE}/envs/${CONDA_ENV_KRAKEN2}"
echo ""

# Helper: get installed version from conda package metadata.
# This is more reliable than --version flags (bracken 2.7 --version prints usage).
conda_pkg_ver() {
    local pkg="$1"
    conda list -n "${CONDA_ENV_KRAKEN2}" "${pkg}" 2>/dev/null | \
        awk -v p="${pkg}" '$1==p{print $2; exit}'
}

# Check required binaries and versions
declare -A EXPECTED
EXPECTED[kraken2]="2.1.2"
EXPECTED[bracken]="2.7"
EXPECTED[seqkit]=""    # any version
EXPECTED[python3]=""   # any version

for tool in "${!EXPECTED[@]}"; do
    expected_ver="${EXPECTED[$tool]}"
    if ! command -v "$tool" >/dev/null 2>&1; then
        fail "$tool: not found"
        continue
    fi
    actual_path=$(command -v "$tool")
    if [[ -n "${expected_ver}" ]]; then
        actual_ver=$(conda_pkg_ver "${tool}")
        if [[ "${actual_ver}" == "${expected_ver}" ]]; then
            pass "$tool ${actual_ver} == ${expected_ver}  (${actual_path})"
        else
            fail "$tool: expected conda package ${expected_ver}, got ${actual_ver:-unknown}  (${actual_path})"
        fi
    else
        pass "$tool found at ${actual_path}"
    fi
done

# Check python can import common modules
echo ""
echo "--- Python module checks"
for mod in gzip csv argparse; do
    if python3 -c "import ${mod}" 2>/dev/null; then
        pass "python3 imports ${mod}"
    else
        fail "python3 cannot import ${mod}"
    fi
done

echo ""
echo "Result: ${PASSES} passed, ${FAILS} failed"
[[ "${FAILS}" -gt 0 ]] && exit 1
exit 0
