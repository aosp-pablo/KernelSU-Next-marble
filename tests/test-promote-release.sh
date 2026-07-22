#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repo_root}"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

today="$(date '+%Y.%m.%d')"

make_artifact() {
  local root="$1"
  local artifact="$2"
  local manager="$3"
  local zip_name="$4"
  local dir="${root}/${artifact}"
  mkdir -p "${dir}"
  printf '%s\n' "${manager}-payload" > "${dir}/${zip_name}"
  (cd "${dir}" && sha256sum "${zip_name}" > "${zip_name}.sha256")
  printf 'zip_name=%s\n' "${zip_name}" > "${dir}/zip-name.env"
  printf '{}\n' > "${dir}/build-info.json"
  cat > "${dir}/build-info.txt" <<INFO
source_repo=aosp-pablo/android_kernel_xiaomi_sm8450
source_ref=16
source_commit=3673961d444b5e2b879be97a161241243d543bd2
workflow_run=https://github.com/mohdakil2426/marble-kernel-builder/actions/runs/123
android_clang_version=clang-r416183b
manager=${manager}
manager_repo=example/${manager}
manager_ref=main
manager_commit=1234567890abcdef
manager_build_version_code=12345
manager_build_version_name=v1.0.0
enable_susfs=true
susfs_kernel_branch=gki-android12-5.10
susfs_commit=4003ecf2d01c6d13fa8edf6c4f2607365738dc3d
susfs_reported_version=v2.2.0
susfs_url=https://gitlab.com/simonpunk/susfs4ksu/-/commit/4003ecf2d01c6d13fa8edf6c4f2607365738dc3d
INFO
}

valid_dir="${tmp_dir}/valid"
make_artifact "${valid_dir}" marble-flash-kernelsu-next-susfs-image-only-r9 kernelsu-next \
  "ksunext_susfs-marble-${today}.zip"
make_artifact "${valid_dir}" marble-flash-resukisu-susfs-image-only-r9 resukisu \
  "resukisu_susfs-marble-${today}.zip"

MATRIX_ARTIFACTS_DIR="${valid_dir}" \
MATRIX_SUMMARY="${tmp_dir}/matrix-summary.md" \
RELEASE_ASSETS_FILE="${tmp_dir}/release-assets.txt" \
BUILD_SCOPE=image-only \
  bash scripts/prepare-promoted-release.sh

[[ -s "${tmp_dir}/matrix-summary.md" ]] || {
  echo "FAIL: combined release summary was not generated" >&2
  exit 1
}
[[ -s "${tmp_dir}/matrix-summary-release.md" ]] || {
  echo "FAIL: release notes file without cache section was not generated" >&2
  exit 1
}
if grep -Eq 'marble-ci-cache|^## .*Cache$' "${tmp_dir}/matrix-summary-release.md"; then
  echo "FAIL: matrix-summary-release.md must not include CI cache section" >&2
  exit 1
fi
[[ "$(wc -l < "${tmp_dir}/release-assets.txt")" -eq 2 ]] || {
  echo "FAIL: release manifest should contain two ZIPs" >&2
  exit 1
}
if grep -Evq '\.zip$' "${tmp_dir}/release-assets.txt"; then
  echo "FAIL: release manifest contains a non-ZIP asset" >&2
  exit 1
fi

single_root="${tmp_dir}/valid-single-root"
make_artifact "${tmp_dir}" valid-single-root kernelsu-next \
  "ksunext_susfs-marble-${today}.zip"

MATRIX_ARTIFACTS_DIR="${single_root}" \
MATRIX_SUMMARY="${tmp_dir}/single-matrix-summary.md" \
RELEASE_ASSETS_FILE="${tmp_dir}/single-release-assets.txt" \
BUILD_SCOPE=image-only \
  bash scripts/prepare-promoted-release.sh

[[ "$(wc -l < "${tmp_dir}/single-release-assets.txt")" -eq 1 ]] || {
  echo "FAIL: single direct artifact release manifest should contain one ZIP" >&2
  exit 1
}

bad_dir="${tmp_dir}/bad-checksum"
cp -R "${valid_dir}" "${bad_dir}"
printf 'tampered\n' >> "$(find "${bad_dir}" -name '*.zip' -print -quit)"
if MATRIX_ARTIFACTS_DIR="${bad_dir}" MATRIX_SUMMARY="${tmp_dir}/bad.md" \
  RELEASE_ASSETS_FILE="${tmp_dir}/bad-assets.txt" BUILD_SCOPE=image-only \
  bash scripts/prepare-promoted-release.sh >/dev/null 2>&1; then
  echo "FAIL: checksum mismatch should block promotion" >&2
  exit 1
fi

missing_dir="${tmp_dir}/missing-metadata"
cp -R "${valid_dir}" "${missing_dir}"
rm "$(find "${missing_dir}" -name build-info.json -print -quit)"
if MATRIX_ARTIFACTS_DIR="${missing_dir}" MATRIX_SUMMARY="${tmp_dir}/missing.md" \
  RELEASE_ASSETS_FILE="${tmp_dir}/missing-assets.txt" BUILD_SCOPE=image-only \
  bash scripts/prepare-promoted-release.sh >/dev/null 2>&1; then
  echo "FAIL: missing metadata should block promotion" >&2
  exit 1
fi

duplicate_dir="${tmp_dir}/duplicate"
duplicate_name="ksunext_susfs-marble-${today}.zip"
make_artifact "${duplicate_dir}" marble-flash-one-image-only-r9 kernelsu-next "${duplicate_name}"
make_artifact "${duplicate_dir}" marble-flash-two-image-only-r9 resukisu "${duplicate_name}"
if MATRIX_ARTIFACTS_DIR="${duplicate_dir}" MATRIX_SUMMARY="${tmp_dir}/duplicate.md" \
  RELEASE_ASSETS_FILE="${tmp_dir}/duplicate-assets.txt" BUILD_SCOPE=image-only \
  bash scripts/prepare-promoted-release.sh >/dev/null 2>&1; then
  echo "FAIL: duplicate ZIP names should block promotion" >&2
  exit 1
fi

empty_dir="${tmp_dir}/empty"
mkdir -p "${empty_dir}"
if MATRIX_ARTIFACTS_DIR="${empty_dir}" MATRIX_SUMMARY="${tmp_dir}/empty.md" \
  RELEASE_ASSETS_FILE="${tmp_dir}/empty-assets.txt" BUILD_SCOPE=image-only \
  bash scripts/prepare-promoted-release.sh >/dev/null 2>&1; then
  echo "FAIL: empty artifact directory should block promotion" >&2
  exit 1
fi

echo "Promoted release tests passed"
