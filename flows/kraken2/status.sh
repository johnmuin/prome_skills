#!/bin/bash
#===============================================================================
# Status: report progress for each Kraken2 workflow step.
#
# Usage:
#   bash status.sh config.sh          human-readable summary
#   bash status.sh config.sh --json   machine-readable JSON
#===============================================================================

set -u

CONFIG_FILE="${1:-config.sh}"
OUTPUT_MODE="text"
if [[ "${2:-}" == "--json" ]]; then
    OUTPUT_MODE="json"
fi

if [[ ! -f "${CONFIG_FILE}" ]]; then
    if [[ "${OUTPUT_MODE}" == "json" ]]; then
        echo '{"error":"config file not found"}'
    else
        echo "Error: config file not found: ${CONFIG_FILE}"
    fi
    exit 1
fi

CONFIG_DIR="$(cd "$(dirname "${CONFIG_FILE}")" && pwd)"
# shellcheck disable=SC1090
source "${CONFIG_FILE}"

OUTDIR="$(resolve_path "${OUTDIR}")"
if [[ "${TRIM_LEN:-0}" -gt 0 ]]; then
    TRIM_DIR="${OUTDIR}/trim${TRIM_LEN}"
else
    TRIM_DIR="${OUTDIR}/trim0"
fi

samples=$(get_samples)
total=$(echo "${samples}" | wc -l | tr -d ' ')

# Count completed outputs for a step pattern.
# Usage: count_completed <dir> <glob_pattern>
count_completed() {
    local dir="$1" pattern="$2"
    shopt -s nullglob
    local files=( "${dir}"/${pattern} )
    shopt -u nullglob
    echo "${#files[@]}"
}

# Find log files with possible error indicators.
# Returns count of log files containing errors.
count_log_errors() {
    local log_dir="${OUTDIR}/logs"
    local step_pattern="$1"  # e.g. "*.kraken2.log"
    local count=0
    shopt -s nullglob
    for log in "${log_dir}"/${step_pattern}; do
        if grep -qiE '(error|fatal|exception|traceback|killed|segfault|out of memory)' "$log" 2>/dev/null; then
            count=$((count + 1))
        fi
    done
    shopt -u nullglob
    echo "${count}"
}

# ---- Step definitions -------------------------------------------------------
# Each step: name, output_dir, completed_glob, key_output_desc, aggregate (1=aggregate)
declare -a STEP_NAMES STEP_DIRS STEP_GLOBS STEP_KEYS STEP_LOG_PATTERNS STEP_AGGREGATE

STEP_NAMES[0]="step0_trim"
STEP_DIRS[0]="${TRIM_DIR}"
STEP_GLOBS[0]="*_R1.fastq.gz"
STEP_KEYS[0]="${TRIM_DIR}"
STEP_LOG_PATTERNS[0]="*.trim.log"
STEP_AGGREGATE[0]=0

STEP_NAMES[1]="step1_kraken2"
STEP_DIRS[1]="${OUTDIR}/kraken2"
STEP_GLOBS[1]="*.kreport2"
STEP_KEYS[1]="${OUTDIR}/kraken2"
STEP_LOG_PATTERNS[1]="*.kraken2.log"
STEP_AGGREGATE[1]=0

STEP_NAMES[2]="step2_bracken"
STEP_DIRS[2]="${OUTDIR}/bracken"
STEP_GLOBS[2]="*.bracken.kreport"
STEP_KEYS[2]="${OUTDIR}/bracken"
STEP_LOG_PATTERNS[2]="*.bracken.log"
STEP_AGGREGATE[2]=0

STEP_NAMES[3]="step3_kreport2mpa"
STEP_DIRS[3]="${OUTDIR}/mpa"
STEP_GLOBS[3]="*.mpa"
STEP_KEYS[3]="${OUTDIR}/mpa"
STEP_LOG_PATTERNS[3]="*.kreport2mpa.log"
STEP_AGGREGATE[3]=0

STEP_NAMES[4]="step4_mpa2levels"
STEP_DIRS[4]="${OUTDIR}/profile"
STEP_GLOBS[4]="*/L1.txt"
STEP_KEYS[4]="${OUTDIR}/profile"
STEP_LOG_PATTERNS[4]="*.mpa2levels.log"
STEP_AGGREGATE[4]=0

STEP_NAMES[5]="step5_combine"
STEP_DIRS[5]="${OUTDIR}/combined/profile"
STEP_GLOBS[5]="L1.txt"
STEP_KEYS[5]="${OUTDIR}/combined/bracken.mpa + ${OUTDIR}/combined/profile/"
STEP_LOG_PATTERNS[5]="combine_mpa.log"
STEP_AGGREGATE[5]=1

# ---- Compute status per step ------------------------------------------------
declare -a STEP_COMPLETED STEP_FAILED STEP_MISSING STEP_ERROR_LOGS STEP_EXPECTED

for i in "${!STEP_NAMES[@]}"; do
    dir="${STEP_DIRS[$i]}"
    glob="${STEP_GLOBS[$i]}"

    if [[ ! -d "${dir}" ]]; then
        STEP_COMPLETED[$i]=0
        STEP_FAILED[$i]=0
        STEP_MISSING[$i]="${total}"
        STEP_ERROR_LOGS[$i]=0
        STEP_EXPECTED[$i]=$([[ "${STEP_AGGREGATE[$i]}" -eq 1 ]] && echo 1 || echo "${total}")
        continue
    fi

    completed=$(count_completed "${dir}" "${glob}")
    STEP_COMPLETED[$i]="${completed}"

    if [[ "${STEP_AGGREGATE[$i]}" -eq 1 ]]; then
        expected=1
    else
        expected="${total}"
    fi
    missing=$(( expected - completed ))
    STEP_MISSING[$i]="${missing}"
    STEP_EXPECTED[$i]="${expected}"

    # Check log errors for this step
    err_count=$(count_log_errors "${STEP_LOG_PATTERNS[$i]}")
    STEP_ERROR_LOGS[$i]="${err_count}"

    # Failed = samples with log errors but no output
    # This is approximate; real diagnosis needs manual log inspection
    STEP_FAILED[$i]=0
