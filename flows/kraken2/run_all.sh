#!/bin/bash
#===============================================================================
# Run All Steps (Step 0 -> Step 5)
#
# Usage:
#   bash run_all.sh config.sh                   Stop on first failure (default)
#   bash run_all.sh config.sh --continue-on-error  Run all steps, report summary
#===============================================================================

CONTINUE_ON_ERROR=false
CONFIG_FILE=""

for arg in "$@"; do
    case "$arg" in
        --continue-on-error)
            CONTINUE_ON_ERROR=true
            ;;
        *)
            if [[ -z "${CONFIG_FILE}" ]]; then
                CONFIG_FILE="$arg"
            fi
            ;;
    esac
done

CONFIG_FILE="${CONFIG_FILE:-config.sh}"

if [[ ! -f "${CONFIG_FILE}" ]]; then
    echo "错误: 配置文件不存在: ${CONFIG_FILE}" >&2
    echo "用法: bash $0 [config_file] [--continue-on-error]" >&2
    exit 1
fi

if [[ "${CONTINUE_ON_ERROR}" != "true" ]]; then
    set -e
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source config to inspect TRIM_LEN for step0 skip decision
CONFIG_DIR="$(cd "$(dirname "${CONFIG_FILE}")" && pwd)"
# shellcheck disable=SC1090
source "${CONFIG_FILE}"

SKIP_STEP0=false
if [[ "${TRIM_LEN:-0}" == "0" ]]; then
    SKIP_STEP0=true
fi

echo "########################################"
echo "# Kraken2 全流程"
echo "# 配置: ${CONFIG_FILE}"
echo "# 模式: $([[ "${CONTINUE_ON_ERROR}" == "true" ]] && echo 'continue-on-error' || echo 'stop-on-error')"
echo "# 开始: $(date)"
echo "########################################"

declare -a STEP_NAMES STEP_SCRIPTS STEP_EXIT_CODES

if [[ "${SKIP_STEP0}" == "true" ]]; then
    echo ""
    echo ">>> step0_trim -- 跳过 (TRIM_LEN=0, 不需要截断)"
    STEP_EXIT_CODES[0]=0
else
    STEP_NAMES[0]="step0_trim"
    STEP_SCRIPTS[0]="step0_trim.sh"
fi

STEP_NAMES[1]="step1_kraken2"
STEP_SCRIPTS[1]="step1_kraken2.sh"

STEP_NAMES[2]="step2_bracken"
STEP_SCRIPTS[2]="step2_bracken.sh"

STEP_NAMES[3]="step3_kreport2mpa"
STEP_SCRIPTS[3]="step3_kreport2mpa.sh"

STEP_NAMES[4]="step4_mpa2levels"
STEP_SCRIPTS[4]="step4_mpa2levels.sh"

STEP_NAMES[5]="step5_combine"
STEP_SCRIPTS[5]="step5_combine.sh"

failed_steps=0
passed_steps=0

for i in "${!STEP_NAMES[@]}"; do
    name="${STEP_NAMES[$i]}"
    script="${STEP_SCRIPTS[$i]}"

    echo ""
    echo ">>> Running ${name} ..."

    exit_code=0
    bash "${SCRIPT_DIR}/${script}" "${CONFIG_FILE}" || exit_code=$?

    STEP_EXIT_CODES[$i]=${exit_code}

    if [[ ${exit_code} -ne 0 ]]; then
        echo "<<< ${name} FAILED (exit ${exit_code})"
        failed_steps=$((failed_steps + 1))
        if [[ "${CONTINUE_ON_ERROR}" != "true" ]]; then
            echo "########################################"
            echo "# 中断: ${name} 失败"
            echo "# 时间: $(date)"
            echo "########################################"
            exit ${exit_code}
        fi
    else
        echo "<<< ${name} OK"
        passed_steps=$((passed_steps + 1))
    fi
done

echo ""
echo "########################################"
if [[ "${CONTINUE_ON_ERROR}" == "true" ]]; then
    total=$(( passed_steps + failed_steps ))
    echo "# 完成 (continue-on-error): $(date)"
    echo "# 通过: ${passed_steps}/${total}"
    if [[ ${failed_steps} -gt 0 ]]; then
        echo "# 失败: ${failed_steps}/${total}"
        for i in "${!STEP_NAMES[@]}"; do
            if [[ "${STEP_EXIT_CODES[$i]}" -ne 0 ]]; then
                echo "#   - ${STEP_NAMES[$i]} (exit ${STEP_EXIT_CODES[$i]})"
            fi
        done
    fi
    if [[ ${failed_steps} -gt 0 ]]; then
        exit 1
    fi
else
    echo "# 全部完成: $(date)"
fi
echo "########################################"
