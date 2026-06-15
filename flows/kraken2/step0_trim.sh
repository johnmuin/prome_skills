#!/bin/bash
#===============================================================================
# Step 0: Trim / Symlink Reads
# 若 TRIM_LEN>0, 把 .rmhost_R{1,2}.fastq.gz 截断到指定长度
# 若 TRIM_LEN=0,  跳过截断, 直接软链到 trim 目录
# 输出: ${OUTDIR}/trim${TRIM_LEN}/${sample}.trim${TRIM_LEN}_R{1,2}.fastq.gz
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

# resolve paths
INPUT_DIR="$(resolve_path "${INPUT_DIR}")"
OUTDIR="$(resolve_path "${OUTDIR}")"
KRAKEN2_DB="$(resolve_path "${KRAKEN2_DB}")"

# trim dir 名字
if [[ "${TRIM_LEN}" -gt 0 ]]; then
    TRIM_DIR="${OUTDIR}/trim${TRIM_LEN}"
else
    TRIM_DIR="${OUTDIR}/trim0"
fi
mkdir -p "${TRIM_DIR}" "${OUTDIR}/logs"

# 工具检查
load_conda
for tool in seqkit; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "[FATAL] 缺工具 $tool, 在 env ${CONDA_ENV} 里 mamba install seqkit" >&2
        exit 1
    fi
done

echo "========================================"
echo "Step 0: Trim / Symlink  (TRIM_LEN=${TRIM_LEN})"
echo "========================================"
echo "输入:  ${INPUT_DIR}"
echo "输出:  ${TRIM_DIR}"
echo "开始:  $(date)"
echo ""

samples=$(get_samples)
total=$(echo "${samples}" | wc -l | tr -d ' ')
if [[ "${total}" -eq 0 ]]; then
    echo "错误: 在 ${INPUT_DIR} 没找到 *.rmhost_R1.fastq.gz" >&2
    exit 1
fi
echo "样品:  ${total} 个"
echo ""

count=0
for sample in ${samples}; do
    count=$((count + 1))
    R1="${INPUT_DIR}/${sample}.rmhost_R1.fastq.gz"
    R2="${INPUT_DIR}/${sample}.rmhost_R2.fastq.gz"
    if [[ "${TRIM_LEN}" -gt 0 ]]; then
        T1="${TRIM_DIR}/${sample}.trim${TRIM_LEN}_R1.fastq.gz"
        T2="${TRIM_DIR}/${sample}.trim${TRIM_LEN}_R2.fastq.gz"
    else
        T1="${TRIM_DIR}/${sample}.trim0_R1.fastq.gz"
        T2="${TRIM_DIR}/${sample}.trim0_R2.fastq.gz"
    fi

    if [[ -s "$T1" && -s "$T2" ]]; then
        echo "[${count}/${total}] ${sample}  -- 已存在, 跳过"
        continue
    fi

    if [[ ! -f "$R1" || ! -f "$R2" ]]; then
        echo "[${count}/${total}] ${sample}  -- [WARN] 缺 fastq, 跳过" >&2
        continue
    fi

    if [[ "${TRIM_LEN}" -gt 0 ]]; then
        echo "[${count}/${total}] ${sample}  -- 截断到 ${TRIM_LEN}bp"
        seqkit subseq --region "${TRIM_REGION}" -j "${THREADS}" "$R1" -o "$T1" 2>> "${OUTDIR}/logs/${sample}.trim.log"
        seqkit subseq --region "${TRIM_REGION}" -j "${THREADS}" "$R2" -o "$T2" 2>> "${OUTDIR}/logs/${sample}.trim.log"
    else
        echo "[${count}/${total}] ${sample}  -- 跳过截断, 软链"
        ln -sf "$R1" "$T1"
        ln -sf "$R2" "$T2"
    fi
done

echo ""
echo "========================================"
echo "Step 0 完成: $(date)"
echo "输出:  ${TRIM_DIR}"
echo "========================================"
