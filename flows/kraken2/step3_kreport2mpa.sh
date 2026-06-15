#!/bin/bash
#===============================================================================
# Step 3: kreport -> mpa (per sample)
# 输入: ${OUTDIR}/bracken/${sample}.bracken.kreport
# 输出: ${OUTDIR}/mpa/${sample}.mpa
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
if [[ -z "${KRAKEN_TOOLS_DIR:-}" ]]; then
    echo "[FATAL] 未配置 KRAKEN_TOOLS_DIR" >&2
    echo "        需要准备 KrakenTools: https://github.com/jenniferlu717/KrakenTools/" >&2
    echo "        配置示例: export KRAKEN_TOOLS_DIR=\"/path/to/KrakenTools\"" >&2
    exit 1
fi
KRAKEN_TOOLS_DIR="$(resolve_path "${KRAKEN_TOOLS_DIR}")"
BR_DIR="${OUTDIR}/bracken"
MPA_DIR="${OUTDIR}/mpa"
LOG_DIR="${OUTDIR}/logs"
mkdir -p "${MPA_DIR}" "${LOG_DIR}"

load_conda
for tool in python python3; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "[FATAL] 缺工具 $tool" >&2; exit 1
    fi
done

if [[ ! -d "${KRAKEN_TOOLS_DIR}" ]]; then
    echo "[FATAL] KrakenTools 目录不存在: ${KRAKEN_TOOLS_DIR}" >&2
    echo "        需要准备 KrakenTools: https://github.com/jenniferlu717/KrakenTools/" >&2
    echo "        配置示例: export KRAKEN_TOOLS_DIR=\"/path/to/KrakenTools\"" >&2
    exit 1
fi
if [[ ! -f "${KRAKEN_TOOLS_DIR}/kreport2mpa.py" ]]; then
    echo "[FATAL] 找不到 ${KRAKEN_TOOLS_DIR}/kreport2mpa.py" >&2
    echo "        请确认 KRAKEN_TOOLS_DIR 指向 jenniferlu717/KrakenTools 目录" >&2
    echo "        该目录应包含 kreport2mpa.py 和 combine_mpa.py" >&2
    exit 1
fi
PY=$(command -v python3 || command -v python)

echo "========================================"
echo "Step 3: kreport -> mpa"
echo "========================================"
echo "输入:  ${BR_DIR}"
echo "输出:  ${MPA_DIR}"
echo "开始:  $(date)"
echo ""

samples=$(get_samples)
total=$(echo "${samples}" | wc -l | tr -d ' ')
echo "样品:  ${total} 个"
echo ""

count=0
for sample in ${samples}; do
    count=$((count + 1))
    bkrep="${BR_DIR}/${sample}.bracken.kreport"
    mpa="${MPA_DIR}/${sample}.mpa"

    if [[ -s "$mpa" ]]; then
        echo "[${count}/${total}] ${sample}  -- 已存在, 跳过"
        continue
    fi
    if [[ ! -s "$bkrep" ]]; then
        echo "[${count}/${total}] ${sample}  -- [WARN] 缺 bracken.kreport, 跳过" >&2
        continue
    fi

    echo "[${count}/${total}] ${sample}  -- kreport2mpa"
    "${PY}" "${KRAKEN_TOOLS_DIR}/kreport2mpa.py" \
        --display-header \
        -r "${bkrep}" \
        -o "${mpa}" 2> "${LOG_DIR}/${sample}.kreport2mpa.log"
done

echo ""
echo "========================================"
echo "Step 3 完成: $(date)"
echo "输出:  ${MPA_DIR}"
echo "========================================"
