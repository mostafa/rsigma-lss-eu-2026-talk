#!/usr/bin/env bash
#
# Install the pinned RSigma release binary into demo/.state/bin.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly ROOT_DIR
readonly STATE_DIR="${SCRIPT_DIR}/.state"
readonly BIN_DIR="${STATE_DIR}/bin"
readonly ARCHIVE="${STATE_DIR}/rsigma.tar.gz"

# shellcheck disable=SC1091
source "${ROOT_DIR}/versions.env"

err() {
  echo "error: $*" >&2
}

sha256_file() {
  local path="$1"

  if command -v sha256sum &>/dev/null; then
    sha256sum "${path}" | awk '{print $1}'
  else
    shasum -a 256 "${path}" | awk '{print $1}'
  fi
}

main() {
  local os
  local arch
  local url
  local expected
  local actual

  os="$(uname -s)"
  arch="$(uname -m)"
  if [[ "${arch}" != "arm64" && "${arch}" != "aarch64" ]]; then
    err "only arm64/aarch64 hosts are supported, got ${arch}"
    return 1
  fi

  case "${os}" in
    Darwin)
      url="${RSIGMA_MACOS_ARM64_URL}"
      expected="${RSIGMA_MACOS_ARM64_SHA256}"
      ;;
    Linux)
      url="${RSIGMA_LINUX_ARM64_URL}"
      expected="${RSIGMA_LINUX_ARM64_SHA256}"
      ;;
    *)
      err "unsupported operating system: ${os}"
      return 1
      ;;
  esac

  if [[ -x "${BIN_DIR}/rsigma" ]]; then
    "${BIN_DIR}/rsigma" --version
    return
  fi

  mkdir -p "${BIN_DIR}"
  curl --fail --location --silent --show-error "${url}" --output "${ARCHIVE}"
  actual="$(sha256_file "${ARCHIVE}")"
  if [[ "${actual}" != "${expected}" ]]; then
    err "checksum mismatch: expected ${expected}, got ${actual}"
    return 1
  fi

  tar -xzf "${ARCHIVE}" -C "${BIN_DIR}"
  chmod 0755 "${BIN_DIR}/rsigma"
  "${BIN_DIR}/rsigma" --version
}

main "$@"
