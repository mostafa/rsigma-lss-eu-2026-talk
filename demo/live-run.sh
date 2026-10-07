#!/usr/bin/env bash
#
# Run the complete in-VM telemetry-to-correlation demonstration.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly ROOT_DIR
readonly API_URL="http://127.0.0.1:9090"
readonly LOG_DIR="/var/log/rsigma-talk"
readonly DETECTIONS="${LOG_DIR}/detections.ndjson"
readonly AUDIT_CAPTURE="${LOG_DIR}/auditd-normalized.ndjson"
readonly TETRAGON_CAPTURE="${LOG_DIR}/tetragon-normalized.ndjson"
readonly ATTACK_DIR="/var/lib/rsigma-talk/attack"

daemon_pid=""
audit_adapter_pid=""
tetragon_adapter_pid=""

cleanup() {
  local pid

  for pid in \
    "${audit_adapter_pid}" \
    "${tetragon_adapter_pid}" \
    "${daemon_pid}"; do
    [[ -z "${pid}" ]] || kill "${pid}" 2>/dev/null || true
  done
}

wait_for_ready() {
  local attempt

  for ((attempt = 1; attempt <= 30; attempt++)); do
    if curl --fail --silent "${API_URL}/readyz" >/dev/null; then
      return
    fi
    sleep 1
  done
  echo "error: RSigma did not become ready" >&2
  return 1
}

wait_for_correlation() {
  local attempt

  for ((attempt = 1; attempt <= 15; attempt++)); do
    if [[ -s "${DETECTIONS}" ]] \
      && jq -e -s \
        'any(.[]; .rule_title == "Linux Discovery-to-Execution Sequence")' \
        "${DETECTIONS}" \
        >/dev/null; then
      return
    fi
    sleep 1
  done
  echo "error: correlated alert did not arrive" >&2
  return 1
}

main() {
  local rsigma_pid

  if (( EUID != 0 )); then
    echo "error: run live-run.sh as root inside the VM" >&2
    return 1
  fi

  trap cleanup EXIT
  cd "${ROOT_DIR}"
  install -d -o ubuntu -g ubuntu -m 0750 "${LOG_DIR}"
  rm -rf "${ATTACK_DIR}"
  cp -R "${SCRIPT_DIR}/attack" "${ATTACK_DIR}"
  chown -R lssdemo:lssdemo "${ATTACK_DIR}"
  chmod 0755 "${ATTACK_DIR}/chain.sh" "${ATTACK_DIR}/tcp_listener.py"
  rm -f \
    "${DETECTIONS}" \
    "${AUDIT_CAPTURE}" \
    "${TETRAGON_CAPTURE}" \
    "${LOG_DIR}/daemon.log"
  touch "${DETECTIONS}"
  chown ubuntu:ubuntu "${DETECTIONS}"

  # The wrapper itself is root, so the shell owns this redirect.
  # shellcheck disable=SC2024
  sudo -u ubuntu rsigma engine daemon \
    --rules "${SCRIPT_DIR}/rules" \
    --input http \
    --input-format json \
    --output "file://${DETECTIONS}" \
    --api-addr 127.0.0.1:9090 \
    --schema-routing \
    --schema-config "${SCRIPT_DIR}/schema-routing.yml" \
    --logsource-routing \
    --timestamp-field "@timestamp" \
    >"${LOG_DIR}/daemon.log" 2>&1 &
  daemon_pid="$!"
  wait_for_ready

  tail --pid="$$" -n 0 -F /var/log/laurel/audit.log \
    | python3 "${SCRIPT_DIR}/adapters/auditd/normalize.py" \
      --host rsigma-lss \
      --url "${API_URL}/api/v1/events" \
      --capture "${AUDIT_CAPTURE}" &
  audit_adapter_pid="$!"

  tail --pid="$$" -n 0 -F /var/log/tetragon/tetragon.log \
    | python3 "${SCRIPT_DIR}/adapters/tetragon/normalize.py" \
      --host rsigma-lss \
      --url "${API_URL}/api/v1/events" \
      --capture "${TETRAGON_CAPTURE}" &
  tetragon_adapter_pid="$!"
  sleep 2

  sudo -u lssdemo "${ATTACK_DIR}/chain.sh"
  wait_for_correlation

  jq -r '"\(.level | ascii_upcase)\t\(.rule_title)"' "${DETECTIONS}"
  rsigma_pid="$(pidof rsigma)"
  printf "\nRSigma process footprint after correlation:\n"
  awk '/VmRSS|VmPeak/ {print}' "/proc/${rsigma_pid}/status"
  printf "\nCaptured normalized telemetry:\n%s\n%s\n" \
    "${AUDIT_CAPTURE}" \
    "${TETRAGON_CAPTURE}"
}

main "$@"
