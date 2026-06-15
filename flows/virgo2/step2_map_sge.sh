#!/bin/bash
#$ -cwd
#$ -o logs
#$ -e logs

# Use SGE_O_WORKDIR if available, otherwise use script directory
if [[ -n "${SGE_O_WORKDIR}" ]]; then
    SCRIPT_DIR="${SGE_O_WORKDIR}"
else
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

source "${SCRIPT_DIR}/config.sh"

resolve_path() {
    local value="$1"
    case "${value}" in
        "~")
            printf '%s\n' "${HOME}"
            ;;
        "~/"*)
            printf '%s/%s\n' "${HOME}" "${value#~/}"
            ;;
        /*)
            printf '%s\n' "${value}"
            ;;
        *)
            printf '%s/%s\n' "${SCRIPT_DIR}" "${value}"
            ;;
    esac
}

VIRGO2_DIR="$(resolve_path "${VIRGO2_DIR}")"
CONDA_BASE="$(resolve_path "${CONDA_BASE}")"
PROJECT_DIR="$(resolve_path "${PROJECT_DIR}")"
INPUT_DIR="$(resolve_path "${INPUT_DIR}")"
VIRGO2_OUTDIR="$(resolve_path "${VIRGO2_OUTDIR}")"
VIRGO2_SCRIPT="${VIRGO2_DIR}/VIRGO2.py"
export PATH="${CONDA_BASE}/envs/${CONDA_ENV}/bin:${PATH}"

SAMPLE=${SAMPLE}
INPUT="${VIRGO2_OUTDIR}/merged_reads/${SAMPLE}.merged.fastq.gz"
OUTPUT_PREFIX="${VIRGO2_OUTDIR}/map_results/${SAMPLE}"

[[ -f "${OUTPUT_PREFIX}.out" ]] && exit 0

python3 "${VIRGO2_SCRIPT}" map \
    -r "${INPUT}" \
    -c "${MAP_COV}" \
    -p "${MAP_THREADS}" \
    -o "${OUTPUT_PREFIX}" \
    -b 0
