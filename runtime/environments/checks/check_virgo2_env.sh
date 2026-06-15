#!/bin/bash
#===============================================================================
# Verify the VIRGO2 conda environment has the correct tools and versions.
# Usage: bash check_virgo2_env.sh <profile.sh>
#===============================================================================
set -u

PROFILE="${1:-}"
if [[ -z "${PROFILE}" || ! -f "${PROFILE}" ]]; then
    echo "Usage: bash $0 <path/to/profile.sh>"
    echo "  profile.sh should export CONDA_BASE, CONDA_ENV_VIRGO2, and VIRGO2_DIR"
    exit 1
fi

# shellcheck disable=SC1090
source "${PROFILE}"

if [[ -z "${CONDA_BASE:-}" || -z "${CONDA_ENV_VIRGO2:-}" ]]; then
    echo "[FAIL] Profile must set CONDA_BASE and CONDA_ENV_VIRGO2"
    exit 1
fi

# Activate conda
if [[ -f "${CONDA_BASE}/etc/profile.d/conda.sh" ]]; then
    # shellcheck disable=SC1091
    source "${CONDA_BASE}/etc/profile.d/conda.sh"
    conda activate "${CONDA_ENV_VIRGO2}" 2>/dev/null || {
        echo "[FAIL] Could not activate conda env: ${CONDA_ENV_VIRGO2}"
        exit 1
    }
else
    export PATH="${CONDA_BASE}/envs/${CONDA_ENV_VIRGO2}/bin:${PATH}"
fi

PASSES=0
FAILS=0
pass() { PASSES=$((PASSES + 1)); echo "  [PASS] $1"; }
fail() { FAILS=$((FAILS + 1)); echo "  [FAIL] $1"; }

echo "VIRGO2 Environment Check"
echo "Profile:  ${PROFILE}"
echo "Conda:    ${CONDA_BASE}/envs/${CONDA_ENV_VIRGO2}"
echo ""

# Check python
if command -v python3 >/dev/null 2>&1; then
    pass "python3 -> $(command -v python3)"
elif command -v python >/dev/null 2>&1; then
    pass "python -> $(command -v python)"
else
    fail "python not found"
fi

# Check required Python modules
echo ""
echo "--- Python module checks"
for mod in pandas numpy; do
    if python3 -c "import ${mod}" 2>/dev/null; then
        ver=$(python3 -c "import ${mod}; print(${mod}.__version__)" 2>/dev/null)
        pass "${mod} ${ver}"
    else
        fail "${mod} not found"
    fi
done

# Check VIRGO2.py
echo ""
echo "--- VIRGO2 script"
if [[ -n "${VIRGO2_DIR:-}" && -f "${VIRGO2_DIR}/VIRGO2.py" ]]; then
    pass "VIRGO2.py -> ${VIRGO2_DIR}/VIRGO2.py"
elif [[ -n "${VIRGO2_DIR:-}" ]]; then
    fail "VIRGO2.py not found at ${VIRGO2_DIR}/VIRGO2.py"
else
    fail "VIRGO2_DIR is not set in profile"
fi

echo ""
echo "Result: ${PASSES} passed, ${FAILS} failed"
[[ "${FAILS}" -gt 0 ]] && exit 1
exit 0
