#!/bin/bash
#===============================================================================
# Step 1: Kraken2 Classification
# 输入:  ${OUTDIR}/trim${TRIM_LEN}/${sample}.trim*_R{1,2}.fastq.gz
# 输出:  ${OUTDIR}/kraken2/${sample}.kraken2
#        ${OUTDIR}/kraken2/${sample}.kreport2
# MAX_PARALLEL 控制本地并发样品数
#===============================================================================

set -u

CONFIG_FILE="${1:-config.sh}"
if [[ ! -f "${CONFIG_FILE}" ]]; then
    echo "错误: 配置文件不存在: ${CONFIG_FILE}" >&2
    echo "用法: bash $0 [config_file]" >&2
    exit 1
fi

CONFIG_DIR="$(cd "$(dirname "${CONFIG_FILE}")" && pwd)"
# shellcheck disable=SC1090
source "${CONFIG_FILE}"

INPUT_DIR="$(resolve_path "${INPUT_DIR}")"
OUTDIR="$(resolve_path "${OUTDIR}")"
KRAKEN2_DB="$(resolve_path "${KRAKEN2_DB}")"

if [[ "${TRIM_LEN}" -gt 0 ]]; then
    TRIM_DIR="${OUTDIR}/trim${TRIM_LEN}"
else
    TRIM_DIR="${OUTDIR}/trim0"
fi
K2_DIR="${OUTDIR}/kraken2"
LOG_DIR="${OUTDIR}/logs"
mkdir -p "${K2_DIR}" "${LOG_DIR}"

load_conda
for tool in kraken2; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "[FATAL] 缺工具 $tool" >&2; exit 1
    fi
done
if [[ ! -f "${KRAKEN2_DB}/hash.k2d" ]]; then
    echo "[FATAL] 找不到 ${KRAKEN2_DB}/hash.k2d, 检查 KRAKEN2_DB" >&2; exit 1
fi

MAX_PARALLEL="${MAX_PARALLEL:-1}"
THREADS_PER_JOB="${THREADS}"

echo "========================================"
echo "Step 1: Kraken2 Classification"
echo "========================================"
echo "库:    ${KRAKEN2_DB}"
echo "输入:  ${TRIM_DIR}"
echo "输出:  ${K2_DIR}"
echo "并发:  ${MAX_PARALLEL}  样品, 每样品 ${THREADS_PER_JOB} 线程"
echo "开始:  $(date)"
echo ""

samples=$(get_samples)
total=$(echo "${samples}" | wc -l | tr -d ' ')
if [[ "${total}" -eq 0 ]]; then
    echo "错误: 没找到样品" >&2; exit 1
fi
echo "样品:  ${total} 个"
echo ""

run_one() {
    local sample="$1"
    local t1="${TRIM_DIR}/${sample}.trim${TRIM_LEN:-0}_R1.fastq.gz"
    local t2="${TRIM_DIR}/${sample}.trim${TRIM_LEN:-0}_R2.fastq.gz"
    local out="${K2_DIR}/${sample}.kraken2"
    local rep="${K2_DIR}/${sample}.kreport2"
    local log="${LOG_DIR}/${sample}.kraken2.log"

    if [[ -s "$rep" ]]; then
        echo "[${sample}] 已存在 kreport2, 跳过"
        return 0
    fi
    if [[ ! -f "$t1" || ! -f "$t2" ]]; then
        echo "[${sample}] 缺 fastq, 跳过" >&2
        return 1
    fi

    echo "[$(date +%H:%M:%S)] [${sample}] 启动"
    local args=(
        --db "${KRAKEN2_DB}"
        --threads "${THREADS_PER_JOB}"
        --paired
        --report-zero-counts
        --output "${out}"
        --report "${rep}"
        "${t1}" "${t2}"
    )
    [[ "${KRAKEN2_USE_NAMES}" -eq 1 ]] && args+=( --use-names )
    [[ "${KRAKEN2_USE_MM}"     -eq 1 ]] && args+=( --memory-mapping )
    [[ -n "${KRAKEN2_CONFIDENCE}" ]] && args+=( --confidence "${KRAKEN2_CONFIDENCE}" )

    kraken2 "${args[@]}" 2> "${log}"
    if [[ -s "$rep" ]]; then
        local pct
        pct=$(awk -F'\t' 'NR==2{print $1; exit}' "$rep" 2>/dev/null)
        echo "[$(date +%H:%M:%S)] [${sample}] 完成  classified%=${pct:-?}"
        return 0
    else
        echo "[$(date +%H:%M:%S)] [${sample}] 失败  (看 ${log})" >&2
        return 1
    fi
}
export -f run_one
export INPUT_DIR OUTDIR KRAKEN2_DB TRIM_DIR K2_DIR LOG_DIR \
       THREADS_PER_JOB KRAKEN2_CONFIDENCE KRAKEN2_USE_NAMES KRAKEN2_USE_MM \
       TRIM_LEN

running_pids=()
running_samples=()
failed_samples=()
count=0

for sample in ${samples}; do
    count=$((count + 1))

    # 等到有空位
    while [[ "${MAX_PARALLEL}" -gt 1 && "${#running_pids[@]}" -ge "${MAX_PARALLEL}" ]]; do
        pid="${running_pids[0]}"
        wait "${pid}" 2>/dev/null
        status=$?
        finished="${running_samples[0]}"
        running_pids=("${running_pids[@]:1}")
        running_samples=("${running_samples[@]:1}")
        [[ "${status}" -ne 0 ]] && failed_samples+=("${finished}")
    done

    # 串行模式直接跑
    if [[ "${MAX_PARALLEL}" -le 1 ]]; then
        if ! run_one "${sample}"; then
            failed_samples+=("${sample}")
        fi
    else
        ( run_one "${sample}" ) &
        running_pids+=( "$!" )
        running_samples+=( "${sample}" )
        echo "[${count}/${total}] ${sample}  -- 已入队"
    fi
done

# drain
if [[ "${MAX_PARALLEL}" -gt 1 ]]; then
    while [[ "${#running_pids[@]}" -gt 0 ]]; do
        pid="${running_pids[0]}"
        wait "${pid}" 2>/dev/null
        status=$?
        finished="${running_samples[0]}"
        running_pids=("${running_pids[@]:1}")
        running_samples=("${running_samples[@]:1}")
        [[ "${status}" -ne 0 ]] && failed_samples+=("${finished}")
    done
fi

echo ""
echo "========================================"
if [[ "${#failed_samples[@]}" -gt 0 ]]; then
    echo "Step 1 完成(有失败 ${#failed_samples[@]}): $(date)"
    printf '  失败样品: %s\n' "${failed_samples[@]}"
    exit 1
fi
echo "Step 1 完成: $(date)"
echo "输出:  ${K2_DIR}"
echo "========================================"
