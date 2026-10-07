#!/usr/bin/env bash
#
# Install the pinned demo dependencies inside the Multipass VM.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
readonly ROOT_DIR
readonly STATE_DIR="/var/lib/rsigma-talk"
readonly MARKER="${STATE_DIR}/provisioned-v1"
temp_dir=""

# shellcheck disable=SC1091
source "${ROOT_DIR}/versions.env"

err() {
  echo "error: $*" >&2
}

cleanup() {
  [[ -z "${temp_dir}" ]] || rm -rf "${temp_dir}"
}

download() {
  local url="$1"
  local expected="$2"
  local output="$3"
  local actual

  curl --fail --location --silent --show-error "${url}" --output "${output}"
  actual="$(sha256sum "${output}" | awk '{print $1}')"
  if [[ "${actual}" != "${expected}" ]]; then
    err "checksum mismatch for ${url}: expected ${expected}, got ${actual}"
    return 1
  fi
}

install_rsigma() {
  local archive="$1"
  local extract_dir="$2"

  download \
    "${RSIGMA_LINUX_ARM64_URL}" \
    "${RSIGMA_LINUX_ARM64_SHA256}" \
    "${archive}"
  mkdir -p "${extract_dir}"
  tar -xzf "${archive}" -C "${extract_dir}"
  sudo install -m 0755 "${extract_dir}/rsigma" /usr/local/bin/rsigma
}

install_tetragon() {
  local archive="$1"
  local extract_dir="$2"
  local -a installers

  download \
    "${TETRAGON_LINUX_ARM64_URL}" \
    "${TETRAGON_LINUX_ARM64_SHA256}" \
    "${archive}"
  mkdir -p "${extract_dir}"
  tar -xzf "${archive}" -C "${extract_dir}"
  installers=("${extract_dir}"/tetragon-*/install.sh)
  if (( ${#installers[@]} != 1 )) || [[ ! -f "${installers[0]}" ]]; then
    err "could not locate the Tetragon installer"
    return 1
  fi
  sudo bash "${installers[0]}"
  sudo systemctl enable --now tetragon
}

install_laurel() {
  local archive="$1"
  local extract_dir="$2"
  local -a binaries

  download \
    "${LAUREL_LINUX_ARM64_URL}" \
    "${LAUREL_LINUX_ARM64_SHA256}" \
    "${archive}"
  mkdir -p "${extract_dir}"
  tar -xzf "${archive}" -C "${extract_dir}"
  binaries=("${extract_dir}"/laurel-*/bin/laurel)
  if (( ${#binaries[@]} != 1 )) || [[ ! -f "${binaries[0]}" ]]; then
    err "could not locate the Laurel binary"
    return 1
  fi
  sudo install -m 0755 "${binaries[0]}" /usr/local/sbin/laurel

  if ! id _laurel &>/dev/null; then
    sudo useradd \
      --system \
      --home-dir /var/log/laurel \
      --no-create-home \
      _laurel
  fi
  sudo usermod -a -G _laurel lssdemo
  sudo install -d -o _laurel -g _laurel -m 0750 /var/log/laurel
  sudo install -d -o root -g root -m 0755 /etc/laurel
  sudo tee /etc/laurel/config.toml >/dev/null <<'EOF'
directory = "/var/log/laurel"
user = "_laurel"
statusreport-period = 0
input = "stdin"

[auditlog]
file = "audit.log"
size = 5000000
generations = 2

[state]
file = "state"
generations = 0
max-age = 60

[transform]
execve-argv = [ "array" ]

[translate]
universal = false
user-db = false
drop-raw = false

[enrich]
pid = true
spawned-by = true
container = true
systemd = true
script = true
user-groups = false
EOF
  sudo tee /etc/audit/plugins.d/laurel.conf >/dev/null <<'EOF'
active = yes
direction = out
type = always
format = string
path = /usr/local/sbin/laurel
args = --config /etc/laurel/config.toml
EOF
  sudo pkill -HUP auditd
  sleep 2
}

main() {
  if [[ -f "${MARKER}" ]]; then
    echo "VM dependencies are already provisioned."
    return
  fi

  temp_dir="$(mktemp -d)"
  trap cleanup EXIT

  install_rsigma \
    "${temp_dir}/rsigma.tar.gz" \
    "${temp_dir}/rsigma"
  install_tetragon \
    "${temp_dir}/tetragon.tar.gz" \
    "${temp_dir}/tetragon"
  install_laurel \
    "${temp_dir}/laurel.tar.gz" \
    "${temp_dir}/laurel"

  sudo systemctl restart tetragon
  sleep 2
  sudo systemctl is-active --quiet tetragon
  sudo systemctl is-active --quiet auditd
  pgrep -x laurel >/dev/null
  rsigma --version

  sudo touch "${MARKER}"
  echo "Pinned VM dependencies installed."
}

main "$@"
