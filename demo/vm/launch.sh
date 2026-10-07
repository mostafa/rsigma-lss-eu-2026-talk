#!/usr/bin/env bash
#
# Create or start the pinned Ubuntu Multipass instance and provision the demo.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
readonly ROOT_DIR
readonly INSTANCE="rsigma-lss"
readonly MOUNT_POINT="/home/ubuntu/rsigma-talk"

# shellcheck disable=SC1091
source "${ROOT_DIR}/versions.env"

err() {
  echo "error: $*" >&2
}

instance_exists() {
  multipass list --format json \
    | jq -e --arg name "${INSTANCE}" \
      '.list[] | select(.name == $name)' \
      >/dev/null
}

main() {
  if ! command -v multipass &>/dev/null; then
    err "multipass is not installed"
    return 1
  fi
  if ! command -v jq &>/dev/null; then
    err "jq is not installed"
    return 1
  fi

  if ! instance_exists; then
    multipass launch "${UBUNTU_IMAGE}" \
      --name "${INSTANCE}" \
      --cpus 4 \
      --memory 6G \
      --disk 20G \
      --cloud-init "${SCRIPT_DIR}/cloud-init.yml"
  else
    multipass start "${INSTANCE}" >/dev/null 2>&1 || true
  fi

  if ! multipass exec "${INSTANCE}" -- cloud-init status --wait; then
    multipass exec "${INSTANCE}" -- \
      test -f /var/lib/rsigma-talk/cloud-init-ready
  fi

  if ! multipass exec "${INSTANCE}" -- \
    test -f "${MOUNT_POINT}/versions.env"; then
    multipass exec "${INSTANCE}" -- mkdir -p "${MOUNT_POINT}"
    multipass mount "${ROOT_DIR}" "${INSTANCE}:${MOUNT_POINT}"
  fi

  multipass exec "${INSTANCE}" -- \
    chmod +x \
    "${MOUNT_POINT}/demo/vm/check-kernel.sh" \
    "${MOUNT_POINT}/demo/vm/provision.sh"
  multipass exec "${INSTANCE}" -- \
    "${MOUNT_POINT}/demo/vm/check-kernel.sh"
  multipass exec "${INSTANCE}" -- \
    "${MOUNT_POINT}/demo/vm/provision.sh"

  multipass info "${INSTANCE}"
}

main "$@"
