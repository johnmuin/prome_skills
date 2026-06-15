#!/bin/bash
#===============================================================================
# VIRGO2 Pipeline - Configuration File
# 请将此文件复制为 config.sh 并根据项目修改
#===============================================================================

#-------------------------------------------------------------------------------
# 软件路径配置（通常不需要修改）
#-------------------------------------------------------------------------------
export VIRGO2_DIR="/path/to/VIRGO2"
export VIRGO2_SCRIPT="${VIRGO2_DIR}/VIRGO2.py"
export CONDA_ENV="virgo2"
export CONDA_BASE="/path/to/miniconda3"

#-------------------------------------------------------------------------------
# 项目路径配置（根据实际项目修改）
#-------------------------------------------------------------------------------
# 项目根目录
export PROJECT_DIR="/path/to/project"

# 输入数据目录（质控/去宿主后的fastq）
export INPUT_DIR="${PROJECT_DIR}/quality"

# VIRGO2分析输出目录
export VIRGO2_OUTDIR="${PROJECT_DIR}/virgo2_analysis"

# 样品列表文件（可选，如果不存在则自动扫描INPUT_DIR）
export SAMPLE_LIST=""

#-------------------------------------------------------------------------------
# 分析参数配置
#-------------------------------------------------------------------------------
# 线程数
export THREADS=8

# 内存限制（G）
export MEMORY=8

# Map步骤参数
export MAP_COV=1          # 1=使用coverage校正，0=不使用
export MAP_THREADS=8      # map步骤线程数
export MAX_MAP_JOBS=8     # 同时并行的样品数

# Taxonomy步骤参数
export TAX_BACTERIA=0     # 1=仅细菌，0=所有域（包括真菌）
export TAX_FILTER=1       # 1=过滤低丰度，0=不过滤
export TAX_MULTIGENERA=0  # 1=包含多属基因，0=不包含

#-------------------------------------------------------------------------------
# SGE配置（如使用集群）
#-------------------------------------------------------------------------------
export SGE_QUEUE="all.q"
export SGE_VF="8G"        # 虚拟内存
export SGE_P="8"          # CPU数

#===============================================================================
# 以下函数用于加载配置和检查环境
#===============================================================================

load_conda() {
    source "${CONDA_BASE}/etc/profile.d/conda.sh"
    conda activate "${CONDA_ENV}"
}

check_directories() {
    if [[ ! -d "${INPUT_DIR}" ]]; then
        echo "错误: 输入目录不存在: ${INPUT_DIR}"
        exit 1
    fi
    
    mkdir -p "${VIRGO2_OUTDIR}"/{merged_reads,map_results,compiled,taxonomy,logs}
}

get_samples() {
    if [[ -n "${SAMPLE_LIST}" && -f "${SAMPLE_LIST}" ]]; then
        cat "${SAMPLE_LIST}"
    else
        # 自动从INPUT_DIR扫描样品
        ls "${INPUT_DIR}"/*.rmhost_R1.fastq.gz 2>/dev/null | \
            xargs -n1 basename | \
            sed 's/.rmhost_R1.fastq.gz//'
    fi
}

export -f load_conda check_directories get_samples
