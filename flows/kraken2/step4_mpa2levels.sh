#!/bin/bash
#===============================================================================
# Step 4: mpa -> L1~L8  (per sample)
# 输入: ${OUTDIR}/mpa/${sample}.mpa
# 输出: ${OUTDIR}/profile/${sample}/L1.txt ~ L8.txt
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
MPA2LEVELS_SCRIPT="$(resolve_path "${MPA2LEVELS_SCRIPT}")"
MPA_DIR="${OUTDIR}/mpa"
PROFILE_DIR="${OUTDIR}/profile"
LOG_DIR="${OUTDIR}/logs"
mkdir -p "${PROFILE_DIR}" "${LOG_DIR}"

load_conda
for tool in python python3; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "[FATAL] 缺工具 $tool" >&2; exit 1
    fi
done
if [[ ! -f "${MPA2LEVELS_SCRIPT}" ]]; then
    echo "[FATAL] 找不到 ${MPA2LEVELS_SCRIPT}" >&2
    exit 1
fi
PY=$(command -v python3 || command -v python)

echo "========================================"
echo "Step 4: mpa -> L1~L8"
echo "========================================"
echo "输入:  ${MPA_DIR}"
echo "输出:  ${PROFILE_DIR}/<sample>/L{{1..8}}.txt"
echo "开始:  $(date)"
echo ""

samples=$(get_samples)
total=$(echo "${samples}" | wc -l | tr -d ' ')
echo "样品:  ${total} 个"
echo ""

count=0
for sample in ${samples}; do
    count=$((count + 1))
    mpa="${MPA_DIR}/${sample}.mpa"
    out="${PROFILE_DIR}/${sample}"

    if [[ -s "${out}/L1.txt" && -s "${out}/L7.txt" ]]; then
        echo "[${count}/${total}] ${sample}  -- 已存在, 跳过"
        continue
    fi
    if [[ ! -s "$mpa" ]]; then
        echo "[${count}/${total}] ${sample}  -- [WARN] 缺 mpa, 跳过" >&2
        continue
    fi

    echo "[${count}/${total}] ${sample}  -- mpa2levels"
    "${PY}" "${MPA2LEVELS_SCRIPT}" "${mpa}" "${out}" \
        > "${LOG_DIR}/${sample}.mpa2levels.log" 2>&1
done

echo ""
echo "========================================"
echo "Step 4 完成: $(date)"
echo "输出:  ${PROFILE_DIR}/"
echo "========================================"
