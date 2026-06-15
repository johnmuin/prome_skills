#!/bin/bash
#===============================================================================
# Status: report progress for each VIRGO2 workflow step.
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

resolve_path() {
    local value="$1"
    case "${value}" in
        "~")       printf '%s\n' "${HOME}" ;;
        "~/"*)     printf '%s/%s\n' "${HOME}" "${value#~/}" ;;
        /*)        printf '%s\n' "${value}" ;;
        *)         printf '%s/%s\n' "${CONFIG_DIR}" "${value}" ;;
    esac
}

VIRGO2_OUTDIR="$(resolve_path "${VIRGO2_OUTDIR}")"

# Discover samples from step1 output (merged reads), falling back to input dir
get_samples() {
    if [[ -n "${SAMPLE_LIST:-}" && -f "${SAMPLE_LIST}" ]]; then
        cat "${SAMPLE_LIST}"
    else
        ls "${INPUT_DIR}"/*.rmhost_R1.fastq.gz 2>/dev/null | \
            xargs -n1 basename | sed 's/.rmhost_R1.fastq.gz//'
    fi
}
samples=$(get_samples)
total=$(echo "${samples}" | wc -l | tr -d ' ')

count_completed() {
    local dir="$1" pattern="$2"
    shopt -s nullglob
    local files=( "${dir}"/${pattern} )
    shopt -u nullglob
    echo "${#files[@]}"
}

count_log_errors() {
    local log_dir="${VIRGO2_OUTDIR}/logs"
    local step_pattern="$1"
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
declare -a STEP_NAMES STEP_DIRS STEP_GLOBS STEP_KEYS STEP_LOG_PATTERNS

STEP_NAMES[0]="step1_merge"
STEP_DIRS[0]="${VIRGO2_OUTDIR}/merged_reads"
STEP_GLOBS[0]="*.merged.fastq.gz"
STEP_KEYS[0]="${VIRGO2_OUTDIR}/merged_reads"
STEP_LOG_PATTERNS[0]="*.merge.log"

STEP_NAMES[1]="step2_map"
STEP_DIRS[1]="${VIRGO2_OUTDIR}/map_results"
STEP_GLOBS[1]="*.out"
STEP_KEYS[1]="${VIRGO2_OUTDIR}/map_results"
STEP_LOG_PATTERNS[1]="*.map.log"

STEP_NAMES[2]="step3_compile"
STEP_DIRS[2]="${VIRGO2_OUTDIR}/compiled"
STEP_GLOBS[2]="VIRGO2_compiled.summary.NR.txt"
STEP_KEYS[2]="${VIRGO2_OUTDIR}/compiled/VIRGO2_compiled.summary.NR.txt"
STEP_LOG_PATTERNS[2]="*.compile.log"

STEP_NAMES[3]="step4_taxonomy"
STEP_DIRS[3]="${VIRGO2_OUTDIR}/taxonomy"
STEP_GLOBS[3]="VIRGO2_taxonomy.relAbund.csv"
STEP_KEYS[3]="${VIRGO2_OUTDIR}/taxonomy/VIRGO2_taxonomy.relAbund.csv"
STEP_LOG_PATTERNS[3]="*.taxonomy.log"

STEP_NAMES[4]="step5_annotate"
STEP_DIRS[4]="${VIRGO2_OUTDIR}/annotation"
STEP_GLOBS[4]="VIRGO2_annotated_all_annotations.csv"
STEP_KEYS[4]="${VIRGO2_OUTDIR}/annotation/VIRGO2_annotated_all_annotations.csv"
STEP_LOG_PATTERNS[4]="*.annotate.log"

# ---- Compute status per step ------------------------------------------------
declare -a STEP_COMPLETED STEP_MISSING STEP_ERROR_LOGS

for i in "${!STEP_NAMES[@]}"; do
    dir="${STEP_DIRS[$i]}"
    glob="${STEP_GLOBS[$i]}"

    if [[ ! -d "${dir}" ]]; then
        STEP_COMPLETED[$i]=0
        STEP_MISSING[$i]="${total}"
        STEP_ERROR_LOGS[$i]=0
        continue
    fi

    completed=$(count_completed "${dir}" "${glob}")
    STEP_COMPLETED[$i]="${completed}"

    # For aggregate steps (compile/taxonomy/annotate), 1 output is "complete"
    # For per-sample steps (merge/map), count vs total
    if [[ $i -ge 2 ]]; then
        # Aggregate steps: completed is 1 or 0
        STEP_MISSING[$i]=$(( 1 - completed ))
    else
        missing=$(( total - completed ))
        STEP_MISSING[$i]="${missing}"
    fi

    err_count=$(count_log_errors "${STEP_LOG_PATTERNS[$i]}")
    STEP_ERROR_LOGS[$i]="${err_count}"
done

# ---- Output -----------------------------------------------------------------
if [[ "${OUTPUT_MODE}" == "json" ]]; then
    echo "{"
    echo "  \"workflow\": \"virgo2\","
    echo "  \"config\": \"${CONFIG_FILE}\","
    echo "  \"outdir\": \"${VIRGO2_OUTDIR}\","
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
      "completed": ${STEP_COMPLETED[$i]},
      "missing": ${STEP_MISSING[$i]},
      "error_logs": ${STEP_ERROR_LOGS[$i]},
      "output_dir": "${STEP_DIRS[$i]}",
      "key_output": "${STEP_KEYS[$i]}"
    }
EOF
    done
    echo ""
    echo "  ],"
    echo "  \"log_dir\": \"${VIRGO2_OUTDIR}/logs\""
    echo "}"
else
    echo "========================================"
    echo "VIRGO2 Workflow Status"
    echo "Config:   ${CONFIG_FILE}"
    echo "Outdir:   ${VIRGO2_OUTDIR}"
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

        if [[ $i -ge 2 ]]; then
            # Aggregate steps
            if [[ "${completed}" -ge 1 ]]; then
                status="DONE"
            else
                status="PENDING"
            fi
            printf "%-22s %12s %12s %12s %12s\n" \
                "${STEP_NAMES[$i]}" "${completed}/1" "${missing}" "${errors}" "${status}"
        else
            # Per-sample steps
            if [[ "${completed}" -ge "${total}" && "${total}" -gt 0 ]]; then
                status="DONE"
            elif [[ "${completed}" -gt 0 ]]; then
                status="PARTIAL"
            else
                status="PENDING"
            fi
            printf "%-22s %12s %12s %12s %12s\n" \
                "${STEP_NAMES[$i]}" "${completed}/${total}" "${missing}" "${errors}" "${status}"
        fi
    done

    echo ""
    echo "Key outputs:"
    for i in "${!STEP_NAMES[@]}"; do
        echo "  ${STEP_NAMES[$i]}: ${STEP_KEYS[$i]}"
    done
    echo "  logs: ${VIRGO2_OUTDIR}/logs"

    total_errors=0
    for i in "${!STEP_NAMES[@]}"; do
        total_errors=$(( total_errors + STEP_ERROR_LOGS[$i] ))
    done
    if [[ "${total_errors}" -gt 0 ]]; then
        echo ""
        echo "WARNING: ${total_errors} log file(s) contain error indicators."
        echo "Run: grep -liE '(error|fatal|exception)' ${VIRGO2_OUTDIR}/logs/*.log"
    fi

    echo ""
    echo "Per-sample detail:"
    echo "  (use --json for machine-readable per-sample status)"
    echo "  Sample list:"
    for sample in ${samples}; do
        markers=""
        if [[ -s "${VIRGO2_OUTDIR}/merged_reads/${sample}.merged.fastq.gz" ]]; then
            markers="${markers}1"
        else
            markers="${markers}-"
        fi
        markers="${markers} "
        if [[ -s "${VIRGO2_OUTDIR}/map_results/${sample}.out" ]]; then
            markers="${markers}2"
        else
            markers="${markers}-"
        fi
        echo "  ${sample}  [${markers}]  (steps: 1=merge 2=map; 3=compile 4=taxonomy 5=annotate are aggregate)"
    done
fi
