#!/usr/bin/env bash
#
# Run the deterministic replay or invoke the prepared live VM sequence.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
readonly RSIGMA="${SCRIPT_DIR}/.state/bin/rsigma"
readonly OUTPUT_DIR="${SCRIPT_DIR}/output"

err() {
  echo "error: $*" >&2
}

show_usage() {
  cat <<EOF
Usage: ${0##*/} --replay|--live

  --replay  Evaluate the pinned malicious and benign fixtures locally.
  --live    Run the prepared attack sequence inside the Multipass VM.
EOF
}

run_eval() {
  local fixture="$1"
  local output="$2"

  "${RSIGMA}" engine eval \
    --rules "${SCRIPT_DIR}/rules" \
    --event "@${fixture}" \
    --schema-routing \
    --schema-config "${SCRIPT_DIR}/schema-routing.yml" \
    --timestamp-field "@timestamp" \
    --output-format ndjson \
    >"${output}"
}

replay() {
  local malicious_output="${OUTPUT_DIR}/malicious.ndjson"
  local benign_output="${OUTPUT_DIR}/benign.ndjson"
  local actual_titles="${OUTPUT_DIR}/malicious-titles.json"
  local backtest_output="${OUTPUT_DIR}/backtest.json"

  "${SCRIPT_DIR}/fetch-rsigma.sh" >/dev/null
  mkdir -p "${OUTPUT_DIR}"

  run_eval "${SCRIPT_DIR}/fixtures/malicious.ndjson" "${malicious_output}"
  run_eval "${SCRIPT_DIR}/fixtures/benign.ndjson" "${benign_output}"

  jq -s 'map(.rule_title)' "${malicious_output}" >"${actual_titles}"
  if ! diff -u \
    "${SCRIPT_DIR}/expected/malicious-titles.json" \
    "${actual_titles}"; then
    err "malicious replay did not produce the expected sequence"
    return 1
  fi

  if [[ -s "${benign_output}" ]]; then
    err "benign replay produced an unexpected detection"
    cat "${benign_output}" >&2
    return 1
  fi

  "${RSIGMA}" rule backtest \
    --rules "${SCRIPT_DIR}/rules" \
    --corpus "${SCRIPT_DIR}/fixtures" \
    --expectations "${SCRIPT_DIR}/expectations.yml" \
    --pipeline "${SCRIPT_DIR}/pipelines/tetragon.yml" \
    --unexpected fail \
    --output-format json \
    >"${backtest_output}"

  jq -r '"\(.level | ascii_upcase)\t\(.rule_title)"' "${malicious_output}"
  printf "\nReplay passed: 4 low-severity detections, 1 critical correlation, 0 benign matches.\n"
  jq -r \
    '"Backtest passed: \(.summary.expectations_passed)/\(.summary.expectations_total) expectations."' \
    "${backtest_output}"
}

live() {
  if ! command -v multipass &>/dev/null; then
    err "multipass is required for the live path"
    return 1
  fi
  multipass exec rsigma-lss -- \
    sudo /home/ubuntu/rsigma-talk/demo/live-run.sh
}

main() {
  if (( $# != 1 )); then
    show_usage
    return 2
  fi

  case "$1" in
    --replay)
      replay
      ;;
    --live)
      live
      ;;
    -h|--help)
      show_usage
      ;;
    *)
      err "unknown argument: $1"
      show_usage
      return 2
      ;;
  esac
}

main "$@"
