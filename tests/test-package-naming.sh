#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repo_root}"

today="$(date '+%Y.%m.%d')"

assert_name() {
  local expected="$1"
  shift
  local actual
  actual="$(env PACKAGE_NAME_ONLY=true GITHUB_RUN_NUMBER=9 "$@" bash scripts/package-anykernel.sh)"
  if [[ "${actual}" != "${expected}" ]]; then
    echo "FAIL: expected ${expected}, got ${actual}" >&2
    exit 1
  fi
}

# KSUNext + SUSFS
assert_name \
  "ksunext_susfs-marble-${today}.zip" \
  KERNEL_SOURCE=aosp-pablo \
  MANAGER=kernelsu-next ENABLE_SUSFS=true \
  manager_build_version_name='v3.2.0@KernelSU-Next' \
  manager_build_version_code=33203 manager_commit=66656dd123456789 \
  susfs_reported_version=v2.2.0

# SukiSU + SUSFS
assert_name \
  "sukisu_susfs-marble-${today}.zip" \
  KERNEL_SOURCE=aosp-pablo \
  MANAGER=sukisu-ultra ENABLE_SUSFS=true \
  manager_build_version_name='v4.1.3-b88403d2@HEAD' \
  manager_build_version_code=40813 manager_commit=b88403d2561b6e00 \
  susfs_reported_version=v2.2.0

# ReSukiSU, no SUSFS
assert_name \
  "resukisu-marble-${today}.zip" \
  KERNEL_SOURCE=aosp-pablo \
  MANAGER=resukisu ENABLE_SUSFS=false \
  manager_version_code=34990 manager_commit=88e7f51c3840436b

echo "Package naming tests passed"
