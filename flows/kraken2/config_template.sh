#!/bin/bash
#===============================================================================
# Kraken2 通用分析流程 - 配置文件模板
# 请将此文件复制为 config.sh 并按项目修改
# 用法:  bash step*.sh config.sh
#===============================================================================

#-------------------------------------------------------------------------------
# 软件路径（一般无需改）
#-------------------------------------------------------------------------------
# conda 根
export CONDA_BASE="/path/to/miniconda3"
# 含 kraken2 / bracken / seqkit / python3 的环境名
export CONDA_ENV="kraken2.1.2"
# KrakenTools 目录(含 kreport2mpa.py / combine_mpa.py)
# 来源: https://github.com/jenniferlu717/KrakenTools/
export KRAKEN_TOOLS_DIR="/path/to/KrakenTools"
# 本流程的 mpa2levels 独立脚本
export MPA2LEVELS_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/mpa2levels_standalone.py"

#-------------------------------------------------------------------------------
# 数据库（按 kraken2 库切换）
#-------------------------------------------------------------------------------
# 库根目录（含 hash.k2d / taxo.k2d / opts.k2d / database*mers.kmer_distrib）
export KRAKEN2_DB="/path/to/kraken2_db"
# Bracken 读长, 必须与库内 database*mers.kmer_distrib 一致
#   例: 库里有 database100mers.kmer_distrib → BRACKEN_READ_LEN=100
#       库里有 database150mers.kmer_distrib → BRACKEN_READ_LEN=150
export BRACKEN_READ_LEN="100"

#-------------------------------------------------------------------------------
# 项目路径（按当前项目修改）
#-------------------------------------------------------------------------------
export PROJECT_DIR="/path/to/project"

# 去宿主后的 fastq 目录（含 *.rmhost_R1.fastq.gz / *.rmhost_R2.fastq.gz）
export INPUT_DIR="${PROJECT_DIR}/quality"

# 本流程的输出根目录
export OUTDIR="${PROJECT_DIR}/kraken2_output"

# 样品列表文件（可选, 留空则自动扫 INPUT_DIR）
export SAMPLE_LIST=""

#-------------------------------------------------------------------------------
# 分析参数（按需调整）
#-------------------------------------------------------------------------------
# 线程
export THREADS=16

# Step 0 截断设置
#   TRIM_LEN=0     跳过截断, 直接把 INPUT_DIR 软链到 trim 目录
#   TRIM_LEN=100   截到 100bp (适合 database100mers 的库)
#   TRIM_LEN=150   截到 150bp (适合 database150mers 的库)
export TRIM_LEN=100
# 截断区域 (seqkit --region 语法)
export TRIM_REGION="1:${TRIM_LEN}"

# Step 1 kraken2 参数
export KRAKEN2_CONFIDENCE=0.1
export KRAKEN2_USE_NAMES=1   # 1=--use-names, 0=--use-mpa-style
export KRAKEN2_USE_MM=1      # 1=--memory-mapping (大库友好)

# Step 2 bracken 参数
export BRACKEN_LEVEL="S"     # S/G/F/O/C/P/D
export BRACKEN_THRESHOLD=10

# 并发: 本地并行最多同时跑 N 个样品 (1=串行)
export MAX_PARALLEL=4

#-------------------------------------------------------------------------------
# SGE / SLURM 配置（如果走集群; 当前默认本地）
#-------------------------------------------------------------------------------
export SGE_QUEUE="all.q"
export SGE_VF="64G"
export SGE_P="16"
export SLURM_PARTITION="default"
export SLURM_MEM="64G"
export SLURM_TIME="12:00:00"

#===============================================================================
# 以下函数: 加载配置 / 检查环境 / 解析路径 / 拿样品
#===============================================================================

load_conda() {
    if [[ -f "${CONDA_BASE}/etc/profile.d/conda.sh" ]]; then
        # shellcheck disable=SC1091
        source "${CONDA_BASE}/etc/profile.d/conda.sh"
        conda activate "${CONDA_ENV}" 2>/dev/null || export PATH="${CONDA_BASE}/envs/${CONDA_ENV}/bin:${PATH}"
    else
        export PATH="${CONDA_BASE}/envs/${CONDA_ENV}/bin:${PATH}"
    fi
}

resolve_path() {
    local value="$1"
    case "${value}" in
        "~")      printf '%s\n' "${HOME}" ;;
        "~/"*)    printf '%s/%s\n' "${HOME}" "${value#~/}" ;;
        /*)       printf '%s\n' "${value}" ;;
        *)        printf '%s\n' "${value}" ;;
    esac
}

check_directories() {
    if [[ ! -d "${INPUT_DIR}" ]]; then
        echo "错误: 输入目录不存在: ${INPUT_DIR}" >&2
        return 1
    fi
    if [[ ! -d "${KRAKEN2_DB}" ]]; then
        echo "错误: kraken2 库不存在: ${KRAKEN2_DB}" >&2
        return 1
    fi
    mkdir -p "${OUTDIR}"/{trim,trim${TRIM_LEN},kraken2,bracken,mpa,profile,combined,logs}
}

get_samples() {
    if [[ -n "${SAMPLE_LIST}" && -f "${SAMPLE_LIST}" ]]; then
        cat "${SAMPLE_LIST}"
    else
        ls "${INPUT_DIR}"/*.rmhost_R1.fastq.gz 2>/dev/null | \
            xargs -n1 basename | sed 's/.rmhost_R1.fastq.gz//'
    fi
}

export -f load_conda resolve_path check_directories get_samples