done

# ---- Output -----------------------------------------------------------------
if [[ "${OUTPUT_MODE}" == "json" ]]; then
    echo "{"
    echo "  \"workflow\": \"kraken2\","
    echo "  \"config\": \"${CONFIG_FILE}\","
    echo "  \"outdir\": \"${OUTDIR}\","
    echo "  \"total_samples\": ${total},"
    echo "  \"samples\": ["
    first_sample=true
    for sample in ${samples}; do
        [[ "${first_sample}" == "true" ]] && first_sample=false || echo ","
        printf '    "%s"' "$sample"
    done
    echo ""
    echo "  ],"
    echo "  \"steps\": ["
    for i in "${!STEP_NAMES[@]}"; do
        [[ $i -gt 0 ]] && echo ","
        cat <<EOF
    {
      "step": "${STEP_NAMES[$i]}",
      "aggregate": ${STEP_AGGREGATE[$i]},
      "completed": ${STEP_COMPLETED[$i]},
      "expected": ${STEP_EXPECTED[$i]},
      "missing": ${STEP_MISSING[$i]},
      "error_logs": ${STEP_ERROR_LOGS[$i]},
      "output_dir": "${STEP_DIRS[$i]}",
      "key_output": "${STEP_KEYS[$i]}"
    }
EOF
    done
    echo ""
    echo "  ],"
    echo "  \"log_dir\": \"${OUTDIR}/logs\""
    echo "}"
else
    echo "========================================"
    echo "Kraken2 Workflow Status"
    echo "Config:   ${CONFIG_FILE}"
    echo "Outdir:   ${OUTDIR}"
    echo "Samples:  ${total}"
    echo "Time:     $(date)"
    echo "========================================"
    echo ""
    printf "%-22s %12s %12s %12s %12s\n" "Step" "Completed" "Missing" "ErrorLogs" "Status"
    printf "%-22s %12s %12s %12s %12s\n" "--------------------" "----------" "----------" "----------" "----------"

    for i in "${!STEP_NAMES[@]}"; do
        completed="${STEP_COMPLETED[$i]}"
        missing="${STEP_MISSING[$i]}"
        errors="${STEP_ERROR_LOGS[$i]}"

        expected="${STEP_EXPECTED[$i]}"
        if [[ "${completed}" -ge "${expected}" && "${expected}" -gt 0 ]]; then
            status="DONE"
        elif [[ "${completed}" -gt 0 ]]; then
            status="PARTIAL"
        else
            status="PENDING"
        fi

        printf "%-22s %12s %12s %12s %12s\n" \
            "${STEP_NAMES[$i]}" "${completed}/${expected}" "${missing}" "${errors}" "${status}"
    done

    echo ""
    echo "Key outputs:"
    for i in "${!STEP_NAMES[@]}"; do
        echo "  ${STEP_NAMES[$i]}: ${STEP_KEYS[$i]}"
    done
    echo "  logs: ${OUTDIR}/logs"

    # Highlight issues
    total_errors=0
    for i in "${!STEP_NAMES[@]}"; do
        total_errors=$(( total_errors + STEP_ERROR_LOGS[$i] ))
    done
    if [[ "${total_errors}" -gt 0 ]]; then
        echo ""
        echo "WARNING: ${total_errors} log file(s) contain error indicators."
        echo "Run: grep -liE '(error|fatal|exception)' ${OUTDIR}/logs/*.log"
    fi

    # Show sample-level detail for per-sample steps (skip aggregate step 5)
    echo ""
    echo "Per-sample detail:"
    echo "  (use --json for machine-readable per-sample status)"
    echo "  Sample list:"
    for sample in ${samples}; do
        markers=""
        if [[ -s "${TRIM_DIR}/${sample}.trim${TRIM_LEN:-0}_R1.fastq.gz" ]]; then
            markers="${markers}0"
        else
            markers="${markers}-"
        fi
        markers="${markers} "
        if [[ -s "${OUTDIR}/kraken2/${sample}.kreport2" ]]; then
            markers="${markers}1"
        else
            markers="${markers}-"
        fi
        markers="${markers} "
        if [[ -s "${OUTDIR}/bracken/${sample}.bracken.kreport" ]]; then
            markers="${markers}2"
        else
            markers="${markers}-"
        fi
        markers="${markers} "
        if [[ -s "${OUTDIR}/mpa/${sample}.mpa" ]]; then
            markers="${markers}3"
        else
            markers="${markers}-"
        fi
        markers="${markers} "
        if [[ -s "${OUTDIR}/profile/${sample}/L1.txt" ]]; then
            markers="${markers}4"
        else
            markers="${markers}-"
        fi
        markers="${markers} "
        if [[ -s "${OUTDIR}/combined/bracken.mpa" ]]; then
            markers="${markers}5"
        else
            markers="${markers}-"
        fi
        echo "  ${sample}  [${markers}]  (steps: 0=trim 1=kraken2 2=bracken 3=mpa 4=levels 5=combine)"
    done
fi
