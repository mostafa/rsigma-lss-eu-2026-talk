#!/usr/bin/env bash
#
# Snapshot the fully provisioned VM for offline stage recovery.

set -euo pipefail

readonly INSTANCE="rsigma-lss"
readonly SNAPSHOT="ready-v1"

main() {
  if multipass info "${INSTANCE}.${SNAPSHOT}" >/dev/null 2>&1; then
    echo "Snapshot ${INSTANCE}.${SNAPSHOT} already exists."
    return
  fi

  multipass stop "${INSTANCE}"
  multipass snapshot \
    --name "${SNAPSHOT}" \
    --comment "LSS EU 2026 offline-ready demo" \
    "${INSTANCE}"
  multipass start "${INSTANCE}"
  multipass info "${INSTANCE}.${SNAPSHOT}"
}

main "$@"
