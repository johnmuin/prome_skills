#!/bin/bash
#===============================================================================
# Step 2: Bracken Abundance Re-estimation
# 输入: ${OUTDIR}/kraken2/${sample}.kreport2
# 输出: ${OUTDIR}/bracken/${sample}.bracken
#       ${OUTDIR}/bracken/${sample}.bracken.kreport
#===============================================================================

set -u

CONFIG_FILE="${1:-config.sh}"
if [[ ! -f "${CONFIG_FILE}" ]]; then
    echo "错误: 配置文件不存在: ${CONFIG_FILE}" >&2
    exit 1
fi

CONFIG_DIR="$(cd "$(dirname "${CONFIG_FILE}")" && pwd)"
# shellcheck disable=SC1090
source "${CONFIG_FILE}"

OUTDIR="$(resolve_path "${OUTDIR}")"
KRAKEN2_DB="$(resolve_path "${KRAKEN2_DB}")"
K2_DIR="${OUTDIR}/kraken2"
BR_DIR="${OUTDIR}/bracken"
LOG_DIR="${OUTDIR}/logs"
mkdir -p "${BR_DIR}" "${LOG_DIR}"

load_conda
for tool in bracken; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "[FATAL] 缺工具 $tool" >&2; exit 1
    fi
done

# 检查 kmer 分布文件存在
KMER_DIST="${KRAKEN2_DB}/database${BRACKEN_READ_LEN}mers.kmer_distrib"
if [[ ! -f "${KMER_DIST}" ]]; then
    echo "[FATAL] 缺 kmer 分布: ${KMER_DIST}" >&2
    echo "        BRACKEN_READ_LEN=${BRACKEN_READ_LEN}, 与库不匹配" >&2
    exit 1
fi

echo "========================================"
echo "Step 2: Bracken Re-estimation"
echo "========================================"
echo "库:    ${KRAKEN2_DB}"
echo "读长:  ${BRACKEN_READ_LEN}"
echo "层级:  ${BRACKEN_LEVEL}  阈值:  ${BRACKEN_THRESHOLD}"
echo "开始:  $(date)"
echo ""

samples=$(get_samples)
total=$(echo "${samples}" | wc -l | tr -d ' ')
if [[ "${total}" -eq 0 ]]; then
    echo "错误: 没找到样品" >&2; exit 1
fi
echo "样品:  ${total} 个"
echo ""

count=0
failed=()
for sample in ${samples}; do
    count=$((count + 1))
    krep="${K2_DIR}/${sample}.kreport2"
    bout="${BR_DIR}/${sample}.bracken"
    bkrep="${BR_DIR}/${sample}.bracken.kreport"
    log="${LOG_DIR}/${sample}.bracken.log"

    if [[ -s "$bkrep" ]]; then
        echo "[${count}/${total}] ${sample}  -- 已存在, 跳过"
        continue
    fi
    if [[ ! -s "$krep" ]]; then
        echo "[${count}/${total}] ${sample}  -- [WARN] 缺 kreport2, 跳过" >&2
        continue
    fi

    echo "[${count}/${total}] ${sample}  -- bracken"
    bracken \
        -d "${KRAKEN2_DB}" \
        -i "${krep}" \
        -o "${bout}" \
        -w "${bkrep}" \
        -r "${BRACKEN_READ_LEN}" \
        -l "${BRACKEN_LEVEL}" \
        -t "${BRACKEN_THRESHOLD}" 2> "${log}"

    if [[ ! -s "$bkrep" ]]; then
        failed+=("${sample}")
        echo "  失败, 看 ${log}" >&2
    fi
done

echo ""
echo "========================================"
if [[ "${#failed[@]}" -gt 0 ]]; then
    echo "Step 2 完成(有失败 ${#failed[@]}): $(date)"
    printf '  失败样品: %s\n' "${failed[@]}"
    exit 1
fi
echo "Step 2 完成: $(date)"
echo "输出:  ${BR_DIR}"
echo "========================================"
