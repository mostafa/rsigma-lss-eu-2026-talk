#!/usr/bin/env bash
#
# Fail early when the VM cannot support the auditd/Tetragon demo.

set -euo pipefail

err() {
  echo "error: $*" >&2
}

main() {
  local architecture
  local cgroup_type

  architecture="$(uname -m)"
  if [[ "${architecture}" != "aarch64" ]]; then
    err "expected aarch64, got ${architecture}"
    return 1
  fi
  if [[ ! -r /sys/kernel/btf/vmlinux ]]; then
    err "/sys/kernel/btf/vmlinux is not readable"
    return 1
  fi

  cgroup_type="$(stat -fc %T /sys/fs/cgroup)"
  if [[ "${cgroup_type}" != "cgroup2fs" ]]; then
    err "expected cgroup v2, got ${cgroup_type}"
    return 1
  fi

  if ! sudo auditctl -s >/dev/null; then
    err "audit subsystem is unavailable"
    return 1
  fi

  printf "Kernel checks passed: %s, BTF, cgroup v2, audit subsystem.\n" \
    "${architecture}"
}

main "$@"
