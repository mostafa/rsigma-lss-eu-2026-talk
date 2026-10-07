#!/usr/bin/env bash
#
# Trigger four harmless, ordered Linux behaviors over loopback.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
readonly PAYLOAD_DIR="/usr/local/share/rsigma-talk"
readonly OUTPUT="/tmp/lss-demo-payload"

http_pid=""
tcp_pid=""

cleanup() {
  [[ -z "${http_pid}" ]] || kill "${http_pid}" 2>/dev/null || true
  [[ -z "${tcp_pid}" ]] || kill "${tcp_pid}" 2>/dev/null || true
  rm -f "${OUTPUT}"
}

main() {
  trap cleanup EXIT

  python3 -m http.server \
    18080 \
    --bind 127.0.0.1 \
    --directory "${PAYLOAD_DIR}" \
    >/tmp/rsigma-talk-http.log 2>&1 &
  http_pid="$!"
  python3 "${SCRIPT_DIR}/tcp_listener.py" \
    >/tmp/rsigma-talk-tcp.log 2>&1 &
  tcp_pid="$!"
  sleep 1

  printf "[1/4] discovery\n"
  whoami >/dev/null
  sleep 2

  printf "[2/4] loopback download\n"
  curl \
    --fail \
    --silent \
    --show-error \
    http://127.0.0.1:18080/payload \
    --output "${OUTPUT}"
  sleep 2

  printf "[3/4] permission change\n"
  chmod +x "${OUTPUT}"
  sleep 2

  printf "[4/4] network utility\n"
  printf "probe\n" | nc -w 2 127.0.0.1 18081
  wait "${tcp_pid}"
  tcp_pid=""
}

main "$@"
