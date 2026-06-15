#!/bin/bash
# Step 2: VIRGO2 Map (Parallel Local Mode)
# 本地并行运行map比对：按样品并发，每个样品占用 MAP_THREADS 线程

set -u

CONFIG_FILE="${1:-config.sh}"
if [[ ! -f "${CONFIG_FILE}" ]]; then
    echo "Error: Config file not found: ${CONFIG_FILE}"
    exit 1
fi

CONFIG_DIR="$(cd "$(dirname "${CONFIG_FILE}")" && pwd)"
source "${CONFIG_FILE}"

# Expand ~ and relative paths from the config directory.
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
            printf '%s/%s\n' "${CONFIG_DIR}" "${value}"
            ;;
    esac
}

VIRGO2_DIR="$(resolve_path "${VIRGO2_DIR}")"
CONDA_BASE="$(resolve_path "${CONDA_BASE}")"
PROJECT_DIR="$(resolve_path "${PROJECT_DIR}")"
INPUT_DIR="$(resolve_path "${INPUT_DIR}")"
VIRGO2_OUTDIR="$(resolve_path "${VIRGO2_OUTDIR}")"
VIRGO2_SCRIPT="${VIRGO2_DIR}/VIRGO2.py"

# Set PATH to use virgo2 environment
export PATH="${CONDA_BASE}/envs/${CONDA_ENV}/bin:${PATH}"

MAX_MAP_JOBS="${MAX_MAP_JOBS:-8}"

echo "========================================"
echo "Step 2: VIRGO2 Map (Parallel Local)"
echo "========================================"
echo "Start: $(date)"
echo "Config: ${CONFIG_FILE}"
echo "Map threads per sample: ${MAP_THREADS}"
echo "Parallel samples: ${MAX_MAP_JOBS}"
echo ""

mkdir -p "${VIRGO2_OUTDIR}/map_results" "${VIRGO2_OUTDIR}/logs"

samples=$(ls "${VIRGO2_OUTDIR}/merged_reads"/*.merged.fastq.gz 2>/dev/null | \
    xargs -n1 basename | sed 's/.merged.fastq.gz//')

total=$(echo "${samples}" | wc -l)
if [[ "${total}" -eq 0 ]]; then
    echo "Error: No merged reads found in ${VIRGO2_OUTDIR}/merged_reads"
    exit 1
fi

echo "Samples to process: ${total}"
echo ""

run_one_sample() {
    local sample="$1"
    local input="${VIRGO2_OUTDIR}/merged_reads/${sample}.merged.fastq.gz"
    local output_prefix="${VIRGO2_OUTDIR}/map_results/${sample}"
    local log_file="${VIRGO2_OUTDIR}/logs/${sample}.map.log"

    if [[ -f "${output_prefix}.out" ]]; then
        echo "[${sample}] already done"
        return 0
    fi

    echo "[${sample}] mapping..."
    python3 "${VIRGO2_SCRIPT}" map \
        -r "${input}" \
        -c "${MAP_COV}" \
        -p "${MAP_THREADS}" \
        -o "${output_prefix}" \
        -b 0 \
        > "${log_file}" 2>&1

    if [[ -f "${output_prefix}.out" ]]; then
        echo "[${sample}] done"
        return 0
    else
        echo "[${sample}] failed"
        return 1
    fi
}

running_pids=()
running_samples=()
failed_samples=()

count=0
for sample in ${samples}; do
    count=$((count + 1))

    while [[ ${#running_pids[@]} -ge ${MAX_MAP_JOBS} ]]; do
        pid="${running_pids[0]}"
        wait "${pid}"
        status=$?
        finished_sample="${running_samples[0]}"

        running_pids=("${running_pids[@]:1}")
        running_samples=("${running_samples[@]:1}")

        if [[ ${status} -ne 0 ]]; then
            failed_samples+=("${finished_sample}")
        fi
    done

    (
        run_one_sample "${sample}"
    ) &

    running_pids+=("$!")
    running_samples+=("${sample}")

    echo "[${count}/${total}] queued ${sample}"
done

# Drain remaining jobs
while [[ ${#running_pids[@]} -gt 0 ]]; do
    pid="${running_pids[0]}"
    wait "${pid}"
    status=$?
    finished_sample="${running_samples[0]}"

    running_pids=("${running_pids[@]:1}")
    running_samples=("${running_samples[@]:1}")

    if [[ ${status} -ne 0 ]]; then
        failed_samples+=("${finished_sample}")
    fi
done

echo ""
if [[ ${#failed_samples[@]} -gt 0 ]]; then
    echo "Map complete with failures: ${#failed_samples[@]} sample(s)"
    printf '  %s\n' "${failed_samples[@]}"
    exit 1
fi

echo "Map complete: $(date)"
