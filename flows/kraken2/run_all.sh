#!/bin/bash
#===============================================================================
# Run All Steps (Step 0 -> Step 5)
# 失败立即停止 (set -e)
#===============================================================================

set -e

CONFIG_FILE="${1:-config.sh}"
if [[ ! -f "${CONFIG_FILE}" ]]; then
    echo "错误: 配置文件不存在: ${CONFIG_FILE}" >&2
    echo "用法: bash $0 [config_file]" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "########################################"
echo "# Kraken2 全流程"
echo "# 配置: ${CONFIG_FILE}"
echo "# 开始: $(date)"
echo "########################################"

bash "${SCRIPT_DIR}/step0_trim.sh"          "${CONFIG_FILE}"
bash "${SCRIPT_DIR}/step1_kraken2.sh"       "${CONFIG_FILE}"
bash "${SCRIPT_DIR}/step2_bracken.sh"        "${CONFIG_FILE}"
bash "${SCRIPT_DIR}/step3_kreport2mpa.sh"    "${CONFIG_FILE}"
bash "${SCRIPT_DIR}/step4_mpa2levels.sh"     "${CONFIG_FILE}"
bash "${SCRIPT_DIR}/step5_combine.sh"        "${CONFIG_FILE}"

echo "########################################"
echo "# 全部完成: $(date)"
echo "########################################"
