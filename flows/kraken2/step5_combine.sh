#!/bin/bash
#===============================================================================
# Step 5: Combine all samples' mpa into one table, then split to L1~L8
# 输入: ${OUTDIR}/mpa/*.mpa
# 输出: ${OUTDIR}/combined/bracken.mpa
#       ${OUTDIR}/combined/profile/L1.txt ~ L8.txt  (所有样品并列)
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
MPA2LEVELS_SCRIPT="$(resolve_path "${MPA2LEVELS_SCRIPT}")"
MPA_DIR="${OUTDIR}/mpa"
COMB_DIR="${OUTDIR}/combined"
PROFILE_COMB_DIR="${COMB_DIR}/profile"
LOG_DIR="${OUTDIR}/logs"
mkdir -p "${COMB_DIR}" "${PROFILE_COMB_DIR}" "${LOG_DIR}"

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
if [[ ! -f "${KRAKEN_TOOLS_DIR}/combine_mpa.py" ]]; then
    echo "[FATAL] 找不到 ${KRAKEN_TOOLS_DIR}/combine_mpa.py" >&2
    echo "        请确认 KRAKEN_TOOLS_DIR 指向 jenniferlu717/KrakenTools 目录" >&2
    echo "        该目录应包含 kreport2mpa.py 和 combine_mpa.py" >&2
    exit 1
fi
if [[ ! -f "${MPA2LEVELS_SCRIPT}" ]]; then
    echo "[FATAL] 找不到 ${MPA2LEVELS_SCRIPT}" >&2; exit 1
fi
PY=$(command -v python3 || command -v python)

COMB_MPA="${COMB_DIR}/bracken.mpa"

echo "========================================"
echo "Step 5: Combine all samples -> L1~L8"
echo "========================================"
echo "输入:  ${MPA_DIR}/*.mpa"
echo "合并:  ${COMB_MPA}"
echo "拆表:  ${PROFILE_COMB_DIR}/L{{1..8}}.txt"
echo "开始:  $(date)"
echo ""

shopt -s nullglob
mpas=( "${MPA_DIR}"/*.mpa )
shopt -u nullglob
if [[ "${#mpas[@]}" -eq 0 ]]; then
    echo "错误: ${MPA_DIR} 下没 .mpa, 请先跑 step3" >&2; exit 1
fi
echo "合并:  ${#mpas[@]} 个 mpa 文件"

# combine
if [[ -s "${COMB_MPA}" ]]; then
    echo "  -- ${COMB_MPA} 已存在, 跳过"
else
    "${PY}" "${KRAKEN_TOOLS_DIR}/combine_mpa.py" \
        -i "${mpas[@]}" \
        -o "${COMB_MPA}" 2> "${LOG_DIR}/combine_mpa.log"
fi

# mpa2levels
if [[ -s "${PROFILE_COMB_DIR}/L1.txt" ]]; then
    echo "  -- profile/L1.txt 已存在, 跳过"
else
    echo "  -- 拆 L1~L8"
    "${PY}" "${MPA2LEVELS_SCRIPT}" "${COMB_MPA}" "${PROFILE_COMB_DIR}" \
        > "${LOG_DIR}/mpa2levels_combined.log" 2>&1
fi

echo ""
echo "========================================"
echo "Step 5 完成: $(date)"
echo "合并:  ${COMB_MPA}"
echo "拆表:  ${PROFILE_COMB_DIR}/"
echo "========================================"
