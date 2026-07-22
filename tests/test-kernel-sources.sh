#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repo_root}"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

assert_contains() {
  local haystack="$1"
  local needle="$2"
  if [[ "${haystack}" != *"${needle}"* ]]; then
    echo "FAIL: expected to find '${needle}' in output" >&2
    echo "${haystack}" >&2
    exit 1
  fi
}

# Default aosp-pablo preset
out="$(
  cd "${tmp_dir}"
  mkdir -p config scripts release
  cp "${repo_root}/config/kernel-sources.json" config/
  cp "${repo_root}/scripts/resolve-kernel-source.sh" scripts/
  KERNEL_SOURCE=aosp-pablo SOURCE_REF='' bash scripts/resolve-kernel-source.sh
  cat release/kernel-source.env
)"
assert_contains "${out}" "SOURCE_REPO=aosp-pablo/android_kernel_xiaomi_sm8450"
assert_contains "${out}" "SOURCE_REF=16"
assert_contains "${out}" "DEFCONFIG_MODE=gki_fragments"
assert_contains "${out}" "BASE_DEFCONFIG=gki_defconfig"

# LOS GKI fragments preset (aosp-pablo)
out="$(
  cd "${tmp_dir}"
  rm -rf release
  mkdir -p release
  KERNEL_SOURCE=aosp-pablo SOURCE_REF='' bash scripts/resolve-kernel-source.sh >/dev/null
  cat release/kernel-source.env
)"
assert_contains "${out}" "DEFCONFIG_MODE=gki_fragments"
assert_contains "${out}" "BASE_DEFCONFIG=gki_defconfig"
assert_contains "${out}" "vendor/marble_GKI.config"
assert_contains "${out}" "vendor/infinity.config"

# Optional source_ref override
out="$(
  cd "${tmp_dir}"
  rm -rf release
  mkdir -p release
  KERNEL_SOURCE=aosp-pablo SOURCE_REF=15 bash scripts/resolve-kernel-source.sh >/dev/null
  cat release/kernel-source.env
)"
assert_contains "${out}" "SOURCE_REF=15"

# Unknown preset must fail
if KERNEL_SOURCE=not-a-real-preset SOURCE_REF='' bash scripts/resolve-kernel-source.sh >/dev/null 2>&1; then
  echo "FAIL: unknown kernel_source should be rejected" >&2
  exit 1
fi

# Package naming uses manager tokens
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

today="$(date '+%Y.%m.%d')"

assert_name \
  "ksunext_susfs-marble-${today}.zip" \
  KERNEL_SOURCE=aosp-pablo \
  MANAGER=kernelsu-next ENABLE_SUSFS=true \
  manager_build_version_name='v3.2.0' manager_build_version_code=33203 \
  susfs_reported_version=v2.2.0

assert_name \
  "resukisu-marble-${today}.zip" \
  KERNEL_SOURCE=aosp-pablo \
  MANAGER=resukisu ENABLE_SUSFS=false \
  manager_build_version_name=v4.1.0 manager_build_version_code=34990

echo "Kernel source preset tests passed"
